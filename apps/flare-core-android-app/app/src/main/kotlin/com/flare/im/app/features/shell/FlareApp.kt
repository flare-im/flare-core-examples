package com.flare.im.app.features.shell

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.Chat
import androidx.compose.material.icons.outlined.PermMedia
import androidx.compose.material.icons.outlined.Search
import androidx.compose.material.icons.outlined.Science
import androidx.compose.material.icons.outlined.Settings
import com.flare.im.app.R
import android.content.Context
import android.net.ConnectivityManager
import android.net.Network
import android.net.NetworkCapabilities
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import com.flare.im.model.entity.NetworkInterfaceKind
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import com.flare.im.app.core.FlareAppStore
import com.flare.im.app.core.designsystem.FlareAppTheme
import com.flare.im.app.core.designsystem.FlareTheme
import com.flare.im.app.core.domain.AppSection
import com.flare.im.app.core.domain.ThemeChoice
import com.flare.im.app.features.auth.LoginScreen
import com.flare.im.app.features.messaging.chat.ChatScreen
import com.flare.im.app.features.messaging.conversationlist.ConversationListScreen
import com.flare.im.app.features.sdklab.SdkLabScreen
import com.flare.im.app.features.search.SearchScreen
import com.flare.im.app.features.settings.SettingsScreen
import com.flare.im.ui.EmptyState as KitEmptyState
import com.flare.im.ui.FlareApplicationFeatures
import com.flare.im.ui.FlareApplicationNavigationBadge
import com.flare.im.ui.FlareApplicationNavigationGroup
import com.flare.im.ui.FlareApplicationNavigationItem
import com.flare.im.ui.FlareApplicationResponsiveMode
import com.flare.im.ui.FlareApplicationWorkspacePane
import com.flare.im.ui.FlareCapabilitySet
import com.flare.im.ui.FlareIMAppConfiguration
import com.flare.im.ui.FlareToastHost
import com.flare.im.ui.IMAppKit
import com.flare.im.ui.resolveApplicationResponsiveMode

/** App 根：主题 + 登录路由 + 自适应 workbench 导航。 */
@Composable
fun FlareApp(store: FlareAppStore) {
    val theme by store.environment.theme.collectAsState()
    val loggedIn by store.session.isLoggedIn.collectAsState()
    val dark = when (theme) {
        ThemeChoice.System -> null
        ThemeChoice.Light -> false
        ThemeChoice.Dark -> true
    }
    // 热启动：有会话档案则本地出图直进工作台；登录页只在无档案/恢复失败时出现（不闪屏）。
    var resumeAttempted by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        if (!resumeAttempted) {
            store.resumeSavedSession()
            resumeAttempted = true
        }
    }
    // 平台原始信号 → core：网络变化（主动重连）+ 前后台（心跳降配/前台收敛）。策略全在 core。
    val appContext = LocalContext.current.applicationContext
    DisposableEffect(loggedIn) {
        if (!loggedIn) return@DisposableEffect onDispose {}
        val connectivity = appContext.getSystemService(Context.CONNECTIVITY_SERVICE) as? ConnectivityManager
        val callback = object : ConnectivityManager.NetworkCallback() {
            override fun onAvailable(network: Network) {
                store.notifyNetworkChange(true, currentInterfaceKind(connectivity), "network_available")
            }

            override fun onLost(network: Network) {
                store.notifyNetworkChange(false, NetworkInterfaceKind.UNKNOWN, "network_lost")
            }

            override fun onCapabilitiesChanged(network: Network, capabilities: NetworkCapabilities) {
                store.notifyNetworkChange(true, interfaceKindOf(capabilities), "capabilities_changed")
            }
        }
        runCatching { connectivity?.registerDefaultNetworkCallback(callback) }
        onDispose { runCatching { connectivity?.unregisterNetworkCallback(callback) } }
    }
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(loggedIn, lifecycleOwner) {
        if (!loggedIn) return@DisposableEffect onDispose {}
        val observer = LifecycleEventObserver { _, event ->
            when (event) {
                Lifecycle.Event.ON_START -> store.setAppForeground(true)
                Lifecycle.Event.ON_STOP -> store.setAppForeground(false)
                else -> Unit
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }
    FlareAppTheme(dark = dark) {
        val colors = FlareTheme.colors
        // The kit's feedback presenter: toasts (保存到本机 answers with one) and the danger confirm dialog.
        FlareToastHost(modifier = Modifier.fillMaxSize()) {
            Box(Modifier.fillMaxSize().background(colors.background)) {
                when {
                    loggedIn -> WorkbenchScreen(store)
                    resumeAttempted -> LoginScreen(store)
                    else -> Unit
                }
                val busy by store.environment.isBusy.collectAsState()
                if (busy) {
                    Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.08f)), Alignment.Center) {
                        CircularProgressIndicator(color = colors.brand)
                    }
                }
            }
        }
    }
}

