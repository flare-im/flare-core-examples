import FlareIMUI
import UniformTypeIdentifiers
import XCTest
@testable import FlareImApp

/// Layer 5（spec/platform-contract.json）宿主侧：声明的能力必须等于真正能执行的操作，
/// accept 列表必须映射成 iOS 的内容类型，取消/空选择只能是 CANCELLED。
final class IosPlatformAdapterTests: XCTestCase {

    func testDeclaresExactlyThePickersItCanPerform() {
        let native = iosHostCapabilities(width: 393, pickersAvailable: true)
        XCTAssertEqual(native.filePicker, .supported)
        XCTAssertEqual(native.imagePicker, .supported)
        // 没实现的操作保持 unsupported：宿主不声明自己做不到的事。
        XCTAssertEqual(native.share, .unsupported)
        XCTAssertTrue(native.safeArea)
        XCTAssertTrue(native.bottomSheet, "393pt 手机宽度应走 bottom sheet")
    }

    func testWithoutNativePickersImageFallsBackAndFileDisappears() {
        let degraded = iosHostCapabilities(width: 393, pickersAvailable: false)
        XCTAssertEqual(degraded.imagePicker, .fallback, "无相册时 composer 仍有入口，走宿主自己的表单")
        XCTAssertEqual(degraded.filePicker, .unsupported, "文件没有替代路径，入口直接消失")
    }

    func testTabletWidthTurnsOffTheBottomSheetFormFactor() {
        XCTAssertFalse(iosHostCapabilities(width: 1024, pickersAvailable: true).bottomSheet)
    }

    func testAcceptListMapsToContentTypes() {
        XCTAssertEqual(iosContentTypes(for: []), [.item])
        XCTAssertEqual(iosContentTypes(for: ["video/*"]), [.movie])
        XCTAssertEqual(iosContentTypes(for: ["image/*", "video/*"]), [.image, .movie])
        XCTAssertEqual(iosContentTypes(for: ["audio/*"]), [.audio])
        XCTAssertEqual(iosContentTypes(for: [".pdf"]), [UTType.pdf])
        XCTAssertEqual(iosContentTypes(for: ["application/pdf"]), [UTType.pdf])
        XCTAssertEqual(iosContentTypes(for: ["  ", "video/*", "video/*"]), [.movie], "空项忽略，重复项只留一份")
    }

    func testDismissedPickerIsCancelled() {
        XCTAssertEqual(IosNativePickers.dismissed.code, .cancelled)
        XCTAssertNil(IosNativePickers.dismissed.valueOrNil, "取消不能冒充空成功")
    }

    #if !canImport(UIKit)
    /// 这份测试跑在没有 UIKit 的 macOS 构建上：两个操作必须返回 UNSUPPORTED 而不是抛异常，
    /// 和 capabilities 里声明的级别一致。
    func testAdapterWithoutNativePickersReportsUnsupported() async {
        let adapter = IosPlatformAdapter(width: 393)
        let files = await adapter.pickFiles(FlarePickFilesOptions())
        let images = await adapter.pickImages(FlarePickImagesOptions())
        XCTAssertEqual(files.code, .unsupported)
        XCTAssertEqual(images.code, .unsupported)
        XCTAssertEqual(adapter.capabilities.filePicker, .unsupported)
    }
    #endif
}
