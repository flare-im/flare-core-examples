import 'dart:async';
import 'dart:convert';

import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart' as core;
import 'package:flare_im/application/bus/event_bus.dart';
import 'package:flare_im/application/providers/auth_state_provider.dart';
import 'package:flare_im/application/providers/conversation_state_provider.dart';
import 'package:flare_im/application/providers/service_providers.dart';
import 'package:flare_im/application/services/message_service.dart';
import 'package:flare_im/domain/entities/message.dart';
import 'package:flare_im/domain/value_objects/conversation_type.dart';
import 'package:flare_im/domain/value_objects/message_content.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 单会话消息列表（分页由 [MessageListNotifier.loadMore] 维护）；IM 下行只经 EventBus 写入，UI 不触 SDK。
final messageProvider =
    StateNotifierProvider.family<MessageListNotifier, List<Message>, String>((
      ref,
      conversationId,
    ) {
      final messageService = ref.watch(messageServiceProvider);
      return MessageListNotifier(ref, messageService, conversationId.trim());
    });

String _safeJsonForLog(Object? value) {
  try {
    return jsonEncode(value);
  } catch (_) {
    return value.toString();
  }
}

class MessageListNotifier extends StateNotifier<List<Message>> {
  MessageListNotifier(this._ref, this._messageService, String conversationId)
    : conversationId = conversationId.trim(),
      super([]);

  static const Duration _sendUiTimeout = Duration(seconds: 30);
  static const Duration _ackSmoothStep = Duration(milliseconds: 45);
  static const int _ackSmoothMaxSlots = 8;
  static const List<Duration> _transientSendRetryDelays = [
    Duration(milliseconds: 300),
    Duration(milliseconds: 700),
    Duration(milliseconds: 1200),
    Duration(milliseconds: 2400),
    Duration(milliseconds: 4000),
  ];

  final Ref _ref;
  final MessageService _messageService;

  /// 已 trim，与路由/SDK 对齐。
  final String conversationId;
  final Map<String, Timer> _sendTimeouts = {};
  final Map<String, Timer> _ackSmoothTimers = {};
  Timer? _ackSmoothResetTimer;
  int _ackSmoothSlot = 0;
  int _localPendingCounter = 0;

  @override
  void dispose() {
    for (final timer in _sendTimeouts.values) {
      timer.cancel();
    }
    for (final timer in _ackSmoothTimers.values) {
      timer.cancel();
    }
    _ackSmoothResetTimer?.cancel();
    super.dispose();
  }

  Future<void> load({int limit = 50}) async {
    final messages = await _messageService.getMessages(
      conversationId: conversationId,
      limit: limit,
    );
    _replaceWithCoreSnapshot(messages);
  }

  Future<void> openTimeline({int limit = 50}) async {
    final messages = await _messageService.openConversationTimeline(
      conversationId: conversationId,
      limit: limit,
    );
    _replaceWithCoreSnapshot(messages);
  }

  void applyCoreSnapshot(List<Message> snapshot) {
    final fetched = snapshot
        .where((message) => message.conversationId.trim() == conversationId)
        .toList(growable: false);
    _replaceWithCoreSnapshot(fetched);
  }

  void _replaceWithCoreSnapshot(List<Message> snapshot) {
    state = _reapplyPeerReadToMessages(
      _coreSnapshotPreservingUnresolvedLocal(snapshot),
    );
    _cancelResolvedSendTracking();
  }

  /// 核心时间线视图的增量：删 `remove` 里的行键，原位替换 `upsert`，`prepend` 放最前、
  /// `append` 放最后，再按时间线顺序排列（`reorder` 因此不用单独处理）。行键是
  /// clientMsgId，没有时 serverId，都没有时 `seq:<会话>:<seq>`，发送确认前后不变。
  void applyCoreTimelineDelta({
    List<Message> prepend = const [],
    List<Message> append = const [],
    List<Message> upsert = const [],
    List<String> remove = const [],
  }) {
    bool scoped(Message message) =>
        message.conversationId.trim() == conversationId;
    if (prepend.isEmpty && append.isEmpty && upsert.isEmpty && remove.isEmpty) {
      return;
    }
    final removed = remove.toSet();
    final upserts = {
      for (final message in upsert.where(scoped)) _rowKey(message): message,
    };
    final next = [
      ...prepend.where(scoped),
      for (final message in state)
        if (!removed.contains(_rowKey(message)))
          upserts[_rowKey(message)] ?? message,
      ...append.where(scoped),
    ];
    state = _reapplyPeerReadToMessages(_timelineDisplayOrder(next));
    _cancelResolvedSendTracking();
  }

  static String _rowKey(Message message) {
    if (message.clientMsgId.isNotEmpty) return message.clientMsgId;
    if (message.serverId.isNotEmpty) return message.serverId;
    return 'seq:${message.conversationId}:${message.seq}';
  }

  void mergeIncomingMessages(List<Message> incoming) {
    if (incoming.isEmpty) return;
    final scoped = incoming
        .where((message) => message.conversationId.trim() == conversationId)
        .toList(growable: false);
    if (scoped.isEmpty) return;

    final next = List<Message>.from(state);
    for (final message in scoped) {
      final existingIndex = _incomingMessageIndex(next, message);
      if (existingIndex >= 0) {
        next[existingIndex] = _mergeServerMessage(next[existingIndex], message);
      } else {
        next.add(message);
      }
    }

    state = _reapplyPeerReadToMessages(_timelineDisplayOrder(next));
    _cancelResolvedSendTracking();
  }

  bool containsClientMessage(String clientMsgId) {
    final id = clientMsgId.trim();
    if (id.isEmpty) return false;
    return state.any((message) => message.clientMsgId.trim() == id);
  }

