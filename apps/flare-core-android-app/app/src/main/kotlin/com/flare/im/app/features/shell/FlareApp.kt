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
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.res.stringResource
import com.flare.im.app.core.FlareAppStore
import com.flare.im.app.core.designsystem.FlareAppPalette
import com.flare.im.app.core.designsystem.FlareAppTheme
import com.flare.im.app.core.designsystem.FlareTheme
import com.flare.im.app.core.domain.AppSection
import com.flare.im.app.core.domain.ThemeChoice
import com.flare.im.app.core.domain.toKitStatus
import com.flare.im.app.features.auth.LoginScreen
import com.flare.im.app.features.messaging.chat.ChatScreen
import com.flare.im.app.features.messaging.conversationlist.ConversationListScreen
import com.flare.im.app.features.sdklab.SdkLabScreen
import com.flare.im.app.features.search.SearchScreen
import com.flare.im.app.features.settings.AccessDiagnosticsScreen
import com.flare.im.app.features.settings.SettingsScreen
import com.flare.im.ui.ConnectionNotice
import com.flare.im.ui.EmptyState as KitEmptyState
import com.flare.im.ui.FlareSizes
import com.flare.im.ui.screenHeaderHeight
import com.flare.im.ui.FlareApplicationFeatures
import com.flare.im.ui.FlareApplicationNavigationBadge
import com.flare.im.ui.FlareApplicationNavigationGroup
import com.flare.im.ui.FlareApplicationNavigationItem
import com.flare.im.ui.FlareApplicationResponsiveMode
import com.flare.im.ui.FlareApplicationWorkspacePane
import com.flare.im.ui.FlareCapabilitySet
import com.flare.im.ui.FlareIMAppConfiguration
import com.flare.im.ui.FlareThemeMode
import com.flare.im.ui.FlareToastHost
import com.flare.im.ui.IMAppKit
import com.flare.im.ui.flareStrings
import com.flare.im.ui.resolveApplicationResponsiveMode
import com.flare.im.update.FlareUpdatePromptForm
import com.flare.im.update.ui.FlareUpdatePromptHost
import com.flare.im.update.ui.FlareUpdateResourceScope
import kotlinx.coroutines.launch

/** App 根：主题 + 登录路由 + 自适应 workbench 导航。 */
@Composable
fun FlareApp(store: FlareAppStore, recoveryLink: String?, onRecoveryLinkTaken: () -> Unit) {
    val theme by store.environment.theme.collectAsState()
    val loggedIn by store.session.isLoggedIn.collectAsState()
    val dark = when (theme) {
        ThemeChoice.System -> null
        ThemeChoice.Light -> false
        ThemeChoice.Dark -> true
    }
    val resourceMode = when (theme) {
        ThemeChoice.System -> FlareThemeMode.System
        ThemeChoice.Light -> FlareThemeMode.Light
        ThemeChoice.Dark -> FlareThemeMode.Dark
    }
    // 热启动：有会话档案则本地出图直进工作台；登录页只在无档案/恢复失败时出现（不闪屏）。
    var resumeAttempted by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) {
        if (!resumeAttempted) {
            store.resumeSavedSession()
            resumeAttempted = true
        }
    }
    // The update center reads through the client, which the resume brings up: it starts right after, signed in or not.
    LaunchedEffect(resumeAttempted) { if (resumeAttempted) store.updateCenter.install() }
    // The language the app shows: its resources, which a system change replaces without a restart.
    val language = stringResource(R.string.flare_kit_language)
    val locale = if (language == "zh") "zh-CN" else "en-US"
    LaunchedEffect(resumeAttempted, locale) {
        if (resumeAttempted) store.updateCenter.launch { setLocale(locale) }
    }
    // A recovery link waits for the saved session's resume, which is what brings the client up.
    LaunchedEffect(resumeAttempted, recoveryLink) {
        if (resumeAttempted && recoveryLink != null) {
            onRecoveryLinkTaken()
            store.accessDiagnostics.openRecoveryLink(recoveryLink)
        }
    }
    FlareAppTheme(dark = dark) {
        AppResources(store, locale, resourceMode) {
            val colors = FlareTheme.colors
            // The kit's feedback presenter: toasts (保存到本机 answers with one) and the danger confirm dialog.
            FlareToastHost(modifier = Modifier.fillMaxSize()) {
                Box(Modifier.fillMaxSize().background(colors.background)) {
                    when {
                        loggedIn -> {
                            WorkbenchScreen(store)
                            WorkbenchConnectionNotice(store, Modifier.align(Alignment.TopCenter))
                        }
                        resumeAttempted -> LoginScreen(store)
                        else -> Unit
                    }
                    val busy by store.environment.isBusy.collectAsState()
                    if (busy) {
                        Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.08f)), Alignment.Center) {
                            CircularProgressIndicator(color = colors.brand)
                        }
                    }
                    // The network and line page sits over sign-in and the workbench: a recovery link can open it in either.
                    if (store.accessDiagnostics.presented) {
                        // The empty pointer modifier keeps taps from reaching the page underneath.
                        Box(Modifier.fillMaxSize().pointerInput(Unit) {}) {
                            AccessDiagnosticsScreen(store.accessDiagnostics, onBack = { store.accessDiagnostics.presented = false })
                        }
                    }
                    // The update prompt over everything, in either sign-in state.
                    FlareUpdatePromptHost(store.updateCenter)
                }
            }
        }
    }
}

/** Resource packs over the built-in strings and colours, once they are read; nothing below waits for them. */
@Composable
private fun AppResources(store: FlareAppStore, locale: String, mode: FlareThemeMode, content: @Composable () -> Unit) {
    FlareUpdateResourceScope(store.updateCenter, locale, mode) { FlareAppPalette(content) }
}

/**
 * The connection notice over the signed-in workbench: the kit's ConnectionNotice reads the core SDK's
 * `connection://status` as it arrives and decides what shows when. 立即重试 asks the SDK for its next round now;
 * 重新登录 (kicked or expired) signs out to the login page; 诊断 opens the network and line page.
 */
@Composable
private fun WorkbenchConnectionNotice(store: FlareAppStore, modifier: Modifier = Modifier) {
    val status by store.session.connectionStatus.collectAsState()
    val scope = rememberCoroutineScope()
    Box(
        modifier.windowInsetsPadding(WindowInsets.safeDrawing)
            .padding(top = FlareSizes.screenHeaderHeight + FlareSizes.spacingXs, start = FlareSizes.spacingLg, end = FlareSizes.spacingLg),
    ) {
        ConnectionNotice(
            status = status?.toKitStatus(),
            floating = true,
            onRetry = { scope.launch { runCatching { store.session.reconnectNow() } } },
            onSignIn = { scope.launch { store.logout() } },
            onUpdate = { store.updateCenter.launch { update() } },
            onDiagnose = { store.accessDiagnostics.presented = true },
        )
    }
}

@Composable
private fun WorkbenchScreen(store: FlareAppStore) {
    val section by store.environment.section.collectAsState()
    val selectedId by store.environment.selectedConversationId.collectAsState()
    val conversations by store.messagingViewModel.conversations.collectAsState()
    val updateStatus by store.updateCenter.state.collectAsState()
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
                    FlareApplicationNavigationItem(
                        id = "settings",
                        label = stringResource(R.string.nav_settings),
                        icon = "settings",
                        badge = if (updateStatus?.prompt == FlareUpdatePromptForm.BADGE) {
                            FlareApplicationNavigationBadge(
                                kind = FlareApplicationNavigationBadge.Kind.Dot,
                                label = flareStrings().settingsRowBadge,
                            )
                        } else null,
                    ),
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
