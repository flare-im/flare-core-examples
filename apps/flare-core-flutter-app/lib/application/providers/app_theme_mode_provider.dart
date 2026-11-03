import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefKey = 'flare_im_theme_mode';

final appThemeModeProvider =
    StateNotifierProvider<AppThemeModeNotifier, ThemeMode>((ref) {
      return AppThemeModeNotifier();
    });

class AppThemeModeNotifier extends StateNotifier<ThemeMode> {
  AppThemeModeNotifier() : super(ThemeMode.system) {
    unawaited(_restore());
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefKey);
    if (raw == null) return;
    state = switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    final prefs = await SharedPreferences.getInstance();
    final stored = switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };
    await prefs.setString(_prefKey, stored);
  }
}
