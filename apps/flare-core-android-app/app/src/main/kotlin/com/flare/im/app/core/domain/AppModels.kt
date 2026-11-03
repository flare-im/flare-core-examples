package com.flare.im.app.core.domain

import androidx.annotation.StringRes
import com.flare.im.app.R
import com.flare.im.app.core.designsystem.FlareTone

/** 顶层区段。 */
enum class AppSection(@StringRes val titleRes: Int) {
    Conversations(R.string.nav_messages),
    Search(R.string.nav_search),
    SdkLab(R.string.nav_sdk_status),
    Settings(R.string.nav_settings),
}

/** 会话列表过滤。 */
enum class ConversationFilter(@StringRes val titleRes: Int) {
    All(R.string.filter_all),
    Unread(R.string.filter_unread),
    Mentions(R.string.filter_mentions),
    Pinned(R.string.filter_pinned),
    Archived(R.string.filter_archived),
    Muted(R.string.filter_muted),
    Drafts(R.string.filter_drafts),
}

/** 主题选择。null=跟随系统。 */
enum class ThemeChoice { System, Light, Dark }

/** 起会话类型。 */
enum class StartConversationKind { Single, Group }

/**
 * 运行时状态，sealed 保留关联消息。
 * productLabel/tone/icon 提供产品化呈现。
 */
sealed interface RuntimeStatus {
    object Idle : RuntimeStatus
    data class Loading(val message: String) : RuntimeStatus
    object Ready : RuntimeStatus
    data class Offline(val reason: String) : RuntimeStatus
    data class Error(val message: String) : RuntimeStatus
    data class Unavailable(val message: String) : RuntimeStatus

    val isBlocking: Boolean
        get() = this is Error || this is Unavailable

    /** 用户可见状态文案的 string-res（连接态用）。 */
    @get:StringRes
    val productLabelRes: Int
        get() = when (this) {
            Idle -> R.string.status_not_connected
            is Loading -> R.string.status_connecting
            Ready -> R.string.status_online
            is Offline -> R.string.status_offline
            is Error -> R.string.status_needs_attention
            is Unavailable -> R.string.status_unavailable
        }

    val tone: FlareTone
        get() = when (this) {
            Idle -> FlareTone.Neutral
            is Loading -> FlareTone.Info
            Ready -> FlareTone.Success
            is Offline, is Unavailable -> FlareTone.Warning
            is Error -> FlareTone.Danger
        }
}

/** 传输模式；保留现有 AndroidTransportMode 行为。 */
enum class LoginTransportMode(val title: String) {
    WebSocket("WebSocket"),
    Quic("QUIC"),
    Race("QUIC Race"),
    ;

    companion object {
        fun fromNameOrDefault(raw: String?): LoginTransportMode =
            entries.firstOrNull { it.name.equals(raw?.trim(), ignoreCase = true) } ?: WebSocket
    }
}

/** 登录默认值（与 LoginDraft 等价，含 transportConfig 生成）。 */
data class LoginDraft(
    val userId: String = com.flare.im.app.BuildConfig.DEFAULT_USER_ID,
    val transportMode: LoginTransportMode = LoginTransportMode.fromNameOrDefault(com.flare.im.app.BuildConfig.DEFAULT_TRANSPORT_MODE),
    val wsUrl: String = com.flare.im.app.BuildConfig.DEFAULT_WS_URL,
    val quicUrl: String = com.flare.im.app.BuildConfig.DEFAULT_QUIC_URL,
    val tlsCaCertPath: String = "",
    /** 内联信任 CA（PEM 或 base64 DER）：QUIC / wss 连自建 CA 签发证书的服务端时必配；移动端没有稳定文件路径。 */
    val tlsCaCert: String = com.flare.im.app.BuildConfig.DEFAULT_TLS_CA_CERT,
    val tenantId: String = "0",
    /** 网关 HTTP 基址：SDK 托管 token 时向它签发/刷新；也是媒体等 HTTP 接口的基址。 */
    val httpUrl: String = com.flare.im.app.BuildConfig.DEFAULT_HTTP_URL,
    /**
     * 可选：应用托管形态——直接填业务后端签好的接入 token，SDK 原样使用、不做刷新。
     * 留空则 SDK 托管：向 `httpUrl` 的网关签发并自动刷新。客户端从不持有签名密钥。
     */
    val accessToken: String = com.flare.im.app.BuildConfig.DEFAULT_ACCESS_TOKEN,
    val dataSubfolder: String = "flare-core-android-app",
) {
    /** 当前传输模式下用户可编辑的服务地址。 */
    val visibleServerAddress: String
        get() = when (transportMode) {
            LoginTransportMode.WebSocket -> wsUrl
            LoginTransportMode.Quic, LoginTransportMode.Race -> quicUrl
        }

    fun withVisibleServerAddress(value: String): LoginDraft = when (transportMode) {
        LoginTransportMode.WebSocket -> copy(wsUrl = value)
        LoginTransportMode.Quic, LoginTransportMode.Race -> copy(quicUrl = value)
    }

    /** race 模式下的备用 WebSocket 地址（否则 null）。 */
    val secondaryServerAddress: String?
        get() = if (transportMode == LoginTransportMode.Race) wsUrl else null

    fun withSecondaryServerAddress(value: String): LoginDraft =
        if (transportMode == LoginTransportMode.Race) copy(wsUrl = value) else this

    /** 生成 SDK init 的 transport 配置（与现有 androidTransportConfig 等价，含 tenant/token 元信息留给调用方拼装）。 */
    fun transportConfig(): Map<String, Any> {
        val ws = wsUrl.trim()
        require(ws.isNotEmpty()) { "WebSocket URL is required" }
        val tls = buildMap<String, Any> {
            tlsCaCertPath.trim().takeIf { it.isNotEmpty() }?.let { put("tlsCaCertPath", it) }
            tlsCaCert.trim().takeIf { it.isNotEmpty() }?.let { put("tlsCaCert", it) }
        }
        if (transportMode == LoginTransportMode.WebSocket) {
            return mapOf(
                "wsUrl" to ws,
                "transportPolicy" to "websocket_only",
                "defaultTransport" to "websocket",
            ) + tls
        }
        val quic = quicUrl.trim()
        require(quic.isNotEmpty()) { "QUIC URL is required for selected transport" }
        return when (transportMode) {
            LoginTransportMode.WebSocket -> error("unreachable")
            LoginTransportMode.Quic -> mapOf(
                "wsUrl" to ws, "quicUrl" to quic,
                "transportPolicy" to "auto", "defaultTransport" to "quic",
                "protocolRaceOrder" to listOf("quic"),
            ) + tls
            LoginTransportMode.Race -> mapOf(
                "wsUrl" to ws, "quicUrl" to quic,
                "transportPolicy" to "protocol_race", "defaultTransport" to "quic",
                "protocolRaceOrder" to listOf("quic", "websocket"),
            ) + tls
        }
    }
}

/** SDK Lab 操作记录。[id] 按记录顺序递增，结果列表用它做 key。 */
data class LabResult(
    val id: Long,
    val operation: String,
    val status: String,
    val detail: String,
    val timestampMs: Long = System.currentTimeMillis(),
)

/** 连接事件日志条目。 */
data class EventLogEntry(
    val domain: String,
    val name: String,
    val detail: String,
    val timestampMs: Long = System.currentTimeMillis(),
)
