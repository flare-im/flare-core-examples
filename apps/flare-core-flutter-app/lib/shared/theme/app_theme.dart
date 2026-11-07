import 'package:flare_im_ui/flare_im_ui.dart';
import 'package:flutter/material.dart';

/// Adapts the public kit palette to Material-owned platform surfaces.
abstract final class AppTheme {
  static ThemeData light() => material(Brightness.light);
  static ThemeData dark() => material(Brightness.dark);

  /// The theme for [brightness]: on the built-in palette, or on [palette] once
  /// a resource pack changed it.
  static ThemeData material(Brightness brightness, [FlareColors? palette]) {
    final colors = palette ?? FlareColors.resolve(brightness);
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: colors.bgSecondary,
      dividerColor: colors.borderPrimary,
      colorScheme: ColorScheme.fromSeed(
        seedColor: colors.primary,
        brightness: brightness,
      ).copyWith(
        primary: colors.primary,
        onPrimary: colors.messageOutgoingForeground,
        primaryContainer: colors.bgSelected,
        onPrimaryContainer: colors.textPrimary,
        secondary: colors.info,
        surface: colors.bgPrimary,
        onSurface: colors.textPrimary,
        surfaceContainerHighest: colors.bgTertiary,
        error: colors.error,
        outline: colors.borderPrimary,
      ),
    );
  }
}
