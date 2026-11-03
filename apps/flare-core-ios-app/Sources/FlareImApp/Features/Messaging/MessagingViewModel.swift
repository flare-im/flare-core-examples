import Combine
import FlareCoreAppleSDK
import FlareIMUI
import Foundation

private let messagePinScopeConversation = 0
private let messagePinScopeSelf = 1
/// 标记类型「重要」（核心 MarkType::Important）。
private let messageMarkTypeImportant = 1
/// 标记默认色；核心要求 color 非空，不关心颜色时用它。
private let messageMarkDefaultColor = "#F5A623"

/// 消息特性 ViewModel:会话列表 + 时间线 + 全部消息/会话操作。
///
/// 设计判断:会话列表与聊天经**选择态 + 消息生命周期**强互连(`openConversation` / `refreshConversations`
/// 被双方多处调用),严格拆成两个 VM 会产生约 8 处跨 VM 调用,反而更乱。故合为一个内聚的「消息」特性。
/// 依赖共享的 [AppSession] / [ViewDataRepository] / [AppEnvironment];下方「转发」段让迁移自 god-store
/// 的方法体几乎零改动。
@MainActor
final class MessagingViewModel: ObservableObject {
    @Published var startConversationDraft = StartConversationDraft()
    @Published private(set) var pendingMessageKeys: Set<String> = []
    @Published private(set) var failedMessageKeys: Set<String> = []
    @Published var replyTarget: AppMessage?
    @Published var previewTarget: AppMessage?
    @Published private(set) var selectedActionMessageIds: Set<String> = []

    private let session: AppSession
    private let repository: ViewDataRepository
    private let environment: AppEnvironment
    private weak var lifecycle: AppLifecycle?
    private var cancellables = Set<AnyCancellable>()

    init(session: AppSession, repository: ViewDataRepository, environment: AppEnvironment) {
        self.session = session
        self.repository = repository
        self.environment = environment
        for publisher in [session.objectWillChange, repository.objectWillChange, environment.objectWillChange] {
            publisher.sink { [weak self] in self?.objectWillChange.send() }.store(in: &cancellables)
        }
    }

    /// 由组合根在装配后回填，用于把登出动作委派给协调器。
    func bind(lifecycle: AppLifecycle) { self.lifecycle = lifecycle }
    func logout() async { await lifecycle?.logout() }

    // MARK: - 视图只读态(供 Messaging 视图替代直读 store)
    var allConversations: [AppConversation] { repository.conversations }
    var currentUserId: String? { session.currentUserId }
    var runtimeStatus: RuntimeStatus { environment.runtimeStatus }
    var lastError: String? { environment.lastError }

    // MARK: - 转发(让迁移来的方法体零改动)
    private var client: (any FlareImClientProtocol)? { session.client }
    private var selectedConversationId: String? {
        get { environment.selectedConversationId }
        set { environment.selectedConversationId = newValue }
    }
    private var conversations: [AppConversation] { repository.conversations }
    private var messagesByConversation: [String: [AppMessage]] { repository.messagesByConversation }
    var visibleConversations: [AppConversation] { conversations.filter(matchesCurrentFilter) }
    var selectedConversation: AppConversation? {
        guard let id = selectedConversationId else { return nil }
        return conversations.first { $0.conversationId == id }
    }
    var selectedMessages: [AppMessage] { repository.messages(in: selectedConversationId) }
    var selectedConversationHasMoreMessages: Bool { repository.hasMoreMessages(in: selectedConversationId) }
    var isMessageMultiSelectMode: Bool { !selectedActionMessageIds.isEmpty }
    private func perform(_ operation: String, showBusy: Bool = true, body: () async throws -> Void) async {
        await environment.run(operation, showBusy: showBusy, body: body)
    }
    private func appendLab(_ operation: String, status: String, detail: String) {
        environment.appendLab(operation, status: status, detail: detail)
    }
    private func unavailable(_ message: String) -> AppStoreError { AppStoreError(message: message) }

    private func requireConnectedClient(
        _ message: String,
        showProgress: Bool = true
    ) async throws -> any FlareImClientProtocol {
        guard session.client != nil || session.isLoggedIn else { throw unavailable(message) }
        return try await session.ensureConnected { stage in
            if showProgress {
                environment.setRuntimeStatus(.loading(stage))
            }
        }
    }

