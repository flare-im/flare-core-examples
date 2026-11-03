package com.flare.im.app.core

import com.flare.im.app.core.data.AppEnvironment
import com.flare.im.app.core.data.ViewDataRepository
import com.flare.im.app.core.domain.AppSection
import com.flare.im.app.core.domain.RuntimeStatus
import com.flare.im.app.core.session.AppLifecycle
import com.flare.im.app.core.session.AppSession
import com.flare.im.app.core.session.SavedSessionStore
import com.flare.im.model.command.NetworkChangeRequest
import com.flare.im.model.command.SetHeartbeatAppStateRequest
import com.flare.im.model.entity.HeartbeatAppState
import com.flare.im.model.entity.NetworkInterfaceKind
import com.flare.im.app.features.auth.AuthViewModel
import com.flare.im.app.features.messaging.MessagingViewModel
import com.flare.im.app.features.search.SearchViewModel
import com.flare.im.app.features.sdklab.SdkLabViewModel
import com.flare.im.app.features.settings.SettingsViewModel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

/**
 * 组合根 / 协调器：装配 Core（session/repository/environment），
 * 持有跨切面登录/登出/释放编排（[AppLifecycle]），并把 session 的 onViewUpdate 接线到 repository。
 * 特性 ViewModel 在 Phase 2+ 装配进来。
 */
class FlareAppStore(
    private val dataDir: String,
    private val scope: CoroutineScope,
    private val savedSessionStore: SavedSessionStore? = null,
) : AppLifecycle {
    val session = AppSession()
    val repository = ViewDataRepository()
    val environment = AppEnvironment()

    val messagingViewModel = MessagingViewModel(session, repository, environment, scope)
    val sdkLabViewModel = SdkLabViewModel(session, environment, scope)
    val searchViewModel = SearchViewModel(session, environment, scope)
    val authViewModel = AuthViewModel(environment, scope)
    val settingsViewModel = SettingsViewModel(
        session, environment, sdkLabViewModel, scope,
        onCacheCleared = { messagingViewModel.forgetResolvedPictures() },
    )

    init {
        // 反应式接线：core 推 ViewUpdate → 重投影本地视图（在 scope 上 re-fetch）。
        session.onViewUpdate = { update ->
            scope.launch { session.client?.let { repository.apply(it, update) } }
        }
        session.onMessageSendFailed = { key -> messagingViewModel.markSendFailed(key) }
        repository.onLog = { operation, detail -> environment.appendLab(operation, "ok", detail) }
        // 装配后回填生命周期（破 store↔VM 环）。
        messagingViewModel.bind(this)
        sdkLabViewModel.bind(this)
        authViewModel.bind(this)
        settingsViewModel.bind(this)
    }

    override suspend fun login() {
        environment.run("login") {
            session.start(environment.loginDraft.value, dataDir) { stage ->
                environment.setRuntimeStatus(RuntimeStatus.Loading(stage))
            }
            savedSessionStore?.save(environment.loginDraft.value)
            environment.setSection(AppSection.Conversations)
            environment.setRuntimeStatus(RuntimeStatus.Ready)
            session.client?.let { repository.openConversationList(it, "login") }
        }
    }

    /**
     * 热启动：本地会话档案存在时 prepare 本地出图（不等网络），
     * 连接与首次同步在后台补齐。成功返回 true，UI 直进工作台。
     */
    suspend fun resumeSavedSession(): Boolean {
        if (session.isLoggedIn.value) return true
        val draft = runCatching { savedSessionStore?.load() }.getOrNull() ?: return false
        return runCatching {
            environment.updateLoginDraft { draft }
            session.resumeLocal(draft, dataDir) { stage ->
                environment.setRuntimeStatus(RuntimeStatus.Loading(stage))
            }
            environment.setSection(AppSection.Conversations)
            environment.setRuntimeStatus(RuntimeStatus.Ready)
            session.client?.let { repository.openConversationList(it, "session_resume") }
            scope.launch {
                session.connectInBackground()
                session.client?.let { repository.openConversationList(it, "session_resume_connected") }
            }
            true
        }.getOrElse {
            runCatching { savedSessionStore?.clear() }
            environment.setRuntimeStatus(RuntimeStatus.Idle)
            environment.appendLab("session_resume", "error", it.message ?: it.toString())
            false
        }
    }

    /** 平台网络变化 → core 主动重连（策略全在 core，这里只喂原始信号）。 */
    fun notifyNetworkChange(available: Boolean, interfaceKind: NetworkInterfaceKind, reason: String) {
        val sdk = session.client ?: return
        scope.launch {
            runCatching {
                sdk.connection.notifyNetworkChange(
                    NetworkChangeRequest(available = available, `interface` = interfaceKind, reason = reason),
                )
            }.onFailure { environment.appendLab("network_change", "error", it.message ?: "$it") }
        }
    }

    /** 前后台切换 → core 心跳降配 + 前台立即收敛。 */
    fun setAppForeground(foreground: Boolean) {
        val sdk = session.client ?: return
        scope.launch {
            runCatching {
                sdk.setHeartbeatAppState(
                    SetHeartbeatAppStateRequest(
                        if (foreground) HeartbeatAppState.FOREGROUND else HeartbeatAppState.BACKGROUND,
                    ),
                )
            }.onFailure { environment.appendLab("heartbeat_app_state", "error", it.message ?: "$it") }
        }
    }

    override suspend fun logout() {
        environment.run("logout") {
            runCatching { savedSessionStore?.clear() }
            session.logout()
            clearLocalData()
        }
    }

    override suspend fun dispose() {
        environment.run("dispose") {
            runCatching { savedSessionStore?.clear() }
            session.dispose()
            clearLocalData()
        }
    }

    private fun clearLocalData() {
        environment.setSelectedConversationId(null)
        repository.reset()
        environment.setRuntimeStatus(RuntimeStatus.Idle)
    }
}
