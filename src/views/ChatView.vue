<script setup lang="ts">
import { computed, nextTick, onBeforeUnmount, onMounted, ref, watch } from "vue";
import {
  ArrowBackOutline,
  CallOutline,
  ChatbubbleEllipsesOutline,
  CloseOutline,
  EllipsisHorizontalOutline,
  LibraryOutline,
  PinOutline,
  SearchOutline,
  ShareSocialOutline,
  TrashOutline,
  VideocamOutline,
} from "@vicons/ionicons5";
import { NButton, NIcon, useMessage } from "naive-ui";
import { onBeforeRouteLeave, useRouter } from "vue-router";
import { MessageContentType, type Message, type MessageContent } from "@flare-im/sdk/web";
import {
  FlareChatHeader as ChatConversationHeader,
  FlareChatHeaderIdentity as ChatConversationHeaderIdentity,
  FlareComposer as EnhancedComposer,
  FlareComposerEmojiStickerPanel as ComposerEmojiStickerPanel,
  FlareMessageList as MessageList,
  FlarePinnedMessageBar as PinnedMessageBar,
} from "@flare-im/vue-ui/components";
import {
  formatEmojiPackToken,
  getMessageText,
  isMarkdown,
  listMessageMediaDownloadSources,
  markdownToPlainText,
  proxiedMediaUrl,
  resolveLoneEmojiPackKey,
  withTimeout,
  type MessageMediaDownloadSource,
} from "@flare-im/vue-ui/utils";
import type { MessageMenuConfig } from "@flare-im/vue-ui/utils";
import { useFlareWorkbenchUi } from "@flare-im/vue-ui/composables";
import {
  canRevealDownloadedMedia,
  conversationTitle,
  createMessageOperationAdapter,
  DraftIdleScheduler,
  FlareComposerPayloadModal as ComposerPayloadModal,
  FlareForwardModal as ForwardModal,
  FlareMediaComposerPreviewModal as MediaComposerPreviewModal,
  FlareMessageBatchToolbar as MessageBatchToolbar,
  hasAppMediaPathPicker,
  pickAppMediaSourcePaths,
  revealDownloadedMediaFile,
  resolveAppMediaLocalPath,
  resolveComposerAction,
  resolveConversationPeer,
  resolveMessageMenuActions,
  startBrowserDownload,
  useFlareI18n,
  useFlareSdk,
  useMessageInteractionState,
  type BatchOperationResult,
  type ComposerActionDefinition,
  type ComposerPayloadRequest,
  type EnhancedMessageKind,
  type ForwardMode,
  type MediaComposerPreviewItem,
  type MessageOperationSdk,
  type MessagePinScope,
} from "@flare-im/vue-ui/app";

type MessageIdentity = Pick<Message, "serverId" | "clientMsgId" | "messageType" | "content">;
type MediaDownloadAction = "download" | "openFolder";
type MediaDownloadState = "notDownloaded" | "downloading" | "downloaded";
type MessageMediaDownloadUiState = "idle" | "downloading" | "downloaded" | "openFolder";
type ComposerMentionCandidate = {
  userId: string;
  label?: string;
  avatarUrl?: string;
};
const COMPOSER_SEND_TIMEOUT_MS = 16_000;
const DRAFT_IDLE_DELAY_MS = 5_000;
const DRAFT_CLEAR_DELAY_MS = 1_200;
const MESSAGE_LOCATE_MAX_OLDER_LOADS = 48;

const workbenchUi = useFlareWorkbenchUi();
const sdk = useFlareSdk();
const router = useRouter();
const message = useMessage();
const { t } = useFlareI18n();

const composerText = ref("");
const replyMessageId = ref("");
const editingMessageId = ref("");
const composerPanel = ref<"emoji" | "sticker" | "more" | null>(null);
const composerRichMode = ref(false);
const chatContentTab = ref<"messages" | "pin">("messages");
const sending = ref(false);
const chatRouteRef = ref<HTMLElement | null>(null);
const composerStackRef = ref<HTMLElement | null>(null);
const composerRef = ref<{ insertAtCursor?: (text: string) => void; focus?: () => void } | null>(null);
const messageListRef = ref<InstanceType<typeof MessageList> | null>(null);
const mediaFileInput = ref<HTMLInputElement | null>(null);
const composerOverlayHeight = ref(88);
const mediaDownloadStates = ref<Record<string, MediaDownloadState>>({});
const mediaDownloadRefreshInFlight = ref(false);

let typingTimer: number | undefined;
let scrollBottomFrame: number | undefined;
let scrollBottomTimer: number | undefined;
let composerResizeObserver: ResizeObserver | null = null;
let skipNextComposerTextWatch = false;
let composerUserEditVersion = 0;
const draftClearTimers = new Map<string, number>();

const draftScheduler = new DraftIdleScheduler(DRAFT_IDLE_DELAY_MS, (conversationId, draft) =>
  sdk.clearConversationDraft(conversationId, draft),
);

const mediaPanelOpen = computed(() => composerPanel.value === "emoji" || composerPanel.value === "sticker");
const composerMediaTab = computed<"emoji" | "sticker">(() =>
  composerPanel.value === "sticker" ? "sticker" : "emoji",
);
const canSendText = computed(() =>
  composerText.value.trim().length > 0
  && !sending.value
  && Boolean(sdk.activeConversationId.value),
);
const chatRouteStyle = computed(() => ({
  "--chat-composer-overlay-height": `${composerOverlayHeight.value}px`,
}));
const messageListBottomInset = computed(() =>
  multiSelectMode.value
    ? 84
    : Math.max(24, Math.min(48, Math.round(composerOverlayHeight.value * 0.18))),
);
const peerPresenceStatus = ref<"online" | "offline" | "busy">("offline");
const messageInteractionSource = computed(() => sdk.messages.value as unknown as readonly Message[]);
const forwardConversationSource = computed(() => sdk.conversations.value as unknown as readonly import("@flare-im/sdk/web").Conversation[]);
const interactions = useMessageInteractionState(messageInteractionSource);
const operations = createMessageOperationAdapter(sdk as unknown as MessageOperationSdk);
const multiSelectMode = interactions.multiSelectMode;
const selectedMessageIds = interactions.selectedMessageIds;
const selectedMessages = interactions.selectedMessages;
const selectableMessageIds = interactions.selectableMessageIds;
const allSelected = interactions.allSelected;
const forwardOpen = interactions.forwardOpen;
const forwardMode = interactions.forwardMode;
const composerActionOpen = interactions.composerActionOpen;
const activeComposerOp = interactions.activeComposerOp;
const operationBusy = computed(() => sending.value || operations.busyKeys.value.size > 0);
const activeMediaAction = ref<ComposerActionDefinition | null>(null);
const mediaPreviewOpen = ref(false);
const mediaPreviewItems = ref<MediaComposerPreviewItem[]>([]);
const mediaFileAccept = computed(() => activeMediaAction.value ? mediaAcceptForKind(activeMediaAction.value.kind) : "");
const activePayloadAction = computed(() => resolveComposerAction(activeComposerOp.value));
const payloadComposerOpen = computed({
  get: () => Boolean(composerActionOpen.value && activePayloadAction.value && !activePayloadAction.value.acceptsFiles),
  set: (open: boolean) => {
    composerActionOpen.value = open;
    if (!open) activeComposerOp.value = "";
  },
});
const messageMenuConfig = computed<MessageMenuConfig>(() => ({
  resolveVisible: ({ message: row }) =>
    resolveMessageMenuActions(row as unknown as Message, {
      currentUserId: sdk.currentUserId.value || sdk.form.userId,
      connected: isConnected.value,
      multiSelectMode: multiSelectMode.value,
    }),
  resolveMediaAction: ({ message: row, hasDownloadableMedia }) => {
    if (!hasDownloadableMedia) return null;
    const first = firstMediaDownloadSource(row);
    if (!first) return null;
    const state = mediaDownloadStates.value[first.downloadKey];
    if (state === "downloading") return null;
    if (state === "downloaded") {
      return canRevealDownloadedMedia() ? "openMediaFolder" : "downloadMedia";
    }
    return "downloadMedia";
  },
}));

