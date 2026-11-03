package com.flare.im.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.lifecycle.viewmodel.compose.viewModel
import com.flare.im.app.core.platform.AndroidPlatformAdapter
import com.flare.im.app.features.shell.FlareApp
import com.flare.im.ui.FlarePlatformProvider

/**
 * 单 Activity 宿主：装配 [FlareRootViewModel]（持组合根 FlareAppStore）并渲染 [FlareApp]。
 */
class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 全屏：内容铺到状态栏/导航栏之下（渐变品牌头满铺，对齐 iOS）。各屏自行用 inset padding。
        enableEdgeToEdge()
        val dataDir = filesDir.absolutePath
        // The native core resolves its default data root from XDG/HOME conventions, which on
        // Android point under the read-only "/" mount. Anchor them to app-private storage so
        // any default-root fallback (and SQLite/media-cache roots) lands in a writable place.
        runCatching {
            android.system.Os.setenv("HOME", dataDir, true)
            android.system.Os.setenv("XDG_DATA_HOME", dataDir, true)
            android.system.Os.setenv("TMPDIR", cacheDir.absolutePath, true)
        }
        val savedSessionStore = com.flare.im.app.core.session.SavedSessionStore(applicationContext)
        // Layer 5（spec/platform-contract.json）：宿主声明并执行原生能力，kit 只读 capabilities。
        // 在 onCreate 注册 ActivityResult 契约（onStart 之前），配置变更后结果仍能回到新实例。
        val platform = AndroidPlatformAdapter(
            context = applicationContext,
            registry = activityResultRegistry,
            widthDp = { resources.configuration.screenWidthDp },
        )
        setContent {
            val root: FlareRootViewModel =
                viewModel(factory = FlareRootViewModel.factory(dataDir, savedSessionStore))
            FlarePlatformProvider(platform) {
                FlareApp(root.store)
            }
        }
    }
}
