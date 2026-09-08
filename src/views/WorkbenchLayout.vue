<script setup lang="ts">
import { computed, ref, watch } from "vue";
import {
  AddOutline,
  ArchiveOutline,
  AlertCircleOutline,
  ChatbubbleEllipsesOutline,
  CheckmarkDoneOutline,
  DocumentTextOutline,
  FileTrayOutline,
  ImageOutline,
  InformationCircleOutline,
  LogOutOutline,
  MailUnreadOutline,
  MicOutline,
  NotificationsOffOutline,
  PinOutline,
  SearchOutline,
  SettingsOutline,
  SyncOutline,
  TimeOutline,
  TrashOutline,
  VideocamOutline,
} from "@vicons/ionicons5";
import {
  NButton,
  NIcon,
  NInput,
  NModal,
  NSelect,
  NTag,
  useMessage,
} from "naive-ui";
import { useRoute, useRouter } from "vue-router";
import { FlareFilterTabs, FlareStartConversationDialog, FlareWorkbenchShell } from "@flare-im/vue-ui/components";
import type { FlareWorkbenchShellMode } from "@flare-im/vue-ui/contracts";
import { provideFlareWorkbenchUi } from "@flare-im/vue-ui/composables";
import { useFlareTheme, type FlareThemeMode, type FlareThemeVariant } from "@flare-im/vue-ui/theme";
import {
  displayTextFromStoredPreview,
  previewTextFromMessageContent,
} from "@flare-im/vue-ui/utils";
import {
  MessageSearchKind,
} from "@flare-im/sdk/web";
import {
  FlareConversationDetails as ConversationDetails,
  FlareDiagnosticsConsole as DeveloperConsole,
  FlareMessageActionSheet as MessageActionSheet,
  FlareMessagePreviewModal as MessagePreviewModal,
} from "@flare-im/vue-ui/components";
import {
  conversationTitle,
  useFlareI18n,
  useFlareSdk,
  type FlareLocale,
} from "@flare-im/vue-ui/app";

type MessageIdentity = { readonly serverId: string; readonly clientMsgId: string };
type ChatSearchResultMessage = MessageIdentity & {
  readonly content?: {
    readonly contentType?: string;
    readonly data?: Record<string, unknown>;
  };
  readonly textPreview?: string;
  readonly senderDisplayName?: string;
  readonly senderName?: string;
  readonly senderId?: string;
  readonly createdAt?: number;
  readonly clientCreatedAt?: number;
  readonly conversationSeq?: number;
};
type ChatSearchKindValue = "all" | "text" | "media" | "image" | "video" | "audio" | "file";

const sdk = useFlareSdk();
const message = useMessage();
const router = useRouter();
const route = useRoute();
const { t, locale, setLocale } = useFlareI18n();
const { mode: themeMode, variant: themeVariant, setMode: setThemeMode, setVariant: setThemeVariant } =
  useFlareTheme();

const settingsOpen = ref(false);
const startChatOpen = ref(false);
const moreOpen = ref(false);
const sdkBuildOpen = ref(false);
const chatSearchOpen = ref(false);
const chatSearchQuery = ref("");
const chatSearchKind = ref<ChatSearchKindValue>("all");
const chatSearchLoading = ref(false);
const chatSearchSearched = ref(false);
const chatSearchError = ref("");
const chatSearchLastQuery = ref("");
const chatSearchLastKind = ref<ChatSearchKindValue>("all");
const previewOpen = ref(false);
const previewMessageId = ref("");
const startConversationType = ref<"single" | "group">("single");
const startPeerUserId = ref("");

watch(startChatOpen, (open) => {
  if (open) {
    startPeerUserId.value = sdk.sdkLab.peerUserId.trim() || "";
  }
});

provideFlareWorkbenchUi({
  openMore: () => {
    moreOpen.value = true;
  },
  openStartChat: () => {
    startChatOpen.value = true;
  },
  openSdkBuild: () => {
    sdkBuildOpen.value = true;
  },
  openChatSearch: () => {
    chatSearchOpen.value = true;
  },
  openPreview: (messageId: string) => {
    previewMessageId.value = messageId;
    previewOpen.value = true;
  },
});

const shellMode = computed<FlareWorkbenchShellMode>(() => {
  if (route.name === "chat") return "chat";
  if (route.name === "sdk-lab") return "lab";
  return "conversations";
});

const moreActionCount = computed(() => {
  if (route.name === "chat") return 11;
  if (route.name === "conversations") return 5;
  return 3;
});

const themeModeValue = computed({
  get: () => themeMode.value,
  set: (value: FlareThemeMode) => setThemeMode(value),
});

