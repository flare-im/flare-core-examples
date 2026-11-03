import FlareCoreAppleSDK
import AVFoundation
import AVKit
import SwiftUI

private enum ComposerMediaError: LocalizedError {
    case microphonePermissionDenied
    case recordingDidNotStart
    case missingRecording

    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return String(localized: "Microphone access is off; cannot record")
        case .recordingDidNotStart:
            return String(localized: "Failed to start recording")
        case .missingRecording:
            return String(localized: "No recording to send")
        }
    }
}

@MainActor
final class ComposerAudioRecorder: ObservableObject {
    static let maximumDuration: TimeInterval = 65

    @Published private(set) var isRecording = false
    @Published private(set) var elapsedTime: TimeInterval = 0

    private var recorder: AVAudioRecorder?
    private var recorderTimer: Timer?
    private var currentId: String?
    private var currentURL: URL?

    func start() async throws {
        guard !isRecording else { return }
        guard await PlatformAudioSession.requestMicrophonePermission() else {
            throw ComposerMediaError.microphonePermissionDenied
        }
        try PlatformAudioSession.activateForRecording()

        let id = "local-audio-\(UUID().uuidString)"
        let url = try composerMediaDirectory().appendingPathComponent("\(id).m4a")
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 48_000,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 96_000,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        let nextRecorder = try AVAudioRecorder(url: url, settings: settings)
        nextRecorder.isMeteringEnabled = true
        nextRecorder.prepareToRecord()
        guard nextRecorder.record(forDuration: Self.maximumDuration) else {
            throw ComposerMediaError.recordingDidNotStart
        }

        recorder = nextRecorder
        currentId = id
        currentURL = url
        elapsedTime = 0
        isRecording = true
        startTimer()
    }

    func finish() throws -> [String: Any]? {
        guard let recorder, let currentId, let currentURL else {
            throw ComposerMediaError.missingRecording
        }
        let duration = min(recorder.currentTime, Self.maximumDuration)
        let durationMs = max(1, Int((duration * 1000).rounded()))
        recorder.stop()
        stopTimer()
        isRecording = false
        elapsedTime = 0
        self.recorder = nil
        self.currentId = nil
        self.currentURL = nil
        PlatformAudioSession.deactivate()

        let values = try currentURL.resourceValues(forKeys: [.fileSizeKey])
        var payload: [String: Any] = [
            "audioId": currentId,
            "description": String(localized: "Voice message"),
            "localPath": currentURL.path,
            "sourceUrl": currentURL.absoluteString,
            "mimeType": "audio/mp4",
            "durationMs": durationMs
        ]
        if let size = values.fileSize {
            payload["size"] = size
        }
        return payload
    }

    func cancel() {
        recorder?.stop()
        if let currentURL {
            try? FileManager.default.removeItem(at: currentURL)
        }
        stopTimer()
        recorder = nil
        currentId = nil
        currentURL = nil
        elapsedTime = 0
        isRecording = false
        PlatformAudioSession.deactivate()
    }

    private func startTimer() {
        stopTimer()
        recorderTimer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.recorder?.updateMeters()
                self.elapsedTime = min(self.recorder?.currentTime ?? 0, Self.maximumDuration)
            }
        }
    }

    private func stopTimer() {
        recorderTimer?.invalidate()
        recorderTimer = nil
    }

}
