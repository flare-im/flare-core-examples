<script setup lang="ts">
import { computed, onMounted, ref } from "vue";
import { useRouter } from "vue-router";
import { NButton, NIcon, NProgress, NTag, useMessage } from "naive-ui";
import { ChatbubbleEllipsesOutline, CheckmarkCircleOutline, RefreshOutline } from "@vicons/ionicons5";
import { useFlareSdk } from "@flare-im/vue-ui/app";

const sdk = useFlareSdk();
const router = useRouter();
const message = useMessage();
const running = ref(false);

const progress = computed(() => sdk.homeSyncProgress.value);
const percent = computed(() => Math.max(0, Math.min(100, progress.value.percent)));
const failed = computed(() => progress.value.step === "failed");
const done = computed(() => progress.value.step === "ready");
const statusType = computed(() => {
  if (failed.value) return "error";
  if (done.value) return "success";
  return "info";
});

async function runSync(): Promise<void> {
  if (running.value) return;
  running.value = true;
  try {
    await sdk.syncHomeBeforeEnter();
    await router.replace({ name: "conversations" });
  } catch (error) {
    const detail = error instanceof Error ? error.message : String(error);
    message.error(detail || "首页同步失败");
  } finally {
    running.value = false;
  }
}

onMounted(() => {
  void runSync();
});
</script>

<template>
  <main class="sync-route">
    <section class="sync-panel" aria-live="polite">
      <div class="sync-icon" :class="{ 'sync-icon--done': done, 'sync-icon--failed': failed }">
        <n-icon :component="done ? CheckmarkCircleOutline : ChatbubbleEllipsesOutline" />
      </div>

      <div class="sync-heading">
        <span class="sync-eyebrow">FLARE CORE WEB</span>
        <h1>{{ progress.title }}</h1>
        <p>{{ progress.detail }}</p>
      </div>

      <n-progress
        type="line"
        :percentage="percent"
        :status="statusType"
        :height="10"
        border-radius="6px"
        indicator-placement="inside"
        processing
      />

      <div class="sync-stats">
        <div>
          <strong>{{ sdk.conversations.value.length }}</strong>
          <span>会话</span>
        </div>
        <div>
          <strong>{{ sdk.totalUnread.value }}</strong>
          <span>未读</span>
        </div>
        <div>
          <strong>{{ sdk.connectionState.value }}</strong>
          <span>连接状态</span>
        </div>
      </div>

      <div class="sync-footer">
        <n-tag :type="failed ? 'error' : done ? 'success' : 'info'" round>
          {{ failed ? "同步失败" : done ? "已完成" : "同步中" }}
        </n-tag>
        <n-button v-if="failed" type="primary" :loading="running" @click="runSync">
          <template #icon>
            <n-icon :component="RefreshOutline" />
          </template>
          重试
        </n-button>
      </div>
    </section>
  </main>
</template>

<style scoped>
.sync-route {
  min-height: 100vh;
  display: grid;
  place-items: center;
  padding: 24px;
  background:
    linear-gradient(180deg, rgba(255, 255, 255, 0.96), rgba(244, 247, 251, 0.94)),
    #f6f8fb;
}

.sync-panel {
  width: min(560px, 100%);
  display: grid;
  gap: 22px;
  padding: 34px;
  border: 1px solid rgba(148, 163, 184, 0.28);
  border-radius: 12px;
  background: rgba(255, 255, 255, 0.92);
  box-shadow: 0 22px 64px rgba(15, 23, 42, 0.12);
}

.sync-icon {
  width: 64px;
  height: 64px;
  display: grid;
  place-items: center;
  justify-self: center;
  border-radius: 18px;
  color: #7c3aed;
  background: #f0e7ff;
  font-size: 34px;
}

.sync-icon--done {
  color: #059669;
  background: #dcfce7;
}

.sync-icon--failed {
  color: #dc2626;
  background: #fee2e2;
}

.sync-heading {
  display: grid;
  gap: 8px;
  text-align: center;
}

.sync-eyebrow {
  color: #64748b;
  font-size: 12px;
  font-weight: 800;
  letter-spacing: 0;
}

.sync-heading h1 {
  margin: 0;
  color: #111827;
  font-size: 24px;
  line-height: 1.25;
}

.sync-heading p {
  margin: 0;
  color: #64748b;
  font-size: 14px;
}

.sync-stats {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 10px;
}

.sync-stats div {
  min-width: 0;
  display: grid;
  gap: 4px;
  padding: 12px;
  border: 1px solid #e2e8f0;
  border-radius: 8px;
  background: #f8fafc;
  text-align: center;
}

.sync-stats strong {
  min-width: 0;
  overflow: hidden;
  color: #111827;
  font-size: 15px;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.sync-stats span {
  color: #64748b;
  font-size: 12px;
}

.sync-footer {
  display: flex;
  align-items: center;
  justify-content: space-between;
  min-height: 34px;
  gap: 12px;
}

@media (max-width: 520px) {
  .sync-route {
    padding: 16px;
  }

  .sync-panel {
    padding: 24px 18px;
  }

  .sync-stats {
    grid-template-columns: 1fr;
  }
}
</style>