private fun interfaceKindOf(capabilities: NetworkCapabilities?): NetworkInterfaceKind = when {
    capabilities == null -> NetworkInterfaceKind.UNKNOWN
    capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> NetworkInterfaceKind.WIFI
    capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> NetworkInterfaceKind.CELLULAR
    capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> NetworkInterfaceKind.ETHERNET
    else -> NetworkInterfaceKind.OTHER
}

private fun currentInterfaceKind(connectivity: ConnectivityManager?): NetworkInterfaceKind {
    val network = connectivity?.activeNetwork ?: return NetworkInterfaceKind.UNKNOWN
    return interfaceKindOf(connectivity.getNetworkCapabilities(network))
}

@Composable
private fun WorkbenchScreen(store: FlareAppStore) {
    val section by store.environment.section.collectAsState()
    val selectedId by store.environment.selectedConversationId.collectAsState()
    val conversations by store.messagingViewModel.conversations.collectAsState()
    val showChat = section == AppSection.Conversations && selectedId != null

    // 导航是状态驱动的（section + 选中会话），没有返回栈；不接系统返回，返回键就直接结束 Activity。
    // 返回的顺序与界面层级一致：聊天 → 会话列表，其它分区 → 消息。
    BackHandler(enabled = showChat) { store.environment.setSelectedConversationId(null) }
    BackHandler(enabled = !showChat && section != AppSection.Conversations) {
        store.environment.setSection(AppSection.Conversations)
    }

    // enableEdgeToEdge 让内容铺到状态栏、手势条与键盘之下（Android 15 起系统强制）。工作台自己不让位，
    // 页头就压在状态栏里（聊天返回键点不到），输入区压在手势条上，键盘还会盖住发送键。
    // 在工作台根部统一让出 safeDrawing（含 IME）并消费掉；kit 底部导航随之不再重复加导航栏内边距。
    BoxWithConstraints(Modifier.fillMaxSize().windowInsetsPadding(WindowInsets.safeDrawing)) {
        val mode = resolveApplicationResponsiveMode(maxWidth)
        val unread = conversations.sumOf { it.core.unreadCount }
        val groups = listOf(
            FlareApplicationNavigationGroup(
                id = "reference",
                items = listOf(
                    FlareApplicationNavigationItem(
                        id = "chats",
                        label = stringResource(R.string.nav_messages),
                        icon = "chats",
                        badge = unread.takeIf { it > 0 }?.let {
                            FlareApplicationNavigationBadge(
                                count = it,
                                label = "Unread conversations",
                            )
                        },
                    ),
                    FlareApplicationNavigationItem("search", stringResource(R.string.nav_search), "search"),
                    FlareApplicationNavigationItem("media", "Media", "image", enabled = false),
                    FlareApplicationNavigationItem("settings", stringResource(R.string.nav_settings), "settings"),
                    FlareApplicationNavigationItem("sdk-lab", stringResource(R.string.nav_sdk_status), "diagnostics"),
                ),
            ),
        )
        val activeId = when (section) {
            AppSection.Conversations -> "chats"
            AppSection.Search -> "search"
            AppSection.SdkLab -> "sdk-lab"
            AppSection.Settings -> "settings"
        }
        val activePane = if (
            mode == FlareApplicationResponsiveMode.Mobile &&
            section == AppSection.Conversations && !showChat
        ) FlareApplicationWorkspacePane.Primary else FlareApplicationWorkspacePane.Content

        IMAppKit(
            configuration = FlareIMAppConfiguration(
                features = FlareApplicationFeatures(
                    contacts = false,
                    groups = false,
                    calls = false,
                    media = false,
                ),
                capabilities = FlareCapabilitySet(setOf("reply", "media", "retry", "messageActions")),
            ),
            groups = groups,
            activeNavigationId = activeId,
            onNavigate = { id ->
                when (id) {
                    "chats" -> store.environment.setSection(AppSection.Conversations)
                    "search" -> store.environment.setSection(AppSection.Search)
                    "settings" -> store.environment.setSection(AppSection.Settings)
                    "sdk-lab" -> store.environment.setSection(AppSection.SdkLab)
                }
            },
            destination = {
                com.flare.im.ui.AppLayout(
                    primary = if (section == AppSection.Conversations) {
                        { ConversationListScreen(store) }
                    } else null,
                    activePane = activePane,
                    content = {
                        when (section) {
                            AppSection.Conversations -> if (showChat) {
                                ChatScreen(store)
                            } else {
                                KitEmptyState(
                                    title = stringResource(R.string.choose_conversation),
                                    description = stringResource(R.string.choose_conversation_hint),
                                )
                            }
                            AppSection.Search -> SearchScreen(store)
                            AppSection.SdkLab -> SdkLabScreen(store)
                            AppSection.Settings -> SettingsScreen(store)
                        }
                    },
                )
            },
        )
    }
}
