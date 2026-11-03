import AVFoundation

/// The single place that bridges the recording audio-session lifecycle.
/// `AVAudioSession` is iOS-only, so every method is a no-op on macOS.
enum PlatformAudioSession {
    /// Configures and activates the shared session for voice recording.
    static func activateForRecording() throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: [.defaultToSpeaker, .allowBluetoothHFP])
        try session.setActive(true, options: [])
        #endif
    }

    /// Configures and activates the shared session for voice-message playback.
    static func activateForPlayback() throws {
        #if os(iOS)
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try session.setActive(true, options: [])
        #endif
    }

    /// Deactivates the shared session, notifying others (best-effort).
    static func deactivate() {
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: [.notifyOthersOnDeactivation])
        #endif
    }

    /// Requests microphone permission. Returns `true` immediately on platforms
    /// that don't gate recording behind `AVAudioSession`.
    static func requestMicrophonePermission() async -> Bool {
        #if os(iOS)
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        #else
        return true
        #endif
    }
}