const messageMediaDownloadUiStates = computed<Record<string, MessageMediaDownloadUiState>>(() => {
  const states: Record<string, MessageMediaDownloadUiState> = {};
  const canOpenFolder = canRevealDownloadedMedia();
  for (const row of sdk.messages.value) {
    const messageRow = row as unknown as Message;
    const source = firstMediaDownloadSource(messageRow);
    if (!source) continue;
    const state = mediaDownloadStates.value[source.downloadKey];
    if (state === "downloading") {
      states[mediaMessageId(messageRow)] = "downloading";
    } else if (state === "downloaded" && canOpenFolder) {
      states[mediaMessageId(messageRow)] = "openFolder";
    }
  }
  return states;
});

const isConnected = computed(() => {
  const state = sdk.connectionState.value;
  return state === "ready" || state === "connected";
});

const activeTitle = computed(() =>
  conversationTitle(sdk.activeConversation.value, sdk.currentUserId.value || sdk.form.userId) || t("nav.chat"),
);
const activeSubtitle = computed(() => {
  const item = sdk.activeConversation.value;
  if (!item) return "";
  if (item.conversationType === "group") {
    return t("chat.members", { count: item.membersCount ?? 0 });
  }
  if (item.conversationType === "ai") return t("chat.aiAssistant");
  if (peerPresenceStatus.value === "online") return t("chat.online");
  if (peerPresenceStatus.value === "busy") return t("chat.busy");
  return t("chat.offline");
});

const composerDisabled = computed(() => !sdk.activeConversationId.value);
const composerStatusHint = computed(() => {
  if (isConnected.value) return "";
  const state = sdk.connectionState.value;
  if (state === "connecting") return t("connection.connecting");
  if (state === "reconnecting") return t("connection.reconnecting");
  return "";
});
const composerStatusPulse = computed(() => {
  const state = sdk.connectionState.value;
  return state === "connecting" || state === "reconnecting";
});
const pinnedCount = computed(() => sdk.pinnedMessages.value.length);
const showContentTabs = computed(() =>
  !multiSelectMode.value && Boolean(sdk.activeConversationId.value) && pinnedCount.value > 0,
);
const showingPinnedTab = computed(() => chatContentTab.value === "pin" && pinnedCount.value > 0);
const chatEmptyState = computed(() => {
  const conversation = sdk.activeConversation.value;
  const hasHistoryHint = Boolean(
    Boolean(conversation?.lastMessageId)
    || Boolean(conversation?.lastMessagePreview)
    || Boolean(conversation?.lastMessage?.messageId)
    || Number(conversation?.maxSeq ?? 0) > 0,
  );
  if (sdk.messageOpening.value || sdk.messageSyncing.value) {
    return {
      title: t("chat.emptySyncing"),
      detail: t("chat.emptySyncingHint"),
      loading: true,
      error: false,
    };
  }
  if (sdk.messageSyncError.value) {
    return {
      title: t("chat.emptySyncFailed"),
      detail: sdk.messageSyncError.value,
      loading: false,
      error: true,
    };
  }
  if (hasHistoryHint) {
    return {
      title: t("chat.emptyHistoryUnavailable"),
      detail: t("chat.emptyHistoryUnavailableHint"),
      loading: false,
      error: true,
    };
  }
  return {
    title: t("chat.emptyTitle"),
    detail: t("chat.emptyHint"),
    loading: false,
    error: false,
  };
});

const runtimeStatus = computed(() => {
  const state = sdk.connectionState.value;
  if (state === "ready" || state === "connected") {
    return { show: false, title: t("connection.stable"), detail: t("connection.ready"), tone: "success" as const, pulse: false };
  }
  if (state === "connecting") {
    return { show: true, title: t("connection.connecting"), detail: t("connection.syncMessagesDetail"), tone: "info" as const, pulse: true };
  }
  if (state === "reconnecting") {
    return { show: true, title: t("connection.reconnecting"), detail: t("connection.retryHint"), tone: "warning" as const, pulse: true };
  }
  return { show: false, title: t("connection.disconnected"), detail: t("connection.retryHint"), tone: "error" as const, pulse: false };
});

function resolvePeerUserId(): string {
  const item = sdk.activeConversation.value;
  if (!item || item.conversationType !== "single") return "";
  const peer = resolveConversationPeer(item, sdk.currentUserId.value || sdk.form.userId);
  return peer?.userId?.trim() || item.channelId?.trim() || "";
}

const composerMentionCandidates = computed<ComposerMentionCandidate[]>(() => {
  const item = sdk.activeConversation.value;
  if (!item) return [];
  const currentUserId = (sdk.currentUserId.value || sdk.form.userId).trim();
  const candidates = new Map<string, ComposerMentionCandidate>();
  const add = (userId?: string, label?: string): void => {
    const id = userId?.trim();
    if (!id || id === currentUserId || candidates.has(id)) return;
    const display = label?.trim() || id;
    candidates.set(id, { userId: id, label: display });
  };

  for (const participant of item.participants ?? []) add(participant.userId, participant.nickname);
  for (const participant of item.memberPreview ?? []) add(participant.userId, participant.nickname);
  if (item.conversationType === "single") add(resolvePeerUserId(), activeTitle.value);

  const channel = item.channelId?.trim() ?? "";
  if (channel.startsWith("users:")) {
    for (const userId of channel.slice("users:".length).split(/[,\s，、;；|]+/)) add(userId, userId);
  }

  return [...candidates.values()].slice(0, 64);
});

function mapPresenceStatus(raw: string): "online" | "offline" | "busy" {
  const normalized = raw.toLowerCase();
  if (normalized.includes("busy") || normalized.includes("dnd")) return "busy";
  if (normalized.includes("online")) return "online";
  return "offline";
}

const composerPlaceholder = computed(() => t("chat.composerPlaceholder", { name: activeTitle.value }));

const replyMessage = computed(() => findMessage(replyMessageId.value));
const editingMessage = computed(() => findMessage(editingMessageId.value));
const editingPreview = computed(() => (editingMessage.value ? getMessageText(editingMessage.value) : ""));

function clearScrollBottomRetry(): void {
  if (scrollBottomFrame !== undefined) {
    window.cancelAnimationFrame(scrollBottomFrame);
    scrollBottomFrame = undefined;
  }
  if (scrollBottomTimer !== undefined) {
    window.clearTimeout(scrollBottomTimer);
    scrollBottomTimer = undefined;
  }
}

