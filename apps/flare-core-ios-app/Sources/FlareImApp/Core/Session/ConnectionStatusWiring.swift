import FlareCoreAppleSDK
import FlareIMUI

extension FlareConnectionStatus {
    /// The connection notice's input for the core SDK's `connection://status`, field for field. The two sides name the
    /// phases the same (`spec/connection-notice-vectors.json`); the reason goes through as the SDK wrote it, and the kit
    /// explains only the actionRequired ones.
    init(_ status: ConnectionStatus) {
        self.init(phase: FlareConnectionPhase(rawValue: status.phase.rawValue) ?? .idle,
                  quality: status.quality.flatMap { FlareConnectionQuality(rawValue: $0.rawValue) },
                  nextRetryAt: status.nextRetryAt, attempt: Int(status.attempt),
                  reason: status.reason, developmentMode: status.developmentMode)
    }
}
