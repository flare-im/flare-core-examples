<script setup lang="ts">
// Reference-app workbench shell (rail + panes + sheets). A product shell, not
// kit API; it composes public kit composables and glyphs only.
import { computed } from "vue";
import {
  ChatbubbleEllipsesOutline,
  InformationCircleOutline,
  LogOutOutline,
} from "@flare-im/vue-ui/icon-glyphs";
import { useViewport } from "@flare-im/vue-ui/composables";
import { workbenchShellClass, type WorkbenchShellMode } from "./workbenchShell";
import AppIcon from "./AppIcon.vue";
import WorkbenchOverlay from "./WorkbenchOverlay.vue";

const props = withDefaults(
  defineProps<{
    mode?: WorkbenchShellMode;
    brandLabel?: string;
    navigationLabel?: string;
    messagesLabel?: string;
    labLabel?: string;
    logoutLabel?: string;
    moreTitle?: string;
    moreSheetHeight?: string;
    moreActionCount?: number;
    messageUnreadCount?: number;
    chatSearchTitle?: string;
    sdkBuildTitle?: string;
    previewTitle?: string;
    closeLabel?: string;
  }>(),
  {
    mode: "conversations",
    brandLabel: "F",
    navigationLabel: "Flare IM navigation",
    messagesLabel: "Messages",
    labLabel: "SDK Lab",
    logoutLabel: "Log out",
    moreTitle: "More",
    moreActionCount: 2,
    messageUnreadCount: 0,
    chatSearchTitle: "Search messages",
    sdkBuildTitle: "SDK message type",
    previewTitle: "Message preview",
    closeLabel: "Close",
  },
);

const moreOpen = defineModel<boolean>("moreOpen", { default: false });
const chatSearchOpen = defineModel<boolean>("chatSearchOpen", { default: false });
const sdkBuildOpen = defineModel<boolean>("sdkBuildOpen", { default: false });
const previewOpen = defineModel<boolean>("previewOpen", { default: false });

const emit = defineEmits<{
  (event: "navigate-messages"): void;
  (event: "navigate-lab"): void;
  (event: "logout"): void;
}>();

const { isDesktop } = useViewport();

const shellClass = computed(() => workbenchShellClass(props.mode));
const messagesNavActive = computed(() => props.mode === "conversations" || props.mode === "chat");
const labNavActive = computed(() => props.mode === "lab");
const showConversationPanel = computed(() => props.mode !== "lab");
const showDetails = computed(() => props.mode === "conversations" || props.mode === "chat");
const messageUnread = computed(() => Math.max(0, Math.floor(Number(props.messageUnreadCount) || 0)));
const messageUnreadLabel = computed(() => (messageUnread.value > 99 ? "99+" : String(messageUnread.value)));

const sheetPlacement = computed<"right" | "bottom">(() => (isDesktop.value ? "right" : "bottom"));
const sheetWidth = computed(() => (isDesktop.value ? 440 : undefined));
const tallSheetHeight = computed(() => (isDesktop.value ? undefined : "70vh"));

const resolvedMoreSheetHeight = computed(() => {
  if (props.moreSheetHeight) return props.moreSheetHeight;
  if (isDesktop.value) return undefined;
  const grabberAndTitle = 48;
  const accountCard = props.mode === "conversations" ? 88 : 0;
  const listTop = 10;
  const rowHeight = 48;
  const rowGap = 6;
  const actions =
    props.moreActionCount * rowHeight + Math.max(0, props.moreActionCount - 1) * rowGap + listTop;
  const edge = 10;
  const total = grabberAndTitle + accountCard + actions + edge;
  const maxPx =
    typeof window !== "undefined" ? Math.round(window.innerHeight * 0.5) : 400;
  return `${Math.min(total, maxPx)}px`;
});
</script>

<template>
  <main class="flutter-shell workbench-shell" :class="shellClass">
    <nav class="workbench-rail" :aria-label="navigationLabel">
      <button
        type="button"
        class="workbench-rail__brand"
        title="flare IM"
        @click="emit('navigate-messages')"
      >
        {{ brandLabel }}
      </button>
      <button
        type="button"
        class="workbench-rail__item"
        :class="{ 'workbench-rail__item--active': messagesNavActive }"
        :title="messagesLabel"
        :aria-label="messagesLabel"
        @click="emit('navigate-messages')"
      >
        <AppIcon :icon="ChatbubbleEllipsesOutline" />
        <span class="workbench-rail__label">{{ messagesLabel }}</span>
        <span v-if="messageUnread" class="workbench-rail__badge">{{ messageUnreadLabel }}</span>
      </button>
      <button
        type="button"
        class="workbench-rail__item"
        :class="{ 'workbench-rail__item--active': labNavActive }"
        :title="labLabel"
        :aria-label="labLabel"
        @click="emit('navigate-lab')"
      >
        <AppIcon :icon="InformationCircleOutline" />
        <span class="workbench-rail__label">{{ labLabel }}</span>
      </button>
      <span class="workbench-rail__spacer" />
      <button type="button" class="workbench-rail__item" :title="logoutLabel" :aria-label="logoutLabel" @click="emit('logout')">
        <AppIcon :icon="LogOutOutline" />
        <span class="workbench-rail__label">{{ logoutLabel }}</span>
      </button>
    </nav>

    <slot v-if="showConversationPanel" name="conversation" />
    <slot name="main" />

    <aside v-if="showDetails" class="workbench-details">
      <slot name="details" />
    </aside>

    <WorkbenchOverlay
      v-model:open="moreOpen"
      class="workbench-more-sheet"
      :title="moreTitle"
      :placement="sheetPlacement"
      :width="sheetWidth"
      :height="resolvedMoreSheetHeight"
      :close-label="closeLabel"
    >
      <slot name="more" />
    </WorkbenchOverlay>

    <WorkbenchOverlay
      v-model:open="chatSearchOpen"
      class="workbench-search-sheet"
      :title="chatSearchTitle"
      :placement="sheetPlacement"
      :width="sheetWidth"
      :height="tallSheetHeight"
      :close-label="closeLabel"
    >
      <slot name="chat-search" />
    </WorkbenchOverlay>

    <WorkbenchOverlay
      v-model:open="sdkBuildOpen"
      :title="sdkBuildTitle"
      :placement="sheetPlacement"
      :width="sheetWidth"
      :height="tallSheetHeight"
      :close-label="closeLabel"
    >
      <slot name="sdk-build" />
    </WorkbenchOverlay>

    <WorkbenchOverlay
      v-model:open="previewOpen"
      class="preview-card"
      :title="previewTitle"
      placement="center"
      :close-label="closeLabel"
    >
      <slot name="preview" />
    </WorkbenchOverlay>
  </main>
</template>
