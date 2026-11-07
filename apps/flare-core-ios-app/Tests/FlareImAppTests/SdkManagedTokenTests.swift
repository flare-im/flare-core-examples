import XCTest
@testable import FlareImApp

/// 客户端不再本地签发接入 token（那等于把签名密钥打进 App）。
/// SDK 托管：init 只交 `"auth": {}`，核心在当前接入点的 Core API 上签发与换新，login 不传 token；
/// 粘贴的 token 原样交给 login。
final class SdkManagedTokenTests: XCTestCase {
    func testInitConfigAsksForSdkManagedTokensAndLoginOmitsTokenByDefault() throws {
        var draft = LoginDraft()
        draft.userId = "hugo"
        for access in [try AppAccess.resolve(lookup: { _ in nil }, allowDevelopment: true),
                       AppAccess(access: ["trustMode": "production"])] {
            let config = AppSession.sessionInitConfig(draft: draft, dataURL: URL(fileURLWithPath: "/tmp/x"), access: access)
            let auth = try XCTUnwrap(config["auth"]?.value as? [String: Any], "every build asks for SDK-managed tokens")
            XCTAssertTrue(auth.isEmpty, "no endpoint of its own: the SDK issues on the access point's Core API")
        }

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
