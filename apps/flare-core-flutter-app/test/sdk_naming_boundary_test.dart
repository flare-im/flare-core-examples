import 'dart:convert';

import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart' as core;
import 'package:flare_im/domain/entities/conversation.dart';
import 'package:flare_im/domain/entities/user.dart';
import 'package:flare_im/infrastructure/sdk/flare_core_sdk_wrapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Conversation.fromCore ignores legacy snake_case SDK fields', () {
    final conversation = Conversation.fromCore(const {
      'conversation_id': 'legacy-c1',
      'display_name': 'Legacy Conversation',
      'avatar_url': 'https://example.invalid/avatar.png',
      'unread_count': 9,
      'is_pinned': true,
    });

    expect(conversation.conversationId, isEmpty);
    expect(conversation.displayName, '会话');
    expect(conversation.avatarUrl, isEmpty);
    expect(conversation.unreadCount, 0);
    expect(conversation.isPinned, isFalse);
  });

  test('Conversation.fromCore keeps core lastMessagePreview authoritative', () {
    final conversation = Conversation.fromCore(const {
      'conversationId': 'c1',
      'conversationType': 'single',
      'displayName': 'Chat',
      'lastMessagePreview': 'core preview',
    });

    expect(conversation.lastMessagePreview, 'core preview');
    expect(conversation.lastMessage, isNull);
  });

  test('User.fromCoreMap ignores legacy snake_case SDK fields', () {
    final user = User.fromCoreMap(const {
      'user_id': 'legacy-u1',
      'display_name': 'Legacy User',
      'avatar_url': 'https://example.invalid/avatar.png',
    });

    expect(user.userId, isEmpty);
    expect(user.nickname, isEmpty);
    expect(user.avatar, isNull);
  });

  test('sendMessage rejects snake_case SDK message JSON', () async {
    final messages = _RecordingMessagesApi();
    final sdk = SdkWrapper(client: _FakeFlareImClient(messages));

    await expectLater(
      () => sdk.sendMessage(
        jsonEncode({
          'client_msg_id': 'cm1',
          'conversation_id': 'c1',
          'message_type': 1,
          'content': {'content_type': 'text', 'text': 'hello'},
        }),
      ),
      throwsA(isA<ArgumentError>()),
    );
    expect(messages.sentMessage, isNull);
  });
}

final class _FakeFlareImClient implements core.FlareImClient {
  _FakeFlareImClient(this._messages);

  final _RecordingMessagesApi _messages;

  @override
  core.MessagesApi get messages => _messages;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _RecordingMessagesApi implements core.MessagesApi {
  core.Message? sentMessage;

  @override
  Future<core.SendMessageResponse> sendMessage(
    core.SendMessageRequest request, [
    core.MessageSendCallback? callback,
  ]) async {
    sentMessage = request.message;
    final ack = core.SendMessageResponse(
      clientMsgId: request.message.clientMsgId,
      conversationId: request.message.conversationId,
    );
    callback?.onSuccess(core.MessageSendAckEvent(ack: ack));
    return ack;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
