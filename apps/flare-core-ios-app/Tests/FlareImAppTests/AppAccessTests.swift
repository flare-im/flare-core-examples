import FlareCoreAppleSDK
import FlareIMUI
import XCTest
@testable import FlareImApp

/// The access configuration a build starts the SDK with (``AppAccess``), and how the SDK's connection status reaches
/// the kit notice.
final class AppAccessTests: XCTestCase {
    private func lookup(_ values: [String: String]) -> (String) -> String? { { values[$0] } }

    func testADebugBuildRunsOnTheLocalStackByDefault() throws {
        let resolved = try AppAccess.resolve(lookup: lookup([:]), allowDevelopment: true)
        XCTAssertEqual(resolved.access["trustMode"] as? String, "development")
        let endpoints = try XCTUnwrap(resolved.access["developmentEndpoints"] as? [String: Any])
        XCTAssertEqual(endpoints["wsUrl"] as? String, "ws://127.0.0.1:60051")
        XCTAssertEqual(endpoints["coreApiUrl"] as? String, "http://127.0.0.1:50050")
        XCTAssertEqual(endpoints["mediaUrl"] as? String, "http://127.0.0.1:50050")
        XCTAssertNil(endpoints["quicUrl"], "QUIC only when an address is given")
    }

    func testTheDevelopmentEndpointsComeFromTheBuildSettings() throws {
        let resolved = try AppAccess.resolve(lookup: lookup([
            "FLARE_DEV_WS_URL": "ws://10.1.2.3:60051",
            "FLARE_DEV_QUIC_URL": "quic://10.1.2.3:60052",
            "FLARE_DEV_CORE_API_URL": "http://10.1.2.3:50050",
        ]), allowDevelopment: true)
        let endpoints = try XCTUnwrap(resolved.access["developmentEndpoints"] as? [String: Any])
        XCTAssertEqual(endpoints["wsUrl"] as? String, "ws://10.1.2.3:60051")
        XCTAssertEqual(endpoints["quicUrl"] as? String, "quic://10.1.2.3:60052")
        XCTAssertEqual(endpoints["mediaUrl"] as? String, "http://10.1.2.3:50050", "media follows Core HTTP")
    }

    func testAWholeAccessObjectIsTakenAsGiven() throws {
        let json = #"{"trustMode":"development","developmentEndpoints":{"wsUrl":"ws://127.0.0.1:60051","coreApiUrl":"http://127.0.0.1:50050","accessPoints":[{"id":"dev-b","wsUrl":"ws://127.0.0.1:61051"}]}}"#
        let resolved = try AppAccess.resolve(lookup: lookup(["FLARE_ACCESS_JSON": json, "FLARE_DEV_WS_URL": "ws://x"]),
                                             allowDevelopment: true)
        let endpoints = try XCTUnwrap(resolved.access["developmentEndpoints"] as? [String: Any])
        XCTAssertEqual(endpoints["wsUrl"] as? String, "ws://127.0.0.1:60051", "the whole object wins over single keys")
        XCTAssertEqual((endpoints["accessPoints"] as? [[String: Any]])?.first?["id"] as? String, "dev-b")
        XCTAssertThrowsError(try AppAccess.resolve(lookup: lookup(["FLARE_ACCESS_JSON": "[1]"]), allowDevelopment: true))
    }

    func testAReleaseBuildNeedsItsProductionAccessAndNeverFallsBackToDevelopment() throws {
        XCTAssertThrowsError(try AppAccess.resolve(lookup: lookup([:]), allowDevelopment: false))
        XCTAssertThrowsError(try AppAccess.resolve(lookup: lookup(["FLARE_DEV_WS_URL": "ws://127.0.0.1:60051"]),
                                                   allowDevelopment: false))
        XCTAssertThrowsError(try AppAccess.resolve(
            lookup: lookup(["FLARE_ACCESS_JSON": #"{"trustMode":"development","developmentEndpoints":{}}"#]),
            allowDevelopment: false))
        let production = #"{"bootstrapId":"flare-im","trustRoots":[],"seed":"{}","trustMode":"production"}"#
        let resolved = try AppAccess.resolve(lookup: lookup(["FLARE_ACCESS_JSON": production]), allowDevelopment: false)
        XCTAssertEqual(resolved.access["bootstrapId"] as? String, "flare-im")
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
