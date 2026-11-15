<script setup lang="ts">
/**
 * The engine's alerts while the link is up, and the conversation on screen the engine needs to know. The engine
 * decides every alert (mute, quiet hours, the conversation on screen, one notification per conversation, the ring
 * budget) and renders its text; this only shows what it hands over:
 * - system notifications through the SDK notifier with the Tauri presenter;
 * - the kit's in-app banner for presentations with surface `inApp`, with the app's message sound; opening it opens the
 *   conversation the way the conversation list does (the workbench cannot be asked to scroll to one message);
 * - the dock / taskbar badge and the tray title from `notification.badge`.
 * It starts with the session and stops on sign-out. The notification permission is asked once per account, from the
 * conversation list, with the kit's soft-ask: the same rule as the mobile apps. The permission is the one the settings
 * sheet shows (./permission.ts), so an answer in either place updates both. It renders inside `ReferenceApp`.
 */
import { computed, onBeforeUnmount, onMounted, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import { startSystemNotifications, type SystemNotifications } from "@flare-im/sdk/notifications";
import { FlareInAppNotificationHost, FlarePermissionPrompt } from "@flare-im/vue-ui/components";
import { createFlareInAppNotifications } from "@flare-im/vue-ui/composables";
import { inAppNotificationChannels, type FlareInAppNotificationChannel } from "@flare-im/vue-ui/contracts";
import {
  getFlareSdkSingleton,
  playDesktopNotificationSound,
} from "../../../../shared/vue-reference/workbench/app";
import { setDesktopBadgeCount } from "../desktopNotifications";
import { notificationPermission, notificationPresenter } from "./permission";

const referenceSdk = getFlareSdkSingleton();
if (!referenceSdk) throw new Error("MessageAlerts reads the reference app's SDK: mount it inside ReferenceApp.");
// A non-null binding: function declarations below are hoisted and do not see the narrowing above.
const sdk = referenceSdk;
const { client } = sdk;
const router = useRouter();
const route = useRoute();
const banners = createFlareInAppNotifications();

let notifier: SystemNotifications | null = null;
let listeners: Array<{ unsubscribe(): void }> = [];
const permission = notificationPermission.state;
const softAskAnswered = ref(true);

function warn(error: unknown): void {
  console.warn("[notifications]", error);
}

function inAppChannel(channel: string): FlareInAppNotificationChannel {
  return (inAppNotificationChannels as readonly string[]).includes(channel)
    ? channel as FlareInAppNotificationChannel
    : "messages";
}

/** Opens a conversation the way the conversation list does. */
async function openConversation(conversationId: string): Promise<void> {
  if (!conversationId || !sdk.loggedIn.value) return;
  try {
    const selecting = sdk.selectConversation(conversationId);
    await router.push({ name: "chat" });
    await selecting;
  } catch (error) {
    warn(error);
  }
}

function start(): void {
  stop();
  notifier = startSystemNotifications(client.events, {
    presenter: notificationPresenter,
    onOpen: ({ conversationId }) => void openConversation(conversationId),
    onError: warn,
  });
  listeners = [
    client.events.onNotificationPresent((presentation) => {
      if (presentation.surface !== "inApp") return;
      banners.present({
        collapseId: presentation.collapseId,
        conversationId: presentation.conversationId,
        ...(presentation.messageId ? { messageId: presentation.messageId } : {}),
        title: presentation.title,
        body: presentation.body,
        count: Math.max(1, presentation.count),
        channel: inAppChannel(presentation.channel),
      });
      if (presentation.sound) void playDesktopNotificationSound("message").catch(warn);
    }),
    client.events.onNotificationClear((event) => {
      if (event.all) banners.clearAll();
      else banners.clear(event.collapseIds);
    }),
    client.events.onNotificationBadge((event) => {
      void setDesktopBadgeCount(event.count).catch(warn);
    }),
  ];
  softAskAnswered.value = readSoftAskAnswered(account());
  void notificationPermission.refresh();
}

function stop(): void {
  notifier?.stop();
  notifier = null;
  for (const listener of listeners.splice(0)) listener.unsubscribe();
  banners.clearAll();
}

watch(sdk.loggedIn, (loggedIn) => {
  if (loggedIn) {
    start();
  } else {
    stop();
    void setDesktopBadgeCount(0).catch(warn);
  }
}, { immediate: true });

// The conversation on screen: the chat page of a focused window. Its messages do not alert while it is there.
const windowFocused = ref(true);
const onWindowFocus = () => { windowFocused.value = true; };
const onWindowBlur = () => { windowFocused.value = false; };
onMounted(() => {
  windowFocused.value = document.hasFocus();
  window.addEventListener("focus", onWindowFocus);
  window.addEventListener("blur", onWindowBlur);
});
onBeforeUnmount(() => {
  window.removeEventListener("focus", onWindowFocus);
  window.removeEventListener("blur", onWindowBlur);
  stop();
});

const focusedConversation = computed(() => {
  if (!sdk.loggedIn.value || !windowFocused.value || route.name !== "chat") return "";
  return sdk.activeConversationId.value.trim();
});
/** Focus reports reach the engine in order: each waits for the one before. */
let focusReport: Promise<void> = Promise.resolve();
watch([focusedConversation, sdk.loggedIn], ([conversationId]) => {
  focusReport = focusReport
    .then(() => client.notification.setFocus(conversationId ? { conversationId } : {}))
    .catch(warn);
}, { immediate: true });

// The soft-ask: once per account, on the conversation list, while the system can still ask.
const softAskOpen = computed(() =>
  sdk.loggedIn.value
  && sdk.homeSyncReady.value
  && route.name === "conversations"
  && permission.value === "prompt"
  && !softAskAnswered.value);

function account(): string {
  return `${sdk.form.tenantId.trim() || "0"}/${sdk.currentUserId.value.trim()}`;
}

function softAskKey(owner: string): string {
  return `flare.notifications.softAskAnswered.${owner}`;
}

function readSoftAskAnswered(owner: string): boolean {
  try {
    return localStorage.getItem(softAskKey(owner)) === "1";
  } catch {
    return false;
  }
}

function answerSoftAsk(): void {
  softAskAnswered.value = true;
  try {
    localStorage.setItem(softAskKey(account()), "1");
  } catch {
    // Storage unavailable: the prompt stays answered for this run.
  }
}

function turnOnNotifications(): void {
  answerSoftAsk();
  void notificationPermission.request();
}
</script>

<template>
  <FlareInAppNotificationHost :notifications="banners" @open="openConversation" />
  <FlarePermissionPrompt
    kind="notifications"
    state="undetermined"
    soft-ask
    presentation="sheet"
    :open="softAskOpen"
    @request="turnOnNotifications"
    @dismiss="answerSoftAsk"
  />
</template>
