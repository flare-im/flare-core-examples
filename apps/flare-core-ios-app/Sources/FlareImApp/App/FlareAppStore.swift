import FlareCoreUpdateBridge
import Combine
import Foundation
import FlareCoreAppleSDK
import FlarePlatformUpdate
import SwiftUI


@MainActor
final class FlareAppStore: ObservableObject, AppLifecycle {
    /// 进程里唯一的组合根（其中是唯一的客户端）。应用代理在启动时取它、恢复保存的会话并接上推送宿主，界面之后用的
    /// 是同一个：被后台刷新或静默推送冷启动起来的进程没有界面，会话只能在进程这一级恢复。
    static let shared = FlareAppStore()

    /// 组合根 / 协调器:装配 Core(session/repository/environment)+ 各特性 ViewModel,
    /// 持有跨切面的登录/登出/释放编排([AppLifecycle])。下列计算属性把视图仍读的 `store.xxx` 转发到 Core。
    let session: AppSession
    let repository: ViewDataRepository
    let environment: AppEnvironment
    let messagingViewModel: MessagingViewModel
    let sdkLabViewModel: SdkLabViewModel
    let searchViewModel: SearchViewModel
    let authViewModel: AuthViewModel
    let settingsViewModel: SettingsViewModel
    /// 推送：登录或恢复会话后接上客户端，登出、释放前摘下（进程唯一，由应用代理在启动时开起来）。
    let notifications: PushNotifications
    /// 应用内横幅、提示音与屏幕上的会话：登录或恢复会话后报给新客户端，登出、释放前收走。
    let alerts: MessageAlerts
    private lazy var updateEngine = ClientUpdateEngine { @MainActor [unowned self] in
        try await self.session.accessClient(draft: self.environment.loginDraft, dataURL: self.dataURL())
    }
    /// The update center. `update.*` needs no session: a build too old to sign in has to hear about it first.
    private(set) lazy var updateCenter: FlareUpdateController = {
        let engine = updateEngine
        session.onUpdateState = { engine.receive($0) }
        return FlareUpdateController(engine: engine)
    }()
    var currentUserId: String? { session.currentUserId }
    var isLoggedIn: Bool { session.isLoggedIn }
    var connectionStatus: ConnectionStatus? { session.connectionStatus }
    var eventLog: [EventLogEntry] { session.eventLog }
    var conversations: [AppConversation] { repository.conversations }
    var selectedConversationId: String? {
        get { environment.selectedConversationId }
        set { environment.selectedConversationId = newValue }
    }
    var isBusy: Bool { environment.isBusy }
    var runtimeStatus: RuntimeStatus { environment.runtimeStatus }
    var lastError: String? { environment.lastError }
    var labResults: [LabResult] { environment.labResults }

    private var cancellables = Set<AnyCancellable>()

    init(session: AppSession = AppSession(), repository: ViewDataRepository = ViewDataRepository()) {
        self.session = session
        self.repository = repository
        let environment = AppEnvironment(session: session)
        self.environment = environment
        let messagingViewModel = MessagingViewModel(session: session, repository: repository, environment: environment)
        self.messagingViewModel = messagingViewModel
        let sdkLabViewModel = SdkLabViewModel(session: session, repository: repository, environment: environment, messaging: messagingViewModel)
        self.sdkLabViewModel = sdkLabViewModel
        self.searchViewModel = SearchViewModel(session: session, environment: environment)
        self.authViewModel = AuthViewModel(environment: environment)
        self.settingsViewModel = SettingsViewModel(session: session, environment: environment, sdkLab: sdkLabViewModel)
        self.notifications = PushNotifications.shared
        let alerts = MessageAlerts(session: session)
        self.alerts = alerts
        notifications.onError = { [weak environment] detail in environment?.appendLab("push", status: "warn", detail: detail) }
        session.onNotificationPresent = { [weak alerts] presentation in alerts?.present(presentation) }
        session.onNotificationClear = { [weak alerts] event in alerts?.clear(event) }
        for publisher in [session.objectWillChange, repository.objectWillChange, environment.objectWillChange] {
            publisher.sink { [weak self] in self?.objectWillChange.send() }.store(in: &cancellables)
        }
        session.onViewUpdate = { [weak repository, weak session] update in
            guard let repository, !repository.apply(update), let client = session?.client else { return }
            // 时间线视图版本号跳了:取快照整体替换。
            Task { @MainActor in try? await repository.resyncTimeline(client: client, viewId: update.viewId) }
        }
        session.onMessageSendFailed = { [weak messagingViewModel] key in messagingViewModel?.markSendFailed(key) }
        repository.onLog = { [weak environment] operation, detail in environment?.appendLab(operation, status: "ok", detail: detail) }
        // 选择态留 store(List binding);会话列表变化后若选中项消失则重置(复刻原 delta/snapshot 行为)。
        repository.$conversations
            .sink { [weak self] convos in
                guard let self, let selected = self.selectedConversationId,
                      !convos.contains(where: { $0.conversationId == selected }) else { return }
                self.selectedConversationId = convos.first?.conversationId
            }
            .store(in: &cancellables)
        // 装配完成后回填生命周期(self 此刻已完全初始化),破 store ↔ VM 强引用环。
        authViewModel.bind(lifecycle: self)
        settingsViewModel.bind(lifecycle: self)
        settingsViewModel.bind(messaging: messagingViewModel)
        messagingViewModel.bind(lifecycle: self)
        sdkLabViewModel.bind(lifecycle: self)
    }

