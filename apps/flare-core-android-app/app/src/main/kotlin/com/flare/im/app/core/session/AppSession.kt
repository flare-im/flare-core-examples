package com.flare.im.app.core.session

import com.flare.im.api.FlareImClient
import com.flare.im.app.core.domain.EventLogEntry
import com.flare.im.app.core.domain.LoginDraft
import com.flare.im.listener.EventSubscription
import com.flare.im.model.entity.ConnectionStatus
import com.flare.im.model.entity.UpdateStatus
import com.flare.im.model.entity.ViewUpdate
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import java.util.concurrent.atomic.AtomicLong
import org.json.JSONObject

/**
 * 跨切面会话核心：唯一持有 `FlareImClient` 的地方（其余层经它拿门面）。
 * 拥有客户端生命周期 + 认证态 + 连接态 + 原始事件流，
 * 事件经 `onViewUpdate` / `onMessageSendFailed` 钩子路由给数据层/聊天层。
 *
 * [newClient] builds the SDK client (`FlareCoreSdk.createClient(context)`: it reports the app version on connect and
 * installs the platform lifecycle — network and foreground — after `init`). [access] says where the SDK connects.
 */
class AppSession(
    private val newClient: () -> FlareImClient,
    private val access: () -> AppAccess = { AppAccess.current },
) {
    private val _currentUserId = MutableStateFlow<String?>(null)
    val currentUserId: StateFlow<String?> = _currentUserId.asStateFlow()

    private val _isLoggedIn = MutableStateFlow(false)
    val isLoggedIn: StateFlow<Boolean> = _isLoggedIn.asStateFlow()

    /** The SDK's `connection://status`, replaced whole on every event; null before the SDK has said anything. */
    private val _connectionStatus = MutableStateFlow<ConnectionStatus?>(null)
    val connectionStatus: StateFlow<ConnectionStatus?> = _connectionStatus.asStateFlow()
    private val connectionStatusEvents = AtomicLong()

    private val _eventLog = MutableStateFlow<List<EventLogEntry>>(emptyList())
    val eventLog: StateFlow<List<EventLogEntry>> = _eventLog.asStateFlow()

    /** 唯一客户端持有点。 */
    var client: FlareImClient? = null
        private set

    /** 事件路由钩子（由数据层/聊天层注入）。 */
    var onViewUpdate: ((ViewUpdate) -> Unit)? = null
    var onMessageReceived: ((String) -> Unit)? = null
    var onMessageSendFailed: ((String) -> Unit)? = null
    var onUpdateState: ((UpdateStatus) -> Unit)? = null

    private val subscriptions = mutableListOf<EventSubscription>()
    private var lastDraft: LoginDraft? = null
    private var nativeEventSubscription: Any? = null

    /** A client [accessClient] brought up without a session; the sign-in that follows continues on it. */
    private var sessionless: Sessionless? = null

    private class Sessionless(val sdk: FlareImClient, val dataDir: String, val tenantId: String)

    /** Bringing a client up is one at a time: a sign-in during the update center's first read continues on its client. */
    private val clientBringUp = Mutex()

    /** 创建 → 订阅 → init → 取 token → 登录。`progress` 回报阶段。 */
    suspend fun start(
        draft: LoginDraft,
        dataDir: String,
        progress: (String) -> Unit,
    ): FlareImClient {
        // `dataUrl` is a URL; filesDir is absolute, so this yields file:///data/...
        val sdkConfig = buildSdkConfig(draft, dataDir)
        val storeConfigJson = JSONObject(sdkConfig).toString()
        val sdk = initializedClient(draft, dataDir, sdkConfig, progress)

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

        adopt(sdk)
        _currentUserId.value = userId
        _isLoggedIn.value = true
        lastDraft = draft.copy(userId = userId, tenantId = tenantId)
        readConnectionStatus(sdk)
        return sdk
    }

    /**
     * A client created, subscribed and initialized for this sign-in, unless [accessClient] already did so for the same
     * data directory and tenant. It stays [sessionless] until [adopt]: a read during the sign-in reaches this client
     * instead of bringing up a second core, and a build the server refused is known to this client's update center
     * only, so after a refusal it stays up and the next try continues on it.
     */
    private suspend fun initializedClient(
        draft: LoginDraft,
        dataDir: String,
        sdkConfig: Map<String, Any>,
        progress: (String) -> Unit,
    ): FlareImClient = clientBringUp.withLock {
        val tenantId = normalizedTenantId(draft)
        val ready = sessionless
        if (ready != null && ready.dataDir == dataDir && ready.tenantId == tenantId) return@withLock ready.sdk
        sessionless = null
        progress("Creating Android SDK client")
        val sdk = newClient()
        subscribeEvents(sdk)
        subscribeNativeEvents(sdk)

        progress("Initializing SDK")
        sdk.init(sdkConfig)
        sessionless = Sessionless(sdk, dataDir, tenantId)
        sdk
    }

    /** The sign-in went through: [sdk] is the client from here on. */
    private suspend fun adopt(sdk: FlareImClient) = clientBringUp.withLock {
        client = sdk
        sessionless = null
    }

    /**
     * The client `access.*` runs on. It needs no session, and a recovery link can arrive before anyone signed in: the
     * SDK then comes up without one.
     */
    suspend fun accessClient(draft: LoginDraft, dataDir: String): FlareImClient = clientBringUp.withLock {
        client?.let { return@withLock it }
        sessionless?.let { return@withLock it.sdk }
        val sdk = newClient()
        subscribeEvents(sdk)
        subscribeNativeEvents(sdk)
        sdk.init(buildSdkConfig(draft, dataDir))
        sessionless = Sessionless(sdk, dataDir, normalizedTenantId(draft))
        sdk
    }

    /** The events the network and line page reads again on; the returned function stops listening. */
    fun subscribeLinkEvents(onLinkEvent: () -> Unit): () -> Unit {
        val sdk = client ?: sessionless?.sdk ?: return {}
        val links = listOf(
            sdk.events.onConnectionStatusChanged { onLinkEvent() },
            sdk.events.onAccessChanged { onLinkEvent() },
            sdk.events.onAccessSwitched { onLinkEvent() },
        )
        return { links.forEach { runCatching { it.unsubscribe() } } }
    }

    internal fun buildSdkConfig(draft: LoginDraft, dataDir: String): Map<String, Any> {
        val access = access()
        return draft.trustConfig() + buildMap {
            put("dataUrl", "file://$dataDir")
            put("tenantId", normalizedTenantId(draft))
            put("deviceId", ANDROID_EXAMPLE_DEVICE_ID)
            put("access", access.access)
            // SDK 托管 token：核心在当前接入点的 Core API 上签发、到期前刷新（`auth` 给空对象即可，路径用默认值）。
            // 填了 accessToken 时核心会直接用它，不走签发。
            put("auth", emptyMap<String, Any>())
            put("platform", "android")
            put("runtime", "compose-example")
            put("app", appConfig())
        }
    }

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
        val sdkConfig = buildSdkConfig(draft, dataDir)
        val sdk = initializedClient(draft, dataDir, sdkConfig, progress)

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

        adopt(sdk)
        _currentUserId.value = userId
        _isLoggedIn.value = true
        lastDraft = draft.copy(userId = userId, tenantId = tenantId)
        return sdk
    }

    /**
     * 热启动网络半段：后台建连并完成首次同步。链路自己能恢复的失败（断网、连不上、过载……）SDK 照样返回成功并保留
     * 会话，在不在线只看 `connection://status`；这里只会收到鉴权、升级、配置这类终态错误，记进事件日志，本地视图照常可用。
     */
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
        }.onFailure { appendEvent("connection", "connect_failed", it.message ?: it.toString()) }
        readConnectionStatus(sdk)
    }

    /** The connection notice's 立即重试: the SDK starts its next round now. */
    suspend fun reconnectNow() {
        val sdk = client ?: error("SDK client is not initialized")
        sdk.connection.reconnectNow()
    }

    suspend fun logout() {
        val sdk = client ?: error("SDK client is not initialized")
        unsubscribeNativeEvents(sdk)
        try {
            sdk.logout()
        } finally {
            _isLoggedIn.value = false
            _currentUserId.value = null
            _connectionStatus.value = null
        }
    }

    suspend fun dispose() {
        val sdk = client ?: error("SDK client is not initialized")
        unsubscribeNativeEvents(sdk)
        runCatching { sdk.dispose() }
        teardown()
    }

    /** Reads where the connection stands now, unless a status event already said so. */
    private suspend fun readConnectionStatus(sdk: FlareImClient) {
        val seen = connectionStatusEvents.get()
        val status = runCatching { sdk.connection.getStatus() }.getOrNull() ?: return
        if (seen == connectionStatusEvents.get() && sdk === client) _connectionStatus.value = status
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
        subscriptions += sdk.events.onConnectionStatusChanged { status ->
            connectionStatusEvents.incrementAndGet()
            _connectionStatus.value = status
            appendEvent("connection", status.phase.name.lowercase(), status.reason ?: "")
        }
        subscriptions += sdk.events.onLoginSucceeded { event ->
            appendEvent("lifecycle", event.name.name, event.operation)
        }
        subscriptions += sdk.events.onUpdateState { status -> onUpdateState?.invoke(status) }
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
        _connectionStatus.value = null
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
