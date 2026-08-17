<script setup lang="ts">
import { computed } from "vue";
import { ChatbubbleEllipsesOutline, FlaskOutline, SearchOutline } from "@vicons/ionicons5";
import { NButton, NIcon } from "naive-ui";
import { useRouter } from "vue-router";
import { useFlareWorkbenchUi } from "@flare-im/vue-ui/composables";
// SDK 绑定符号走独立子路径：它们对 @flare-im/sdk 有运行时依赖，
// 不能挂在会被主 barrel 带出去的 ./composables 上。
import { loginTransportDisplayName } from "@flare-im/vue-ui/composables/sdk";
import { useFlareI18n, useFlareSdk } from "@flare-im/vue-ui/app";

const sdk = useFlareSdk();
const router = useRouter();
const workbenchUi = useFlareWorkbenchUi();
const { t } = useFlareI18n();

const runtimeProductLabel = computed(() =>
  sdk.sdkRuntimeStatus.value === "tauri-native" ? "Flare Core Tauri" : "Flare Core Web",
);
const activeTransportLabel = computed(() => loginTransportDisplayName(sdk.form.transportMode));

function openLab(): void {
  void router.push({ name: "sdk-lab" });
}
</script>

<template>
  <section class="flutter-page chat-route chat-route--placeholder">
    <div class="chat-placeholder">
      <div class="chat-placeholder__mark">
        <n-icon :component="ChatbubbleEllipsesOutline" :size="34" />
      </div>
      <div class="chat-placeholder__copy">
        <span>{{ runtimeProductLabel }}</span>
        <strong>{{ t("chat.selectTitle") }}</strong>
        <p>{{ t("chat.selectHint") }}</p>
      </div>
      <div class="chat-placeholder__metrics" aria-label="Current SDK state">
        <div>
          <strong>{{ sdk.conversations.value.length }}</strong>
          <span>local conversations</span>
        </div>
        <div>
          <strong>{{ sdk.totalUnread.value }}</strong>
          <span>unread messages</span>
        </div>
        <div>
          <strong>{{ sdk.connectionState.value }}</strong>
          <span>connection state</span>
        </div>
        <div>
          <strong>{{ activeTransportLabel }}</strong>
          <span>protocol</span>
        </div>
      </div>
      <div class="chat-placeholder__actions">
        <n-button type="primary" @click="workbenchUi.openStartChat()">
          <template #icon><n-icon :component="ChatbubbleEllipsesOutline" /></template>
          新建会话
        </n-button>
        <n-button secondary @click="workbenchUi.openChatSearch()">
          <template #icon><n-icon :component="SearchOutline" /></template>
          搜索消息
        </n-button>
        <n-button secondary @click="openLab">
          <template #icon><n-icon :component="FlaskOutline" /></template>
          SDK Lab
        </n-button>
      </div>
    </div>
  </section>
</template>
