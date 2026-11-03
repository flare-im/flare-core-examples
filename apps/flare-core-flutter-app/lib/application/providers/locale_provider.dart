import 'dart:async';

import 'package:flare_im/shared/i18n/flare_locale.dart';
import 'package:flare_im/shared/i18n/flare_messages.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _prefKey = 'flare_im_locale';

final flareLocaleProvider =
    StateNotifierProvider<FlareLocaleNotifier, FlareLocale>((ref) {
      return FlareLocaleNotifier();
    });

final flareMessagesProvider = Provider<FlareMessages>((ref) {
  return FlareMessages.of(ref.watch(flareLocaleProvider));
});

class FlareLocaleNotifier extends StateNotifier<FlareLocale> {
  FlareLocaleNotifier() : super(FlareLocale.zhCn) {
    unawaited(_restore());
  }

  Future<void> _restore() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefKey);
    if (saved == null) return;
    state = FlareLocale.fromCode(saved);
  }

  Future<void> setLocale(FlareLocale locale) async {
    state = locale;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, locale.code);
  }
}

/// Material [Locale] for [MaterialApp].
Locale materialLocaleFor(FlareLocale locale) {
  return switch (locale) {
    FlareLocale.zhCn => const Locale('zh', 'CN'),
    FlareLocale.enUs => const Locale('en', 'US'),
  };
}
