import Combine
import FlareCoreAppleSDK
import Foundation

/// SDK Lab 特性 ViewModel:诊断 / builder 目录 + 三个子 Lab(通用操作、媒体中心、能力中心)的探针分发。
///
/// 持有 [MessagingViewModel] 依赖:部分 Lab 探针复用消息特性的 `refreshConversations` / `selectedMessages`
/// / `messageMutationRequest`(workbench 应用里 Lab 天然驱动其它特性,这是有意的跨特性协作)。
/// 「转发」段让迁移自 god-store 的方法体零改动。
@MainActor
final class SdkLabViewModel: ObservableObject {
    @Published var mediaLabDraft = MediaLabDraft()
    @Published var capabilityLabDraft = CapabilityLabDraft()
    @Published private(set) var diagnostics: [String: String] = [:]
    @Published private(set) var capabilities: [String: AnySendable] = [:]
    @Published private(set) var userCapabilities: [String: AnySendable] = [:]
    @Published private(set) var presence: [String: Bool] = [:]
    @Published private(set) var builderCatalog: [MessageBuildCatalogEntry] = []

    private let session: AppSession
    private let repository: ViewDataRepository
    private let environment: AppEnvironment
    private let messaging: MessagingViewModel
    private weak var lifecycle: AppLifecycle?
    private var cancellables = Set<AnyCancellable>()

    init(session: AppSession, repository: ViewDataRepository, environment: AppEnvironment, messaging: MessagingViewModel) {
        self.session = session
        self.repository = repository
        self.environment = environment
        self.messaging = messaging
        for publisher in [session.objectWillChange, environment.objectWillChange] {
            publisher.sink { [weak self] in self?.objectWillChange.send() }.store(in: &cancellables)
        }
    }

    /// 由组合根在装配后回填，用于把登出/释放委派给协调器。
    func bind(lifecycle: AppLifecycle) { self.lifecycle = lifecycle }
    func logout() async { await lifecycle?.logout() }
    func dispose() async { await lifecycle?.dispose() }

    // MARK: - 视图只读态(供 SDK Lab / Settings 视图替代直读 store)
    var eventLog: [EventLogEntry] { session.eventLog }
    var labResults: [LabResult] { environment.labResults }
    var runtimeStatus: RuntimeStatus { environment.runtimeStatus }

    var coverageRows: [CoverageRow] {
        [
            CoverageRow(family: "Lifecycle", api: "create, init, login, logout (token issued by the gateway)", status: "Real", entryPoint: "Login and Settings"),
            CoverageRow(family: "Lifecycle", api: "updateAccessToken, disconnect, uninit, hardReset, dispose", status: "Lab", entryPoint: "SDK Lab Lifecycle"),
            CoverageRow(family: "Connection", api: "isConnected, sessionActive, connection.getConnectionState", status: "Lab", entryPoint: "Diagnostics"),
            CoverageRow(family: "Conversations", api: "list, query, archived, paginated, raw, bootstrap, open timeline", status: "Real/Lab", entryPoint: "Conversation list and Lab"),
            CoverageRow(family: "Conversations", api: "mark read/unread, pin, mute, archive, draft, clear, delete", status: "Real", entryPoint: "Conversation actions and Details"),
            CoverageRow(family: "Messages", api: "messageBuilder.buildText, sendMessage, listMessages, setTyping", status: "Real", entryPoint: "Chat composer and timeline"),
            CoverageRow(family: "Messages", api: "recall, edit, delete, reactions, pin, mark, raw fetch", status: "Real/Lab", entryPoint: "Message menu and Lab"),
            CoverageRow(family: "Message Builder", api: "listSupportedBuildOperations and all typed build operations", status: "Lab", entryPoint: "Builder catalog and quick probes"),
            CoverageRow(family: "Search", api: "searchMessages, searchMessagesByQuery, searchMessagesInConversation", status: "Real", entryPoint: "Search screen"),
            CoverageRow(family: "Media", api: "upload, delete, URL, cache, downloads", status: "Lab", entryPoint: "Media Center"),
            CoverageRow(family: "Capabilities/Calls", api: "list, dispatch, grant, revoke, sendCallSignal", status: "Lab/Unavailable", entryPoint: "Capability Center"),
            CoverageRow(family: "Events", api: "subscribeEvents, typed listeners, unsubscribe, unsubscribeAll", status: "Real/Lab", entryPoint: "Event console"),
            CoverageRow(family: "Diagnostics", api: "getSdkVersion, getFfiContractVersion, getDataRoot", status: "Lab", entryPoint: "Diagnostics")
        ]
    }