async function scrollChatToBottomAfterRender(): Promise<void> {
  await nextTick();
  await messageListRef.value?.scrollToBottom();
  if (typeof window !== "undefined") {
    clearScrollBottomRetry();
    scrollBottomFrame = window.requestAnimationFrame(() => {
      scrollBottomFrame = undefined;
      void messageListRef.value?.scrollToBottom();
    });
    scrollBottomTimer = window.setTimeout(() => {
      scrollBottomTimer = undefined;
      void messageListRef.value?.scrollToBottom();
    }, 320);
  }
}

function handleTimelineAtBottomChange(atBottom: boolean): void {
  sdk.setActiveTimelineAtBottom(atBottom);
}

watch(
  () => sdk.activeConversationId.value,
  async (conversationId, previousConversationId) => {
    if (previousConversationId) {
      await flushComposerDraftNow(previousConversationId, editingMessageId.value ? "" : composerText.value);
    } else {
      draftScheduler.cancel();
    }
    if (!conversationId) {
      setComposerTextSilently("");
      replyMessageId.value = "";
      editingMessageId.value = "";
      composerPanel.value = null;
      peerPresenceStatus.value = "offline";
      chatContentTab.value = "messages";
      exitMultiSelect();
      return;
    }
    const draft =
      sdk.conversations.value.find((item) => item.conversationId === conversationId)?.draft ?? "";
    setComposerTextSilently(draft);
    replyMessageId.value = "";
    editingMessageId.value = "";
    composerPanel.value = null;
    chatContentTab.value = "messages";
    exitMultiSelect();
    const peerUserId = resolvePeerUserId();
    if (peerUserId) {
      peerPresenceStatus.value = mapPresenceStatus(await sdk.refreshActivePeerPresence(peerUserId));
    } else {
      peerPresenceStatus.value = "offline";
    }
    await sdk.enterActiveConversation("chat_enter");
    await scrollChatToBottomAfterRender();
  },
  { immediate: true },
);

watch(pinnedCount, (count) => {
  if (count === 0 && chatContentTab.value === "pin") {
    chatContentTab.value = "messages";
  }
});

watch(
  () =>
    sdk.messages.value
      .map((row) => [
        row.timelineKey,
        row.serverId,
        row.clientMsgId,
        row.content?.contentType,
      ].join(":"))
      .join("|"),
  () => {
    void refreshVisibleMediaDownloadStates();
  },
  { flush: "post" },
);

watch(
  () => sdk.peerPresence.value,
  (presence) => {
    const peerUserId = resolvePeerUserId();
    if (!peerUserId) return;
    const status = presence[peerUserId];
    if (status) {
      peerPresenceStatus.value = mapPresenceStatus(status);
    }
  },
  { deep: true },
);

watch(composerText, (draft) => {
  if (skipNextComposerTextWatch) {
    skipNextComposerTextWatch = false;
    return;
  }
  composerUserEditVersion += 1;
  if (editingMessageId.value) return;
  scheduleComposerDraft(draft);
  if (!isConnected.value) return;
  if (typingTimer !== undefined) {
    window.clearTimeout(typingTimer);
    typingTimer = undefined;
  }
  void sdk.sendTyping(true);
  typingTimer = window.setTimeout(() => {
    typingTimer = undefined;
    void sdk.sendTyping(false);
  }, 1200);
});

function findMessage(id: string) {
  if (!id) return null;
  return sdk.messages.value.find((m) => m.serverId === id || m.clientMsgId === id) ?? null;
}

async function scrollLoadedMessageIntoView(messageId: string, smooth = true): Promise<boolean> {
  await nextTick();
  return (await messageListRef.value?.scrollToMessage(messageId, smooth)) ?? false;
}

async function ensureMessageLocated(messageId: string): Promise<boolean> {
  const targetId = messageId.trim();
  if (!targetId || !sdk.activeConversationId.value) return false;
  chatContentTab.value = "messages";
  await nextTick();
  if (await scrollLoadedMessageIntoView(targetId, true)) return true;

  for (let attempt = 0; attempt < MESSAGE_LOCATE_MAX_OLDER_LOADS; attempt += 1) {
    if (!sdk.messageHasMore.value) break;
    try {
      await sdk.loadOlderMessages();
    } catch (error) {
      const detail = error instanceof Error ? error.message : String(error);
      message.error(detail || "加载历史消息失败");
      return false;
    }
    await nextTick();
    if (findMessage(targetId) && await scrollLoadedMessageIntoView(targetId, true)) {
      return true;
    }
  }

  return scrollLoadedMessageIntoView(targetId, true);
}

async function locateMessage(messageId: string): Promise<void> {
  const found = await ensureMessageLocated(messageId);
  if (!found) {
    message.warning(t("chat.messageLocateFailed"));
  }
}

function messageId(message: MessageIdentity): string {
  return message.clientMsgId || message.serverId;
}

function quotedMessageContent(message: MessageIdentity): MessageContent {
  if (message.content) {
    return {
      contentType: message.content.contentType,
      data: message.content.data,
    };
  }
  return {
    contentType: MessageContentType.Text,
    data: {
      text: getMessageText(message),
      mentions: [],
    },
  };
}

function back(): void {
  if (multiSelectMode.value) {
    exitMultiSelect();
    return;
  }
  void router.push({ name: "conversations" });
}

function setComposerTextSilently(value: string): void {
  if (composerText.value === value) return;
  skipNextComposerTextWatch = true;
  composerText.value = value;
}

function cancelPendingDraftClear(conversationId: string): void {
  const timer = draftClearTimers.get(conversationId);
  if (timer === undefined) return;
  window.clearTimeout(timer);
  draftClearTimers.delete(conversationId);
}

function cancelAllPendingDraftClears(): void {
  for (const timer of draftClearTimers.values()) {
    window.clearTimeout(timer);
  }
  draftClearTimers.clear();
}

function scheduleComposerDraft(draft: string): void {
  const conversationId = sdk.activeConversationId.value;
  if (conversationId && draft.trim()) {
    cancelPendingDraftClear(conversationId);
  }
  draftScheduler.schedule({
    conversationId,
    draft,
  });
}

async function flushComposerDraftNow(
  conversationId = sdk.activeConversationId.value,
  draft = composerText.value,
): Promise<void> {
  if (conversationId && draft.trim()) {
    cancelPendingDraftClear(conversationId);
  }
  await draftScheduler.flush({ conversationId, draft });
}

function clearComposerDraft(conversationId = sdk.activeConversationId.value): void {
  draftScheduler.cancel();
  if (!conversationId) return;
  cancelPendingDraftClear(conversationId);
  const timer = window.setTimeout(() => {
    draftClearTimers.delete(conversationId);
    void sdk.clearConversationDraft(conversationId, "");
  }, DRAFT_CLEAR_DELAY_MS);
  draftClearTimers.set(conversationId, timer);
}

function prepareComposerSend(): void {
  draftScheduler.cancel();
  const conversationId = sdk.activeConversationId.value;
  if (conversationId) cancelPendingDraftClear(conversationId);
}

function composerSendTimeoutError(): Error {
  const error = new Error("发送超时，请检查网络后重试");
  (error as Error & { code?: string; operation?: string; details?: Record<string, string> }).code = "timeout";
  (error as Error & { code?: string; operation?: string; details?: Record<string, string> }).operation = "composer.send";
  (error as Error & { code?: string; operation?: string; details?: Record<string, string> }).details = {
    timeoutMs: String(COMPOSER_SEND_TIMEOUT_MS),
  };
  return error;
}