  void applySendFailurePayload(Map<String, dynamic> failure) {
    final clientMsgId =
        (failure['clientMsgId'] ?? failure['client_msg_id'])
            ?.toString()
            .trim() ??
        '';
    if (clientMsgId.isEmpty) return;
    _applySendFailure(clientMsgId, failure);
  }

  /// 下行同步 + 重新拉取本地列表（`IMClient::sync_messages`）
  Future<void> refreshFromServer({int limit = 50}) async {
    final lastSeq = state.fold<int>(
      0,
      (current, message) => message.seq > current ? message.seq : current,
    );
    await _messageService.syncMessages(
      conversationId: conversationId,
      lastSeq: lastSeq,
      limit: limit,
    );
    await load(limit: limit);
  }

  /// 会话读位 + 列表未读清零（`conversation.mark_read`）
  Future<void> markFullyReadAtTop() async {
    if (state.isEmpty) {
      _ref
          .read(conversationProvider.notifier)
          .applyUnreadPatch(conversationId, 0);
      return;
    }
    final topSeq = state.fold<int>(
      0,
      (current, message) => message.seq > current ? message.seq : current,
    );
    if (topSeq > 0) {
      await _ref
          .read(conversationProvider.notifier)
          .markAsRead(conversationId, topSeq);
    } else {
      _ref
          .read(conversationProvider.notifier)
          .applyUnreadPatch(conversationId, 0);
    }
  }

  Future<void> loadMore({int limit = 50}) async {
    if (state.isEmpty) return;
    // state 是展示顺序：旧 -> 新。翻页要从最旧的已落库 seq 往前拉。
    var beforeSeq = 0;
    for (final m in state) {
      if (m.seq > 0) {
        beforeSeq = m.seq;
        break;
      }
    }
    if (beforeSeq <= 0) return;

    final messages = await _messageService.getMessages(
      conversationId: conversationId,
      beforeSeq: beforeSeq,
      limit: limit,
    );
    if (messages.isEmpty) return;

    final seenSeq = <int>{
      for (final m in state)
        if (m.seq > 0) m.seq,
    };
    final olderPage = <Message>[];
    for (final m in messages) {
      if (m.seq > 0 && seenSeq.contains(m.seq)) continue;
      if (m.seq > 0) seenSeq.add(m.seq);
      olderPage.add(m);
    }
    if (olderPage.isEmpty) return;
    state = _reapplyPeerReadToMessages(
      _timelineDisplayOrder([...olderPage, ...state]),
    );
    _cancelResolvedSendTracking();
  }

