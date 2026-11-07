import FlareCoreAppleSDK
import Foundation
import XCTest
@testable import FlareImApp

/// Answers every call with an empty object.
private final class AnsweringBridge: NativeBridgeProtocol, @unchecked Sendable {
    private let lock = NSLock()
    private var operations: [String] = []

    func invoke(_ descriptor: NativeCallDescriptor, request: AnySendable?) async throws -> AnySendable {
        lock.lock()
        operations.append(descriptor.operation)
        lock.unlock()
        return AnySendable([String: Any]())
    }

    func count(_ descriptor: NativeCallDescriptor) -> Int {
        lock.lock()
        defer { lock.unlock() }
        return operations.filter { $0 == descriptor.operation }.count
    }
}

private final class CountingFactory: SdkClientFactory, @unchecked Sendable {
    let bridge = AnsweringBridge()
    private let lock = NSLock()
    private var made = 0

    var created: Int {
        lock.lock()
        defer { lock.unlock() }
        return made
    }

    func makeClient(libraryPath: String?) throws -> any FlareImClientProtocol {
        lock.lock()
        made += 1
        lock.unlock()
        return DefaultFlareImClient(bridge: bridge)
    }
}

/// The update center and the network page read through ``AppSession/accessClient(draft:dataURL:)``, before any sign-in
/// and during one.
@MainActor
final class AppSessionAccessClientTests: XCTestCase {
    private let dataURL = URL(fileURLWithPath: "/tmp/flare-core-ios-app")
    private var factory: CountingFactory!
    private var session: AppSession!

    override func setUp() async throws {
        factory = CountingFactory()
        session = AppSession(clientFactory: factory, access: AppAccess(access: ["trustMode": "development"]))
    }

    func testReadsShareOneClient() async throws {
        let first = try await session.accessClient(draft: LoginDraft(), dataURL: dataURL)
        let second = try await session.accessClient(draft: LoginDraft(), dataURL: dataURL)

        XCTAssertTrue(first === second)
        XCTAssertEqual(factory.created, 1)
        XCTAssertEqual(factory.bridge.count(NativeCallMap.sdkInit), 1)
    }

    /// The first read of the update center and the network page can start together: `init` runs once.
    func testASecondReadWaitsForTheBringUpUnderWay() async throws {
        let session = self.session!
        let url = dataURL
        let first = Task { _ = try await session.accessClient(draft: LoginDraft(), dataURL: url) }
        let second = Task { _ = try await session.accessClient(draft: LoginDraft(), dataURL: url) }

        try await first.value
        try await second.value

        XCTAssertEqual(factory.created, 1)
        XCTAssertEqual(factory.bridge.count(NativeCallMap.sdkInit), 1)
    }

    func testASignInContinuesOnTheClientAReadBroughtUp() async throws {
        let read = try await session.accessClient(draft: LoginDraft(), dataURL: dataURL)

        let signedIn = try await session.start(draft: LoginDraft(), dataURL: dataURL) { _ in }

        XCTAssertTrue(read === signedIn)
        XCTAssertEqual(factory.created, 1)
        XCTAssertEqual(factory.bridge.count(NativeCallMap.sdkInit), 1)
        XCTAssertEqual(factory.bridge.count(NativeCallMap.sdkLogin), 1)
    }

    func testAReadAfterSignInUsesTheSignedInClient() async throws {
        let signedIn = try await session.start(draft: LoginDraft(), dataURL: dataURL) { _ in }

        let read = try await session.accessClient(draft: LoginDraft(), dataURL: dataURL)

        XCTAssertTrue(signedIn === read)
        XCTAssertEqual(factory.created, 1)
    }

    /// Another tenant is another core: what a read brought up cannot serve it.
    func testASignInForAnotherTenantGetsItsOwnClient() async throws {
        let read = try await session.accessClient(draft: LoginDraft(), dataURL: dataURL)
        var other = LoginDraft()
        other.tenantId = "tenant-other"

        let signedIn = try await session.start(draft: other, dataURL: dataURL) { _ in }

        XCTAssertFalse(read === signedIn)
        XCTAssertEqual(factory.created, 2)
    }
}
