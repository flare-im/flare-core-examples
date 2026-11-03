package com.flare.im.app.features.messaging

import android.util.Log
import com.flare.im.api.FlareImClient
import com.flare.im.app.core.data.AppEnvironment
import com.flare.im.app.core.data.ViewDataRepository
import com.flare.im.app.core.domain.ConversationFilter
import com.flare.im.app.core.domain.MessageBuildOp
import com.flare.im.app.core.domain.MessageBuilder
import com.flare.im.api.ConnectionState
import com.flare.im.app.core.session.AppLifecycle
import com.flare.im.app.core.session.AppSession
import com.flare.im.app.core.domain.AppConversation
import com.flare.im.app.core.domain.AppMessage
import com.flare.im.app.core.domain.SdkModelMapper
import com.flare.im.app.core.domain.PictureAccess
import com.flare.im.app.core.domain.PictureAccessEntry
import com.flare.im.app.core.domain.PictureAccessPolicy
import com.flare.im.app.core.domain.SavedMedia
import com.flare.im.app.core.domain.mediaSaveRequest
import com.flare.im.app.core.domain.pictureAccessFrom
import com.flare.im.app.core.domain.pictureFileIdOf
import com.flare.im.app.core.domain.savedMediaFrom
import com.flare.im.model.command.message.SendMessageRequest
import com.flare.im.model.entity.Message
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.combine
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import com.flare.im.ui.FlareMessageActionAvailability

/** 起会话草稿。 */
data class StartConversationDraft(
    val peerUserId: String = "",
    val groupUserIds: String = "",
)

/**
 * 消息特性 ViewModel：会话列表 + 时间线 + 全部消息/会话操作。
 * 持共享 session/repository/environment + weak lifecycle；经 scope 调 SDK（Map 形态 payload）。
 */
/** 标记类型「重要」（核心 MarkType::Important）。 */
private const val MARK_TYPE_IMPORTANT = 1

/** 标记默认色；核心要求 color 非空，不关心颜色时用它。 */
private const val DEFAULT_MARK_COLOR = "#F5A623"

