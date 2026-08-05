<script setup lang="ts">
import { computed } from "vue";
import { ArrowBackOutline, CheckmarkCircleOutline, FlashOutline, RefreshOutline, TerminalOutline } from "@vicons/ionicons5";
import { NButton, NIcon, NInput, NInputNumber, NList, NListItem, NSelect, NSwitch, NTabPane, NTabs, NTag } from "naive-ui";
import { NetworkInterfaceKind } from "@flare-im/sdk/web";
import { useRouter } from "vue-router";
import { useFlareI18n, useFlareSdk } from "@flare-im/vue-ui/app";

const sdk = useFlareSdk();
const router = useRouter();
const { t } = useFlareI18n();

const diagnosticsText = computed(() => JSON.stringify(sdk.diagnostics.value, null, 2));
const labResultText = computed(() => JSON.stringify(sdk.labResult.value, null, 2));
const buildCatalogText = computed(() => JSON.stringify(sdk.messageBuildCatalog.value, null, 2));
const latestEvent = computed(() => sdk.events.value[0]);
const activeRuntimeTone = computed(() => {
  const state = sdk.connectionState.value;
  if (state === "ready" || state === "connected") return "success";
  if (state === "connecting" || state === "reconnecting") return "warning";
  return "default";
});

const runtimeCards = computed(() => {
  const diagnostics = sdk.diagnostics.value as Record<string, unknown>;
  const sdkVersion = (diagnostics.sdkVersion ?? {}) as Record<string, unknown>;
  const ffi = (diagnostics.ffi ?? {}) as Record<string, unknown>;
  const dataRoot = (diagnostics.dataRoot ?? {}) as Record<string, unknown>;
  const runtimeHealth = (diagnostics.runtimeHealth ?? {}) as Record<string, unknown>;
  const wasmBinding = (sdkVersion.wasmBinding ?? {}) as Record<string, unknown>;
  return [
    {
      label: "Runtime",
      value: String(sdkVersion.runtime ?? sdk.sdkRuntimeStatus.value),
      detail: String(sdkVersion.adapterBoundary ?? "TypeScript SDK + host IMClient"),
    },
    {
      label: "Core Contract",
      value: String(ffi.version ?? "flare-im-ffi/v1"),
      detail: String(sdkVersion.coreSdk ?? "flare-im-core-sdk"),
    },
    {
      label: "Storage",
      value: String((dataRoot.storage as Record<string, unknown> | undefined)?.kind ?? "indexeddb"),
      detail: String(dataRoot.dataUrl ?? sdk.form.dataUrl),
    },
    {
      label: "Native Binding",
      value: String(wasmBinding.status ?? sdk.sdkRuntimeStatus.value),
      detail: String(wasmBinding.source ?? "flare-im-core-sdk/bindings/wasm"),
    },
    {
      label: "Runtime Health",
      value: String(runtimeHealth.state ?? sdk.connectionState.value),
      detail: `drops=${String(runtimeHealth.rawSubscriberDroppedTotal ?? 0)} metrics=${String(runtimeHealth.metricsEnabled ?? false)}`,
    },
  ];
});

const heartbeatStateOptions = [
  { label: "Foreground", value: "foreground" },
  { label: "Background", value: "background" },
];

const networkInterfaceOptions = [
  { label: "Wi-Fi", value: NetworkInterfaceKind.Wifi },
  { label: "Cellular", value: NetworkInterfaceKind.Cellular },
  { label: "Ethernet", value: NetworkInterfaceKind.Ethernet },
  { label: "Unknown", value: NetworkInterfaceKind.Unknown },
];

function back(): void {
  void router.push({ name: "conversations" });
}
</script>

