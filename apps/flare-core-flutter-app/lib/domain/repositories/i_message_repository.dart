import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart' as core;
import 'package:flare_im/domain/entities/message.dart';

typedef MessageSendEventCallback = void Function(Map<String, dynamic> payload);

/// 消息仓库：`flare_message_*` + `flare_message_dispatch_json` 能力
abstract class IMessageRepository {
  /// [beforeSeq] 为 `null` 时传 `0` 给 SDK（会话首屏）；翻页传当前列表中已有消息的最小 `seq`（须 `> 0`）。
  Future<List<Message>> getMessages({
    required String conversationId,
    int? beforeSeq,
    required int limit,
  });

  Future<List<Message>> openConversationTimeline({
    required String conversationId,
    required int limit,
  });

  /// `IMClient::sync_messages`
  Future<void> syncMessages({
    required String conversationId,
    int lastSeq = 0,
    int limit = 50,
  });

  /// 创建文本消息（返回 generated SDK 强类型消息）
  Future<core.Message> createTextMessage(String conversationId, String text);

  /// 发送已由 SDK 构建的消息 JSON
  Future<Map<String, dynamic>> sendMessageJson(
    String messageJson, {
    MessageSendEventCallback? onProgress,
    MessageSendEventCallback? onSuccess,
    MessageSendEventCallback? onFailure,
  });

  /// 发送 generated SDK 强类型消息；业务路径不再把 Message 转 JSON 后送回 SDK。
  Future<Map<String, dynamic>> sendCoreMessage(
    core.Message message, {
    MessageSendEventCallback? onProgress,
    MessageSendEventCallback? onSuccess,
    MessageSendEventCallback? onFailure,
  });

  /// 调用 generated message builder 构建非文本消息（emoji/sticker/image/video/audio/file 等）
  Future<core.Message> messageBuild(String op, Map<String, dynamic> params);

  Future<Map<String, dynamic>> normalizeRichDocFromMarkdown(String markdown);

  Future<Map<String, dynamic>> normalizeRichDocFromHtml(String html);

  Future<Map<String, dynamic>> normalizeRichDocFromDocJson(String docJson);

  Future<void> editRichDocByMessageId({
    required String messageId,
    required String docJson,
  });

  Future<void> recallMessage(String conversationId, String messageId);

  Future<void> deleteMessage(String conversationId, String messageId);

  /// `flare_message_dispatch_json`: `op` uses generated core dispatch ids, e.g. `search`, `edit_text_by_message_id`.
  Future<Map<String, dynamic>> messageDispatch(
    String op,
    Map<String, dynamic> params,
  );

  /// `messages.getMessage` generated typed path.
  Future<Message?> getMessageById(String messageId);

  /// `messages.search` / `search_by_query` / `search_in_conversation`
  Future<List<Message>> searchMessages({
    required String keyword,
    String? conversationId,
    required List<core.MessageSearchKind> kinds,
    int limit = 50,
  });
}
