import Combine
import Foundation
import FlareCoreAppleSDK

/// 客户端侧的「视图数据仓库」:把 core 拥有的 observable views(会话列表 / 时间线)经 delta / 快照
/// 投影到本地缓存。这是从 god-store 抽出的**数据层** —— ConversationList 与 Chat 两个特性共享它。
///
/// 设计:
/// - 不持有 client(开视图时由调用方经 [AppSession] 传入);delta 应用是纯本地操作。
/// - **不持有选择态**:`selectedConversationId` 是 UI/导航关注点,留在上层;时间线 delta 用本仓库自有的
///   `activeTimelineConversationId`(= 当前打开时间线的会话)门控。
/// - 印证 memory `views-core-vs-shadow-engines`:core 拥有视图顺序,client 只投影,不重排不维护影子引擎。
@MainActor
final class ViewDataRepository: ObservableObject {
    @Published private(set) var conversations: [AppConversation] = []
    @Published private(set) var messagesByConversation: [String: [AppMessage]] = [:]
    @Published private(set) var hasMoreMessagesByConversation: [String: Bool] = [:]

    /// 视图打开的诊断日志钩子(由 store / VM 注入到 SDK Lab 控制台)。
    var onLog: (@MainActor (_ operation: String, _ detail: String) -> Void)?

    private var conversationListViewId: String?
    private var timelineViewId: String?
    /// 已应用到本地缓存的时间线视图版本号:view.updated 按版本号逐次加 1 推来,跳号时取快照整体替换。
    private var timelineRevision: UInt64 = 0
    private var activeTimelineConversationId: String?

    nonisolated init() {}

    func messages(in conversationId: String?) -> [AppMessage] {
        guard let conversationId else { return [] }
        // Trust core timeline-view order (display-ready, owned by core); no client re-sort.
        return messagesByConversation[conversationId, default: []]
    }

    func hasMoreMessages(in conversationId: String?) -> Bool {
        guard let conversationId else { return false }
        return hasMoreMessagesByConversation[conversationId, default: true]
    }

    // MARK: - 本地缓存维护(乐观更新;随后 refresh 会再同步)

    /// 退出登录 / 释放时清空本地缓存。
    func reset() {
        conversations = []
        messagesByConversation = [:]
        hasMoreMessagesByConversation = [:]
        conversationListViewId = nil
        timelineViewId = nil
        activeTimelineConversationId = nil
    }

    /// clearLocalChatHistory 后清掉某会话的本地消息。
    func clearMessages(in conversationId: String) {
        messagesByConversation[conversationId] = []
        hasMoreMessagesByConversation[conversationId] = false
    }

    /// deleteConversation 后本地移除(选择态由上层观察 `$conversations` 自行重置)。
    func removeConversation(_ conversationId: String) {
        conversations.removeAll { $0.conversationId == conversationId }
        messagesByConversation.removeValue(forKey: conversationId)
        hasMoreMessagesByConversation.removeValue(forKey: conversationId)
    }

    // MARK: - 打开视图(订阅 core 观察视图 + 应用首帧快照)

    func openConversationList(client: any FlareImClientProtocol, reason: String) async throws {
        try await client.sync.syncConversationSummaries()
        let home = try await client.conversations.bootstrapHomeTimeline(BootstrapHomeTimelineRequest(conversationLimit: 100))
        conversations = SdkModelMapper.conversationsFromCore(home.conversations)
        onLog?("conversation.bootstrap_home", "\(reason): \(conversations.count) conversations")

        let response = try await client.views.openConversationList(OpenConversationListViewRequest(conversationLimit: 100))
        if let oldViewId = conversationListViewId, oldViewId != response.viewId {
            _ = try? await client.views.close(CloseViewRequest(viewId: oldViewId))
        }
        conversationListViewId = response.viewId
        try applyConversationListSnapshot(response.snapshot)
        onLog?("view.conversation_list.open", "\(reason): \(conversations.count) conversations")
    }

    func openTimeline(client: any FlareImClientProtocol, conversationId: String, reason: String) async throws {
        if let oldViewId = timelineViewId {
            _ = try? await client.views.close(CloseViewRequest(viewId: oldViewId))
        }
        activeTimelineConversationId = conversationId
        await prefetchTimelineMessages(client: client, conversationId: conversationId, reason: reason)
        let response = try await client.views.openTimeline(OpenTimelineViewRequest(
            conversationId: conversationId,
            messageLimit: 50
        ))
        timelineViewId = response.viewId
        try applyTimelineSnapshot(response.snapshot, viewId: response.viewId, revision: response.revision)
        onLog?("view.timeline.open", "\(reason): \(messagesByConversation[conversationId, default: []].count) messages")
    }

