import Combine
import Foundation
import FlareCoreAppleSDK
import FlareIMUI

/// 跨切面会话核心:拥有 SDK 客户端的生命周期 + 认证态 + 连接态 + 原始事件流。
///
/// 连接态只读 SDK 的 `connection://status`(`events.onConnectionStatusChanged`):重连、换线、网络与前后台上报都在
/// SDK 里(`init` 成功后自动装上 PlatformLifecycle),App 不再自己监听网络、上报前后台或重建会话。
///
/// 从 god-store 抽出 —— 这是**唯一**持有 `any FlareImClientProtocol` 的地方;ViewModel / Repository
/// 经它拿到客户端的协议门面去调用。事件经回调路由到数据层(`onViewUpdate`)与聊天层(`onMessageSendFailed`),
/// 避免 Session 反向依赖具体的会话/消息状态。
@MainActor
final class AppSession: ObservableObject {
    @Published private(set) var currentUserId: String?
    @Published private(set) var isLoggedIn = false
    /// The SDK's latest `connection://status`, whole; nil before the first (and after signing out).
    @Published private(set) var connectionStatus: ConnectionStatus?
    @Published private(set) var eventLog: [EventLogEntry] = []

    /// 唯一的客户端持有点(其余层经协议门面使用)。
    private(set) var client: (any FlareImClientProtocol)?

    /// 事件路由钩子(由数据层/聊天层注入)。@MainActor 闭包:回调里可直接调 @MainActor 状态。
    var onViewUpdate: (@MainActor (ViewUpdate) -> Void)?
    var onMessageSendFailed: (@MainActor (String) -> Void)?
    var onUpdateState: (@MainActor (UpdateStatus) -> Void)?

    private let clientFactory: SdkClientFactory
    private let access: AppAccess
    private var eventSubscriptions: [any EventSubscription] = []
    private var nativeEventSubscription: [String: AnySendable]?
    private var lastLoginDraft: LoginDraft?
    /// Statuses received since the client was created: the status read after subscribing never replaces a newer one.
    private var connectionStatusEvents = 0
    /// What ``accessClient(draft:dataURL:)`` initialized without a session; the sign-in that follows continues on it.
    private var sessionlessInit: (dataURL: URL, tenantId: String)?
    /// That initialization while it runs: a sign-in during the update center's first read continues on its client.
    private var sessionlessBringUp: Task<Void, Error>?

    nonisolated init(clientFactory: SdkClientFactory = DefaultSdkClientFactory(), access: AppAccess = .current) {
        self.clientFactory = clientFactory
        self.access = access
    }

    /// 创建 → 订阅 → init → 取 token → 登录 → 订阅原生事件。`progress` 回报阶段供上层更新 UI 状态。
    @discardableResult
    func start(draft: LoginDraft, dataURL: URL, progress: @MainActor (String) -> Void) async throws -> any FlareImClientProtocol {
        let client = try await initializedClient(draft: draft, dataURL: dataURL, progress: progress)

        progress("Logging in")
        try await client.login(Self.loginRequest(draft: draft))
        try await subscribeNativeEvents(client)

        // 配置 SDK 托管的媒体磁盘缓存（LRU + 去重，核心已实现）：设根目录 + 上限，
        // 之后看过的图片经 media.resolve_access(autoCache) 落到这里（离线可用、不重复下载）。
        await configureMediaCache(client, dataURL: dataURL)

        currentUserId = draft.userId
        isLoggedIn = true
        lastLoginDraft = draft
        await readConnectionStatus(client)
        return client
    }

    /// 热启动半段：创建 → 订阅 → init → prepare(开本地库,不连网) → 本地会话即已可读。
    /// 连接（取 token + connect + 首次同步）由调用方在后台补（[connectInBackground]）。
    @discardableResult
    func resumeLocal(draft: LoginDraft, dataURL: URL, progress: @MainActor (String) -> Void) async throws -> any FlareImClientProtocol {
        let client = try await initializedClient(draft: draft, dataURL: dataURL, progress: progress)

        progress("Opening local store")
        try await client.prepare(["userId": AnySendable(draft.userId)])
        try await subscribeNativeEvents(client)

        await configureMediaCache(client, dataURL: dataURL)

        currentUserId = draft.userId
        isLoggedIn = true
        lastLoginDraft = draft
        return client
    }

    /// A client created, subscribed and initialized for this sign-in, unless ``accessClient(draft:dataURL:)`` already
    /// brought one up for the same data directory and tenant.
    private func initializedClient(draft: LoginDraft, dataURL: URL, progress: @MainActor (String) -> Void) async throws -> any FlareImClientProtocol {
        if let sessionlessBringUp { _ = try? await sessionlessBringUp.value }
        defer { sessionlessInit = nil }
        if let client, let ready = sessionlessInit, ready.dataURL == dataURL, ready.tenantId == draft.tenantId {
            return client
        }
        progress("Creating Apple SDK client")
        let client = try clientFactory.makeClient(libraryPath: draft.libraryPath)
        self.client = client
        installEventSubscriptions(client)

        progress("Initializing SDK")
        try await client.`init`(Self.sessionInitConfig(draft: draft, dataURL: dataURL, access: access))
        return client
    }

