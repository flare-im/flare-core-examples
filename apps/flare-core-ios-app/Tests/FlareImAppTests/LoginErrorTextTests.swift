import XCTest
@testable import FlareImApp

/// 网关拒掉 token 时核心报的是一长串传输层错误；登录页要换成「核对签名密钥」。
/// 判据与 web kit / Android / Flutter 一致。
final class LoginErrorTextTests: XCTestCase {
    func testAuthenticationFailedIsTokenRejected() {
        XCTAssertTrue(LoginErrorText.isTokenRejected(
            "错误 [AUTHENTICATION_FAILED] connect failed primary=ws://x/ws: TOKEN_REJECTED: server closed the connection before CONNECT_ACK"))
        XCTAssertTrue(LoginErrorText.isTokenRejected("TOKEN_REJECTED: x"))
    }

    func testConnectionFailureIsNotTokenRejected() {
        let raw = "错误 [CONNECTION_FAILED] Negotiation timeout after 10s (CONNECT_ACK not received)"
        XCTAssertFalse(LoginErrorText.isTokenRejected(raw))
        XCTAssertEqual(LoginErrorText.display(raw), raw, "连不上服务器保持原文")
    }

    func testDisplayReplacesRejectedTokenText() {
        let shown = LoginErrorText.display("错误 [AUTHENTICATION_FAILED] TOKEN_REJECTED: x")
        XCTAssertFalse(shown.contains("TOKEN_REJECTED"))
        XCTAssertTrue(shown.lowercased().contains("secret") || shown.contains("签名密钥"))
    }
}
