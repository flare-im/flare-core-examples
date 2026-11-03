import FlareCoreAppleSDK
import FlareIMUI
import AVFoundation
import AVKit
import SwiftUI

struct MessageRow: View {
    @EnvironmentObject private var messaging: MessagingViewModel
    let message: AppMessage
    var onOpenMedia: (MediaPreview) -> Void = { _ in }
    var onShowActions: (AppMessage) -> Void = { _ in }
    /// Saves the message's file to the download location (a file tap); the chat says how it went.
    var onSave: (AppMessage) -> Void = { _ in }
    @State private var mediaTask: Task<Void, Never>?
    /// A picture's local copy in the SDK media cache, else a fetchable URL (``MessagingViewModel/resolvePicture(fileId:)``).
    @State private var picture: PictureAccess?

    private var outgoing: Bool {
        guard let current = messaging.currentUserId else { return false }
        return message.senderId == current
    }

    var body: some View {
        let reactions = Self.reactionGroups(for: message, currentUserId: messaging.currentUserId)
        VStack(alignment: outgoing ? .trailing : .leading, spacing: 0) {
            MessageBubbleView(
                message: presentationMessage,
                currentUserId: messaging.currentUserId ?? "",
                conversationKind: .group,
                onMediaAction: { _, content in openMedia(content) },
                onResend: outgoing ? { _ in Task { await messaging.retry(message) } } : nil
            )
            .contentShape(Rectangle())
            .highPriorityGesture(
                LongPressGesture(minimumDuration: 0.42)
                    .onEnded { _ in onShowActions(message) }
            )
            .accessibilityAction(named: Text("More actions")) {
                onShowActions(message)
            }
            // Reactions sit under the bubble, as in the other examples. Tapping a pill you
            // already reacted with takes it back; any other pill adds that reaction.
            if !reactions.isEmpty {
                ReactionSummaryView(reactions: reactions, hideAdd: true) { emoji in
                    let remove = reactions.first { $0.emoji == emoji }?.reactedBySelf == true
                    Task { await messaging.messageAction(remove ? "unreact" : "react", message: message, reaction: emoji) }
                }
                .padding(.horizontal, FlareSizes.spacingMd)
                .padding(.bottom, FlareSizes.spacingXs)
            }
        }
        .onDisappear { mediaTask?.cancel() }
        // Pictures are drawn from the SDK media cache once it holds them; until then from a signed URL while the
        // core fetches the picture into the cache in the background.
        .task(id: pictureKey) {
            guard let pictureKey else { return }
            picture = await messaging.resolvePicture(fileId: pictureKey)
        }
    }

    /// The stored file id of this message's picture, when it is one.
    private var pictureKey: String? {
        guard let content = message.content, !message.isRecalled,
              content.contentType == .image || content.contentType == .imageGroup else { return nil }
        return content.mediaFileId
    }

    /// The message's reactions for the kit `ReactionSummaryView`. A recalled message shows none.
    static func reactionGroups(for message: AppMessage, currentUserId: String?) -> [ReactionGroup] {
        guard !message.isRecalled else { return [] }
        return message.reactions.map { reaction in
            ReactionGroup(
                emoji: reaction.emoji,
                count: Int(reaction.count),
                reactedBySelf: currentUserId.map(reaction.userIds.contains) ?? false,
                users: reaction.userIds
            )
        }
    }

    private var presentationMessage: FlareMessageData {
        FlareMessageData(
            id: message.appStableId,
            senderId: message.senderId,
            senderName: message.senderTitle,
            content: presentationContent,
            senderAvatarURL: message.senderAvatar.isEmpty ? nil : message.senderAvatar,
            timeLabel: Self.timeFormatter.string(from: Date(timeIntervalSince1970: Double(message.appSortTimestamp) / 1000)),
            status: presentationStatus,
            edited: message.isEdited
        )
    }

