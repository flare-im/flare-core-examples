import XCTest
@testable import FlareImApp

/// iOS 作为**接收端**：另一端发的消息必须经 Apple SDK 的事件通道到达。
///
/// 与 RemoteTokenFlowTests 的区别：那条只证明能登录。这条验证的是
/// **绑定层**（Apple SDK over C FFI）是否把实时消息正确透上来 ——
/// 跨端互通用例两端都跑在 Rust 核心上，覆盖不到各端各自的绑定。
///
/// 需要本机有 FFI 产物（SIP 会剥掉 DYLD_LIBRARY_PATH，只能放进 Frameworks/）：
///   cargo build --release -p flare-im-core-sdk-ffi
///   cp target/release/libflare_im_core_sdk_ffi.dylib examples/flare-core-ios-app/Frameworks/
///
/// 默认跳过。要跑：
///   FLARE_E2E_WS_URL=ws://<host>/ws FLARE_E2E_TOKEN=... FLARE_E2E_USER=...
///   FLARE_E2E_TAG=<发送端写进正文的标记> swift test --filter RemoteRealtimeReceiveTests
final class RemoteRealtimeReceiveTests: XCTestCase {

    func testReceivesRealtimeMessageFromAnotherClient() async throws {
        let env = ProcessInfo.processInfo.environment
        guard
            let wsUrl = env["FLARE_E2E_WS_URL"], !wsUrl.isEmpty,
            let token = env["FLARE_E2E_TOKEN"], !token.isEmpty,
            let userId = env["FLARE_E2E_USER"], !userId.isEmpty,
            let tag = env["FLARE_E2E_TAG"], !tag.isEmpty
        else {
            throw XCTSkip("未提供 FLARE_E2E_* 环境变量，跳过接收端用例")
        }

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("flare-ios-recv-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        var draft = LoginDraft()
        draft.userId = userId
        draft.wsUrl = wsUrl
        draft.transportMode = .websocket
        draft.tokenOverride = token

        let session = AppSession()
        defer { Task { try? await session.dispose() } }
        let client = try await session.start(draft: draft, dataURL: root) { _ in }

        let received = expectation(description: "收到带标记的实时消息")
        // 只认批量：批量是规范路径，逐条回调对聊天消息不触发。
        let subscription = client.events.onMessageReceivedBatch { event in
            for message in event.messages
            where String(describing: message).contains(tag) {
                received.fulfill()
                return
            }
        }
        defer { subscription.unsubscribe() }

        // 冷启首屏同步：本地库是空的，不先同步就收不到会话上下文。
        try? await client.sync.syncConversationSummaries()

        // ⚠️ 不能用 print 做就绪信号：swift test 的管道输出里看不到它，
        // 外部编排会一直等一个永不出现的信号。写文件是可观测的。
        if let readyPath = env["FLARE_E2E_READY_FILE"] {
            try? "ready \(tag)".write(toFile: readyPath, atomically: true, encoding: .utf8)
        }
        print("IOS_LISTENER_READY tag=\(tag)")
        await fulfillment(of: [received], timeout: 300)
    }
}