async function withComposerSendDeadline<T>(task: Promise<T>): Promise<T> {
  return await withTimeout(task, COMPOSER_SEND_TIMEOUT_MS, composerSendTimeoutError);
}

function titleFromRichMarkdown(markdown: string): string {
  const firstLine = markdownToPlainText(markdown)
    .split(/\r?\n/)
    .map((line) => line.trim())
    .find(Boolean) ?? "";
  return (firstLine || "富文本").slice(0, 48);
}

function buildRichTextPayload(markdown: string): ComposerPayloadRequest {
  const action = resolveComposerAction("create_rich_doc");
  if (!action) throw new Error("富文本构建器不可用");
  return action.buildRequest({
    markdown,
    title: titleFromRichMarkdown(markdown),
  });
}

function textLooksLikeRichMarkdown(text: string): boolean {
  return isMarkdown(text);
}

async function sendText(): Promise<void> {
  const text = composerText.value.trim();
  if (!text) {
    message.warning("请输入要发送的内容");
    return;
  }
  if (!sdk.activeConversationId.value) {
    message.warning("请先选择会话");
    return;
  }
  if (sending.value) return;

  prepareComposerSend();
  sending.value = true;
  const composerVersionAtSubmit = composerUserEditVersion;
  try {
    setComposerTextSilently("");
    clearComposerDraft();
    let task: Promise<void>;
    if (editingMessageId.value) {
      task = sdk.editMessageText(editingMessageId.value, text);
    } else if (replyMessage.value) {
      task = sdk.buildAndSendMessage("create_quote", {
        text,
        quotedMessageId: messageId(replyMessage.value),
        quotedTextPreview: getMessageText(replyMessage.value),
        quotedContent: quotedMessageContent(replyMessage.value),
      });
    } else if (composerRichMode.value || textLooksLikeRichMarkdown(text)) {
      task = operations.sendComposerPayload(buildRichTextPayload(text));
    } else {
      const loneEmojiKey = resolveLoneEmojiPackKey(text);
      if (loneEmojiKey) {
        task = sdk.sendEmoji(loneEmojiKey);
      } else {
        task = sdk.sendText(text);
      }
    }
    await withComposerSendDeadline(task);
    editingMessageId.value = "";
    replyMessageId.value = "";
    if (composerUserEditVersion === composerVersionAtSubmit && !composerText.value.trim()) {
      setComposerTextSilently("");
      clearComposerDraft();
    }
    composerPanel.value = null;
    await nextTick();
    await messageListRef.value?.scrollToBottom();
  } catch (error) {
    const detail = error instanceof Error ? error.message : String(error);
    message.error(detail || "发送失败");
    if (!composerText.value.trim()) {
      setComposerTextSilently(text);
      void flushComposerDraftNow(sdk.activeConversationId.value, text);
    }
  } finally {
    sending.value = false;
  }
}

async function reactMessage(id: string, emoji: string): Promise<void> {
  try {
    await operations.toggleReaction(id, emoji);
  } catch (error) {
    const detail = error instanceof Error ? error.message : String(error);
    message.error(detail || "表情回应失败");
  }
}

function forwardOne(id: string): void {
  selectedMessageIds.value = [id];
  interactions.openForward("separate", [id]);
}

async function recallMessage(id: string): Promise<void> {
  try {
    await sdk.recallMessageById(id);
    if (editingMessageId.value === id) cancelEditingMessage();
  } catch (error) {
    const detail = error instanceof Error ? error.message : String(error);
    message.error(detail || "撤回失败");
  }
}

function editMessage(id: string): void {
  const target = findMessage(id);
  if (!target) {
    message.warning("未找到要编辑的消息");
    return;
  }
  const text = getMessageText(target).trim();
  if (!text) {
    message.warning("这条消息暂无可编辑文本");
    return;
  }
  editingMessageId.value = id;
  replyMessageId.value = "";
  composerPanel.value = null;
  setComposerTextSilently(text);
}

function cancelEditingMessage(): void {
  editingMessageId.value = "";
  setComposerTextSilently("");
}

async function markMessage(id: string): Promise<void> {
  sdk.sdkLab.messageId = id;
  await sdk.runDispatch("mark_by_message_id");
  await sdk.refreshActiveChat();
}

async function deleteMessage(id: string): Promise<void> {
  const result = await operations.deleteMessagesForSelf([id]);
  showBatchResult("删除", result);
}

async function pinMessage(id: string, pinned: boolean, scope: MessagePinScope = "conversation"): Promise<void> {
  const result = await operations.setMessagesPinned([id], pinned, scope);
  showBatchResult(pinned ? "置顶" : "取消置顶", result);
}

function startReply(id: string): void {
  editingMessageId.value = "";
  replyMessageId.value = id;
  composerPanel.value = null;
}

function startMultiSelect(id: string): void {
  cancelEditingMessage();
  replyMessageId.value = "";
  composerPanel.value = null;
  chatContentTab.value = "messages";
  interactions.enterMultiSelect(id);
}

function toggleSelected(id: string): void {
  interactions.toggleSelected(id);
}

function exitMultiSelect(): void {
  interactions.exitMultiSelect();
}

function forwardSelected(merge: boolean): void {
  if (!selectedMessageIds.value.length) return;
  interactions.openForward(merge ? "merged" : "separate");
}

async function deleteSelectedForSelf(): Promise<void> {
  const result = await operations.deleteMessagesForSelf(selectedMessageIds.value);
  showBatchResult("删除", result);
  if (!result.failed.length) exitMultiSelect();
}

async function pinSelected(): Promise<void> {
  const result = await operations.setMessagesPinned(selectedMessageIds.value, true, "conversation");
  showBatchResult("置顶", result);
  if (!result.failed.length) exitMultiSelect();
}

async function pinSelectedForSelf(): Promise<void> {
  const result = await operations.setMessagesPinned(selectedMessageIds.value, true, "self");
  showBatchResult("仅自己置顶", result);
  if (!result.failed.length) exitMultiSelect();
}

function showBatchResult(action: string, result: BatchOperationResult): void {
  if (result.failed.length) {
    message.error(`${action}完成 ${result.succeeded.length}/${result.total}，失败 ${result.failed.length} 项：${result.failed[0]?.reason ?? ""}`);
    return;
  }
  message.success(`${action}成功 ${result.succeeded.length}/${result.total}`);
}

function openPreview(id: string): void {
  workbenchUi.openPreview(id);
}

function mediaMessageId(row: Message): string {
  return row.clientMsgId || row.serverId;
}

function findMessageByActionId(id: string): Message | undefined {
  return sdk.messages.value.find((row) => mediaMessageId(row as unknown as Message) === id) as Message | undefined;
}

function firstMediaDownloadSource(row: unknown): MessageMediaDownloadSource | null {
  const sources = listMessageMediaDownloadSources(row as Parameters<typeof listMessageMediaDownloadSources>[0]);
  return sources[0] ?? null;
}

function savedPathFromResponse(response: unknown): string {
  if (typeof response === "string") return response.trim();
  if (!response || typeof response !== "object") return "";
  const record = response as Record<string, unknown>;
  const value = record.path ?? record.savedPath ?? record.localPath;
  return typeof value === "string" ? value.trim() : "";
}