    // MARK: - 转发(让迁移来的方法体零改动)
    private var client: (any FlareImClientProtocol)? { session.client }
    private var currentUserId: String? { session.currentUserId }
    private var connectionState: ConnectionState { session.connectionState }
    private var selectedConversationId: String? { environment.selectedConversationId }
    private var selectedMessages: [AppMessage] { messaging.selectedMessages }
    private func messageMutationRequest(_ message: AppMessage) -> [String: AnySendable] { messaging.messageMutationRequest(message) }
    private func refreshConversations() async { await messaging.refreshConversations() }
    private func perform(_ operation: String, showBusy: Bool = true, body: () async throws -> Void) async {
        await environment.run(operation, showBusy: showBusy, body: body)
    }
    private func appendLab(_ operation: String, status: String, detail: String) {
        environment.appendLab(operation, status: status, detail: detail)
    }
    private func unavailable(_ message: String) -> AppStoreError { AppStoreError(message: message) }
    private func dataURL() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let folder = environment.loginDraft.dataSubfolder.trimmingCharacters(in: .whitespacesAndNewlines)
        let url = base.appendingPathComponent(folder.isEmpty ? "flare-core-ios-app" : folder, isDirectory: true)
        try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    // MARK: - 操作(迁移自 god-store)
    func refreshDiagnostics() async {
        await perform("diagnostics.refresh", showBusy: false) {
            guard let client else { throw unavailable("Login before diagnostics") }
            let version = try await client.diagnostics.getSdkVersion()
            let contract = try await client.diagnostics.getFfiContractVersion()
            let root = try await client.diagnostics.getDataRoot()
            let current = try await client.currentUserId()
            let active = try await client.sessionActive()
            let connected = try await client.isConnected()
            try await session.refreshConnectionState()
            diagnostics = [
                "sdkVersion": stringField(version, "version"),
                "ffiContract": stringField(contract, "version"),
                "dataRoot": FlareFormatters.jsonPreview(root),
                "currentUser": FlareFormatters.jsonPreview(current),
                "sessionActive": String(active),
                "isConnected": String(connected),
                "connectionState": connectionState.rawValue
            ]
        }
    }

    func refreshBuilderCatalog() async {
        await perform("message_builder.catalog", showBusy: false) {
            guard let client else { throw unavailable("Login before builder catalog") }
            let response = try await client.messageBuilder.listSupportedBuildOperations()
            builderCatalog = response.entries.sorted { $0.op.rawValue < $1.op.rawValue }
            appendLab("message_builder.catalog", status: "ok", detail: "\(response.entries.count) operations")
        }
    }

