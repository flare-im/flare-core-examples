<script setup lang="ts">
import { computed, reactive, watch } from "vue";
import { FlareInput, FlareTextarea, FlareCheckbox, FlareFormField, FlareFormSheet } from "@flare-im/vue-ui/components";
import { resolveComposerAction } from "../messageTypeRegistry";
import type { ComposerPayloadRequest } from "../types";
import { useFlareI18n } from "../../shared/i18n";
const { t } = useFlareI18n();

const props = defineProps<{
  show: boolean;
  op: string;
  loading?: boolean;
}>();

const emit = defineEmits<{
  (event: "update:show", value: boolean): void;
  (event: "submit", payload: ComposerPayloadRequest): void;
}>();

type ComposerFormValue = string | number | boolean | string[];

const form = reactive<Record<string, ComposerFormValue>>({});

const action = computed(() => {
  const resolved = resolveComposerAction(props.op);
  return resolved?.acceptsFiles ? undefined : resolved;
});
const title = computed(() => action.value?.label ?? t("enhance.messageFallback"));

watch(
  () => props.show,
  (open) => {
    if (!open || !action.value) return;
    Object.keys(form).forEach((key) => delete form[key]);
    Object.assign(form, action.value.defaultParams() as Record<string, ComposerFormValue>);
  },
);

function setOptions(value: string): void {
  form.options = value.split("\n").map((item) => item.trim()).filter(Boolean);
}

function fieldText(key: string): string {
  const value = form[key];
  return typeof value === "string" || typeof value === "number" ? String(value) : "";
}

function setTextField(key: string, value: string): void {
  form[key] = value;
}

function optionsText(): string {
  return Array.isArray(form.options) ? form.options.join("\n") : "";
}

function submit(): void {
  const current = action.value;
  if (!current || props.loading) return;
  emit("submit", current.buildRequest({ ...form }, []));
}
</script>

