import 'dart:convert';

import 'package:flare_im/shared/config/app_defaults_model.dart';
import 'package:flutter/services.dart' show rootBundle;

/// 加载 [assets/config/app_defaults.json]；失败时返回 [AppDefaults.fallback]。
abstract final class AppConfigLoader {
  static const String assetPath = 'assets/config/app_defaults.json';

  static AppDefaults? _cached;

  static Future<AppDefaults> load() async {
    if (_cached != null) return _cached!;
    try {
      final raw = await rootBundle.loadString(assetPath);
      final map = jsonDecode(raw) as Map<String, dynamic>;
      _cached = AppDefaults.fromJson(map);
    } catch (_) {
      _cached = AppDefaults.fallback;
    }
    return _cached!;
  }

  /// 测试或热重载时清空缓存
  static void clearCache() => _cached = null;
}
