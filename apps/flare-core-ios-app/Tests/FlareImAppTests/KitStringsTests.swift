import FlareIMUI
import XCTest
@testable import FlareImApp

final class KitStringsTests: XCTestCase {
    func testLocaleUsesCompleteKitPresetWithAppWording() {
        let chinese = KitStrings.forLanguage("zh-Hans")
        let english = KitStrings.forLanguage("en-US")
        XCTAssertEqual(chinese.send, FlareStrings().send)
        XCTAssertEqual(english.send, FlareStrings.english.send)
        XCTAssertEqual(english.actionImage, "Image")
        XCTAssertEqual(english.packetFromSender("Alice"), FlareStrings.english.packetFromSender("Alice"))
        XCTAssertEqual(KitStrings.forLanguage("fr").send, english.send)
    }

    func testHostOverridesDoNotMutateCachedPresets() {
        var custom = KitStrings.forLanguage("en")
        custom.send = "Deliver"
        custom.packetFromSender = { "From \($0)" }
        XCTAssertEqual(custom.send, "Deliver")
        XCTAssertEqual(custom.packetFromSender("Alice"), "From Alice")
        XCTAssertEqual(KitStrings.forLanguage("en").send, "Send")
        XCTAssertEqual(KitStrings.forLanguage("en").packetFromSender("Alice"), FlareStrings.english.packetFromSender("Alice"))
        XCTAssertEqual(KitStrings.forLanguage("zh").send, "发送")
    }
}
