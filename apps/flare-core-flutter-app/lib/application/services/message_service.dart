import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart' as core;
import 'package:flare_im/domain/entities/message.dart';
import 'package:flare_im/domain/repositories/i_message_repository.dart';
import 'package:flare_im/domain/value_objects/message_content.dart';
import 'package:flare_im/infrastructure/mappers/sdk_model_mapper.dart';

typedef CreatedSdkMessage = ({Message message, core.Message sdkMessage});

/// `create_quote` 的 `quotedContent`：SDK MessageContent，adapter 统一转为 core Elem JSON。
Map<String, dynamic> quotedContentShellForMessage(Message quoted) {
  final c = quoted.content;
  if (c is TextContent) {
    return {
      'contentType': 'text',
      'data': {'text': c.text, 'mentions': <Map<String, dynamic>>[]},
    };
  }
  if (c is EmojiContent) {
    return {
      'contentType': 'emoji',
      'data': {
        'emoji': c.emoji,
        'description': '',
        'attributes': <String, String>{},
      },
    };
  }
  if (c is StickerContent) {
    return {
      'contentType': 'sticker',
      'data': {
        'stickerId': c.stickerId,
        'packageId': c.packageId ?? '',
        'url': c.url ?? '',
        'width': c.width ?? 0,
        'height': c.height ?? 0,
        'format': 'webp',
        'attributes': <String, String>{},
      },
    };
  }
  final preview = c.previewText.trim().isEmpty ? '[消息]' : c.previewText;
  return {
    'contentType': 'text',
    'data': {'text': preview, 'mentions': <Map<String, dynamic>>[]},
  };
}

class MessageService {
  final IMessageRepository _repo;

  MessageService(this._repo);

  Future<List<Message>> getMessages({
    required String conversationId,
    int? beforeSeq,
    required int limit,
  }) {
    return _repo.getMessages(
      conversationId: conversationId,
      beforeSeq: beforeSeq,
      limit: limit,
    );
  }

  Future<List<Message>> openConversationTimeline({
    required String conversationId,
    required int limit,
  }) {
    return _repo.openConversationTimeline(
      conversationId: conversationId,
      limit: limit,
    );
  }

  Future<void> syncMessages({
    required String conversationId,
    int lastSeq = 0,
    int limit = 50,
  }) {
    return _repo.syncMessages(
      conversationId: conversationId,
      lastSeq: lastSeq,
      limit: limit,
    );
  }

  /// 创建并返回实体（用于 UI）；发送请用 [sendPreparedMessage]
  Future<Message> createTextMessage(String conversationId, String text) async {
    final message = await _repo.createTextMessage(conversationId, text);
    return SdkModelMapper.messageFromCore(message);
  }

  /// 创建文本消息：同时返回 generated SDK 强类型消息供发送复用。
  Future<CreatedSdkMessage> createTextForSend(
    String conversationId,
    String text,
  ) async {
    final message = await _repo.createTextMessage(conversationId, text);
    return (
      message: SdkModelMapper.messageFromCore(message),
      sdkMessage: message,
    );
  }

  /// 引用回复：须提供已落库或可引用的 `quotedMessageId`（优先 [Message.serverId]，否则 [Message.clientMsgId]）。
  Future<CreatedSdkMessage> createQuoteForSend(
    String conversationId,
    String replyText,
    Message quoted,
  ) async {
    final qid = quoted.serverId.trim().isNotEmpty
        ? quoted.serverId.trim()
        : quoted.clientMsgId.trim();
    if (qid.isEmpty) {
      throw StateError('quoted message has no serverId or clientMsgId');
    }
    final preview = quoted.content.previewText.trim().isEmpty
        ? '[消息]'
        : quoted.content.previewText;
    final params = <String, dynamic>{
      'conversationId': conversationId,
      'quotedMessageId': qid,
      'text': replyText,
      'quotedTextPreview': preview,
      'quotedContent': quotedContentShellForMessage(quoted),
    };
    final sid = quoted.senderId.trim();
    if (sid.isNotEmpty) {
      params['quotedSenderId'] = sid;
    }
    return _createByBuildOp('create_quote', params);
  }

  Future<Map<String, dynamic>> sendPreparedMessage(
    core.Message sdkMessage, {
    MessageSendEventCallback? onProgress,
    MessageSendEventCallback? onSuccess,
    MessageSendEventCallback? onFailure,
  }) {
    return _repo.sendCoreMessage(
      sdkMessage,
      onProgress: onProgress,
      onSuccess: onSuccess,
      onFailure: onFailure,
    );
  }

  Future<CreatedSdkMessage> _createByBuildOp(
    String op,
    Map<String, dynamic> params,
  ) async {
    final message = await _repo.messageBuild(op, params);
    return (
      message: SdkModelMapper.messageFromCore(message),
      sdkMessage: message,
    );
  }

  Future<CreatedSdkMessage> createMessageBuildForSend(
    String op,
    Map<String, dynamic> params,
  ) {
    return _createByBuildOp(op, params);
  }

