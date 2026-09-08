<script setup lang="ts">
import { computed } from "vue";
import { AddOutline, ChatbubbleEllipsesOutline, CloseOutline, EllipsisHorizontalOutline, SearchOutline } from "@vicons/ionicons5";
import { NButton, NIcon, NInput } from "naive-ui";
import { useRouter } from "vue-router";
import type { FlareConversationAction } from "@flare-im/vue-ui/contracts";
import { FlareEmptyState, FlareFilterTabs, FlareStatusBanner } from "@flare-im/vue-ui/components";
import { useFlareWorkbenchUi } from "@flare-im/vue-ui/composables";
import {
  ConversationList,
  ConversationListItem,
  useConversationListModel,
  useFlareI18n,
} from "@flare-im/vue-ui/app";
import type { ConversationFilter } from "@flare-im/vue-ui/composables/sdk";

type FlareBannerTone = "info" | "success" | "warning" | "danger" | "neutral";
function statusTone(tone: string | undefined): FlareBannerTone {
  switch (tone) {
    case "success":
    case "warning":
    case "danger":
    case "neutral":
      return tone;
    case "error":
      return "danger";
    default:
      return "info";
  }
}

const router = useRouter();
const workbenchUi = useFlareWorkbenchUi();
const { t } = useFlareI18n();
const {
  sdk,
  conversationSearchOpen,
  conversationSearchQuery,
  filterOptions,
  activeFilter,
  visibleConversations,
  runtimeStatus,
  applyFilter,
} = useConversationListModel();

const conversationStats = computed(() => {
  const pinned = visibleConversations.value.pinned.length;
  const total = pinned + visibleConversations.value.rest.length;
  return {
    total,
    pinned,
    state: sdk.connectionState.value,
  };
});

const conversationStatusText = computed(() => {
  const stats = conversationStats.value;
  return `${stats.total} ${t("conversation.countUnit")} · ${stats.pinned} ${t("conversation.pinnedUnit")} · ${stats.state}`;
});

async function selectConversation(id: string): Promise<void> {
  const selecting = sdk.selectConversation(id);
  await router.push({ name: "chat" });
  await selecting;
}

async function onFilterChange(filter: ConversationFilter): Promise<void> {
  await applyFilter(filter);
}

async function runConversationAction(action: FlareConversationAction, id: string): Promise<void> {
  if (action === "open") {
    await selectConversation(id);
    return;
  }
  await sdk.selectConversation(id);
  await sdk.runConversationOperation(action);
  if (action === "delete" && sdk.activeConversationId.value === id) {
    await router.replace({ name: "conversations" });
  }
}
</script>

<template>
  <section class="flutter-page conversation-route">
    <header class="flutter-list-header">
      <div class="flutter-title-row">
        <div class="conversation-heading">
          <span class="conversation-heading__eyebrow">Flare Core</span>
          <h1>{{ t("conversation.title") }}</h1>
          <span class="conversation-heading__meta">{{ conversationStatusText }}</span>
        </div>
      </div>
      <div class="flutter-header-actions">
        <n-button
          circle
          secondary
          :aria-label="conversationSearchOpen ? t('conversation.searchClose') : t('conversation.searchOpen')"
          @click="conversationSearchOpen = !conversationSearchOpen"
        >
          <template #icon><n-icon :component="conversationSearchOpen ? CloseOutline : SearchOutline" /></template>
        </n-button>
        <n-button circle type="primary" :aria-label="t('conversation.newChat')" @click="workbenchUi.openStartChat()">
          <template #icon><n-icon :component="AddOutline" /></template>
        </n-button>
        <n-button circle secondary :aria-label="t('conversation.moreActions')" @click="workbenchUi.openMore()">
          <template #icon><n-icon :component="EllipsisHorizontalOutline" /></template>
        </n-button>
      </div>
    </header>

    <FlareFilterTabs
      class="conversation-filter-tabs"
      :options="filterOptions"
      :active="activeFilter"
      @change="(v: string) => onFilterChange(v as ConversationFilter)"
    />

    <div v-if="conversationSearchOpen" class="flutter-search">
      <n-input
        v-model:value="conversationSearchQuery"
        round
        clearable
        autofocus
        :placeholder="t('conversation.searchPlaceholder')"
      >
        <template #prefix><n-icon :component="SearchOutline" /></template>
      </n-input>
    </div>

    <FlareStatusBanner
      v-if="runtimeStatus.show"
      class="runtime-status-tabs-banner"
      :text="[runtimeStatus.title, runtimeStatus.detail].filter(Boolean).join(' · ')"
      :tone="statusTone(runtimeStatus.tone)"
      :pulse="runtimeStatus.busy"
    />

    <div class="flutter-divider" />

    <div class="flutter-list-scroll">
      <section
        v-if="sdk.conversationSyncing.value && !visibleConversations.pinned.length && !visibleConversations.rest.length"
        class="flutter-empty conversation-loading"
        role="status"
      >
        <FlareEmptyState
          loading
          :title="t('connection.syncConversations')"
          :description="t('connection.syncDetail')"
        />
      </section>

      <section v-else-if="!visibleConversations.pinned.length && !visibleConversations.rest.length" class="flutter-empty">
        <FlareEmptyState
          :title="conversationSearchQuery ? t('conversation.emptySearchTitle') : t('conversation.emptyTitle')"
          :description="conversationSearchQuery ? t('conversation.emptySearchHint') : t('conversation.emptyHint')"
          :action-text="conversationSearchQuery ? undefined : t('conversation.startChat')"
          @action="workbenchUi.openStartChat()"
        >
          <template #icon><n-icon :component="ChatbubbleEllipsesOutline" :size="56" /></template>
        </FlareEmptyState>
      </section>

      <template v-else>
        <template v-if="visibleConversations.pinned.length">
          <div class="flutter-section-label">{{ t("conversation.pinnedSection") }}</div>
          <ConversationList :items="visibleConversations.pinned" :active-id="sdk.activeConversationId.value">
            <template #item="{ item, active }">
              <ConversationListItem
                :item="item"
                :active="active"
                :draft-preview="item.draft"
                @select="selectConversation"
                @action="runConversationAction"
              />
            </template>
          </ConversationList>
        </template>

        <div
          v-if="visibleConversations.pinned.length && visibleConversations.rest.length"
          class="flutter-section-label"
        >
          {{ t("conversation.allSection") }}
        </div>
        <ConversationList
          v-if="visibleConversations.rest.length"
          :items="visibleConversations.rest"
          :active-id="sdk.activeConversationId.value"
        >
          <template #item="{ item, active }">
            <ConversationListItem
              :item="item"
              :active="active"
              :draft-preview="item.draft"
              @select="selectConversation"
              @action="runConversationAction"
            />
          </template>
        </ConversationList>
      </template>
    </div>
  </section>
</template>
