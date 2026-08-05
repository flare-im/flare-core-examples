<script setup lang="ts">
import { computed } from "vue";
import { useRouter } from "vue-router";
import { NAlert, NTag, useMessage } from "naive-ui";
import {
  AuthScreen,
  isAppTransportSelectorEnabled,
  useFlareI18n,
  useFlareSdk,
} from "@flare-im/vue-ui/app";

const sdk = useFlareSdk();
const router = useRouter();
const message = useMessage();
const { t } = useFlareI18n();
const showTransportSelector = isAppTransportSelectorEnabled();

const sessionSummary = computed(() => ({
  userId: sdk.currentUserId.value || sdk.form.userId,
  sessionActive: sdk.sessionActive.value,
  isConnected: sdk.isConnected.value,
  connectionState: sdk.connectionState.value,
  runtime: sdk.sdkRuntimeStatus.value,
}));

const runtimeUnavailable = computed(
  () => sdk.sdkRuntimeStatus.value === "browser-unavailable" && !sdk.loggedIn.value,
);

async function login(): Promise<void> {
  try {
    await sdk.initializeAndLogin();
    if (sdk.transportFallbackNotice.value) {
      message.warning(sdk.transportFallbackNotice.value);
    }
    await router.replace({ name: "sync" });
  } catch (error) {
    const detail = error instanceof Error ? error.message : String(error);
    message.error(detail || t("login.failed"));
  }
}

</script>

<template>
  <div class="auth-route">
    <n-alert v-if="runtimeUnavailable" type="error" :title="t('login.runtimeUnavailable')" class="auth-runtime-alert">
      {{ t("login.runtimeUnavailableHint") }}
    </n-alert>
    <n-alert
      v-else-if="sdk.transportFallbackNotice.value && !sdk.loggedIn.value"
      type="warning"
      class="auth-runtime-alert"
    >
      {{ sdk.transportFallbackNotice.value }}
    </n-alert>
    <AuthScreen
      v-model:user-id="sdk.form.userId"
      v-model:token="sdk.form.token"
      v-model:transport-mode="sdk.form.transportMode"
      v-model:ws-url="sdk.form.wsUrl"
      v-model:quic-url="sdk.form.quicUrl"
      v-model:tls-ca-cert-path="sdk.form.tlsCaCertPath"
      v-model:http-url="sdk.form.httpUrl"
      v-model:data-url="sdk.form.dataUrl"
      v-model:tenant-id="sdk.form.tenantId"
      :show-transport-selector="showTransportSelector"
      :loading="sdk.busy.value"
      @generate-token="sdk.generateToken"
      @login="login"
    />
    <section v-if="sdk.initialized.value || sdk.events.value.length" class="auth-session-strip">
      <n-tag size="small" :type="sessionSummary.sessionActive ? 'success' : 'default'">
        {{ sessionSummary.sessionActive ? t("login.sessionActive") : t("login.sessionInactive") }}
      </n-tag>
      <n-tag size="small" :type="sessionSummary.isConnected ? 'success' : 'warning'">
        {{ sessionSummary.isConnected ? t("login.connected") : t("login.disconnected") }}
      </n-tag>
      <span>{{ sessionSummary.userId }} · {{ sessionSummary.connectionState }} · runtime={{ sessionSummary.runtime }}</span>
    </section>
  </div>
</template>

<style scoped>
.auth-route {
  min-height: 100%;
}
</style>
