package com.flare.im.app.core.session

import com.flare.im.FlareCoreSdk
import com.flare.im.api.ConnectionState
import com.flare.im.api.FlareImClient
import com.flare.im.app.core.domain.EventLogEntry
import com.flare.im.app.core.domain.LoginDraft
import com.flare.im.listener.EventSubscription
import com.flare.im.model.entity.ViewUpdate
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import org.json.JSONObject

/**
 * 跨切面会话核心：唯一持有 `FlareImClient` 的地方（其余层经它拿门面）。
 * 拥有客户端生命周期 + 认证态 + 连接态 + 原始事件流，
 * 事件经 `onViewUpdate` / `onMessageSendFailed` 钩子路由给数据层/聊天层。
 */
class AppSession {
    private val _currentUserId = MutableStateFlow<String?>(null)
    val currentUserId: StateFlow<String?> = _currentUserId.asStateFlow()

    private val _isLoggedIn = MutableStateFlow(false)
    val isLoggedIn: StateFlow<Boolean> = _isLoggedIn.asStateFlow()

    private val _connectionState = MutableStateFlow(ConnectionState.DISCONNECTED)
    val connectionState: StateFlow<ConnectionState> = _connectionState.asStateFlow()

    private val _eventLog = MutableStateFlow<List<EventLogEntry>>(emptyList())
    val eventLog: StateFlow<List<EventLogEntry>> = _eventLog.asStateFlow()

    /** 唯一客户端持有点。 */
    var client: FlareImClient? = null
        private set

    /** 事件路由钩子（由数据层/聊天层注入）。 */
    var onViewUpdate: ((ViewUpdate) -> Unit)? = null
    var onMessageReceived: ((String) -> Unit)? = null
    var onMessageSendFailed: ((String) -> Unit)? = null

    private val subscriptions = mutableListOf<EventSubscription>()
    private var lastDraft: LoginDraft? = null
    private var nativeEventSubscription: Any? = null

    /** 创建 → 订阅 → init → 取 token → 登录。`progress` 回报阶段。 */
    suspend fun start(
        draft: LoginDraft,
        dataDir: String,
        progress: (String) -> Unit,
    ): FlareImClient {
        progress("Creating Android SDK client")
        val sdk = FlareCoreSdk.createClient()

        subscribeEvents(sdk)
        subscribeNativeEvents(sdk)

        progress("Initializing SDK")
        // `dataUrl` is a URL; filesDir is absolute, so this yields file:///data/...
        val sdkConfig = buildSdkConfig(draft, dataDir)
        val storeConfigJson = JSONObject(sdkConfig).toString()
        sdk.init(sdkConfig)

        val userId = draft.userId.trim()
        val tenantId = normalizedTenantId(draft)
        // 应用托管：高级区填了现成的接入 token 就原样用；SDK 托管：留空，核心向网关签发并自动刷新。
        val pastedToken = draft.accessToken.trim()

        progress("Logging in")
        sdk.login(
            buildMap {
                put("userId", userId)
                if (pastedToken.isNotEmpty()) put("token", pastedToken)
                put("storeConfigJson", storeConfigJson)
            },
        )

        // 配置 SDK 托管的媒体磁盘缓存（LRU + 去重，核心已实现）：设根目录 + 上限，
        // 之后消息媒体经 media.cacheRemoteMedia 落到这里（离线可用、不重复下载）。
        // 核心的参数名是 absolutePath（也认 path / root）。此前只传 root，旧核心读不到，
        // 调用报错又被 runCatching 吞掉，缓存根目录从来没设上。
        runCatching {
            sdk.media.setMediaCacheRoot(mapOf("absolutePath" to "$dataDir/media-cache"))
            sdk.media.setMediaCacheMaxBytes(mapOf("maxBytes" to MEDIA_CACHE_MAX_BYTES))
        }

        client = sdk
        _currentUserId.value = userId
        _isLoggedIn.value = true
        lastDraft = draft.copy(userId = userId, tenantId = tenantId)
        refreshConnectionState()
        return sdk
    }

    private fun buildSdkConfig(draft: LoginDraft, dataDir: String): Map<String, Any> =
        draft.transportConfig() + mapOf(
            "dataUrl" to "file://$dataDir",
            "tenantId" to normalizedTenantId(draft),
            "deviceId" to ANDROID_EXAMPLE_DEVICE_ID,
            "httpUrl" to draft.httpUrl.trim(),
            // SDK 托管 token：核心向 {httpUrl}/api/v1/auth/tokens 签发、到期前刷新。
            // 填了 accessToken 时核心会直接用它，不走签发。
            "auth" to mapOf("tokenEndpoint" to draft.httpUrl.trim()),
            "platform" to "android",
            "runtime" to "compose-example",
        )

    private fun normalizedTenantId(draft: LoginDraft): String = draft.tenantId.trim().ifEmpty { "0" }