    private func retryingDatabaseLock<T>(
        operation: String,
        attempts: Int = 3,
        body: () async throws -> T
    ) async throws -> T {
        let delaysMs = [150, 350, 700]
        var lastError: Error?
        for attempt in 0..<max(attempts, 1) {
            do {
                return try await body()
            } catch {
                lastError = error
                guard attempt < attempts - 1, isDatabaseLocked(error) else { throw error }
                appendLab(operation, status: "retry", detail: "database is locked, retry \(attempt + 2)/\(attempts)")
                let delay = delaysMs[min(attempt, delaysMs.count - 1)]
                try await Task.sleep(nanoseconds: UInt64(delay) * 1_000_000)
            }
        }
        throw lastError ?? unavailable("Operation failed without an SDK error")
    }

    private func isDatabaseLocked(_ error: Error) -> Bool {
        let text = FlareFormatters.errorText(error).lowercased()
        return text.contains("database is locked") || text.contains("code: 5")
    }

    private func sendMessageWithRetry(
        client: any FlareImClientProtocol,
        message: Message
    ) async throws -> SendMessageResponse {
        try await retryingDatabaseLock(operation: "message.send") {
            try await client.messages.sendMessage(SendMessageRequest(message: message), callback: nil)
        }
    }

    private func refreshTimelineAfterSend(client: any FlareImClientProtocol, conversationId: String) async {
        do {
            selectedConversationId = conversationId
            try await retryingDatabaseLock(operation: "view.timeline.refresh_after_send") {
                try await repository.openTimeline(client: client, conversationId: conversationId, reason: "send")
            }
            let messages = messagesByConversation[conversationId, default: []]
            await markConversationReadBestEffort(
                client: client,
                conversationId: conversationId,
                messages: messages,
                operation: "conversation.mark_read_after_send"
            )
        } catch {
            appendLab("view.timeline.refresh_after_send", status: "warn", detail: FlareFormatters.errorText(error))
        }
    }

    /// 由 [AppSession] 的 send-failed 事件路由进来(协调器在 init 里接线)。
    func markSendFailed(_ key: String) { failedMessageKeys.insert(key) }

    // MARK: - 操作(迁移自 god-store)
    func refreshConversations() async {
        await perform("view.conversation_list.open") {
            try await syncConversationList(reason: "refresh")
        }
    }

    func bootstrapHome() async {
        await perform("view.conversation_list.open") {
            try await syncConversationList(reason: "bootstrap")
            if let selectedConversationId {
                await openConversation(selectedConversationId)
            }
        }
    }

    /// 打开会话列表视图(经 repository)+ 初始化选择态(选中项缺省取第一条;复刻原 open 行为)。
    private func syncConversationList(reason: String) async throws {
        let client = try await requireConnectedClient("Login before loading conversations")
        try await repository.openConversationList(client: client, reason: reason)
        selectedConversationId = selectedConversationId ?? repository.conversations.first?.conversationId
    }

    func openConversation(_ conversationId: String, showBusy: Bool = true) async {
        await perform("view.timeline.open", showBusy: showBusy) {
            let client = try await requireConnectedClient(
                "Login before opening a conversation",
                showProgress: showBusy
            )
            selectedConversationId = conversationId
            environment.section = .conversations
            do {
                try await repository.openTimeline(client: client, conversationId: conversationId, reason: "open")
            } catch {
                appendLab("view.timeline.open", status: "warn", detail: FlareFormatters.errorText(error))
                if messagesByConversation[conversationId, default: []].isEmpty {
                    throw error
                }
            }
            let messages = messagesByConversation[conversationId, default: []]
            await markConversationReadBestEffort(
                client: client,
                conversationId: conversationId,
                messages: messages,
                operation: "conversation.mark_read_on_open"
            )
        }
    }

    func loadOlderMessages() async {
        guard let selectedConversationId else { return }
        await perform("view.timeline.load_older") {
            let client = try await requireConnectedClient("Login before loading messages")
            try await repository.loadOlderTimeline(client: client, conversationId: selectedConversationId)
        }
    }

