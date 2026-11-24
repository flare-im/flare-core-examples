package com.flare.im.app

import android.content.Intent
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.LaunchedEffect
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.repeatOnLifecycle
import com.flare.im.app.core.platform.AndroidPlatformAdapter
import com.flare.im.app.features.shell.FlareApp
import com.flare.im.push.FlarePush
import com.flare.im.update.FlareResumedActivity
import com.flare.im.ui.FlarePlatformProvider
import kotlinx.coroutines.awaitCancellation

/**
 * 单 Activity 宿主：取进程级的 [FlareRootViewModel]（持组合根 FlareAppStore，由 [FlareCoreApplication] 持有）并渲染
 * [FlareApp]。
 */
class MainActivity : ComponentActivity() {
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        FlarePush.handleLaunchIntent(intent)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // The Play update dialog needs the activity on screen, which the view model outlives.
        FlareResumedActivity.track(application)
        if (savedInstanceState == null) {
            // 冷启动的那次点击：会话恢复之前模块先留着它，会话就绪（FlarePush.refresh）后再解析成去向。
            FlarePush.handleLaunchIntent(intent)
        }
        // 全屏：内容铺到状态栏/导航栏之下（渐变品牌头满铺，对齐 iOS）。各屏自行用 inset padding。
        enableEdgeToEdge()
        // 进程级的组合根（唯一的客户端）由 Application 持有：这个页面只用它，关掉或重建都不释放它。
        // The native data roots are anchored there too, before any client exists.
        val root = (application as FlareCoreApplication).root
        // Layer 5（spec/platform-contract.json）：宿主声明并执行原生能力，kit 只读 capabilities。
        // 在 onCreate 注册 ActivityResult 契约（onStart 之前），配置变更后结果仍能回到新实例。
        val platform = AndroidPlatformAdapter(
            context = applicationContext,
            registry = activityResultRegistry,
            widthDp = { resources.configuration.screenWidthDp },
        )
        setContent {
            // 通知点击的去向只在这里收集：界面在前台时打开那条会话，冷启动的点击等会话就绪后才会到。
            LaunchedEffect(root) {
                lifecycle.repeatOnLifecycle(Lifecycle.State.STARTED) {
                    FlarePush.routes.collect { route -> root.store.openFromNotification(route.conversationId) }
                }
            }
            // 界面可见时聊天页上的会话才算在屏幕上：退到后台时引擎照常提醒那个会话的新消息。
            LaunchedEffect(root) {
                lifecycle.repeatOnLifecycle(Lifecycle.State.STARTED) {
                    root.store.alerts.setForeground(true)
                    try {
                        awaitCancellation()
                    } finally {
                        root.store.alerts.setForeground(false)
                    }
                }
            }
            FlarePlatformProvider(platform) {
                FlareApp(root.store)
            }
        }
    }
}
