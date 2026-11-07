import Combine
import Foundation
import FlareCoreAppleSDK
import FlarePlatformUpdate
import SwiftUI


@MainActor
final class FlareAppStore: ObservableObject, AppLifecycle {
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
    /// The network and line page. `access.*` needs no session, so it reads before sign-in as well.
    private(set) lazy var accessDiagnostics = AccessDiagnostics(
        access: { [unowned self] in
            try await self.session.accessClient(draft: self.environment.loginDraft, dataURL: self.dataURL()).access
        },
        subscribeLinkEvents: { [unowned self] onLinkEvent in self.session.subscribeLinkEvents(onLinkEvent) }
    )
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
            try await session.start(draft: environment.loginDraft, dataURL: dataURL()) { stage in
                environment.setRuntimeStatus(.loading(stage))
            }
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

    /// 热启动：本地会话档案存在时 prepare 本地出图（不等网络），后台建连+同步。
    /// 成功返回 true，UI 直接进入会话工作台。
    @discardableResult
    func resumeSavedSession() async -> Bool {
        guard !isLoggedIn, let draft = SavedSessionStore.load() else { return isLoggedIn }
        environment.loginDraft = draft
        do {
            try await session.resumeLocal(draft: draft, dataURL: dataURL()) { stage in
                environment.setRuntimeStatus(.loading(stage))
            }
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
        await perform("logout") {
            // A session the server already ended (kicked, expired) may fail its logout: this device signs out anyway.
            SavedSessionStore.clear()
            defer { clearLocalData() }
            try await session.logout()
        }
    }

    func dispose() async {
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

