package com.flare.im.app.core.designsystem

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import com.flare.im.ui.FlareColors as KitColors
import com.flare.im.ui.LocalFlareStrings
import com.flare.im.ui.FlareThemeProvider
import com.flare.im.ui.FlareThemeMode
import com.flare.im.ui.FlareSizes
import com.flare.im.ui.flareColors

// FlareTheme — Compose 设计系统（品牌锁定，关闭 dynamic-color）。
// 颜色/圆角**委托给 kit 设计 token**(com.flare.im.ui.FlareColors/FlareSizes,
// 源自 flare-im-design/tokens/tokens.json),不再持有并行硬编码值。视图仍通过
// `FlareTheme.colors` / `FlareTheme.tokens` 读取,值统一收敛到 kit,与三端一致。

/** 语义色板（light + dark 各一份）。 */
@Immutable
data class FlareColors(
    val brand: Color,
    val brandSoft: Color,
    val accent: Color,
    val background: Color,
    val surface: Color,
    val surfaceAlt: Color,
    val textPrimary: Color,
    val textSecondary: Color,
    val textTertiary: Color,
    val success: Color,
    val warning: Color,
    val danger: Color,
    val incomingBubble: Color,
    val outgoing: Color,
    val outgoingText: Color,
    val hairline: Color,
    val isDark: Boolean,
)

// 值委托给 kit 色板（app 语义名 → kit token 字段）。
internal fun flareAppColors(kit: KitColors, dark: Boolean): FlareColors = FlareColors(
    brand = kit.primary,
    brandSoft = kit.bgSelected,
    accent = kit.info,
    background = kit.bgSecondary,
    surface = kit.bgPrimary,
    surfaceAlt = kit.bgTertiary,
    textPrimary = kit.textPrimary,
    textSecondary = kit.textSecondary,
    textTertiary = kit.textTertiary,
    success = kit.success,
    warning = kit.warning,
    danger = kit.error,
    incomingBubble = kit.messageIncomingBackground,
    outgoing = kit.messageOutgoingBackground,
    outgoingText = kit.messageOutgoingForeground,
    hairline = kit.borderPrimary,
    isDark = dark,
)

private val LightFlareColors = flareAppColors(KitColors.Light, dark = false)
private val DarkFlareColors = flareAppColors(KitColors.Dark, dark = true)

/** 运行时状态色调。 */
enum class FlareTone { Neutral, Info, Success, Warning, Danger }

fun FlareColors.color(tone: FlareTone): Color = when (tone) {
    FlareTone.Neutral -> textTertiary
    FlareTone.Info -> accent
    FlareTone.Success -> success
    FlareTone.Warning -> warning
    FlareTone.Danger -> danger
}

/** 间距 / 圆角 / 字体标尺 —— 与主题无关。 */
@Immutable
object FlareTokens {
    // Spacing：4pt 基准网格。
    val xxs = FlareSizes.spacingXs / 2
    val xs = FlareSizes.spacingXs
    val sm = FlareSizes.spacingSm
    val md = FlareSizes.spacingMd
    val lg = FlareSizes.spacingLg
    val xl = FlareSizes.spacingXl
    val xxl = FlareSizes.spacing2xl

    // Radius：委托到 kit FlareSizes（sm6/md8/lg10/xl14/full999）。
    val radiusSmall = RoundedCornerShape(FlareSizes.radiusSm)
    val radiusMedium = RoundedCornerShape(FlareSizes.radiusMd)
    val radiusLarge = RoundedCornerShape(FlareSizes.radiusLg)
    val radiusXl = RoundedCornerShape(FlareSizes.radiusXl)
    val pill = RoundedCornerShape(FlareSizes.radiusFull)
}

private val LocalFlareColors = staticCompositionLocalOf { LightFlareColors }

/** 在 Compose 树中读取 Flare 设计 token。 */
object FlareTheme {
    val colors: FlareColors
        @Composable @ReadOnlyComposable get() = LocalFlareColors.current
    val tokens: FlareTokens get() = FlareTokens
}

/**
 * App 主题。`dark` 为 null 时跟随系统。
 * dynamic-color 关闭以保留 Flare 品牌紫。
 */
@Composable
fun FlareAppTheme(
    dark: Boolean? = null,
    content: @Composable () -> Unit,
) {
    val isDark = dark ?: isSystemInDarkTheme()
    val colors = if (isDark) DarkFlareColors else LightFlareColors
    CompositionLocalProvider(LocalFlareColors provides colors, LocalFlareStrings provides rememberKitStrings()) {
        FlareThemeProvider(
            mode = if (isDark) FlareThemeMode.Dark else FlareThemeMode.Light,
            colors = if (isDark) KitColors.Dark else KitColors.Light,
            content = content,
        )
    }
}

/**
 * 让 `FlareTheme.colors` 跟上这里生效的 kit 色板。资源包在 [FlareAppTheme] 里层才到，
 * 改底色时页面和 kit 组件要同一套，所以放在覆盖层下面。
 */
@Composable
fun FlareAppPalette(content: @Composable () -> Unit) {
    val kit = flareColors()
    val dark = FlareTheme.colors.isDark
    val palette = remember(kit, dark) { flareAppColors(kit, dark) }
    CompositionLocalProvider(LocalFlareColors provides palette, content = content)
}