    private var presentationContent: FlareMessageContent {
        if message.isRecalled { return FlareNotificationContent(String(localized: "Message recalled")) }
        guard let content = message.content else { return FlarePlaceholderContent(String(localized: "Unsupported message")) }
        switch content.contentType {
        case .text, .richText, .quote, .forward, .thread:
            return FlareTextContent(content.previewText)
        case .image, .imageGroup:
            // The local copy is only ever a path the core returned from its cache, never an address from content.
            let local = picture?.localPath
            let url = content.mediaSourceURL?.absoluteString ?? picture?.url ?? ""
            guard !url.isEmpty || local != nil else {
                return FlarePlaceholderContent(content.previewText)
            }
            return FlareImageContent(url: url, alt: content.stringValue("description", "title"), localPath: local)
        case .video:
            guard let url = content.mediaSourceURL?.absoluteString else {
                return FlarePlaceholderContent(content.previewText)
            }
            return FlareVideoContent(url: url, poster: content.stringValue("thumbnailUrl"), durationSec: max(0, (content.mediaDurationMs ?? 0) / 1000))
        case .audio:
            return FlareAudioContent(url: content.mediaSourceURL?.absoluteString ?? "", durationSec: max(0, (content.mediaDurationMs ?? 0) / 1000))
        case .file:
            return FlareFileContent(name: content.fileDisplayName, url: content.mediaSourceURL?.absoluteString ?? "", sizeBytes: Int(content.mediaByteSize ?? 0))
        case .location:
            return FlareLocationContent(name: content.stringValue("title", "name") ?? String(localized: "Location"), address: content.stringValue("address") ?? "")
        case .sticker:
            return FlareStickerContent(url: content.mediaSourceURL?.absoluteString ?? content.stringValue("url") ?? "", packageId: content.stringValue("packageId", "package_id"), stickerId: content.stringValue("stickerId", "id"))
        case .emoji:
            return FlareEmojiContent(content.stringValue("emoji", "key") ?? content.previewText)
        case .card:
            return FlareCardContent(title: content.stringValue("title", "name") ?? content.previewText, subtitle: content.stringValue("subtitle", "description"), imageURL: content.stringValue("thumbnailUrl", "imageUrl"))
        case .linkCard:
            return FlareLinkCardContent(url: content.stringValue("url") ?? "", title: content.stringValue("title") ?? content.previewText,
                description: content.stringValue("description", "summary"), imageURL: content.stringValue("thumbnailUrl", "imageUrl"))
        case .vote:
            return FlarePollContent(id: content.stringValue("voteId") ?? "", title: content.stringValue("headline", "title") ?? content.previewText,
                options: content.data["options"]?.value as? [String] ?? [])
        case .task:
            return FlareTaskContent(id: content.stringValue("taskId") ?? "", title: content.stringValue("title") ?? content.previewText,
                detail: content.stringValue("detail", "description") ?? "", done: (content.data["metadata"]?.value as? [String: String])?["done"] == "true")
        case .schedule:
            return FlareCalendarContent(id: content.stringValue("scheduleId") ?? "", title: content.stringValue("title") ?? content.previewText,
                timeRange: content.stringValue("timeRange") ?? "")
        case .miniProgram:
            return FlareMiniAppContent(appId: content.stringValue("appId") ?? "", title: content.stringValue("title") ?? content.previewText,
                pagePath: content.stringValue("pagePath") ?? "", thumbnailUrl: content.stringValue("thumbnailUrl"), description: content.stringValue("description"))
        case .announcement:
            return FlareAnnouncementContent(id: content.stringValue("announcementId") ?? "", title: content.stringValue("headline", "title") ?? content.previewText,
                body: content.stringValue("body") ?? "")
        case .system, .notification:
            return FlareNotificationContent(content.previewText)
        case .custom, .placeholder:
            return FlareGenericContent(contentType: content.contentType.rawValue, label: content.previewText)
        }
    }