    func runLabOperation(_ operation: String) async {
        await perform(operation) {
            guard let client else { throw unavailable("Login before SDK Lab operations") }
            switch operation {
            case "session.update_access_token":
                // 客户端不再签发：只把登录页粘贴的 token 应用到核心（应用托管形态）。
                guard let token = AppSession.explicitToken(draft: environment.loginDraft) else {
                    throw unavailable("SDK-managed tokens are refreshed by the core; paste a backend-issued access token first")
                }
                try await client.updateAccessToken(["token": AnySendable(token)])
            case "connection.disconnect":
                try await client.connection.disconnect()
                try await session.refreshConnectionState()
            case "session.uninit":
                try await client.uninit()
            case "session.hard_reset":
                try await client.hardReset()
                environment.setRuntimeStatus(.idle)
            case "conversation.list_paginated":
                let response = try await client.conversations.listConversationsPaginated([
                    "offset": AnySendable(0),
                    "limit": AnySendable(30),
                    "includeArchived": AnySendable(true)
                ])
                appendLab(operation, status: "ok", detail: "\(response.conversations.count) conversations")
            case "conversation.list_raw":
                let response = try await client.conversations.listRawConversations()
                appendLab(operation, status: "ok", detail: "\(response.conversations.count) raw conversations")
            case "sync.summaries":
                try await client.sync.syncConversationSummaries()
                await refreshConversations()
            case "user.upsert_profiles":
                let uid = currentUserId ?? "self"
                try await client.user.upsertUserProfiles([
                    "profiles": AnySendable([
                        ["userId": uid, "nickname": "SDK Lab nickname", "avatarUrl": ""]
                    ])
                ])
                appendLab(operation, status: "ok", detail: "upserted \(uid)")
            case "message.get_raw":
                guard let message = selectedMessages.last else { throw unavailable("Select a conversation with messages first") }
                let raw = try await client.messages.getRawMessage(messageMutationRequest(message))
                appendLab(operation, status: "ok", detail: FlareFormatters.jsonPreview(raw))
            case "message.send_no_oss":
                guard let message = selectedMessages.last else { throw unavailable("Send or select a message first") }
                let ack = try await client.messages.sendMessageNoOss(SendMessageRequest(message: message.core))
                appendLab(operation, status: "ok", detail: "seq \(ack.seq)")
            case "message.mark_read_burn":
                guard let message = selectedMessages.last else { throw unavailable("Select a message first") }
                try await client.messages.markMessageReadAndBurn(messageMutationRequest(message))
            case "presence.current":
                let uid = currentUserId ?? environment.loginDraft.userId
                let raw = try await client.presence.getUserPresence(["userId": AnySendable(uid)])
                presence[uid] = boolField(raw, "isOnline") ?? boolField(raw, "is_online") ?? false
                appendLab(operation, status: "ok", detail: FlareFormatters.jsonPreview(raw))
            case "presence.batch_subscribe":
                let ids = [currentUserId ?? environment.loginDraft.userId].filter { !$0.isEmpty }
                let raw = try await client.presence.batchGetUserPresence(["userIds": AnySendable(ids)])
                try await client.presence.subscribeUserPresence(["userIds": AnySendable(ids)])
                appendLab(operation, status: "ok", detail: FlareFormatters.jsonPreview(raw))
            case "events.subscribe":
                let raw = try await client.events.subscribeEvents(["sources": AnySendable(["lifecycle", "connection", "conversation", "message", "sync", "presence", "capability", "progress"])])
                appendLab(operation, status: "ok", detail: FlareFormatters.jsonPreview(raw))
            case "events.unsubscribe_all":
                try await client.events.unsubscribeAll()
                session.reinstallEventSubscriptions()
            // --- 补齐:iOS 矩阵真缺项(对照 examples/CAPABILITY-PARITY.md)---
            case "diagnostics.runtime_health":
                let health = try await client.diagnostics.getRuntimeHealth()
                appendLab(operation, status: "ok", detail: "state=\(health.state), metrics=\(health.metricsEnabled)")
            case "session.heartbeat_interval":
                let interval = try await client.heartbeatEffectiveInterval()
                appendLab(operation, status: "ok", detail: "\(interval)")
            case "session.heartbeat_app_state":
                try await client.setHeartbeatAppState(SetHeartbeatAppStateRequest(appState: .foreground))
                appendLab(operation, status: "ok", detail: "appState=foreground")
            case "session.heartbeat_nat_timeout":
                try await client.setHeartbeatNatTimeout(SetHeartbeatNatTimeoutRequest(natTimeoutSecs: 120))
                appendLab(operation, status: "ok", detail: "natTimeout=120s")
            case "session.prepare":
                try await client.prepare(["userId": AnySendable(environment.loginDraft.userId)])
                appendLab(operation, status: "ok", detail: "prepared \(environment.loginDraft.userId)")
            case "conversation.bootstrap_home_timeline":
                _ = try await client.conversations.bootstrapHomeTimeline(BootstrapHomeTimelineRequest(conversationLimit: 30))
                appendLab(operation, status: "ok", detail: "home timeline bootstrapped")
            case "message.mark_color":
                guard let message = selectedMessages.last else { throw unavailable("Select a message first") }
                try await client.messages.markMessageWithColor(messageMutationRequest(message).merging(["color": AnySendable("blue")]) { $1 })
                appendLab(operation, status: "ok", detail: "marked blue")
            case "message_builder.normalize_markdown":
                _ = try await client.messageBuilder.normalizeRichDocFromMarkdown(NormalizeRichDocFromMarkdownRequest(markdown: "# Title\n\n**bold** _italic_"))
                appendLab(operation, status: "ok", detail: "normalized markdown")
            case "message_builder.normalize_html":
                _ = try await client.messageBuilder.normalizeRichDocFromHtml(NormalizeRichDocFromHtmlRequest(html: "<h1>Title</h1><p><b>bold</b></p>"))
                appendLab(operation, status: "ok", detail: "normalized html")
            case "message_builder.normalize_docjson":
                _ = try await client.messageBuilder.normalizeRichDocFromDocJson(NormalizeRichDocFromDocJsonRequest(docJson: "{\"version\":2,\"blocks\":[]}"))
                appendLab(operation, status: "ok", detail: "normalized docjson")
            case "connection.notify_network_change":
                _ = try await client.connection.notifyNetworkChange(NetworkChangeRequest(available: true, expensive: false, metered: false, reason: "iOS lab probe"))
                appendLab(operation, status: "ok", detail: "network change notified (available=true)")
            default:
                throw unavailable("Operation \(operation) is not wired")
            }
        }
    }

