import 'package:shared_preferences/shared_preferences.dart';

/// 「最常使用」表情 key 列表（持久化，与 assets/emoji 文件名 stem 一致）。
abstract final class ComposerRecentEmojiStore {
  ComposerRecentEmojiStore._();

  static const _key = 'flare_composer_recent_emoji_v1';
  static const _max = 24;

  static Future<List<String>> load() async {
    final p = await SharedPreferences.getInstance();
    return p.getStringList(_key) ?? const [];
  }

  static Future<void> record(String emojiKey) async {
    final k = emojiKey.trim();
    if (k.isEmpty) return;
    final p = await SharedPreferences.getInstance();
    final cur = List<String>.from(p.getStringList(_key) ?? []);
    cur.remove(k);
    cur.insert(0, k);
    if (cur.length > _max) {
      cur.removeRange(_max, cur.length);
    }
    await p.setStringList(_key, cur);
  }
}
