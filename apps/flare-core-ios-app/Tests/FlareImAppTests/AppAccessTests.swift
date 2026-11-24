import FlareCoreAppleSDK
import FlareIMUI
import XCTest
@testable import FlareImApp

/// The access configuration a build starts the SDK with (``AppEndpoints``), and how the SDK's connection status reaches
/// the kit notice.
final class AppEndpointsTests: XCTestCase {
    private func lookup(_ values: [String: String]) -> (String) -> String? { { values[$0] } }

    func testLocalEndpoints() throws {
        let config = try AppEndpoints.resolve(lookup: lookup([:]), allowDevelopment: true)
        XCTAssertEqual(config.environment, "development")
        XCTAssertEqual(config.endpoints["baseUrl"] as? String, "http://127.0.0.1:50050")
        XCTAssertEqual(config.endpoints["websocketUrl"] as? String, "ws://127.0.0.1:60051")
    }

    func testReleaseRequiresEndpoints() {
        XCTAssertThrowsError(try AppEndpoints.resolve(lookup: lookup([:]), allowDevelopment: false))
    }

    func testTheKitReadsTheCoreStatusFieldForField() {
        let reconnecting = ConnectionStatus(phase: .reconnecting, attempt: 2, nextRetryAt: 1_762_250_000_000,
                                            developmentMode: true)
        XCTAssertEqual(FlareConnectionStatus(reconnecting),
                       FlareConnectionStatus(phase: .reconnecting, nextRetryAt: 1_762_250_000_000, attempt: 2,
                                             developmentMode: true))
        XCTAssertEqual(FlareConnectionStatus(ConnectionStatus(phase: .online, quality: .poor)).quality, .poor)
        let switching = FlareConnectionStatus(ConnectionStatus(phase: .switching, reason: "failback"))
        XCTAssertEqual(switching.reason, "failback")
        XCTAssertNil(switching.actionReason)
        let expired = FlareConnectionStatus(ConnectionStatus(phase: .actionRequired, reason: "expired"))
        XCTAssertEqual(expired.phase, .actionRequired)
        XCTAssertEqual(expired.actionReason, .expired)
        for phase in ["idle", "connecting", "syncing", "online", "switching", "reconnecting", "waitingForNetwork",
                      "serviceUnavailable", "actionRequired"] {
            let core = ConnectionPhase(rawValue: phase)
            XCTAssertNotNil(core, phase)
            XCTAssertEqual(core.map { FlareConnectionStatus(ConnectionStatus(phase: $0)).phase.rawValue }, phase)
        }
    }
}
