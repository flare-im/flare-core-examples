import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart' as core;
import 'package:flare_im/domain/entities/message.dart';
import 'package:flare_im/domain/repositories/i_message_repository.dart';
import 'package:flare_im/infrastructure/mappers/sdk_model_mapper.dart';
import 'package:flare_im/infrastructure/sdk/flare_core_sdk_wrapper.dart';

class MessageRepositoryImpl implements IMessageRepository {
  final SdkWrapper _sdk;

  MessageRepositoryImpl(this._sdk);

  @override
  Future<List<Message>> getMessages({
    required String conversationId,
    int? beforeSeq,
    required int limit,
  }) async {
    final messages = await _sdk.getMessages(
      conversationId: conversationId,
      beforeSeq: beforeSeq ?? 0,
      limit: limit,
    );
    return messages.map(SdkModelMapper.messageFromCore).toList();
  }

  @override
  Future<List<Message>> openConversationTimeline({
    required String conversationId,
    required int limit,
  }) async {
    final snapshot = await _sdk.openConversationTimeline(
      conversationId: conversationId,
      messageLimit: limit,
    );
    return snapshot.messages
        .map(SdkModelMapper.messageFromCore)
        .toList(growable: false);
  }

  @override
  Future<void> syncMessages({
    required String conversationId,
    int lastSeq = 0,
    int limit = 50,
  }) {
    return _sdk.syncMessages(conversationId, lastSeq: lastSeq, limit: limit);
  }

  @override
  Future<core.Message> createTextMessage(String conversationId, String text) {
    return _sdk.createTextMessage(conversationId: conversationId, text: text);
  }

  @override
  Future<Map<String, dynamic>> sendMessageJson(
    String messageJson, {
    MessageSendEventCallback? onProgress,
    MessageSendEventCallback? onSuccess,
    MessageSendEventCallback? onFailure,
  }) {
    return _sdk.sendMessage(
      messageJson,
      onProgress: onProgress,
      onSuccess: onSuccess,
      onFailure: onFailure,
    );
  }

  @override
  Future<Map<String, dynamic>> sendCoreMessage(
    core.Message message, {
    MessageSendEventCallback? onProgress,
    MessageSendEventCallback? onSuccess,
    MessageSendEventCallback? onFailure,
  }) {
    return _sdk.sendCoreMessage(
      message,
      onProgress: onProgress,
      onSuccess: onSuccess,
      onFailure: onFailure,
    );
  }

  @override
  Future<core.Message> messageBuild(String op, Map<String, dynamic> params) {
    return _sdk.messageBuild({'op': op, ...params});
  }

  @override
  Future<Map<String, dynamic>> normalizeRichDocFromMarkdown(String markdown) {
    return _sdk.normalizeRichDocFromMarkdown(markdown);
  }

  @override
  Future<Map<String, dynamic>> normalizeRichDocFromHtml(String html) {
    return _sdk.normalizeRichDocFromHtml(html);
  }

  @override
  Future<Map<String, dynamic>> normalizeRichDocFromDocJson(String docJson) {
    return _sdk.normalizeRichDocFromDocJson(docJson);
  }

  @override
  Future<void> editRichDocByMessageId({
    required String messageId,
    required String docJson,
  }) async {
    await _sdk.messageCommandJson('edit_rich_doc_by_message_id', {
      'messageId': messageId,
      'docJson': docJson,
    });
  }

  @override
  Future<void> recallMessage(String conversationId, String messageId) {
    return _sdk.messageRecall(conversationId, messageId);
  }

  @override
  Future<void> deleteMessage(String conversationId, String messageId) {
    return _sdk.messageDelete(conversationId, messageId);
  }

  @override
  Future<Map<String, dynamic>> messageDispatch(
    String op,
    Map<String, dynamic> params,
  ) {
    return _sdk.messageDispatchJson(op, params);
  }

  @override
  Future<Message?> getMessageById(String messageId) async {
    final id = messageId.trim();
    if (id.isEmpty) return null;
    final message = await _sdk.getMessage({'messageId': id});
    if (message.serverId.trim().isEmpty && message.clientMsgId.trim().isEmpty) {
      return null;
    }
    return SdkModelMapper.messageFromCore(message);
  }

  @override
  Future<List<Message>> searchMessages({
    required String keyword,
    String? conversationId,
    required List<core.MessageSearchKind> kinds,
    int limit = 50,
  }) async {
    final messages = await _sdk.searchMessages(
      keyword: keyword,
      conversationId: conversationId,
      kinds: kinds,
      limit: limit,
    );
    return messages.map(SdkModelMapper.messageFromCore).toList();
  }
}