    func login() async {
        await perform("login") {
            let client = try await session.start(draft: environment.loginDraft, dataURL: dataURL()) { stage in
                environment.setRuntimeStatus(.loading(stage))
            }
            notifications.signedIn(client: client, tenantId: environment.loginDraft.tenantId, userId: environment.loginDraft.userId)
            alerts.signedIn()
            SavedSessionStore.save(draft: environment.loginDraft)
            environment.section = .conversations
            environment.setRuntimeStatus(.ready)
            await sdkLabViewModel.refreshDiagnostics()
            await sdkLabViewModel.refreshBuilderCatalog()
            await messagingViewModel.bootstrapHome()
            appendLab("login", status: "ok", detail: "Logged in as \(environment.loginDraft.userId)")
        }
        if isLoggedIn { updateCenter.onLoginSucceeded() } else { updateCenter.onLoginFailed() }
    }

    /// 进行中的会话恢复。应用代理启动时发起的与界面随后要的是同一次：进程里只恢复一次、只建一个客户端。
    private var resumption: Task<Bool, Never>?

    /// 热启动：本地会话档案存在时 prepare 本地出图（不等网络），后台建连+同步。
    /// 成功返回 true，UI 直接进入会话工作台。应用代理（[resumeInBackground]）与界面都会调：一次只恢复一个，
    /// 后到的一方等前一个出结果，已经登录就直接返回。
    @discardableResult
    func resumeSavedSession() async -> Bool {
        await startResumption().value
    }

    /// 没有界面时恢复会话：应用代理在启动时调。后台刷新、静默推送把进程冷启动起来时，推送宿主靠它接上；
    /// 界面之后再调 [resumeSavedSession] 时直接拿到同一个结果。
    func resumeInBackground() {
        startResumption()
    }

    /// 进行中的那次恢复，没有就开一次。同步记下：启动后紧接着到的系统回调（静默推送）已经看得到它。
    @discardableResult
    private func startResumption() -> Task<Bool, Never> {
        if let resumption { return resumption }
        let task = Task {
            let resumed = await self.resumeSavedSessionOnce()
            self.resumption = nil
            return resumed
        }
        resumption = task
        return task
    }

    /// 启动时的会话恢复还在进行就等它，最多 `limitMs` 毫秒；没在恢复时立刻返回。
    func waitForResumption(limitMs: UInt64) async {
        let deadline = DispatchTime.now().uptimeNanoseconds + limitMs * 1_000_000
        while resumption != nil, DispatchTime.now().uptimeNanoseconds < deadline {
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    private func resumeSavedSessionOnce() async -> Bool {
        guard !isLoggedIn, let draft = SavedSessionStore.load() else { return isLoggedIn }
        environment.loginDraft = draft
        do {
            let client = try await session.resumeLocal(draft: draft, dataURL: dataURL()) { stage in
                environment.setRuntimeStatus(.loading(stage))
            }
            // 本地库一开就接上：推送冷启动的点击此时才解析出会话，不必等连上网
            notifications.signedIn(client: client, tenantId: draft.tenantId, userId: draft.userId)
            alerts.signedIn()
            environment.section = .conversations
            environment.setRuntimeStatus(.ready)
            await messagingViewModel.bootstrapHome()
            appendLab("session_resume", status: "ok", detail: "Resumed \(draft.userId) from local data")
            Task { [weak self] in
                guard let self else { return }
                await self.session.connectInBackground()
                self.updateCenter.onLoginSucceeded()
                await self.sdkLabViewModel.refreshDiagnostics()
                await self.sdkLabViewModel.refreshBuilderCatalog()
                await self.messagingViewModel.bootstrapHome()
            }
            return true
        } catch {
            SavedSessionStore.clear()
            environment.setRuntimeStatus(.idle)
            appendLab("session_resume", status: "error", detail: String(describing: error))
            return false
        }
    }

    func logout() async {
        // 先摘下推送：之后到的推送不再按这个账号处理，通知中心与角标也清掉
        await notifications.signedOut()
        alerts.signedOut()
        await perform("logout") {
            // A session the server already ended (kicked, expired) may fail its logout: this device signs out anyway.
            SavedSessionStore.clear()
            defer { clearLocalData() }
            try await session.logout()
        }
    }

    func dispose() async {
        await notifications.signedOut()
        alerts.signedOut()
        await perform("dispose") {
            SavedSessionStore.clear()
            try await session.dispose()
            clearLocalData()
        }
    }

    /// 清理 store 自有的会话/时间线缓存(认证/连接由 session 负责)。
    private func clearLocalData() {
        selectedConversationId = nil
        repository.reset()
        environment.setRuntimeStatus(.idle)
    }


    private func perform(_ operation: String, showBusy: Bool = true, body: () async throws -> Void) async {
        await environment.run(operation, showBusy: showBusy, body: body)
    }


    private func dataURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let folder = environment.loginDraft.dataSubfolder.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = base.appendingPathComponent(folder.isEmpty ? "flare-core-ios-app" : folder, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }



    private func appendLab(_ operation: String, status: String, detail: String) {
        environment.appendLab(operation, status: status, detail: detail)
    }

    private func unavailable(_ message: String) -> AppStoreError {
        AppStoreError(message: message)
    }
}

struct AppStoreError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