function mediaDownloadRequest(source: MessageMediaDownloadSource): Record<string, unknown> {
  return {
    downloadKey: source.downloadKey,
    displayFileName: source.displayFileName,
    ...(source.sourcePath ? { sourcePath: source.sourcePath } : {}),
    ...(!source.remoteFileId && source.sourceHttpUrl ? { sourceHttpUrl: source.sourceHttpUrl } : {}),
    ...(source.remoteFileId ? { remoteFileId: source.remoteFileId } : {}),
    ...(source.mimeType ? { mimeType: source.mimeType } : {}),
  };
}

function isNativeDownloadUnsupported(error: unknown): boolean {
  const record = error && typeof error === "object" ? (error as Record<string, unknown>) : {};
  const code = String(record.code ?? "");
  const operation = String(record.operation ?? "");
  const detail = error instanceof Error ? error.message : String(error ?? "");
  return (
    code === "operation.not_supported" ||
    operation.includes("media.download_file_to_downloads") ||
    detail.includes("operation.not_supported") ||
    detail.includes("Native media cache is disabled")
  );
}

async function resolveBrowserDownloadUrl(source: MessageMediaDownloadSource): Promise<string> {
  if (source.remoteFileId) {
    try {
      const url = await sdk.client.media.resolveDisplayUrl({
        fileId: source.remoteFileId,
        mediaUrl: source.sourceHttpUrl ?? "",
      });
      return proxiedMediaUrl(url);
    } catch {
      // Fall through to explicit browser/source URLs when the runtime cannot resolve media access.
    }
  }
  if (source.browserUrl) return proxiedMediaUrl(source.browserUrl);
  if (source.sourceHttpUrl) return proxiedMediaUrl(source.sourceHttpUrl);
  return "";
}

function setMediaDownloadState(source: MessageMediaDownloadSource, state: MediaDownloadState): void {
  mediaDownloadStates.value = {
    ...mediaDownloadStates.value,
    [source.downloadKey]: state,
  };
}

async function downloadMediaSource(source: MessageMediaDownloadSource): Promise<void> {
  setMediaDownloadState(source, "downloading");
  try {
    const response = await sdk.client.media.downloadFileToDownloads(mediaDownloadRequest(source));
    const savedPath = savedPathFromResponse(response);
    if (savedPath) {
      setMediaDownloadState(source, "downloaded");
      message.success("已下载");
      return;
    }
  } catch (error) {
    if (!isNativeDownloadUnsupported(error)) {
      setMediaDownloadState(source, "notDownloaded");
      throw error;
    }
  }

  const browserUrl = await resolveBrowserDownloadUrl(source);
  if (!browserUrl) {
    setMediaDownloadState(source, "notDownloaded");
    throw new Error("没有可下载地址");
  }
  try {
    await startBrowserDownload(browserUrl, source.displayFileName);
    setMediaDownloadState(source, "notDownloaded");
  } catch (error) {
    setMediaDownloadState(source, "notDownloaded");
    throw error;
  }
}

async function openDownloadedMediaFolder(source: MessageMediaDownloadSource): Promise<void> {
  try {
    const response = await sdk.client.media.getUserDownloadSavedPath({
      downloadKey: source.downloadKey,
      fileId: source.fileId,
    });
    const savedPath = savedPathFromResponse(response);
    if (!savedPath) {
      setMediaDownloadState(source, "notDownloaded");
      await downloadMediaSource(source);
      return;
    }
    const opened = await revealDownloadedMediaFile(savedPath);
    if (opened) {
      setMediaDownloadState(source, "downloaded");
      return;
    }
    await sdk.client.media.deleteUserDownloadRecord({
      downloadKey: source.downloadKey,
      fileId: source.fileId,
    });
    setMediaDownloadState(source, "notDownloaded");
    message.warning("本地文件不存在，请重新下载");
  } catch (error) {
    if (!isNativeDownloadUnsupported(error)) {
      throw error;
    }
    await downloadMediaSource(source);
  }
}

async function handleMediaAction(id: string, action: MediaDownloadAction): Promise<void> {
  const row = findMessageByActionId(id);
  if (!row) return;
  const sources = listMessageMediaDownloadSources(row as Parameters<typeof listMessageMediaDownloadSources>[0]);
  if (!sources.length) return;
  try {
    if (action === "openFolder") {
      await openDownloadedMediaFolder(sources[0]);
      return;
    }
    for (const source of sources) {
      await downloadMediaSource(source);
    }
  } catch (error) {
    const detail = error instanceof Error ? error.message : String(error);
    message.error(detail || "下载失败");
  }
}

async function refreshVisibleMediaDownloadStates(): Promise<void> {
  if (!canRevealDownloadedMedia() || mediaDownloadRefreshInFlight.value) return;
  const sourcesByKey = new Map<string, MessageMediaDownloadSource>();
  for (const row of sdk.messages.value) {
    for (const source of listMessageMediaDownloadSources(row as Parameters<typeof listMessageMediaDownloadSources>[0])) {
      sourcesByKey.set(source.downloadKey, source);
    }
  }
  if (!sourcesByKey.size) return;
  mediaDownloadRefreshInFlight.value = true;
  try {
    const next = { ...mediaDownloadStates.value };
    for (const source of sourcesByKey.values()) {
      if (next[source.downloadKey] === "downloaded") continue;
      try {
        const response = await sdk.client.media.getUserDownloadSavedPath({
          downloadKey: source.downloadKey,
          fileId: source.fileId,
        });
        next[source.downloadKey] = savedPathFromResponse(response)
          ? "downloaded"
          : "notDownloaded";
      } catch (error) {
        if (!isNativeDownloadUnsupported(error)) {
          next[source.downloadKey] = "notDownloaded";
        }
      }
    }
    mediaDownloadStates.value = next;
  } finally {
    mediaDownloadRefreshInFlight.value = false;
  }
}

function isMediaComposerAction(action: ComposerActionDefinition | undefined): action is ComposerActionDefinition {
  if (!action?.acceptsFiles) return false;
  return ["file", "image", "video", "audio", "imageGroup"].includes(action.kind);
}

function mediaAcceptForKind(kind: EnhancedMessageKind): string {
  if (kind === "image" || kind === "imageGroup") return "image/*";
  if (kind === "video") return "video/*";
  if (kind === "audio") return "audio/*";
  return "";
}

function mediaNameFromPath(path: string): string {
  const normalized = path.replace(/\\/g, "/");
  return normalized.split("/").filter(Boolean).pop() || path;
}

function revokeMediaPreviewUrls(): void {
  for (const item of mediaPreviewItems.value) {
    if (item.previewUrl?.startsWith("blob:") && typeof URL !== "undefined" && typeof URL.revokeObjectURL === "function") {
      URL.revokeObjectURL(item.previewUrl);
    }
  }
}

function setMediaPreviewItems(action: ComposerActionDefinition, items: MediaComposerPreviewItem[]): void {
  revokeMediaPreviewUrls();
  activeMediaAction.value = action;
  mediaPreviewItems.value = items;
  mediaPreviewOpen.value = items.length > 0;
}

function mediaActionForSelection(action: ComposerActionDefinition, count: number): ComposerActionDefinition {
  if (action.kind === "image" && count > 1) {
    return resolveComposerAction("create_image_group") ?? action;
  }
  return action;
}

