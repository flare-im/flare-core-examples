import 'package:equatable/equatable.dart';

import 'package:flare_im/domain/entities/message.dart';
import 'package:flare_im/domain/value_objects/conversation_type.dart';

/// 超过这个人数的群默认只在 @我 时提醒，成员可以打开「接收全部消息通知」。
const int largeGroupMembers = 1000;

/// 会话实体
class Conversation extends Equatable {
  final String conversationId;
  final ConversationType conversationType;
  final String displayName;
  final String avatarUrl;
  final Message? lastMessage;
  final String? lastMessagePreview;
  final int unreadCount;
  final bool isPinned;
  final bool isMuted;

  /// 大群里当前用户打开了「接收全部消息通知」。
  final bool notifyAll;
  final bool isArchived;
  final DateTime updatedAt;
  final DateTime createdAt;

  // 可选字段
  final String? remark;
  final String? draft;
  final int? mentionCount;
  final bool? mentionMe;
  final String? peerUserId;
  final List<String> memberUserIds;

  /// 成员总数（核心会话摘要的 `membersCount`）。
  final int membersCount;

  /// 对端已读位点（SDK `ext.peerReadSeq` / 回执事件累加），用于己方消息双勾回填。
  final int peerReadSeq;

  const Conversation({
    required this.conversationId,
    required this.conversationType,
    required this.displayName,
    required this.avatarUrl,
    this.lastMessage,
    this.lastMessagePreview,
    this.unreadCount = 0,
    this.isPinned = false,
    this.isMuted = false,
    this.notifyAll = false,
    this.isArchived = false,
    required this.updatedAt,
    required this.createdAt,
    this.remark,
    this.draft,
    this.mentionCount,
    this.mentionMe,
    this.peerUserId,
    this.memberUserIds = const [],
    this.membersCount = 0,
    this.peerReadSeq = 0,
  });

  factory Conversation.fromCore(
    Map<String, Object?> core, {
    Message? lastMessage,
  }) {
    final id = _string(core, 'conversationId');
    final now = DateTime.now().millisecondsSinceEpoch;
    final updatedAt = _positiveInt(core, 'updatedAt', now);
    final createdAt = _positiveInt(core, 'createdAt', updatedAt);
    return Conversation(
      conversationId: id,
      conversationType: _conversationTypeFromCore(core),
      displayName: _string(
        core,
        'displayName',
        fallback: id.isEmpty ? '会话' : id,
      ),
      avatarUrl: _string(core, 'avatarUrl'),
      lastMessage: lastMessage,
      lastMessagePreview: _stringOrNull(core, 'lastMessagePreview'),
      unreadCount: _int(core, 'unreadCount', 0),
      isPinned: _bool(core, 'isPinned'),
      isMuted: _bool(core, 'isMuted'),
      notifyAll: _bool(core, 'notifyAll'),
      isArchived: _bool(core, 'isArchived'),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAt),
      createdAt: DateTime.fromMillisecondsSinceEpoch(createdAt),
      remark: _stringOrNull(core, 'remark'),
      draft: _stringOrNull(core, 'draft'),
      mentionCount: _intOrNull(core, 'mentionCount'),
      mentionMe: _boolOrNull(core, 'mentionMe'),
      peerUserId: _stringOrNull(core, 'peerUserId'),
      memberUserIds: _stringList(core, 'memberUserIds'),
      membersCount: _int(core, 'membersCount', 0),
      peerReadSeq: _int(core, 'peerReadSeq', 0),
    );
  }

  @override
  List<Object?> get props => [
    conversationId,
    conversationType,
    displayName,
    avatarUrl,
    lastMessage,
    lastMessagePreview,
    unreadCount,
    isPinned,
    isMuted,
    notifyAll,
    isArchived,
    updatedAt,
    createdAt,
    remark,
    draft,
    mentionCount,
    mentionMe,
    peerUserId,
    memberUserIds,
    membersCount,
    peerReadSeq,
  ];

  /// 业务方法：是否包含未读消息
  bool get hasUnread => unreadCount > 0;

  /// 业务方法：是否被@提及
  bool get isMentioned =>
      mentionMe == true && mentionCount != null && mentionCount! > 0;

  /// 业务方法：获取显示名称（优先使用备注）
  String get displayTitle => remark ?? displayName;

  /// 超过 1000 人的群：默认只在 @我 时提醒，成员可以打开「接收全部消息通知」。
  bool get isLargeGroup =>
      conversationType == ConversationType.group &&
      membersCount > largeGroupMembers;

  /// 复制并更新
  Conversation copyWith({
    String? conversationId,
    ConversationType? conversationType,
    String? displayName,
    String? avatarUrl,
    Message? lastMessage,
    String? lastMessagePreview,
    int? unreadCount,
    bool? isPinned,
    bool? isMuted,
    bool? notifyAll,
    bool? isArchived,
    DateTime? updatedAt,
    DateTime? createdAt,
    String? remark,
    String? draft,
    int? mentionCount,
    bool? mentionMe,
    String? peerUserId,
    List<String>? memberUserIds,
    int? membersCount,
    int? peerReadSeq,
  }) {
    return Conversation(
      conversationId: conversationId ?? this.conversationId,
      conversationType: conversationType ?? this.conversationType,
      displayName: displayName ?? this.displayName,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessagePreview: lastMessagePreview ?? this.lastMessagePreview,
      unreadCount: unreadCount ?? this.unreadCount,
      isPinned: isPinned ?? this.isPinned,
      isMuted: isMuted ?? this.isMuted,
      notifyAll: notifyAll ?? this.notifyAll,
      isArchived: isArchived ?? this.isArchived,
      updatedAt: updatedAt ?? this.updatedAt,
      createdAt: createdAt ?? this.createdAt,
      remark: remark ?? this.remark,
      draft: draft ?? this.draft,
      mentionCount: mentionCount ?? this.mentionCount,
      mentionMe: mentionMe ?? this.mentionMe,
      peerUserId: peerUserId ?? this.peerUserId,
      memberUserIds: memberUserIds ?? this.memberUserIds,
      membersCount: membersCount ?? this.membersCount,
      peerReadSeq: peerReadSeq ?? this.peerReadSeq,
    );
  }

  static ConversationType _conversationTypeFromCore(Map<String, Object?> map) {
    final value = map['conversationType'];
    if (value is ConversationType) return value;
    final text = value?.toString().trim().toLowerCase() ?? '';
    switch (text) {
      case '1':
      case 'group':
        return ConversationType.group;
      case '2':
      case 'channel':
      case 'broadcast':
        return ConversationType.channel;
      case '0':
      case 'single':
      default:
        return ConversationType.single;
    }
  }

  static String _string(
    Map<String, Object?> map,
    String key, {
    String fallback = '',
  }) {
    return _stringOrNull(map, key) ?? fallback;
  }

  static String? _stringOrNull(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static int _int(Map<String, Object?> map, String key, int fallback) {
    return _intOrNull(map, key) ?? fallback;
  }

  static int _positiveInt(Map<String, Object?> map, String key, int fallback) {
    final value = _intOrNull(map, key);
    return value != null && value > 0 ? value : fallback;
  }

  static int? _intOrNull(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) {
      return int.tryParse(value.trim());
    }
    return null;
  }

  static bool _bool(Map<String, Object?> map, String key) {
    return _boolOrNull(map, key) ?? false;
  }

  static bool? _boolOrNull(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
    return null;
  }

  static List<String> _stringList(Map<String, Object?> map, String key) {
    final value = map[key];
    if (value is Iterable) {
      return value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList(growable: false);
    }
    return const [];
  }
}