<template>
  <FlareFormSheet
    :open="show"
    :title="t('enhance.sendTitle', { title })"
    :busy="loading"
    :confirm-disabled="!action"
    :confirm-label="t('enhance.send')"
    @close="emit('update:show', false)"
    @confirm="submit"
  >
    <template v-if="action">
      <FlareFormField :label="action.kind" :hint="action.description" />

      <template v-if="action.kind === 'richText'">
        <FlareFormField :label="t('enhance.title')">
          <FlareInput :model-value="fieldText('title')" :disabled="loading" @update:model-value="setTextField('title', $event)" />
        </FlareFormField>
        <FlareFormField :label="t('composeType.field.richMarkdown')">
          <FlareTextarea :model-value="fieldText('markdown')" :disabled="loading" :max-rows="8" @update:model-value="setTextField('markdown', $event)" />
        </FlareFormField>
      </template>

      <template v-else-if="action.kind === 'vote'">
        <FlareFormField :label="t('composeType.field.voteTitle')">
          <FlareInput :model-value="fieldText('title')" :disabled="loading" @update:model-value="setTextField('title', $event)" />
        </FlareFormField>
        <FlareFormField :label="t('enhance.optionsPerLine')">
          <FlareTextarea :model-value="optionsText()" :disabled="loading" :max-rows="5" @update:model-value="setOptions" />
        </FlareFormField>
        <FlareFormField>
          <FlareCheckbox :model-value="Boolean(form.multiple)" :disabled="loading" :label="t('enhance.multiple')" @update:model-value="form.multiple = $event" />
          <FlareCheckbox :model-value="Boolean(form.anonymous)" :disabled="loading" :label="t('enhance.anonymous')" @update:model-value="form.anonymous = $event" />
        </FlareFormField>
      </template>

      <template v-else>
        <FlareFormField v-if="'id' in form" label="ID">
          <FlareInput :model-value="fieldText('id')" :disabled="loading" @update:model-value="setTextField('id', $event)" />
        </FlareFormField>
        <FlareFormField v-if="'threadId' in form" label="Thread ID">
          <FlareInput :model-value="fieldText('threadId')" :disabled="loading" @update:model-value="setTextField('threadId', $event)" />
        </FlareFormField>
        <FlareFormField v-if="'appId' in form" label="App ID">
          <FlareInput :model-value="fieldText('appId')" :disabled="loading" @update:model-value="setTextField('appId', $event)" />
        </FlareFormField>
        <FlareFormField v-if="'cardType' in form" :label="t('enhance.cardType')">
          <FlareInput :model-value="fieldText('cardType')" :disabled="loading" @update:model-value="setTextField('cardType', $event)" />
        </FlareFormField>
        <FlareFormField v-if="'pagePath' in form" :label="t('enhance.path')">
          <FlareInput :model-value="fieldText('pagePath')" :disabled="loading" @update:model-value="setTextField('pagePath', $event)" />
        </FlareFormField>
        <FlareFormField v-if="'title' in form" :label="t('enhance.titleOrName')">
          <FlareInput :model-value="fieldText('title')" :disabled="loading" @update:model-value="setTextField('title', $event)" />
        </FlareFormField>
        <FlareFormField v-if="'subtitle' in form" :label="t('enhance.subtitle')">
          <FlareInput :model-value="fieldText('subtitle')" :disabled="loading" @update:model-value="setTextField('subtitle', $event)" />
        </FlareFormField>
        <FlareFormField v-if="'avatar' in form" :label="t('enhance.avatar')">
          <FlareInput :model-value="fieldText('avatar')" :disabled="loading" @update:model-value="setTextField('avatar', $event)" />
        </FlareFormField>
        <FlareFormField v-if="'appName' in form" :label="t('enhance.appName')">
          <FlareInput :model-value="fieldText('appName')" :disabled="loading" @update:model-value="setTextField('appName', $event)" />
        </FlareFormField>
        <FlareFormField v-if="'description' in form" :label="t('enhance.description')">
          <FlareTextarea :model-value="fieldText('description')" :disabled="loading" :max-rows="5" @update:model-value="setTextField('description', $event)" />
        </FlareFormField>
        <FlareFormField v-if="'text' in form" :label="t('enhance.content')">
          <FlareTextarea :model-value="fieldText('text')" :disabled="loading" :max-rows="5" @update:model-value="setTextField('text', $event)" />
        </FlareFormField>
        <FlareFormField v-if="'address' in form" :label="t('enhance.address')">
          <FlareInput :model-value="fieldText('address')" :disabled="loading" @update:model-value="setTextField('address', $event)" />
        </FlareFormField>
        <FlareFormField v-if="'url' in form" :label="t('enhance.link')">
          <FlareInput :model-value="fieldText('url')" :disabled="loading" @update:model-value="setTextField('url', $event)" />
        </FlareFormField>
        <FlareFormField v-if="'thumbnailUrl' in form" :label="t('enhance.thumbnail')">
          <FlareInput :model-value="fieldText('thumbnailUrl')" :disabled="loading" @update:model-value="setTextField('thumbnailUrl', $event)" />
        </FlareFormField>
        <FlareFormField v-if="'mimeType' in form" label="MIME Type">
          <FlareInput :model-value="fieldText('mimeType')" :disabled="loading" @update:model-value="setTextField('mimeType', $event)" />
        </FlareFormField>
        <FlareFormField v-if="'fileName' in form" :label="t('enhance.fileName')">
          <FlareInput :model-value="fieldText('fileName')" :disabled="loading" @update:model-value="setTextField('fileName', $event)" />
        </FlareFormField>
        <FlareFormField v-if="'latitude' in form" :label="t('composeType.field.latitude')">
          <FlareInput :model-value="fieldText('latitude')" :disabled="loading" @update:model-value="setTextField('latitude', $event)" />
        </FlareFormField>
        <FlareFormField v-if="'longitude' in form" :label="t('composeType.field.longitude')">
          <FlareInput :model-value="fieldText('longitude')" :disabled="loading" @update:model-value="setTextField('longitude', $event)" />
        </FlareFormField>
        <FlareFormField v-if="'assignee' in form" :label="t('enhance.assignee')">
          <FlareInput :model-value="fieldText('assignee')" :disabled="loading" @update:model-value="setTextField('assignee', $event)" />
        </FlareFormField>
        <FlareFormField v-if="'dueTime' in form" :label="t('enhance.dueTime')">
          <FlareInput :model-value="fieldText('dueTime')" :disabled="loading" @update:model-value="setTextField('dueTime', $event)" />
        </FlareFormField>
        <FlareFormField v-if="'deadline' in form" :label="t('enhance.dueTime')">
          <FlareInput :model-value="fieldText('deadline')" :disabled="loading" @update:model-value="setTextField('deadline', $event)" />
        </FlareFormField>
        <FlareFormField v-if="'status' in form" :label="t('enhance.status')">
          <FlareInput :model-value="fieldText('status')" :disabled="loading" @update:model-value="setTextField('status', $event)" />
        </FlareFormField>
        <FlareFormField v-if="'time' in form" :label="t('enhance.time')">
          <FlareInput :model-value="fieldText('time')" :disabled="loading" @update:model-value="setTextField('time', $event)" />
        </FlareFormField>
        <FlareFormField v-if="'location' in form" :label="t('enhance.place')">
          <FlareInput :model-value="fieldText('location')" :disabled="loading" @update:model-value="setTextField('location', $event)" />
        </FlareFormField>
        <FlareFormField v-if="'summary' in form" :label="t('enhance.summary')">
          <FlareTextarea :model-value="fieldText('summary')" :disabled="loading" :max-rows="5" @update:model-value="setTextField('summary', $event)" />
        </FlareFormField>
      </template>
    </template>
  </FlareFormSheet>
</template>
