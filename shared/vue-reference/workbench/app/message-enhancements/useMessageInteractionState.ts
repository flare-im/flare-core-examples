import { computed, ref, watch, type Ref } from "vue";
import type { Message } from "@flare-im/sdk/web";
import type { EnhancedMessageKind, ForwardMode } from "./types";
import { messageHasId, messageStableId } from "./types";

export function useMessageInteractionState(messages: Readonly<Ref<readonly Message[]>>) {
  const multiSelectMode = ref(false);
  const selectedMessageIds = ref<string[]>([]);
  const forwardOpen = ref(false);
  const forwardMode = ref<ForwardMode>("separate");
  const composerActionOpen = ref(false);
  const activeComposerOp = ref("");
  const previewMessageId = ref("");

  const selectedMessages = computed(() => {
    const selected = selectedMessageIds.value;
    // 按两个 id 都比：选中 id 的来路不一定和 messageStableId 同序，见 messageHasId。
    return messages.value.filter((message) => selected.some((id) => messageHasId(message, id)));
  });

  const selectableMessageIds = computed(() =>
    messages.value
      .filter((message) => !message.isRecalled && messageStableId(message))
      .map(messageStableId),
  );

  const allSelected = computed(() =>
    selectableMessageIds.value.length > 0
    && selectableMessageIds.value.every((id) => selectedMessageIds.value.includes(id)),
  );

  function enterMultiSelect(id?: string): void {
    multiSelectMode.value = true;
    selectedMessageIds.value = id ? [id] : [];
  }

  function exitMultiSelect(): void {
    multiSelectMode.value = false;
    selectedMessageIds.value = [];
  }

  function toggleSelected(id: string): void {
    if (!id) return;
    if (!multiSelectMode.value) enterMultiSelect(id);
    selectedMessageIds.value = selectedMessageIds.value.includes(id)
      ? selectedMessageIds.value.filter((item) => item !== id)
      : [...selectedMessageIds.value, id];
    if (!selectedMessageIds.value.length) {
      multiSelectMode.value = false;
    }
  }

  function selectAll(): void {
    multiSelectMode.value = true;
    selectedMessageIds.value = [...selectableMessageIds.value];
  }

  function clearSelection(): void {
    selectedMessageIds.value = [];
  }

  function openForward(mode: ForwardMode, ids = selectedMessageIds.value): void {
    selectedMessageIds.value = [...ids].filter(Boolean);
    if (!selectedMessageIds.value.length) return;
    forwardMode.value = mode;
    forwardOpen.value = true;
  }

  function closeForward(): void {
    forwardOpen.value = false;
  }

  function openComposerAction(op: string): void {
    activeComposerOp.value = op;
    composerActionOpen.value = true;
  }

  function closeComposerAction(): void {
    composerActionOpen.value = false;
    activeComposerOp.value = "";
  }

  function openPreview(messageId: string): void {
    previewMessageId.value = messageId;
  }

  watch(
    () => messages.value.map(messageStableId).join("\u0000"),
    () => {
      if (!selectedMessageIds.value.length) return;
      const existing = new Set(selectableMessageIds.value);
      selectedMessageIds.value = selectedMessageIds.value.filter((id) => existing.has(id));
      if (!selectedMessageIds.value.length) {
        multiSelectMode.value = false;
      }
    },
  );

  return {
    multiSelectMode,
    selectedMessageIds,
    selectedMessages,
    selectableMessageIds,
    allSelected,
    forwardOpen,
    forwardMode,
    composerActionOpen,
    activeComposerOp,
    previewMessageId,
    enterMultiSelect,
    exitMultiSelect,
    toggleSelected,
    selectAll,
    clearSelection,
    openForward,
    closeForward,
    openComposerAction,
    closeComposerAction,
    openPreview,
  };
}

export function composerKindForOp(op: string): EnhancedMessageKind | "" {
  if (op === "create_link_card") return "linkCard";
  if (op === "create_rich_doc") return "richText";
  if (op === "create_image_group") return "imageGroup";
  if (op === "create_mini_program") return "miniProgram";
  if (op === "create_thread_reply") return "thread";
  const trimmed = op.replace(/^create_/, "");
  if (["file", "image", "video", "audio", "location", "card", "schedule", "task", "vote", "notification", "announcement"].includes(trimmed)) {
    return trimmed as EnhancedMessageKind;
  }
  return "";
}
