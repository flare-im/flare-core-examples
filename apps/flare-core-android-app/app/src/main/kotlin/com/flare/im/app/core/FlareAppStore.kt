package com.flare.im.app.core

import com.flare.im.app.core.data.AppEnvironment
import com.flare.im.app.core.data.ViewDataRepository
import com.flare.im.app.core.domain.AppSection
import com.flare.im.app.core.domain.RuntimeStatus
import com.flare.im.app.core.session.AppLifecycle
import com.flare.im.app.core.session.AppSession
import com.flare.im.app.core.session.SavedSessionStore
import com.flare.im.api.FlareImClient
import com.flare.im.app.features.auth.AuthViewModel
import com.flare.im.app.features.messaging.MessagingViewModel
import com.flare.im.app.features.search.SearchViewModel
import com.flare.im.app.features.settings.AccessDiagnosticsHost
import com.flare.im.app.features.sdklab.SdkLabViewModel
import com.flare.im.app.features.settings.SettingsViewModel
import com.flare.im.update.ClientUpdateEngine
import com.flare.im.update.FlareUpdateController
import com.flare.im.update.FlareUpdateInstaller
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
    updateInstaller: FlareUpdateInstaller,
    newClient: () -> FlareImClient,
) : AppLifecycle {
    val session = AppSession(newClient)
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

    /** The network and line page. `access.*` needs no session, so it reads before sign-in as well. */
    val accessDiagnostics = AccessDiagnosticsHost(
        access = { session.accessClient(environment.loginDraft.value, dataDir).access },
        subscribeLinkEvents = session::subscribeLinkEvents,
        scope = scope,
    )

    private val updateEngine = ClientUpdateEngine { session.accessClient(environment.loginDraft.value, dataDir) }

    /** The update center. `update.*` needs no session: a build too old to sign in has to hear about it first. */
    val updateCenter = FlareUpdateController(updateEngine, updateInstaller)

    init {
        // 反应式接线：core 推 ViewUpdate → 重投影本地视图（在 scope 上 re-fetch）。
        session.onViewUpdate = { update ->
            scope.launch { session.client?.let { repository.apply(it, update) } }
        }
        session.onMessageSendFailed = { key -> messagingViewModel.markSendFailed(key) }
        session.onUpdateState = updateEngine::receive
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
        if (session.isLoggedIn.value) updateCenter.onLoginSucceeded() else updateCenter.onLoginFailed()
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
                updateCenter.onLoginSucceeded()
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
