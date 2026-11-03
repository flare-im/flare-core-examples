import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart' as core;
import 'package:flare_im/domain/entities/conversation.dart';
import 'package:flare_im/domain/repositories/i_conversation_repository.dart';
import 'package:flare_im/domain/value_objects/conversation_filter.dart';
import 'package:flare_im/domain/value_objects/conversation_type.dart';
import 'package:flare_im/infrastructure/mappers/conversation_list_query_mapper.dart';
import 'package:flare_im/infrastructure/mappers/sdk_model_mapper.dart';
import 'package:flare_im/infrastructure/sdk/flare_core_sdk_wrapper.dart';

class ConversationRepositoryImpl implements IConversationRepository {
  final SdkWrapper _sdk;

  ConversationRepositoryImpl(this._sdk);

  @override
  Future<List<Conversation>> getConversations({
    ConversationFilter filter = ConversationFilter.all,
    String? keyword,
  }) async {
    final items = switch (filter) {
      ConversationFilter.archived =>
        await _sdk.getConversationsIncludingArchived(),
      _ => await _getFilteredConversations(filter, keyword),
    };

    var list = items.map(SdkModelMapper.conversationFromCore).toList();

    if (filter == ConversationFilter.archived) {
      list = list.where((c) => c.isArchived).toList();
    } else {
      list = list.where((c) => !c.isArchived).toList();
    }

    if (filter == ConversationFilter.muted) {
      list = list.where((c) => c.isMuted).toList();
    }

    return list;
  }

  Future<List<core.Conversation>> _getFilteredConversations(
    ConversationFilter filter,
    String? keyword,
  ) {
    final query = ConversationListQueryMapper.toSdkQuery(
      filter,
      keyword: keyword,
    );
    if (query == null && filter == ConversationFilter.all) {
      return _sdk.getConversations();
    }
    if (query != null) {
      return _sdk.getConversationsByQuery(query);
    }
    return _sdk.getConversations();
  }

  @override
  Future<Conversation?> getConversation(String conversationId) async {
    final c = await _sdk.getConversation(conversationId);
    if (c == null) return null;
    return SdkModelMapper.conversationFromCore(c);
  }

  @override
  Future<Conversation?> getConversationOne(
    String sourceId,
    ConversationType type,
  ) async {
    final c = await _sdk.getConversationOne(
      sourceId,
      conversationTypeTagForSdk(type),
    );
    return SdkModelMapper.conversationFromCore(c);
  }

  @override
  Future<Conversation?> getGroupConversationByUserIds(
    List<String> userIds, {
    String? displayName,
  }) async {
    final c = await _sdk.getGroupConversationByUserIds(
      userIds,
      displayName: displayName,
    );
    return SdkModelMapper.conversationFromCore(c);
  }

  @override
  Future<List<Conversation>> getMultipleConversations(
    List<String> conversationIds,
  ) async {
    final items = await _sdk.getMultipleConversations(conversationIds);
    return items.map(SdkModelMapper.conversationFromCore).toList();
  }

  @override
  Future<List<Conversation>> bootstrapHomeTimeline({
    int conversationLimit = 100,
  }) async {
    final snapshot = await _sdk.bootstrapHomeTimeline(
      conversationLimit: conversationLimit,
    );
    return snapshot.conversations
        .map(SdkModelMapper.conversationFromCore)
        .toList(growable: false);
  }

  @override
  Future<void> deleteConversation(String conversationId) {
    return _sdk.conversationDelete(conversationId);
  }

  @override
  Future<void> pinConversation(String conversationId, bool pinned) {
    return _sdk.conversationSetPinned(conversationId, pinned);
  }

  @override
  Future<void> markAsRead(String conversationId, int readSeq) {
    return _sdk.conversationMarkRead(conversationId, readSeq);
  }

  @override
  Future<void> syncConversation(String conversationId) {
    return _sdk.syncConversation(conversationId);
  }

  @override
  Future<void> updateDraft(String conversationId, String? draft) {
    return _sdk.conversationUpdateDraft(conversationId, draft);
  }

  @override
  Future<void> setMuted(String conversationId, bool muted) {
    return _sdk.conversationSetMuted(conversationId, muted);
  }

  @override
  Future<void> setArchived(String conversationId, bool archived) {
    return _sdk.conversationSetArchived(conversationId, archived);
  }

  @override
  Future<void> markUnread(String conversationId) {
    return _sdk.conversationMarkUnread(conversationId);
  }

  @override
  Future<void> clearLocalHistory(String conversationId) {
    return _sdk.clearLocalChatHistory(conversationId);
  }
}
