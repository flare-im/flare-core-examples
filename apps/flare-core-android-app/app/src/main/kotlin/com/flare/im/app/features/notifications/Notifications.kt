package com.flare.im.app.features.notifications

import android.content.Context
import android.media.RingtoneManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import com.flare.im.app.R
import com.flare.im.app.core.push.AppKeepAlive
import com.flare.im.push.FlareBackgroundRestrictions
import com.flare.im.push.FlarePush
import com.flare.im.push.FlarePushBackgroundDelivery
import com.flare.im.push.FlarePushPermission
import com.flare.im.push.FlarePushPermissionStatus
import com.flare.im.ui.FlareBackgroundDelivery
import com.flare.im.ui.FlareNotificationGuideAction
import com.flare.im.ui.FlareNotificationStatus
import com.flare.im.ui.FlarePermissionKind
import com.flare.im.ui.FlarePermissionPresentation
import com.flare.im.ui.FlarePermissionState
import com.flare.im.ui.FlareStatusTone
import com.flare.im.ui.LocalFlareToast
import com.flare.im.ui.NotificationDeliverySettings
import com.flare.im.ui.PermissionPrompt

/**
 * 会话列表上的首次通知引导（kit `PermissionPrompt` 软询问，底部面板）。登录后来到会话列表、通知还没开时出现：
 * 系统授权框还会弹时「开启通知」，弹不出来了「前往设置」。选了哪个（含划掉面板）都按账号记住，之后不再出现，
 * 改主意走设置里的「新消息通知」。[account] 是租户与用户，换了账号会再问一次。
 */
@Composable
fun NotificationSoftAsk(account: String) {
    val context = LocalContext.current
    val status by FlarePush.permission.collectAsState()
    // 授权框的结果要回到这里：引导收起之后它也一直在，不能放到下面的提前返回之后。
    val turnOn = rememberTurnOnNotifications()
    val answers = remember(context) { SoftAskAnswers(context) }
    var answered by remember(account) { mutableStateOf(answers.answered(account)) }
    val state = notificationSoftAskState(status, FlarePushPermission.canRequest(context), answered) ?: return
    fun answer() {
        answers.answer(account)
        answered = true
    }
    PermissionPrompt(
        kind = FlarePermissionKind.Notifications,
        state = state,
        softAsk = true,
        presentation = FlarePermissionPresentation.Sheet,
        onRequest = {
            answer()
            turnOn()
        },
        onOpenSettings = {
            answer()
            turnOn()
        },
        onDismiss = ::answer,
    )
}

/**
 * 设置里的通知分组（kit `NotificationDeliverySettings`，自带分组标题）：「新消息通知」显示权限，点它申请授权或打开
 * 本应用的通知设置；「后台接收消息」显示系统电池设置的那一档，点开是 kit 的说明面板：电池使用，华为、荣耀、小米、
 * OPPO、vivo 另有自启动。只读状态、打开系统自己的页面，不做任何自动化。
 *
 * 没有推送通道的构建另有「后台保持连接」开关（kit 的常驻连接行，[AppKeepAlive]），开着且电池优化没关时 kit 再给一行
 * 关闭电池优化，点了打开电池优化的设置页，不替用户申请豁免。
 */
@Composable
fun NotificationDeliverySection(modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val status by FlarePush.permission.collectAsState()
    val turnOn = rememberTurnOnNotifications()
    // 模块在安装、刷新与每次回到前台时重读电池设置那一档，用户从系统设置回来就是新值。
    val background by FlarePush.backgroundDelivery.collectAsState()
    val resident by AppKeepAlive.enabled.collectAsState()
    val vendor = remember { FlareBackgroundRestrictions.vendor() }
    val toast = LocalFlareToast.current
    val openFailed = stringResource(R.string.settings_open_failed)
    fun opened(done: Boolean) {
        if (!done) toast.show(openFailed, tone = FlareStatusTone.Danger)
    }
    NotificationDeliverySettings(
        status = status?.let(::notificationStatus),
        background = background?.let(::backgroundDelivery),
        vendorActions = if (vendor.hasAutoStartSettings) {
            listOf(FlareNotificationGuideAction { opened(FlareBackgroundRestrictions.openAutoStartSettings(context)) })
        } else {
            emptyList()
        },
        onStatusAction = { opened(turnOn()) },
        onOpenBatterySettings = { opened(FlareBackgroundRestrictions.openBatteryOptimizationSettings(context)) },
        // 只有没有推送通道的构建才有这个开关。
        residentMode = resident.takeIf { AppKeepAlive.available() },
        onResidentModeChange = { on -> AppKeepAlive.setEnabled(context, on) },
        modifier = modifier,
    )
}