    /**
     * 热启动本地半段：创建 → 订阅 → init → prepare(开本地库，不连网)。
     * 本地会话即刻可读（会话列表/消息本地直出）；连接由 [connectInBackground] 补。
     */
    suspend fun resumeLocal(
        draft: LoginDraft,
        dataDir: String,
        progress: (String) -> Unit,
    ): FlareImClient {
        progress("Creating Android SDK client")
        val sdk = FlareCoreSdk.createClient()
        subscribeEvents(sdk)
        subscribeNativeEvents(sdk)

        progress("Initializing SDK")
        val sdkConfig = buildSdkConfig(draft, dataDir)
        sdk.init(sdkConfig)

        progress("Opening local store")
        val userId = draft.userId.trim()
        val tenantId = normalizedTenantId(draft)
        sdk.prepare(
            mapOf(
                "userId" to userId,
                "storeConfigJson" to JSONObject(sdkConfig).toString(),
            ),
        )

        runCatching {
            sdk.media.setMediaCacheRoot(mapOf("absolutePath" to "$dataDir/media-cache"))
            sdk.media.setMediaCacheMaxBytes(mapOf("maxBytes" to MEDIA_CACHE_MAX_BYTES))
        }

        client = sdk
        _currentUserId.value = userId
        _isLoggedIn.value = true
        lastDraft = draft.copy(userId = userId, tenantId = tenantId)
        return sdk
    }

    /** 热启动网络半段：后台重签 token 并建连；失败保持本地视图可用。 */
    suspend fun connectInBackground() {
        val sdk = client ?: return
        val draft = lastDraft ?: return
        runCatching {
            val userId = draft.userId.trim()
            val tenantId = normalizedTenantId(draft)
            val pastedToken = draft.accessToken.trim()
            sdk.connect(
                buildMap {
                    put("userId", userId)
                    if (pastedToken.isNotEmpty()) put("token", pastedToken)
                    put("tenantId", tenantId)
                },
            )
        }
        refreshConnectionState()
    }

    suspend fun logout() {
        val sdk = client ?: error("SDK client is not initialized")
        unsubscribeNativeEvents(sdk)
        sdk.logout()
        _isLoggedIn.value = false
        _currentUserId.value = null
        refreshConnectionState()
    }

    suspend fun dispose() {
        val sdk = client ?: error("SDK client is not initialized")
        unsubscribeNativeEvents(sdk)
        runCatching { sdk.dispose() }
        teardown()
    }

    suspend fun refreshConnectionState() {
        runCatching { client?.connection?.getConnectionState() }
            .getOrNull()
            ?.let { _connectionState.value = it }
    }

    private fun subscribeEvents(sdk: FlareImClient) {
        subscriptions += sdk.events.onViewUpdated { update -> onViewUpdate?.invoke(update) }
        subscriptions += sdk.events.onMessageReceived { event ->
            event.message.conversationId.trim().takeIf { it.isNotEmpty() }?.let { conversationId ->
                appendEvent("message", "received", conversationId)
                onMessageReceived?.invoke(conversationId)
            }
        }
        subscriptions += sdk.events.onMessageReceivedBatch { event ->
            val conversationIds = event.messages
                .mapNotNull { it.conversationId.trim().takeIf(String::isNotEmpty) }
                .distinct()
            if (conversationIds.isNotEmpty()) {
                appendEvent("message", "received_batch", conversationIds.joinToString(","))
                conversationIds.forEach { onMessageReceived?.invoke(it) }
            }
        }
        subscriptions += sdk.events.onConnectSuccess { event ->
            _connectionState.value = ConnectionState.CONNECTED
            appendEvent("connection", event.name.name, event.reason ?: "")
        }
        subscriptions += sdk.events.onConnectReady { event ->
            _connectionState.value = ConnectionState.READY
            appendEvent("connection", event.name.name, event.reason ?: "")
        }
        subscriptions += sdk.events.onDisconnected { event ->
            _connectionState.value = ConnectionState.DISCONNECTED
            appendEvent("connection", event.name.name, event.reason ?: "")
        }
        subscriptions += sdk.events.onLoginSucceeded { event ->
            appendEvent("lifecycle", event.name.name, event.operation)
        }
    }

    private suspend fun subscribeNativeEvents(sdk: FlareImClient) {
        nativeEventSubscription?.let { sdk.events.unsubscribe(mapOf("subscription" to it)) }
        nativeEventSubscription = sdk.events.subscribeEvents(emptyMap())["subscription"]
    }

    private suspend fun unsubscribeNativeEvents(sdk: FlareImClient) {
        nativeEventSubscription?.let { subscription ->
            runCatching { sdk.events.unsubscribe(mapOf("subscription" to subscription)) }
        }
        nativeEventSubscription = null
    }

    private fun teardown() {
        subscriptions.forEach { runCatching { it.unsubscribe() } }
        subscriptions.clear()
        nativeEventSubscription = null
        client = null
        _isLoggedIn.value = false
        _currentUserId.value = null
        _connectionState.value = ConnectionState.DISCONNECTED
    }

    private fun appendEvent(domain: String, name: String, detail: String) {
        _eventLog.update { (it + EventLogEntry(domain, name, detail)).takeLast(200) }
    }

    companion object {
        private const val ANDROID_EXAMPLE_DEVICE_ID = "android-example"

        /** 媒体磁盘缓存默认上限 256MB（对齐主流 IM；可在设置页调整）。 */
        const val MEDIA_CACHE_MAX_BYTES = 256L * 1024 * 1024
    }
}
