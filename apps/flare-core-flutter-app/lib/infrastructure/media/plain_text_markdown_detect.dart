/// 与 Tauri `utils/markdown.ts` 中 [detectContentType] / [isMarkdown] 的正则列表一致，
/// 用于在解析 `[pack_key]` 前排除 Markdown（见 `TextView.vue`）。
abstract final class PlainTextMarkdownDetect {
  PlainTextMarkdownDetect._();

  static final List<RegExp> _patterns = [
    RegExp(r'^#{1,6}\s+', multiLine: true),
    RegExp(r'^\*\s+', multiLine: true),
    RegExp(r'^\d+\.\s+', multiLine: true),
    RegExp(r'```[\s\S]*?```'),
    RegExp(r'\[.*?\]\(.*?\)'),
    RegExp(r'\*\*.*?\*\*'),
    RegExp(r'\*.*?\*'),
    RegExp(r'^>\s+', multiLine: true),
    RegExp(r'^\|.*\|.*$', multiLine: true),
  ];

  static bool isMarkdown(String content) {
    if (content.isEmpty) return false;
    for (final p in _patterns) {
      if (p.hasMatch(content)) return true;
    }
    return false;
  }
}
