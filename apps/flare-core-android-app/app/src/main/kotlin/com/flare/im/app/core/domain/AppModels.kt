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

/** The sign-in form. Where to connect is not part of it: the build's access configuration (`AppAccess`) is. */
data class LoginDraft(
    val userId: String = com.flare.im.app.BuildConfig.DEFAULT_USER_ID,
    val tlsCaCertPath: String = "",
    /** 内联信任 CA（PEM 或 base64 DER）：QUIC / wss 连自建 CA 签发证书的服务端时必配；移动端没有稳定文件路径。 */
    val tlsCaCert: String = com.flare.im.app.BuildConfig.DEFAULT_TLS_CA_CERT,
    val tenantId: String = "0",
    /**
     * 可选：应用托管形态——直接填业务后端签好的接入 token，SDK 原样使用、不做刷新。
     * 留空则 SDK 托管（`auth: {}`）：核心在当前接入点的 Core API 上签发并自动刷新。客户端从不持有签名密钥。
     */
    val accessToken: String = com.flare.im.app.BuildConfig.DEFAULT_ACCESS_TOKEN,
    val dataSubfolder: String = "flare-core-android-app",
) {
    /** The private CA the SDK trusts besides the system roots, when one is given. */
    fun trustConfig(): Map<String, Any> = buildMap {
        tlsCaCertPath.trim().takeIf { it.isNotEmpty() }?.let { put("tlsCaCertPath", it) }
        tlsCaCert.trim().takeIf { it.isNotEmpty() }?.let { put("tlsCaCert", it) }
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