  Future<void> sendQuoteText(String text, Message quoted) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final buildConversationId = await _conversationIdForMessageBuild();
    final created = await _messageService.createQuoteForSend(
      buildConversationId,
      trimmed,
      quoted,
    );
    await _sendCreated(created: created);
  }

  Future<void> sendText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final pending = _createLocalTextPending(trimmed);
    state = _reapplyPeerReadToMessages(_withPendingMessage(state, pending));
    _watchSendTimeout(pending.clientMsgId);

    late final CreatedSdkMessage created;
    try {
      final buildConversationId = await _conversationIdForMessageBuild();
      created = await _messageService.createTextForSend(
        buildConversationId,
        trimmed,
      );
    } catch (error, stackTrace) {
      _logBuildException('sendText.build', error, stackTrace);
      _applySendFailure(pending.clientMsgId, {'reason': error.toString()});
      return;
    }

    final pendingStillSending = state.any(
      (m) =>
          m.clientMsgId == pending.clientMsgId &&
          m.status == MessageStatus.sending,
    );
    if (!pendingStillSending) return;

    var optimistic = created.message;
    final me = _ref.read(currentUserProvider)?.userId ?? '';
    if (me.isNotEmpty && optimistic.senderId.isEmpty) {
      optimistic = optimistic.copyWith(senderId: me);
    }
    _replacePendingMessage(pending.clientMsgId, optimistic);
    _cancelSendTimeout(pending.clientMsgId);
    _watchSendTimeout(optimistic.clientMsgId);

    try {
      final ack = await _sendPreparedWithTransientRetry(
        sdkMessage: created.sdkMessage,
        clientMsgId: optimistic.clientMsgId,
      );
      // C 层 `flare_message_send` 与 dispatch `send` 一致：返回 SendAck 对象（曾错误地传裸 clientMsgId 导致 jsonDecode 失败 -> 误判失败）。
      if (_isQueuedSendAck(ack)) {
        return;
      }
      if (ack['success'] == false) {
        _applySendFailure(optimistic.clientMsgId, ack);
        return;
      }
      applySendAck(ack);
    } catch (error, stackTrace) {
      _logSendException('sendText', optimistic.clientMsgId, error, stackTrace);
      _applySendFailure(optimistic.clientMsgId, {'reason': error.toString()});
    }
  }

  Message _createLocalTextPending(String text) {
    final now = DateTime.now();
    final user = _ref.read(currentUserProvider);
    final senderId = user?.userId.trim() ?? '';
    final displayName = (user?.displayName.trim().isNotEmpty ?? false)
        ? user!.displayName.trim()
        : senderId;
    final clientMsgId =
        'local:${now.microsecondsSinceEpoch}:${_localPendingCounter++}';
    return Message(
      serverId: '',
      clientMsgId: clientMsgId,
      conversationId: conversationId,
      senderId: senderId,
      seq: 0,
      timestamp: now,
      clientTimestamp: now,
      content: TextContent(text),
      status: MessageStatus.sending,
      source: MessageSource.local,
      timelineKey: 'client:$clientMsgId',
      senderName: displayName,
      senderAvatar: user?.avatar ?? '',
      senderDisplayName: displayName,
    );
  }

  void _replacePendingMessage(String pendingClientMsgId, Message replacement) {
    final pendingId = pendingClientMsgId.trim();
    if (pendingId.isEmpty) {
      state = _reapplyPeerReadToMessages(
        _withPendingMessage(state, replacement),
      );
      return;
    }

    var replaced = false;
    final next = state.map((m) {
      if (m.clientMsgId != pendingId) return m;
      replaced = true;
      return replacement;
    }).toList();
    state = _reapplyPeerReadToMessages(
      replaced
          ? _timelineDisplayOrder(next)
          : _withPendingMessage(state, replacement),
    );
  }

  Future<String> _conversationIdForMessageBuild() async {
    final cid = conversationId.trim();
    if (cid.isEmpty) return cid;

    var conversation = conversationById(_ref.read(conversationProvider), cid);
    final selected = _ref.read(selectedConversationProvider);
    if (selected != null && selected.conversationId.trim() == cid) {
      conversation ??= selected;
    }

    if (conversation == null) {
      try {
        conversation = await _ref
            .read(conversationServiceProvider)
            .getConversation(cid);
        if (conversation != null) {
          _ref.read(conversationProvider.notifier).upsert(conversation);
        }
      } catch (error, stackTrace) {
        _logBuildException('conversation.get', error, stackTrace);
      }
    }

    if (conversation?.conversationType == ConversationType.single) {
      final peerUserId = (conversation?.peerUserId ?? '').trim();
      if (peerUserId.isNotEmpty) {
        final resolved = await _ref
            .read(conversationProvider.notifier)
            .openSingleChat(peerUserId);
        final resolvedId = resolved?.conversationId.trim() ?? '';
        if (resolvedId.isNotEmpty) return resolvedId;
      }
    }

    return cid;
  }

  Future<void> _sendCreated({required CreatedSdkMessage created}) async {
    var optimistic = created.message;
    final me = _ref.read(currentUserProvider)?.userId ?? '';
    if (me.isNotEmpty && optimistic.senderId.isEmpty) {
      optimistic = optimistic.copyWith(senderId: me);
    }
    state = _reapplyPeerReadToMessages(_withPendingMessage(state, optimistic));
    _watchSendTimeout(optimistic.clientMsgId);

    try {
      final ack = await _sendPreparedWithTransientRetry(
        sdkMessage: created.sdkMessage,
        clientMsgId: optimistic.clientMsgId,
      );
      if (_isQueuedSendAck(ack)) {
        return;
      }
      if (ack['success'] == false) {
        _applySendFailure(optimistic.clientMsgId, ack);
        return;
      }
      applySendAck(ack);
    } catch (error, stackTrace) {
      _logSendException(
        'sendPreparedMessage',
        optimistic.clientMsgId,
        error,
        stackTrace,
      );
      _applySendFailure(optimistic.clientMsgId, {'reason': error.toString()});
    }
  }

  Future<void> sendEmoji(String emoji) async {
    final e = emoji.trim();
    if (e.isEmpty) return;
    final buildConversationId = await _conversationIdForMessageBuild();
    final created = await _messageService.createEmojiForSend(
      buildConversationId,
      e,
    );
    await _sendCreated(created: created);
  }

  Future<void> sendSticker({
    required String stickerId,
    String? packageId,
    String? url,
    int? width,
    int? height,
    String? stickerFormat,
  }) async {
    final sid = stickerId.trim();
    if (sid.isEmpty) return;
    final buildConversationId = await _conversationIdForMessageBuild();
    final created = await _messageService.createStickerForSend(
      conversationId: buildConversationId,
      stickerId: sid,
      packageId: packageId,
      url: url,
      width: width,
      height: height,
      stickerFormat: stickerFormat,
    );
    await _sendCreated(created: created);
  }

  Future<void> sendImageByPath(String path) async {
    final p = path.trim();
    if (p.isEmpty) return;
    final buildConversationId = await _conversationIdForMessageBuild();
    final created = await _messageService.createImageForSend(
      buildConversationId,
      p,
    );
    await _sendCreated(created: created);
  }

  Future<void> sendVideoByPath(String path) async {
    final p = path.trim();
    if (p.isEmpty) return;
    final buildConversationId = await _conversationIdForMessageBuild();
    final created = await _messageService.createVideoForSend(
      buildConversationId,
      p,
    );
    await _sendCreated(created: created);
  }

  Future<void> sendAudioByPath(String path) async {
    final p = path.trim();
    if (p.isEmpty) return;
    final buildConversationId = await _conversationIdForMessageBuild();
    final created = await _messageService.createAudioForSend(
      buildConversationId,
      p,
    );
    await _sendCreated(created: created);
  }

  Future<void> sendFileByPath(String path) async {
    final p = path.trim();
    if (p.isEmpty) return;
    final buildConversationId = await _conversationIdForMessageBuild();
    final created = await _messageService.createFileForSend(
      buildConversationId,
      p,
    );
    await _sendCreated(created: created);
  }

  Future<void> sendRichDoc({
    required String format,
    required String source,
  }) async {
    final s = source.trim();
    if (s.isEmpty) return;
    final buildConversationId = await _conversationIdForMessageBuild();
    final created = await _messageService.createRichDocForSend(
      conversationId: buildConversationId,
      format: format,
      source: s,
    );
    await _sendCreated(created: created);
  }

  Future<void> sendLocation({
    required double latitude,
    required double longitude,
    String? title,
    String? address,
    int? zoom,
    String? snapshotUrl,
    String? snapshotLocalPath,
  }) async {
    final buildConversationId = await _conversationIdForMessageBuild();
    final created = await _messageService.createLocationForSend(
      conversationId: buildConversationId,
      latitude: latitude,
      longitude: longitude,
      title: title,
      address: address,
      zoom: zoom,
      snapshotUrl: snapshotUrl,
      snapshotLocalPath: snapshotLocalPath,
    );
    await _sendCreated(created: created);
  }

  Future<void> sendContactCard({
    required String id,
    String? cardType,
    String? title,
    String? subtitle,
    String? avatar,
  }) async {
    final cardId = id.trim();
    if (cardId.isEmpty) return;
    final buildConversationId = await _conversationIdForMessageBuild();
    final created = await _messageService.createCardForSend(
      conversationId: buildConversationId,
      id: cardId,
      cardType: cardType,
      title: title,
      subtitle: subtitle,
      avatar: avatar,
    );
    await _sendCreated(created: created);
  }

  Future<void> sendTask({
    required String taskId,
    required String title,
    String? status,
    List<String>? participantUserIds,
  }) async {
    final tid = taskId.trim();
    final t = title.trim();
    if (tid.isEmpty || t.isEmpty) return;
    final buildConversationId = await _conversationIdForMessageBuild();
    final created = await _messageService.createTaskForSend(
      conversationId: buildConversationId,
      taskId: tid,
      title: t,
      status: status,
      participantUserIds: participantUserIds,
    );
    await _sendCreated(created: created);
  }

  Future<void> sendSchedule({
    required String scheduleId,
    required String title,
    required int startTimeMs,
    required int endTimeMs,
    List<String>? participantUserIds,
  }) async {
    final sid = scheduleId.trim();
    final t = title.trim();
    if (sid.isEmpty || t.isEmpty) return;
    final buildConversationId = await _conversationIdForMessageBuild();
    final created = await _messageService.createScheduleForSend(
      conversationId: buildConversationId,
      scheduleId: sid,
      title: t,
      startTimeMs: startTimeMs,
      endTimeMs: endTimeMs,
      participantUserIds: participantUserIds,
    );
    await _sendCreated(created: created);
  }

  Future<void> sendMessageBuild(String op, Map<String, dynamic> params) async {
    final buildConversationId = await _conversationIdForMessageBuild();
    final requestParams = <String, dynamic>{
      'conversationId': buildConversationId,
      ...params,
    };
    final created = await _messageService.createMessageBuildForSend(
      op,
      requestParams,
    );
    await _sendCreated(created: created);
  }

  Future<void> forwardMessages({
    required List<String> messageIds,
    required bool merge,
    required String title,
  }) async {
    final ids = messageIds
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
    if (ids.isEmpty) return;

    final sourceMessages = <Map<String, dynamic>>[];
    for (final id in ids) {
      final raw = await _messageService.getRawMessageById(id);
      if (raw != null && raw.isNotEmpty) {
        sourceMessages.add(raw);
      }
    }
    if (sourceMessages.isEmpty) {
      throw StateError('未找到可转发的原始消息');
    }

    await sendMessageBuild('create_forward', {
      'merge': merge,
      'title': title.trim().isNotEmpty ? title.trim() : '转发消息',
      'sourceMessages': sourceMessages,
    });
  }

  /// 失败文本消息：用新 client_msg 重建并再次发送，替换原列表项（保持位置）。
  Future<void> resendFailedText(String clientMsgId) async {
    final trimmedId = clientMsgId.trim();
    if (trimmedId.isEmpty) return;

    final idx = state.indexWhere((m) => m.clientMsgId == trimmedId);
    if (idx < 0) return;

    final old = state[idx];
    if (old.status != MessageStatus.failed) return;
    final content = old.content;
    if (content is! TextContent) return;
    final text = content.text.trim();
    if (text.isEmpty) return;

    final buildConversationId = await _conversationIdForMessageBuild();
    final created = await _messageService.createTextForSend(
      buildConversationId,
      text,
    );
    var optimistic = created.message;
    final me = _ref.read(currentUserProvider)?.userId ?? '';
    if (me.isNotEmpty && optimistic.senderId.isEmpty) {
      optimistic = optimistic.copyWith(senderId: me);
    }

    final replacement = optimistic.copyWith(status: MessageStatus.sending);
    final next = List<Message>.from(state);
    next[idx] = replacement;
    state = _timelineDisplayOrder(next);
    _watchSendTimeout(replacement.clientMsgId);

    try {
      final ack = await _sendPreparedWithTransientRetry(
        sdkMessage: created.sdkMessage,
        clientMsgId: replacement.clientMsgId,
      );
      if (ack['success'] == false) {
        _applySendFailure(replacement.clientMsgId, ack);
        return;
      }
      applySendAck(ack);
    } catch (error, stackTrace) {
      _logSendException(
        'resendFailedText',
        replacement.clientMsgId,
        error,
        stackTrace,
      );
      _applySendFailure(replacement.clientMsgId, {'reason': error.toString()});
    }
  }

  /// 对端已读回执：以会话序列 [readSeq] 为唯一读位标准；己方发送且回执来自对方时升级为 [MessageStatus.read]（双勾）。
  void applyReadReceipt({required int readSeq, String? readerUserId}) {
    if (readSeq <= 0) return;
    final self = _ref.read(currentUserProvider)?.userId.trim() ?? '';

    state = state.map((m) {
      final mSeq = m.seq;
      if (mSeq <= 0 || mSeq > readSeq) return m;

      var next = m.copyWith(isRead: true);
      final isOwn = self.isNotEmpty && m.senderId == self;
      final reader = readerUserId?.trim() ?? '';
      // 显式 `userId` 且非己方 -> 双勾。未带回执人 id 时按单聊已读回执处理（仍升级己方消息）。
      final fromPeer = reader.isEmpty || reader != self;
      if (isOwn &&
          fromPeer &&
          m.status != MessageStatus.failed &&
          m.status != MessageStatus.sending) {
        next = next.copyWith(status: MessageStatus.read);
      }
      return next;
    }).toList();
  }

  int _peerReadSeqForConversation() {
    for (final c in _ref.read(conversationProvider)) {
      if (c.conversationId == conversationId) return c.peerReadSeq;
    }
    return 0;
  }

  /// 会话列表已含 `peerReadSeq` 时，冷启动拉库也能显示己方双勾（对齐 Tauri 打开会话）。
  List<Message> _reapplyPeerReadToMessages(List<Message> list) {
    final peer = _peerReadSeqForConversation();
    if (peer <= 0) return list;
    final me = _ref.read(currentUserProvider)?.userId;
    return list
        .map(
          (m) => _maybePromoteOwnMessageReadByPeerSeq(
            m,
            selfUserId: me,
            peerReadSeq: peer,
          ),
        )
        .toList();
  }

  List<Message> _coreSnapshotPreservingUnresolvedLocal(List<Message> incoming) {
    final next = List<Message>.from(_coreMessageSnapshot(incoming));
    for (final message in state) {
      if (!_shouldPreserveUnresolvedLocal(message)) continue;
      final cid = message.conversationId.trim();
      if (cid.isNotEmpty && cid != conversationId) continue;
      if (_incomingMessageIndex(next, message) >= 0) continue;
      next.add(message);
    }
    return _timelineDisplayOrder(next);
  }

  bool _shouldPreserveUnresolvedLocal(Message message) {
    final clientMsgId = message.clientMsgId.trim();
    if (clientMsgId.isEmpty) return false;
    if (message.status == MessageStatus.sending ||
        message.status == MessageStatus.failed) {
      return true;
    }
    return message.source == MessageSource.local &&
        message.serverId.trim().isEmpty &&
        message.seq <= 0;
  }

  void _watchSendTimeout(String clientMsgId) {
    final id = clientMsgId.trim();
    if (id.isEmpty) return;
    _sendTimeouts.remove(id)?.cancel();
    _sendTimeouts[id] = Timer(_sendUiTimeout, () {
      _sendTimeouts.remove(id);
      final stillSending = state.any(
        (m) => m.clientMsgId == id && m.status == MessageStatus.sending,
      );
      if (!stillSending) return;
      _applySendFailure(id, {'code': 'send_timeout', 'reason': '发送超时，可点击重发'});
    });
  }

  void _cancelSendTimeout(String clientMsgId) {
    final id = clientMsgId.trim();
    if (id.isEmpty) return;
    _sendTimeouts.remove(id)?.cancel();
  }

  void _cancelSmoothAck(String clientMsgId) {
    final id = clientMsgId.trim();
    if (id.isEmpty) return;
    _ackSmoothTimers.remove(id)?.cancel();
  }

  void _cancelResolvedSendTracking() {
    final sendingIds = {
      for (final m in state)
        if (m.status == MessageStatus.sending) m.clientMsgId.trim(),
    }..remove('');
    final timeoutIds = List<String>.from(_sendTimeouts.keys);
    for (final id in timeoutIds) {
      if (!sendingIds.contains(id)) {
        _cancelSendTimeout(id);
      }
    }
    final ackIds = List<String>.from(_ackSmoothTimers.keys);
    for (final id in ackIds) {
      if (!sendingIds.contains(id)) {
        _cancelSmoothAck(id);
      }
    }
  }

  Duration _nextAckSmoothDelay() {
    _ackSmoothResetTimer?.cancel();
    _ackSmoothResetTimer = Timer(const Duration(milliseconds: 180), () {
      _ackSmoothSlot = 0;
    });
    final slot = _ackSmoothSlot;
    if (_ackSmoothSlot < _ackSmoothMaxSlots) {
      _ackSmoothSlot += 1;
    }
    return Duration(milliseconds: slot * _ackSmoothStep.inMilliseconds);
  }

  void _applySendProgress(String clientMsgId, Map<String, dynamic> progress) {
    final id = clientMsgId.trim();
    if (id.isEmpty) return;
    final current = (progress['current'] as num?)?.toInt() ?? 0;
    final total = (progress['total'] as num?)?.toInt() ?? 0;
    final percentage = total > 0 ? (current / total).clamp(0.0, 1.0) : 0.0;
    state = _timelineDisplayOrder(
      state.map((m) {
        if (m.clientMsgId != id) return m;
        return m.copyWith(
          localUpload: LocalUploadState(
            current: current,
            total: total,
            percentage: percentage,
          ),
        );
      }).toList(),
    );
  }

  void _applySendFailure(String clientMsgId, Map<String, dynamic> failure) {
    final id = clientMsgId.trim();
    if (id.isEmpty) return;
    _cancelSendTimeout(id);
    _cancelSmoothAck(id);
    final reason = _sendFailureReason(failure);
    _logSendFailure(id, failure, reason: reason);
    state = _timelineDisplayOrder(
      state.map((m) {
        if (m.clientMsgId != id) return m;
        final previous = m.localUpload;
        return m.copyWith(
          status: MessageStatus.failed,
          localUpload: LocalUploadState(
            current: previous?.current ?? 0,
            total: previous?.total ?? 0,
            percentage: previous?.percentage ?? 0,
            error: reason.isEmpty ? 'send_failed' : reason,
          ),
        );
      }).toList(),
    );
  }

  Future<Map<String, dynamic>> _sendPreparedWithTransientRetry({
    required core.Message sdkMessage,
    required String clientMsgId,
  }) async {
    for (var attempt = 0; ; attempt += 1) {
      try {
        final ack = await _messageService.sendPreparedMessage(
          sdkMessage,
          onProgress: (payload) => _applySendProgress(clientMsgId, payload),
          onSuccess: applySendAck,
          onFailure: (payload) {
            if (!_isDatabaseLockedPayload(payload)) {
              _applySendFailure(clientMsgId, payload);
            }
          },
        );
        if (!_isDatabaseLockedPayload(ack) ||
            attempt >= _transientSendRetryDelays.length) {
          return ack;
        }
      } catch (error) {
        if (!_isDatabaseLockedText(error.toString()) ||
            attempt >= _transientSendRetryDelays.length) {
          rethrow;
        }
      }
      await Future<void>.delayed(_transientSendRetryDelays[attempt]);
    }
  }

  bool _isDatabaseLockedPayload(Map<String, dynamic> payload) {
    if (payload['success'] != false) return false;
    return _isDatabaseLockedText(_safeJsonForLog(payload));
  }

  bool _isDatabaseLockedText(String text) {
    return text.toLowerCase().contains('database is locked');
  }

  String _sendFailureReason(Map<String, dynamic> failure) {
    final reason = failure['reason']?.toString().trim();
    if (reason != null && reason.isNotEmpty) return reason;
    final message = failure['message']?.toString().trim();
    if (message != null && message.isNotEmpty) return message;
    final error = failure['error'];
    if (error is Map) {
      final errorMessage = error['message']?.toString().trim();
      if (errorMessage != null && errorMessage.isNotEmpty) {
        return errorMessage;
      }
      final code = error['code']?.toString().trim();
      if (code != null && code.isNotEmpty) return code;
    }
    final code = failure['code']?.toString().trim();
    if (code != null && code.isNotEmpty) return code;
    return 'send_failed';
  }

  void _logSendFailure(
    String clientMsgId,
    Map<String, dynamic> failure, {
    required String reason,
  }) {
    debugPrintSynchronously(
      '[flare-im] message.send failure '
      'conversationId=$conversationId '
      'clientMsgId=$clientMsgId '
      'reason=$reason '
      'payload=${_safeJsonForLog(failure)}',
    );
  }

  void _logSendException(
    String stage,
    String clientMsgId,
    Object error,
    StackTrace stackTrace,
  ) {
    debugPrintSynchronously(
      '[flare-im] $stage exception '
      'conversationId=$conversationId '
      'clientMsgId=$clientMsgId '
      'error=$error\n$stackTrace',
    );
  }

  void _logBuildException(String stage, Object error, StackTrace stackTrace) {
    debugPrintSynchronously(
      '[flare-im] $stage exception '
      'conversationId=$conversationId '
      'error=$error\n$stackTrace',
    );
  }

  void applySendAck(Map<String, dynamic> ack) {
    if (_isQueuedSendAck(ack)) return;
    final cid = ack['conversationId'] as String?;
    if (cid != null && cid != conversationId) return;
    final clientId = ack['clientMsgId'] as String?;
    final serverId = (ack['serverMsgId'] as String?)?.trim();
    // 缺省不视为失败；仅显式 success == false 时标失败（避免 JSON 未带字段时误伤）。
    final successFlag = ack['success'];
    final explicitFailure = successFlag == false;
    final clientTrim = clientId?.trim() ?? '';
    if (clientTrim.isEmpty && (serverId == null || serverId.isEmpty)) return;
    if (explicitFailure) {
      if (clientTrim.isNotEmpty) {
        _applySendFailure(clientTrim, ack);
        return;
      }
      _applySendAckNow(ack);
      return;
    }

    final trackingId = clientTrim.isNotEmpty ? clientTrim : serverId ?? '';
    _cancelSendTimeout(trackingId);
    _cancelSmoothAck(trackingId);
    final delay = _nextAckSmoothDelay();
    if (delay == Duration.zero) {
      _applySendAckNow(ack);
      return;
    }
    _ackSmoothTimers[trackingId] = Timer(delay, () {
      _ackSmoothTimers.remove(trackingId);
      _applySendAckNow(ack);
    });
  }

  bool _isQueuedSendAck(Map<String, dynamic> ack) {
    final cid = ack['conversationId']?.toString().trim() ?? '';
    if (cid.isNotEmpty && cid != conversationId) return false;
    final clientId = ack['clientMsgId']?.toString().trim() ?? '';
    if (clientId.isEmpty) return false;
    final serverId =
        (ack['serverMsgId'] ?? ack['serverId'])?.toString().trim() ?? '';
    final seq =
        (ack['conversationSeq'] as num?)?.toInt() ??
        (ack['seq'] as num?)?.toInt() ??
        0;
    if (serverId.isNotEmpty || seq > 0) return false;
    if (ack['success'] == false) {
      final raw = _safeJsonForLog(ack).toLowerCase();
      final error = ack['error'];
      final errorHasReason =
          error is Map &&
          ((error['code']?.toString().trim().isNotEmpty ?? false) ||
              (error['message']?.toString().trim().isNotEmpty ?? false));
      final errorCode = (ack['errorCode'] as num?)?.toInt() ?? 0;
      final hasFailureReason =
          (ack['reason']?.toString().trim().isNotEmpty ?? false) ||
          (ack['message']?.toString().trim().isNotEmpty ?? false) ||
          (ack['code']?.toString().trim().isNotEmpty ?? false) ||
          errorHasReason ||
          errorCode != 0;
      if (raw.contains('missing send ack result')) return true;
      return !hasFailureReason;
    }
    return true;
  }

  void _applySendAckNow(Map<String, dynamic> ack) {
    final clientId = ack['clientMsgId'] as String?;
    final serverId = (ack['serverMsgId'] as String?)?.trim();
    final seq = (ack['conversationSeq'] as num?)?.toInt();
    final successFlag = ack['success'];
    final explicitFailure = successFlag == false;
    final clientTrim = clientId?.trim() ?? '';
    final trackingId = clientTrim.isNotEmpty ? clientTrim : serverId ?? '';
    _cancelSendTimeout(trackingId);
    _cancelSmoothAck(trackingId);
    if (explicitFailure && clientTrim.isNotEmpty) {
      _logSendFailure(clientTrim, ack, reason: _sendFailureReason(ack));
    }

    bool matchesRow(Message m) {
      if (clientTrim.isNotEmpty && m.clientMsgId == clientTrim) return true;
      if (serverId != null && serverId.isNotEmpty && m.serverId == serverId) {
        return true;
      }
      return false;
    }

    Message? updatedMessage;
    state = _timelineDisplayOrder(
      state.map((m) {
        if (!matchesRow(m)) return m;
        if (explicitFailure) {
          updatedMessage = m.copyWith(status: MessageStatus.failed);
          return updatedMessage!;
        }
        updatedMessage = m.copyWith(
          serverId: (serverId != null && serverId.isNotEmpty)
              ? serverId
              : m.serverId,
          seq: seq ?? m.seq,
          clientMsgId: clientTrim.isNotEmpty ? clientTrim : m.clientMsgId,
          status: MessageStatus.sent,
        );
        return updatedMessage!;
      }).toList(),
    );
  }

  Future<void> recall(String messageId) async {
    await _messageService.recallMessage(conversationId, messageId);
    applyRecallNotice(messageId);
  }

  /// 仅合并下行撤回态（不再调用 SDK）。
  void applyRecallNotice(String messageId) {
    final id = messageId.trim();
    if (id.isEmpty) return;
    state = state.map((m) {
      if (m.serverId == id || m.clientMsgId == id) {
        return m.copyWith(isRecalled: true);
      }
      return m;
    }).toList();
  }

  Future<void> deleteByServerId(String messageId) async {
    await _messageService.deleteMessage(conversationId, messageId);
    state = state
        .where((m) => m.serverId != messageId && m.clientMsgId != messageId)
        .toList();
  }

  Future<void> deleteForSelf(String messageId) async {
    await _messageService.deleteForSelf(messageId);
    state = state
        .where((m) => m.serverId != messageId && m.clientMsgId != messageId)
        .toList();
  }

  Future<void> deleteForEveryone(String messageId) async {
    await _messageService.deleteForEveryone(messageId);
    state = state
        .where((m) => m.serverId != messageId && m.clientMsgId != messageId)
        .toList();
  }

  Future<void> editOwnText(String serverMessageId, String newText) async {
    await _messageService.editTextByMessageId(serverMessageId, newText);
    state = state.map((m) {
      if (m.serverId != serverMessageId) return m;
      return m.copyWith(content: TextContent(newText), isEdited: true);
    }).toList();
  }

  Future<void> editOwnRichDoc({
    required String serverMessageId,
    required String format,
    required String source,
  }) async {
    final nextContent = await _messageService.editRichDocByMessageId(
      messageId: serverMessageId,
      format: format,
      source: source,
    );
    state = state.map((m) {
      if (m.serverId != serverMessageId) return m;
      return m.copyWith(content: nextContent, isEdited: true);
    }).toList();
  }

  /// 与 SDK 库内 [apply_reaction_change] 一致；供下行 [MessageReactionChangedEvent] 与本地乐观更新共用。
  void applyReactionChanged({
    required String serverMsgId,
    required String userId,
    required String emoji,
    required int action,
  }) {
    final id = serverMsgId.trim();
    if (id.isEmpty) return;
    state = state.map((m) {
      if (m.serverId != id) return m;
      final rx = applyReactionDelta(m.reactions, userId, emoji, action);
      return m.copyWith(reactions: rx);
    }).toList();
  }

  Future<void> addReaction(String messageId, String emoji) async {
    await _messageService.addReaction(messageId, emoji);
    final me = _ref.read(currentUserProvider)?.userId.trim() ?? '';
    if (me.isNotEmpty) {
      applyReactionChanged(
        serverMsgId: messageId,
        userId: me,
        emoji: emoji,
        action: 1,
      );
    }
  }

  Future<void> removeReaction(String messageId, String emoji) async {
    await _messageService.removeReaction(messageId, emoji);
    final me = _ref.read(currentUserProvider)?.userId.trim() ?? '';
    if (me.isNotEmpty) {
      applyReactionChanged(
        serverMsgId: messageId,
        userId: me,
        emoji: emoji,
        action: 2,
      );
    }
  }

  Future<List<Message>> searchInServer(
    String keyword, {
    required List<core.MessageSearchKind> kinds,
    int limit = 30,
  }) {
    return _messageService.searchMessages(
      keyword,
      conversationId: conversationId,
      kinds: kinds,
      limit: limit,
    );
  }
}

