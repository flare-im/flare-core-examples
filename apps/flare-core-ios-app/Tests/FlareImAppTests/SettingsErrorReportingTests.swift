import XCTest

/// 用户动作失败必须让用户知道。
///
/// 缓存上限与清空缓存原本一律 `try?` 吞掉：点了什么都没发生，界面照样一片祥和，
/// 用户以为做成了。而这个 app 本来就有统一的 `environment.run` + `lastError`
/// + StatusBanner —— 机制在，只有这里绕过去了。
final class SettingsErrorReportingTests: XCTestCase {

    private var source: String {
        get throws {
            let root = URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .deletingLastPathComponent()
            return try String(
                contentsOf: root.appendingPathComponent(
                    "Sources/FlareImApp/Features/Settings/SettingsViewModel.swift"
                ),
                encoding: .utf8
            )
        }
    }

    func testCacheMutationsReportFailures() throws {
        let s = try source
        for action in ["setCacheMaxBytes", "clearCache"] {
            let start = s.range(of: "func \(action)")!.lowerBound
            let body = String(s[start...].prefix(420))
            XCTAssertTrue(
                body.contains("environment.run"),
                "\(action) 必须走统一上报，否则失败时用户毫不知情"
            )
            XCTAssertFalse(
                body.contains("try? await client.media"),
                "\(action) 不能再用 try? 吞掉失败"
            )
        }
    }

    func testReadOnlyStatsMayStayQuiet() throws {
        // 反向界定范围：读取失败静默降级是**对的**，不该被上面的规则误伤。
        let s = try source
        let start = s.range(of: "func refreshCacheStats")!.lowerBound
        let body = String(s[start...].prefix(260))
        XCTAssertTrue(
            body.contains("try? await client.media.getMediaCacheStats"),
            "读取用量失败不值得打扰用户，保持静默降级"
        )
    }
}