    /// The client `access.*` runs on. It needs no session, and a recovery link can arrive before anyone signed in: the
    /// SDK then comes up without one.
    func accessClient(draft: LoginDraft, dataURL: URL) async throws -> any FlareImClientProtocol {
        if let sessionlessBringUp { try await sessionlessBringUp.value }
        if let client { return client }
        let client = try clientFactory.makeClient(libraryPath: draft.libraryPath)
        self.client = client
        installEventSubscriptions(client)
        let config = Self.sessionInitConfig(draft: draft, dataURL: dataURL, access: access)
        let bringUp = Task<Void, Error> { _ = try await client.`init`(config) }
        sessionlessBringUp = bringUp
        defer { sessionlessBringUp = nil }
        do {
            try await bringUp.value
        } catch {
            self.client = nil
            throw error
        }
        sessionlessInit = (dataURL, draft.tenantId)
        return client
    }

    /// The events the network and line page reads again on; the returned function stops listening.
    func subscribeLinkEvents(_ onLinkEvent: @escaping @Sendable () -> Void) -> () -> Void {
        guard let client else { return {} }
        let subscriptions: [any EventSubscription] = [
            client.events.onConnectionStatusChanged { _ in onLinkEvent() },
            client.events.onAccessChanged { _ in onLinkEvent() },
            client.events.onAccessSwitched { _ in onLinkEvent() },
        ]
        return { subscriptions.forEach { $0.unsubscribe() } }
    }

    /// 热启动网络半段：本地出图后在后台建连并完成首次同步，失败保持本地视图可用。链路自己能恢复的失败（没网、
    /// 连不上、过载）connect 照样返回成功，在不在线只看 `connection://status`；这里只记下终态错误，不重试。
    func connectInBackground() async {
        guard let client, let draft = lastLoginDraft else { return }
        do {
            try await client.connect(Self.loginRequest(draft: draft))
        } catch {
            appendEvent("connection", name: "connect_failed", detail: FlareFormatters.errorText(error))
        }
        await readConnectionStatus(client)
    }

    /// The connection notice's 立即重试: the SDK starts its next round now.
    func reconnectNow() async throws {
        guard let client else { throw AppStoreError(message: "SDK client is not initialized") }
        try await client.connection.reconnectNow()
    }

    /// The connection notice's input: the SDK's status as the kit reads it.
    var kitConnectionStatus: FlareConnectionStatus? { connectionStatus.map(FlareConnectionStatus.init) }

    /// 媒体缓存放在本账号数据目录下，上限 256 MB。
    private func configureMediaCache(_ client: any FlareImClientProtocol, dataURL: URL) async {
        _ = try? await client.media.setMediaCacheRoot(Self.mediaCacheRootRequest(dataURL: dataURL))
        _ = try? await client.media.setMediaCacheMaxBytes(["maxBytes": AnySendable(Self.mediaCacheMaxBytes)])
    }

    nonisolated static let mediaCacheMaxBytes: Int64 = 268_435_456

    /// `media.set_cache_root` 的请求：核心契约的键是 `absolutePath`（此前发的 `root` 只被新版核心兼容，
    /// 旧核心会当成没给路径、缓存落到默认目录）。
    nonisolated static func mediaCacheRootRequest(dataURL: URL) -> [String: AnySendable] {
        ["absolutePath": AnySendable(dataURL.appendingPathComponent("media-cache").path)]
    }

    /// Reads where the connection stands now, unless a status event already said so.
    private func readConnectionStatus(_ client: any FlareImClientProtocol) async {
        let seen = connectionStatusEvents
        guard let status = try? await client.connection.getStatus(), seen == connectionStatusEvents,
              client === self.client else { return }
        connectionStatus = status
    }

    func logout() async throws {
        guard let client else { throw AppStoreError(message: "SDK client is not initialized") }
        defer {
            isLoggedIn = false
            currentUserId = nil
            nativeEventSubscription = nil
            lastLoginDraft = nil
            connectionStatus = nil
        }
        try await client.logout()
    }

    func dispose() async throws {
        eventSubscriptions.forEach { $0.unsubscribe() }
        eventSubscriptions.removeAll()
        try await client?.dispose()
        client = nil
        isLoggedIn = false
        currentUserId = nil
        nativeEventSubscription = nil
        lastLoginDraft = nil
        connectionStatus = nil
    }

    func refreshConnectionStatus() async throws {
        guard let client else { return }
        connectionStatus = try await client.connection.getStatus()
    }