const themeVariantValue = computed({
  get: () => themeVariant.value,
  set: (value: FlareThemeVariant) => setThemeVariant(value),
});

const localeValue = computed({
  get: () => locale.value,
  set: (value: FlareLocale) => setLocale(value),
});

const moreDrawerTitle = computed(() => (route.name === "chat" ? t("workbench.chatActions") : t("workbench.more")));
const activeConversation = computed(() => sdk.activeConversation.value);
const activeConversationUnread = computed(() => Math.max(0, Number(activeConversation.value?.unreadCount ?? 0) || 0));
const activeConversationPinned = computed(() => Boolean(activeConversation.value?.isPinned));
const activeConversationMuted = computed(() => Boolean(activeConversation.value?.isMuted));
const activeConversationArchived = computed(() => Boolean(activeConversation.value?.isArchived));
const chatSearchResults = computed(() => sdk.messageSearchResults.value);
const chatSearchCanSubmit = computed(() =>
  Boolean(sdk.activeConversationId.value && chatSearchQuery.value.trim() && !chatSearchLoading.value),
);
const chatSearchSummaryText = computed(() => {
  if (chatSearchLoading.value) return t("workbench.searchingCurrentConv");
  if (chatSearchError.value) return t("workbench.searchFailed");
  if (!chatSearchSearched.value) return t("workbench.searchStartHint");
  return t("workbench.resultsCount", { count: chatSearchResults.value.length });
});
const chatSearchActiveConversationText = computed(() => {
  const target = activeConversation.value;
  if (!target) return t("workbench.noConvSelected");
  return conversationTitle(target, sdk.currentUserId.value || sdk.form.userId) || target.conversationId;
});
const chatSearchLastKindLabel = computed(() =>
  chatSearchKindOptions.find((option) => option.value === chatSearchLastKind.value)?.label ?? t("workbench.kind.all"),
);

const chatSearchKindOptions = [
  { label: t("workbench.kind.all"), value: "all", icon: ChatbubbleEllipsesOutline },
  { label: t("workbench.kind.text"), value: "text", icon: DocumentTextOutline },
  { label: t("workbench.kind.media"), value: "media", icon: FileTrayOutline },
  { label: t("workbench.kind.image"), value: "image", icon: ImageOutline },
  { label: t("workbench.kind.video"), value: "video", icon: VideocamOutline },
  { label: t("workbench.kind.audio"), value: "audio", icon: MicOutline },
  { label: t("workbench.kind.file"), value: "file", icon: FileTrayOutline },
] satisfies Array<{ label: string; value: ChatSearchKindValue; icon: typeof SearchOutline }>;

const connectionTone = computed(() => {
  if (sdk.connectionState.value === "ready" || sdk.connectionState.value === "connected") return "success";
  if (sdk.connectionState.value === "connecting" || sdk.connectionState.value === "reconnecting") return "warning";
  return "default";
});

const connectionText = computed(() => {
  const state = sdk.connectionState.value;
  if (state === "ready") return "Ready";
  if (state === "connected") return "Connected";
  if (state === "connecting") return "Connecting";
  if (state === "reconnecting") return "Reconnecting";
  return "Disconnected";
});

const diagnosticsText = computed(() => JSON.stringify(sdk.diagnostics.value, null, 2));
const labResultText = computed(() => JSON.stringify(sdk.labResult.value, null, 2));
const previewMessage = computed(() => findMessage(previewMessageId.value));

function findMessage(id: string) {
  if (!id) return null;
  return (
    sdk.messages.value.find((m) => m.serverId === id || m.clientMsgId === id) ??
    chatSearchResults.value.find((m) => m.serverId === id || m.clientMsgId === id) ??
    null
  );
}

function messageId(message: MessageIdentity): string {
  return message.clientMsgId || message.serverId;
}

function chatSearchResultText(message: ChatSearchResultMessage): string {
  const contentText = previewTextFromMessageContent(message.content, locale.value).trim();
  if (contentText) return contentText;
  const storedPreview = displayTextFromStoredPreview(message.textPreview ?? "", locale.value).trim();
  if (storedPreview) return storedPreview;
  return chatSearchResultKindLabel(message);
}

function chatSearchResultKindLabel(message: ChatSearchResultMessage & { readonly content?: { readonly contentType?: string } }): string {
  const type = message.content?.contentType ?? "";
  if (type === "image") return t("workbench.kind.image");
  if (type === "video") return t("workbench.kind.video");
  if (type === "audio") return t("workbench.kind.audio");
  if (type === "file") return t("workbench.kind.file");
  if (type === "sticker") return t("workbench.kind.sticker");
  if (type === "emoji") return t("workbench.kind.emoji");
  return t("workbench.kind.message");
}

