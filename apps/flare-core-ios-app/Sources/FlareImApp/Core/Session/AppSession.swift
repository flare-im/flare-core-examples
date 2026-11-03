import Combine
import Foundation
import Network
import FlareCoreAppleSDK
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// 跨切面会话核心:拥有 SDK 客户端的生命周期 + 认证态 + 连接态 + 原始事件流。
///
/// 从 god-store 抽出 —— 这是**唯一**持有 `any FlareImClientProtocol` 的地方;ViewModel / Repository
/// 经它拿到客户端的协议门面去调用。事件经回调路由到数据层(`onViewUpdate`)与聊天层(`onMessageSendFailed`),
/// 避免 Session 反向依赖具体的会话/消息状态。
@MainActor
final class AppSession: ObservableObject {
    @Published private(set) var currentUserId: String?
    @Published private(set) var isLoggedIn = false
    @Published private(set) var connectionState: ConnectionState = .disconnected
    @Published private(set) var eventLog: [EventLogEntry] = []

    /// 唯一的客户端持有点(其余层经协议门面使用)。
    private(set) var client: (any FlareImClientProtocol)?

    /// 事件路由钩子(由数据层/聊天层注入)。@MainActor 闭包:回调里可直接调 @MainActor 状态。
    var onViewUpdate: (@MainActor (ViewUpdate) -> Void)?
    var onMessageSendFailed: (@MainActor (String) -> Void)?

    private let clientFactory: SdkClientFactory
    private var eventSubscriptions: [any EventSubscription] = []
    private var nativeEventSubscription: [String: AnySendable]?
    private var lastLoginDraft: LoginDraft?
    private var lastDataURL: URL?
    private var restoringConnection = false
    private var pathMonitor: NWPathMonitor?
    private var appStateObservers: [NSObjectProtocol] = []

    nonisolated init(clientFactory: SdkClientFactory = DefaultSdkClientFactory()) {
        self.clientFactory = clientFactory
    }

    /// 创建 → 订阅 → init → 取 token → 登录 → 订阅原生事件。`progress` 回报阶段供上层更新 UI 状态。
    @discardableResult
    func start(draft: LoginDraft, dataURL: URL, progress: @MainActor (String) -> Void) async throws -> any FlareImClientProtocol {
        progress("Creating Apple SDK client")
        let client = try clientFactory.makeClient(libraryPath: draft.libraryPath)
        self.client = client
        installEventSubscriptions(client)

        progress("Initializing SDK")
        var initConfig = try draft.sdkTransportConfig()
        initConfig.merge(Self.sessionInitConfig(draft: draft, dataURL: dataURL)) { _, new in new }
        try await client.`init`(initConfig)

        progress("Logging in")
        try await client.login(Self.loginRequest(draft: draft))
        try await subscribeNativeEvents(client)

        // 配置 SDK 托管的媒体磁盘缓存（LRU + 去重，核心已实现）：设根目录 + 上限，
        // 之后看过的图片经 media.resolve_access(autoCache) 落到这里（离线可用、不重复下载）。
        await configureMediaCache(client, dataURL: dataURL)

        currentUserId = draft.userId
        isLoggedIn = true
        connectionState = try await client.connection.getConnectionState()
        lastLoginDraft = draft
        lastDataURL = dataURL
        startPlatformSignalBridge()
        return client
    }

