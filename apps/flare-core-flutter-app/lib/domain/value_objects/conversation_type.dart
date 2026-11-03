/// 会话类型枚举
enum ConversationType {
  single(1, '单聊'),
  group(2, '群聊'),
  channel(3, '频道');

  final int value;
  final String label;

  const ConversationType(this.value, this.label);

  /// 从整数值创建
  static ConversationType fromValue(int value) {
    return ConversationType.values.firstWhere(
      (type) => type.value == value,
      orElse: () => throw ArgumentError('Invalid conversation type: $value'),
    );
  }

  /// 从字符串创建
  static ConversationType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'single':
        return ConversationType.single;
      case 'group':
        return ConversationType.group;
      case 'channel':
        return ConversationType.channel;
      default:
        throw ArgumentError('Invalid conversation type: $value');
    }
  }
}

/// 连接状态枚举
enum ConnectionState {
  disconnected(0, '未连接'),
  connecting(1, '连接中'),
  connected(2, '已连接'),

  /// 与 SDK `SdkState::Reconnecting` / Tauri `Reconnecting` 对齐（自动重连尝试中）
  reconnecting(3, '重连中'),
  disconnecting(4, '断开中');

  final int value;
  final String label;

  const ConnectionState(this.value, this.label);

  static ConnectionState fromValue(int value) {
    return ConnectionState.values.firstWhere(
      (state) => state.value == value,
      orElse: () => throw ArgumentError('Invalid connection state: $value'),
    );
  }
}

/// 消息状态枚举
enum MessageStatus {
  sending(0, '发送中'),
  sent(1, '已发送'),
  delivered(2, '已送达'),
  read(3, '已读'),
  failed(4, '发送失败');

  final int value;
  final String label;

  const MessageStatus(this.value, this.label);

  /// 与 Dart 枚举 [value] 一致（0=sending … 4=failed），用于本地/测试。
  static MessageStatus fromValue(int value) {
    return MessageStatus.values.firstWhere(
      (status) => status.value == value,
      orElse: () => throw ArgumentError('Invalid message status: $value'),
    );
  }

  /// 与 `flare.common.v1.MessageStatus`（message.proto）wire 值一致，**不等于** [value]。
  /// 例如 proto READ=4 对应本枚举 [read]；若误用 [fromValue](4) 会得到 [failed]。
  static MessageStatus fromProtoWire(int value) {
    switch (value) {
      case 0: // MESSAGE_STATUS_UNSPECIFIED
        return MessageStatus.sent;
      case 1: // MESSAGE_STATUS_CREATED
        return MessageStatus.sending;
      case 2: // MESSAGE_STATUS_SENT
        return MessageStatus.sent;
      case 3: // MESSAGE_STATUS_DELIVERED
        return MessageStatus.delivered;
      case 4: // MESSAGE_STATUS_READ
        return MessageStatus.read;
      case 5: // MESSAGE_STATUS_FAILED
        return MessageStatus.failed;
      case 6: // MESSAGE_STATUS_RECALLED
        return MessageStatus.sent;
      case 7: // MESSAGE_STATUS_DELETED_HARD
      case 8: // MESSAGE_STATUS_DELETED_SOFT
        return MessageStatus.sent;
      default:
        throw ArgumentError('Invalid proto message status: $value');
    }
  }
}

/// 消息来源枚举
enum MessageSource {
  local(0, '本地'),
  remote(1, '远程');

  final int value;
  final String label;

  const MessageSource(this.value, this.label);

  static MessageSource fromValue(int value) {
    return MessageSource.values.firstWhere(
      (source) => source.value == value,
      orElse: () => throw ArgumentError('Invalid message source: $value'),
    );
  }

  static MessageSource fromProtoWire(int value) {
    switch (value) {
      case 1: // MESSAGE_SOURCE_USER
      case 2: // MESSAGE_SOURCE_SYSTEM
      case 3: // MESSAGE_SOURCE_BOT
      case 4: // MESSAGE_SOURCE_ADMIN
        return MessageSource.remote;
      default:
        throw ArgumentError('Invalid proto message source: $value');
    }
  }
}