/**
 * 首次引导画成哪一种：答过、还没读到权限或已经开着时不画（null）；系统授权框还会弹时请求，弹不出来了引导去设置。
 */
internal fun notificationSoftAskState(
    status: FlarePushPermissionStatus?,
    canRequest: Boolean,
    answered: Boolean,
): FlarePermissionState? = when {
    answered || status == null || status == FlarePushPermissionStatus.GRANTED -> null
    canRequest -> FlarePermissionState.Undetermined
    else -> FlarePermissionState.Denied
}

/** 模块的三态权限在设置行上的说法。 */
internal fun notificationStatus(status: FlarePushPermissionStatus): FlareNotificationStatus = when (status) {
    FlarePushPermissionStatus.GRANTED -> FlareNotificationStatus.On
    FlarePushPermissionStatus.DENIED -> FlareNotificationStatus.Off
    FlarePushPermissionStatus.NOT_DETERMINED -> FlareNotificationStatus.NotTurnedOn
}

/** 模块读出的电池设置那一档，换成 kit 的同名三档。 */
internal fun backgroundDelivery(delivery: FlarePushBackgroundDelivery): FlareBackgroundDelivery = when (delivery) {
    FlarePushBackgroundDelivery.UNRESTRICTED -> FlareBackgroundDelivery.Unrestricted
    FlarePushBackgroundDelivery.OPTIMIZED -> FlareBackgroundDelivery.Optimized
    FlarePushBackgroundDelivery.RESTRICTED -> FlareBackgroundDelivery.Restricted
}

/**
 * 打开通知的唯一做法：系统授权框还会弹就经模块弹（模块记下问过，结果经 [FlarePush.refresh] 报给引擎，
 * [FlarePush.permission] 随之更新），否则打开本应用的通知设置；已经开着时也去设置，那里管各个通知渠道。
 * 什么都没打开时返回 false。
 */
@Composable
private fun rememberTurnOnNotifications(): () -> Boolean {
    val context = LocalContext.current
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { FlarePush.refresh() }
    return remember(context, launcher) {
        {
            val asked = FlarePushPermission.canRequest(context) && FlarePushPermission.request(context, launcher)
            asked || FlarePushPermission.openSettings(context)
        }
    }
}

/**
 * 应用内横幅的提示音：系统的通知提示音（用户在系统设置里选的那一个），跟着通知音量与静音模式。没有可放的提示音时
 * 什么都不做。
 */
internal fun playMessageSound(context: Context) {
    val sound = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION) ?: return
    runCatching { RingtoneManager.getRingtone(context.applicationContext, sound)?.play() }
}

/** 首次引导按账号答过没有。权限本身由模块记，这里只记引导：换了账号会再问一次。 */
private class SoftAskAnswers(context: Context) {
    private val prefs = context.applicationContext.getSharedPreferences("flare_notifications", Context.MODE_PRIVATE)

    fun answered(account: String): Boolean = account in prefs.getStringSet(KEY_ANSWERED, null).orEmpty()

    fun answer(account: String) {
        val answered = prefs.getStringSet(KEY_ANSWERED, null).orEmpty() + account
        prefs.edit().putStringSet(KEY_ANSWERED, answered).apply()
    }

    private companion object {
        const val KEY_ANSWERED = "promptAnswered"
    }
}
