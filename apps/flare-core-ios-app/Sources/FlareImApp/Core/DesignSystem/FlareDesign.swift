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

    /// 一套 light/dark 色。资源包改颜色时整套换掉，不在每次读取时新建 `Color`。
    private struct Palette {
        let brand: Color
        let brandSoft: Color
        let accent: Color
        let appBackground: Color
        let surface: Color
        let surfaceAlt: Color
        let textPrimary: Color
        let textSecondary: Color
        let textTertiary: Color
        let success: Color
        let warning: Color
        let danger: Color
        let incoming: Color
        let outgoing: Color
        let outgoingText: Color

        init(light: FlareColors, dark: FlareColors) {
            brand = themed(light.primary, dark.primary)
            brandSoft = themed(light.bgSelected, dark.bgSelected)
            accent = themed(light.info, dark.info)
            appBackground = themed(light.bgSecondary, dark.bgSecondary)
            surface = themed(light.bgPrimary, dark.bgPrimary)
            surfaceAlt = themed(light.bgTertiary, dark.bgTertiary)
            textPrimary = themed(light.textPrimary, dark.textPrimary)
            textSecondary = themed(light.textSecondary, dark.textSecondary)
            textTertiary = themed(light.textTertiary, dark.textTertiary)
            success = themed(light.success, dark.success)
            warning = themed(light.warning, dark.warning)
            danger = themed(light.error, dark.error)
            incoming = themed(light.messageIncomingBackground, dark.messageIncomingBackground)
            outgoing = themed(light.messageOutgoingBackground, dark.messageOutgoingBackground)
            outgoingText = themed(light.messageOutgoingForeground, dark.messageOutgoingForeground)
        }
    }

    private static var palette = Palette(light: .light, dark: .dark)
    private static var followed = FlareBrandTheme.violet.name

    /// 换成 `theme` 的颜色。视图读的是这里的静态值，不是环境，所以读到新颜色要靠 `flareDesignFollowsTheme()` 重建。
    static func follow(_ theme: FlareBrandTheme) {
        guard theme.name != followed else { return }
        followed = theme.name
        palette = Palette(light: theme.light, dark: theme.dark)
    }

    static var brand: Color { palette.brand }
    static var brandSoft: Color { palette.brandSoft }
    static var accent: Color { palette.accent }
    static var appBackground: Color { palette.appBackground }
    static var surface: Color { palette.surface }
    static var surfaceAlt: Color { palette.surfaceAlt }
    static var textPrimary: Color { palette.textPrimary }
    static var textSecondary: Color { palette.textSecondary }
    static var textTertiary: Color { palette.textTertiary }
    static var success: Color { palette.success }
    static var warning: Color { palette.warning }
    static var danger: Color { palette.danger }
    static var incoming: Color { palette.incoming }
    static var outgoing: Color { palette.outgoing }
    static var outgoingText: Color { palette.outgoingText }

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

private struct FlareDesignFollower: ViewModifier {
    @Environment(\.flareBrandTheme) private var brand

    func body(content: Content) -> some View {
        FlareDesign.follow(brand)
        // 只有 token 包到达时主题名才变，一次运行最多一次；下面的视图都读静态值，只能这样全部重建。
        return content.id(brand.name)
    }
}

extension View {
    /// 让 `FlareDesign` 跟上环境里的 kit 主题（资源包的颜色从这里来）。放在 `flareUpdateResources` 里层。
    /// 主题名变化时这一层以下的视图状态会重置。
    func flareDesignFollowsTheme() -> some View {
        modifier(FlareDesignFollower())
    }
}
