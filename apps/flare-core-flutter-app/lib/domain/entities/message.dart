import 'package:equatable/equatable.dart';

import 'package:flare_im/domain/value_objects/conversation_type.dart';
import 'package:flare_im/domain/value_objects/message_content.dart';

/// 消息实体
class Message extends Equatable {
  final String serverId;
  final String clientMsgId;
  final String conversationId;
  final String senderId;
  final int seq;
  final DateTime timestamp;
  final DateTime clientTimestamp;
  final MessageContent content;
  final MessageStatus status;
  final MessageSource source;
  final String timelineKey;

  // 发送者信息
  final String senderName;
  final String senderAvatar;
  final String senderDisplayName;

  // 状态标记
  final bool isRead;
  final bool isRecalled;
  final bool isEdited;

  // 扩展信息
  final List<String> mentionUsers;
  final bool mentionAll;
  final Map<String, String> extra;

  // UI 扩展
  final List<Reaction>? reactions;
  final LocalUploadState? localUpload;

  const Message({
    required this.serverId,
    required this.clientMsgId,
    required this.conversationId,
    required this.senderId,
    required this.seq,
    required this.timestamp,
    required this.clientTimestamp,
    required this.content,
    required this.status,
    required this.source,
    this.timelineKey = '',
    required this.senderName,
    required this.senderAvatar,
    required this.senderDisplayName,
    this.isRead = false,
    this.isRecalled = false,
    this.isEdited = false,
    this.mentionUsers = const [],
    this.mentionAll = false,
    this.extra = const {},
    this.reactions,
    this.localUpload,
  });

  @override
  List<Object?> get props => [
    serverId,
    clientMsgId,
    conversationId,
    senderId,
    seq,
    timestamp,
    clientTimestamp,
    content,
    status,
    source,
    timelineKey,
    senderName,
    senderAvatar,
    senderDisplayName,
    isRead,
    isRecalled,
    isEdited,
    mentionUsers,
    mentionAll,
    extra,
    reactions,
    localUpload,
  ];

  /// 业务方法：是否为发送中状态
  bool get isSending => status == MessageStatus.sending;

  /// 业务方法：是否发送失败
  bool get isFailed => status == MessageStatus.failed;

  /// 业务方法：是否可以撤回
  bool get canRecall {
    // 2分钟内的消息可以撤回
    final now = DateTime.now();
    final diff = now.difference(timestamp);
    return diff.inMinutes < 2 && !isRecalled;
  }

  /// 业务方法：是否可以编辑
  bool get canEdit {
    // 仅文本消息且在2分钟内可以编辑
    return content is TextContent && canRecall;
  }

  /// 复制并更新
  Message copyWith({
    String? serverId,
    String? clientMsgId,
    String? conversationId,
    String? senderId,
    int? seq,
    DateTime? timestamp,
    DateTime? clientTimestamp,
    MessageContent? content,
    MessageStatus? status,
    MessageSource? source,
    String? timelineKey,
    String? senderName,
    String? senderAvatar,
    String? senderDisplayName,
    bool? isRead,
    bool? isRecalled,
    bool? isEdited,
    List<String>? mentionUsers,
    bool? mentionAll,
    Map<String, String>? extra,
    List<Reaction>? reactions,
    LocalUploadState? localUpload,
  }) {
    return Message(
      serverId: serverId ?? this.serverId,
      clientMsgId: clientMsgId ?? this.clientMsgId,
      conversationId: conversationId ?? this.conversationId,
      senderId: senderId ?? this.senderId,
      seq: seq ?? this.seq,
      timestamp: timestamp ?? this.timestamp,
      clientTimestamp: clientTimestamp ?? this.clientTimestamp,
      content: content ?? this.content,
      status: status ?? this.status,
      source: source ?? this.source,
      timelineKey: timelineKey ?? this.timelineKey,
      senderName: senderName ?? this.senderName,
      senderAvatar: senderAvatar ?? this.senderAvatar,
      senderDisplayName: senderDisplayName ?? this.senderDisplayName,
      isRead: isRead ?? this.isRead,
      isRecalled: isRecalled ?? this.isRecalled,
      isEdited: isEdited ?? this.isEdited,
      mentionUsers: mentionUsers ?? this.mentionUsers,
      mentionAll: mentionAll ?? this.mentionAll,
      extra: extra ?? this.extra,
      reactions: reactions ?? this.reactions,
      localUpload: localUpload ?? this.localUpload,
    );
  }
}

/// 表情反应
class Reaction extends Equatable {
  final String emoji;
  final List<String> userIds;
  final int count;

  const Reaction({
    required this.emoji,
    required this.userIds,
    required this.count,
  });

  @override
  List<Object?> get props => [emoji, userIds, count];
}

/// 本地上传状态
class LocalUploadState extends Equatable {
  final int current;
  final int total;
  final double percentage;
  final String? error;

  const LocalUploadState({
    required this.current,
    required this.total,
    required this.percentage,
    this.error,
  });

  @override
  List<Object?> get props => [current, total, percentage, error];

  bool get isCompleted => current >= total;

  bool get hasError => error != null;
}