function chatSearchResultIcon(message: ChatSearchResultMessage): typeof SearchOutline {
  const type = message.content?.contentType ?? "";
  if (type === "image") return ImageOutline;
  if (type === "video") return VideocamOutline;
  if (type === "audio") return MicOutline;
  if (type === "file") return FileTrayOutline;
  return DocumentTextOutline;
}

function chatSearchResultSender(message: ChatSearchResultMessage): string {
  return message.senderDisplayName?.trim() || message.senderName?.trim() || message.senderId || t("workbench.unknownMember");
}

function chatSearchResultTime(message: ChatSearchResultMessage): string {
  const timestamp = Number(message.createdAt || message.clientCreatedAt || 0);
  if (!Number.isFinite(timestamp) || timestamp <= 0) return t("workbench.justNow");
  const date = new Date(timestamp);
  const now = new Date();
  const sameDay =
    date.getFullYear() === now.getFullYear() &&
    date.getMonth() === now.getMonth() &&
    date.getDate() === now.getDate();
  const time = new Intl.DateTimeFormat("zh-CN", {
    hour: "2-digit",
    minute: "2-digit",
    hour12: false,
  }).format(date);
  if (sameDay) return time;
  return t("workbench.monthDayTime", { month: date.getMonth() + 1, day: date.getDate(), time });
}

function chatSearchResultSeq(message: ChatSearchResultMessage): string {
  const seq = Number(message.conversationSeq);
  return Number.isFinite(seq) && seq > 0 ? `seq ${seq}` : t("workbench.localMessage");
}

function openSearchResult(message: ChatSearchResultMessage): void {
  previewMessageId.value = messageId(message);
  previewOpen.value = true;
}

function selectChatSearchKind(value: ChatSearchKindValue): void {
  chatSearchKind.value = value;
  if (!chatSearchQuery.value.trim()) return;
  void searchMessages();
}

function navigate(name: "conversations" | "chat" | "sdk-lab"): void {
  void router.push({ name });
}

async function logout(): Promise<void> {
  await sdk.logout();
  await router.replace({ name: "login" });
}

async function conversationOpenChat(): Promise<void> {
  const peerUserId = startPeerUserId.value.trim();
  if (!peerUserId) return;
  await sdk.openPeerConversation(startConversationType.value, peerUserId);
  startChatOpen.value = false;
  await router.push({ name: "chat" });
}

async function conversationDelete(): Promise<void> {
  await sdk.runConversationOperation("delete");
  await router.replace({ name: "conversations" });
}

async function conversationPullFromServer(): Promise<void> {
  if (route.name === "chat") {
    await sdk.syncActiveConversation();
    await sdk.runSyncOperation("read");
    return;
  }
  await sdk.syncConversationsFromServer();
}

async function chatEnterLoadAndMarkRead(): Promise<void> {
  await conversationPullFromServer();
}

async function runActiveConversationAction(kind: string): Promise<void> {
  if (!sdk.activeConversationId.value) return;
  if (kind === "delete") {
    await conversationDelete();
  } else {
    await sdk.runConversationOperation(kind);
  }
  moreOpen.value = false;
}

async function searchMessages(): Promise<void> {
  const query = chatSearchQuery.value.trim();
  chatSearchError.value = "";
  chatSearchSearched.value = Boolean(query);
  if (!query) {
    await sdk.searchActiveMessages("", []);
    return;
  }
  if (!sdk.activeConversationId.value) {
    chatSearchError.value = t("workbench.selectOneConvFirst");
    return;
  }
  chatSearchLoading.value = true;
  chatSearchLastQuery.value = query;
  chatSearchLastKind.value = chatSearchKind.value;
  try {
    await sdk.searchActiveMessages(query, selectedChatSearchKinds());
  } catch (error) {
    chatSearchError.value = searchErrorText(error);
  } finally {
    chatSearchLoading.value = false;
  }
}

function selectedChatSearchKinds(): MessageSearchKind[] {
  switch (chatSearchKind.value) {
    case "text":
      return [MessageSearchKind.Text];
    case "media":
      return [MessageSearchKind.Media];
    case "image":
      return [MessageSearchKind.Image];
    case "video":
      return [MessageSearchKind.Video];
    case "audio":
      return [MessageSearchKind.Audio];
    case "file":
      return [MessageSearchKind.File];
    default:
      return [MessageSearchKind.Message];
  }
}