    /// 热启动半段：创建 → 订阅 → init → prepare(开本地库,不连网) → 本地会话即已可读。
    /// 连接（取 token + connect + 首次同步）由调用方在后台补（[connectInBackground]）。
    @discardableResult
    func resumeLocal(draft: LoginDraft, dataURL: URL, progress: @MainActor (String) -> Void) async throws -> any FlareImClientProtocol {
        progress("Creating Apple SDK client")
        let client = try clientFactory.makeClient(libraryPath: draft.libraryPath)
        self.client = client
        installEventSubscriptions(client)

        progress("Initializing SDK")
        var initConfig = try draft.sdkTransportConfig()
        initConfig.merge(Self.sessionInitConfig(draft: draft, dataURL: dataURL)) { _, new in new }
        try await client.`init`(initConfig)

        progress("Opening local store")
        try await client.prepare(["userId": AnySendable(draft.userId)])
        try await subscribeNativeEvents(client)

        await configureMediaCache(client, dataURL: dataURL)

        currentUserId = draft.userId
        isLoggedIn = true
        lastLoginDraft = draft
        lastDataURL = dataURL
        startPlatformSignalBridge()
        return client
    }

    /// 热启动网络半段：本地出图后在后台建连并完成首次同步；失败保持本地视图可用。
    func connectInBackground() async {
        guard let client, let draft = lastLoginDraft else { return }
        do {
            try await client.connect(Self.loginRequest(draft: draft))
            connectionState = (try? await client.connection.getConnectionState()) ?? connectionState
        } catch {
            connectionState = (try? await client.connection.getConnectionState()) ?? .disconnected
        }
    }

    @discardableResult
    func ensureConnected(progress: @MainActor (String) -> Void) async throws -> any FlareImClientProtocol {
        if let client, (try? await client.isConnected()) == true {
            isLoggedIn = true
            currentUserId = currentUserId ?? (lastLoginDraft?.userId)
            connectionState = try await client.connection.getConnectionState()
            return client
        }

        while restoringConnection {
            try await Task.sleep(nanoseconds: 120_000_000)
            if let client, (try? await client.isConnected()) == true {
                connectionState = try await client.connection.getConnectionState()
                return client
            }
        }

        guard var draft = lastLoginDraft, let dataURL = lastDataURL else {
            throw AppStoreError(message: "Login before using the SDK")
        }

        restoringConnection = true
        defer { restoringConnection = false }

        progress("Reconnecting")
        connectionState = .reconnecting
        eventSubscriptions.forEach { $0.unsubscribe() }
        eventSubscriptions.removeAll()
        try? await client?.dispose()
        client = nil
        nativeEventSubscription = nil
        isLoggedIn = false
        currentUserId = nil
        return try await start(draft: draft, dataURL: dataURL, progress: progress)
    }

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