  Future<CreatedSdkMessage> createEmojiForSend(
    String conversationId,
    String emoji,
  ) {
    return _createByBuildOp('create_emoji', {
      'conversationId': conversationId,
      'emoji': emoji,
    });
  }

  Future<CreatedSdkMessage> createStickerForSend({
    required String conversationId,
    required String stickerId,
    String? packageId,
    String? url,
    int? width,
    int? height,
    String? stickerFormat,
  }) {
    return _createByBuildOp('create_sticker', {
      'conversationId': conversationId,
      'stickerId': stickerId,
      if (packageId != null && packageId.isNotEmpty) 'packageId': packageId,
      if (url != null && url.isNotEmpty) 'url': url,
      if (width != null && width > 0) 'width': width,
      if (height != null && height > 0) 'height': height,
      if (stickerFormat != null && stickerFormat.isNotEmpty)
        'format': stickerFormat,
    });
  }

  Future<CreatedSdkMessage> createImageForSend(
    String conversationId,
    String imagePathOrFileId,
  ) {
    return _createByBuildOp('create_image', {
      'conversationId': conversationId,
      'imageId': imagePathOrFileId,
    });
  }

  Future<CreatedSdkMessage> createVideoForSend(
    String conversationId,
    String videoPathOrFileId,
  ) {
    return _createByBuildOp('create_video', {
      'conversationId': conversationId,
      'videoId': videoPathOrFileId,
    });
  }

  Future<CreatedSdkMessage> createAudioForSend(
    String conversationId,
    String audioPathOrFileId,
  ) {
    return _createByBuildOp('create_audio', {
      'conversationId': conversationId,
      'audioId': audioPathOrFileId,
    });
  }

  Future<CreatedSdkMessage> createFileForSend(
    String conversationId,
    String filePathOrFileId,
  ) {
    return _createByBuildOp('create_file', {
      'conversationId': conversationId,
      'fileId': filePathOrFileId,
    });
  }

  Future<CreatedSdkMessage> createRichDocForSend({
    required String conversationId,
    required String format,
    required String source,
  }) async {
    final normalized = await _normalizeRichDocSource(
      format: format,
      source: source,
    );
    final docJson = (normalized['docJson'] ?? '').toString().trim();
    if (docJson.isEmpty) {
      throw StateError('rich doc normalization returned empty docJson');
    }
    return _createByBuildOp('create_rich_doc', {
      'conversationId': conversationId,
      'docJson': docJson,
    });
  }

  Future<RichDocContent> editRichDocByMessageId({
    required String messageId,
    required String format,
    required String source,
  }) async {
    final id = messageId.trim();
    if (id.isEmpty) throw StateError('rich doc message id is empty');
    final normalized = await _normalizeRichDocSource(
      format: format,
      source: source,
    );
    final docJson = (normalized['docJson'] ?? '').toString().trim();
    if (docJson.isEmpty) {
      throw StateError('rich doc normalization returned empty docJson');
    }
    await _repo.editRichDocByMessageId(messageId: id, docJson: docJson);
    final plain = (normalized['plainText'] ?? normalized['searchText'] ?? '')
        .toString()
        .trim();
    return RichDocContent(
      docJson: docJson,
      plainText: plain.isNotEmpty ? plain : '[富文本]',
      sourceFormat: (normalized['inputFormat'] ?? format).toString(),
    );
  }

  Future<Map<String, dynamic>> _normalizeRichDocSource({
    required String format,
    required String source,
  }) {
    final f = format.trim().toLowerCase();
    final s = source.trim();
    if (s.isEmpty) {
      throw StateError('rich doc source is empty');
    }
    return switch (f) {
      'markdown' => _repo.normalizeRichDocFromMarkdown(s),
      'html' => _repo.normalizeRichDocFromHtml(s),
      'docjson' || 'json' => _repo.normalizeRichDocFromDocJson(s),
      _ => throw StateError('unsupported rich doc format: $format'),
    };
  }

  Future<CreatedSdkMessage> createLocationForSend({
    required String conversationId,
    required double latitude,
    required double longitude,
    String? title,
    String? address,
    int? zoom,
    String? snapshotUrl,
    String? snapshotLocalPath,
  }) {
    final params = <String, dynamic>{
      'conversationId': conversationId,
      'latitude': latitude,
      'longitude': longitude,
    };
    final t = title?.trim() ?? '';
    final a = address?.trim() ?? '';
    final s = snapshotUrl?.trim() ?? '';
    final sp = snapshotLocalPath?.trim() ?? '';
    if (t.isNotEmpty) params['title'] = t;
    if (a.isNotEmpty) params['address'] = a;
    if (zoom != null) params['zoom'] = zoom;
    if (s.isNotEmpty) params['snapshotUrl'] = s;
    if (sp.isNotEmpty) params['snapshotLocalPath'] = sp;
    return _createByBuildOp('create_location', params);
  }

