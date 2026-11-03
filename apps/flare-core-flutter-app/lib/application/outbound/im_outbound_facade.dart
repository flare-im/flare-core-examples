import 'dart:async';

import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart' as core;
import 'package:flare_im/application/bus/event_bus.dart';
import 'package:flare_im/application/providers/auth_state_provider.dart';
import 'package:flare_im/application/providers/conversation_state_provider.dart';
import 'package:flare_im/application/providers/message_state_provider.dart';
import 'package:flare_im/application/providers/sdk_provider.dart';
import 'package:flare_im/application/providers/sdk_runtime_status_provider.dart';
import 'package:flare_im/application/providers/service_providers.dart';
import 'package:flare_im/application/services/message_service.dart';
import 'package:flare_im/domain/entities/conversation.dart';
import 'package:flare_im/domain/entities/message.dart';
import 'package:flare_im/domain/value_objects/conversation_type.dart';
import 'package:flare_im/domain/value_objects/transport_mode.dart';
import 'package:flare_im/infrastructure/mappers/sdk_model_mapper.dart';
import 'package:flare_im/infrastructure/sdk/flare_core_sdk_wrapper.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// **UI → SDK / 应用层唯一写入口**（与下行 `SDK → EventBus → Riverpod` 对称）。
///
/// `interface/` 内禁止再 `read(messageServiceProvider)`、`read(messageProvider().notifier)` 等散落调用；
/// 只保留 `watch` 订阅状态 + 经本类发起变更。
class ImOutboundFacade {
  ImOutboundFacade(this._ref);

  static const _chatMessageSyncTimeout = Duration(seconds: 4);
  static const _chatMarkReadTimeout = Duration(seconds: 3);

  final Ref _ref;

  bool get authSdkInitialized =>
      _ref.read(authServiceProvider).isSdkInitialized;

  MessageListNotifier _messages(String conversationId) =>
      _ref.read(messageProvider(conversationId.trim()).notifier);

  ConversationListNotifier get _conversations =>
      _ref.read(conversationProvider.notifier);

  SdkWrapper get _sdk => _ref.read(sdkWrapperProvider);

  // --- 认证 / SDK 生命周期 ---

  Future<void> authEnsureSdkInitialized({
    required String wsUrl,
    required SdkTransportMode transportMode,
    required String quicUrl,
    required String tenantId,
    required String httpUrl,
    String? tlsCaCertPath,
    String? tlsCaCert,
    String? dataUrl,
  }) async {
    _ref.read(sdkRuntimeStatusProvider.notifier).applyLifecycle({
      'event': 'initializing',
      'operation': 'sdk.init',
    });
    try {
      final auth = _ref.read(authServiceProvider);
      await auth.initSdk(
        wsUrl: wsUrl,
        transportMode: transportMode,
        quicUrl: quicUrl,
        tenantId: tenantId,
        httpUrl: httpUrl,
        tlsCaCertPath: tlsCaCertPath,
        tlsCaCert: tlsCaCert,
        dataUrl: dataUrl,
      );
      _ref.read(sdkRuntimeStatusProvider.notifier).applyLifecycle({
        'event': 'initialized',
        'operation': 'sdk.init',
      });
    } catch (e) {
      _ref.read(sdkRuntimeStatusProvider.notifier).markFailure('$e');
      rethrow;
    }
  }

  Future<void> authLogin(String userId, [String? token]) async {
    try {
      await _ref.read(currentUserProvider.notifier).login(userId, token);
      _ref.read(sdkRuntimeStatusProvider.notifier).applyLifecycle({
        'event': 'loginSucceeded',
        'operation': 'sdk.login',
        'userId': userId,
      });
    } catch (e) {
      _ref.read(sdkRuntimeStatusProvider.notifier).markFailure('$e');
      rethrow;
    }
    await _ref.read(connectionStateProvider.notifier).refresh();
    try {
      _ref.read(sdkRuntimeStatusProvider.notifier).markConversationBootstrap();
      final count = await _loadConversationsFromCore(reason: 'login');
      debugPrint('authLogin conversation bootstrap count=$count');
      _ref
          .read(sdkRuntimeStatusProvider.notifier)
          .markReady(conversationCount: count);
    } catch (e, st) {
      _ref.read(sdkRuntimeStatusProvider.notifier).markFailure('$e');
      debugPrint('authLogin conversation bootstrap failed: $e\n$st');
    }
  }

