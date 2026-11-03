import XCTest
@testable import FlareImApp

/// 用**服务端签好的 token** 连真实网关，跑通登录并确认连接建立。
///
/// 为什么不走 UI：模拟器上没有可靠的输入通道 —— `xcrun simctl` 没有点击/输入 API，
/// 而 256 字符的 JWT 在 Android 那边实测用 adb input text 只能落进 12~26 个字符。
/// 直接驱动会话层验证的是同一套客户端栈（Apple SDK + Rust 核心），而且可复跑。
///
/// 默认跳过。要跑就给三个环境变量——**别把 token 写进仓库**：
///   FLARE_E2E_WS_URL=ws://<host>/ws \
///   FLARE_E2E_TOKEN="$(ssh <server> mint_token.py <user>)" \
///   FLARE_E2E_USER=<user> swift test --filter RemoteTokenFlowTests
final class RemoteTokenFlowTests: XCTestCase {

    func testLoginWithServerIssuedToken() async throws {
        let env = ProcessInfo.processInfo.environment
        guard
            let wsUrl = env["FLARE_E2E_WS_URL"], !wsUrl.isEmpty,
            let token = env["FLARE_E2E_TOKEN"], !token.isEmpty,
            let userId = env["FLARE_E2E_USER"], !userId.isEmpty
        else {
            throw XCTSkip("未提供 FLARE_E2E_* 环境变量，跳过远端联通用例")
        }

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("flare-ios-remote-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        var draft = LoginDraft()
        draft.userId = userId
        draft.wsUrl = wsUrl
        draft.transportMode = .websocket
        // 关键：用服务端签好的 token，不碰本地签名密钥。
        // 若实现哪天回退成本地自签，占位密钥签出来的 token 服务端会直接验不过，
        // 这条用例就会红。
        draft.tokenOverride = token

        let session = AppSession()
        defer { Task { try? await session.dispose() } }

        _ = try await session.start(draft: draft, dataURL: root) { _ in }

        let current = await session.currentUserId
        XCTAssertEqual(current, userId, "登录后当前用户应当是 \(userId)")
    }
}
