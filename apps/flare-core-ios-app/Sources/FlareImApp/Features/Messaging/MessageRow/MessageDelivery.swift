import FlareCoreAppleSDK
import Foundation

enum MessageDeliveryStateKind: String {
    case none, sending, failed, delivered, read
}

/// 送达状态。**真源是核心 `domain::message_delivery_state`**；这里是它在 iOS 侧的实现，由
/// `sdk-spec/message-action-vectors.json` 逐位钉住（见 MessageActionVectorsTests）。
///
/// 消息动作的可用性不在这里：那是核心直接回答的（`MessagingViewModel.actionAvailability`），
/// iOS 不再保留一份自己的规则。
enum MessageDelivery {
    private static let statusFailed = 4
    private static let statusRecalled = 5
    private static let statusDeleted = 6

    /// 自己发出的消息该显示什么送达状态。视觉：单勾=已送达、双勾=已读。
    static func state(
        isSelf: Bool,
        status: Int,
        isRead: Bool,
        isPending: Bool,
        isFailed: Bool
    ) -> MessageDeliveryStateKind {
        // 对方发来的消息不显示送达状态——那是发送方才关心的事。
        guard isSelf else { return .none }
        // 撤回/删除是终态，由占位气泡接管展示。
        if status == statusRecalled || status == statusDeleted { return .none }
        if isFailed || status == statusFailed { return .failed }
        if isPending { return .sending }
        return isRead ? .read : .delivered
    }
}

extension AppMessage {
    /// 置顶记在属性里，不在 status。
    var isPinned: Bool {
        core.attributes.booleanValue(forAnyOf: ["pinned", "isPinned", "messagePinned"])
    }

    /// 映射到核心的数值状态。撤回/删除在这个 app 里走的是布尔字段而非 status。
    var numericStatus: Int {
        if isRecalled { return 5 }
        if isDeleted { return 6 }
        return Int(core.status)
    }

    var isDeleted: Bool {
        core.attributes.booleanValue(forAnyOf: ["deleted", "isDeleted", "messageDeleted"])
    }
}

private extension [String: String] {
    func booleanValue(forAnyOf keys: [String]) -> Bool {
        keys.contains { key in
            guard let value = self[key]?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
                return false
            }
            return value == "true" || value == "1" || value == "yes"
        }
    }
}
