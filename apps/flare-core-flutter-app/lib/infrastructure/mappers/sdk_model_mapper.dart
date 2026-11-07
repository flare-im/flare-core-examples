import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart' as core;
import 'package:flare_im/domain/entities/conversation.dart';
import 'package:flare_im/domain/entities/message.dart';
import 'package:flare_im/domain/entities/user.dart';
import 'package:flare_im/domain/value_objects/conversation_type.dart';
import 'package:flare_im/domain/value_objects/message_content.dart';
import 'package:flare_im/infrastructure/mappers/sdk_message_content_mapper.dart';
import 'package:flare_im/infrastructure/mappers/storage_preview_format.dart';

/// 示例 App 的 SDK/domain 模型边界。
class SdkModelMapper {
  static Message messageFromCore(core.Message message) {
    final ts = message.createdAt;
    final cts = message.clientCreatedAt > 0 ? message.clientCreatedAt : ts;
    final context = <String, dynamic>{
      'serverId': message.serverId,
      'attributes': message.attributes,
    };
    return Message(
      serverId: message.serverId,
      clientMsgId: message.clientMsgId,
      conversationId: message.conversationId,
      senderId: message.senderId,
      seq: message.conversationSeq,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        ts > 0 ? ts : DateTime.now().millisecondsSinceEpoch,
      ),
      clientTimestamp: DateTime.fromMillisecondsSinceEpoch(
        cts > 0 ? cts : DateTime.now().millisecondsSinceEpoch,
      ),
      content: SdkMessageContentMapper.fromMap(
        SdkMessageContentMapper.contentMapFromCore(message.content),
        context,
      ),
      status: MessageStatus.fromProtoWire(message.status),
      source: MessageSource.fromProtoWire(message.source),
      timelineKey: message.timelineKey,
      senderName: message.senderName,
      senderAvatar: message.senderAvatar,
      senderDisplayName: message.senderDisplayName,
      isRead: message.isRead,
      isRecalled: message.isRecalled,
      isEdited: message.isEdited,
      mentionUsers: message.mentionUsers,
      mentionAll: message.mentionAll,
      extra: message.attributes,
      reactions: _reactionsFromCore(message.reactions),
      localUpload: null,
    );
  }

  static Conversation conversationFromCore(core.Conversation c) {
    Message? lastMsg;
    if (c.lastMessage != null) {
      lastMsg = _messageFromCorePreview(c, c.lastMessage!);
    }

    final updatedMs = c.updatedAt > 0 ? c.updatedAt : c.updatedAtTs ?? 0;
    final createdMs = c.createdAt;

    return Conversation.fromCore({
      'conversationId': c.conversationId,
      'conversationType': _conversationTypeFromCore(c.conversationType),
      'displayName': _resolveCoreDisplayName(c),
      'avatarUrl': _resolveCoreAvatarUrl(c),
      'unreadCount': c.unreadCount,
      'isPinned': c.isPinned,
      'isMuted': c.isMuted,
      'isArchived': c.isArchived,
      'updatedAt': updatedMs,
      'createdAt': createdMs,
      'remark': c.remark,
      'draft': c.draft,
      'lastMessagePreview': c.lastMessagePreview,
      'mentionCount': c.mentionCount,
      'mentionMe': c.mentionMe,
      'peerUserId': _resolveCorePeerUserId(c),
      'memberUserIds': _resolveCoreMemberUserIds(c),
      'peerReadSeq': _peerReadSeqFromCoreConversation(c),
    }, lastMessage: lastMsg);
  }

  static List<Conversation> conversationsFromCoreHomeTimeline(
    core.HomeTimelineSnapshot snapshot,
  ) {
    return snapshot.conversations
        .where((item) => item.conversationId.trim().isNotEmpty)
        .map(conversationFromCore)
        .toList(growable: false);
  }

  static List<Message> messagesFromCoreTimeline(
    core.ConversationTimelineSnapshot snapshot,
  ) {
    return snapshot.messages
        .where((item) => item.conversationId.trim().isNotEmpty)
        .map(messageFromCore)
        .toList(growable: false);
  }

  static List<Message> messagesFromCoreTimelineView(
    core.TimelineViewSnapshot snapshot,
  ) {
    return snapshot.messages
        .where((item) => item.conversationId.trim().isNotEmpty)
        .map(messageFromCore)
        .toList(growable: false);
  }

  static String conversationIdFromCoreTimelineView(
    core.TimelineViewSnapshot snapshot,
    List<Message> messages,
  ) {
    final fromConversation = snapshot.conversation?.conversationId.trim() ?? '';
    if (fromConversation.isNotEmpty) return fromConversation;
    return messages.isEmpty ? '' : messages.first.conversationId.trim();
  }

  static String conversationIdFromCoreTimeline(
    core.ConversationTimelineSnapshot snapshot,
    List<Message> messages,
  ) {
    final fromConversation = snapshot.conversation?.conversationId.trim() ?? '';
    if (fromConversation.isNotEmpty) return fromConversation;
    return messages.isEmpty ? '' : messages.first.conversationId.trim();
  }

  static User userFromCore(Map<String, Object?> user) {
    return User.fromCoreMap(user);
  }

  static User? userFromPresenceEntry(String userId, Object? entry) {
    final id = userId.trim();
    if (id.isEmpty) return null;
    if (entry is Map<String, Object?>) {
      return userFromCore({...entry, 'userId': entry['userId'] ?? id});
    }
    if (entry is Map) {
      return userFromCore({
        for (final item in entry.entries) item.key.toString(): item.value,
        'userId': id,
      });
    }
    if (entry is bool) {
      return User.fromCoreMap({'userId': id, 'isOnline': entry});
    }
    return User.fromCoreMap({'userId': id});
  }

  static Map<String, dynamic> messageJsonFromCore(core.Message message) {
    return {
      'serverId': message.serverId,
      'clientMsgId': message.clientMsgId,
      'conversationId': message.conversationId,
      'conversationType': message.conversationType,
      'channelId': message.channelId,
      'senderId': message.senderId,
      'source': message.source,
      'conversationSeq': message.conversationSeq,
      'createdAt': message.createdAt,
      'clientCreatedAt': message.clientCreatedAt,
      'messageType': message.messageType,
      'content': SdkMessageContentMapper.contentMapFromCore(message.content),
      'senderName': message.senderName,
      'senderAvatar': message.senderAvatar,
      'senderDisplayName': message.senderDisplayName,
      'replyTo': message.replyTo,
      'quotePreview': message.quotePreview,
      'status': message.status,
      'isRead': message.isRead,
      'isRecalled': message.isRecalled,
      'isEdited': message.isEdited,
      'mentionUsers': message.mentionUsers,
      'mentionAll': message.mentionAll,
      'attributes': message.attributes,
      'reactions': [
        for (final reaction in message.reactions)
          {
            'emoji': reaction.emoji,
            'userIds': reaction.userIds,
            'count': reaction.count,
          },
      ],
    };
  }

  static Map<String, dynamic> sendAckJsonFromCore(
    core.SendMessageResponse ack,
  ) {
    return {
      'serverId': ack.serverId,
      'serverMsgId': ack.serverId,
      'clientMsgId': ack.clientMsgId,
      'conversationId': ack.conversationId,
      'conversationSeq': ack.seq,
      'createdAt': ack.timestamp,
    };
  }

  static Map<String, dynamic> sendFailureJsonFromCore(
    core.MessageSendFailedEvent event,
  ) {
    return {
      'success': false,
      'clientMsgId': event.clientMsgId,
      'reason': event.reason,
      'error': errorJsonFromCore(event.error),
    };
  }

  static Map<String, dynamic>? errorJsonFromCore(core.SdkErrorPayload? error) {
    if (error == null) return null;
    return {
      'code': error.code,
      'message': error.message,
      'operation': error.operation,
      'retryable': error.retryable,
      'details': error.details,
    };
  }

  static Map<String, dynamic> lifecycleJsonFromCore(core.LifecycleEvent event) {
    return {
      'type': 'lifecycle',
      'event': event.name.name,
      'operation': event.operation,
      'userId': event.userId,
      'sessionId': event.sessionId,
      'error': errorJsonFromCore(event.error),
    };
  }

  /// The `connection://status` payload as the SDK lab logs it.
  static Map<String, dynamic> connectionStatusJsonFromCore(
    core.ConnectionStatus status,
  ) {
    return {
      'phase': status.phase.name,
      'quality': status.quality?.name,
      'accessPointId': status.accessPointId,
      'cellId': status.cellId,
      'regionId': status.regionId,
      'protocol': status.protocol,
      'rttMs': status.rttMs,
      'attempt': status.attempt,
      'nextRetryAt': status.nextRetryAt,
      'reason': status.reason,
      'developmentMode': status.developmentMode,
    };
  }

  static Map<String, dynamic> syncJsonFromCore(core.SyncEvent event) {
    return {
      'type': 'sync',
      'event': event.name.name,
      'trigger': event.trigger,
      'phase': event.phase,
      'task': event.task,
      'progress': event.progress,
      'error': errorJsonFromCore(event.error),
    };
  }

  static Map<String, dynamic> progressJsonFromCore(core.ProgressEvent event) {
    return {
      'type': 'progress',
      'event': event.name.name,
      'operation': event.operation,
      'current': event.current,
      'total': event.total,
      'taskId': event.taskId,
      'detail': event.detail,
    };
  }

  static Map<String, dynamic> conversationJsonFromCore(core.Conversation c) {
    return {
      'conversationId': c.conversationId,
      'conversationType': c.conversationType.index,
      'displayName': c.displayName,
      'avatarUrl': c.avatarUrl,
      'channelId': c.channelId,
      'unreadCount': c.unreadCount,
      'isPinned': c.isPinned,
      'isMuted': c.isMuted,
      'isArchived': c.isArchived,
      'updatedAt': c.updatedAt,
      'updatedAtTs': c.updatedAtTs ?? c.updatedAt,
      'createdAt': c.createdAt,
      'remark': c.remark,
      'draft': c.draft,
      'mentionCount': c.mentionCount,
      'mentionMe': c.mentionMe,
      'peerReadSeq': c.peerReadSeq,
      'lastMessagePreview': c.lastMessagePreview,
      if (c.lastMessage != null)
        'lastMessage': {
          'messageId': c.lastMessage!.messageId,
          'senderId': c.lastMessage!.senderId,
          'type': c.lastMessage!.type,
          'text': c.lastMessage!.text,
          'time': c.lastMessage!.time,
        },
      'lastSenderNickname': c.lastSenderNickname,
      'lastSenderAvatarUrl': c.lastSenderAvatarUrl,
    };
  }

  static ConversationType _conversationTypeFromCore(
    core.ConversationType type,
  ) {
    switch (type.name) {
      case 'single':
        return ConversationType.single;
      case 'group':
        return ConversationType.group;
      default:
        return ConversationType.single;
    }
  }

  static String _resolveCoreDisplayName(core.Conversation c) {
    final direct = c.displayName.trim();
    if (direct.isNotEmpty) return direct;

    final nick = c.lastSenderNickname.trim();
    if (nick.isNotEmpty) return nick;

    final channel = c.channelId.trim();
    if (channel.isNotEmpty) return channel;

    final id = c.conversationId;
    if (id.isEmpty) return '会话';
    return id.length > 20 ? '${id.substring(0, 16)}…' : id;
  }

  static String _resolveCoreAvatarUrl(core.Conversation c) {
    final avatar = c.avatarUrl.trim();
    if (avatar.isNotEmpty) return avatar;
    final lastAvatar = c.lastSenderAvatarUrl.trim();
    if (lastAvatar.isNotEmpty) return lastAvatar;
    return '';
  }

  static String? _resolveCorePeerUserId(core.Conversation c) {
    for (final v in [c.ext['peerUserId'], c.ext['peerId'], c.channelId]) {
      final t = (v ?? '').trim();
      if (t.isNotEmpty) return t;
    }
    return null;
  }

  static List<String> _resolveCoreMemberUserIds(core.Conversation c) {
    final ids = <String>{
      for (final participant in c.participants)
        if (participant.userId.trim().isNotEmpty) participant.userId.trim(),
      for (final participant in c.memberPreview)
        if (participant.userId.trim().isNotEmpty) participant.userId.trim(),
    };
    return ids.toList(growable: false)..sort();
  }

  static int _peerReadSeqFromCoreConversation(core.Conversation c) {
    return c.peerReadSeq > 0 ? c.peerReadSeq : 0;
  }

  static List<Reaction>? _reactionsFromCore(
    List<core.ReactionEntry> reactions,
  ) {
    if (reactions.isEmpty) return null;
    return [
      for (final reaction in reactions)
        Reaction(
          emoji: reaction.emoji,
          userIds: List<String>.from(reaction.userIds),
          count: reaction.count,
        ),
    ];
  }

  static Message? _messageFromCorePreview(
    core.Conversation conv,
    core.MessagePreview preview,
  ) {
    final text = preview.text;
    final displayText = formatStoragePreview(text);
    final id = preview.messageId;
    final sid = preview.senderId;
    final t = preview.time;
    return Message(
      serverId: id,
      clientMsgId: id,
      conversationId: conv.conversationId,
      senderId: sid,
      seq: 0,
      timestamp: DateTime.fromMillisecondsSinceEpoch(
        t > 0 ? t : DateTime.now().millisecondsSinceEpoch,
      ),
      clientTimestamp: DateTime.fromMillisecondsSinceEpoch(
        t > 0 ? t : DateTime.now().millisecondsSinceEpoch,
      ),
      content: TextContent(displayText.isEmpty ? ' ' : displayText),
      status: MessageStatus.sent,
      source: MessageSource.remote,
      senderName: '',
      senderAvatar: '',
      senderDisplayName: conv.lastSenderNickname,
      isRead: true,
    );
  }
}

/// 与 Rust `ConversationType` 字符串枚举一致（供 `SdkWrapper.getConversationOne` 再 `jsonEncode`）
String conversationTypeTagForSdk(ConversationType t) {
  switch (t) {
    case ConversationType.single:
      return 'single';
    case ConversationType.group:
      return 'group';
    case ConversationType.channel:
      return 'group';
  }
}
