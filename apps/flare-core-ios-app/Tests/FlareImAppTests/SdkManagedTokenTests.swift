import XCTest
@testable import FlareImApp

/// 客户端不再本地签发接入 token（那等于把签名密钥打进 App）。
/// SDK 托管：init 把网关地址交给核心（auth.tokenEndpoint），login 不传 token；
/// 应用托管：高级区粘贴 token 原样传。
final class SdkManagedTokenTests: XCTestCase {
    func testInitConfigHandsGatewayToCoreAndLoginOmitsTokenByDefault() {
        var draft = LoginDraft()
        draft.userId = "hugo"
        draft.httpUrl = " http://h/api "
        let config = AppSession.sessionInitConfig(draft: draft, dataURL: URL(fileURLWithPath: "/tmp/x"))
        XCTAssertEqual(config["httpUrl"]?.value as? String, "http://h/api")
        let auth = config["auth"]?.value as? [String: Any]
        XCTAssertEqual(auth?["tokenEndpoint"] as? String, "http://h/api")

        let login = AppSession.loginRequest(draft: draft)
        XCTAssertEqual(login["userId"]?.value as? String, "hugo")
        XCTAssertNil(login["token"], "没粘贴 token 时不能传空 token，让核心向网关签发")
    }

    func testPastedTokenIsPassedThrough() {
        var draft = LoginDraft()
        draft.userId = "hugo"
        draft.tokenOverride = " eyJ.paste "
        XCTAssertEqual(AppSession.loginRequest(draft: draft)["token"]?.value as? String, "eyJ.paste")
    }

    func testNoLocalMintingSurfacesRemain() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        for rel in ["Sources/FlareImApp/Core/Session/AppSession.swift", "Sources/FlareImApp/Core/Domain/AppModels.swift", "Sources/FlareImApp/Features/Auth/LoginView.swift"] {
            let src = try String(contentsOf: root.appendingPathComponent(rel), encoding: .utf8)
            XCTAssertFalse(src.contains("generateCoreToken"), rel)
            XCTAssertFalse(src.contains("tokenSecret"), rel)
        }
    }
}
