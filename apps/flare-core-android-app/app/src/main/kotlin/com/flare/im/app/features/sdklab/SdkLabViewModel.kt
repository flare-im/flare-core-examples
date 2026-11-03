package com.flare.im.app.features.sdklab

import com.flare.im.api.FlareImClient
import com.flare.im.app.core.data.AppEnvironment
import com.flare.im.app.core.session.AppLifecycle
import com.flare.im.app.core.session.AppSession
import com.flare.im.model.command.NetworkChangeRequest
import com.flare.im.model.command.SetHeartbeatAppStateRequest
import com.flare.im.model.command.SetHeartbeatNatTimeoutRequest
import com.flare.im.model.command.NormalizeRichDocFromDocJsonRequest
import com.flare.im.model.command.NormalizeRichDocFromHtmlRequest
import com.flare.im.model.command.NormalizeRichDocFromMarkdownRequest
import com.flare.im.model.command.message.SendMessageRequest
import com.flare.im.model.command.message.build.BuildTextMessageRequest
import com.flare.im.model.entity.HeartbeatAppState
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

/** SDK Lab 草稿输入。 */
data class LabDraft(
    val mediaFileId: String = "demo-file",
    val mediaFilePath: String = "",
    val cacheMaxBytes: String = "52428800",
    val downloadSubfolder: String = "flare-downloads",
    val capabilityUserId: String = "",
    val capability: String = "rtc.call",
    val operation: String = "invite",
    val callSignalType: String = "offer",
    val payloadJson: String = "{}",
)

/**
 * SDK Lab 特性 ViewModel：诊断 / 生命周期 / 会话·消息探针 /
 * 媒体中心 / 能力中心 / 事件 / presence / sync —— 穷尽长尾 op，达成与 同等覆盖。
 * 每个探针把结果写入 environment.labResults。
 */
