import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flare_im/application/providers/auth_state_provider.dart';
import 'package:flare_im/application/providers/conversation_state_provider.dart';
import 'package:flare_im/domain/entities/user.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------------------
// 未读：由 [conversationProvider] 派生，保证单一事实来源；[UnreadUpdateEvent] 只 patch 列表项。
// ---------------------------------------------------------------------------

@immutable
final class UnreadSnapshot extends Equatable {
  const UnreadSnapshot({required this.total, required this.perConversation});

  final int total;
  final Map<String, int> perConversation;

  @override
  List<Object?> get props => [total, perConversation];
}

final unreadProvider = Provider<UnreadSnapshot>((ref) {
  final list = ref.watch(conversationProvider);
  final per = {for (final c in list) c.conversationId: c.unreadCount};
  final total = per.values.fold<int>(0, (a, b) => a + b);
  return UnreadSnapshot(total: total, perConversation: per);
});

// ---------------------------------------------------------------------------
// 正在输入：按会话维度存 Set<userId>，UI 用 [typingProvider] + select 限制重建范围。
// ---------------------------------------------------------------------------

final class TypingSession extends Equatable {
  const TypingSession(this.typingUserIds);

  final Set<String> typingUserIds;

  static const TypingSession empty = TypingSession({});

  bool get isAnyoneTyping => typingUserIds.isNotEmpty;

  @override
  List<Object?> get props => [typingUserIds];
}

class TypingMapNotifier extends StateNotifier<Map<String, TypingSession>> {
  TypingMapNotifier() : super(const {});

  static const _typingExpire = Duration(seconds: 5);
  final Map<String, Timer> _expireTimers = {};

  String _timerKey(String conversationId, String userId) =>
      '$conversationId\x1f$userId';

  void clearAll() {
    for (final timer in _expireTimers.values) {
      timer.cancel();
    }
    _expireTimers.clear();
    state = const {};
  }

  @override
  void dispose() {
    for (final timer in _expireTimers.values) {
      timer.cancel();
    }
    _expireTimers.clear();
    super.dispose();
  }

  void applyTypingEvent({
    required String conversationId,
    required String userId,
    required bool isTyping,
  }) {
    final uid = userId.trim();
    final cid = conversationId.trim();
    if (cid.isEmpty || uid.isEmpty) return;

    final prev = state[cid] ?? TypingSession.empty;
    final nextIds = {...prev.typingUserIds};
    final key = _timerKey(cid, uid);
    if (isTyping) {
      nextIds.add(uid);
      _expireTimers[key]?.cancel();
      _expireTimers[key] = Timer(_typingExpire, () {
        applyTypingEvent(conversationId: cid, userId: uid, isTyping: false);
      });
    } else {
      nextIds.remove(uid);
      _expireTimers.remove(key)?.cancel();
    }

    final nextMap = Map<String, TypingSession>.from(state);
    if (nextIds.isEmpty) {
      nextMap.remove(cid);
    } else {
      nextMap[cid] = TypingSession(nextIds);
    }
    state = nextMap;
  }

  void applyTypingAggregate({
    required String conversationId,
    required Iterable<String> userIds,
  }) {
    final cid = conversationId.trim();
    if (cid.isEmpty) return;

    final ids = userIds
        .map((userId) => userId.trim())
        .where((userId) => userId.isNotEmpty)
        .toSet();

    final prefix = '$cid\x1f';
    final oldKeys = _expireTimers.keys
        .where((key) => key.startsWith(prefix))
        .toList();
    for (final key in oldKeys) {
      _expireTimers.remove(key)?.cancel();
    }

    final nextMap = Map<String, TypingSession>.from(state);
    if (ids.isEmpty) {
      nextMap.remove(cid);
      state = nextMap;
      return;
    }

    for (final uid in ids) {
      final key = _timerKey(cid, uid);
      _expireTimers[key] = Timer(_typingExpire, () {
        applyTypingEvent(conversationId: cid, userId: uid, isTyping: false);
      });
    }
    nextMap[cid] = TypingSession(ids);
    state = nextMap;
  }

  void clearConversation(String conversationId) {
    final cid = conversationId.trim();
    if (cid.isEmpty || !state.containsKey(cid)) return;
    final prefix = '$cid\x1f';
    final keys = _expireTimers.keys
        .where((key) => key.startsWith(prefix))
        .toList();
    for (final key in keys) {
      _expireTimers.remove(key)?.cancel();
    }
    state = Map<String, TypingSession>.from(state)..remove(cid);
  }
}

final typingMapProvider =
    StateNotifierProvider<TypingMapNotifier, Map<String, TypingSession>>((ref) {
      return TypingMapNotifier();
    });

/// 某会话下的输入态快照；与 [conversationId] 绑定，避免整表监听。
final typingProvider = Provider.family<TypingSession, String>((
  ref,
  conversationId,
) {
  final cid = conversationId.trim();
  return ref.watch(
    typingMapProvider.select((m) => m[cid] ?? TypingSession.empty),
  );
});

// ---------------------------------------------------------------------------
// 用户资料：下行推送合并进目录；[userProvider] 同时回落到当前登录用户。
// ---------------------------------------------------------------------------

class UserDirectoryNotifier extends StateNotifier<Map<String, User>> {
  UserDirectoryNotifier() : super(const {});

  void clearAll() => state = const {};

  void upsert(User u) {
    state = {...state, u.userId: u};
  }
}

final userDirectoryProvider =
    StateNotifierProvider<UserDirectoryNotifier, Map<String, User>>((ref) {
      return UserDirectoryNotifier();
    });

/// 按 userId 订阅目录中的单条，避免整张 [userDirectoryProvider] 变更时全局重建。
final userProvider = Provider.family<User?, String>((ref, userId) {
  final id = userId.trim();
  if (id.isEmpty) return null;
  final fromDir = ref.watch(userDirectoryProvider.select((m) => m[id]));
  if (fromDir != null) return fromDir;
  return ref.watch(
    currentUserProvider.select((u) => u != null && u.userId == id ? u : null),
  );
});

// ---------------------------------------------------------------------------
// 在线状态：null 表示尚未收到任何 presence 推送。
// ---------------------------------------------------------------------------

class PresenceMapNotifier extends StateNotifier<Map<String, bool>> {
  PresenceMapNotifier() : super(const {});

  void clearAll() => state = const {};

  void setOnline(String userId, bool online) {
    final id = userId.trim();
    if (id.isEmpty) return;
    state = {...state, id: online};
  }
}

final presenceMapProvider =
    StateNotifierProvider<PresenceMapNotifier, Map<String, bool>>((ref) {
      return PresenceMapNotifier();
    });

final userOnlineProvider = Provider.family<bool?, String>((ref, userId) {
  final id = userId.trim();
  if (id.isEmpty) return null;
  return ref.watch(presenceMapProvider.select((m) => m[id]));
});
