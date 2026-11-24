package com.flare.im.app.core

import com.flare.im.app.core.data.AppEnvironment
import com.flare.im.app.core.data.ViewDataRepository
import com.flare.im.app.core.domain.AppSection
import com.flare.im.app.core.domain.RuntimeStatus
import com.flare.im.app.core.notifications.MessageAlerts
import com.flare.im.app.core.push.AppPush
import com.flare.im.app.core.session.AppLifecycle
import com.flare.im.app.core.session.AppSession
import com.flare.im.app.core.session.SavedSessionStore
import com.flare.im.api.FlareImClient
import com.flare.im.app.features.auth.AuthViewModel
import com.flare.im.app.features.messaging.MessagingViewModel
import com.flare.im.app.features.search.SearchViewModel
import com.flare.im.app.features.sdklab.SdkLabViewModel
import com.flare.im.app.features.settings.SettingsViewModel
import com.flare.im.push.CorePushHost
import com.flare.im.update.ClientUpdateEngine
import com.flare.im.update.FlareUpdateController
import com.flare.im.update.FlareUpdateInstaller
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/**
 * 组合根 / 协调器：装配 Core（session/repository/environment），
 * 持有跨切面登录/登出/释放编排（[AppLifecycle]），并把 session 的 onViewUpdate 接线到 repository。
 * 特性 ViewModel 在 Phase 2+ 装配进来。进程里只有一个（[com.flare.im.app.FlareCoreApplication.root]），
 * 界面与常驻连接用的是同一个客户端。
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

    /** 应用内横幅、提示音与屏幕上的会话：登录或恢复会话后报给新客户端，登出、释放前收走。 */
    val alerts = MessageAlerts(session, scope)

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
        session.onNotificationPresent = alerts::present
        session.onNotificationClear = alerts::clear
        repository.onLog = { operation, detail -> environment.appendLab(operation, "ok", detail) }
        // 装配后回填生命周期（破 store↔VM 环）。
        messagingViewModel.bind(this)
        sdkLabViewModel.bind(this)
        authViewModel.bind(this)
        settingsViewModel.bind(this)
    }

    override suspend fun login() {
        AppPush.sessionStarting(this)
        environment.run("login") {
            session.start(environment.loginDraft.value, dataDir) { stage ->
                environment.setRuntimeStatus(RuntimeStatus.Loading(stage))
            }
            savedSessionStore?.save(environment.loginDraft.value)
            environment.setSection(AppSection.Conversations)
            environment.setRuntimeStatus(RuntimeStatus.Ready)
            session.client?.let { repository.openConversationList(it, "login") }
        }
        // 推送宿主跟着这次会话：登录成功后交给推送模块（补报令牌与权限、解析排队的点击）。
        val signedIn = session.client.takeIf { session.isLoggedIn.value }
        if (signedIn != null) AppPush.sessionReady(this, CorePushHost(signedIn)) else AppPush.sessionEnded(this)
        if (signedIn != null) alerts.signedIn()
        if (session.isLoggedIn.value) updateCenter.onLoginSucceeded() else updateCenter.onLoginFailed()
    }

    /**
     * 点开的通知（系统通知由推送模块核对过属于当前账号，应用内横幅来自当前会话的引擎）。回到消息分区打开那条会话；
     * 盖在上面的网络与线路页收起。时间线不支持定位到某条消息，只打开会话。
     */
    fun openFromNotification(conversationId: String) {
        if (!session.isLoggedIn.value) return
        environment.setSection(AppSection.Conversations)
        messagingViewModel.openConversation(conversationId)
    }

    /**
     * 热启动：本地会话档案存在时 prepare 本地出图（不等网络），
     * 连接与首次同步在后台补齐。成功返回 true，UI 直进工作台。界面与常驻连接（[resumeInBackground]）都会调，
     * 一次只恢复一个：后到的一方等前一个出结果，已经登录就直接返回。
     */
    suspend fun resumeSavedSession(): Boolean = resumption.withLock { resumeSavedSessionLocked() }

    /**
     * 没有界面时恢复会话：常驻连接在开机、应用更新或被系统重建后启动，进程里还没有会话，链路要靠它在线。
     * 界面之后再调 [resumeSavedSession] 时直接拿到结果。
     */
    fun resumeInBackground() {
        scope.launch { resumeSavedSession() }
    }

    private val resumption = Mutex()

    private suspend fun resumeSavedSessionLocked(): Boolean {
        if (session.isLoggedIn.value) return true
        val draft = runCatching { savedSessionStore?.load() }.getOrNull() ?: return false
        AppPush.sessionStarting(this)
        return runCatching {
            environment.updateLoginDraft { draft }
            val client = session.resumeLocal(draft, dataDir) { stage ->
                environment.setRuntimeStatus(RuntimeStatus.Loading(stage))
            }
            environment.setSection(AppSection.Conversations)
            environment.setRuntimeStatus(RuntimeStatus.Ready)
            session.client?.let { repository.openConversationList(it, "session_resume") }
            // 本地会话已经恢复，推送用到的账号与本地状态都在：宿主这时就交给推送模块，建连在后台补。
            AppPush.sessionReady(this, CorePushHost(client))
            alerts.signedIn()
            scope.launch {
                session.connectInBackground()
                updateCenter.onLoginSucceeded()
                session.client?.let { repository.openConversationList(it, "session_resume_connected") }
            }
            true
        }.getOrElse {
            AppPush.sessionEnded(this)
            runCatching { savedSessionStore?.clear() }
            environment.setRuntimeStatus(RuntimeStatus.Idle)
            environment.appendLab("session_resume", "error", it.message ?: it.toString())
            false
        }
    }

    override suspend fun logout() {
        // 登出无论服务端答不答都回到登录页：推送宿主先撤下，这个账号的通知一并移除。
        AppPush.signedOut(this)
        alerts.signedOut()
        environment.run("logout") {
            runCatching { savedSessionStore?.clear() }
            session.logout()
            clearLocalData()
        }
    }

    override suspend fun dispose() {
        AppPush.signedOut(this)
        alerts.signedOut()
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