function closeMediaPreview(): void {
  revokeMediaPreviewUrls();
  mediaPreviewItems.value = [];
  mediaPreviewOpen.value = false;
  activeMediaAction.value = null;
  if (mediaFileInput.value) mediaFileInput.value.value = "";
}

async function openMediaComposer(action: ComposerActionDefinition): Promise<void> {
  composerPanel.value = null;
  interactions.closeComposerAction();
  activeMediaAction.value = action;
  if (hasAppMediaPathPicker()) {
    const paths = await pickAppMediaSourcePaths({
      accept: mediaAcceptForKind(action.kind),
      multiple: action.kind === "image" || Boolean(action.multipleFiles),
      kind: action.kind,
    });
    if (!paths.length) {
      activeMediaAction.value = null;
      return;
    }
    const previewAction = mediaActionForSelection(action, paths.length);
    setMediaPreviewItems(previewAction, paths.map((path, index) => ({
      id: `${previewAction.kind}:path:${index}:${path}`,
      kind: previewAction.kind,
      name: mediaNameFromPath(path),
      sourcePath: path,
      previewUrl: previewAction.kind === "file" ? "" : resolveAppMediaLocalPath(path),
    })));
    return;
  }

  await nextTick();
  mediaFileInput.value?.click();
}

function handleMediaFileInputChange(event: Event): void {
  const action = activeMediaAction.value;
  const input = event.target as HTMLInputElement;
  if (!action) return;
  const selected = [...(input.files ?? [])];
  const files = action.kind === "image" || action.multipleFiles ? selected : selected.slice(0, 1);
  if (!files.length) return;
  const previewAction = mediaActionForSelection(action, files.length);
  setMediaPreviewItems(previewAction, files.map((file, index) => ({
    id: `${previewAction.kind}:file:${index}:${file.name}:${file.size}:${file.lastModified}`,
    kind: previewAction.kind,
    name: file.name,
    file,
    mimeType: file.type || "application/octet-stream",
    size: file.size,
    previewUrl: typeof URL !== "undefined" && typeof URL.createObjectURL === "function"
      ? URL.createObjectURL(file)
      : "",
  })));
}

async function fileToCoreDataUrl(file: File): Promise<string> {
  const raw = await new Promise<string>((resolve, reject) => {
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result ?? ""));
    reader.onerror = () => reject(reader.error ?? new Error("file read failed"));
    reader.readAsDataURL(file);
  });
  const comma = raw.indexOf(",");
  const body = comma >= 0 ? raw.slice(comma + 1) : raw;
  const mimeType = file.type || "application/octet-stream";
  return `data:${mimeType};name=${encodeURIComponent(file.name)};size=${file.size};base64,${body}`;
}

async function mediaItemSource(item: MediaComposerPreviewItem): Promise<{
  sourcePath: string;
  fileName: string;
  mimeType: string;
  fileSize: number;
}> {
  if (item.sourcePath) {
    return {
      sourcePath: item.sourcePath,
      fileName: item.name,
      mimeType: item.mimeType ?? "",
      fileSize: item.size ?? 0,
    };
  }
  if (!item.file) throw new Error("missing selected media file");
  return {
    sourcePath: await fileToCoreDataUrl(item.file),
    fileName: item.name,
    mimeType: item.mimeType ?? item.file.type ?? "application/octet-stream",
    fileSize: item.size ?? item.file.size,
  };
}

async function sendMediaPreview(description: string): Promise<void> {
  const action = activeMediaAction.value;
  if (!action || sending.value) return;
  const items = [...mediaPreviewItems.value];
  if (!items.length) return;
  const sources = await Promise.all(items.map(mediaItemSource));
  const first = sources[0];
  if (!first) return;
  const params: Record<string, unknown> = {
    description,
    sourcePath: first.sourcePath,
    fileName: first.fileName,
    mimeType: first.mimeType,
    fileSize: first.fileSize,
    size: first.fileSize,
  };
  if (action.kind === "image") params.imageId = first.sourcePath;
  if (action.kind === "video") params.videoId = first.sourcePath;
  if (action.kind === "audio") params.audioId = first.sourcePath;
  if (action.kind === "file") params.fileId = first.sourcePath;
  if (action.kind === "imageGroup") {
    params.imageSources = sources.map((source) => ({
      imageId: source.sourcePath,
      fileName: source.fileName,
      mimeType: source.mimeType,
      size: source.fileSize,
    }));
  }
  closeMediaPreview();
  await sendComposerPayload(action.buildRequest(params, []), { rethrow: true });
}

async function buildFromAction(op: string): Promise<void> {
  if (!sdk.activeConversationId.value) {
    message.warning("请先选择会话");
    return;
  }
  const action = resolveComposerAction(op);
  if (action?.kind === "richText") {
    composerRichMode.value = true;
    composerPanel.value = null;
    await nextTick();
    return;
  }
  if (isMediaComposerAction(action)) {
    await openMediaComposer(action);
    return;
  }
  if (action) {
    interactions.openComposerAction(op);
    return;
  }
  if (sending.value) return;
  prepareComposerSend();
  sending.value = true;
  try {
    await withComposerSendDeadline(sdk.buildFromComposerAction(op, composerText.value));
    setComposerTextSilently("");
    clearComposerDraft();
    composerPanel.value = null;
    await messageListRef.value?.scrollToBottom();
  } catch (error) {
    const detail = error instanceof Error ? error.message : String(error);
    message.error(detail || "发送失败");
  } finally {
    sending.value = false;
  }
}

async function sendComposerPayload(
  payload: ComposerPayloadRequest,
  options: { rethrow?: boolean } = {},
): Promise<void> {
  if (sending.value) return;
  prepareComposerSend();
  sending.value = true;
  try {
    await withComposerSendDeadline(operations.sendComposerPayload(payload));
    composerActionOpen.value = false;
    activeComposerOp.value = "";
    setComposerTextSilently("");
    clearComposerDraft();
    composerPanel.value = null;
    await messageListRef.value?.scrollToBottom();
    message.success(`${payload.previewText} 已发送`);
  } catch (error) {
    const detail = error instanceof Error ? error.message : String(error);
    message.error(detail || "发送失败");
    if (options.rethrow) throw error;
  } finally {
    sending.value = false;
  }
}

async function confirmForward(payload: { targetConversationId: string; title: string }): Promise<void> {
  const mode: ForwardMode = forwardMode.value;
  const result = await operations.forwardMessages({
    mode,
    targetConversationId: payload.targetConversationId,
    title: payload.title,
    messageIds: selectedMessageIds.value,
  });
  showBatchResult(mode === "merged" ? "合并转发" : "逐条转发", result);
  if (!result.failed.length) {
    interactions.closeForward();
    exitMultiSelect();
  }
}

async function resendMessage(clientMsgId: string): Promise<void> {
  if (!clientMsgId || sending.value) return;
  sending.value = true;
  try {
    await withComposerSendDeadline(sdk.resendFailedMessage(clientMsgId));
    await messageListRef.value?.scrollToBottom();
  } catch (error) {
    const detail = error instanceof Error ? error.message : String(error);
    message.error(detail || "重发失败");
  } finally {
    sending.value = false;
  }
}

