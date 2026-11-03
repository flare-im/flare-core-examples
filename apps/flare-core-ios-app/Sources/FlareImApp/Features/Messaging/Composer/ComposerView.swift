import FlareCoreAppleSDK
import FlareIMUI
import AVFoundation
import AVKit
import SwiftUI
import UniformTypeIdentifiers

private enum ComposerPanel {
    case none
    case emoji
}

private enum ComposerMoreKind {
    case file, video, location, card, task, schedule, poll, link, miniProgram, topic, notification, announcement
}

struct ComposerView: View {
    @EnvironmentObject private var messaging: MessagingViewModel
    @EnvironmentObject private var environment: AppEnvironment
    @Binding var text: String
    let conversation: AppConversation
    var expandedInputHeight: CGFloat = 360
    @State private var panel: ComposerPanel = .none
    @State private var formDraft: ComposerFormDraft?
    // Layer 5：相册 / 文件选择由宿主适配器执行（Core/Platform/IosPlatformAdapter），
    // 这里只读能力决定入口存在与否、走原生还是走 fallback 表单。
    @Environment(\.flarePlatform) private var platform

    var body: some View {
        VStack(spacing: 0) {
            if messaging.runtimeStatus.isBlocking {
                StatusBannerView(text: messaging.lastError ?? messaging.runtimeStatus.productLabel, tone: .warning)
            }
            if panel == .emoji {
                FlareEmojiStickerPicker(emojiLabel: String(localized: "Default emoji"), onInsertEmoji: { text += "[\($0)]" }, onSendSticker: { packageId, stickerId in
                    panel = .none
                    Task { await messaging.buildAndSend(op: .createSticker, payload: ["stickerId": stickerId, "packageId": packageId]) }
                })
            }
            FlareIMUI.ComposerView(
                text: $text,
                placeholder: String(localized: "Send to \(conversation.appTitle)"),
                disabled: messaging.runtimeStatus.isBlocking,
                replyTo: messaging.replyTarget.map { FlareReplyTarget(senderName: $0.senderTitle, summary: $0.previewText) },
                onSend: { value in text = value; sendCurrentText() },
                onImage: platform.capabilities.imagePicker == .unsupported ? nil : {
                    if platform.capabilities.imagePicker == .supported {
                        Task { await pickAndSendMedia(video: false, operation: "composer.image") }
                    } else {
                        formDraft = ComposerFormDraft(kind: .imageFallback)
                    }
                },
                onSendRich: { value in Task { if !(await messaging.buildAndSend(op: .createRichDoc, payload: ["markdown": value])), text.isEmpty, messaging.selectedConversation?.conversationId == conversation.conversationId { text = value } } },
                onEmoji: { toggle(.emoji) },
                onCancelReply: { messaging.clearReplyTarget() },
                actions: composerActions,
                onAction: { action in
                    if let kind = actionKinds[action.id] { handleMoreItem(kind) }
                },
                enableVoice: true,
                onVoiceSend: { url, duration in
                    do {
                        let payload: [String: Any] = ["audioId": url.path, "sourcePath": url.path, "sourceUrl": url.absoluteString, "mimeType": "audio/wav", "durationMs": duration]
                        return await messaging.buildAndSend(op: .createAudio, payload: try await messaging.uploadAudioAttachmentPayload(payload))
                    } catch { return false }
                }
            ).id(conversation.conversationId)
        }
        .onChange(of: text) { value in Task { await messaging.setTyping(!value.isEmpty) } }
        .sheet(item: $formDraft) { draft in
            ComposerInputFormSheet(draft: draft, currentUserId: messaging.currentUserId) { payload in
                Task { await messaging.buildAndSend(op: draft.kind.op, payload: payload) }
            }
            .presentationDetents([.height(draft.kind.preferredSheetHeight), .large])
            .presentationDragIndicator(.visible)
        }
    }

    /// 能力决定入口：unsupported 的选择器不出现在更多面板里。
    private var visibleActionIds: Set<String> {
        var hidden: Set<String> = []
        if platform.capabilities.filePicker != .supported { hidden.insert("file") }
        if platform.capabilities.imagePicker == .unsupported { hidden.insert("video") }
        return Set(actionKinds.keys).subtracting(hidden)
    }

    private var actionKinds: [String: ComposerMoreKind] { ["file": .file, "video": .video, "location": .location, "card": .card, "task": .task, "schedule": .schedule, "poll": .poll, "link": .link, "miniProgram": .miniProgram, "topic": .topic, "notification": .notification, "announcement": .announcement] }
    private var composerActions: [FlareComposerAction] {
        [("file", "File", "file"), ("video", "Video", "video"), ("location", "Location", "location"), ("card", "Card", "card"), ("task", "Task", "check"), ("schedule", "Schedule", "calendar"), ("poll", "Vote", "poll"), ("link", "Link", "link"), ("miniProgram", "Mini program", "mini-app"), ("topic", "Topic", "tag"), ("notification", "Notification", "notification"), ("announcement", "Announcement", "announcement")]
            .filter { visibleActionIds.contains($0.0) }
            .map { FlareComposerAction(id: $0.0, label: NSLocalizedString($0.1, comment: ""), icon: $0.2) }
    }

    private func toggle(_ next: ComposerPanel) {
        panel = panel == next ? .none : next
    }

