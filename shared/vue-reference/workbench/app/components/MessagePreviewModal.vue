<script setup lang="ts">
// Workbench "preview a message" panel of the reference app: a product composition over the kit's
// MessageContentView / MarkdownPreview, not a kit component.
import { computed } from "vue";
import { FlareMarkdownPreview, FlareMessageContentView } from "@flare-im/vue-ui/components";
import { useFlareI18n } from "@flare-im/vue-ui/i18n";
import {
  isMarkdown,
  messageContentTypeForUi,
  normalizeToContentElem,
  previewTextFromMessageContent,
  textBodyFromContent,
} from "@flare-im/vue-ui/utils";

const { t } = useFlareI18n();

type PreviewMessage = {
  senderDisplayName?: string;
  senderId?: string;
  createdAt?: number;
  clientCreatedAt?: number;
  content?: {
    contentType?: string;
    data?: Record<string, unknown>;
  };
  attributes?: Record<string, unknown>;
};

const props = defineProps<{
  message?: PreviewMessage | null;
}>();

const type = computed(() =>
  messageContentTypeForUi(props.message?.content?.contentType ?? "text"),
);
const decoded = computed(() => normalizeToContentElem(props.message?.content));
const summary = computed(() =>
  previewTextFromMessageContent(props.message?.content),
);
const markdownBody = computed(() => {
  if (!decoded.value || type.value !== "text") return "";
  const body = textBodyFromContent(decoded.value);
  return isMarkdown(body) ? body : "";
});

const title = computed(() => {
  const known = ["image", "video", "audio", "file", "location", "quote", "forward", "richText", "sticker", "emoji"];
  return t(`messagePreviewModal.${known.includes(type.value) ? type.value : "details"}`);
});

const timeText = computed(() => {
  const ts = Number(
    props.message?.createdAt ?? props.message?.clientCreatedAt ?? 0,
  );
  if (!ts) return "";
  return new Date(ts).toLocaleString("zh-CN");
});
</script>

<template>
  <section v-if="message" class="preview-modal">
    <header class="preview-modal__head">
      <div>
        <strong>{{ title }}</strong>
        <span>{{
          message.senderDisplayName || message.senderId || "Unknown sender"
        }}</span>
        <small v-if="timeText">{{ timeText }}</small>
      </div>
      <span class="preview-modal__type">{{ type }}</span>
    </header>

    <div class="preview-modal__body" :class="`preview-modal__body--${type}`">
      <FlareMessageContentView
        v-if="message.content"
        :content="message.content"
        preview-mode
        :sender-name="message.senderDisplayName"
        :message-extra="message.attributes"
      />
      <FlareMarkdownPreview v-else-if="markdownBody" :content="markdownBody" />
      <p v-else class="preview-modal__fallback">{{ summary }}</p>
    </div>

    <details
      v-if="message.content?.data && Object.keys(message.content.data).length"
      class="preview-modal__raw"
    >
      <summary>Raw payload</summary>
      <pre>{{ JSON.stringify(message.content.data, null, 2) }}</pre>
    </details>
  </section>
</template>

<style scoped>
.preview-modal {
  display: flex;
  flex-direction: column;
  gap: 14px;
  min-width: 0;
}

.preview-modal__head {
  display: flex;
  align-items: flex-start;
  justify-content: space-between;
  gap: 12px;
}

.preview-modal__type {
  flex: none;
  padding: 2px 10px;
  border: 1px solid var(--flare-color-border-primary);
  border-radius: var(--flare-size-radius-full, 999px);
  color: var(--flare-color-text-secondary);
  font-size: 12px;
  line-height: 18px;
}

.preview-modal__head span,
.preview-modal__head small {
  display: block;
  color: var(--flare-color-text-secondary);
  font-size: 12px;
}

.preview-modal__body {
  min-height: 120px;
  padding: 12px;
  border: 1px solid var(--flare-color-border-primary);
  border-radius: 12px;
  background: var(--flare-color-bg-tertiary);
}

.preview-modal__fallback {
  margin: 0;
  white-space: pre-wrap;
  word-break: break-word;
  color: var(--flare-color-text-primary);
}

.preview-modal__raw summary {
  cursor: pointer;
  color: var(--flare-color-text-secondary);
  font-size: 12px;
}

.preview-modal__raw pre {
  margin-top: 8px;
  max-height: 220px;
  overflow: auto;
  padding: 10px;
  border-radius: 8px;
  background: var(--flare-color-bg-primary);
  font-size: 11px;
}
</style>
