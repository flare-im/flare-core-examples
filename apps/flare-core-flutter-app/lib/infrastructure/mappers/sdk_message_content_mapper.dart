import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart' as core;
import 'package:flare_im/domain/value_objects/message_content.dart';
import 'package:flare_im/infrastructure/mappers/storage_preview_format.dart';

/// Maps generated SDK message content payloads into example-domain content.
class SdkMessageContentMapper {
  const SdkMessageContentMapper._();

  static Map<String, dynamic>? contentMapFromCore(
    core.MessageContent? content,
  ) {
    if (content == null) return null;
    return {
      'contentType': _snakeCase(content.contentType.name),
      ..._dynamicMap(content.data),
    };
  }

  static MessageContent fromMap(
    dynamic content,
    Map<String, dynamic> messageJson,
  ) {
    if (content == null) {
      throw ArgumentError('Message content is required');
    }
    if (content is! Map<String, dynamic>) {
      throw ArgumentError('Message content must be an object');
    }
    final kind = _optionalTrimmedString(content['contentType']);

    switch (kind) {
      case 'text':
        {
          final data = _asMap(content['data']);
          final nested = _asMap(content['text']);
          return TextContent(
            _prefer([
              content['text'] as String?,
              _str(data?['text']),
              _str(nested?['text']),
            ]),
          );
        }
      case 'rich_text':
      case 'rich_doc':
        {
          final data = _asMap(content['data']);
          final nested = _asMap(content['richDoc']);
          final docJson = _prefer([
            _str(content['docJson']),
            _str(data?['docJson']),
            _str(nested?['docJson']),
          ]);
          final plain = formatStoragePreview(
            _prefer([
              _str(content['plainText']),
              _str(content['searchText']),
              _str(data?['plainText']),
              _str(nested?['plainText']),
              _str(content['markdown']),
              _str(content['html']),
            ]),
          );
          return RichDocContent(
            docJson: docJson,
            plainText: plain.isNotEmpty ? plain : '[富文本]',
            sourceFormat: _optionalTrimmedString(content['inputFormat']),
          );
        }
      case 'custom':
        {
          final data = _asMap(content['data']);
          final nested = _asMap(content['custom']);
          final description = _prefer([
            _str(content['description']),
            _str(data?['description']),
            _str(nested?['description']),
            _str(content['text']),
            _str(data?['text']),
          ]);
          if (description.isNotEmpty) return TextContent(description);
          return const TextContent('[自定义]');
        }
      case 'emoji':
        return EmojiContent(
          _prefer([content['emoji'] as String?, content['text'] as String?]),
        );
      case 'image':
        final src = _asMap(content['source']);
        final thumb = _asMap(content['thumbnail']);
        final mediaId = _prefer([_str(src?['imageId']), _str(src?['uuid'])]);
        final resolved = _prefer([
          _str(src?['url']),
          _str(thumb?['url']),
          mediaId,
        ]);
        return ImageContent(
          url: resolved,
          localPath: mediaId,
          fileId: _storedMediaId(
            _prefer([
              _str(src?['imageId']),
              _str(src?['uuid']),
              _str(src?['fileId']),
            ]),
          ),
          width:
              (src?['width'] as num?)?.toInt() ??
              (thumb?['width'] as num?)?.toInt(),
          height:
              (src?['height'] as num?)?.toInt() ??
              (thumb?['height'] as num?)?.toInt(),
          size: (src?['size'] as num?)?.toInt(),
          description: _optionalTrimmedString(content['description']),
        );
      case 'image_group':
        final urls = <String>[];
        final rawList = content['images'];
        if (rawList is List<dynamic>) {
          for (final item in rawList) {
            final m = _asMap(item);
            if (m == null) continue;
            final mediaId = _prefer([_str(m['imageId']), _str(m['uuid'])]);
            final u = _prefer([_str(m['url']), mediaId]);
            if (u.isNotEmpty) urls.add(u);
          }
        }
        return ImageGroupContent(
          imageUrls: urls,
          description: _optionalTrimmedString(content['description']),
        );
      case 'video':
        final src = _asMap(content['source']);
        final cover = _asMap(content['cover']);
        final videoId = _prefer([
          content['videoId'] as String?,
          _str(src?['uuid']),
        ]);
        final url = _prefer([_str(src?['url']), videoId]);
        return VideoContent(
          url: url,
          localPath: videoId,
          fileId: _storedMediaId(videoId),
          thumbnailUrl: _prefer([_str(cover?['url']), _str(cover?['imageId'])]),
          width: (src?['width'] as num?)?.toInt(),
          height: (src?['height'] as num?)?.toInt(),
          duration: ((src?['durationMs'] as num?)?.toInt() ?? 0) ~/ 1000,
          size: (src?['size'] as num?)?.toInt(),
          description: _optionalTrimmedString(content['description']),
        );
      case 'audio':
        final src = _asMap(content['source']);
        final audioId = _prefer([
          content['audioId'] as String?,
          _str(src?['uuid']),
        ]);
        return AudioContent(
          url: _prefer([_str(src?['url']), audioId]),
          localPath: audioId,
          duration: ((src?['durationMs'] as num?)?.toInt() ?? 0) ~/ 1000,
          size: (src?['size'] as num?)?.toInt(),
        );
      case 'file':
        final fileId = _prefer([
          content['fileId'] as String?,
          content['url'] as String?,
        ]);
        final fileName = _prefer([
          content['fileName'] as String?,
          content['filename'] as String?,
          _basenameFromPath(fileId),
          'file',
        ]);
        return FileContent(
          url: _prefer([content['url'] as String?, fileId]),
          localPath: fileId,
          fileId: _storedMediaId(_str(content['fileId'])),
          filename: fileName,
          size: (content['fileSize'] as num?)?.toInt(),
        );
      case 'location':
        return LocationContent(
          latitude: (content['latitude'] as num?)?.toDouble() ?? 0,
          longitude: (content['longitude'] as num?)?.toDouble() ?? 0,
          address: content['address'] as String?,
          title: content['title'] as String?,
          zoom: (content['zoom'] as num?)?.toInt(),
          snapshotUrl: content['snapshotUrl'] as String?,
          snapshotLocalPath: content['snapshotLocalPath'] as String?,
        );
      case 'sticker':
        final pid = content['packageId'] as String?;
        return StickerContent(
          stickerId: content['stickerId'] as String? ?? '',
          packageId: pid != null && pid.isNotEmpty ? pid : null,
          url: content['url'] as String?,
          width: (content['width'] as num?)?.toInt(),
          height: (content['height'] as num?)?.toInt(),
        );
      case 'card':
        final cardId = _prefer([
          _str(content['id']),
          _str(messageJson['serverId']),
          'card',
        ]);
        return CardContent(
          id: cardId,
          cardType: _optionalTrimmedString(content['cardType']),
          title: _optionalTrimmedString(content['title']),
          subtitle: _optionalTrimmedString(content['subtitle']),
          avatar: _optionalTrimmedString(content['avatar']),
        );
      case 'link_card':
        return LinkCardContent(
          url: _prefer([_str(content['url']), '']),
          title: _optionalTrimmedString(content['title']),
          summary: _optionalTrimmedString(content['description']),
          siteName: _optionalTrimmedString(content['siteName']),
          thumbnailUrl: _optionalTrimmedString(content['thumbnailUrl']),
        );
      case 'mini_program':
        return MiniProgramContent(
          appId: _prefer([_str(content['appId']), '']),
          title: _optionalTrimmedString(content['title']),
          pagePath: _optionalTrimmedString(content['pagePath']),
          thumbnailUrl: _optionalTrimmedString(content['thumbnailUrl']),
          description: _optionalTrimmedString(
            content['description'] ?? content['summary'],
          ),
        );
      case 'notification':
        return NotificationContent(
          title: _optionalTrimmedString(content['title']),
          body: _optionalTrimmedString(content['body']),
          notificationType: _optionalTrimmedString(content['notificationType']),
          data: _stringStringMapFromJson(content['data']),
        );
      case 'vote':
        return VoteContent(
          voteId: _optionalTrimmedString(content['voteId']),
          headline: _optionalTrimmedString(content['title']),
          options: _stringListFromJson(content['options']),
          metadata: _stringStringMapFromJson(content['metadata']),
        );
      case 'task':
        return TaskContent(
          taskId: _optionalTrimmedString(content['taskId']),
          title: _optionalTrimmedString(content['title']),
          detail: _optionalTrimmedString(content['status']),
          metadata: _stringStringMapFromJson(content['metadata']),
          participantUserIds: _stringListFromJson(
            content['participantUserIds'],
          ),
        );
      case 'schedule':
        final startMs = (content['startTimeMs'] as num?)?.toInt() ?? 0;
        final endMs = (content['endTimeMs'] as num?)?.toInt() ?? 0;
        return ScheduleContent(
          scheduleId: _optionalTrimmedString(content['scheduleId']),
          title: _optionalTrimmedString(content['title']),
          timeRange: _formatScheduleTimeRangeMs(startMs, endMs),
          metadata: _stringStringMapFromJson(content['metadata']),
          participantUserIds: _stringListFromJson(
            content['participantUserIds'],
          ),
        );
      case 'announcement':
        final meta = _stringStringMapFromJson(content['metadata']);
        return AnnouncementContent(
          announcementId:
              _optionalTrimmedString(meta['announcementId']) ??
              _optionalTrimmedString(meta['id']),
          headline: _optionalTrimmedString(content['title']),
          body: _optionalTrimmedString(content['body']),
          metadata: meta,
        );
      case 'forward':
        return _forwardContentFromJson(content, messageJson);
      case 'quote':
        final quotedMessageId = _prefer([_str(content['quotedMessageId'])]);
        if (quotedMessageId.isEmpty) {
          throw ArgumentError('Quote content quotedMessageId is required');
        }
        final previewRaw = _optionalTrimmedString(content['quotedTextPreview']);
        final preview = previewRaw != null
            ? formatStoragePreview(previewRaw)
            : null;
        final currentRaw = content['currentContent'];
        final currentMap = _asMap(currentRaw);
        final replyContent = currentMap == null || currentMap.isEmpty
            ? const TextContent('')
            : fromMap(_normalizedContentMap(currentMap), messageJson);
        return QuoteContent(
          quotedMessageId: quotedMessageId,
          content: replyContent,
          quotedTextPreview: preview,
          quotedSenderName: _optionalTrimmedString(content['quotedSenderName']),
          quotedSenderId: _optionalTrimmedString(content['quotedSenderId']),
        );
      case 'thread':
        final data = _asMap(content['data']);
        final nested = _asMap(content['thread']);
        final attributes = _asObjectMap(messageJson['attributes']);
        final threadId = _prefer([
          _str(content['threadId']),
          _str(data?['threadId']),
          _str(nested?['threadId']),
        ]);
        final text = _prefer([
          _str(content['text']),
          _str(data?['text']),
          _str(nested?['text']),
          _str(content['threadTitle']),
          _str(data?['threadTitle']),
          _str(nested?['threadTitle']),
          _str(attributes?['contentText']),
        ]);
        return ThreadReplyContent(threadId: threadId, text: text);
      case 'placeholder':
        final fb = _optionalTrimmedString(content['fallbackText']);
        return PlaceholderMessageContent(
          fallbackText: fb != null && fb.isNotEmpty ? fb : '[占位]',
        );
      default:
        throw ArgumentError(
          'Unsupported message content type: ${kind ?? '<empty>'}',
        );
    }
  }

