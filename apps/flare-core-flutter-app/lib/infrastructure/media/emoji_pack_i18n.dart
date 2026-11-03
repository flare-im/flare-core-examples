import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

/// 表情 pack key 的展示文案，加载 client-sdk 共享 i18n 资产。
class EmojiPackI18n {
  EmojiPackI18n._();

  static Map<String, dynamic>? _locales;

  static Future<void> ensureLoaded() async {
    if (_locales != null) return;
    final s = await rootBundle.loadString('assets/emoji-locales.json');
    _locales = jsonDecode(s) as Map<String, dynamic>;
  }

  static String _columnForLocale(String? locale) {
    final l = (locale ?? 'en').toLowerCase();
    if (l.startsWith('zh')) return 'zh-Hans';
    return 'en';
  }

  /// 短名；未知 key 回退为 key 本身；未 [ensureLoaded] 时同样回退。
  static String packLabel(String key, {String? locale}) {
    final k = key.trim();
    if (k.isEmpty) return '';
    final raw = _locales;
    if (raw == null) return k;
    final col = _columnForLocale(locale);
    final primary = (raw[col] as Map<String, dynamic>?)?[k];
    if (primary is String && primary.trim().isNotEmpty) return primary.trim();
    final en = (raw['en'] as Map<String, dynamic>?)?[k];
    if (en is String && en.trim().isNotEmpty) return en.trim();
    return k;
  }

  static String formatBracket(String key, {String? locale}) =>
      '[${packLabel(key, locale: locale)}]';

  static final RegExp _packKeyToken = RegExp(r'\[([a-z][a-z0-9_]*)\]');

  /// 会话摘要等：把 `[pensive_face]` 换成当前语言短名。
  static String formatPackKeysInPlainText(String text, {String? locale}) {
    return text.replaceAllMapped(_packKeyToken, (m) {
      final key = m.group(1);
      if (key == null) return m.group(0)!;
      return packLabel(key, locale: locale);
    });
  }
}