function operationErrorText(error: unknown, fallback: string): string {
  if (error instanceof Error && error.message.trim()) return error.message;
  if (typeof error === "string" && error.trim()) return error;
  return fallback;
}

function searchErrorText(error: unknown): string {
  return operationErrorText(error, t("workbench.searchUnavailable"));
}

async function buildFromAction(op: string): Promise<void> {
  try {
    await sdk.buildFromComposerAction(op, "");
    sdkBuildOpen.value = false;
  } catch (error) {
    message.error(operationErrorText(error, t("chat.sendFailed")));
  }
}
</script>

<template>
  <FlareWorkbenchShell
    v-model:more-open="moreOpen"
    v-model:chat-search-open="chatSearchOpen"
    v-model:sdk-build-open="sdkBuildOpen"
    v-model:preview-open="previewOpen"
    :mode="shellMode"
    :more-title="moreDrawerTitle"
    :more-action-count="moreActionCount"
    :message-unread-count="sdk.totalUnread.value"
    @navigate-messages="navigate('conversations')"
    @navigate-lab="navigate('sdk-lab')"
    @logout="logout"
  >
    <template #conversation>
      <router-view name="conversation" />
    </template>

    <template #main>
      <router-view name="main" />
    </template>

    <template #details>
      <ConversationDetails
        :conversation="sdk.activeConversation.value"
        :connection-text="connectionText"
        :connection-tone="connectionTone"
        :message-count="sdk.messages.value.length"
        :latest-message-id="sdk.activeLatestMessageId.value"
        @sync="chatEnterLoadAndMarkRead"
        @mark-read="sdk.runSyncOperation('read')"
        @mark-unread="sdk.runConversationOperation('mark_unread')"
        @pin="(pinned) => sdk.runConversationOperation(pinned ? 'pin' : 'unpin')"
        @mute="(muted) => sdk.runConversationOperation(muted ? 'mute' : 'unmute')"
        @archive="(archived) => sdk.runConversationOperation(archived ? 'archive' : 'unarchive')"
        @clear-history="sdk.runConversationOperation('clear_history')"
        @delete="conversationDelete"
        @open-devtools="navigate('sdk-lab')"
      />
    </template>

    <template #more>
      <section v-if="route.name === 'conversations'" class="account-sheet-header">
        <div class="account-avatar">{{ sdk.form.userId.slice(0, 1).toUpperCase() }}</div>
        <div>
          <span>{{ t("workbench.account") }}</span>
          <strong>{{ sdk.form.userId }}</strong>
        </div>
        <n-tag :type="connectionTone" round>{{ connectionText }}</n-tag>
      </section>
      <div class="more-action-list">
        <button v-if="route.name === 'conversations'" type="button" @click="startChatOpen = true; moreOpen = false">
          <n-icon :component="AddOutline" /> {{ t("workbench.newChat") }}
        </button>
        <button v-if="route.name === 'chat'" type="button" @click="chatSearchOpen = true; moreOpen = false">
          <n-icon :component="SearchOutline" /> {{ t("workbench.searchMessages") }}
        </button>
        <button v-if="route.name === 'conversations'" type="button" @click="conversationPullFromServer(); moreOpen = false">
          <n-icon :component="SyncOutline" /> {{ t("workbench.pullFromServer") }}
        </button>
        <button v-if="route.name === 'chat'" type="button" @click="chatEnterLoadAndMarkRead(); moreOpen = false">
          <n-icon :component="SyncOutline" /> {{ t("workbench.syncAndMarkRead") }}
        </button>
      </div>
      <div v-if="route.name === 'chat' && activeConversation" class="more-action-list more-action-list--grouped">
        <button type="button" @click="runActiveConversationAction(activeConversationUnread ? 'mark_read' : 'mark_unread')">
          <n-icon :component="activeConversationUnread ? CheckmarkDoneOutline : MailUnreadOutline" />
          {{ activeConversationUnread ? t("workbench.markRead") : t("workbench.markUnread") }}
        </button>
        <button type="button" @click="runActiveConversationAction(activeConversationPinned ? 'unpin' : 'pin')">
          <n-icon :component="PinOutline" /> {{ activeConversationPinned ? t("workbench.unpinConv") : t("workbench.pinConv") }}
        </button>
        <button type="button" @click="runActiveConversationAction(activeConversationMuted ? 'unmute' : 'mute')">
          <n-icon :component="NotificationsOffOutline" /> {{ activeConversationMuted ? t("workbench.unmuteConv") : t("workbench.muteConv") }}
        </button>
        <button type="button" @click="runActiveConversationAction(activeConversationArchived ? 'unarchive' : 'archive')">
          <n-icon :component="ArchiveOutline" /> {{ activeConversationArchived ? t("workbench.unarchiveConv") : t("workbench.archiveConv") }}
        </button>
        <button type="button" @click="runActiveConversationAction('clear_history')">
          <n-icon :component="TrashOutline" /> {{ t("workbench.clearLocalHistory") }}
        </button>
        <button type="button" class="more-action-danger" @click="runActiveConversationAction('delete')">
          <n-icon :component="TrashOutline" /> {{ t("workbench.deleteConv") }}
        </button>
      </div>
      <div class="more-action-list more-action-list--grouped">
        <button type="button" @click="navigate('sdk-lab'); moreOpen = false">
          <n-icon :component="InformationCircleOutline" /> {{ t("workbench.sdkRuntimeStatus") }}
        </button>
        <button type="button" @click="settingsOpen = true; moreOpen = false">
          <n-icon :component="SettingsOutline" /> {{ t("nav.settings") }}
        </button>
        <button type="button" class="more-action-danger" @click="logout(); moreOpen = false">
          <n-icon :component="LogOutOutline" /> {{ t("common.logout") }}
        </button>
      </div>
    </template>

    <template #chat-search>
      <form class="chat-search-panel" @submit.prevent="searchMessages">
        <header class="chat-search-panel__header">
          <div class="chat-search-panel__scope">
            <span>{{ t("workbench.currentConv") }}</span>
            <strong>{{ chatSearchActiveConversationText }}</strong>
          </div>
          <div class="chat-search-panel__summary">
            <n-icon :component="chatSearchLoading ? TimeOutline : SearchOutline" />
            <span>{{ chatSearchSummaryText }}</span>
          </div>
        </header>

        <div class="chat-search-panel__field">
          <n-input
            v-model:value="chatSearchQuery"
            round
            clearable
            :disabled="!sdk.activeConversationId.value"
            :placeholder="t(`workbench.searchChatHistory`)"
          >
            <template #prefix><n-icon :component="SearchOutline" /></template>
          </n-input>
          <n-button
            type="primary"
            attr-type="submit"
            :loading="chatSearchLoading"
            :disabled="!chatSearchCanSubmit"
          >{{ t("workbench.searchBtn") }}</n-button>
        </div>

        <FlareFilterTabs
          class="chat-search-panel__filters"
          :options="chatSearchKindOptions"
          :active="chatSearchKind"
          @change="(v: string) => selectChatSearchKind(v as ChatSearchKindValue)"
        />

        <div v-if="chatSearchSearched && !chatSearchError" class="chat-search-panel__meta">
          <span>{{ chatSearchLastKindLabel }}</span>
          <strong>{{ chatSearchLastQuery }}</strong>
        </div>

        <div v-if="!sdk.activeConversationId.value" class="chat-search-panel__state">
          <n-icon :component="ChatbubbleEllipsesOutline" />
          <strong>{{ t("workbench.noConvSelected") }}</strong>
          <span>{{ t("workbench.searchNoContent") }}</span>
        </div>
        <div v-else-if="chatSearchError" class="chat-search-panel__state chat-search-panel__state--error">
          <n-icon :component="AlertCircleOutline" />
          <strong>{{ t("workbench.searchFailed") }}</strong>
          <span>{{ chatSearchError }}</span>
        </div>
        <div v-else-if="chatSearchLoading" class="chat-search-panel__state">
          <span class="chat-search-panel__spinner" />
          <strong>{{ t("workbench.searchingTitle") }}</strong>
          <span>{{ t("workbench.searchingHint") }}</span>
        </div>
        <div v-else-if="!chatSearchSearched" class="chat-search-panel__state chat-search-panel__state--idle">
          <n-icon :component="SearchOutline" />
          <strong>{{ t("workbench.searchCurrentConvTitle") }}</strong>
          <span>{{ t("workbench.searchStartHint") }}</span>
        </div>
        <div v-else-if="!chatSearchResults.length" class="chat-search-panel__state">
          <n-icon :component="SearchOutline" />
          <strong>{{ t("workbench.noRelatedMsg") }}</strong>
          <span>{{ t("workbench.tryOtherKeyword") }}</span>
        </div>
        <div v-else class="chat-search-results" role="list">
          <button
            v-for="message in chatSearchResults"
            :key="messageId(message)"
            type="button"
            class="chat-search-result-card"
            role="listitem"
            @click="openSearchResult(message)"
          >
            <span class="chat-search-result-card__icon">
              <n-icon :component="chatSearchResultIcon(message)" />
            </span>
            <div class="chat-search-result-card__content">
              <div class="chat-search-result-card__topline">
                <strong>{{ chatSearchResultSender(message) }}</strong>
                <span>{{ chatSearchResultTime(message) }}</span>
              </div>
              <p>{{ chatSearchResultText(message) }}</p>
              <div class="chat-search-result-card__meta">
                <span>{{ chatSearchResultKindLabel(message) }}</span>
                <span>{{ chatSearchResultSeq(message) }}</span>
              </div>
            </div>
          </button>
        </div>
      </form>
    </template>

    <template #sdk-build>
      <MessageActionSheet @build="buildFromAction" />
      <DeveloperConsole
        class="sdk-build-console"
        :diagnostics-text="diagnosticsText"
        :lab-result-text="labResultText"
        :lab-busy="sdk.labBusy.value"
        :build-options="sdk.messageBuildOptions.value"
        :dispatch-options="sdk.messageDispatchOptions"
        :sdk-lab="sdk.sdkLab"
        :events="sdk.events.value"
        @session="sdk.runSessionDiagnostics"
        @events="sdk.runEventOperation"
        @open-peer="sdk.openPeerConversation"
        @build-send="sdk.buildAndSendMessage()"
        @dispatch="sdk.runDispatch()"
        @conversation="sdk.runConversationOperation"
        @sync="sdk.runSyncOperation"
        @presence="sdk.runPresenceOperation"
        @media="sdk.runMediaOperation"
        @capability="sdk.runCapabilityOperation"
      />
    </template>

    <template #preview>
      <MessagePreviewModal :message="previewMessage" />
    </template>
  </FlareWorkbenchShell>

  <FlareStartConversationDialog
    v-model:open="startChatOpen"
    v-model:peer-user-id="startPeerUserId"
    v-model:conversation-type="startConversationType"
    :busy="sdk.labBusy.value"
    @confirm="conversationOpenChat"
  />

  <n-modal v-model:show="settingsOpen" preset="card" :title="t('nav.settings')" style="max-width: 420px">
    <div class="settings-form">
      <label class="settings-field">
        <span>{{ t("workbench.themeMode") }}</span>
        <n-select
          v-model:value="themeModeValue"
          :options="[
            { label: t('workbench.themeOpt.system'), value: 'system' },
            { label: t('workbench.themeOpt.light'), value: 'light' },
            { label: t('workbench.themeOpt.dark'), value: 'dark' },
          ]"
        />
      </label>
      <label class="settings-field">
        <span>{{ t("workbench.themeVariant") }}</span>
        <n-select
          v-model:value="themeVariantValue"
          :options="[
            { label: t('workbench.variantOpt.default'), value: 'default' },
            { label: t('workbench.variantOpt.compact'), value: 'compact' },
            { label: t('workbench.variantOpt.callDark'), value: 'callDark' },
            { label: t('workbench.variantOpt.highContrast'), value: 'highContrast' },
          ]"
        />
      </label>
      <label class="settings-field">
        <span>{{ t("workbench.language") }}</span>
        <n-select
          v-model:value="localeValue"
          :options="[
            { label: '简体中文', value: 'zh-CN' },
            { label: 'English', value: 'en-US' },
          ]"
        />
      </label>
    </div>
  </n-modal>