List<Message> _coreMessageSnapshot(List<Message> incoming) {
  return _timelineDisplayOrder(
    incoming
        .where((message) => message.conversationId.trim().isNotEmpty)
        .toList(growable: false),
  );
}

List<Message> _withPendingMessage(List<Message> current, Message pending) {
  final clientId = pending.clientMsgId.trim();
  if (clientId.isNotEmpty) {
    final existingIndex = current.indexWhere(
      (message) => message.clientMsgId.trim() == clientId,
    );
    if (existingIndex >= 0) {
      final next = List<Message>.from(current);
      next[existingIndex] = pending;
      return _timelineDisplayOrder(next);
    }
  }
  return _timelineDisplayOrder([...current, pending]);
}

int _incomingMessageIndex(List<Message> current, Message incoming) {
  final serverId = incoming.serverId.trim();
  if (serverId.isNotEmpty) {
    final index = current.indexWhere((m) => m.serverId.trim() == serverId);
    if (index >= 0) return index;
  }

  final clientMsgId = incoming.clientMsgId.trim();
  if (clientMsgId.isNotEmpty) {
    final index = current.indexWhere(
      (m) => m.clientMsgId.trim() == clientMsgId,
    );
    if (index >= 0) return index;
  }

  final timelineKey = incoming.timelineKey.trim();
  if (timelineKey.isNotEmpty) {
    final index = current.indexWhere(
      (m) => m.timelineKey.trim() == timelineKey,
    );
    if (index >= 0) return index;
  }

  final seq = incoming.seq;
  if (seq > 0) {
    final index = current.indexWhere((m) => m.seq == seq);
    if (index >= 0) return index;
  }

  return -1;
}

