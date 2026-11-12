package com.flare.im.app.core.push

import android.app.Application
import android.content.Context
import android.util.Log
import com.flare.im.app.BuildConfig
import com.flare.im.app.MainActivity
import com.flare.im.app.R
import com.flare.im.push.FlareBackgroundPresenter
import com.flare.im.push.FlarePush
import com.flare.im.push.FlarePushHost
import com.flare.im.push.FlarePushOptions
import com.flare.im.push.getui.FlareGetuiPush
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.update

/**
 * 应用与平台推送模块之间的接线：进程启动时在 [FlareCoreApplication][com.flare.im.app.FlareCoreApplication]
 * 里装上模块，会话就绪时把宿主交给它，退出登录时撤下。
 *
 * 宿主跟着会话走：登录或恢复会话成功后才有，同一次会话始终是同一个宿主（模块按宿主是否换了决定要不要
 * 重报令牌与权限）。模块要宿主时，会话还在登录或恢复就等它出结果，等多久由模块自己的超时决定。
 * 会话由界面恢复：被推送拉起、还没有界面的进程里没有宿主，推送按载荷原样展示，点击留到恢复后再解析。
 * 常驻连接开着时会话由它恢复（[AppKeepAlive]），推送绑定关掉（[setResident]）。
 */
object AppPush {
    private const val TAG = "FlarePush"

    private sealed interface HostState {
        data object Absent : HostState

        class Pending(val owner: Any) : HostState

        class Ready(val owner: Any, val host: FlarePushHost) : HostState
    }

    private val state = MutableStateFlow<HostState>(HostState.Absent)

    @Volatile
    private var application: Application? = null

    /**
     * `Application.onCreate` 里调一次：通知渠道、FCM 令牌、权限上报与点击处理从这里开始。后台展示器在这里就要上：
     * 模块只在通知权限已经允许、会话就绪时告诉引擎接上，所以实际是在授权之后接上，撤销权限时自己断开。
     */
    fun install(application: Application) {
        this.application = application
        FlarePush.install(
            application,
            hostProvider = { currentHost() },
            options = FlarePushOptions(
                smallIcon = R.drawable.ic_notification,
                launchActivity = MainActivity::class.java,
                // 模块给出的错误不含令牌与载荷，可以进日志。
                onError = { error -> Log.w(TAG, "push report failed", error) },
            ),
        )
        FlareBackgroundPresenter.attach()
    }

    /** 这个构建有推送通道：打包了 FCM 的客户端配置，或给了个推的应用标识。没有时设置里才提供常驻连接。 */
    fun hasPushProvider(context: Context): Boolean =
        FlarePush.isFcmAvailable(context) || BuildConfig.FLARE_GETUI_APP_ID.isNotBlank()

    /**
     * 常驻连接开着（[resident]）：不登记推送绑定，模块对每个通道撤一次服务端的绑定（`clearPushToken`），之后每个
     * 会话也是；后台展示器照常接着。关掉时恢复登记。
     */
    fun setResident(resident: Boolean) {
        FlarePush.setPushBindingsEnabled(!resident)
        if (resident) FlareBackgroundPresenter.attach()
    }

    /** [owner] 开始登录或恢复会话：这期间要宿主的一方等它出结果。 */
    fun sessionStarting(owner: Any) {
        state.value = HostState.Pending(owner)
    }

    /**
     * [owner] 的会话就绪：宿主交给模块，模块补报权限与令牌、解析排队的点击。构建配了个推就在这时启动它：
     * 推送 SDK 不在用户登录之前初始化。
     */
    fun sessionReady(owner: Any, host: FlarePushHost) {
        state.value = HostState.Ready(owner, host)
        FlarePush.refresh()
        startGetui()
    }

    /** [owner] 的登录或恢复没有成功，或持有会话的一方不在了：没有宿主。别的一方登记的宿主不动。 */
    fun sessionEnded(owner: Any) {
        state.update { current -> if (current.ownedBy(owner)) HostState.Absent else current }
    }

    /**
     * 退出登录：没有宿主；模块移除本应用发出的通知，丢掉排队的点击，忘掉报过的令牌与权限，下一个账号重新登记。
     */
    fun signedOut(owner: Any) {
        sessionEnded(owner)
        FlarePush.signOut()
    }

    /** 模块要的宿主：会话还在登录或恢复时等它出结果；没登录时为 null。 */
    internal suspend fun currentHost(): FlarePushHost? =
        (state.first { it !is HostState.Pending } as? HostState.Ready)?.host

    private fun startGetui() {
        val app = application ?: return
        if (BuildConfig.FLARE_GETUI_APP_ID.isBlank()) return
        runCatching { FlareGetuiPush.install(app) }.onFailure { Log.w(TAG, "Getui start failed", it) }
    }

    private fun HostState.ownedBy(owner: Any): Boolean = when (this) {
        HostState.Absent -> false
        is HostState.Pending -> this.owner === owner
        is HostState.Ready -> this.owner === owner
    }
}
