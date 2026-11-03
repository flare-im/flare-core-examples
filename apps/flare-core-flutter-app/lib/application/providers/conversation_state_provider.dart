import 'package:equatable/equatable.dart';
import 'package:flare_im/application/bus/event_bus.dart';
import 'package:flare_im/application/providers/conversation_filter_provider.dart';
import 'package:flare_im/application/providers/service_providers.dart';
import 'package:flare_im/application/services/conversation_service.dart';
import 'package:flare_im/domain/entities/conversation.dart';
import 'package:flare_im/domain/value_objects/conversation_type.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 会话列表单一数据源；UI 只 watch [conversationProvider]，下行经 EventBus → [ImEventToStoreBridge] 触发刷新。
final conversationProvider =
    StateNotifierProvider<ConversationListNotifier, List<Conversation>>((ref) {
      final conversationService = ref.watch(conversationServiceProvider);
      return ConversationListNotifier(ref, conversationService);
    });

class ConversationListNotifier extends StateNotifier<List<Conversation>> {
  ConversationListNotifier(this._ref, this._conversationService) : super([]);

  final Ref _ref;
  final ConversationService _conversationService;

  /// 对端已读位点上移（[MessageReadReceiptEvent]），与 `applyReadReceipt` 更新 `peerReadSeq` 一致。
  void applyPeerReadSeq(String conversationId, int readSeq) {
    final cid = conversationId.trim();
    if (cid.isEmpty || readSeq <= 0) return;
    state = state.map((c) {
      if (c.conversationId != cid) return c;
      if (readSeq <= c.peerReadSeq) return c;
      return c.copyWith(peerReadSeq: readSeq);
    }).toList();
    _syncSelectedConversation();
  }

  /// 未读增量（不经全量 list API），用于 [UnreadUpdateEvent]。
  void applyUnreadPatch(String conversationId, int unreadCount) {
    final cid = conversationId.trim();
    if (cid.isEmpty) return;
    state = state
        .map(
          (c) => c.conversationId == cid
              ? c.copyWith(unreadCount: unreadCount)
              : c,
        )
        .toList(growable: false);
    _syncSelectedConversation();
  }

  Future<void> load() async {
    final filter = _ref.read(conversationFilterProvider);
    final conversations = await _conversationService.getConversations(
      filter: filter,
    );
    state = _coreConversationSnapshot(conversations);
    _syncSelectedConversation();
  }

  void applyCoreSnapshot(List<Conversation> conversations) {
    state = _coreConversationSnapshot(conversations);
    _syncSelectedConversation();
  }

  void applyCoreDelta(List<CoreViewDeltaOp<Conversation>> ops) {
    if (ops.isEmpty) return;
    state = _applyIndexedDeltaOps<Conversation>(
      state,
      ops,
      (item) => item.conversationId.trim(),
    );
    _syncSelectedConversation();
  }

  void clear() {
    state = const [];
  }

  void upsert(Conversation conversation) {
    final cid = conversation.conversationId.trim();
    if (cid.isEmpty) return;
    final next = <Conversation>[];
    var inserted = false;
    for (final item in state) {
      if (item.conversationId == cid) {
        next.add(conversation);
        inserted = true;
        continue;
      }
      if (item.conversationId != cid) {
        next.add(item);
      }
    }
    if (!inserted) next.insert(0, conversation);
    state = next;
  }

  Future<void> delete(String conversationId) async {
    await _conversationService.deleteConversation(conversationId);
    state = state.where((c) => c.conversationId != conversationId).toList();
  }

  Future<void> pin(String conversationId, bool pinned) async {
    await _conversationService.pinConversation(conversationId, pinned);
    await load();
  }

  Future<void> markAsRead(String conversationId, int readSeq) async {
    await _conversationService.markAsRead(conversationId, readSeq);
    state = state.map((c) {
      if (c.conversationId == conversationId) {
        return c.copyWith(unreadCount: 0);
      }
      return c;
    }).toList();
    _syncSelectedConversation();
  }

  Future<void> syncConversation(String conversationId) async {
    await _conversationService.syncConversation(conversationId);
    await load();
  }

  Future<void> saveDraft(String conversationId, String? draft) async {
    state = state.map((c) {
      if (c.conversationId == conversationId) {
        return c.copyWith(draft: draft);
      }
      return c;
    }).toList();
    try {
      await _conversationService.updateDraft(conversationId, draft);
    } catch (_) {
      // Draft persistence is best-effort; it must not break composer sends.
    }
  }