  static MessageContent _forwardContentFromJson(
    Map<String, dynamic> content,
    Map<String, dynamic> messageJson,
  ) {
    final nested = _asMap(content['forward']);
    final title =
        _optionalTrimmedString(nested?['title']) ??
        _optionalTrimmedString(content['title']) ??
        '';
    final itemsRaw = nested != null && nested['items'] is List<dynamic>
        ? nested['items'] as List<dynamic>
        : content['items'] is List<dynamic>
        ? content['items'] as List<dynamic>
        : const <dynamic>[];

    final items = <ForwardSnapshotItem>[];
    for (final raw in itemsRaw) {
      final row = _asMap(raw);
      if (row == null) continue;
      final plain = _optionalTrimmedString(row['plainText']);
      final innerContent = _forwardItemInnerContent(
        _asMap(row['content']),
        plain,
        messageJson,
      );
      items.add(
        ForwardSnapshotItem(
          sourceMessageId: _optionalTrimmedString(row['sourceMessageId']),
          sourceSenderId: _optionalTrimmedString(row['sourceSenderId']),
          senderName: _optionalTrimmedString(row['sourceSenderName']),
          plainText: plain,
          messageTypeWire: (row['messageType'] as num?)?.toInt(),
          content: innerContent,
          sentAt: _forwardItemSentAt(row),
        ),
      );
    }
    return ForwardContent(forwardTitle: title, items: items);
  }