function insertEmojiPackKey(packKey: string): void {
  const token = formatEmojiPackToken(packKey);
  if (!token) return;
  if (composerRef.value?.insertAtCursor) {
    composerRef.value.insertAtCursor(token);
    return;
  }
  composerText.value = `${composerText.value}${token}`;
}

type ComposerStickerSendPick = {
  stickerId: string;
  packageId: string;
  url: string;
};

function onSendStickerFromPanel(payload: { picks: ComposerStickerSendPick[] }): void {
  const pick = payload.picks[0];
  if (!pick) return;
  void sendStickerItem(pick);
}

async function sendStickerItem(sticker: ComposerStickerSendPick): Promise<void> {
  if (!sdk.activeConversationId.value) {
    message.warning("请先选择会话");
    return;
  }
  try {
    await withComposerSendDeadline(sdk.sendSticker({
      stickerId: sticker.stickerId,
      packageId: sticker.packageId,
      url: sticker.url,
      stickerFormat: "webp",
    }));
    await messageListRef.value?.scrollToBottom();
  } catch (error) {
    const detail = error instanceof Error ? error.message : String(error);
    message.error(detail || "贴纸发送失败");
  }
}

function dismissMediaPanel(): void {
  if (composerPanel.value === "emoji" || composerPanel.value === "sticker") {
    composerPanel.value = null;
  }
}

function onChatEscape(event: KeyboardEvent): void {
  if (event.key !== "Escape") return;
  dismissMediaPanel();
}

function syncComposerOverlayHeight(): void {
  const composer = composerStackRef.value;
  if (!composer) return;
  const next = Math.ceil(composer.getBoundingClientRect().height);
  if (next <= 0 || next === composerOverlayHeight.value) return;
  composerOverlayHeight.value = next;
}

onMounted(() => {
  window.addEventListener("keydown", onChatEscape);
  window.addEventListener("resize", syncComposerOverlayHeight);
  void nextTick(syncComposerOverlayHeight);
  if (typeof ResizeObserver !== "undefined" && composerStackRef.value) {
    composerResizeObserver = new ResizeObserver(syncComposerOverlayHeight);
    composerResizeObserver.observe(composerStackRef.value);
  }
});

onBeforeUnmount(() => {
  window.removeEventListener("keydown", onChatEscape);
  window.removeEventListener("resize", syncComposerOverlayHeight);
  closeMediaPreview();
  clearScrollBottomRetry();
  if (typingTimer !== undefined) {
    window.clearTimeout(typingTimer);
    typingTimer = undefined;
  }
  composerResizeObserver?.disconnect();
  composerResizeObserver = null;
  operations.dispose();
  cancelAllPendingDraftClears();
  void draftScheduler.flush();
  draftScheduler.dispose();
});

onBeforeRouteLeave(async () => {
  await flushComposerDraftNow(sdk.activeConversationId.value, editingMessageId.value ? "" : composerText.value);
});

function toggleComposerPanel(panel: "emoji" | "sticker" | "more" | null): void {
  composerPanel.value = panel;
  void messageListRef.value?.scrollToBottom();
}

function setComposerMediaTab(tab: "emoji" | "sticker"): void {
  composerPanel.value = tab;
  void messageListRef.value?.scrollToBottom();
}

async function syncEmptyChat(): Promise<void> {
  try {
    await sdk.syncActiveConversation();
    await messageListRef.value?.scrollToBottom();
  } catch (error) {
    const detail = error instanceof Error ? error.message : String(error);
    message.error(detail || "同步失败");
  }
}

async function loadOlderMessages(): Promise<void> {
  try {
    await sdk.loadOlderMessages();
  } catch (error) {
    const detail = error instanceof Error ? error.message : String(error);
    message.error(detail || "加载历史消息失败");
  }
}

async function focusPinnedMessage(messageId: string): Promise<void> {
  await locateMessage(messageId);
}

</script>

