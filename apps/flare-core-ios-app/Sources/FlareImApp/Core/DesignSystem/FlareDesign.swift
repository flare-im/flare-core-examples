import SwiftUI
import FlareIMUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

// FlareDesign 是 app 的设计门面,现已**委托给 kit 设计 token**
// (FlareColors / FlareSizes,源自 flare-im-design/tokens/tokens.json),
// 不再持有并行的硬编码色值/尺寸。调用点(FlareDesign.brand / .Spacing.lg 等)保持不变,
// 随平台外观解析 light/dark，支持系统主题和应用内主题选择。
enum FlareDesign {
    private static func themed(_ light: Color, _ dark: Color) -> Color {
        #if canImport(UIKit)
        return Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
        #else
        return Color(nsColor: NSColor(name: nil) { appearance in
            appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? NSColor(dark) : NSColor(light)
        })
        #endif
    }

    static let brand = themed(FlareColors.light.primary, FlareColors.dark.primary)
    static let brandSoft = themed(FlareColors.light.bgSelected, FlareColors.dark.bgSelected)
    static let accent = themed(FlareColors.light.info, FlareColors.dark.info)
    static let appBackground = themed(FlareColors.light.bgSecondary, FlareColors.dark.bgSecondary)
    static let surface = themed(FlareColors.light.bgPrimary, FlareColors.dark.bgPrimary)
    static let surfaceAlt = themed(FlareColors.light.bgTertiary, FlareColors.dark.bgTertiary)
    static let textPrimary = themed(FlareColors.light.textPrimary, FlareColors.dark.textPrimary)
    static let textSecondary = themed(FlareColors.light.textSecondary, FlareColors.dark.textSecondary)
    static let textTertiary = themed(FlareColors.light.textTertiary, FlareColors.dark.textTertiary)
    static let success = themed(FlareColors.light.success, FlareColors.dark.success)
    static let warning = themed(FlareColors.light.warning, FlareColors.dark.warning)
    static let danger = themed(FlareColors.light.error, FlareColors.dark.error)
    static let incoming = themed(FlareColors.light.messageIncomingBackground, FlareColors.dark.messageIncomingBackground)
    static let outgoing = themed(FlareColors.light.messageOutgoingBackground, FlareColors.dark.messageOutgoingBackground)
    static let outgoingText = themed(FlareColors.light.messageOutgoingForeground, FlareColors.dark.messageOutgoingForeground)

    /// 向后兼容别名：等价于 `Radius.medium`。新代码直接用 `FlareDesign.Radius.*`。
    static let radius: CGFloat = Radius.medium

    /// 圆角标尺，委托到 kit `FlareSizes`（sm6/md8/lg10/xl14/2xl18/full999）。
    enum Radius {
        static let small = FlareSizes.radiusSm     // 6
        static let medium = FlareSizes.radiusMd    // 8
        static let large = FlareSizes.radiusLg     // 10
        static let xl = FlareSizes.radiusXl        // 14
        static let pill = FlareSizes.radiusFull    // 999
    }

    /// 间距标尺（4pt 基准网格），委托到 kit `FlareSizes`。
    enum Spacing {
        static let xxs = FlareSizes.spacingXs / 2
        static let xs = FlareSizes.spacingXs       // 4
        static let sm = FlareSizes.spacingSm       // 8
        static let md = FlareSizes.spacingMd       // 12
        static let lg = FlareSizes.spacingLg       // 16
        static let xl = FlareSizes.spacingXl       // 20
        static let xxl = FlareSizes.spacing2xl     // 24
    }

    /// 字体标尺。集中字号/字重，便于全局统一与无障碍缩放。
    enum Typography {
        static let largeTitle = Font.title2.weight(.semibold)
        static let title = Font.title3.weight(.bold)
        static let headline = Font.headline
        static let body = Font.body
        static let callout = Font.callout.weight(.medium)
        static let caption = Font.caption
        static let captionStrong = Font.caption.weight(.semibold)
    }

    static func color(for tone: RuntimeTone) -> Color {
        switch tone {
        case .neutral: return textTertiary
        case .info: return accent
        case .success: return success
        case .warning: return warning
        case .danger: return danger
        }
    }
}
