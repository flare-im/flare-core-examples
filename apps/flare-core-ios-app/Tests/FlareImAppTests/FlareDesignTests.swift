import FlareIMUI
import SwiftUI
import XCTest
@testable import FlareImApp

#if canImport(AppKit)
import AppKit
#endif

/// The app's palette is the Kit's, so a resource pack changes pages and Kit components alike.
final class FlareDesignTests: XCTestCase {
    private let pack = FlareResourcePack(
        id: "tokens",
        kind: "tokens",
        packVersion: 1,
        contentJson: ##"{"schema":"flare.resource.v1","kind":"tokens","colors":{"bgSecondary":"#112233"},"dark":{"bgSecondary":"#445566"}}"##
    )

    override func tearDown() {
        FlareDesign.follow(.violet)
        super.tearDown()
    }

    private func hex(_ color: Color, dark: Bool) -> String {
        #if canImport(UIKit)
        let style: UIUserInterfaceStyle = dark ? .dark : .light
        let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        #else
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
        NSAppearance(named: dark ? .darkAqua : .aqua)!.performAsCurrentDrawingAppearance {
            let resolved = NSColor(color).usingColorSpace(.sRGB)!
            red = resolved.redComponent
            green = resolved.greenComponent
            blue = resolved.blueComponent
        }
        #endif
        return String(format: "#%02X%02X%02X", Int((red * 255).rounded()), Int((green * 255).rounded()), Int((blue * 255).rounded()))
    }

    func testAThemeFromAPackReachesThePage() {
        FlareDesign.follow(FlareResourceOverlay(packs: [pack]).brandTheme(.violet))
        XCTAssertEqual(hex(FlareDesign.appBackground, dark: false), "#112233")
        XCTAssertEqual(hex(FlareDesign.appBackground, dark: true), "#445566")
    }

    func testWhatThePackLeavesStaysTheKits() {
        let builtIn = hex(FlareDesign.brand, dark: false)
        FlareDesign.follow(FlareResourceOverlay(packs: [pack]).brandTheme(.violet))
        XCTAssertEqual(hex(FlareDesign.brand, dark: false), builtIn)
    }

    func testTheBuiltInThemeComesBack() {
        let builtIn = hex(FlareDesign.appBackground, dark: false)
        FlareDesign.follow(FlareResourceOverlay(packs: [pack]).brandTheme(.violet))
        FlareDesign.follow(.violet)
        XCTAssertEqual(hex(FlareDesign.appBackground, dark: false), builtIn)
    }

    /// A read gives the same colour until the theme changes: a new one per read would redraw what reads it.
    func testAPackWithNoColoursChangesNothing() {
        let theme = FlareResourceOverlay.empty.brandTheme(.violet)
        XCTAssertEqual(theme.name, FlareBrandTheme.violet.name)
        let before = FlareDesign.surface
        FlareDesign.follow(theme)
        XCTAssertEqual(FlareDesign.surface, before)
    }
}
