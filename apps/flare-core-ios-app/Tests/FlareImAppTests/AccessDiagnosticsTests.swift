import FlareCoreAppleSDK
import FlareIMUI
import XCTest
@testable import FlareImApp

private struct Refused: Error {}

private final class FakeAccess: AccessApiProtocol, @unchecked Sendable {
    var serial: UInt64 = 7
    var links: [String] = []
    var pins: [String] = []
    var imported = AccessRecoveryImport(outcome: "adopted", serial: 9)
    var failing: Set<String> = []

    private func check(_ op: String) throws { if failing.contains(op) { throw Refused() } }

    func getStatus() async throws -> AccessStatus { AccessStatus(loaded: true, serial: serial) }
    func listAccessPoints() async throws -> [AccessPointInfo] {
        [AccessPointInfo(accessPointId: "ap-a", status: "active", breaker: "closed", current: true)]
    }
    func pin(_ request: AccessPinRequest) async throws -> AccessPin {
        try check("pin")
        pins.append(request.accessPointId)
        return AccessPin(accessPointId: request.accessPointId)
    }
    func unpin() async throws {}
    func refresh() async throws -> AccessRefreshReport {
        try check("refresh")
        return AccessRefreshReport(outcome: "upToDate")
    }
    func importRecovery(_ request: AccessImportRecoveryRequest) async throws -> AccessRecoveryImport {
        links.append(request.link)
        try check("import")
        return imported
    }
    func exportDiagnostics() async throws -> [String: AnySendable] {
        try check("export")
        return ["status": AnySendable(["serial": AnySendable(7)])]
    }
}

@MainActor
final class AccessDiagnosticsTests: XCTestCase {
    private func host(_ core: FakeAccess, clipboard: @escaping (String) -> Void = { _ in }) -> AccessDiagnostics {
        AccessDiagnostics(access: { core }, subscribeLinkEvents: { _ in {} }, writeClipboard: clipboard)
    }

    func testKeepsARecoveryLinkAsItArrivedAndLeavesOtherLinksAlone() {
        XCTAssertEqual(parseRecoveryLink(" flare-recover://v1?p=aB-_&k=root&s=c2ln "), "flare-recover://v1?p=aB-_&k=root&s=c2ln")
        XCTAssertNil(parseRecoveryLink(nil))
        XCTAssertNil(parseRecoveryLink("https://example.com/flare-recover://v1"))
    }

    func testTheSdkResultsReachTheKitFieldForField() {
        let status = FlareAccessStatus(AccessStatus(
            loaded: true, serial: 42, source: "recovery", stale: true, developmentMode: true, regionId: "cn-east",
            accessPointId: "ap-a", protocol: "quic",
            connectAck: AccessConnectAck(accessPointId: "ap-b", accessPointMismatch: true),
            recovering: AccessRecoveringStatus(sinceMs: 1, rounds: 2, nextRoundAtMs: 1000)))
        XCTAssertEqual(status, FlareAccessStatus(
            loaded: true, serial: 42, source: "recovery", stale: true, developmentMode: true, regionId: "cn-east",
            accessPointId: "ap-a", protocol: "quic",
            connectAck: FlareAccessConnectAck(accessPointId: "ap-b", accessPointMismatch: true),
            recovering: FlareAccessRecovering(rounds: 2, nextRoundAtMs: 1000)))
        XCTAssertEqual(
            FlareAccessPoint(AccessPointInfo(accessPointId: "ap-a", status: "draining", rttMs: 12.5, breaker: "open", pinned: true, current: true)),
            FlareAccessPoint(accessPointId: "ap-a", status: "draining", rttMs: 12.5, breaker: "open", pinned: true, current: true))
    }

    func testFollowsLinkEventsUntilStopped() async {
        let core = FakeAccess()
        var notify: (@Sendable () -> Void)?
        var stopped = 0
        let page = AccessDiagnostics(access: { core }, subscribeLinkEvents: { handler in
            notify = handler
            return { stopped += 1 }
        })
        await page.follow()
        XCTAssertEqual(page.status?.serial, 7)
        XCTAssertEqual(page.accessPoints.map(\.accessPointId), ["ap-a"])

        core.serial = 8
        notify?()
        for _ in 0..<50 where page.status?.serial != 8 { try? await Task.sleep(nanoseconds: 1_000_000) }
        XCTAssertEqual(page.status?.serial, 8)

        page.stop()
        XCTAssertEqual(stopped, 1)
    }

    func testARefusedPinIsSaidAndTheDirectoryReadAgain() async {
        let core = FakeAccess()
        let page = host(core)
        await page.pin("ap-a")
        XCTAssertEqual(core.pins, ["ap-a"])
        XCTAssertFalse(page.pinRefused)

        core.failing = ["pin"]
        core.serial = 8
        await page.pin("ap-gone")
        XCTAssertTrue(page.pinRefused)
        XCTAssertEqual(page.status?.serial, 8)
    }

    func testARefreshFillsItsOutcomeAndAThrowReadsFailed() async {
        let core = FakeAccess()
        let page = host(core)
        await page.refresh()
        XCTAssertEqual(page.refreshOutcome, "upToDate")

        core.failing = ["refresh"]
        await page.refresh()
        XCTAssertEqual(page.refreshOutcome, "failed")
        XCTAssertFalse(page.refreshing)
    }

    func testARejectedLinkCarriesItsCodeBackToThePage() async {
        let core = FakeAccess()
        core.imported = AccessRecoveryImport(outcome: "rejected", code: "rollback", serial: 7)
        let page = host(core)
        await page.importRecovery("flare-recover://v1?p=a&k=b&s=c")
        XCTAssertEqual(core.links, ["flare-recover://v1?p=a&k=b&s=c"])
        XCTAssertEqual(page.importOutcome, "rejected")
        XCTAssertEqual(page.importCode, "rollback")
    }

    func testAnImportThatThrowsIsNotSilent() async {
        let core = FakeAccess()
        core.failing = ["import"]
        let page = host(core)
        await page.importRecovery("flare-recover://x")
        XCTAssertEqual(page.importOutcome, "rejected")
        XCTAssertNil(page.importCode)
        XCTAssertFalse(page.importing)
    }

    func testAnOpenedLinkShowsThePageAndImports() async {
        let page = host(FakeAccess())
        page.openRecoveryLink("flare-recover://x")
        XCTAssertTrue(page.presented)
        for _ in 0..<50 where page.importOutcome == nil { try? await Task.sleep(nanoseconds: 1_000_000) }
        XCTAssertEqual(page.importOutcome, "adopted")
    }

    func testTheDiagnosticsGoToTheClipboardAsJson() async {
        let core = FakeAccess()
        var copied: [String] = []
        let page = host(core) { copied.append($0) }
        await page.exportDiagnostics()
        XCTAssertEqual(page.exportOutcome, "copied")
        XCTAssertTrue(copied.first?.contains("\"serial\" : 7") == true)

        core.failing = ["export"]
        await page.exportDiagnostics()
        XCTAssertEqual(page.exportOutcome, "failed")
        XCTAssertFalse(page.exporting)
    }
}
