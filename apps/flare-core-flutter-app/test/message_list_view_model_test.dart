import 'package:flare_im/application/selectors/message_list_view_model.dart';
import 'package:flare_im/domain/entities/message.dart';
import 'package:flare_im/domain/value_objects/conversation_type.dart';
import 'package:flare_im/domain/value_objects/message_content.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shows avatar on newest bottom item of a contiguous sender group', () {
    final messages = [
      _message('m1', 'bob', 1),
      _message('m2', 'bob', 2),
      _message('m3', 'bob', 3),
    ];

    final oldest = messageRowViewModelForKey(
      messages,
      stableMessageListKey(messages[0]),
    );
    final middle = messageRowViewModelForKey(
      messages,
      stableMessageListKey(messages[1]),
    );
    final newest = messageRowViewModelForKey(
      messages,
      stableMessageListKey(messages[2]),
    );

    expect(newest?.showAvatar, isTrue);
    expect(middle?.showAvatar, isFalse);
    expect(oldest?.showAvatar, isFalse);
  });
}

Message _message(String id, String senderId, int seq) {
  final ts = DateTime.fromMillisecondsSinceEpoch(1000 + seq);
  return Message(
    serverId: id,
    clientMsgId: '',
    conversationId: 'c1',
    senderId: senderId,
    seq: seq,
    timestamp: ts,
    clientTimestamp: ts,
    content: const TextContent('hi'),
    status: MessageStatus.sent,
    source: MessageSource.remote,
    senderName: senderId,
    senderAvatar: '',
    senderDisplayName: senderId,
  );
}