  Future<int> _loadConversationsFromCore({required String reason}) async {
    final count = await _conversations.bootstrapHomeTimeline(
      conversationLimit: 100,
    );
    debugPrint('conversation bootstrapHomeTimeline ($reason) count=$count');
    return count;
  }

  Future<void> authLogout() => _ref.read(currentUserProvider.notifier).logout();

  // --- 会话列表 ---

  Future<void> conversationListReload() async {
    _ref.read(sdkRuntimeStatusProvider.notifier).markConversationBootstrap();
    try {
      final count = await _loadConversationsFromCore(reason: 'manual_reload');
      debugPrint('conversationListReload count=$count');
      _ref
          .read(sdkRuntimeStatusProvider.notifier)
          .markReady(conversationCount: count);
    } catch (e) {
      _ref.read(sdkRuntimeStatusProvider.notifier).markFailure('$e');
      rethrow;
    }
  }

  Future<Conversation?> conversationOpenSingleChat(String peerUserId) =>
      _conversations.openSingleChat(peerUserId);

  Future<Conversation?> conversationOpenGroupChat(
    List<String> userIds, {
    String? displayName,
  }) => _conversations.openGroupChat(userIds, displayName: displayName);

  Future<int> conversationBootstrapHomeTimeline({
    int conversationLimit = 100,
  }) => _conversations.bootstrapHomeTimeline(
    conversationLimit: conversationLimit,
  );

  /// 群 / 频道等：拉取后整表刷新。
  Future<Conversation?> conversationOpenOther(
    String sourceId,
    ConversationType type,
  ) async {
    final c = await _ref
        .read(conversationServiceProvider)
        .getConversationOne(sourceId, type);
    await _conversations.load();
    return c;
  }

  void conversationSetSelected(Conversation? conversation) {
    _ref.read(selectedConversationProvider.notifier).state = conversation;
  }

  Future<void> conversationPin(String conversationId, bool pinned) =>
      _conversations.pin(conversationId, pinned);

  Future<void> conversationSync(String conversationId) =>
      _conversations.syncConversation(conversationId);

  Future<void> conversationDelete(String conversationId) =>
      _conversations.delete(conversationId);

  Future<void> conversationSetMuted(String conversationId, bool muted) =>
      _conversations.setMuted(conversationId, muted);

  Future<void> conversationSetArchived(String conversationId, bool archived) =>
      _conversations.setArchived(conversationId, archived);

  Future<void> conversationMarkUnread(String conversationId) =>
      _conversations.markUnread(conversationId);

  Future<void> conversationClearLocalHistory(String conversationId) =>
      _conversations.clearLocalHistory(conversationId);

  Future<List<Message>> searchMessagesGlobal(
    String keyword, {
    required List<core.MessageSearchKind> kinds,
    int limit = 50,
  }) {
    return _ref
        .read(messageServiceProvider)
        .searchMessages(keyword, kinds: kinds, limit: limit);
  }

  // --- 聊天页：消息与草稿 ---

  Future<void> chatEnterLoadAndMarkRead(String conversationId) async {
    final cid = conversationId.trim();
    final m = _messages(cid);
    await _syncTimelineFromServer(m, cid, reason: 'chat_enter_prefetch');
    await _openTimelineView(cid, reason: 'chat_enter');
    await _markReadBestEffort(m, cid, reason: 'chat_enter');
  }

  Future<void> _openTimelineView(
    String conversationId, {
    required String reason,
  }) async {
    final cid = conversationId.trim();
    if (cid.isEmpty) return;
    final sdk = _sdk;
    if (!sdk.isInitialized) return;
    try {
      final response = await sdk
          .openTimelineView(conversationId: cid, messageLimit: 50)
          .timeout(const Duration(seconds: 3));
      _applyViewOpenResponse(response);
    } catch (e, st) {
      debugPrint('openTimelineView failed ($reason/$cid): $e\n$st');
    }
  }

