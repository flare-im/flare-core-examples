<script setup lang="ts">
import { computed } from "vue";
import { ChatbubbleEllipsesOutline, FlaskOutline, SearchOutline } from "@flare-im/vue-ui/icon-glyphs";
import { FlareButton, FlareEmptyState, FlareChatWorkspace } from "@flare-im/vue-ui/components";
import { useRouter } from "vue-router";
import { useFlareWorkbenchUi } from "../../composables/useFlareWorkbenchUi";
import { useFlareSdk } from "../sdk/flareSdkContext";
import { useFlareI18n } from "../shared/i18n";

const sdk = useFlareSdk();
const router = useRouter();
const workbenchUi = useFlareWorkbenchUi();
const { t } = useFlareI18n();

const runtimeProductLabel = computed(() =>
  sdk.sdkRuntimeStatus.value === "tauri-native" ? "Flare Core Tauri" : "Flare Core Web",
);

function openLab(): void {
  void router.push({ name: "sdk-lab" });
}
</script>

<template>
  <FlareChatWorkspace :label="t('chat.selectTitle')">
    <template #timeline>
      <FlareEmptyState :title="t('chat.selectTitle')" :description="`${runtimeProductLabel} · ${t('chat.selectHint')}`" icon="chats">
      <template #actions>
        <FlareButton :icon="ChatbubbleEllipsesOutline" @click="workbenchUi.openStartChat()">
          {{ t("workbench.newChat") }}
        </FlareButton>
        <FlareButton variant="secondary" :icon="SearchOutline" @click="workbenchUi.openChatSearch()">
          {{ t("workbench.searchMessages") }}
        </FlareButton>
        <FlareButton variant="secondary" :icon="FlaskOutline" @click="openLab">
          {{ t("nav.sdkLab") }}
        </FlareButton>
      </template>
      </FlareEmptyState>
    </template>
  </FlareChatWorkspace>
</template>