Message _mergeServerMessage(Message existing, Message incoming) {
  return incoming.copyWith(
    isRead: incoming.isRead || existing.isRead,
    reactions: incoming.reactions ?? existing.reactions,
    localUpload: incoming.localUpload ?? existing.localUpload,
  );
}

List<Message> _timelineDisplayOrder(List<Message> messages) {
  final next = List<Message>.from(messages);
  next.sort(_compareMessagesForTimelineAsc);
  return next;
}

int _compareMessagesForTimelineAsc(Message left, Message right) {
  final leftSeq = left.seq;
  final rightSeq = right.seq;
  if (leftSeq > 0 && rightSeq > 0) {
    return _compareInts(leftSeq, rightSeq) ??
        _compareDateTimes(left.timestamp, right.timestamp) ??
        _compareTimelineKeys(left, right);
  }

  final leftPending = _isLocalPendingForTimeline(left);
  final rightPending = _isLocalPendingForTimeline(right);
  if (leftPending != rightPending && (leftSeq > 0 || rightSeq > 0)) {
    return leftPending ? 1 : -1;
  }

  return _compareDateTimes(_timelineSortTime(left), _timelineSortTime(right)) ??
      _compareInts(leftSeq, rightSeq) ??
      _compareTimelineKeys(left, right);
}

