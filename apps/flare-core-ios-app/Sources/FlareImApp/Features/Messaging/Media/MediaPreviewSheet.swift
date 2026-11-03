import FlareCoreAppleSDK
import FlareIMUI
import AVFoundation
import AVKit
import SwiftUI

struct MediaPreview: Identifiable {
    enum Kind {
        case image
        case video
        case audio
    }

    let id = UUID()
    let kind: Kind
    /// A web address, or a file on this device that the SDK media cache returned (never one from content).
    let url: URL
    let title: String
    /// The message shown, for the download key; none offers no download key.
    var message: AppMessage? = nil
}

/// The kit image preview / video player over a system sheet, with the kit download key: it saves the message's
/// picture or video to the download location through the core, says it is saving, then where it went. The sheet
/// hosts its own toasts: the root's are underneath a system sheet.
struct MediaPreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @EnvironmentObject private var messaging: MessagingViewModel
    let preview: MediaPreview
    @State private var player: AVPlayer?
    @StateObject private var feedback = FlareFeedback()

    init(preview: MediaPreview) {
        self.preview = preview
        _player = State(initialValue: preview.kind == .image ? nil : AVPlayer(url: preview.url))
    }

    var body: some View {
        content.flareFeedbackHost(feedback)
    }

    @ViewBuilder
    private var content: some View {
        switch preview.kind {
        case .image:
            ImagePreviewView(
                show: true,
                imageSrc: preview.url.isFileURL ? preview.url.path : preview.url.absoluteString,
                alt: preview.title,
                onClose: { dismiss() },
                onDownload: download,
                // A file here is the picture's local copy, which the SDK media cache returned.
                allowLocalFile: preview.url.isFileURL
            )
        case .video, .audio:
            VideoPlayerView(
                show: true,
                videoSrc: preview.url.absoluteString,
                title: preview.title,
                player: AnyView(VideoPlayer(player: player)),
                onClose: { player?.pause(); dismiss() },
                onDownload: preview.kind == .video ? download : nil
            )
            .onDisappear { player?.pause() }
        }
    }

    /// The download key, when there is a message to save.
    private var download: (() -> Void)? {
        guard let message = preview.message else { return nil }
        return {
            // The core reports no progress for a save, so the kit's progress ring would sit at 0: a toast says
            // it is under way instead.
            MediaSaveFeedback.save(message, messaging: messaging, feedback: feedback, openURL: openURL)
        }
    }
}

/// How a save's outcome is said: where it went (with the Files app one tap away), or why it did not.
enum MediaSaveFeedback {
    /// Saves `message` through the core, saying it is saving, then how it went.
    @MainActor
    static func save(_ message: AppMessage, messaging: MessagingViewModel, feedback: FlareFeedback?,
                     openURL: OpenURLAction) {
        let dismissSaving = feedback?.toast(MediaSaveCopy.saving, variant: .loading, duration: 0)
        Task {
            let outcome = await messaging.saveToDevice(message)
            dismissSaving?()
            show(outcome, feedback: feedback, openURL: openURL)
        }
    }

    @MainActor
    static func show(_ outcome: MediaSaveOutcome, feedback: FlareFeedback?, openURL: OpenURLAction) {
        switch outcome {
        case let .saved(directory, _):
            let folder = DownloadLocationLabel.filesAppURL(directory)
            feedback?.toast(MediaSaveCopy.savedTo(DownloadLocationLabel.label(directory: directory)), tone: .success,
                            actionLabel: folder == nil ? nil : MediaSaveCopy.showInFolder,
                            action: folder.map { url -> () -> Void in { openURL(url) } })
        case let .failed(text):
            feedback?.toast(text, tone: .danger)
        }
    }
}