  static MessageContent _forwardItemInnerContent(
    Map<String, dynamic>? inner,
    String? plainText,
    Map<String, dynamic> messageJson,
  ) {
    if (inner != null && inner.isNotEmpty) {
      final m = _normalizedContentMap(inner);
      final ct = (m['contentType'] as String?)?.trim();
      if (ct != null && ct.isNotEmpty) {
        return fromMap(m, messageJson);
      }
    }
    final pt = (plainText ?? '').trim();
    if (pt.isNotEmpty) return TextContent(formatStoragePreview(pt));
    throw ArgumentError('Forward item content is required');
  }

  static Map<String, dynamic> _normalizedContentMap(
    Map<String, dynamic> input,
  ) {
    return Map<String, dynamic>.from(input);
  }

  static DateTime? _forwardItemSentAt(Map<String, dynamic> row) {
    final v = row['sourceMessageTimeMs'];
    if (v is! num) return null;
    var ms = v.toInt();
    if (ms <= 0) return null;
    if (ms < 100000000000) ms *= 1000;
    return DateTime.fromMillisecondsSinceEpoch(ms);
  }

  static Map<String, dynamic>? _asMap(dynamic v) =>
      v is Map<String, dynamic> ? v : null;

  static Map<dynamic, dynamic>? _asObjectMap(dynamic v) => v is Map ? v : null;