    /// SDK Lab 的 `events.unsubscribe_all` 后重装订阅。
    func reinstallEventSubscriptions() {
        guard let client else { return }
        eventSubscriptions.removeAll()
        installEventSubscriptions(client)
    }

    /// 应用托管：高级区粘贴了业务后端签好的 token 就原样用；否则不传，SDK 向网关签发并自动刷新。
    nonisolated static func explicitToken(draft: LoginDraft) -> String? {
        let override = draft.tokenOverride.trimmingCharacters(in: .whitespacesAndNewlines)
        return override.isEmpty ? nil : override
    }

    nonisolated static func loginRequest(draft: LoginDraft) -> [String: AnySendable] {
        var request: [String: AnySendable] = ["userId": AnySendable(draft.userId)]
        if let token = explicitToken(draft: draft) {
            request["token"] = AnySendable(token)
        }
        return request
    }

    /// The init config: data directory, tenant, the build's access configuration (``AppAccess``), the private CA when
    /// one is given, and SDK-managed connect tokens (`auth: {}`: the SDK issues and renews them on the Core API of the
    /// access point it uses). The client never mints tokens itself (that would put the signing key in the app); a
    /// token pasted in Settings goes to `login` as given.
    nonisolated static func sessionInitConfig(draft: LoginDraft, dataURL: URL, access: AppAccess) -> [String: AnySendable] {
        var config = draft.trustConfig()
        config["dataUrl"] = AnySendable(dataURL.absoluteString)
        config["tenantId"] = AnySendable(draft.tenantId)
        config["access"] = AnySendable(access.access)
        config["auth"] = AnySendable([String: Any]())
        config["platform"] = AnySendable("apple")
        config["runtime"] = AnySendable("swiftui-example")
        config["app"] = AnySendable(AppAccess.updateApp)
        return config
    }

    private func installEventSubscriptions(_ client: any FlareImClientProtocol) {
        eventSubscriptions.forEach { $0.unsubscribe() }
        connectionStatusEvents = 0
        eventSubscriptions = [
            client.events.onConnectionStatusChanged { [weak self, weak client] status in
                Task { @MainActor in
                    guard let self, let client, client === self.client else { return }
                    self.connectionStatusEvents += 1
                    self.connectionStatus = status
                    self.appendEvent("connection", name: status.phase.rawValue,
                                     detail: [status.reason, status.accessPointId, status.protocol].compactMap { $0 }.joined(separator: " "))
                }
            },
            client.events.onUpdateState { [weak self] status in
                Task { @MainActor in self?.onUpdateState?(status) }
            },
            client.events.onInitialized { [weak self] event in
                Task { @MainActor in self?.appendEvent("lifecycle", name: event.name.rawValue, detail: event.operation) }
            },
            client.events.onLoginSucceeded { [weak self] event in
                Task { @MainActor in self?.appendEvent("lifecycle", name: event.name.rawValue, detail: event.userId ?? "") }
            },
            client.events.onLoggedOut { [weak self] event in
                Task { @MainActor in self?.appendEvent("lifecycle", name: event.name.rawValue, detail: event.operation) }
            },
            client.events.onMessageReceived { [weak self] event in
                Task { @MainActor in
                    let message = SdkModelMapper.messageFromCore(event.message)
                    self?.appendEvent("message", name: "received", detail: message.previewText)
                }
            },
            client.events.onViewUpdated { [weak self] event in
                Task { @MainActor in
                    self?.appendEvent("view", name: event.kind, detail: event.viewId)
                    self?.onViewUpdate?(event)
                }
            },
            client.events.onMessageSendAck { [weak self] event in
                Task { @MainActor in self?.appendEvent("message", name: "send_ack", detail: event.ack.clientMsgId) }
            },
            client.events.onMessageSendFailed { [weak self] event in
                Task { @MainActor in
                    self?.onMessageSendFailed?(event.clientMsgId)
                    self?.appendEvent("message", name: "send_failed", detail: event.reason)
                }
            },
            client.events.onConversationChanged { [weak self] event in
                Task { @MainActor in self?.appendEvent("conversation", name: event.name.rawValue, detail: event.conversationId ?? "") }
            },
            client.events.onPluginCatalogChanged { [weak self] event in
                Task { @MainActor in self?.appendEvent("plugin", name: "catalog_changed", detail: event.version) }
            }
        ]
    }

    private func subscribeNativeEvents(_ client: any FlareImClientProtocol) async throws {
        nativeEventSubscription = try await client.events.subscribeEvents([
            "sources": AnySendable(["view", "message", "conversation", "sync"])
        ])
    }

    private func appendEvent(_ domain: String, name: String, detail: String) {
        eventLog.insert(EventLogEntry(time: Date(), domain: domain, name: name, detail: detail), at: 0)
        if eventLog.count > 120 { eventLog.removeLast(eventLog.count - 120) }
    }
}
