import Foundation
import FlareCoreAppleSDK

/// App-domain conversation model used by the Apple example UI.
///
/// The example keeps a reference to the generated SDK model for command
/// payloads, but all UI-facing access goes through this app model. This mirrors
/// the Flutter `fromCore` boundary without adding a JSON remapping layer.
struct AppConversation: Identifiable, Sendable {
    let core: Conversation

    var id: String { conversationId }
    var conversationId: String { core.conversationId }
    var conversationType: ConversationType { core.conversationType }
    var channelId: String { core.channelId }
    var membersCount: UInt32 { core.membersCount }
    var avatarUrl: String { core.avatarUrl }
    var unreadCount: UInt32 { core.unreadCount }
    var isPinned: Bool { core.isPinned }
    var isMuted: Bool { core.isMuted }
    var isArchived: Bool { core.isArchived }
    var draft: String? { core.draft }
    var mentionCount: UInt32 { core.mentionCount }
    var mentionMe: Bool { core.mentionMe }
    var role: String? { core.role }
    var version: UInt64 { core.version }
    var lastReadSeq: UInt64 { core.lastReadSeq }
    var maxSeq: UInt64 { core.maxSeq }
    var memberPreview: [ConversationParticipant] { core.memberPreview }

    var appTitle: String {
        if let remark = core.remark?.trimmingCharacters(in: .whitespacesAndNewlines), !remark.isEmpty {
            return remark
        }
        let name = core.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty {
            return name
        }
        // A direct chat's channel id is the peer's user id. Without this step the title fell
        // back to the raw conversation id whenever a snapshot arrived without a display name —
        // on open, and again after pinning. Same order as the Android example.
        let channel = channelId.trimmingCharacters(in: .whitespacesAndNewlines)
        if !channel.isEmpty {
            return channel
        }
        return conversationId.isEmpty ? "Untitled conversation" : conversationId
    }

    var appPreview: String {
        if let draft, !draft.isEmpty {
            return "Draft: \(draft)"
        }
        if let preview = core.lastMessagePreview?.trimmingCharacters(in: .whitespacesAndNewlines),
           !preview.isEmpty {
            return PreviewStorageFormat.format(preview)
        }
        if let lastMessage = core.lastMessage {
            return lastMessage.previewText
        }
        return core.description ?? "No messages yet"
    }

    var appSortTimestamp: UInt64 {
        core.updatedAtTs ?? core.lastMessageAt ?? core.updatedAt
    }
}

/// App-domain message model used by timeline, search, and message actions.
struct AppMessage: Identifiable, Sendable {
    let core: Message

    var id: String { appStableId }
    var serverId: String { core.serverId }
    var clientMsgId: String { core.clientMsgId }
    var conversationId: String { core.conversationId }
    var senderId: String { core.senderId }
    var senderAvatar: String { core.senderAvatar }
    var seq: UInt64 { core.conversationSeq }
    var quotePreview: String? { core.quotePreview }
    var isRead: Bool { core.isRead }
    var isRecalled: Bool { core.isRecalled }
    var isEdited: Bool { core.isEdited }
    var reactions: [ReactionEntry] { core.reactions }
    var localState: MessageLocalState? { core.localState }
    var content: MessageContent? { core.content }

    var appStableId: String {
        if !core.timelineKey.isEmpty { return core.timelineKey }
        if !serverId.isEmpty { return serverId }
        if !clientMsgId.isEmpty { return clientMsgId }
        if seq > 0 { return "\(conversationId):seq:\(seq)" }
        return "\(conversationId):\(core.createdAt):\(core.clientCreatedAt):\(senderId)"
    }

    var appSortTimestamp: UInt64 {
        core.timelineSortTs.nonZero ?? core.localState?.sortTs ?? core.createdAt.nonZero ?? core.clientCreatedAt
    }

    var senderTitle: String {
        if !core.senderDisplayName.isEmpty { return core.senderDisplayName }
        if !core.senderName.isEmpty { return core.senderName }
        return senderId.isEmpty ? "Unknown" : senderId
    }

    var previewText: String {
        if isRecalled { return "Message recalled" }
        guard let content else { return "Unsupported message" }
        return content.previewText
    }
}

private extension UInt64 {
    var nonZero: UInt64? { self == 0 ? nil : self }
}