  Future<CreatedSdkMessage> createCardForSend({
    required String conversationId,
    required String id,
    String? cardType,
    String? title,
    String? subtitle,
    String? avatar,
  }) {
    return _createByBuildOp('create_card', {
      'conversationId': conversationId,
      'id': id,
      if (cardType != null && cardType.trim().isNotEmpty)
        'cardType': cardType.trim(),
      if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
      if (subtitle != null && subtitle.trim().isNotEmpty)
        'subtitle': subtitle.trim(),
      if (avatar != null && avatar.trim().isNotEmpty) 'avatar': avatar.trim(),
    });
  }

  Future<CreatedSdkMessage> createTaskForSend({
    required String conversationId,
    required String taskId,
    required String title,
    String? status,
    List<String>? participantUserIds,
  }) {
    return _createByBuildOp('create_task', {
      'conversationId': conversationId,
      'taskId': taskId,
      'title': title,
      if (status != null && status.trim().isNotEmpty) 'status': status.trim(),
      if (participantUserIds != null && participantUserIds.isNotEmpty)
        'participantUserIds': participantUserIds,
    });
  }

  Future<CreatedSdkMessage> createScheduleForSend({
    required String conversationId,
    required String scheduleId,
    required String title,
    required int startTimeMs,
    required int endTimeMs,
    List<String>? participantUserIds,
  }) {
    return _createByBuildOp('create_schedule', {
      'conversationId': conversationId,
      'scheduleId': scheduleId,
      'title': title,
      'startTimeMs': startTimeMs,
      'endTimeMs': endTimeMs,
      if (participantUserIds != null && participantUserIds.isNotEmpty)
        'participantUserIds': participantUserIds,
    });
  }

  Future<void> recallMessage(String conversationId, String messageId) {
    return _repo.recallMessage(conversationId, messageId);
  }

  Future<void> deleteMessage(String conversationId, String messageId) {
    return _repo.deleteMessage(conversationId, messageId);
  }

  Future<void> deleteForSelf(String messageId, {String? reason}) async {
    await _repo.messageDispatch('delete_for_self', {
      'messageId': messageId,
      'reason': ?reason,
    });
  }

  Future<void> deleteForEveryone(String messageId, {String? reason}) async {
    await _repo.messageDispatch('delete_for_everyone', {
      'messageId': messageId,
      'reason': ?reason,
    });
  }

  Future<void> editTextByMessageId(String messageId, String text) async {
    await _repo.messageDispatch('edit_text_by_message_id', {
      'messageId': messageId,
      'text': text,
    });
  }

  Future<void> setTyping(String conversationId, bool typing) async {
    try {
      await _repo.messageDispatch('typing', {
        'conversationId': conversationId,
        'isTyping': typing,
      });
    } catch (_) {
      // Typing is a non-blocking realtime control event and must not block input or sending.
    }
  }

  Future<List<Message>> searchMessages(
    String keyword, {
    String? conversationId,
    required List<core.MessageSearchKind> kinds,
    int limit = 50,
  }) {
    return _repo.searchMessages(
      keyword: keyword,
      conversationId: conversationId,
      kinds: kinds,
      limit: limit,
    );
  }

  Future<Message?> getMessageById(String messageId) async {
    return _repo.getMessageById(messageId);
  }

  Future<Map<String, dynamic>?> getRawMessageById(String messageId) async {
    final id = messageId.trim();
    if (id.isEmpty) return null;
    final m = await _repo.messageDispatch('get_raw', {'messageId': id});
    if (m.containsKey('serverId') || m.containsKey('clientMsgId')) {
      return m;
    }
    final value = m['value'];
    if (value is Map<String, dynamic>) return value;
    return null;
  }

  Future<void> addReaction(String messageId, String emoji) async {
    await _repo.messageDispatch('add_reaction', {
      'messageId': messageId,
      'emoji': emoji,
    });
  }

  Future<void> removeReaction(String messageId, String emoji) async {
    await _repo.messageDispatch('remove_reaction', {
      'messageId': messageId,
      'emoji': emoji,
    });
  }

  static const int messagePinScopeConversation = 0;
  static const int messagePinScopeSelf = 1;

  Future<void> pinByMessageId(
    String messageId, {
    int scope = messagePinScopeConversation,
  }) async {
    await _repo.messageDispatch('pin_by_message_id', {
      'messageId': messageId,
      'scope': scope,
    });
  }

  Future<void> unpinByMessageId(
    String messageId, {
    int scope = messagePinScopeConversation,
  }) async {
    await _repo.messageDispatch('unpin_by_message_id', {
      'messageId': messageId,
      'scope': scope,
    });
  }

  /// `markType`：1=重要 / 2=待办 / 3=完成 / 其它=自定义。
  Future<void> markByMessageId(
    String messageId, {
    int markType = 1,
    String color = '#FA8C16',
  }) async {
    await _repo.messageDispatch('mark_by_message_id', {
      'messageId': messageId,
      'markType': markType,
      'color': color,
    });
  }

  Future<void> unmarkByMessageId(String messageId, {int markType = 1}) async {
    await _repo.messageDispatch('unmark_by_message_id', {
      'messageId': messageId,
      'markType': markType,
    });
  }
}