<template>
  <section class="flutter-page sdk-lab-route">
    <header class="sdk-lab-header">
      <n-button circle quaternary class="page-nav-back" @click="back">
        <template #icon><n-icon :component="ArrowBackOutline" /></template>
      </n-button>
      <div class="sdk-lab-title">
        <span>Diagnostics Workbench</span>
        <h1>{{ t("sdkLab.title") }}</h1>
      </div>
      <n-button circle quaternary :loading="sdk.labBusy.value" @click="sdk.runSessionDiagnostics">
        <template #icon><n-icon :component="RefreshOutline" /></template>
      </n-button>
    </header>

    <section class="sdk-lab-hero">
      <div class="sdk-lab-hero__status">
        <n-tag round :type="activeRuntimeTone">{{ sdk.connectionState.value }}</n-tag>
        <n-tag round :type="sdk.sessionActive.value ? 'success' : 'default'">
          {{ sdk.sessionActive.value ? t("login.sessionActive") : t("login.sessionInactive") }}
        </n-tag>
      </div>
      <div class="sdk-lab-hero__copy">
        <strong>{{ sdk.currentUserId.value || sdk.form.userId || "anonymous" }}</strong>
        <span>{{ latestEvent ? `${latestEvent.label} · ${latestEvent.detail}` : "No runtime events captured yet" }}</span>
      </div>
      <div class="sdk-lab-hero__actions">
        <n-button secondary :loading="sdk.labBusy.value" @click="sdk.runSessionDiagnostics">
          <template #icon><n-icon :component="TerminalOutline" /></template>
          Session
        </n-button>
        <n-button secondary :loading="sdk.labBusy.value" @click="sdk.runEventOperation">
          <template #icon><n-icon :component="FlashOutline" /></template>
          Events
        </n-button>
        <n-button type="primary" :loading="sdk.labBusy.value" @click="sdk.runSyncOperation('messages')">
          <template #icon><n-icon :component="CheckmarkCircleOutline" /></template>
          Sync
        </n-button>
      </div>
    </section>

    <n-tabs type="line" animated class="sdk-lab-tabs">
      <n-tab-pane name="diagnostics" :tab="t('sdkLab.diagnostics')">
        <div class="runtime-card-grid">
          <section v-for="card in runtimeCards" :key="card.label" class="runtime-card">
            <span>{{ card.label }}</span>
            <strong>{{ card.value }}</strong>
            <small>{{ card.detail }}</small>
          </section>
        </div>
        <pre class="drawer-json">{{ diagnosticsText }}</pre>
      </n-tab-pane>
      <n-tab-pane name="connection-session" tab="连接/会话">
        <div class="lab-field">
          <span>Connection state</span>
          <div class="lab-grid">
            <n-button secondary :loading="sdk.labBusy.value" @click="sdk.runConnectionOperation('state')">Get state</n-button>
            <n-button secondary :loading="sdk.labBusy.value" @click="sdk.runConnectionOperation('disconnect')">Disconnect</n-button>
            <n-button type="primary" :loading="sdk.labBusy.value" @click="sdk.runConnectionOperation('network_change')">Notify network</n-button>
          </div>
          <n-select v-model:value="sdk.sdkLab.networkInterface" :options="networkInterfaceOptions" />
          <div class="lab-switch-row">
            <span>Available</span>
            <n-switch v-model:value="sdk.sdkLab.networkAvailable" />
            <span>Expensive</span>
            <n-switch v-model:value="sdk.sdkLab.networkExpensive" />
            <span>Metered</span>
            <n-switch v-model:value="sdk.sdkLab.networkMetered" />
          </div>
        </div>
        <div class="lab-field">
          <span>Session lifecycle</span>
          <div class="lab-grid">
            <n-button secondary :loading="sdk.labBusy.value" @click="sdk.runSessionOperation('current_user')">Current user</n-button>
            <n-button secondary :loading="sdk.labBusy.value" @click="sdk.runSessionOperation('session_active')">Session active</n-button>
            <n-button secondary :loading="sdk.labBusy.value" @click="sdk.runSessionOperation('runtime_health')">Runtime health</n-button>
          </div>
        </div>
        <div class="lab-field">
          <span>Heartbeat / token</span>
          <n-select v-model:value="sdk.sdkLab.heartbeatAppState" :options="heartbeatStateOptions" />
          <n-input-number v-model:value="sdk.sdkLab.heartbeatNatTimeoutSecs" :min="0" :step="5" />
          <n-input-number v-model:value="sdk.sdkLab.tokenTtlSecs" :min="60" :step="60" />
          <div class="lab-grid">
            <n-button secondary :loading="sdk.labBusy.value" @click="sdk.runSessionOperation('heartbeat_interval')">Effective interval</n-button>
            <n-button secondary :loading="sdk.labBusy.value" @click="sdk.runSessionOperation('heartbeat_app_state')">Set app state</n-button>
            <n-button secondary :loading="sdk.labBusy.value" @click="sdk.runSessionOperation('heartbeat_nat_timeout')">Set NAT timeout</n-button>
            <n-button type="primary" :loading="sdk.labBusy.value" @click="sdk.runSessionOperation('update_access_token')">Refresh token</n-button>
          </div>
        </div>
        <pre class="drawer-json">{{ labResultText }}</pre>
      </n-tab-pane>
      <n-tab-pane name="builder" :tab="t('sdkLab.builder')">
        <div class="lab-field">
          <span>Builder catalog</span>
          <n-select v-model:value="sdk.sdkLab.buildOp" :options="sdk.messageBuildOptions.value" filterable />
          <n-input v-model:value="sdk.sdkLab.messageText" placeholder="消息正文 / 标题 / 摘要" />
          <n-input
            v-model:value="sdk.sdkLab.jsonParams"
            type="textarea"
            placeholder='附加 JSON，例如 {"title":"任务","description":"来自 SDK Lab"}'
            :autosize="{ minRows: 3, maxRows: 8 }"
          />
          <div class="lab-grid">
            <n-button type="primary" :loading="sdk.labBusy.value" @click="sdk.buildAndSendMessage()">{{ t("sdkLab.buildSend") }}</n-button>
            <n-button secondary :loading="sdk.labBusy.value" @click="sdk.runSessionDiagnostics">{{ t("sdkLab.refreshCatalog") }}</n-button>
          </div>
        </div>
        <pre class="drawer-json">{{ buildCatalogText }}</pre>
      </n-tab-pane>
      <n-tab-pane name="message-dispatch" tab="消息操作">
        <div class="lab-field">
          <span>Message dispatch</span>
          <n-select v-model:value="sdk.sdkLab.dispatchOp" :options="sdk.messageDispatchOptions" filterable />
          <n-input v-model:value="sdk.sdkLab.messageId" placeholder="message id，留空时使用当前会话最新消息" />
          <n-input v-model:value="sdk.sdkLab.query" placeholder="搜索关键词" />
          <n-input v-model:value="sdk.sdkLab.reaction" placeholder="reaction / mark color" />
          <n-button type="primary" :loading="sdk.labBusy.value" @click="sdk.runDispatch()">Dispatch</n-button>
        </div>
        <pre class="drawer-json">{{ labResultText }}</pre>
      </n-tab-pane>
      <n-tab-pane name="sync-presence" tab="同步/在线">
        <div class="lab-field">
          <span>Presence users</span>
          <n-input v-model:value="sdk.sdkLab.userIds" placeholder="输入真实用户 ID，多个用逗号分隔" />
        </div>
        <div class="lab-grid">
          <n-button secondary :loading="sdk.labBusy.value" @click="sdk.runSyncOperation('conversation')">Sync conversation</n-button>
          <n-button secondary :loading="sdk.labBusy.value" @click="sdk.runSyncOperation('messages')">Sync messages</n-button>
          <n-button secondary :loading="sdk.labBusy.value" @click="sdk.runSyncOperation('read')">Mark read</n-button>
          <n-button secondary :loading="sdk.labBusy.value" @click="sdk.runPresenceOperation('get')">Presence single</n-button>
          <n-button secondary :loading="sdk.labBusy.value" @click="sdk.runPresenceOperation('batch')">Presence batch</n-button>
          <n-button secondary :loading="sdk.labBusy.value" @click="sdk.runPresenceOperation('subscribe')">Subscribe presence</n-button>
        </div>
        <pre class="drawer-json">{{ labResultText }}</pre>
      </n-tab-pane>
      <n-tab-pane name="capability" tab="能力">
        <div class="lab-field">
          <span>Capability dispatch</span>
          <n-input v-model:value="sdk.sdkLab.capability" placeholder="rtc.call / plugin capability id" />
          <n-input v-model:value="sdk.sdkLab.capabilityTargetUserId" placeholder="grant/revoke target user id" />
          <n-input
            v-model:value="sdk.sdkLab.jsonParams"
            type="textarea"
            placeholder='capability payload JSON，例如 {"roomId":"room-1"}'
            :autosize="{ minRows: 3, maxRows: 8 }"
          />
        </div>
        <div class="lab-grid">
          <n-button secondary @click="sdk.runCapabilityOperation('list')">Global capabilities</n-button>
          <n-button secondary @click="sdk.runCapabilityOperation('list_user')">Current user</n-button>
          <n-button secondary @click="sdk.runCapabilityOperation('dispatch')">Dispatch</n-button>
          <n-button secondary @click="sdk.runCapabilityOperation('grant')">Grant</n-button>
          <n-button secondary @click="sdk.runCapabilityOperation('revoke')">Revoke</n-button>
          <n-button secondary @click="sdk.runCapabilityOperation('call_signal')">Call signal</n-button>
        </div>
        <pre class="drawer-json">{{ labResultText }}</pre>
      </n-tab-pane>
      <n-tab-pane name="media" tab="媒体">
        <div class="lab-field">
          <span>Media inputs</span>
          <n-input v-model:value="sdk.sdkLab.fileId" placeholder="file id / object key" />
          <n-input v-model:value="sdk.sdkLab.downloadKey" placeholder="download key" />
          <n-input v-model:value="sdk.sdkLab.displayFileName" placeholder="display file name" />
          <n-input v-model:value="sdk.sdkLab.sourcePath" placeholder="source path" />
          <n-input v-model:value="sdk.sdkLab.sourceUrl" placeholder="source http url" />
          <n-input v-model:value="sdk.sdkLab.remoteFileId" placeholder="remote file id" />
          <n-input v-model:value="sdk.sdkLab.mediaUrl" placeholder="remote media url" />
          <n-input v-model:value="sdk.sdkLab.mediaCacheRoot" placeholder="cache root" />
          <n-input-number v-model:value="sdk.sdkLab.mediaCacheMaxBytes" :min="1048576" :step="1048576" />
          <n-input v-model:value="sdk.sdkLab.downloadSubfolder" placeholder="download subfolder" />
        </div>
        <div class="lab-grid">
          <n-button secondary @click="sdk.runMediaOperation('stats')">Media cache</n-button>
          <n-button secondary @click="sdk.runMediaOperation('upload_file')">Upload file</n-button>
          <n-button secondary @click="sdk.runMediaOperation('upload_image')">Upload image</n-button>
          <n-button secondary @click="sdk.runMediaOperation('upload_video')">Upload video</n-button>
          <n-button secondary @click="sdk.runMediaOperation('upload_bytes')">Upload bytes</n-button>
          <n-button secondary @click="sdk.runMediaOperation('delete_file')">Delete file</n-button>
          <n-button secondary @click="sdk.runMediaOperation('url')">Access URL</n-button>
          <n-button secondary @click="sdk.runMediaOperation('temp_url')">Temp URL</n-button>
          <n-button secondary @click="sdk.runMediaOperation('resolve')">Resolve</n-button>
          <n-button secondary @click="sdk.runMediaOperation('display_url')">Display URL</n-button>
          <n-button secondary @click="sdk.runMediaOperation('cache_remote')">Cache remote</n-button>
          <n-button secondary @click="sdk.runMediaOperation('set_root')">Set cache root</n-button>
          <n-button secondary @click="sdk.runMediaOperation('set_max')">Set cache max</n-button>
          <n-button secondary @click="sdk.runMediaOperation('download_subfolder')">Download folder</n-button>
          <n-button secondary @click="sdk.runMediaOperation('download_file')">Download file</n-button>
          <n-button secondary @click="sdk.runMediaOperation('cancel_download')">Cancel download</n-button>
          <n-button secondary @click="sdk.runMediaOperation('saved_path')">Saved path</n-button>
          <n-button secondary @click="sdk.runMediaOperation('delete_download')">Delete record</n-button>
          <n-button secondary @click="sdk.runMediaOperation('clear')">清理媒体缓存</n-button>
        </div>
        <pre class="drawer-json">{{ labResultText }}</pre>
      </n-tab-pane>
      <n-tab-pane name="events" tab="事件">
        <div class="lab-grid">
          <n-button type="primary" :loading="sdk.labBusy.value" @click="sdk.runEventOperation()">
            Subscribe events
          </n-button>
        </div>
        <div class="event-contracts">
          <n-tag
            v-for="name in [
              'onInitializing',
              'onInitialized',
              'onConnecting',
              'onConnectReady',
              'onDisconnected',
              'onMessageReceived',
              'onMessageSendAck',
              'onMessageReactionChanged',
              'onInputStatusChanged',
              'onNewConversation',
              'onConversationChanged',
              'onSyncProgress',
              'onUploadProgress',
              'onDownloadProgress',
              'onCapabilityChanged',
            ]"
            :key="name"
            round
          >
            {{ name }}
          </n-tag>
        </div>
        <n-list>
          <n-list-item v-for="event in sdk.events.value" :key="event.id">
            <strong>{{ event.label }}</strong> · {{ event.detail }}
          </n-list-item>
        </n-list>
      </n-tab-pane>
    </n-tabs>
  </section>
</template>
