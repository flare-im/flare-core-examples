import 'package:flare_im/infrastructure/media/composer_pack_assets.dart';

// 纯文本里 `[pack_key]` 分段；调用方须先排除 Markdown。
sealed class PlainTextEmojiSegment {}

final class PlainTextRunSegment extends PlainTextEmojiSegment {
  PlainTextRunSegment(this.text);
  String text;
}

/// 本地存在 `assets/emoji/<key>.webp`
final class PlainEmojiPackSegment extends PlainTextEmojiSegment {
  PlainEmojiPackSegment(this.key);
  final String key;
}

// `[key]` 但包内无对应 webp。
final class PlainEmojiUnknownSegment extends PlainTextEmojiSegment {
  PlainEmojiUnknownSegment(this.key);
  final String key;
}

// `[a-z][a-z0-9_]*` bracket token；切段方式与 JS 捕获组 split 行为对齐。
final RegExp emojiBracketTokenPattern = RegExp(r'\[([a-z][a-z0-9_]*)\]');

/// 解析正文里的 `[pack_key]`；其余保持纯文本。仅小写 snake 形式 key 参与匹配。
List<PlainTextEmojiSegment> splitPlainTextForEmojiDisplay(String text) {
  if (text.isEmpty) return const [];
  final out = <PlainTextEmojiSegment>[];
  var cursor = 0;
  for (final m in emojiBracketTokenPattern.allMatches(text)) {
    if (m.start > cursor) {
      _appendPlainRun(out, text.substring(cursor, m.start));
    }
    final key = m.group(1)!;
    if (ComposerPackAssets.hasEmojiWebp(key)) {
      out.add(PlainEmojiPackSegment(key));
    } else {
      out.add(PlainEmojiUnknownSegment(key));
    }
    cursor = m.end;
  }
  if (cursor < text.length) {
    _appendPlainRun(out, text.substring(cursor));
  }
  return out;
}

void _appendPlainRun(List<PlainTextEmojiSegment> out, String chunk) {
  if (chunk.isEmpty) return;
  if (out.isNotEmpty && out.last is PlainTextRunSegment) {
    (out.last as PlainTextRunSegment).text += chunk;
  } else {
    out.add(PlainTextRunSegment(chunk));
  }
}

// trim 后整段为单个已知 `[key]`。
({String key})? resolveLoneEmojiPackInText(String text) {
  final t = text.trim();
  if (t.isEmpty) return null;
  final m = RegExp(r'^\[([a-z][a-z0-9_]*)\]$').firstMatch(t);
  if (m == null) return null;
  final key = m.group(1)!;
  if (!ComposerPackAssets.hasEmojiWebp(key)) return null;
  return (key: key);
}

// trim 后整段为 `[key]` 但无 webp → 仅括号文案。
PlainEmojiUnknownSegment? resolveLoneEmojiBracketUnknown(String text) {
  final t = text.trim();
  if (t.isEmpty || text != t) return null;
  final parts = splitPlainTextForEmojiDisplay(t);
  if (parts.length != 1) return null;
  final only = parts.single;
  return only is PlainEmojiUnknownSegment ? only : null;
}

bool plainTextHasEmojiOrUnknown(List<PlainTextEmojiSegment> parts) {
  for (final p in parts) {
    if (p is PlainEmojiPackSegment || p is PlainEmojiUnknownSegment) {
      return true;
    }
  }
  return false;
}
