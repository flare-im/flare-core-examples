<script setup lang="ts">
import { computed, ref, watch } from "vue";
import { FlareInput, FlareFormField, FlareFormSheet, FlareForwardPicker } from "@flare-im/vue-ui/components";
import type { Conversation, Message } from "@flare-im/sdk/web";
import type { ForwardMode } from "../types";
import { messageStableId } from "../types";
import { useFlareI18n } from "../../shared/i18n";
const { t } = useFlareI18n();

const props = defineProps<{
  show: boolean;
  mode: ForwardMode;
  conversations: readonly Conversation[];
  messages: readonly Message[];
  activeConversationId: string;
  loading?: boolean;
}>();

const emit = defineEmits<{
  (event: "update:show", value: boolean): void;
  (event: "confirm", payload: { targetConversationId: string; title: string }): void;
}>();

const selectedTargets = ref<string[]>([]);
const targetConversationId = computed(() => selectedTargets.value[0] ?? "");
const title = ref("");

const options = computed(() =>
  props.conversations.map((conversation) => ({
    name: conversation.displayName || conversation.conversationId,
    id: conversation.conversationId,
  })),
);

const orderedMessages = computed(() =>
  [...props.messages].sort((left, right) =>
    Number(left.conversationSeq || left.createdAt || left.clientCreatedAt || 0)
    - Number(right.conversationSeq || right.createdAt || right.clientCreatedAt || 0),
  ),
);

const defaultTitle = computed(() =>
  props.mode === "merged" ? t("forward.chatHistoryCount", { count: orderedMessages.value.length }) : t("enhance.forwardEachMessages"),
);

watch(
  () => props.show,
  (open) => {
    if (!open) return;
    selectedTargets.value = options.value.some(item => item.id === props.activeConversationId)
      ? [props.activeConversationId] : [];
    title.value = defaultTitle.value;
  },
);

function previewText(message: Message): string {
  const data = (message.content as { data?: Record<string, unknown> } | undefined)?.data;
  const text = typeof data?.text === "string" ? data.text : "";
  return text || message.content?.contentType || messageStableId(message);
}
</script>

<template>
  <FlareFormSheet
    :open="show"
    :title="t('enhance.forwardConfirmTitle')"
    :busy="loading"
    :confirm-disabled="!targetConversationId || orderedMessages.length === 0"
    :confirm-label="t('enhance.confirmForward')"
    @close="emit('update:show', false)"
    @confirm="emit('confirm', { targetConversationId, title: title || defaultTitle })"
  >
    <FlareFormField :label="t('enhance.modeLabel')" :hint="mode === 'merged' ? t('enhance.forwardMerged') : t('enhance.forwardEach')" />
    <FlareFormField :label="t('enhance.targetConv')">
      <FlareForwardPicker v-model="selectedTargets" :targets="options" :multiple="false" :busy="loading" embedded />
    </FlareFormField>
    <FlareFormField :label="t('enhance.previewTitleLabel')">
      <FlareInput v-model="title" :disabled="loading" :aria-label="t('enhance.previewTitleLabel')" :placeholder="t('enhance.forwardTitlePlaceholder')" />
    </FlareFormField>
    <FlareFormField
      :label="t('enhance.messagePreview')"
      :hint="t('enhance.itemsCount', { count: orderedMessages.length })"
    />
    <FlareFormField v-for="(item, index) in orderedMessages" :key="messageStableId(item)"
      :label="String(index + 1)" :hint="previewText(item)" />
  </FlareFormSheet>
</template>
