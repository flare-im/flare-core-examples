package com.flare.im.app

import android.app.ActivityManager
import android.app.Application
import android.os.Build
import android.os.Process
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.ViewModelStore
import androidx.lifecycle.ViewModelStoreOwner
import com.flare.im.FlareCoreSdk
import com.flare.im.app.core.push.AppKeepAlive
import com.flare.im.app.core.push.AppPush
import com.flare.im.app.core.session.SavedSessionStore

/**
 * 进程入口与进程级的所有者：装上平台推送（通知渠道、FCM、通知点击与权限上报、后台展示器）与常驻连接，并持有进程里
 * 唯一的组合根（[root]，其中是唯一的客户端）。被推送拉起、开机后常驻连接自启的进程都没有界面，也会走到这里，
 * 所以这些只能在 Application 里装。
 *
 * 客户端跟着进程走，不跟某个页面：组合根放在 Application 自己的 ViewModelStore 里，界面关掉、Activity 重建都不
 * 释放它，退到后台后链路照常在线，后台展示器与常驻连接靠的就是这一点。会话仍由界面恢复；常驻连接在没有界面时
 * 启动，由它恢复（[AppKeepAlive]）。
 */
class FlareCoreApplication : Application(), ViewModelStoreOwner {
    /** 进程级的 ViewModelStore：从不清空，里面的组合根活到进程结束。 */
    override val viewModelStore: ViewModelStore = ViewModelStore()

    /** 进程里唯一的组合根；第一次读时建（界面、常驻连接谁先用谁建），之后一直是这一个。 */
    val root: FlareRootViewModel by lazy {
        // The view model lives as long as the process: its client factory holds the application context only.
        val factory = FlareRootViewModel.factory(
            filesDir.absolutePath,
            SavedSessionStore(this),
            updateInstaller(this),
        ) { FlareCoreSdk.createClient(this) }
        ViewModelProvider(this, factory)[FlareRootViewModel::class.java]
    }

    override fun onCreate() {
        super.onCreate()
        if (!isMainProcess()) return
        anchorNativeDataRoots()
        AppPush.install(this)
        AppKeepAlive.install(this) { root.store }
    }

    /**
     * The native core resolves its default data root from XDG/HOME conventions, which on Android point under the
     * read-only "/" mount. Anchor them to app-private storage before any client exists, so any default-root fallback
     * (and SQLite/media-cache roots) lands in a writable place, with or without a screen.
     */
    private fun anchorNativeDataRoots() {
        val dataDir = filesDir.absolutePath
        runCatching {
            android.system.Os.setenv("HOME", dataDir, true)
            android.system.Os.setenv("XDG_DATA_HOME", dataDir, true)
            android.system.Os.setenv("TMPDIR", cacheDir.absolutePath, true)
        }
    }

    /** 推送 SDK（个推）会另起自己的进程，那里也跑 `onCreate`；推送模块只装在应用的主进程里。 */
    private fun isMainProcess(): Boolean {
        val name = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            Application.getProcessName()
        } else {
            val pid = Process.myPid()
            getSystemService(ActivityManager::class.java)?.runningAppProcesses?.firstOrNull { it.pid == pid }?.processName
        }
        return name == null || name == packageName
    }
}