  /// 单聊：按对方 userId 解析或创建会话并刷新列表
  Future<Conversation?> openSingleChat(String peerUserId) async {
    final c = await _conversationService.getConversationOne(
      peerUserId.trim(),
      ConversationType.single,
    );
    await load();
    return c;
  }

  Future<Conversation?> openGroupChat(
    List<String> userIds, {
    String? displayName,
  }) async {
    final c = await _conversationService.getGroupConversationByUserIds(
      _normalizeIds(userIds),
      displayName: displayName,
    );
    await load();
    return c;
  }

  Future<int> bootstrapHomeTimeline({int conversationLimit = 100}) async {
    final conversations = await _conversationService.bootstrapHomeTimeline(
      conversationLimit: conversationLimit,
    );
    final visible = conversations
        .where((c) => !c.isArchived)
        .toList(growable: false);
    state = _coreConversationSnapshot(visible);
    _syncSelectedConversation();
    return state.length;
  }

  Future<void> setMuted(String conversationId, bool muted) async {
    await _conversationService.setMuted(conversationId, muted);
    await load();
  }

  Future<void> setArchived(String conversationId, bool archived) async {
    await _conversationService.setArchived(conversationId, archived);
    await load();
  }

  Future<void> markUnread(String conversationId) async {
    await _conversationService.markUnread(conversationId);
  }

  Future<void> clearLocalHistory(String conversationId) async {
    await _conversationService.clearLocalHistory(conversationId);
  }

  List<String> _normalizeIds(List<String> rawIds) {
    return rawIds
        .map((id) => id.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
  }

  void _syncSelectedConversation() {
    final selected = _ref.read(selectedConversationProvider);
    if (selected == null) return;
    for (final item in state) {
      if (item.conversationId == selected.conversationId) {
        _ref.read(selectedConversationProvider.notifier).state = item;
        return;
      }
    }
  }
}

List<Conversation> _coreConversationSnapshot(List<Conversation> incoming) {
  return incoming
      .where((item) => item.conversationId.trim().isNotEmpty)
      .toList(growable: false);
}

List<T> _applyIndexedDeltaOps<T>(
  List<T> current,
  List<CoreViewDeltaOp<T>> ops,
  String Function(T item) keyOf,
) {
  final next = [...current];
  int indexByKey(String key) => next.indexWhere((item) => keyOf(item) == key);
  int boundedIndex(int index) => index.clamp(0, next.length).toInt();

  for (final op in ops) {
    final key = op.key.trim();
    if (key.isEmpty) continue;
    switch (op.op) {
      case 'remove':
        final existing = indexByKey(key);
        if (existing >= 0) next.removeAt(existing);
        break;
      case 'move':
        final existing = indexByKey(key);
        if (existing < 0) continue;
        final item = next.removeAt(existing);
        next.insert(boundedIndex(op.index), item);
        break;
      case 'insert':
        final item = op.item;
        if (item == null) continue;
        final existing = indexByKey(key);
        if (existing >= 0) next.removeAt(existing);
        next.insert(boundedIndex(op.index), item);
        break;
      case 'update':
        final item = op.item;
        if (item == null) continue;
        final existing = indexByKey(key);
        if (existing >= 0) {
          next[existing] = item;
        } else {
          next.insert(boundedIndex(op.index), item);
        }
        break;
    }
  }
  return next;
}

final selectedConversationProvider = StateProvider<Conversation?>(
  (ref) => null,
);

/// 会话列表 Sliver 分区 + id 顺序；仅顺序/成员变化时 [==]，避免无关字段变更触发整棵 Sliver 重建。
final class ConversationListSliverIds extends Equatable {
  const ConversationListSliverIds({
    required this.pinnedIds,
    required this.restIds,
  });

  final List<String> pinnedIds;
  final List<String> restIds;

  @override
  List<Object?> get props => [pinnedIds.join('\x1e'), restIds.join('\x1e')];
}

final conversationListSliverIdsProvider = Provider<ConversationListSliverIds>((
  ref,
) {
  final conversations = ref.watch(conversationProvider);
  return ConversationListSliverIds(
    pinnedIds: conversations
        .where((c) => c.isPinned)
        .map((c) => c.conversationId)
        .toList(),
    restIds: conversations
        .where((c) => !c.isPinned)
        .map((c) => c.conversationId)
        .toList(),
  );
});

Conversation? conversationById(List<Conversation> list, String conversationId) {
  final id = conversationId.trim();
  if (id.isEmpty) return null;
  for (final c in list) {
    if (c.conversationId == id) return c;
  }
  return null;
}