class SdkLabViewModel(
    private val session: AppSession,
    private val environment: AppEnvironment,
    private val scope: CoroutineScope,
) {
    private var lifecycle: AppLifecycle? = null
    fun bind(lifecycle: AppLifecycle) { this.lifecycle = lifecycle }
    fun logout() = scope.launch { lifecycle?.logout() }
    fun dispose() = scope.launch { lifecycle?.dispose() }

    private val client: FlareImClient? get() = session.client

    val labResults get() = environment.labResults
    val eventLog get() = session.eventLog
    val connectionState get() = session.connectionState
    val currentUserId get() = session.currentUserId

    private val _draft = MutableStateFlow(LabDraft())
    val draft: StateFlow<LabDraft> = _draft.asStateFlow()
    fun updateDraft(transform: (LabDraft) -> LabDraft) = _draft.update(transform)

    private fun probe(operation: String, body: suspend (FlareImClient) -> Any?) = scope.launch {
        environment.run(operation, showBusy = false) {
            val sdk = client ?: error("Login before running lab operations")
            val result = body(sdk)
            environment.appendLab(operation, "ok", result?.toString()?.take(400) ?: "")
        }
    }

    // ---- Diagnostics ----
    fun refreshDiagnostics() {
        probe("diagnostics.getRuntimeHealth") { it.diagnostics.getRuntimeHealth() }
        probe("diagnostics.getSdkVersion") { it.diagnostics.getSdkVersion() }
        probe("diagnostics.getFfiContractVersion") { it.diagnostics.getFfiContractVersion() }
        probe("diagnostics.getDataRoot") { it.diagnostics.getDataRoot() }
    }

    // ---- Lifecycle / session / connection ----
    fun runPrepare() = probe("session.prepare") { it.prepare(mapOf("warm" to true)) }
    fun runUninit() = probe("session.uninit") { it.uninit() }
    fun runHardReset() = probe("session.hardReset") { it.hardReset() }
    fun runHeartbeatInterval() = probe("session.heartbeatEffectiveInterval") { it.heartbeatEffectiveInterval() }
    fun runSetHeartbeatAppState() = probe("session.setHeartbeatAppState") { it.setHeartbeatAppState(SetHeartbeatAppStateRequest(HeartbeatAppState.FOREGROUND)) }
    fun runSetHeartbeatNatTimeout() = probe("session.setHeartbeatNatTimeout") { it.setHeartbeatNatTimeout(SetHeartbeatNatTimeoutRequest(30)) }
    fun runUpdateAccessToken() = probe("session.updateAccessToken") { it.updateAccessToken(mapOf("token" to "")) }
    fun runIsConnected() = probe("session.isConnected") { it.isConnected() }
    fun runSessionActive() = probe("session.sessionActive") { it.sessionActive() }
    fun runConnect() = probe("session.connect") { it.connect(emptyMap()) }
    fun runCurrentUserId() = probe("session.currentUserId") { it.currentUserId() }
    fun runDisconnect() = probe("connection.disconnect") { it.connection.disconnect() }
    fun runConnectionState() = probe("connection.getConnectionState") { it.connection.getConnectionState() }
    fun runNotifyNetworkChange() = probe("connection.notifyNetworkChange") {
        it.connection.notifyNetworkChange(NetworkChangeRequest(available = true, expensive = false, metered = false, reason = "lab"))
    }

    // ---- Conversation probes ----
    fun runListConversations() = probe("conversations.listConversations") { it.conversations.listConversations() }
    fun runListConversationsPaginated() = probe("conversations.listConversationsPaginated") { it.conversations.listConversationsPaginated(mapOf("limit" to 50)) }
    fun runListRawConversations() = probe("conversations.listRawConversations") { it.conversations.listRawConversations() }
    fun runListConversationsIncludingArchived() = probe("conversations.listConversationsIncludingArchived") { it.conversations.listConversationsIncludingArchived() }

    // ---- Message probes ----
    fun runGetRawMessage(conversationId: String, messageId: String) = probe("messages.getRawMessage") {
        it.messages.getRawMessage(mapOf("conversationId" to conversationId, "messageId" to messageId))
    }
    fun runGetMessage(conversationId: String, messageId: String) = probe("messages.getMessage") {
        it.messages.getMessage(mapOf("conversationId" to conversationId, "messageId" to messageId))
    }
    fun runMarkMessageWithColor(conversationId: String, messageId: String) = probe("messages.markMessageWithColor") {
        it.messages.markMessageWithColor(mapOf("conversationId" to conversationId, "messageId" to messageId, "color" to "red"))
    }
    fun runMarkMessageReadAndBurn(conversationId: String, messageId: String) = probe("messages.markMessageReadAndBurn") {
        it.messages.markMessageReadAndBurn(mapOf("conversationId" to conversationId, "messageId" to messageId))
    }
    fun runSendMessageNoOss(conversationId: String) = probe("messages.sendMessageNoOss") { sdk ->
        val msg = sdk.messageBuilder.buildText(BuildTextMessageRequest(conversationId, "No-OSS probe"))
        sdk.messages.sendMessageNoOss(SendMessageRequest(msg))
    }
    fun runListMessages(conversationId: String) = probe("messages.listMessages") {
        it.messages.listMessages(com.flare.im.model.query.ListMessagesRequest(conversationId, 0L, 50))
    }
    fun runCreateTextMessage(conversationId: String) = probe("messages.createTextMessage") {
        it.messages.createTextMessage(com.flare.im.model.command.message.CreateTextMessageRequest(conversationId, "Created via Lab"))
    }

    // ---- Message builder catalog / normalize ----
    fun refreshBuilderCatalog() = probe("message_builder.listSupportedBuildOperations") { it.messageBuilder.listSupportedBuildOperations() }
    fun runNormalizeMarkdown() = probe("message_builder.normalizeRichDocFromMarkdown") { it.messageBuilder.normalizeRichDocFromMarkdown(NormalizeRichDocFromMarkdownRequest("## Hello")) }
    fun runNormalizeHtml() = probe("message_builder.normalizeRichDocFromHtml") { it.messageBuilder.normalizeRichDocFromHtml(NormalizeRichDocFromHtmlRequest("<h2>Hello</h2>")) }
    fun runNormalizeDocJson() = probe("message_builder.normalizeRichDocFromDocJson") { it.messageBuilder.normalizeRichDocFromDocJson(NormalizeRichDocFromDocJsonRequest("{\"type\":\"doc\",\"version\":2,\"children\":[]}")) }

    // ---- Presence ----
    fun runPresenceCurrent() {
        val uid = currentUserId.value ?: "self"
        probe("presence.getUserPresence") { it.presence.getUserPresence(mapOf("userId" to uid)) }
    }
    fun runPresenceBatchSubscribe() {
        val uid = currentUserId.value ?: "self"
        probe("presence.batchGetUserPresence") { it.presence.batchGetUserPresence(mapOf("userIds" to listOf(uid))) }
        probe("presence.subscribeUserPresence") { it.presence.subscribeUserPresence(mapOf("userIds" to listOf(uid))) }
    }

    // ---- User identity cache ----
    fun runUpsertUserProfiles() {
        val uid = currentUserId.value ?: "self"
        probe("user.upsertUserProfiles") {
            it.user.upsertUserProfiles(
                mapOf(
                    "profiles" to listOf(
                        mapOf("userId" to uid, "nickname" to "SDK Lab nickname", "avatarUrl" to ""),
                    ),
                ),
            )
        }
    }

    // ---- Capabilities ----
    fun refreshCapabilities() {
        probe("capabilities.listCapabilities") { it.capabilities.listCapabilities(emptyMap()) }
        val uid = draft.value.capabilityUserId.ifBlank { currentUserId.value ?: "self" }
        probe("capabilities.listUserCapabilities") { it.capabilities.listUserCapabilities(mapOf("userId" to uid)) }
    }
    fun runDispatchCapability() = probe("capabilities.dispatchCapability") {
        it.capabilities.dispatchCapability(mapOf("capability" to draft.value.capability, "operation" to draft.value.operation, "payload" to draft.value.payloadJson))
    }
    fun runGrantCapability() = probe("capabilities.grantCapability") {
        it.capabilities.grantCapability(mapOf("userId" to draft.value.capabilityUserId, "capability" to draft.value.capability))
    }
    fun runRevokeCapability() = probe("capabilities.revokeCapability") {
        it.capabilities.revokeCapability(mapOf("userId" to draft.value.capabilityUserId, "capability" to draft.value.capability))
    }
    fun runSendCallSignal() = probe("capabilities.sendCallSignal") {
        it.capabilities.sendCallSignal(mapOf("type" to draft.value.callSignalType, "payload" to draft.value.payloadJson))
    }

    // ---- Media center ----
    fun runMediaCacheStats() = probe("media.getMediaCacheStats") { it.media.getMediaCacheStats() }
    fun runMediaUrl() = probe("media.getMediaUrl") { it.media.getMediaUrl(mapOf("fileId" to draft.value.mediaFileId)) }
    fun runTempDownloadUrl() = probe("media.getTempDownloadUrl") { it.media.getTempDownloadUrl(mapOf("fileId" to draft.value.mediaFileId)) }
    fun runResolveMediaAccess() = probe("media.resolveMediaAccess") { it.media.resolveMediaAccess(mapOf("fileId" to draft.value.mediaFileId)) }
    fun runCacheRemoteMedia() = probe("media.cacheRemoteMedia") { it.media.cacheRemoteMedia(mapOf("fileId" to draft.value.mediaFileId)) }
    fun runUploadFile() = probe("media.uploadFile") { it.media.uploadFile(mapOf("path" to draft.value.mediaFilePath)) }
    fun runUploadImage() = probe("media.uploadImage") { it.media.uploadImage(mapOf("path" to draft.value.mediaFilePath)) }
    fun runUploadVideo() = probe("media.uploadVideo") { it.media.uploadVideo(mapOf("path" to draft.value.mediaFilePath)) }
    fun runUploadBytes() = probe("media.uploadBytes") { it.media.uploadBytes(mapOf("bytes" to ByteArray(0), "name" to "probe.bin")) }
    fun runDeleteFile() = probe("media.deleteFile") { it.media.deleteFile(mapOf("fileId" to draft.value.mediaFileId)) }
    fun runSetCacheMaxBytes() = probe("media.setMediaCacheMaxBytes") { it.media.setMediaCacheMaxBytes(mapOf("maxBytes" to (draft.value.cacheMaxBytes.toLongOrNull() ?: 52428800L))) }
    fun runSetCacheRoot() = probe("media.setMediaCacheRoot") { it.media.setMediaCacheRoot(mapOf("path" to draft.value.downloadSubfolder)) }
    fun runClearMediaCache() = probe("media.clearMediaCache") { it.media.clearMediaCache() }
    fun runGetDownloadSubfolder() = probe("media.getUserDownloadSubfolder") { it.media.getUserDownloadSubfolder() }
    fun runSetDownloadSubfolder() = probe("media.setUserDownloadSubfolder") { it.media.setUserDownloadSubfolder(mapOf("subfolder" to draft.value.downloadSubfolder)) }
    fun runGetDownloadSavedPath() = probe("media.getUserDownloadSavedPath") { it.media.getUserDownloadSavedPath(mapOf("fileId" to draft.value.mediaFileId)) }
    fun runDeleteDownloadRecord() = probe("media.deleteUserDownloadRecord") { it.media.deleteUserDownloadRecord(mapOf("fileId" to draft.value.mediaFileId)) }
    fun runCancelDownload() = probe("media.cancelUserFileDownload") { it.media.cancelUserFileDownload(mapOf("fileId" to draft.value.mediaFileId)) }
    fun runDownloadToDownloads() = probe("media.downloadFileToDownloads") { it.media.downloadFileToDownloads(mapOf("fileId" to draft.value.mediaFileId)) }

    // ---- Sync ----
    fun runSyncConversation(conversationId: String) = probe("sync.syncConversation") { it.sync.syncConversation(mapOf("conversationId" to conversationId)) }
    fun runSyncMessages(conversationId: String) = probe("sync.syncMessages") { it.sync.syncMessages(mapOf("conversationId" to conversationId)) }
    fun runSyncSummaries() = probe("sync.syncConversationSummaries") { it.sync.syncConversationSummaries() }

    // ---- Events ----
    fun runSubscribeEvents() = probe("events.subscribeEvents") { it.events.subscribeEvents(mapOf("domains" to listOf("message", "conversation", "connection"))) }
    fun runSubscribeEventsBatch() = probe("events.subscribeEventsBatch") { it.events.subscribeEventsBatch(mapOf("domains" to listOf("message", "conversation"))) }
    fun runUnsubscribeAll() = probe("events.unsubscribeAll") { it.events.unsubscribeAll() }
}