  void _applyViewOpenResponse(core.ViewOpenResponse response) {
    final snapshot = response.snapshot;
    final data = snapshot.data;
    if (snapshot.viewType == 'conversationList' &&
        data is core.HomeTimelineSnapshot) {
      _conversations.applyCoreSnapshot(
        SdkModelMapper.conversationsFromCoreHomeTimeline(data),
      );
      return;
    }
    if (snapshot.viewType == 'timeline' &&
        data is core.TimelineViewSnapshot) {
      final messages = SdkModelMapper.messagesFromCoreTimelineView(data);
      final conversationId = SdkModelMapper.conversationIdFromCoreTimelineView(
        data,
        messages,
      );
      if (conversationId.isNotEmpty) {
        timelineViews[response.viewId] = (
          conversationId: conversationId,
          revision: response.revision,
        );
        _messages(conversationId).applyCoreSnapshot(messages);
      }
    }
  }

  Future<void> chatLoadMore(String conversationId) =>
      _messages(conversationId).loadMore();

  Future<void> chatPullServerAndMarkRead(String conversationId) async {
    final m = _messages(conversationId);
    await _syncTimelineFromServer(m, conversationId, reason: 'chat_pull');
    await _openTimelineView(conversationId, reason: 'chat_pull');
    await _markReadBestEffort(m, conversationId, reason: 'chat_pull');
  }

  Future<void> chatPullServer(String conversationId) async {
    final m = _messages(conversationId);
    await _syncTimelineFromServer(
      m,
      conversationId,
      reason: 'foreground_refresh',
    );
    await _openTimelineView(conversationId, reason: 'foreground_refresh');
  }

  Future<void> _syncTimelineFromServer(
    MessageListNotifier messages,
    String conversationId, {
    required String reason,
  }) async {
    final cid = conversationId.trim();
    if (cid.isEmpty) return;
    try {
      await messages.refreshFromServer().timeout(_chatMessageSyncTimeout);
    } catch (e, st) {
      debugPrint('syncTimelineFromServer failed ($reason/$cid): $e\n$st');
    }
  }

  Future<void> _markReadBestEffort(
    MessageListNotifier messages,
    String conversationId, {
    required String reason,
  }) async {
    final cid = conversationId.trim();
    if (cid.isEmpty) return;
    try {
      await messages.markFullyReadAtTop().timeout(_chatMarkReadTimeout);
    } catch (e, st) {
      debugPrint('markReadBestEffort failed ($reason/$cid): $e\n$st');
      _conversations.applyUnreadPatch(cid, 0);
    }
  }

  Future<void> chatSyncConversationMeta(String conversationId) =>
      _conversations.syncConversation(conversationId);

  Future<List<Message>> chatSearchInServer(
    String conversationId,
    String keyword, {
    required List<core.MessageSearchKind> kinds,
  }) => _messages(conversationId).searchInServer(keyword, kinds: kinds);

  Future<void> chatSendTextAndClearDraft(
    String conversationId,
    String text,
  ) async {
    await _messages(conversationId).sendText(text);
    unawaited(_conversations.saveDraft(conversationId, null));
  }

  Future<void> chatSendQuoteTextAndClearDraft(
    String conversationId,
    String text,
    Message quoted,
  ) async {
    await _messages(conversationId).sendQuoteText(text, quoted);
    unawaited(_conversations.saveDraft(conversationId, null));
  }

  Future<void> chatSendLocation(
    String conversationId, {
    required double latitude,
    required double longitude,
    String? title,
    String? address,
    int? zoom,
    String? snapshotUrl,
    String? snapshotLocalPath,
  }) {
    return _messages(conversationId).sendLocation(
      latitude: latitude,
      longitude: longitude,
      title: title,
      address: address,
      zoom: zoom,
      snapshotUrl: snapshotUrl,
      snapshotLocalPath: snapshotLocalPath,
    );
  }

  Future<void> chatSendContactCard(
    String conversationId, {
    required String id,
    String? cardType,
    String? title,
    String? subtitle,
    String? avatar,
  }) {
    return _messages(conversationId).sendContactCard(
      id: id,
      cardType: cardType,
      title: title,
      subtitle: subtitle,
      avatar: avatar,
    );
  }