    func runMediaLab(_ operation: String) async {
        await perform(operation) {
            guard let client else { throw unavailable("Login before media operations") }
            switch operation {
            case "media.cache_stats":
                let raw = try await client.media.getMediaCacheStats()
                appendLab(operation, status: "ok", detail: FlareFormatters.jsonPreview(raw))
            case "media.configure_cache":
                if let bytes = UInt64(mediaLabDraft.cacheMaxBytes) {
                    try await client.media.setMediaCacheMaxBytes(["maxBytes": AnySendable(bytes)])
                }
                let root = dataURL().appendingPathComponent("media-cache").path
                try await client.media.setMediaCacheRoot(["root": AnySendable(root)])
            case "media.clear_cache":
                try await client.media.clearMediaCache()
            case "media.get_subfolder":
                let raw = try await client.media.getUserDownloadSubfolder()
                appendLab(operation, status: "ok", detail: FlareFormatters.jsonPreview(raw))
            case "media.set_subfolder":
                try await client.media.setUserDownloadSubfolder(["subfolder": AnySendable(mediaLabDraft.downloadSubfolder)])
            case "media.resolve":
                let request = try mediaAccessRequest()
                let raw = try await client.media.resolveMediaAccess(request)
                appendLab(operation, status: "ok", detail: FlareFormatters.jsonPreview(raw))
            case "media.url":
                let raw = try await client.media.getMediaUrl(try mediaAccessRequest())
                appendLab(operation, status: "ok", detail: FlareFormatters.jsonPreview(raw))
            case "media.temp_url":
                var request = try mediaAccessRequest()
                request["expiresInSeconds"] = AnySendable(600)
                let raw = try await client.media.getTempDownloadUrl(request)
                appendLab(operation, status: "ok", detail: FlareFormatters.jsonPreview(raw))
            case "media.cache_remote":
                let raw = try await client.media.cacheRemoteMedia(try mediaAccessRequest())
                appendLab(operation, status: "ok", detail: FlareFormatters.jsonPreview(raw))
            case "media.saved_path":
                let raw = try await client.media.getUserDownloadSavedPath([
                    "fileId": AnySendable(requiredMediaFileId()),
                    "subfolder": AnySendable(mediaLabDraft.downloadSubfolder)
                ])
                appendLab(operation, status: "ok", detail: FlareFormatters.jsonPreview(raw))
            case "media.delete_record":
                try await client.media.deleteUserDownloadRecord([
                    "fileId": AnySendable(requiredMediaFileId()),
                    "subfolder": AnySendable(mediaLabDraft.downloadSubfolder)
                ])
            case "media.cancel_download":
                let ok = try await client.media.cancelUserFileDownload(["fileId": AnySendable(requiredMediaFileId())])
                appendLab(operation, status: "ok", detail: String(ok))
            case "media.download":
                let raw = try await client.media.downloadFileToDownloads(try mediaAccessRequest())
                appendLab(operation, status: "ok", detail: FlareFormatters.jsonPreview(raw))
            case "media.upload_file":
                let path = mediaLabDraft.filePath.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !path.isEmpty else { throw unavailable("Provide a local file path for upload probes") }
                let raw = try await client.media.uploadFile(["path": AnySendable(path)])
                appendLab(operation, status: "ok", detail: FlareFormatters.jsonPreview(raw))
            // 补齐:iOS 矩阵真缺(对照 CAPABILITY-PARITY.md)。上传需本地文件路径(File path 输入框)。
            case "media.upload_image":
                let path = mediaLabDraft.filePath.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !path.isEmpty else { throw unavailable("Provide a local file path for upload probes") }
                let raw = try await client.media.uploadImage(["path": AnySendable(path)])
                appendLab(operation, status: "ok", detail: FlareFormatters.jsonPreview(raw))
            case "media.upload_video":
                let path = mediaLabDraft.filePath.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !path.isEmpty else { throw unavailable("Provide a local file path for upload probes") }
                let raw = try await client.media.uploadVideo(["path": AnySendable(path)])
                appendLab(operation, status: "ok", detail: FlareFormatters.jsonPreview(raw))
            case "media.delete_file":
                let raw = try await client.media.deleteFile(["fileId": AnySendable(requiredMediaFileId())])
                appendLab(operation, status: "ok", detail: FlareFormatters.jsonPreview(raw))
            default:
                throw unavailable("Unsupported media operation")
            }
        }
    }

