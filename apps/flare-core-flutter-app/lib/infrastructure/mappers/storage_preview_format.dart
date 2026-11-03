import 'dart:convert';

import 'package:flare_im/infrastructure/media/emoji_pack_i18n.dart';

/// 是否为 SDK 的 `PreviewStoragePayload`（`k` 以 `im.preview.` 开头）。
bool isStoragePreviewPayloadString(String raw) {
  final t = raw.trim();
  if (!t.startsWith('{')) return false;
  try {
    final decoded = jsonDecode(t);
    if (decoded is! Map<String, dynamic>) return false;
    final k = decoded['k'];
    return k is String && k.startsWith('im.preview.');
  } catch (_) {
    return false;
  }
}

/// 将 SDK 写入的 `PreviewStoragePayload` JSON 转为示例 UI 可读串；正式产品应接 i18n。
String formatStoragePreview(String raw, {String? locale}) {
  final t = raw.trim();
  if (t.isEmpty) return t;
  if (!t.startsWith('{')) return raw;
  try {
    final decoded = jsonDecode(t);
    if (decoded is! Map<String, dynamic>) return raw;
    final k = decoded['k'];
    if (k is! String) return raw;
    final a = decoded['a'];
    final m = a is Map<String, dynamic> ? a : <String, dynamic>{};
    return _formatPayload(k, m, locale: locale);
  } catch (_) {
    return raw;
  }
}

bool storagePreviewIsSticker(String raw) {
  final payload = _decodeStoragePayload(raw);
  return payload?.key == 'im.preview.sticker';
}

String? storagePreviewEmojiKey(String raw) {
  final payload = _decodeStoragePayload(raw);
  if (payload?.key != 'im.preview.emoji') return null;
  final key = _str(payload!.args, 'e');
  return key.isEmpty ? null : key;
}

({String key, Map<String, dynamic> args})? _decodeStoragePayload(String raw) {
  final t = raw.trim();
  if (!t.startsWith('{')) return null;
  try {
    final decoded = jsonDecode(t);
    if (decoded is! Map<String, dynamic>) return null;
    final k = decoded['k'];
    if (k is! String || !k.startsWith('im.preview.')) return null;
    final a = decoded['a'];
    return (key: k, args: a is Map<String, dynamic> ? a : <String, dynamic>{});
  } catch (_) {
    return null;
  }
}

String _str(Map<String, dynamic> m, String key) {
  final v = m[key];
  if (v == null) return '';
  return v.toString().trim();
}

String _formatInner(dynamic v) {
  if (v == null) return '';
  if (v is String) return formatStoragePreview(v);
  if (v is Map<String, dynamic>) {
    final k = v['k'];
    if (k is String) {
      final a = v['a'];
      final m = a is Map<String, dynamic> ? a : <String, dynamic>{};
      return _formatPayload(k, m);
    }
  }
  return '';
}

String _formatPayload(String k, Map<String, dynamic> a, {String? locale}) {
  switch (k) {
    case 'im.preview.user_text':
      return _str(a, 't');
    case 'im.preview.rich_text':
      final title = _str(a, 'title');
      final body = _str(a, 'body');
      if (title.isNotEmpty && body.isNotEmpty) return '$title $body';
      if (title.isNotEmpty) return title;
      if (body.isNotEmpty) return body;
      return '[富文本]';
    case 'im.preview.file':
      final n = _str(a, 'n');
      return n.isNotEmpty ? '[文件] $n' : '[文件]';
    case 'im.preview.image':
      if (a['m'] == true) return '[动图]';
      final d = _str(a, 'd');
      return d.isNotEmpty ? d : '[图片]';
    case 'im.preview.video':
      return _str(a, 'd').isNotEmpty ? _str(a, 'd') : '[视频]';
    case 'im.preview.audio':
      return _str(a, 'd').isNotEmpty ? _str(a, 'd') : '[语音]';
    case 'im.preview.location':
      final label = _str(a, 'label');
      return label.isNotEmpty ? '[位置] $label' : '[位置]';
    case 'im.preview.card':
      final label = _str(a, 'label');
      return label.isNotEmpty ? '[名片] $label' : '[名片]';
    case 'im.preview.sticker':
      return locale?.toLowerCase().startsWith('en') == true ? '[Sticker]' : '[贴纸]';
    case 'im.preview.emoji':
      final key = _str(a, 'e');
      return key.isNotEmpty
          ? EmojiPackI18n.packLabel(key, locale: locale)
          : (locale?.toLowerCase().startsWith('en') == true ? '[Emoji]' : '[表情]');
    case 'im.preview.quote':
      final qInner = _formatInner(a['inner']);
      return qInner.isNotEmpty ? qInner : '[引用]';
    case 'im.preview.link':
      return _str(a, 't').isNotEmpty ? _str(a, 't') : '[链接]';
    case 'im.preview.forward_empty':
      return '[转发]';
    case 'im.preview.forward_many':
      final n = a['n'];
      final count = n is num ? n.toInt() : int.tryParse('$n') ?? 0;
      final first = _formatInner(a['first']);
      if (count > 1) {
        return first.isNotEmpty ? '[转发] $count 条 · $first' : '[转发] $count 条消息';
      }
      return first.isNotEmpty ? first : '[转发]';
    case 'im.preview.thread':
      return _str(a, 't').isNotEmpty ? _str(a, 't') : '[话题]';
    case 'im.preview.mini_program':
      return _str(a, 't').isNotEmpty ? _str(a, 't') : '[小程序]';
    case 'im.preview.image_group':
      return '[多图]';
    case 'im.preview.system':
      return _str(a, 't').isNotEmpty ? _str(a, 't') : '[系统消息]';
    case 'im.preview.notification':
      final b = _str(a, 'body');
      if (b.isNotEmpty) return b;
      final title = _str(a, 'title');
      return title.isNotEmpty ? title : '[通知]';
    case 'im.preview.vote':
      return '[投票]';
    case 'im.preview.task':
      final title = _str(a, 't');
      return title.isNotEmpty ? '[任务] $title' : '[任务]';
    case 'im.preview.schedule':
      return '[日程]';
    case 'im.preview.announcement':
      final title = _str(a, 't');
      return title.isNotEmpty ? '[公告] $title' : '[公告]';
    case 'im.preview.custom':
      return _str(a, 'd').isNotEmpty ? _str(a, 'd') : '[自定义]';
    case 'im.preview.placeholder':
      return _str(a, 't').isNotEmpty ? _str(a, 't') : '[占位]';
    case 'im.preview.unknown':
      return '[未知]';
    default:
      return '[$k]';
  }
}
