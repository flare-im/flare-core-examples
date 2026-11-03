import 'dart:convert';

import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart' as core;
import 'package:flare_im/domain/value_objects/message_content.dart';
import 'package:flare_im/infrastructure/mappers/sdk_message_content_mapper.dart';
import 'package:flare_im/infrastructure/mappers/sdk_model_mapper.dart';
import 'package:flare_im/infrastructure/sdk/flare_core_sdk_wrapper.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps core text content into visible app text', () {
    final message = SdkModelMapper.messageFromCore(
      const core.Message(
        clientMsgId: 'cm1',
        conversationId: 'c1',
        messageType: 1,
        source: 1,
        content: core.MessageContent(
          contentType: core.MessageContentType.text,
          data: {'text': 'hello'},
        ),
      ),
    );

    expect(message.content, isA<TextContent>());
    expect((message.content as TextContent).text, 'hello');
  });

  test('maps core emoji content into visible app emoji', () {
    final message = SdkModelMapper.messageFromCore(
      const core.Message(
        clientMsgId: 'cm1',
        conversationId: 'c1',
        messageType: 9,
        source: 1,
        content: core.MessageContent(
          contentType: core.MessageContentType.emoji,
          data: {'emoji': '😀'},
        ),
      ),
    );

    expect(message.content, isA<EmojiContent>());
    expect((message.content as EmojiContent).emoji, '😀');
  });

  test(
    'rejects missing or unknown message content instead of rendering text fallback',
    () {
      expect(
        () => SdkMessageContentMapper.fromMap(null, const {}),
        throwsArgumentError,
      );
      expect(
        () => SdkMessageContentMapper.fromMap(const {
          'contentType': 'mystery',
        }, const {}),
        throwsArgumentError,
      );
      expect(
        () => SdkMessageContentMapper.fromMap(const {
          'contentType': 'quote',
        }, const {}),
        throwsArgumentError,
      );
    },
  );

  test('sends a fully built message without rebuilding it', () async {
    final messages = _RecordingMessagesApi();
    final builder = _FailingMessageBuilderApi();
    final sdk = SdkWrapper(client: _FakeFlareImClient(messages, builder));

    final ack = await sdk.sendMessage(
      jsonEncode({
        'serverId': '',
        'clientMsgId': 'cm1',
        'conversationId': 'c1',
        'conversationType': 1,
        'channelId': 'ch1',
        'senderId': 'u1',
        'source': 2,
        'conversationSeq': 0,
        'createdAt': 1000,
        'clientCreatedAt': 1000,
        'messageType': 1,
        'content': {'contentType': 'text', 'text': 'hello'},
        'status': 0,
        'timelineKey': 'client:cm1',
        'timelineSortTs': 1000,
      }),
    );

    expect(builder.buildWithContentCalled, isFalse);
    expect(messages.sentMessage?.clientMsgId, 'cm1');
    expect(messages.sentMessage?.conversationId, 'c1');
    expect(messages.sentMessage?.channelId, 'ch1');
    expect(
      messages.sentMessage?.content?.contentType,
      core.MessageContentType.text,
    );
    expect(messages.sentMessage?.content?.data['text'], 'hello');
    expect(ack['success'], isTrue);
    expect(ack['clientMsgId'], 'cm1');
  });

  test('uses generated SDK camelCase keys for conversation requests', () async {
    final conversations = _RecordingConversationsApi();
    final sdk = SdkWrapper(
      client: _FakeConversationFlareImClient(conversations),
    );

    await sdk.getConversationOne('u2', 'single');
    expect(conversations.getOneRequest, {
      'sourceId': 'u2',
      'conversationType': 'single',
    });

    await sdk.getGroupConversationByUserIds(['u1', 'u2'], displayName: 'Team');
    expect(conversations.groupRequest, {
      'userIds': ['u1', 'u2'],
      'displayName': 'Team',
    });

    await sdk.getMultipleConversations(['c1', 'c2']);
    expect(conversations.multipleRequest, {
      'conversationIds': ['c1', 'c2'],
    });

    await sdk.conversationMarkRead('c1', 9);
    expect(conversations.markReadRequest, {
      'conversationId': 'c1',
      'readSeq': 9,
    });

    await sdk.conversationMarkUnread('c1');
    expect(conversations.markUnreadRequest, {'conversationId': 'c1'});
  });
}

final class _FakeFlareImClient implements core.FlareImClient {
  _FakeFlareImClient(this._messages, this._messageBuilder);

  final _RecordingMessagesApi _messages;
  final _FailingMessageBuilderApi _messageBuilder;

  @override
  core.MessagesApi get messages => _messages;

  @override
  core.MessageBuilderApi get messageBuilder => _messageBuilder;

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
      serverId: 's1',
      clientMsgId: request.message.clientMsgId,
      conversationId: request.message.conversationId,
      seq: 12,
      timestamp: 2000,
    );
    callback?.onSuccess(core.MessageSendAckEvent(ack: ack));
    return ack;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FailingMessageBuilderApi implements core.MessageBuilderApi {
  var buildWithContentCalled = false;

  @override
  Future<core.Message> buildWithContent(
    core.BuildWithContentMessageRequest request,
  ) async {
    buildWithContentCalled = true;
    throw StateError('sendMessage must not rebuild a fully built message');
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeConversationFlareImClient implements core.FlareImClient {
  _FakeConversationFlareImClient(this._conversations);

  final _RecordingConversationsApi _conversations;

  @override
  core.ConversationsApi get conversations => _conversations;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _RecordingConversationsApi implements core.ConversationsApi {
  Map<String, Object?>? getOneRequest;
  Map<String, Object?>? groupRequest;
  Map<String, Object?>? multipleRequest;
  Map<String, Object?>? markReadRequest;
  Map<String, Object?>? markUnreadRequest;

  @override
  Future<core.Conversation> getOneConversation(
    Map<String, Object?> request,
  ) async {
    getOneRequest = request;
    return _coreConversation(request['sourceId']?.toString() ?? 'c1');
  }

  @override
  Future<core.Conversation> getGroupConversationByUserIds(
    Map<String, Object?> request,
  ) async {
    groupRequest = request;
    return _coreConversation('group-c1');
  }

  @override
  Future<core.ListConversationsResponse> getMultipleConversations(
    Map<String, Object?> request,
  ) async {
    multipleRequest = request;
    return const core.ListConversationsResponse(
      conversations: [
        core.Conversation(
          conversationId: 'c1',
          conversationType: core.ConversationType.single,
        ),
      ],
    );
  }

  @override
  Future<void> markConversationRead(Map<String, Object?> request) async {
    markReadRequest = request;
  }

  @override
  Future<void> markConversationUnread(Map<String, Object?> request) async {
    markUnreadRequest = request;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

core.Conversation _coreConversation(String id) {
  return core.Conversation(
    conversationId: id,
    conversationType: core.ConversationType.single,
  );
}