    func runCapabilityLab(_ operation: String) async {
        await perform(operation) {
            guard let client else { throw unavailable("Login before capability operations") }
            switch operation {
            case "capability.list":
                capabilities = try await client.capabilities.listCapabilities([:])
                appendLab(operation, status: "ok", detail: FlareFormatters.jsonPreview(capabilities))
            case "capability.list_user":
                let uid = capabilityLabDraft.userId.isEmpty ? (currentUserId ?? environment.loginDraft.userId) : capabilityLabDraft.userId
                userCapabilities = try await client.capabilities.listUserCapabilities(["userId": AnySendable(uid)])
                appendLab(operation, status: "ok", detail: FlareFormatters.jsonPreview(userCapabilities))
            case "capability.dispatch":
                let raw = try await client.capabilities.dispatchCapability([
                    "capability": AnySendable(capabilityLabDraft.capability),
                    "operation": AnySendable(capabilityLabDraft.operation),
                    "payload": AnySendable(FlareFormatters.unwrap(sendableJSON(capabilityLabDraft.payload)))
                ])
                appendLab(operation, status: "ok", detail: FlareFormatters.jsonPreview(raw))
            case "capability.grant":
                let uid = capabilityLabDraft.userId.isEmpty ? (currentUserId ?? environment.loginDraft.userId) : capabilityLabDraft.userId
                try await client.capabilities.grantCapability([
                    "userId": AnySendable(uid),
                    "capability": AnySendable(capabilityLabDraft.capability),
                    "payload": AnySendable([String: Any]())
                ])
            case "capability.revoke":
                let uid = capabilityLabDraft.userId.isEmpty ? (currentUserId ?? environment.loginDraft.userId) : capabilityLabDraft.userId
                try await client.capabilities.revokeCapability([
                    "userId": AnySendable(uid),
                    "capability": AnySendable(capabilityLabDraft.capability)
                ])
            case "capability.call_signal":
                guard let selectedConversationId else { throw unavailable("Select a conversation before sending call signal") }
                if capabilities.isEmpty {
                    capabilities = try await client.capabilities.listCapabilities([:])
                }
                let available = FlareFormatters.jsonPreview(capabilities).localizedCaseInsensitiveContains("call")
                    || FlareFormatters.jsonPreview(capabilities).localizedCaseInsensitiveContains("rtc")
                guard available else {
                    throw unavailable("Call capability is not advertised by the runtime")
                }
                try await client.capabilities.sendCallSignal([
                    "conversationId": AnySendable(selectedConversationId),
                    "signalType": AnySendable(capabilityLabDraft.callSignalType),
                    "payload": AnySendable(FlareFormatters.unwrap(sendableJSON(capabilityLabDraft.payload)))
                ])
            default:
                throw unavailable("Unsupported capability operation")
            }
        }
    }
    private func mediaAccessRequest() throws -> [String: AnySendable] {
        [
            "fileId": AnySendable(try requiredMediaFileId()),
            "conversationId": AnySendable(selectedConversationId ?? ""),
            "expiresInSeconds": AnySendable(600)
        ]
    }

    private func requiredMediaFileId() throws -> String {
        let fileId = mediaLabDraft.fileId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !fileId.isEmpty else { throw unavailable("Provide a file id for this media operation") }
        return fileId
    }
}
