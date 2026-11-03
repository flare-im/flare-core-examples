import 'package:equatable/equatable.dart';
import 'package:flare_im/domain/entities/message.dart';

/// 列表项稳定键（与 [MessageListNotifier] 去重语义一致）。
String stableMessageListKey(Message m) {
  final s = m.serverId.trim();
  if (s.isNotEmpty) return 's:$s';
  final c = m.clientMsgId.trim();
  if (c.isNotEmpty) return 'c:$c';
  if (m.seq > 0) return 'q:${m.seq}';
  return 't:${m.timestamp.millisecondsSinceEpoch}:${m.clientTimestamp.millisecondsSinceEpoch}:${m.senderId}';
}

/// 单条气泡 + 与相邻消息相关的展示位（用于 [select] 合并订阅，局部刷新）。
final class MessageRowViewModel extends Equatable {
  const MessageRowViewModel({
    required this.message,
    required this.showAvatar,
    required this.showTime,
  });

  final Message message;
  final bool showAvatar;
  final bool showTime;

  @override
  List<Object?> get props => [message, showAvatar, showTime];
}

MessageRowViewModel? messageRowViewModelForKey(
  List<Message> list,
  String messageKey,
) {
  final i = list.indexWhere((m) => stableMessageListKey(m) == messageKey);
  if (i < 0) return null;
  final message = list[i];
  final isNewestInList = i == list.length - 1;
  final isOldestInList = i == 0;
  // The timeline stores display order: oldest -> newest.
  // Show sender identity on the newest/bottom item of each contiguous group.
  final showAvatar = isNewestInList || list[i + 1].senderId != message.senderId;
  // 第一条（列表里最旧）没有上一条可比较时间间隔，显示时间条。
  final showTime = isOldestInList
      ? true
      : _shouldShowFeishuStyleTimeDivider(
          newer: message.timestamp,
          older: list[i - 1].timestamp,
          isOldestInList: false,
        );
  return MessageRowViewModel(
    message: message,
    showAvatar: showAvatar,
    showTime: showTime,
  );
}

/// 仅当消息 id 序列变化时 [==]（增删、重排）；用于外层 Sliver childCount，避免每条状态变更重建列表壳。
final class MessageListKeysSignal extends Equatable {
  const MessageListKeysSignal(this.orderedKeys);

  final List<String> orderedKeys;

  @override
  List<Object?> get props => [orderedKeys.join('\x1e')];
}

MessageListKeysSignal messageListKeysSignal(List<Message> list) {
  return MessageListKeysSignal(list.map(stableMessageListKey).toList());
}

/// 飞书式时间条：首条/跨自然日/间隔超过阈值时显示，不在每条气泡内重复时间。
bool _shouldShowFeishuStyleTimeDivider({
  required DateTime newer,
  required DateTime older,
  required bool isOldestInList,
}) {
  if (isOldestInList) return true;
  if (!_isSameCalendarDay(newer, older)) return true;
  return newer.difference(older).inMinutes > 5;
}

bool _isSameCalendarDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}