    private var presentationStatus: FlareMessageDeliveryStatus {
        let kind = MessageDelivery.state(
            isSelf: outgoing,
            status: message.numericStatus,
            isRead: message.isRead,
            isPending: messaging.pendingMessageKeys.contains(message.appStableId),
            isFailed: messaging.failedMessageKeys.contains(message.appStableId)
                || message.localState?.failed == true
        )
        switch kind {
        case .none: return .sent
        case .sending: return .sending
        case .failed: return .failed
        case .delivered: return .sent
        case .read: return .read
        }
    }

    private func openMedia(_ content: FlareMessageContent) {
        mediaTask?.cancel()
        mediaTask = Task { @MainActor in
            if content is FlareFileContent {
                onSave(message)
                return
            }
            let kind: MediaPreview.Kind
            let title: String
            let source: String
            switch content {
            case let image as FlareImageContent:
                // A picture the cache already holds opens from this device.
                if let local = image.localPath, !Task.isCancelled {
                    onOpenMedia(MediaPreview(kind: .image, url: URL(fileURLWithPath: local), title: image.alt ?? String(localized: "Image"),
                                             message: message))
                    return
                }
                kind = .image; source = image.url; title = image.alt ?? String(localized: "Image")
            case let video as FlareVideoContent:
                kind = .video; source = video.url; title = String(localized: "Video")
            case let audio as FlareAudioContent:
                kind = .audio; source = audio.url; title = String(localized: "Voice")
            default: return
            }
            // An address from message content is only ever a web address: a file on this device is opened only
            // when the core's media cache returned it.
            let direct = safeExternalURL(source).flatMap(URL.init(string:))
            guard let url = await messaging.resolveMediaDisplayURL(fileId: message.content?.mediaFileId, directURL: direct),
                  !Task.isCancelled, url.isFileURL || ["https", "http"].contains(url.scheme?.lowercased() ?? "") else { return }
            onOpenMedia(MediaPreview(kind: kind, url: url, title: title, message: message))
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

struct MessagePreviewSheet: View {
    let message: AppMessage

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: FlareDesign.Spacing.lg) {
                Capsule()
                    .fill(Color.black.opacity(0.12))
                    .frame(width: 36, height: 4)
                    .frame(maxWidth: .infinity)
                    .padding(.top, FlareDesign.Spacing.md)

                HStack(spacing: FlareDesign.Spacing.md) {
                    AvatarView(title: message.senderTitle, imageURL: message.senderAvatar, size: 38)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(message.senderTitle)
                            .font(.headline.weight(.bold))
                            .foregroundStyle(FlareDesign.textPrimary)
                        Text(message.content?.contentType.rawValue.replacingOccurrences(of: "_", with: " ") ?? "unknown")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(FlareDesign.textSecondary)
                    }
                    Spacer()
                }

                VStack(alignment: .leading, spacing: FlareDesign.Spacing.sm) {
                    Text(String(localized: "Message content"))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(FlareDesign.textSecondary)
                    Text(message.previewText)
                        .font(.body)
                        .foregroundStyle(FlareDesign.textPrimary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(FlareDesign.Spacing.md)
                        .background(FlareDesign.surfaceAlt)
                        .clipShape(RoundedRectangle(cornerRadius: FlareDesign.Radius.medium, style: .continuous))
                }

                VStack(alignment: .leading, spacing: FlareDesign.Spacing.sm) {
                    MessagePreviewMetaRow(title: String(localized: "Message ID"), value: message.serverId.isEmpty ? message.clientMsgId : message.serverId)
                    MessagePreviewMetaRow(title: String(localized: "Conversation"), value: message.conversationId)
                    MessagePreviewMetaRow(title: String(localized: "Seq"), value: message.seq == 0 ? "-" : String(message.seq))
                }
                .padding(FlareDesign.Spacing.md)
                .background(FlareDesign.surface)
                .clipShape(RoundedRectangle(cornerRadius: FlareDesign.Radius.large, style: .continuous))
            }
            .padding(.horizontal, FlareDesign.Spacing.lg)
            .padding(.bottom, FlareDesign.Spacing.xl)
        }
        .background(FlareDesign.appBackground)
    }
}

