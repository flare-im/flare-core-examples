import 'package:flare_im/shared/theme/app_theme.dart';
import 'package:flare_im_ui/flare_im_ui.dart';
import 'package:flutter/material.dart';

/// Compatibility aliases for screens still awaiting canonical composition.
/// New UI reads FlareColors.of(context); these aliases do not define a palette.
abstract final class FlareImDesign {
  static const Color brandPurple = FlarePalette.lightPrimary;
  static const Color foreground = FlarePalette.lightTextPrimary;
  static const Color card = FlarePalette.lightBgPrimary;
  static const Color mutedForeground = FlarePalette.lightTextSecondary;
  static const Color destructive = FlarePalette.lightError;
  static const Color danger = FlarePalette.lightError;
  static const Color presenceOnline = FlarePalette.lightSuccess;
  static const Color chatMessageListCanvas = FlarePalette.lightBgSecondary;
  static const Color mobileCanvas = FlarePalette.lightBgPrimary;
  static const Color mobileDivider = FlarePalette.lightBorderSecondary;
  static const Color listHeaderIconCircleBg = FlarePalette.lightBgTertiary;
  static const double messageBubbleFontSize = FlareSizes.fontSizeXl;
  static const double messageBubbleTextHeight = FlareSizes.lineHeightNormal;
  static const double messageBubbleListHorizontalPad = FlareSizes.spacingMd;

  // Legacy inline-emoji asset renderer; removed with that renderer, not a kit override.
  static const double messageStickerLikeAssetMaxSide = 120;

  static ThemeData lightTheme() => AppTheme.light();
  static ThemeData darkTheme() => AppTheme.dark();
}