    private func sendCurrentText() {
        panel = .none
        let outbound = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !outbound.isEmpty else { return }
        if let replyTarget = messaging.replyTarget {
            Task {
                let sent = await messaging.sendReplyText(outbound, replyingTo: replyTarget)
                if !sent, text.isEmpty, messaging.selectedConversation?.conversationId == conversation.conversationId { text = outbound }
            }
            return
        }
        if let emojiKey = EmojiPresentation.lonePackKey(in: outbound) {
            Task {
                let sent = await messaging.buildAndSend(op: .createEmoji, payload: ["emoji": emojiKey])
                if !sent, text.isEmpty, messaging.selectedConversation?.conversationId == conversation.conversationId { text = outbound }
            }
        } else {
            Task {
                let sent = await messaging.sendText(outbound)
                if !sent, text.isEmpty, messaging.selectedConversation?.conversationId == conversation.conversationId { text = outbound }
            }
        }
    }

    private func handleMoreItem(_ kind: ComposerMoreKind) {
        switch kind {
        case .file:
            Task { await pickAndSendFile() }
        case .video:
            if platform.capabilities.imagePicker == .supported {
                Task { await pickAndSendMedia(video: true, operation: "composer.video") }
            } else {
                formDraft = ComposerFormDraft(kind: .video)
            }
        case .location:
            formDraft = ComposerFormDraft(kind: .location)
        case .card:
            formDraft = ComposerFormDraft(kind: .card)
        case .task:
            formDraft = ComposerFormDraft(kind: .task)
        case .schedule:
            formDraft = ComposerFormDraft(kind: .schedule)
        case .poll:
            formDraft = ComposerFormDraft(kind: .poll)
        case .link:
            formDraft = ComposerFormDraft(kind: .link)
        case .miniProgram:
            formDraft = ComposerFormDraft(kind: .miniProgram)
        case .topic:
            text = text.isEmpty ? String(localized: "#topic ") : "\(text) \(String(localized: "#topic "))"
        case .notification:
            formDraft = ComposerFormDraft(kind: .notification)
        case .announcement:
            formDraft = ComposerFormDraft(kind: .announcement)
        }
    }

    /// 走契约取一次选择：CANCELLED（含空选择 / 关闭）静默，其余错误码进 Lab 日志。
    private func settled(_ result: FlarePlatformResult<[FlarePickedFile]>, operation: String) -> FlarePickedFile? {
        switch result {
        case .success(let files):
            return files.first
        case .failure(let error):
            if error.code != .cancelled {
                environment.appendLab(operation, status: "error", detail: error.description)
            }
            return nil
        }
    }

    /// 相册：`video` 打开图片+视频，否则只图片；按返回的类型决定 createImage / createVideo。
    private func pickAndSendMedia(video: Bool, operation: String) async {
        guard let picked = settled(await platform.pickImages(FlarePickImagesOptions(video: video)), operation: operation) else { return }
        panel = .none
        do {
            if isVideo(picked) {
                await messaging.buildAndSend(op: .createVideo, payload: try await videoPayload(for: picked))
            } else {
                let payload = try await messaging.uploadImageAttachmentPayload(imagePayload(for: picked))
                await messaging.buildAndSend(op: .createImage, payload: payload)
            }
        } catch {
            environment.appendLab(operation, status: "error", detail: FlareFormatters.errorText(error))
        }
    }

    private func pickAndSendFile() async {
        guard let picked = settled(await platform.pickFiles(FlarePickFilesOptions()), operation: "composer.file") else { return }
        panel = .none
        guard let url = pickedURL(picked) else {
            environment.appendLab("composer.file", status: "error", detail: "picked file has no path")
            return
        }
        var payload: [String: Any] = [
            "fileId": url.deletingPathExtension().lastPathComponent,
            "fileName": picked.name,
            "url": url.absoluteString
        ]
        if let size = picked.size { payload["size"] = size }
        if let mimeType = picked.mimeType { payload["mimeType"] = mimeType }
        await messaging.buildAndSend(op: .createFile, payload: payload)
    }

    /// 适配器把选择物化成 composer 缓存里的文件，这里只读它。
    private func pickedURL(_ picked: FlarePickedFile) -> URL? {
        if let path = picked.path, !path.isEmpty { return URL(fileURLWithPath: path) }
        if let uri = picked.uri, let url = URL(string: uri), url.isFileURL { return url }
        return nil
    }

    private func isVideo(_ picked: FlarePickedFile) -> Bool {
        if let mimeType = picked.mimeType { return mimeType.hasPrefix("video/") }
        guard let url = pickedURL(picked), let type = UTType(filenameExtension: url.pathExtension) else { return false }
        return type.conforms(to: .movie)
    }

    private func imagePayload(for picked: FlarePickedFile) throws -> [String: Any] {
        guard let url = pickedURL(picked) else { throw ComposerPickError.noPath }
        let data = try Data(contentsOf: url)
        var payload: [String: Any] = [
            "imageId": url.deletingPathExtension().lastPathComponent,
            "localPath": url.path,
            "sourceUrl": url.absoluteString,
            "mimeType": picked.mimeType ?? "image/jpeg",
            "size": picked.size ?? data.count
        ]
        if let size = platformImageSize(data: data) {
            payload["width"] = size.width
            payload["height"] = size.height
        }
        return payload
    }

    private func videoPayload(for picked: FlarePickedFile) async throws -> [String: Any] {
        guard let url = pickedURL(picked) else { throw ComposerPickError.noPath }
        var payload: [String: Any] = [
            "videoId": url.deletingPathExtension().lastPathComponent,
            "description": url.lastPathComponent,
            "sourceUrl": url.absoluteString,
            "mimeType": picked.mimeType ?? "video/mp4"
        ]
        if let size = picked.size { payload["size"] = size }
        if let durationMs = await mediaDurationMs(url: url) { payload["durationMs"] = durationMs }
        return payload
    }
}

/// 选择结果没有可读路径时的本地错误（适配器保证有，这里只是不静默吞）。
private enum ComposerPickError: Error { case noPath }