<template>
  <section
    ref="chatRouteRef"
    class="flutter-page chat-route"
    :class="{ 'chat-route--selecting': multiSelectMode }"
    :style="chatRouteStyle"
  >
    <ChatConversationHeader class="flutter-chat-appbar">
      <template #identity>
        <n-button
          circle
          quaternary
          :aria-label="multiSelectMode ? '退出多选' : '返回会话列表'"
          :class="{ 'chat-nav-back': !multiSelectMode }"
          @click="back"
        >
          <template #icon><n-icon :component="multiSelectMode ? CloseOutline : ArrowBackOutline" /></template>
        </n-button>
        <div v-if="multiSelectMode" class="flutter-chat-title">
          {{ t("chat.multiSelect", { count: selectedMessageIds.length }) }}
        </div>
        <ChatConversationHeaderIdentity
          v-else
          :title="activeTitle"
          :subtitle="activeSubtitle"
          :avatar-user-id="sdk.activeConversation.value?.channelId || activeTitle"
          presence-on-avatar
          :presence-status="peerPresenceStatus"
        />
      </template>
      <template #actions>
        <template v-if="multiSelectMode">
          <n-button circle quaternary :disabled="operationBusy || allSelected" title="全选" @click="interactions.selectAll">
            <template #icon><n-icon :component="LibraryOutline" /></template>
          </n-button>
          <n-button circle quaternary :disabled="!selectedMessageIds.length" @click="forwardSelected(false)">
            <template #icon><n-icon :component="ShareSocialOutline" /></template>
          </n-button>
          <n-button circle quaternary :disabled="selectedMessageIds.length < 2" @click="forwardSelected(true)">
            <template #icon><n-icon :component="LibraryOutline" /></template>
          </n-button>
          <n-button circle quaternary :disabled="!selectedMessageIds.length" @click="pinSelected">
            <template #icon><n-icon :component="PinOutline" /></template>
          </n-button>
          <n-button circle quaternary :disabled="!selectedMessageIds.length" title="仅自己置顶" @click="pinSelectedForSelf">
            <template #icon><n-icon :component="PinOutline" /></template>
          </n-button>
          <n-button circle quaternary :disabled="!selectedMessageIds.length" @click="deleteSelectedForSelf">
            <template #icon><n-icon :component="TrashOutline" /></template>
          </n-button>
        </template>
        <template v-else>
          <n-button circle quaternary title="语音信令" @click="sdk.runCapabilityOperation('call_signal')">
            <template #icon><n-icon :component="CallOutline" /></template>
          </n-button>
          <n-button circle quaternary title="视频信令" @click="sdk.runCapabilityOperation('call_signal')">
            <template #icon><n-icon :component="VideocamOutline" /></template>
          </n-button>
          <n-button circle quaternary title="搜索消息" @click="workbenchUi.openChatSearch()">
            <template #icon><n-icon :component="SearchOutline" /></template>
          </n-button>
          <n-button circle quaternary title="SDK 消息类型" @click="workbenchUi.openSdkBuild()">
            <template #icon><n-icon :component="LibraryOutline" /></template>
          </n-button>
          <n-button circle quaternary title="更多" @click="workbenchUi.openMore()">
            <template #icon><n-icon :component="EllipsisHorizontalOutline" /></template>
          </n-button>
        </template>
      </template>
    </ChatConversationHeader>

    <section
      v-if="runtimeStatus.show"
      class="chat-connection-banner"
      :class="`chat-connection-banner--${runtimeStatus.tone}`"
      role="status"
    >
      <span
        class="chat-connection-banner__dot"
        :class="{ 'chat-connection-banner__dot--pulse': runtimeStatus.pulse }"
      />
      <span>{{ runtimeStatus.title }} · {{ runtimeStatus.detail }}</span>
    </section>

    <section v-if="sdk.messageSyncError.value && sdk.messages.value.length" class="chat-message-sync-banner" role="alert">
      <strong>{{ t("chat.messageSyncFailed") }}</strong>
      <span>{{ sdk.messageSyncError.value }}</span>
      <button type="button" class="chat-message-sync-banner__retry" @click="syncEmptyChat">
        {{ t("chat.syncRetry") }}
      </button>
    </section>

    <nav
      v-if="showContentTabs"
      class="chat-content-tabs"
      :aria-label="t('chat.contentTabsAria')"
    >
      <button
        type="button"
        class="chat-content-tab"
        :class="{ 'chat-content-tab--active': chatContentTab === 'messages' }"
        @click="chatContentTab = 'messages'"
      >
        <n-icon :component="ChatbubbleEllipsesOutline" />
        <span>{{ t("chat.messagesTab") }}</span>
      </button>
      <button
        type="button"
        class="chat-content-tab"
        :class="{ 'chat-content-tab--active': chatContentTab === 'pin' }"
        @click="chatContentTab = 'pin'"
      >
        <n-icon :component="PinOutline" />
        <span>{{ t("chat.pinTab") }}</span>
        <small v-if="pinnedCount">{{ pinnedCount }}</small>
      </button>
    </nav>

    <div class="chat-message-stage" :class="{ 'chat-message-stage--panel': showingPinnedTab }">
      <PinnedMessageBar
        v-if="showingPinnedTab"
        :items="sdk.pinnedMessages.value"
        @focus="focusPinnedMessage"
      />
      <template v-else>
        <section
          v-if="!sdk.messages.value.length"
          class="flutter-empty chat-empty"
          :class="{
            'chat-empty--error': chatEmptyState.error,
            'chat-empty--loading': chatEmptyState.loading,
            'chat-empty--clickable': !chatEmptyState.loading,
          }"
          :role="chatEmptyState.loading ? 'status' : 'button'"
          :tabindex="chatEmptyState.loading ? undefined : 0"
          @click="!chatEmptyState.loading ? syncEmptyChat() : undefined"
          @keydown.enter="!chatEmptyState.loading ? syncEmptyChat() : undefined"
        >
          <span v-if="chatEmptyState.loading" class="chat-empty__spinner" aria-hidden="true" />
          <n-icon v-else :component="ChatbubbleEllipsesOutline" :size="56" />
          <strong>{{ chatEmptyState.title }}</strong>
          <span>{{ chatEmptyState.detail }}</span>
        </section>
        <MessageList
          v-else
          ref="messageListRef"
          :conversation-id="sdk.activeConversationId.value"
          :conversation-type="sdk.activeConversation.value?.conversationType"
          :messages="sdk.messages.value"
          :current-user-id="sdk.currentUserId.value || sdk.form.userId"
          :multi-select-mode="multiSelectMode"
          :selected-ids="selectedMessageIds"
          :loading-older="sdk.loadingOlderMessages.value"
          :has-older="sdk.messageHasMore.value"
          :bottom-inset="messageListBottomInset"
          :menu-config="messageMenuConfig"
          :media-download-states="messageMediaDownloadUiStates"
          @react="reactMessage"
          @edit="editMessage"
          @delete="deleteMessage"
          @pin="pinMessage"
          @mark="markMessage"
          @preview="openPreview"
          @media-action="handleMediaAction"
          @reply="startReply"
          @forward="forwardOne"
          @recall="recallMessage"
          @resend="resendMessage"
          @multi-select="startMultiSelect"
          @toggle-select="toggleSelected"
          @locate-message="locateMessage"
          @at-bottom-change="handleTimelineAtBottomChange"
          @load-older="loadOlderMessages"
        />
      </template>
      <MessageBatchToolbar
        v-if="multiSelectMode"
        :count="selectedMessageIds.length"
        :total="selectableMessageIds.length"
        :busy="operationBusy"
        @select-all="interactions.selectAll"
        @clear="interactions.clearSelection"
        @forward-separate="forwardSelected(false)"
        @forward-merged="forwardSelected(true)"
        @pin="pinSelected"
        @pin-self="pinSelectedForSelf"
        @delete="deleteSelectedForSelf"
        @exit="exitMultiSelect"
      />
      <button
        v-if="mediaPanelOpen"
        type="button"
        class="chat-media-dismiss"
        aria-label="关闭表情与贴纸面板"
        @click="dismissMediaPanel"
      />
    </div>

    <footer
      v-if="!multiSelectMode && chatContentTab === 'messages'"
      ref="composerStackRef"
      class="chat-composer-stack"
      :class="{ 'chat-composer-stack--media': mediaPanelOpen }"
      @mousedown.stop
      @click.stop
    >
      <ComposerEmojiStickerPanel
        v-if="mediaPanelOpen"
        :active-tab="composerMediaTab"
        :can-send="canSendText"
        :sending="sending"
        @insert-emoji="insertEmojiPackKey"
        @send-sticker="onSendStickerFromPanel"
        @send-text="sendText"
        @update:active-tab="setComposerMediaTab"
      />
      <EnhancedComposer
        ref="composerRef"
        v-model="composerText"
        :sending="sending"
        :disabled="composerDisabled"
        :status-hint="composerStatusHint"
        :status-hint-pulse="composerStatusPulse"
        :placeholder="composerPlaceholder"
        :target-name="activeTitle"
        :mention-candidates="composerMentionCandidates"
        :active-panel="composerPanel"
        :rich-mode="composerRichMode"
        :media-panel-open="mediaPanelOpen"
        :reply-sender="replyMessage?.senderDisplayName"
        :reply-preview="replyMessage ? getMessageText(replyMessage) : ''"
        :editing="Boolean(editingMessageId)"
        :edit-preview="editingPreview"
        @toggle-panel="toggleComposerPanel"
        @toggle-rich-mode="composerRichMode = $event"
        @clear-reply="replyMessageId = ''"
        @clear-edit="cancelEditingMessage"
        @build="buildFromAction"
        @send="sendText"
      />
      <input
        ref="mediaFileInput"
        class="chat-media-file-input"
        type="file"
        :accept="mediaFileAccept"
        :multiple="activeMediaAction?.kind === 'image' || Boolean(activeMediaAction?.multipleFiles)"
        @change="handleMediaFileInputChange"
      />
    </footer>

    <ForwardModal
      v-model:show="forwardOpen"
      :mode="forwardMode"
      :conversations="forwardConversationSource"
      :messages="selectedMessages"
      :active-conversation-id="sdk.activeConversationId.value"
      :loading="operationBusy"
      @confirm="confirmForward"
    />

    <ComposerPayloadModal
      v-model:show="payloadComposerOpen"
      :op="activeComposerOp"
      :loading="sending"
      @submit="sendComposerPayload"
    />

    <MediaComposerPreviewModal
      v-model:show="mediaPreviewOpen"
      :kind="activeMediaAction?.kind ?? 'image'"
      :items="mediaPreviewItems"
      :loading="sending"
      @cancel="closeMediaPreview"
      @submit="sendMediaPreview"
    />
  </section>
</template>