    @discardableResult
    func sendText(_ text: String) async -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let selectedConversationId, !trimmed.isEmpty else { return false }
        var didSend = false
        await perform("message.send_text") {
            let client = try await requireConnectedClient("Login before sending messages")
            try await client.messages.setTyping([
                "conversationId": AnySendable(selectedConversationId),
                "typing": AnySendable(false)
            ])
            let message = try await client.messageBuilder.buildText(BuildTextMessageRequest(
                conversationId: selectedConversationId,
                text: trimmed
            ))
            let messageKey = SdkModelMapper.messageFromCore(message).appStableId
            pendingMessageKeys.insert(messageKey)
            do {
                let ack = try await sendMessageWithRetry(client: client, message: message)
                pendingMessageKeys.remove(messageKey)
                appendLab("message.send", status: "ok", detail: "seq \(ack.seq), server \(ack.serverId)")
                await refreshTimelineAfterSend(client: client, conversationId: selectedConversationId)
                didSend = true
            } catch {
                pendingMessageKeys.remove(messageKey)
                failedMessageKeys.insert(messageKey)
                throw error
            }
        }
        return didSend
    }

    @discardableResult
    func buildAndSend(op: MessageBuildOp, payload: [String: Any] = [:]) async -> Bool {
        guard let selectedConversationId else { return false }
        var didSend = false
        await perform("message_builder.\(op.rawValue)") {
            let client = try await requireConnectedClient("Login before building messages")
            let message = try await MessageBuilder.build(
                client: client,
                conversationId: selectedConversationId,
                op: op,
                payload: payload,
                selectedMessages: selectedMessages
            )
            let messageKey = SdkModelMapper.messageFromCore(message).appStableId
            pendingMessageKeys.insert(messageKey)
            do {
                let ack = try await sendMessageWithRetry(client: client, message: message)
                pendingMessageKeys.remove(messageKey)
                appendLab("message.send", status: "ok", detail: "seq \(ack.seq), server \(ack.serverId)")
                await refreshTimelineAfterSend(client: client, conversationId: selectedConversationId)
                didSend = true
            } catch {
                pendingMessageKeys.remove(messageKey)
                failedMessageKeys.insert(messageKey)
                throw error
            }
        }
        return didSend
    }

    @discardableResult
    func sendReplyText(_ text: String, replyingTo message: AppMessage) async -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        let sent = await buildAndSend(
            op: .createQuote,
            payload: [
                "quotedMessageId": message.serverId.isEmpty ? message.clientMsgId : message.serverId,
                "quotedSenderId": message.senderId,
                "quotedTextPreview": message.previewText,
                "text": trimmed
            ]
        )
        if sent {
            clearReplyTarget()
        }
        return sent
    }

    @discardableResult
    func forwardMessage(_ message: AppMessage) async -> Bool {
        await buildAndSend(
            op: .createForward,
            payload: [
                "sourceMessageId": message.serverId.isEmpty ? message.clientMsgId : message.serverId,
                "sourceConversationId": message.conversationId,
                "sourceSenderId": message.senderId,
                "plainText": message.previewText
            ]
        )
    }

    /// 保存图片、视频、文件：由核心 SDK 存进「下载位置」（`media.download_to_user_directory`；看过的图片直接从
    /// 本地缓存拷出，不再走网络）。结果给界面说出来 —— 以前失败只进 SDK Lab 日志，用户点了保存什么都看不到。
    func saveToDevice(_ message: AppMessage, now: Date = Date()) async -> MediaSaveOutcome {
        guard let target = MediaSaveTarget.of(message.content, now: now) else {
            appendLab("media.download_to_user_directory", status: "warn", detail: "nothing to save in \(message.appStableId)")
            return .failed(MediaSaveCopy.nothingToSave)
        }
        guard let client else { return .failed(MediaSaveCopy.failed) }
        do {
            let saved = try await client.media.downloadToUserDirectory(target.request)
            appendLab("media.download_to_user_directory", status: "ok", detail: FlareFormatters.jsonPreview(saved))
            return MediaSaveOutcome.from(saved)
        } catch {
            appendLab("media.download_to_user_directory", status: "warn", detail: FlareFormatters.errorText(error))
            return MediaSaveOutcome.failure(error)
        }
    }

    /// 看过的图片的本地副本（SDK 媒体缓存），按文件 id 记住；没有时拿短时 URL，核心在后台把它拉进缓存
    /// （`media.resolve_access` + `autoCache`），之后再问就是本地路径 —— 看过的图不再重复下载。
    private var pictureCopies = LocalPictureCopies()
    private var pictureURLs: [String: (url: String, at: Date)] = [:]
    private static let pictureURLReuse: TimeInterval = 20

    func resolvePicture(fileId: String?) async -> PictureAccess? {
        guard let mediaId = fileId?.trimmingCharacters(in: .whitespacesAndNewlines), !mediaId.isEmpty else { return nil }
        if let local = pictureCopies.path(mediaId) { return PictureAccess(localPath: local, url: nil) }
        let now = Date()
        let recent = pictureURLs[mediaId].flatMap { now.timeIntervalSince($0.at) < Self.pictureURLReuse ? $0.url : nil }
        guard pictureCopies.shouldAsk(mediaId, now: now) || recent == nil, let client else {
            return recent.map { PictureAccess(localPath: nil, url: $0) }
        }
        do {
            let access = PictureAccess(try await client.media.resolveMediaAccess([
                "fileId": AnySendable(mediaId),
                "expiresIn": AnySendable(3600),
                "autoCache": AnySendable(true)
            ]))
            pictureCopies.record(mediaId, localPath: access.localPath, now: now)
            if access.localPath == nil, let url = access.url { pictureURLs[mediaId] = (url, now) }
            return access
        } catch {
            appendLab("media.resolve_access", status: "warn", detail: "\(mediaId): \(FlareFormatters.errorText(error))")
            return recent.map { PictureAccess(localPath: nil, url: $0) }
        }
    }

    /// 缓存清掉后，记住的本地副本全部作废，下次重新问核心。
    func forgetPictureCopies() {
        pictureCopies.reset()
        pictureURLs = [:]
    }

    func startReply(to message: AppMessage) {
        replyTarget = message
        appendLab("message.reply", status: "ok", detail: "Reply target \(message.appStableId)")
    }

    func clearReplyTarget() {
        replyTarget = nil
    }

    func startMultiSelect(with message: AppMessage) {
        selectedActionMessageIds = [message.appStableId]
        appendLab("message.multi_select", status: "ok", detail: "Selected \(message.appStableId)")
    }

    func cancelMessageMultiSelect() {
        selectedActionMessageIds.removeAll()
    }

    func openMessagePreview(_ message: AppMessage) {
        previewTarget = message
        appendLab("message.preview", status: "ok", detail: "Preview \(message.appStableId)")
    }

    func uploadImageAttachmentPayload(_ payload: [String: Any]) async throws -> [String: Any] {
        let client = try await requireConnectedClient("Login before uploading images")
        let localPath = try mediaLocalPath(from: payload, fallbackOperation: "media.upload_image")
        let uploaded = try await client.media.uploadImage([
            "absolutePath": AnySendable(localPath)
        ])
        let mapped = ComposerMediaUploadPayload.imagePayload(localPayload: payload, uploaded: uploaded)
        appendLab(
            "media.upload_image",
            status: "ok",
            detail: String(describing: mapped["imageId"] ?? localPath)
        )
        return mapped
    }

    func uploadAudioAttachmentPayload(_ payload: [String: Any]) async throws -> [String: Any] {
        let client = try await requireConnectedClient("Login before uploading audio")
        let localPath = try mediaLocalPath(from: payload, fallbackOperation: "media.upload_audio")
        let uploaded = try await client.media.uploadFile([
            "absolutePath": AnySendable(localPath)
        ])
        let mapped = ComposerMediaUploadPayload.audioPayload(localPayload: payload, uploaded: uploaded)
        appendLab(
            "media.upload_audio",
            status: "ok",
            detail: String(describing: mapped["audioId"] ?? localPath)
        )
        return mapped
    }

    func resolveMediaDisplayURL(fileId: String?, directURL: URL?) async -> URL? {
        guard let mediaId = fileId?.trimmingCharacters(in: .whitespacesAndNewlines), !mediaId.isEmpty else {
            return directURL
        }
        guard let client else { return directURL }
        // 本地副本优先（SDK 托管缓存：去重 + LRU + 离线）；没有就拿签名 URL，核心在后台把它拉进缓存。
        do {
            let resolved = try await client.media.resolveMediaAccess([
                "fileId": AnySendable(mediaId),
                "expiresIn": AnySendable(3600),
                "autoCache": AnySendable(true)
            ])
            if let url = displayURL(fromResolvedMediaAccess: resolved) {
                return url
            }
            appendLab("media.resolve_access", status: "warn", detail: "no display URL for \(mediaId)")
        } catch {
            appendLab("media.resolve_access", status: "warn", detail: "\(mediaId): \(FlareFormatters.errorText(error))")
        }
        return directURL
    }

    private func mediaLocalPath(from payload: [String: Any], fallbackOperation: String) throws -> String {
        if let path = payload["localPath"] as? String, !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return path
        }
        if let sourceUrl = payload["sourceUrl"] as? String,
           let url = URL(string: sourceUrl),
           url.isFileURL {
            return url.path
        }
        throw unavailable("Missing local media path for \(fallbackOperation)")
    }

    private func displayURL(fromResolvedMediaAccess resolved: [String: AnySendable]) -> URL? {
        let map = normalizedMap(resolved)
        let urlKeys = [
            "url", "cdnUrl", "cdn_url", "mediaUrl", "media_url",
            "downloadUrl", "download_url", "accessUrl", "access_url",
            "tempUrl", "temp_url", "sourceUrl", "source_url"
        ]
        if let localPath = nonEmptyString(in: map, keys: ["localPath", "local_path"]) {
            return fileOrRemoteURL(from: localPath, preferFilePath: true)
        }
        if let remote = normalizedValue(map["remote"]) as? [String: Any],
           let remoteURL = nonEmptyString(in: remote, keys: urlKeys) {
            return fileOrRemoteURL(from: remoteURL, preferFilePath: false)
        }
        if let topLevelURL = nonEmptyString(in: map, keys: urlKeys) {
            return fileOrRemoteURL(from: topLevelURL, preferFilePath: false)
        }
        return nil
    }

    private func normalizedMap(_ map: [String: AnySendable]) -> [String: Any] {
        Dictionary(uniqueKeysWithValues: map.map { ($0.key, normalizedValue($0.value) as Any) })
    }

    private func normalizedValue(_ raw: Any?) -> Any? {
        if let wrapped = raw as? AnySendable {
            return normalizedValue(wrapped.value)
        }
        if let map = raw as? [String: AnySendable] {
            return normalizedMap(map)
        }
        if let map = raw as? [String: Any] {
            return Dictionary(uniqueKeysWithValues: map.map { ($0.key, normalizedValue($0.value) as Any) })
        }
        return raw
    }

    private func nonEmptyString(in map: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = normalizedValue(map[key]) as? String {
                let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { return trimmed }
            }
        }
        return nil
    }

    private func fileOrRemoteURL(from value: String, preferFilePath: Bool) -> URL? {
        if value.hasPrefix("file://") {
            return URL(string: value)
        }
        if value.hasPrefix("http://") || value.hasPrefix("https://") || value.hasPrefix("blob:") {
            return URL(string: value)
        }
        if preferFilePath || value.hasPrefix("/") {
            return URL(fileURLWithPath: value)
        }
        return URL(string: value)
    }

    func retry(_ message: AppMessage) async {
        await perform("message.retry") {
            let client = try await requireConnectedClient("Login before retrying messages")
            failedMessageKeys.remove(message.appStableId)
            pendingMessageKeys.insert(message.appStableId)
            do {
                _ = try await sendMessageWithRetry(client: client, message: message.core)
                pendingMessageKeys.remove(message.appStableId)
                await refreshTimelineAfterSend(client: client, conversationId: message.conversationId)
            } catch {
                pendingMessageKeys.remove(message.appStableId)
                failedMessageKeys.insert(message.appStableId)
                throw error
            }
        }
    }

    func messageAction(
        _ action: String,
        message: AppMessage,
        reaction: String = "like",
        text: String = ""
    ) async {
        await perform("message.\(action)") {
            let client = try await requireConnectedClient("Login before message actions")
            let request = messageMutationRequest(message)
            switch action {
            case "recall":
                try await client.messages.recallMessage(request)
            case "edit":
                // 正文由调用方给：曾经写死 "Edited from iOS example"，
                // 点一下"编辑"就把用户的原文替换成占位串，且没有任何输入入口。
                try await client.messages.editTextByMessageId(request.merging(["text": AnySendable(text)]) { $1 })
            case "editRich":
                try await client.messages.editRichDocByMessageId(request.merging(["markdown": AnySendable("## Edited rich doc\n\n- **bold** point\n- _italic_ point")]) { $1 })
            case "deleteSelf":
                try await client.messages.deleteMessageForSelf(request)
            case "deleteEveryone":
                try await client.messages.deleteMessageForEveryone(request)
            case "react":
                try await client.messages.addReaction(request.merging(["emoji": AnySendable(reaction)]) { $1 })
            case "unreact":
                try await client.messages.removeReaction(request.merging(["emoji": AnySendable(reaction)]) { $1 })
            case "pin":
                try await client.messages.pinMessageById(pinRequest(request, scope: messagePinScopeConversation))
            case "pinSelf":
                try await client.messages.pinMessageById(pinRequest(request, scope: messagePinScopeSelf))
            case "unpin":
                try await client.messages.unpinMessageById(pinRequest(request, scope: messagePinScopeConversation))
            // mark_by_message_id 要 markType(i32) + color(非空字符串)，unmark 要 markType；
            // 只发消息 id 必然 INVALID_PARAMETER。取值与 web 参考示例一致（重要 + 默认色）。
            case "mark":
                try await client.messages.markMessageById(request.merging([
                    "markType": AnySendable(messageMarkTypeImportant),
                    "color": AnySendable(messageMarkDefaultColor),
                ]) { $1 })
            case "unmark":
                try await client.messages.unmarkMessageById(request.merging(["markType": AnySendable(messageMarkTypeImportant)]) { $1 })
            default:
                throw unavailable("Unsupported action \(action)")
            }
            await openConversation(message.conversationId)
        }
    }

    func noteMessageAction(_ operation: String, detail: String) async {
        appendLab(operation, status: "ok", detail: detail)
    }

    func setTyping(_ typing: Bool) async {
        guard let selectedConversationId else { return }
        await perform("message.typing") {
            let client = try await requireConnectedClient("Login before typing events")
            try await client.messages.setTyping([
                "conversationId": AnySendable(selectedConversationId),
                "typing": AnySendable(typing)
            ])
        }
    }


    @discardableResult
    func openPeerConversation() async -> AppConversation? {
        let peer = startConversationDraft.peerUserId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !peer.isEmpty else { return nil }
        var opened: AppConversation?
        await perform("conversation.get_one") {
            let client = try await requireConnectedClient("Login before starting chat")
            let conversation = try await client.conversations.getOneConversation([
                "sourceId": AnySendable(peer),
                "conversationType": AnySendable(ConversationType.single.rawValue)
            ])
            opened = SdkModelMapper.conversationFromCore(conversation)
            await openConversation(conversation.conversationId)
            do {
                try await syncConversationList(reason: "open_peer")
            } catch {
                appendLab("view.conversation_list.open", status: "warn", detail: FlareFormatters.errorText(error))
            }
        }
        return opened
    }

    @discardableResult
    func openGroupConversation() async -> AppConversation? {
        let ids = startConversationDraft.groupUserIds
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !ids.isEmpty else { return nil }
        var opened: AppConversation?
        await perform("conversation.get_group_by_user_ids") {
            let client = try await requireConnectedClient("Login before starting group chat")
            let conversation = try await client.conversations.getGroupConversationByUserIds([
                "userIds": AnySendable(ids)
            ])
            opened = SdkModelMapper.conversationFromCore(conversation)
            await openConversation(conversation.conversationId)
            do {
                try await syncConversationList(reason: "open_group")
            } catch {
                appendLab("view.conversation_list.open", status: "warn", detail: FlareFormatters.errorText(error))
            }
        }
        return opened
    }

    func conversationAction(_ action: String, conversation: AppConversation) async {
        await perform("conversation.\(action)") {
            let client = try await requireConnectedClient("Login before conversation actions")
            let request: [String: AnySendable] = [
                "conversationId": AnySendable(conversation.conversationId)
            ]
            switch action {
            case "pin":
                try await client.conversations.setConversationPinned(request.merging(["pinned": AnySendable(!conversation.isPinned)]) { $1 })
            case "mute":
                try await client.conversations.setConversationMuted(request.merging(["muted": AnySendable(!conversation.isMuted)]) { $1 })
            case "archive":
                try await client.conversations.setConversationArchived(request.merging(["archived": AnySendable(!conversation.isArchived)]) { $1 })
            case "unread":
                _ = try await client.conversations.markConversationUnread(request)
            case "clear":
                try await client.conversations.clearLocalChatHistory(request)
                repository.clearMessages(in: conversation.conversationId)
            case "delete":
                try await client.conversations.deleteConversation(request)
                repository.removeConversation(conversation.conversationId)
            default:
                throw unavailable("Unsupported action \(action)")
            }
            await refreshConversations()
        }
    }

    func saveDraft(_ text: String) async {
        guard let selectedConversationId else { return }
        await perform("conversation.draft") {
            let client = try await requireConnectedClient("Login before saving drafts")
            try await client.conversations.updateConversationDraft(UpdateConversationDraftRequest(
                conversationId: selectedConversationId,
                draft: text
            ))
            await refreshConversations()
        }
    }

    func syncSelectedConversation(showBusy: Bool = true) async {
        guard let selectedConversationId else { return }
        await perform("sync.conversation", showBusy: showBusy) {
            let client = try await requireConnectedClient("Login before sync", showProgress: showBusy)
            do {
                try await client.sync.syncConversation(["conversationId": AnySendable(selectedConversationId)])
                try await client.sync.syncMessages([
                    "conversationId": AnySendable(selectedConversationId),
                    "lastSeq": AnySendable(selectedMessages.last?.seq ?? 0),
                    "limit": AnySendable(100)
                ])
            } catch {
                appendLab("sync.conversation", status: "warn", detail: FlareFormatters.errorText(error))
                if showBusy { throw error }
            }
            await markConversationReadBestEffort(
                client: client,
                conversationId: selectedConversationId,
                messages: selectedMessages,
                operation: "conversation.mark_read_after_sync"
            )
            await openConversation(selectedConversationId, showBusy: false)
        }
    }

    private func maxPositiveSeq(in messages: [AppMessage]) -> UInt64? {
        let seq = messages.map(\.seq).max() ?? 0
        return seq > 0 ? seq : nil
    }

    private func markConversationReadBestEffort(
        client: any FlareImClientProtocol,
        conversationId: String,
        messages: [AppMessage],
        operation: String
    ) async {
        guard let readSeq = maxPositiveSeq(in: messages) else { return }
        do {
            try await retryingDatabaseLock(operation: operation) {
                try await client.conversations.markConversationRead([
                    "conversationId": AnySendable(conversationId),
                    "readSeq": AnySendable(readSeq)
                ])
            }
        } catch {
            appendLab(operation, status: "warn", detail: FlareFormatters.errorText(error))
        }
    }

    private func matchesCurrentFilter(_ conversation: AppConversation) -> Bool {
        switch environment.filter {
        case .all: return !conversation.isArchived
        case .unread: return conversation.unreadCount > 0 && !conversation.isArchived
        case .mentions: return conversation.mentionMe && !conversation.isArchived
        case .pinned: return conversation.isPinned && !conversation.isArchived
        case .archived: return conversation.isArchived
        case .muted: return conversation.isMuted && !conversation.isArchived
        case .drafts: return !(conversation.draft ?? "").isEmpty && !conversation.isArchived
        }
    }

    /// What the core allows for this message right now (`domain::message_actions`), in the type
    /// the kit's message action sheet takes. The request is flat: `op` sits beside the parameters.
    func actionAvailability(for message: AppMessage) async -> FlareMessageActionAvailability {
        guard let client = session.client else { return FlareMessageActionAvailability() }
        let key = message.appStableId
        let request: [String: AnySendable] = [
            "op": AnySendable("action_availability"),
            "messageId": AnySendable(message.serverId.isEmpty ? message.clientMsgId : message.serverId),
            "multiSelectMode": AnySendable(isMessageMultiSelectMode),
            "isPending": AnySendable(pendingMessageKeys.contains(key) || message.localState?.sending == true),
            "isFailed": AnySendable(failedMessageKeys.contains(key) || message.localState?.failed == true),
            "isPinned": AnySendable(message.isPinned),
            "isConnected": AnySendable(runtimeStatus == .ready),
        ]
        do {
            let answer = try await client.messages.dispatchMessage(request)
            return FlareMessageActionAvailability(json: answer.mapValues(\.value))
        } catch {
            appendLab("message.action_availability", status: "error", detail: String(describing: error))
            return FlareMessageActionAvailability()
        }
    }

    func messageMutationRequest(_ message: AppMessage) -> [String: AnySendable] {
        [
            "conversationId": AnySendable(message.conversationId),
            "messageId": AnySendable(message.serverId.isEmpty ? message.clientMsgId : message.serverId),
            "clientMsgId": AnySendable(message.clientMsgId),
            "seq": AnySendable(message.seq)
        ]
    }

    private func pinRequest(_ request: [String: AnySendable], scope: Int) -> [String: AnySendable] {
        request.merging(["scope": AnySendable(scope)]) { $1 }
    }
}
