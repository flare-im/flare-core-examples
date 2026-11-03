import 'package:flare_im/domain/entities/conversation.dart';
import 'package:flare_im/domain/value_objects/conversation_filter.dart';
import 'package:flare_im/domain/value_objects/conversation_type.dart';

/// 会话仓库：`bindings/c` 会话 API 的直接映射
abstract class IConversationRepository {
  Future<List<Conversation>> getConversations({
    ConversationFilter filter = ConversationFilter.all,
    String? keyword,
  });

  Future<Conversation?> getConversation(String conversationId);

  /// 与 `ConversationApi::get_one` 对齐（如单聊 `sourceId` = 对方 userId）
  Future<Conversation?> getConversationOne(
    String sourceId,
    ConversationType type,
  );

  Future<Conversation?> getGroupConversationByUserIds(
    List<String> userIds, {
    String? displayName,
  });

  Future<List<Conversation>> getMultipleConversations(
    List<String> conversationIds,
  );

  Future<List<Conversation>> bootstrapHomeTimeline({int conversationLimit});

  Future<void> deleteConversation(String conversationId);

  Future<void> pinConversation(String conversationId, bool pinned);

  Future<void> markAsRead(String conversationId, int readSeq);

  /// `IMClient::sync_conversation`
  Future<void> syncConversation(String conversationId);

  Future<void> updateDraft(String conversationId, String? draft);

  Future<void> setMuted(String conversationId, bool muted);

  Future<void> setArchived(String conversationId, bool archived);

  Future<void> markUnread(String conversationId);

  Future<void> clearLocalHistory(String conversationId);
}