  Future<void> chatSendTask(
    String conversationId, {
    required String taskId,
    required String title,
    String? status,
    List<String>? participantUserIds,
  }) {
    return _messages(conversationId).sendTask(
      taskId: taskId,
      title: title,
      status: status,
      participantUserIds: participantUserIds,
    );
  }

  Future<void> chatSendSchedule(
    String conversationId, {
    required String scheduleId,
    required String title,
    required int startTimeMs,
    required int endTimeMs,
    List<String>? participantUserIds,
  }) {
    return _messages(conversationId).sendSchedule(
      scheduleId: scheduleId,
      title: title,
      startTimeMs: startTimeMs,
      endTimeMs: endTimeMs,
      participantUserIds: participantUserIds,
    );
  }

  Future<void> chatSendMessageBuild(
    String conversationId,
    String op,
    Map<String, dynamic> params,
  ) {
    return _messages(conversationId).sendMessageBuild(op, params);
  }

  Future<void> chatSendRichDoc(
    String conversationId, {
    required String format,
    required String source,
  }) {
    return _messages(
      conversationId,
    ).sendRichDoc(format: format, source: source);
  }

  Future<void> chatForwardMessages(
    String conversationId, {
    required List<String> messageIds,
    required bool merge,
    required String title,
  }) {
    return _messages(
      conversationId,
    ).forwardMessages(messageIds: messageIds, merge: merge, title: title);
  }

  Future<void> chatPinMessage(
    String messageId, {
    int scope = MessageService.messagePinScopeConversation,
  }) =>
      _ref.read(messageServiceProvider).pinByMessageId(messageId, scope: scope);

  Future<void> chatPinMessageForSelf(String messageId) =>
      chatPinMessage(messageId, scope: MessageService.messagePinScopeSelf);

  Future<void> chatUnpinMessage(
    String messageId, {
    int scope = MessageService.messagePinScopeConversation,
  }) => _ref
      .read(messageServiceProvider)
      .unpinByMessageId(messageId, scope: scope);

  Future<void> chatMarkMessageImportant(String messageId) =>
      _ref.read(messageServiceProvider).markByMessageId(messageId, markType: 1);

  Future<void> chatEditOwnText(
    String conversationId,
    String serverMessageId,
    String newText,
  ) => _messages(conversationId).editOwnText(serverMessageId, newText);

  Future<void> chatEditOwnRichDoc(
    String conversationId,
    String serverMessageId, {
    required String format,
    required String source,
  }) => _messages(conversationId).editOwnRichDoc(
    serverMessageId: serverMessageId,
    format: format,
    source: source,
  );

  Future<void> chatRecall(String conversationId, String serverMessageId) =>
      _messages(conversationId).recall(serverMessageId);

  Future<void> chatResendFailedText(
    String conversationId,
    String clientMsgId,
  ) => _messages(conversationId).resendFailedText(clientMsgId);

  Future<void> chatDeleteByServerId(
    String conversationId,
    String serverMessageId,
  ) => _messages(conversationId).deleteByServerId(serverMessageId);

  Future<void> chatDeleteForSelf(
    String conversationId,
    String serverMessageId,
  ) => _messages(conversationId).deleteForSelf(serverMessageId);

  Future<void> chatDeleteForEveryone(
    String conversationId,
    String serverMessageId,
  ) => _messages(conversationId).deleteForEveryone(serverMessageId);

  Future<void> chatAddReaction(
    String conversationId,
    String serverMessageId,
    String emoji,
  ) => _messages(conversationId).addReaction(serverMessageId, emoji);

  Future<void> chatRemoveReaction(
    String conversationId,
    String serverMessageId,
    String emoji,
  ) => _messages(conversationId).removeReaction(serverMessageId, emoji);

  Future<void> chatSetTyping(String conversationId, bool isTyping) =>
      _ref.read(messageServiceProvider).setTyping(conversationId, isTyping);

  Future<void> chatSubscribeUserPresence(List<String> userIds) =>
      _ref.read(sdkWrapperProvider).subscribeUserPresence(userIds);

  Future<Map<String, dynamic>> chatBatchGetUserPresence(List<String> userIds) =>
      _ref.read(sdkWrapperProvider).batchGetUserPresence(userIds);

  Future<void> chatSaveDraft(String conversationId, String? draft) =>
      _conversations.saveDraft(conversationId, draft);
}