  static String _str(dynamic v) => v is String ? v : '';

  /// 核心里存的媒体 id；上传完成前核心把本机路径、`data:` 或网址放在同一个字段里，
  /// 那些不是 id（按 id 去缓存 / 网关取会失败），返回 null。
  static String? _storedMediaId(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return null;
    final lower = value.toLowerCase();
    if (lower.startsWith('http://') ||
        lower.startsWith('https://') ||
        lower.startsWith('file:') ||
        lower.startsWith('data:') ||
        lower.startsWith('blob:') ||
        lower.startsWith('content:') ||
        value.startsWith('/') ||
        value.startsWith(r'\') ||
        RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(value)) {
      return null;
    }
    return value;
  }

  static String _prefer(List<String?> values) {
    for (final v in values) {
      final t = (v ?? '').trim();
      if (t.isNotEmpty) return t;
    }
    return '';
  }

  static String? _optionalTrimmedString(dynamic v) {
    if (v == null) return null;
    final s = v is String ? v : v.toString();
    final t = s.trim();
    return t.isEmpty ? null : t;
  }

  static List<String> _stringListFromJson(dynamic v) {
    if (v is! List<dynamic>) return const [];
    return v
        .map((e) => e?.toString().trim() ?? '')
        .where((s) => s.isNotEmpty)
        .toList();
  }

  static Map<String, String> _stringStringMapFromJson(dynamic v) {
    if (v is! Map) return const {};
    final out = <String, String>{};
    for (final e in v.entries) {
      final key = e.key?.toString() ?? '';
      if (key.isEmpty) continue;
      out[key] = e.value?.toString() ?? '';
    }
    return out;
  }

  static String _formatScheduleTimeRangeMs(int startMs, int endMs) {
    if (startMs <= 0 && endMs <= 0) return '';
    String fmt(DateTime d) {
      String two(int n) => n < 10 ? '0$n' : '$n';
      return '${d.year}/${d.month}/${d.day} ${two(d.hour)}:${two(d.minute)}';
    }

    if (startMs > 0 && endMs > 0) {
      final s = DateTime.fromMillisecondsSinceEpoch(startMs);
      final e = DateTime.fromMillisecondsSinceEpoch(endMs);
      return '${fmt(s)} - ${fmt(e)}';
    }
    final d = DateTime.fromMillisecondsSinceEpoch(
      startMs > 0 ? startMs : endMs,
    );
    return fmt(d);
  }

  static String _basenameFromPath(String raw) {
    final t = raw.trim();
    if (t.isEmpty) return '';
    final normalized = t.replaceAll('\\', '/');
    final i = normalized.lastIndexOf('/');
    if (i < 0 || i + 1 >= normalized.length) return normalized;
    return normalized.substring(i + 1);
  }

  static Map<String, dynamic> _dynamicMap(Map source) {
    return source.map(
      (key, value) => MapEntry(key.toString(), _dynamicValue(value)),
    );
  }

  static Object? _dynamicValue(Object? value) {
    if (value is Map) return _dynamicMap(value);
    if (value is List) return value.map(_dynamicValue).toList(growable: false);
    return value;
  }

  static String _snakeCase(String value) {
    final buffer = StringBuffer();
    for (var i = 0; i < value.length; i++) {
      final char = value[i];
      final lower = char.toLowerCase();
      if (i > 0 && char != lower) buffer.write('_');
      buffer.write(lower);
    }
    return buffer.toString();
  }
}