private struct MessagePreviewMetaRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: FlareDesign.Spacing.md) {
            Text(title)
                .font(.caption.weight(.bold))
                .foregroundStyle(FlareDesign.textSecondary)
                .frame(width: 62, alignment: .leading)
            Text(value)
                .font(.caption)
                .foregroundStyle(FlareDesign.textPrimary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// Long-press actions for one message: the kit `MessageActionSheetView`. The core decides what is
/// allowed (`domain::message_actions`) and the kit owns the standard actions' labels, icons and
/// groups; this asks the core, adds the one action the kit has no entry for, and dispatches.
///
/// This used to draw its own sheet (reaction strip, quick-action tiles, action rows) on top of a
/// Swift copy of the core's rules, and looked nothing like the kit sheet on the other platforms.
struct MessageActionSheetHost: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var messaging: MessagingViewModel
    let message: AppMessage
    var onDismiss: (() -> Void)?
    /// 保存: the chat saves the message to the download location and says how it went.
    var onSave: ((AppMessage) -> Void)?
    @State private var availability: FlareMessageActionAvailability?
    @State private var editDialogOpen = false
    @State private var editDraft = ""

    var body: some View {
        ScrollView {
            if let availability {
                MessageActionSheetView(
                    availability: availability,
                    actions: availability.canEdit && message.content?.contentType == .richText
                        ? [FlareMessageMenuEntry(id: "editRich", label: String(localized: "Edit rich text"), icon: "rich-text")]
                        : [],
                    onAction: dispatch,
                    onReact: react
                )
            }
        }
        // The kit sheet paints bgSecondary; the rest of the system sheet matches it.
        .background(FlareDesign.appBackground)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(.container, edges: [.horizontal, .bottom])
        .task(id: message.appStableId) {
            let answer = await messaging.actionAvailability(for: message)
            // Nothing allowed right now: no sheet beats an empty one.
            if answer == FlareMessageActionAvailability() { close() } else { availability = answer }
        }
        // 编辑消息：曾经点一下"编辑"就把原文替换成写死的 "Edited from iOS example"，
        // 没有任何输入入口 —— 用户的内容就这么没了。
        .alert("Edit message", isPresented: $editDialogOpen) {
            TextField("New message text", text: $editDraft)
            Button("Cancel", role: .cancel) {}
            Button("OK") {
                let text = editDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty else { return }
                runAndClose { await messaging.messageAction("edit", message: message, text: text) }
            }
        }
    }

    private func react(_ reaction: String) {
        runAndClose { await messaging.messageAction("react", message: message, reaction: reaction) }
    }

    private func dispatch(_ id: String) {
        switch id {
        case "reply":
            close()
            messaging.startReply(to: message)
        case "forward":
            runAndClose { await messaging.forwardMessage(message) }
        case "resend":
            runAndClose { await messaging.retry(message) }
        case "multiSelect":
            close()
            messaging.startMultiSelect(with: message)
        case "copy":
            close()
            PlatformClipboard.copy(message.previewText)
            Task { await messaging.noteMessageAction("message.copy", detail: "Copied \(message.appStableId)") }
        case "preview":
            close()
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 220_000_000)
                messaging.openMessagePreview(message)
            }
        case "edit":
            editDraft = message.previewText
            editDialogOpen = true
        case "save":
            close()
            onSave?(message)
        case "delete":
            runAndClose { await messaging.messageAction("deleteSelf", message: message) }
        default:
            // recall / mark / pin / pinSelf / unpin / editRich are message actions of the same name.
            runAndClose { await messaging.messageAction(id, message: message) }
        }
    }

    private func runAndClose(_ operation: @escaping () async -> Void) {
        close()
        Task { await operation() }
    }

    private func close() {
        if let onDismiss {
            onDismiss()
        } else {
            dismiss()
        }
    }
}

// PlatformClipboard now lives in Core/Platform/PlatformClipboard.swift.