bool _isLocalPendingForTimeline(Message message) {
  return message.seq == 0 &&
      message.source == MessageSource.local &&
      message.status == MessageStatus.sending;
}

DateTime _timelineSortTime(Message message) {
  if (message.seq > 0) return message.timestamp;
  return message.clientTimestamp.isAfter(message.timestamp)
      ? message.clientTimestamp
      : message.timestamp;
}

int? _compareInts(int left, int right) {
  final value = left.compareTo(right);
  return value == 0 ? null : value;
}

int? _compareDateTimes(DateTime left, DateTime right) {
  final value = left.compareTo(right);
  return value == 0 ? null : value;
}

int _compareTimelineKeys(Message left, Message right) {
  final leftKey = stableTimelineSortKey(left);
  final rightKey = stableTimelineSortKey(right);
  return leftKey.compareTo(rightKey);
}

String stableTimelineSortKey(Message message) {
  final timeline = message.timelineKey.trim();
  if (timeline.isNotEmpty) return timeline;
  final server = message.serverId.trim();
  if (server.isNotEmpty) return 's:$server';
  final client = message.clientMsgId.trim();
  if (client.isNotEmpty) return 'c:$client';
  return 't:${message.timestamp.millisecondsSinceEpoch}:${message.senderId}';
}

/// action：`1` = ADD，`2` = REMOVE（与 proto `ReactionAction` 一致）。
List<Reaction>? applyReactionDelta(
  List<Reaction>? current,
  String userId,
  String emoji,
  int action,
) {
  const addAction = 1;
  const removeAction = 2;
  final uid = userId.trim();
  final em = emoji.trim();
  if (uid.isEmpty || em.isEmpty) return current;
  if (action != addAction && action != removeAction) return current;

  final list = current == null ? <Reaction>[] : List<Reaction>.from(current);
  final isRemove = action == removeAction;
  final idx = list.indexWhere((r) => r.emoji == em);

  if (idx >= 0) {
    final r = list[idx];
    final uids = List<String>.from(r.userIds);
    if (isRemove) {
      uids.removeWhere((u) => u == uid);
    } else if (!uids.contains(uid)) {
      uids.add(uid);
    }
    if (uids.isEmpty) {
      list.removeAt(idx);
    } else {
      list[idx] = Reaction(emoji: r.emoji, userIds: uids, count: uids.length);
    }
  } else if (!isRemove) {
    list.add(Reaction(emoji: em, userIds: [uid], count: 1));
  }

  if (list.isEmpty) return null;
  return list;
}

/// 己方消息且 `seq <= peerReadSeq` 时显示已读（双勾）。
Message _maybePromoteOwnMessageReadByPeerSeq(
  Message msg, {
  required String? selfUserId,
  required int peerReadSeq,
}) {
  final self = selfUserId?.trim() ?? '';
  if (self.isEmpty || msg.senderId != self) return msg;
  if (msg.seq <= 0 || peerReadSeq < msg.seq) return msg;
  if (msg.status == MessageStatus.failed ||
      msg.status == MessageStatus.sending) {
    return msg;
  }
  return msg.copyWith(status: MessageStatus.read, isRead: true);
}
