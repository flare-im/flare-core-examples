package com.flare.im.app.core.push

import android.app.Application
import android.content.Context
import android.util.Log
import com.flare.im.app.MainActivity
import com.flare.im.app.R
import com.flare.im.app.core.FlareAppStore
import com.flare.im.keepalive.FlareKeepAlive
import com.flare.im.keepalive.FlareKeepAliveHost
import com.flare.im.keepalive.FlareKeepAliveOptions
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow

/**
 * 应用与常驻连接模块之间的接线。只在没有推送通道的构建里提供（[available]）；有推送通道的构建里，之前留下的开关
 * 一并关掉。
 *
 * 开着时：模块的前台服务保住进程，进程级的客户端（[com.flare.im.app.FlareCoreApplication.root]）维持链路；推送绑定
 * 关掉、对每个通道撤一次（[AppPush.setResident]）；后台展示器接着，链路上的提示由它发成系统通知。服务在没有界面时
 * 启动（开机、应用更新、被系统重建）就由这里恢复会话。关掉时反过来：恢复推送登记，后台展示器仍按通知权限接着。
 */
object AppKeepAlive {
    private const val TAG = "FlareKeepAlive"

    private val enabledState = MutableStateFlow(false)

    /** 常驻连接的开关（模块记下的），设置页的开关跟着它。 */
    val enabled: StateFlow<Boolean> = enabledState.asStateFlow()

    @Volatile
    private var offered = false

    /** 这个构建提供常驻连接：没有任何推送通道。[install] 之后才有答案。 */
    fun available(): Boolean = offered

    /** `Application.onCreate` 里、[AppPush.install] 之后调一次；[store] 是进程级的组合根，用到时才取。 */
    fun install(application: Application, store: () -> FlareAppStore) {
        offered = !AppPush.hasPushProvider(application)
        if (!offered) {
            // 有推送通道的构建不常驻：之前的构建留下的开关与服务一并关掉。
            if (FlareKeepAlive.isEnabled(application)) FlareKeepAlive.stop(application)
            return
        }
        val on = FlareKeepAlive.isEnabled(application)
        enabledState.value = on
        // 服务起来之前就按开关处理推送绑定：会话可能先于服务就绪。
        AppPush.setResident(on)
        FlareKeepAlive.install(
            application,
            options = FlareKeepAliveOptions(
                smallIcon = R.drawable.ic_notification,
                launchActivity = MainActivity::class.java,
                onError = { error -> Log.w(TAG, "keep-alive service not started", error) },
            ),
            host = object : FlareKeepAliveHost {
                override fun onKeepAliveStarted() {
                    AppPush.setResident(true)
                    // 开机或被系统重建后进程里还没有会话：恢复它，链路才在线。界面之后拿到的是同一个结果。
                    store().resumeInBackground()
                }

                override fun onKeepAliveStopped() {
                    // 系统停掉了服务而开关还开着：仍是常驻连接模式，不恢复推送登记（这个构建也没有推送通道）。
                    if (!FlareKeepAlive.isEnabled(application)) AppPush.setResident(false)
                }
            },
        )
    }

    /** 设置页的开关：打开时启动服务、撤推送绑定、接着后台展示器；关掉时反过来。 */
    fun setEnabled(context: Context, on: Boolean) {
        if (!offered) return
        if (on) FlareKeepAlive.start(context) else FlareKeepAlive.stop(context)
        enabledState.value = on
        AppPush.setResident(on)
    }
}