class MessagingViewModel(
    private val session: AppSession,
    private val repository: ViewDataRepository,
    private val environment: AppEnvironment,
    private val scope: CoroutineScope,
) {
    private var lifecycle: AppLifecycle? = null
    fun bind(lifecycle: AppLifecycle) {
        this.lifecycle = lifecycle
        session.onViewUpdate = { update ->
            scope.launch {
                client?.let { repository.apply(it, update) }
            }
        }
        session.onMessageReceived = { conversationId ->
            scope.launch {
                val sdk = client ?: return@launch
                repository.refreshAfterMessageEvent(sdk, conversationId, "realtime")
                if (environment.selectedConversationId.value == conversationId) {
                    maxPositiveSeq(repository.messages(conversationId))?.let { readSeq ->
                        sdk.conversations.markConversationRead(mapOf("conversationId" to conversationId, "readSeq" to readSeq))
                    }
                }
            }
        }
    }

    private val client: FlareImClient? get() = session.client

    val conversations: StateFlow<List<AppConversation>> = repository.conversations
    val runtimeStatus get() = environment.runtimeStatus
    val currentUserId get() = session.currentUserId
    val lastError get() = environment.lastError

    private val _pendingMessageKeys = MutableStateFlow<Set<String>>(emptySet())
    val pendingMessageKeys: StateFlow<Set<String>> = _pendingMessageKeys.asStateFlow()
    private val _failedMessageKeys = MutableStateFlow<Set<String>>(emptySet())
    val failedMessageKeys: StateFlow<Set<String>> = _failedMessageKeys.asStateFlow()
    /** 本会话内已置顶的消息，用来把 Pin/Unpin 收成一个正确的开关。
     *  wire 上的 Message 没有 pinned 字段，所以只能本地跟踪；
     *  重进会话会丢，但总好过同时常显 Pin 与 Unpin（其中一个必然是错的）。 */
    private val _pinnedMessageKeys = MutableStateFlow<Set<String>>(emptySet())
    /** 正在回复的目标消息；非空时 composer 顶部显示引用条，发送走引用消息。 */
    private val _replyTarget = MutableStateFlow<AppMessage?>(null)
    val replyTarget: StateFlow<AppMessage?> = _replyTarget.asStateFlow()

    fun replyTo(message: AppMessage) { _replyTarget.value = message }
    fun cancelReply() { _replyTarget.value = null }

    private val _startConversationDraft = MutableStateFlow(StartConversationDraft())
    val startConversationDraft: StateFlow<StartConversationDraft> = _startConversationDraft.asStateFlow()
    fun updateStartDraft(transform: (StartConversationDraft) -> StartConversationDraft) = _startConversationDraft.update(transform)

    /** 按当前过滤可见的会话。 */
    val visibleConversations: StateFlow<List<AppConversation>> =
        combine(repository.conversations, environment.filter) { list, filter -> list.filter { matchesFilter(it, filter) } }
            .stateIn(scope, SharingStarted.Eagerly, emptyList())

    val selectedConversation: StateFlow<AppConversation?> =
        combine(repository.conversations, environment.selectedConversationId) { list, id ->
            id?.let { sel -> list.firstOrNull { it.conversationId == sel } }
        }.stateIn(scope, SharingStarted.Eagerly, null)

    val selectedMessages: StateFlow<List<AppMessage>> =
        combine(repository.messagesByConversation, environment.selectedConversationId) { byId, id ->
            id?.let { byId[it] } ?: emptyList()
        }.stateIn(scope, SharingStarted.Eagerly, emptyList())

    val selectedHasMore: StateFlow<Boolean> =
        combine(repository.hasMoreByConversation, environment.selectedConversationId) { byId, id ->
            id?.let { byId[it] } ?: true
        }.stateIn(scope, SharingStarted.Eagerly, true)

    /** 由 session 的 send-failed 事件路由进来。 */
    fun markSendFailed(key: String) { _failedMessageKeys.update { it + key } }

    fun logout() = scope.launch { lifecycle?.logout() }

    fun refreshConversations() = scope.launch {
        environment.run("view.conversation_list.open") { syncConversationList("refresh") }
    }

    fun bootstrapHome() = scope.launch {
        environment.run("view.conversation_list.open") {
            syncConversationList("bootstrap")
            environment.selectedConversationId.value?.let { openConversationInternal(it) }
        }
    }

    fun openConversation(conversationId: String) = scope.launch { openConversationInternal(conversationId) }

    private suspend fun openConversationInternal(conversationId: String) {
        environment.run("view.timeline.open") {
            val sdk = client ?: error("Login before opening a conversation")
            environment.setSelectedConversationId(conversationId)
            repository.openTimeline(sdk, conversationId, "open")
            maxPositiveSeq(repository.messages(conversationId))?.let { readSeq ->
                sdk.conversations.markConversationRead(mapOf("conversationId" to conversationId, "readSeq" to readSeq))
            }
        }
    }

    fun loadOlderMessages() = scope.launch {
        val id = environment.selectedConversationId.value ?: return@launch
        environment.run("view.timeline.load_older", showBusy = false) {
            client?.let { repository.loadOlderTimeline(it, id) }
        }
    }

    fun sendText(text: String): Unit = sendTextBlocking(text).let {}
    private fun sendTextBlocking(text: String) = scope.launch {
        val trimmed = text.trim()
        val conversationId = environment.selectedConversationId.value ?: return@launch
        if (trimmed.isEmpty()) return@launch
        val replying = _replyTarget.value
        environment.run(if (replying == null) "message.send_text" else "message.send_quote") {
            val sdk = client ?: error("Login before sending messages")
            // 有回复目标就发引用消息：正文是用户真正输入的内容，
            // 而不是 SDK Lab 里那个写死的 "Quoted from Android SDK Lab"。
            val message = if (replying == null) {
                sdk.messageBuilder.buildText(
                    com.flare.im.model.command.message.build.BuildTextMessageRequest(conversationId, trimmed),
                )
            } else {
                MessageBuilder.build(
                    sdk,
                    conversationId,
                    MessageBuildOp.CreateQuote,
                    mapOf(
                        "quotedMessageId" to replying.core.serverId.ifBlank { replying.core.clientMsgId },
                        "text" to trimmed,
                    ),
                    listOf(replying),
                )
            }
            _replyTarget.value = null
            sendBuilt(sdk, message, conversationId)
        }
    }

    /** 图片选择 → media.uploadImage（best-effort，需后端）→ buildImage → 发送。 */
    fun sendPickedImage(path: String) = scope.launch {
        val conversationId = environment.selectedConversationId.value ?: return@launch
        environment.run("media.uploadImage") {
            val sdk = client ?: error("Login before sending images")
            val imageId = "picked-${System.currentTimeMillis()}"
            runCatching { sdk.media.uploadImage(mapOf("path" to path, "imageId" to imageId)) }
            val message = MessageBuilder.build(
                sdk, conversationId, MessageBuildOp.CreateImage,
                mapOf("imageId" to imageId, "sourceUrl" to path, "description" to "Picked image"),
                selectedMessages.value,
            )
            sendBuilt(sdk, message, conversationId)
        }
    }

    /** 宿主文件选择器 → CreateFile（真实名字 / mime / 大小，不再用表单里的假值）。 */
    fun sendPickedFile(name: String, uri: String?, mimeType: String?, size: Long?) = buildAndSend(
        MessageBuildOp.CreateFile,
        buildMap<String, Any?> {
            put("fileId", "picked-${System.currentTimeMillis()}")
            put("fileName", name.ifBlank { "file" })
            uri?.takeIf { it.isNotBlank() }?.let { put("url", it) }
            mimeType?.takeIf { it.isNotBlank() }?.let { put("mimeType", it) }
            size?.let { put("size", it) }
        },
    )

    /** 平台契约错误（CANCELLED 之外）记进 Lab 日志，和 send 失败同一条通道。 */
    fun notePlatformError(operation: String, detail: String) = environment.appendLab(operation, "error", detail)

    /** Await acceptance so the voice composer can retain a failed clip for retry. */
    suspend fun sendVoiceClip(path: String, durationMs: Int): Boolean {
        val conversationId = environment.selectedConversationId.value ?: return false
        val sdk = client ?: return false
        return try {
            val message = MessageBuilder.build(sdk, conversationId, MessageBuildOp.CreateAudio,
                mapOf("audioId" to path, "sourcePath" to path, "sourceUrl" to path, "mimeType" to "audio/wav", "durationMs" to durationMs), selectedMessages.value)
            sendBuilt(sdk, message, conversationId)
            true
        } catch (error: Throwable) { environment.appendLab("voice.send", "error", error.message ?: "Failed"); false }
    }
    fun sendAudio(path: String, durationMs: Int) = scope.launch { sendVoiceClip(path, durationMs) }

    fun buildAndSend(op: MessageBuildOp, payload: Map<String, Any?> = emptyMap()) = scope.launch {
        val conversationId = environment.selectedConversationId.value ?: return@launch
        environment.run("message_builder.${op.name}") {
            val sdk = client ?: error("Login before building messages")
            val message = MessageBuilder.build(sdk, conversationId, op, payload, selectedMessages.value)
            sendBuilt(sdk, message, conversationId)
        }
    }

    private suspend fun sendBuilt(sdk: FlareImClient, message: Message, conversationId: String) {
        val appMessage = SdkModelMapper.messageFromCore(message)
        val key = appMessage.appStableId
        // 乐观：发送前立即显示（optimistic always）；ack 后 re-fetch 用权威快照对账。
        repository.insertOptimistic(appMessage)
        _pendingMessageKeys.update { it + key }
        try {
            val ack = sdk.messages.sendMessage(SendMessageRequest(message), null)
            _pendingMessageKeys.update { it - key }
            environment.appendLab("message.send", "ok", "seq ${ack.seq}, server ${ack.serverId}")
            repository.openTimeline(sdk, conversationId, "send")
        } catch (error: Throwable) {
            _pendingMessageKeys.update { it - key }
            _failedMessageKeys.update { it + key }
            val detail = error.message ?: error.toString()
            environment.appendLab("message.send", "error", detail)
            Log.e("FlareAndroidSmoke", "message.send failed", error)
            throw error
        }
    }

    fun retry(message: AppMessage) = scope.launch {
        environment.run("message.retry") {
            val sdk = client ?: error("Login before retrying messages")
            _failedMessageKeys.update { it - message.appStableId }
            sendBuilt(sdk, message.core, message.conversationId)
        }
    }

    /**
     * 解析消息媒体到可显示 URL：本地路径直接用；远端经 `media.resolveMediaAccess(fileId)` 换签名 URL。
     * 解析媒体展示地址。失败兜底直链。
     */
    suspend fun resolveMediaUrl(message: AppMessage): String? {
        // A picture: the core's cached copy when there is one, else its signed URL (the core caches it meanwhile).
        resolvePicture(message)?.let { access -> (access.localPath ?: access.url)?.let { return it } }
        val data = message.core.content?.data ?: return null
        fun pick(keys: List<String>): String? {
            for (k in keys) (data[k] as? String)?.trim()?.takeIf { it.isNotEmpty() }?.let { return it }
            (data["source"] as? Map<*, *>)?.let { src ->
                for (k in keys) (src[k] as? String)?.trim()?.takeIf { it.isNotEmpty() }?.let { return it }
            }
            return null
        }
        val urlKeys = listOf(
            "sourceUrl", "source_url", "url", "cdnUrl", "cdn_url", "mediaUrl", "media_url",
            "downloadUrl", "download_url", "accessUrl", "access_url", "tempUrl", "temp_url",
            "signedUrl", "signed_url", "path", "localPath",
        )
        val direct = pick(urlKeys)
        if (direct != null && (direct.startsWith("content://") || direct.startsWith("file://") || direct.startsWith("/"))) return direct
        val fileId = pick(listOf("fileId", "file_id", "imageId", "audioId", "videoId", "mediaId", "media_id", "uuid", "id"))
        val sdk = client
        if (fileId != null && sdk != null) {
            // 优先经 SDK 托管磁盘缓存拿本地路径（去重 + LRU + 离线，不重复下载）。
            val cached = runCatching { sdk.media.cacheRemoteMedia(mapOf("fileId" to fileId, "expiresIn" to 3600)) }.getOrNull()
            (cached?.get("localPath") as? String)?.trim()?.takeIf { it.isNotEmpty() }?.let { return it }
            // 退而求其次：签名 URL（不落缓存）。
            val resolved = runCatching { sdk.media.resolveMediaAccess(mapOf("fileId" to fileId, "expiresIn" to 3600)) }.getOrNull()
            if (resolved != null) {
                for (k in urlKeys) (resolved[k] as? String)?.trim()?.takeIf { it.isNotEmpty() }?.let { return it }
            }
        }
        return direct
    }

    /** What each picture id resolved to last ([PictureAccessPolicy]). */
    private val pictureAccess = java.util.concurrent.ConcurrentHashMap<String, PictureAccessEntry>()

    /**
     * Where [message]'s picture is drawn from — `media.resolve_access` with `autoCache`: the core's cached copy when
     * there is one, else a signed URL while the core caches the picture in the background, so a picture seen once is
     * not downloaded again. Null for a message without a stored picture id, or when the core cannot answer.
     */
    suspend fun resolvePicture(message: AppMessage): PictureAccess? {
        val fileId = pictureFileIdOf(message.core.content) ?: return null
        val sdk = client ?: return null
        val now = System.currentTimeMillis()
        val cached = pictureAccess[fileId]
        if (cached != null && PictureAccessPolicy.reusable(
                cached, now, localExists = cached.access.localPath?.let { java.io.File(it).isFile } ?: false,
            )
        ) return cached.access
        val answer = runCatching { sdk.media.resolveMediaAccess(mapOf("fileId" to fileId, "autoCache" to true)) }
            .onFailure { environment.appendLab("media.resolve_access", "error", it.message ?: "$it") }
            .getOrNull()
            ?.let(::pictureAccessFrom)
            ?.takeIf { it.localPath != null || it.url != null }
            ?: return cached?.access?.takeIf { it.localPath == null }
        pictureAccess[fileId] = PictureAccessPolicy.next(cached, answer, now)
        return answer
    }

    /**
     * Saves [message]'s media to the device's download location through the core (`media.download_to_user_directory`:
     * the cached copy when there is one, else the attachment; a camera-style or the sender's file name). [onDone] gets
     * the saved file or what went wrong — the screen says it; nothing is left only in the lab log.
     */
    fun saveMedia(message: AppMessage, onDone: (Result<SavedMedia>) -> Unit): Boolean {
        val key = message.appStableId
        // One save per message at a time: a second tap while it runs is not a second file.
        if (!savingKeys.add(key)) return false
        scope.launch {
            val result = runCatching {
                val sdk = client ?: error("Login before saving media")
                // Only this account's own messages may name a file on this device as the source.
                val outgoing = message.core.senderId.isNotEmpty() && message.core.senderId == session.currentUserId.value
                val request = mediaSaveRequest(message.core.content, allowLocalSource = outgoing, localExists = { java.io.File(it).isFile })
                    ?: throw NoSuchElementException("No saveable media in this message")
                savedMediaFrom(sdk.media.downloadToUserDirectory(request))
            }
            savingKeys.remove(key)
            result.onSuccess { environment.appendLab("media.download_to_user_directory", "ok", it.path) }
                .onFailure { environment.appendLab("media.download_to_user_directory", "error", it.message ?: "$it") }
            onDone(result)
        }
        return true
    }

    private val savingKeys: MutableSet<String> = java.util.concurrent.ConcurrentHashMap.newKeySet()

    /** Forget the resolved pictures (the cache was cleared): the next row asks the core again. */
    fun forgetResolvedPictures() = pictureAccess.clear()

    /** 一条消息此刻可用的动作，由**核心**判定（规则在 `domain::message_actions`），交给 kit 的消息面板。 */
    suspend fun actionAvailability(message: AppMessage): FlareMessageActionAvailability {
        val sdk = client ?: return FlareMessageActionAvailability()
        val key = message.appStableId
        // dispatchMessage 的请求是平铺的：`op` 与参数字段同层（桥把 `op` 取出，其余整体作为参数 JSON，
        // 与 Apple 桥一致）。此前参数包在 `params` 里，核心读不到 messageId 而报错，
        // 错误又被吞掉，长按只剩一个空菜单。
        val answer = runCatching {
            sdk.messages.dispatchMessage(
                mapOf(
                    "op" to "action_availability",
                    "messageId" to (message.core.serverId.ifBlank { message.core.clientMsgId }),
                    "multiSelectMode" to false,
                    "isPending" to (key in _pendingMessageKeys.value),
                    "isFailed" to (key in _failedMessageKeys.value),
                    "isPinned" to (key in _pinnedMessageKeys.value),
                    "isConnected" to (session.connectionState.value in
                        setOf(ConnectionState.CONNECTED, ConnectionState.READY)),
                ),
            )
        }.onFailure { error ->
            Log.w("FlareMessageActions", "action_availability failed for $key", error)
        }.getOrDefault(emptyMap())
        return FlareMessageActionAvailability.fromJson(answer)
    }

    fun messageAction(
        action: String,
        message: AppMessage,
        reaction: String = "like",
        text: String = "",
    ) = scope.launch {
        environment.run("message.$action") {
            val sdk = client ?: error("Login before message actions")
            val req = mutationRequest(message)
            when (action) {
                "recall" -> sdk.messages.recallMessage(req)
                // 正文由调用方给：曾经写死 "Edited from Android example"，
                // 点一下"编辑"就把用户的原文替换成占位串，且没有任何输入入口。
                "edit" -> sdk.messages.editTextByMessageId(req + ("text" to text))
                "editRich" -> sdk.messages.editRichDocByMessageId(req + ("markdown" to "## Edited rich doc\n\n- **bold** point\n- _italic_ point"))
                "deleteSelf" -> sdk.messages.deleteMessageForSelf(req)
                "deleteEveryone" -> sdk.messages.deleteMessageForEveryone(req)
                // 核心读的是 emoji（add_reaction/remove_reaction）。发成 reaction 时核心回
                // INVALID_PARAMETER，错误只进实验室日志，界面上点了表情毫无反应。
                "react" -> sdk.messages.addReaction(req + ("emoji" to reaction))
                "unreact" -> sdk.messages.removeReaction(req + ("emoji" to reaction))
                "pin" -> {
                    sdk.messages.pinMessageById(req + ("scope" to 0))
                    _pinnedMessageKeys.update { it + message.appStableId }
                }
                "pinSelf" -> sdk.messages.pinMessageById(req + ("scope" to 1))
                "unpin" -> {
                    sdk.messages.unpinMessageById(req + ("scope" to 0))
                    _pinnedMessageKeys.update { it - message.appStableId }
                }
                // mark_by_message_id 要 markType(i32) + color(非空字符串)，unmark 要 markType；
                // 只发消息 id 必然 INVALID_PARAMETER。取值与 web 参考示例一致（重要 + 默认色）。
                "mark" -> sdk.messages.markMessageById(req + ("markType" to MARK_TYPE_IMPORTANT) + ("color" to DEFAULT_MARK_COLOR))
                "unmark" -> sdk.messages.unmarkMessageById(req + ("markType" to MARK_TYPE_IMPORTANT))
                else -> error("Unsupported action $action")
            }
            openConversationInternal(message.conversationId)
        }
    }

    fun setTyping(typing: Boolean) = scope.launch {
        val id = environment.selectedConversationId.value ?: return@launch
        environment.run("message.typing", showBusy = false) {
            client?.messages?.setTyping(mapOf("conversationId" to id, "typing" to typing))
        }
    }

    fun openPeerConversation() = scope.launch {
        val peer = startConversationDraft.value.peerUserId.trim()
        if (peer.isEmpty()) return@launch
        environment.run("conversation.get_one") {
            val sdk = client ?: error("Login before starting chat")
            val conv = sdk.conversations.getOneConversation(mapOf("sourceId" to peer, "conversationType" to "single"))
            openConversationInternal(conv.conversationId)
            syncConversationList("open_peer")
        }
    }

    fun openGroupConversation() = scope.launch {
        val ids = startConversationDraft.value.groupUserIds.split(",").map { it.trim() }.filter { it.isNotEmpty() }
        if (ids.isEmpty()) return@launch
        environment.run("conversation.get_group_by_user_ids") {
            val sdk = client ?: error("Login before starting group chat")
            val conv = sdk.conversations.getGroupConversationByUserIds(mapOf("userIds" to ids))
            openConversationInternal(conv.conversationId)
            syncConversationList("open_group")
        }
    }

    fun conversationAction(action: String, conversation: AppConversation) = scope.launch {
        environment.run("conversation.$action") {
            val sdk = client ?: error("Login before conversation actions")
            val req = mapOf("conversationId" to conversation.conversationId)
            when (action) {
                "pin" -> sdk.conversations.setConversationPinned(req + ("pinned" to !conversation.core.isPinned))
                "mute" -> sdk.conversations.setConversationMuted(req + ("muted" to !conversation.core.isMuted))
                "archive" -> sdk.conversations.setConversationArchived(req + ("archived" to !conversation.core.isArchived))
                "unread" -> sdk.conversations.markConversationUnread(req)
                "clear" -> { sdk.conversations.clearLocalChatHistory(req); repository.clearMessages(conversation.conversationId) }
                "delete" -> { sdk.conversations.deleteConversation(req); repository.removeConversation(conversation.conversationId) }
                else -> error("Unsupported action $action")
            }
            syncConversationList("action")
        }
    }

    fun saveDraft(text: String) = scope.launch {
        val id = environment.selectedConversationId.value ?: return@launch
        environment.run("conversation.draft", showBusy = false) {
            client?.conversations?.updateConversationDraft(
                com.flare.im.model.command.UpdateConversationDraftRequest(conversationId = id, draft = text),
            )
            syncConversationList("draft")
        }
    }

    private suspend fun syncConversationList(reason: String) {
        val sdk = client ?: error("Login before loading conversations")
        repository.openConversationList(sdk, reason)
        // Opening the most recent conversation is a start-up choice only. Doing it on every sync
        // meant that after the user went back to the list, pinning, muting or refreshing a row
        // jumped straight into the first conversation (on a phone that replaces the list).
        if (reason == "bootstrap" && environment.selectedConversationId.value == null) {
            environment.setSelectedConversationId(repository.conversations.value.firstOrNull()?.conversationId)
        }
    }

    private fun mutationRequest(message: AppMessage): Map<String, Any?> = mapOf(
        "conversationId" to message.conversationId,
        "messageId" to message.core.serverId.ifBlank { message.core.clientMsgId },
        "clientMsgId" to message.core.clientMsgId,
        "seq" to message.core.conversationSeq,
    )

    private fun matchesFilter(c: AppConversation, filter: ConversationFilter): Boolean = when (filter) {
        ConversationFilter.All -> !c.core.isArchived
        ConversationFilter.Unread -> c.core.unreadCount > 0 && !c.core.isArchived
        ConversationFilter.Mentions -> c.core.mentionMe && !c.core.isArchived
        ConversationFilter.Pinned -> c.core.isPinned && !c.core.isArchived
        ConversationFilter.Archived -> c.core.isArchived
        ConversationFilter.Muted -> c.core.isMuted && !c.core.isArchived
        ConversationFilter.Drafts -> !c.core.draft.isNullOrBlank() && !c.core.isArchived
    }

    private fun maxPositiveSeq(messages: List<AppMessage>): Long? =
        messages.maxOfOrNull { it.core.conversationSeq }.takeIf { (it ?: 0L) > 0L }
}
