package com.flare.im.app.core.data

import com.flare.im.api.FlareImClient
import com.flare.im.app.core.domain.AppConversation
import com.flare.im.app.core.domain.AppMessage
import com.flare.im.app.core.domain.SdkModelMapper
import com.flare.im.model.command.BootstrapHomeTimelineRequest
import com.flare.im.model.command.OpenConversationTimelineRequest
import com.flare.im.model.command.OpenConversationListViewRequest
import com.flare.im.model.command.OpenTimelineViewRequest
import com.flare.im.model.command.LoadOlderTimelineViewRequest
import com.flare.im.model.command.CloseViewRequest
import com.flare.im.model.entity.ViewUpdate
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update

/**
 * 客户端「视图数据仓库」：把 core 拥有的 observable views 投影到本地 StateFlow。
 * 维护视图数据投影，并**采用 re-fetch-on-signal**：onViewUpdated 触发时
 * 重新拉取权威 typed 快照（bootstrapHome / openConversationTimeline）替换 StateFlow，
 * 而非本地应用 delta（Kotlin SDK 未暴露 snapshot/delta 解码器；core 拥有顺序，client 只投影）。
 * SDK 的 local-first 存储使快照含乐观消息，故乐观态一致。
 */
class ViewDataRepository {
    private val _conversations = MutableStateFlow<List<AppConversation>>(emptyList())
    val conversations: StateFlow<List<AppConversation>> = _conversations.asStateFlow()

    private val _messagesByConversation = MutableStateFlow<Map<String, List<AppMessage>>>(emptyMap())
    val messagesByConversation: StateFlow<Map<String, List<AppMessage>>> = _messagesByConversation.asStateFlow()

    private val _hasMoreByConversation = MutableStateFlow<Map<String, Boolean>>(emptyMap())
    val hasMoreByConversation: StateFlow<Map<String, Boolean>> = _hasMoreByConversation.asStateFlow()

    /** 视图打开诊断日志钩子（注入 SDK Lab 控制台）。 */
    var onLog: ((operation: String, detail: String) -> Unit)? = null

    private var conversationListViewId: String? = null
    private var timelineViewId: String? = null
    private var activeTimelineConversationId: String? = null
    private var timelineLimit: Int = 50

    fun messages(conversationId: String?): List<AppMessage> =
        conversationId?.let { _messagesByConversation.value[it] } ?: emptyList()

    fun hasMore(conversationId: String?): Boolean =
        conversationId?.let { _hasMoreByConversation.value[it] } ?: true

    suspend fun openConversationList(client: FlareImClient, reason: String) {
        runCatching { client.sync.syncConversationSummaries() }
        val home = client.conversations.bootstrapHomeTimeline(BootstrapHomeTimelineRequest(100))
        _conversations.value = SdkModelMapper.conversationsFromCore(home.conversations).sortedByDescending { it.appSortTimestamp }
        val response = client.views.openConversationList(OpenConversationListViewRequest(100))
        conversationListViewId?.takeIf { it != response.viewId }?.let {
            runCatching { client.views.close(CloseViewRequest(it)) }
        }
        conversationListViewId = response.viewId
        onLog?.invoke("view.conversation_list.open", "$reason: ${_conversations.value.size} conversations")
    }

    suspend fun openTimeline(client: FlareImClient, conversationId: String, reason: String) {
        timelineViewId?.let { runCatching { client.views.close(CloseViewRequest(it)) } }
        activeTimelineConversationId = conversationId
        timelineLimit = 50
        val response = client.views.openTimeline(OpenTimelineViewRequest(conversationId, timelineLimit))
        timelineViewId = response.viewId
        refetchTimeline(client, conversationId)
        onLog?.invoke("view.timeline.open", "$reason: ${messages(conversationId).size} messages")
    }

    suspend fun loadOlderTimeline(client: FlareImClient, conversationId: String) {
        val viewId = timelineViewId ?: return
        if (activeTimelineConversationId != conversationId) return
        // 这一页经 view.updated 推来（返回值只有 loadedCount 与版本号）；这里照旧重取权威快照，hasMore 随快照更新。
        client.views.loadOlderTimeline(LoadOlderTimelineViewRequest(viewId, 30))
        timelineLimit += 30
        refetchTimeline(client, conversationId)
    }

    suspend fun refreshAfterMessageEvent(client: FlareImClient, conversationId: String, reason: String) {
        refetchConversationList(client)
        if (activeTimelineConversationId == conversationId) {
            refetchTimeline(client, conversationId)
        }
        onLog?.invoke("message.received", "$reason: $conversationId")
    }

    /** 乐观插入：发送前立即把本地已构建的消息投影到时间线（flare-im-spec: optimistic always）。
     *  随后 ack re-fetch 用权威快照对账（替换 serverId/seq）。 */
    fun insertOptimistic(message: AppMessage) {
        val cid = message.conversationId
        _messagesByConversation.update { map ->
            val list = map[cid].orEmpty()
            if (list.any { it.appStableId == message.appStableId }) map
            else map + (cid to (list + message))
        }
    }

    /** onViewUpdated 入口：对我方视图 re-fetch 权威快照（吞错，与 god-store 行为一致）。 */
    suspend fun apply(client: FlareImClient, update: ViewUpdate) {
        runCatching {
            when (update.viewId) {
                conversationListViewId -> refetchConversationList(client)
                timelineViewId -> activeTimelineConversationId?.let { refetchTimeline(client, it) }
                else -> Unit
            }
        }
    }

    private suspend fun refetchConversationList(client: FlareImClient) {
        val home = client.conversations.bootstrapHomeTimeline(BootstrapHomeTimelineRequest(100))
        _conversations.value = SdkModelMapper.conversationsFromCore(home.conversations).sortedByDescending { it.appSortTimestamp }
    }

    private suspend fun refetchTimeline(client: FlareImClient, conversationId: String) {
        val snapshot = SdkModelMapper.timelineFromCore(
            client.conversations.openConversationTimeline(
                OpenConversationTimelineRequest(conversationId = conversationId, messageLimit = timelineLimit),
            ),
        )
        val ordered = snapshot.messages.sortedBy { it.appSortTimestamp }
        _messagesByConversation.update { it + (conversationId to ordered) }
        _hasMoreByConversation.update { it + (conversationId to snapshot.hasMore) }
        snapshot.conversation?.let(::replaceConversation)
    }

    private fun replaceConversation(conversation: AppConversation) {
        _conversations.update { current ->
            if (current.any { it.conversationId == conversation.conversationId }) {
                current.map { if (it.conversationId == conversation.conversationId) conversation else it }
            } else {
                current + conversation
            }
        }
    }

    fun reset() {
        _conversations.value = emptyList()
        _messagesByConversation.value = emptyMap()
        _hasMoreByConversation.value = emptyMap()
        conversationListViewId = null
        timelineViewId = null
        activeTimelineConversationId = null
    }

    fun clearMessages(conversationId: String) {
        _messagesByConversation.update { it + (conversationId to emptyList()) }
        _hasMoreByConversation.update { it + (conversationId to false) }
    }

    fun removeConversation(conversationId: String) {
        _conversations.update { list -> list.filterNot { it.conversationId == conversationId } }
        _messagesByConversation.update { it - conversationId }
        _hasMoreByConversation.update { it - conversationId }
    }
}