    private func prefetchTimelineMessages(client: any FlareImClientProtocol, conversationId: String, reason: String) async {
        let localLastSeq = messagesByConversation[conversationId, default: []].map(\.seq).max() ?? 0
        do {
            try await client.sync.syncConversation(["conversationId": AnySendable(conversationId)])
            try await client.sync.syncMessages([
                "conversationId": AnySendable(conversationId),
                "lastSeq": AnySendable(localLastSeq),
                "limit": AnySendable(50)
            ])
            onLog?("sync.timeline.prefetch", "\(reason): localLastSeq=\(localLastSeq)")
        } catch {
            onLog?("sync.timeline.prefetch", "\(reason): warn \(String(describing: error))")
        }
    }

    /// 经观察时间线视图向上翻历史:core 扩窗并经 view.updated 推来这一页,client 仅应用(不自取+合并+重排)。
    /// 返回值说这一页在哪个版本里;事件还没到时取快照,保证返回前已应用。
    func loadOlderTimeline(client: any FlareImClientProtocol, conversationId: String) async throws {
        guard let timelineViewId else { return }
        let response = try await client.views.loadOlderTimeline(LoadOlderTimelineViewRequest(
            viewId: timelineViewId,
            messageLimit: 30
        ))
        guard response.viewId == timelineViewId, activeTimelineConversationId == conversationId else { return }
        if timelineRevision < response.revision {
            try await resyncTimeline(client: client, viewId: response.viewId)
        }
    }

    /// 版本号跳了(或翻页结果还没随事件到达):取当前快照整体替换。
    func resyncTimeline(client: any FlareImClientProtocol, viewId: String) async throws {
        let response = try await client.views.timelineSnapshot(TimelineViewRequest(viewId: viewId))
        guard viewId == timelineViewId, response.revision >= timelineRevision else { return }
        try applyTimelineSnapshot(response.snapshot, viewId: viewId, revision: response.revision)
    }

    // MARK: - 应用 core 推来的视图更新(delta / 快照)

    /// 事件入口:吞掉解码错误(与原 god-store 行为一致)。返回 false 表示时间线视图版本号跳了,
    /// 调用方应调 `resyncTimeline` 取快照。
    @discardableResult
    func apply(_ update: ViewUpdate) -> Bool {
        if update.viewId == timelineViewId {
            if update.revision <= timelineRevision { return true }
            if update.revision != timelineRevision + 1 { return false }
            timelineRevision = update.revision
        }
        try? applyViewUpdate(update)
        return true
    }

    private func applyViewUpdate(_ update: ViewUpdate) throws {
        if update.kind == "delta" {
            guard let delta = update.delta else { return }
            try applyViewDelta(viewId: update.viewId, delta: delta)
            return
        }
        if update.viewId == conversationListViewId {
            guard let snapshot = update.snapshot else { return }
            try applyConversationListSnapshot(snapshot)
            return
        }
        if update.viewId == timelineViewId {
            guard let snapshot = update.snapshot else { return }
            try applyTimelineSnapshot(snapshot, viewId: update.viewId, revision: update.revision)
        }
    }

    private func applyViewDelta(viewId: String, delta: ViewDelta) throws {
        if delta.viewType == "conversationList" {
            try applyConversationListDelta(viewId: viewId, delta: delta)
            return
        }
        if delta.viewType == "timeline" {
            try applyTimelineDelta(viewId: viewId, delta: delta)
        }
    }

    private func applyConversationListDelta(viewId: String, delta: ViewDelta) throws {
        guard viewId == conversationListViewId else { return }
        conversations = try applyIndexedDeltaOps(
            current: conversations,
            ops: delta.ops ?? [],
            keyOf: { $0.conversationId }
        ) { op in
            guard let item = op.item else { return nil }
            let conversation = try conversationFromJson(item)
            guard conversation.conversationId.trimmed == op.key.trimmed else { return nil }
            return SdkModelMapper.conversationFromCore(conversation)
        }
    }

    /// 时间线视图的行键:clientMsgId,没有时 serverId,都没有时 seq:<会话>:<seq>(与核心 row_key 相同)。
    private func timelineRowKey(_ message: AppMessage) -> String {
        if !message.clientMsgId.isEmpty { return message.clientMsgId }
        if !message.serverId.isEmpty { return message.serverId }
        return "seq:\(message.conversationId):\(message.seq)"
    }

