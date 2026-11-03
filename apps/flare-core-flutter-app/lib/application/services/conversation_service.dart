import 'package:flare_im/domain/entities/conversation.dart';
import 'package:flare_im/domain/repositories/i_conversation_repository.dart';
import 'package:flare_im/domain/value_objects/conversation_filter.dart';
import 'package:flare_im/domain/value_objects/conversation_type.dart';

class ConversationService {
  final IConversationRepository _repo;

  ConversationService(this._repo);

  Future<List<Conversation>> getConversations({
    ConversationFilter filter = ConversationFilter.all,
    String? keyword,
  }) => _repo.getConversations(filter: filter, keyword: keyword);

  Future<Conversation?> getConversation(String id) => _repo.getConversation(id);

  Future<Conversation?> getConversationOne(
    String sourceId,
    ConversationType type,
  ) => _repo.getConversationOne(sourceId, type);

  Future<Conversation?> getGroupConversationByUserIds(
    List<String> userIds, {
    String? displayName,
  }) => _repo.getGroupConversationByUserIds(userIds, displayName: displayName);

  Future<List<Conversation>> getMultipleConversations(
    List<String> conversationIds,
  ) => _repo.getMultipleConversations(conversationIds);

  Future<List<Conversation>> bootstrapHomeTimeline({
    int conversationLimit = 100,
  }) => _repo.bootstrapHomeTimeline(conversationLimit: conversationLimit);

  Future<void> deleteConversation(String id) => _repo.deleteConversation(id);

  Future<void> pinConversation(String id, bool pinned) =>
      _repo.pinConversation(id, pinned);

  Future<void> markAsRead(String id, int readSeq) =>
      _repo.markAsRead(id, readSeq);

  Future<void> syncConversation(String conversationId) =>
      _repo.syncConversation(conversationId);

  Future<void> updateDraft(String id, String? draft) =>
      _repo.updateDraft(id, draft);

  Future<void> setMuted(String id, bool muted) => _repo.setMuted(id, muted);

  Future<void> setArchived(String id, bool archived) =>
      _repo.setArchived(id, archived);

  Future<void> markUnread(String id) => _repo.markUnread(id);

  Future<void> clearLocalHistory(String id) => _repo.clearLocalHistory(id);
}
