import 'package:flare_im/shared/theme/app_theme.dart';
import 'package:flare_im_ui/flare_im_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a palette from a resource pack replaces the built-in one', () {
    final palette = FlareColors.light.copyWith(
      bgSecondary: const Color(0xFF112233),
      primary: const Color(0xFF445566),
      borderPrimary: const Color(0xFF778899),
    );

    final theme = AppTheme.material(Brightness.light, palette);

    expect(theme.scaffoldBackgroundColor, palette.bgSecondary);
    expect(theme.colorScheme.primary, palette.primary);
    expect(theme.dividerColor, palette.borderPrimary);
    expect(theme.brightness, Brightness.light);
  });

  test('no palette is the built-in theme', () {
    expect(
      AppTheme.dark().scaffoldBackgroundColor,
      FlareColors.dark.bgSecondary,
    );
    expect(
      AppTheme.material(Brightness.light).scaffoldBackgroundColor,
      FlareColors.light.bgSecondary,
    );
  });
}
