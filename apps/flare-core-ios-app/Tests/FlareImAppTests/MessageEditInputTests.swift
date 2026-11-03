import XCTest

/// 编辑消息必须用**用户输入的正文**，不能写死占位串。
///
/// 钉的是源码形态：真正的失败要在真机上点"编辑"、看着自己的消息变成
/// "Edited from iOS example" 才暴露，而那时用户的内容已经没了。
/// Android 上是同一处缺陷，两端一起修的。
final class MessageEditInputTests: XCTestCase {

    private func source(_ relativePath: String) throws -> String {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // FlareImAppTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // 包根
        return try String(contentsOf: root.appendingPathComponent(relativePath), encoding: .utf8)
    }

    func testEditActionUsesCallerSuppliedText() throws {
        let vm = try source("Sources/FlareImApp/Features/Messaging/MessagingViewModel.swift")
        XCTAssertFalse(
            vm.contains(#""text": AnySendable("Edited from iOS"#),
            "编辑写死占位串等于把用户的原文删了"
        )
        XCTAssertTrue(
            vm.contains(#""text": AnySendable(text)"#),
            "编辑必须用调用方传入的正文"
        )
    }

    func testEditMenuOpensAnInput() throws {
        let row = try source("Sources/FlareImApp/Features/Messaging/MessageRow/MessageRowViews.swift")
        XCTAssertTrue(row.contains("editDialogOpen"), "编辑必须有输入入口")
        XCTAssertTrue(
            row.contains(#"messageAction("edit", message: message, text:"#),
            "输入框确认后要把正文传下去"
        )
    }
}