    /// 平台原始信号桥：NWPathMonitor → SDK 网络变化（core 主动重连，不等心跳超时）、
    /// 前后台通知 → 心跳降配 + 前台立即收敛。策略全在 core，这里只喂信号。
    func startPlatformSignalBridge() {
        guard pathMonitor == nil else { return }
        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { [weak self] path in
            let available = path.status == .satisfied
            let kind: NetworkInterfaceKind = path.usesInterfaceType(.wifi) ? .wifi
                : path.usesInterfaceType(.cellular) ? .cellular
                : path.usesInterfaceType(.wiredEthernet) ? .ethernet
                : available ? .other : .unknown
            let expensive = path.isExpensive
            Task { @MainActor [weak self] in
                await self?.notifyNetworkChange(available: available, kind: kind, expensive: expensive)
            }
        }
        monitor.start(queue: DispatchQueue(label: "flare.network.path-monitor"))
        pathMonitor = monitor

        let center = NotificationCenter.default
        #if canImport(UIKit)
        let foregroundName = UIApplication.didBecomeActiveNotification
        let backgroundName = UIApplication.didEnterBackgroundNotification
        #elseif canImport(AppKit)
        let foregroundName = NSApplication.didBecomeActiveNotification
        let backgroundName = NSApplication.didResignActiveNotification
        #endif
        appStateObservers.append(center.addObserver(forName: foregroundName, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.setAppForeground(true) }
        })
        appStateObservers.append(center.addObserver(forName: backgroundName, object: nil, queue: .main) { [weak self] _ in
            Task { @MainActor [weak self] in await self?.setAppForeground(false) }
        })
    }

    func stopPlatformSignalBridge() {
        pathMonitor?.cancel()
        pathMonitor = nil
        appStateObservers.forEach(NotificationCenter.default.removeObserver)
        appStateObservers.removeAll()
    }

    private func notifyNetworkChange(available: Bool, kind: NetworkInterfaceKind, expensive: Bool) async {
        guard let client else { return }
        let response = try? await client.connection.notifyNetworkChange(NetworkChangeRequest(
            available: available,
            interface: kind,
            expensive: expensive,
            metered: nil,
            reason: "nw_path_monitor"
        ))
        appendEvent("connection", name: "network_change", detail: "\(kind.rawValue) available=\(available) reconnected=\(response?.reconnected ?? false)")
    }

    private func setAppForeground(_ foreground: Bool) async {
        guard let client else { return }
        _ = try? await client.setHeartbeatAppState(SetHeartbeatAppStateRequest(
            appState: foreground ? .foreground : .background
        ))
    }

    func logout() async throws {
        guard let client else { throw AppStoreError(message: "SDK client is not initialized") }
        stopPlatformSignalBridge()
        try await client.logout()
        isLoggedIn = false
        currentUserId = nil
        nativeEventSubscription = nil
        lastLoginDraft = nil
        lastDataURL = nil
        connectionState = try await client.connection.getConnectionState()
    }

    func dispose() async throws {
        stopPlatformSignalBridge()
        eventSubscriptions.forEach { $0.unsubscribe() }
        eventSubscriptions.removeAll()
        try await client?.dispose()
        client = nil
        isLoggedIn = false
        currentUserId = nil
        nativeEventSubscription = nil
        lastLoginDraft = nil
        lastDataURL = nil
        connectionState = .disconnected
    }

    func refreshConnectionState() async throws {
        guard let client else { return }
        connectionState = try await client.connection.getConnectionState()
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

    /// init 里除传输配置外的部分：数据目录、租户、网关 HTTP 基址，以及 SDK 托管 token 的签发地址。
    /// 客户端不再本地签发（那等于把签名密钥打进 App）。
    nonisolated static func sessionInitConfig(draft: LoginDraft, dataURL: URL) -> [String: AnySendable] {
        let httpUrl = draft.httpUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        return [
            "dataUrl": AnySendable(dataURL.absoluteString),
            "tenantId": AnySendable(draft.tenantId),
            "httpUrl": AnySendable(httpUrl),
            "auth": AnySendable(["tokenEndpoint": httpUrl] as [String: Any]),
            "platform": AnySendable("apple"),
            "runtime": AnySendable("swiftui-example")
        ]
    }

    private func installEventSubscriptions(_ client: any FlareImClientProtocol) {
        eventSubscriptions.forEach { $0.unsubscribe() }
        eventSubscriptions = [
            client.events.onInitialized { [weak self] event in
                Task { @MainActor in self?.appendEvent("lifecycle", name: event.name.rawValue, detail: event.operation) }
            },
            client.events.onLoginSucceeded { [weak self] event in
                Task { @MainActor in self?.appendEvent("lifecycle", name: event.name.rawValue, detail: event.userId ?? "") }
            },
            client.events.onLoggedOut { [weak self] event in
                Task { @MainActor in self?.appendEvent("lifecycle", name: event.name.rawValue, detail: event.operation) }
            },
            client.events.onConnectReady { [weak self] event in
                Task { @MainActor in self?.appendEvent("connection", name: event.name.rawValue, detail: event.reason ?? "") }
            },
            client.events.onDisconnected { [weak self] event in
                Task { @MainActor in self?.appendEvent("connection", name: event.name.rawValue, detail: event.reason ?? "") }
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
            client.events.onCapabilityChanged { [weak self] event in
                Task { @MainActor in self?.appendEvent("capability", name: event.name.rawValue, detail: event.capability ?? "") }
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