    /// 按核心视图的增量规则应用:删 remove;原位替换 upsert;prepend 放最前、append 放最后;
    /// reorder 非空时按它重排;最后取 hasOlder 与 conversation。
    private func applyTimelineDelta(viewId: String, delta: ViewDelta) throws {
        guard viewId == timelineViewId else { return }
        let conversationId = activeTimelineConversationId ?? ""
        guard !conversationId.isEmpty else { return }
        if let deltaConversationId = delta.conversation?.conversationId, !deltaConversationId.isEmpty {
            guard deltaConversationId == conversationId else { return }
        }
        let removed = Set(delta.remove ?? [])
        var upserts: [String: AppMessage] = [:]
        for message in SdkModelMapper.messagesFromCore(delta.upsert ?? []) {
            upserts[timelineRowKey(message)] = message
        }
        var next = messagesByConversation[conversationId, default: []]
            .filter { !removed.contains(timelineRowKey($0)) }
            .map { upserts[timelineRowKey($0)] ?? $0 }
        next = SdkModelMapper.messagesFromCore(delta.prepend ?? []) + next
            + SdkModelMapper.messagesFromCore(delta.append ?? [])
        if let order = delta.reorder {
            var byKey: [String: AppMessage] = [:]
            for message in next {
                byKey[timelineRowKey(message)] = message
            }
            next = order.compactMap { byKey[$0] }
        }
        messagesByConversation[conversationId] = next
        if let conversation = delta.conversation {
            replaceConversationSnapshot(SdkModelMapper.conversationFromCore(conversation))
        }
        if let hasOlder = delta.hasOlder {
            hasMoreMessagesByConversation[conversationId] = hasOlder
        }
    }

    private func applyIndexedDeltaOps<T>(
        current: [T],
        ops: [ViewDeltaOp],
        keyOf: (T) -> String,
        decodeItem: (ViewDeltaOp) throws -> T?
    ) throws -> [T] {
        var next = current
        func indexByKey(_ key: String) -> Int? {
            next.firstIndex { keyOf($0).trimmed == key }
        }
        for op in ops {
            let key = op.key.trimmed
            guard !key.isEmpty else { continue }
            switch op.op {
            case "remove":
                if let index = indexByKey(key) {
                    next.remove(at: index)
                }
            case "move":
                guard let index = indexByKey(key) else { continue }
                let item = next.remove(at: index)
                next.insert(item, at: boundedDeltaIndex(op.index, count: next.count))
            case "insert":
                guard let item = try decodeItem(op) else { continue }
                if let index = indexByKey(key) {
                    next.remove(at: index)
                }
                next.insert(item, at: boundedDeltaIndex(op.index, count: next.count))
            case "update":
                guard let index = indexByKey(key), let item = try decodeItem(op) else { continue }
                next[index] = item
            default:
                continue
            }
        }
        return next
    }

    private func boundedDeltaIndex(_ index: UInt32, count: Int) -> Int {
        max(0, min(Int(index), count))
    }

    private func applyConversationListSnapshot(_ snapshot: ViewSnapshot) throws {
        guard snapshot.viewType == "conversationList" else { return }
        let home = try homeTimelineSnapshotFromJson(snapshot.data)
        conversations = SdkModelMapper.conversationsFromCore(home.conversations)
    }

    private func applyTimelineSnapshot(_ snapshot: ViewSnapshot, viewId: String, revision: UInt64) throws {
        guard viewId == timelineViewId, snapshot.viewType == "timeline" else { return }
        timelineRevision = revision
        let timeline = try timelineViewSnapshotFromJson(snapshot.data)
        let conversationId = timeline.conversation?.conversationId ?? activeTimelineConversationId ?? ""
        guard !conversationId.isEmpty, conversationId == activeTimelineConversationId else { return }
        if let conversation = timeline.conversation {
            replaceConversationSnapshot(SdkModelMapper.conversationFromCore(conversation))
        }
        hasMoreMessagesByConversation[conversationId] = timeline.hasOlder
        messagesByConversation[conversationId] = SdkModelMapper.messagesFromCore(timeline.messages)
            .sorted { $0.appSortTimestamp < $1.appSortTimestamp }
    }

    private func replaceConversationSnapshot(_ conversation: AppConversation) {
        if let index = conversations.firstIndex(where: { $0.conversationId == conversation.conversationId }) {
            conversations[index] = conversation
        } else {
            conversations.append(conversation)
        }
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
