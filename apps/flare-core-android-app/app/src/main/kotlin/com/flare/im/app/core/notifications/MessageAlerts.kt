package com.flare.im.app.core.notifications

import com.flare.im.app.core.session.AppSession
import com.flare.im.model.command.SetNotificationFocusRequest
import com.flare.im.model.entity.NotificationClearEvent
import com.flare.im.model.entity.NotificationPresentation
import com.flare.im.ui.FlareInAppNotification
import com.flare.im.ui.FlareInAppNotificationChannel
import com.flare.im.ui.FlareInAppNotifications
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.launch

/**
 * 链路在线时引擎交来的应用内提醒：新消息横幅（kit [FlareInAppNotifications]，根上的 `InAppNotificationHost` 画它）
 * 与提示音，以及告诉引擎屏幕上是哪个会话。提不提醒、走系统通知还是横幅、响不响都由引擎决定，这里只照办；
 * 系统通知、通知栏的清除与角标归推送模块。
 *
 * 屏幕上的会话 = 聊天页正显示的会话，且界面在前台：聊天页报会话（[chatShown] / [chatHidden]），Activity 报前后台
 * （[setForeground]）。
 */
class MessageAlerts(private val session: AppSession, scope: CoroutineScope) {
    /** 横幅呈现器，根上的 `InAppNotificationHost` 画它；哪个线程喂都行。 */
    val banners = FlareInAppNotifications()

    private val soundRequests = Channel<Unit>(Channel.CONFLATED)

    /** 引擎要响一声：界面放系统的通知提示音。 */
    val sounds: Flow<Unit> = soundRequests.receiveAsFlow()

    @Volatile
    private var visibleConversation: String? = null

    @Volatile
    private var foreground = false

    private val focusReports = Channel<Unit>(Channel.CONFLATED)

    init {
        // 焦点按顺序报给引擎，每次报当时的最新值；没有客户端时不报，登录或恢复会话后 [signedIn] 再报。
        scope.launch {
            for (report in focusReports) {
                val sdk = session.client ?: continue
                runCatching { sdk.notification.setFocus(SetNotificationFocusRequest(conversationId = focus())) }
            }
        }
    }

    /** 引擎的 `notification.present`：这里只接应用内横幅，系统通知由推送模块出。 */
    fun present(presentation: NotificationPresentation) {
        if (presentation.surface != IN_APP_SURFACE) return
        banners.present(
            FlareInAppNotification(
                collapseId = presentation.collapseId,
                conversationId = presentation.conversationId,
                messageId = presentation.messageId.ifEmpty { null },
                title = presentation.title,
                body = presentation.body,
                count = presentation.count.toInt().coerceAtLeast(1),
                channel = channelOf(presentation.channel),
            ),
        )
        if (presentation.sound) soundRequests.trySend(Unit)
    }

    /** 引擎的 `notification.clear`：读过或删掉的会话，横幅也一并收走。 */
    fun clear(event: NotificationClearEvent) {
        if (event.all) banners.clearAll() else banners.clear(event.collapseIds)
    }

    /** 聊天页显示 [conversationId]（出现，或换成了它）。 */
    fun chatShown(conversationId: String) {
        visibleConversation = conversationId
        focusReports.trySend(Unit)
    }

    /** 聊天页不再显示 [conversationId]；已经换成别的会话时不动。 */
    fun chatHidden(conversationId: String) {
        if (visibleConversation != conversationId) return
        visibleConversation = null
        focusReports.trySend(Unit)
    }

    /** 界面回到前台或退到后台；在后台时当作屏幕上没有会话。 */
    fun setForeground(value: Boolean) {
        foreground = value
        focusReports.trySend(Unit)
    }

    /** 登录或恢复会话之后：这个客户端从这里得知屏幕上的会话。 */
    fun signedIn() {
        focusReports.trySend(Unit)
    }

    /** 登出或释放之前：横幅全部收走，屏幕上不再有这个账号的会话。 */
    fun signedOut() {
        banners.clearAll()
        visibleConversation = null
        focusReports.trySend(Unit)
    }

    private fun focus(): String? = visibleConversation.takeIf { foreground }

    private fun channelOf(wire: String): FlareInAppNotificationChannel = when (wire) {
        "quiet" -> FlareInAppNotificationChannel.Quiet
        "mentions" -> FlareInAppNotificationChannel.Mentions
        "urgent" -> FlareInAppNotificationChannel.Urgent
        else -> FlareInAppNotificationChannel.Messages
    }

    private companion object {
        const val IN_APP_SURFACE = "inApp"
    }
}