</template>

<style scoped>
.settings-form {
  display: grid;
  gap: 14px;
}

.settings-field {
  display: grid;
  gap: 6px;
  font-size: 13px;
  color: var(--text-secondary);
}

:global(.workbench-search-sheet.mobile-sheet .n-drawer-body-content-wrapper) {
  background:
    linear-gradient(180deg, color-mix(in srgb, var(--im-primary) 7%, transparent), transparent 132px),
    var(--im-bg-app);
}

:global(.workbench-search-sheet .n-drawer-content) {
  background: transparent;
}

:global(.workbench-search-sheet .n-drawer-header) {
  border-bottom: 1px solid color-mix(in srgb, var(--im-border) 74%, transparent);
  background: color-mix(in srgb, var(--im-bg-surface) 92%, transparent);
}

:global(.workbench-search-sheet .n-drawer-header__main) {
  color: var(--im-text-primary);
  font-size: 16px;
  font-weight: 800;
}

:global(.workbench-search-sheet.n-drawer--bottom .n-drawer-content::before) {
  background: color-mix(in srgb, var(--im-text-tertiary) 56%, transparent);
}

.chat-search-panel {
  display: grid;
  align-content: start;
  grid-template-rows: auto;
  gap: 12px;
  min-height: 100%;
  color: var(--im-text-primary);
}

.chat-search-panel__header {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  align-items: center;
  gap: 10px;
  padding: 10px 12px;
  border: 1px solid color-mix(in srgb, var(--im-border) 82%, transparent);
  border-radius: 14px;
  background: color-mix(in srgb, var(--im-bg-surface) 92%, transparent);
  box-shadow: 0 10px 24px color-mix(in srgb, #000000 5%, transparent);
}

.chat-search-panel__scope {
  display: grid;
  gap: 4px;
  min-width: 0;
}

.chat-search-panel__scope span,
.chat-search-panel__summary,
.chat-search-panel__meta {
  color: var(--im-text-tertiary);
  font-size: 12px;
}

.chat-search-panel__scope strong {
  min-width: 0;
  overflow: hidden;
  color: var(--im-text-primary);
  font-size: 15px;
  font-weight: 800;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.chat-search-panel__summary {
  display: inline-flex;
  align-items: center;
  gap: 6px;
  max-width: 132px;
  min-height: 28px;
  padding: 0 10px;
  border: 1px solid color-mix(in srgb, var(--im-border) 74%, transparent);
  border-radius: 999px;
  background: color-mix(in srgb, var(--im-bg-surface-alt, var(--im-bg-surface)) 72%, transparent);
}

.chat-search-panel__summary span {
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.chat-search-panel__summary .n-icon {
  flex: 0 0 auto;
  color: var(--im-primary);
  font-size: 15px;
}

.chat-search-panel__field {
  display: grid;
  grid-template-columns: minmax(0, 1fr) auto;
  align-items: center;
  gap: 10px;
}

.chat-search-panel__field :deep(.n-input) {
  --n-border: 1px solid color-mix(in srgb, var(--im-border) 86%, transparent) !important;
  --n-border-hover: 1px solid color-mix(in srgb, var(--im-primary) 44%, var(--im-border)) !important;
  --n-border-focus: 1px solid var(--im-primary) !important;
  --n-box-shadow-focus: 0 0 0 2px color-mix(in srgb, var(--im-primary) 18%, transparent) !important;
  height: 44px;
  min-height: 44px;
  border-radius: 14px;
  background: color-mix(in srgb, var(--im-bg-surface) 96%, transparent);
}

.chat-search-panel__field :deep(.n-input-wrapper) {
  min-height: 44px;
  align-items: center;
}

.chat-search-panel__field :deep(.n-button) {
  height: 44px;
  min-width: 72px;
  border-radius: 12px;
  font-weight: 800;
}

.chat-search-panel__filters {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 8px;
}

.chat-search-panel__filters button {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  gap: 6px;
  min-width: 0;
  min-height: 42px;
  padding: 0 10px;
  border: 1px solid color-mix(in srgb, var(--im-border) 82%, transparent);
  border-radius: 12px;
  color: var(--im-text-secondary);
  background: color-mix(in srgb, var(--im-bg-surface) 90%, transparent);
  cursor: pointer;
  font: inherit;
  font-size: 12px;
  font-weight: 800;
  white-space: nowrap;
}

.chat-search-panel__filters button:hover {
  border-color: color-mix(in srgb, var(--im-primary) 30%, var(--im-border));
  color: var(--im-text-primary);
  background: color-mix(in srgb, var(--im-primary) 7%, var(--im-bg-surface));
}

.chat-search-panel__filters button.is-active {
  border-color: color-mix(in srgb, var(--im-primary) 46%, transparent);
  color: var(--im-primary);
  background: color-mix(in srgb, var(--im-primary) 13%, var(--im-bg-surface));
  box-shadow: 0 8px 22px color-mix(in srgb, var(--im-primary) 10%, transparent);
}

.chat-search-panel__filters .n-icon {
  flex: 0 0 auto;
  font-size: 15px;
}

.chat-search-panel__meta {
  display: flex;
  align-items: center;
  gap: 8px;
  min-width: 0;
  padding: 0 2px;
}

.chat-search-panel__meta span {
  flex: 0 0 auto;
  padding: 3px 8px;
  border-radius: 999px;
  color: var(--im-primary);
  background: color-mix(in srgb, var(--im-primary) 11%, transparent);
}

.chat-search-panel__meta strong {
  min-width: 0;
  overflow: hidden;
  color: var(--im-text-secondary);
  font-size: 12px;
  font-weight: 700;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.chat-search-panel__state {
  display: grid;
  justify-items: center;
  gap: 7px;
  min-height: 172px;
  align-content: center;
  padding: 22px 16px;
  border: 1px dashed color-mix(in srgb, var(--im-border) 78%, transparent);
  border-radius: 16px;
  color: var(--im-text-tertiary);
  text-align: center;
  background: color-mix(in srgb, var(--im-bg-surface) 70%, transparent);
}

.chat-search-panel__state--idle {
  min-height: 150px;
  border-style: solid;
  background:
    radial-gradient(circle at 50% 0%, color-mix(in srgb, var(--im-primary) 10%, transparent), transparent 54%),
    color-mix(in srgb, var(--im-bg-surface) 82%, transparent);
}

.chat-search-panel__state .n-icon {
  font-size: 32px;
  color: color-mix(in srgb, var(--im-primary) 72%, var(--im-text-tertiary));
}

.chat-search-panel__state strong {
  color: var(--im-text-primary);
  font-size: 15px;
}

.chat-search-panel__state span {
  max-width: 260px;
  font-size: 12px;
  line-height: 1.5;
}

.chat-search-panel__state--error {
  border-color: color-mix(in srgb, var(--im-danger, #ef4444) 38%, transparent);
  color: color-mix(in srgb, var(--im-danger, #ef4444) 78%, var(--im-text-secondary));
  background: color-mix(in srgb, var(--im-danger, #ef4444) 8%, var(--im-bg-surface));
}

.chat-search-panel__state--error .n-icon {
  color: var(--im-danger, #ef4444);
}

.chat-search-panel__spinner {
  width: 30px;
  height: 30px;
  border: 2px solid color-mix(in srgb, var(--im-primary) 16%, transparent);
  border-top-color: var(--im-primary);
  border-radius: 999px;
  animation: chat-search-spin 0.8s linear infinite;
}

.chat-search-results {
  display: grid;
  gap: 9px;
  padding-bottom: 4px;
}

.chat-search-result-card {
  display: grid;
  grid-template-columns: 36px minmax(0, 1fr);
  gap: 10px;
  width: 100%;
  min-width: 0;
  padding: 11px;
  border: 1px solid color-mix(in srgb, var(--im-border) 78%, transparent);
  border-radius: 13px;
  color: inherit;
  background: color-mix(in srgb, var(--im-bg-surface) 94%, transparent);
  box-shadow: 0 10px 24px color-mix(in srgb, #000000 5%, transparent);
  cursor: pointer;
  font: inherit;
  text-align: left;
}

.chat-search-result-card:hover {
  border-color: color-mix(in srgb, var(--im-primary) 34%, var(--im-border));
  background: color-mix(in srgb, var(--im-primary) 5%, var(--im-bg-surface));
}

.chat-search-result-card__icon {
  display: grid;
  place-items: center;
  width: 36px;
  height: 36px;
  border-radius: 12px;
  color: var(--im-primary);
  background: color-mix(in srgb, var(--im-primary) 13%, var(--im-bg-surface));
}

.chat-search-result-card__icon .n-icon {
  font-size: 19px;
}

.chat-search-result-card__content {
  display: grid;
  gap: 6px;
  min-width: 0;
}

.chat-search-result-card__topline,
.chat-search-result-card__meta {
  display: flex;
  align-items: center;
  gap: 8px;
  min-width: 0;
}

.chat-search-result-card__topline strong {
  min-width: 0;
  overflow: hidden;
  color: var(--im-text-primary);
  font-size: 13px;
  font-weight: 800;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.chat-search-result-card__topline span {
  flex: 0 0 auto;
  color: var(--im-text-tertiary);
  font-size: 11px;
}

.chat-search-result-card p {
  display: -webkit-box;
  min-width: 0;
  margin: 0;
  overflow: hidden;
  color: var(--im-text-primary);
  font-size: 13px;
  line-height: 1.55;
  -webkit-box-orient: vertical;
  -webkit-line-clamp: 2;
}

.chat-search-result-card__meta span {
  min-width: 0;
  overflow: hidden;
  color: var(--im-text-tertiary);
  font-size: 11px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.chat-search-result-card__meta span:first-child {
  flex: 0 0 auto;
  padding: 2px 7px;
  border-radius: 999px;
  color: var(--im-primary);
  background: color-mix(in srgb, var(--im-primary) 10%, transparent);
}

@keyframes chat-search-spin {
  to {
    transform: rotate(360deg);
  }
}

@media (max-width: 560px) {
  .chat-search-panel__header {
    grid-template-columns: 1fr;
  }

  .chat-search-panel__summary {
    justify-self: start;
    max-width: 100%;
  }

  .chat-search-panel__filters {
    grid-template-columns: repeat(3, minmax(0, 1fr));
  }

  .chat-search-result-card {
    grid-template-columns: 34px minmax(0, 1fr);
    padding: 10px;
  }

  .chat-search-result-card__icon {
    width: 34px;
    height: 34px;
    border-radius: 10px;
  }
}
</style>
