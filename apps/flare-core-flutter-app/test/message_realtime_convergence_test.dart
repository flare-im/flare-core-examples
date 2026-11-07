import 'dart:async';

import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart' as core;
import 'package:flare_im/application/bus/event_bus.dart';
import 'package:flare_im/application/providers/conversation_state_provider.dart';
import 'package:flare_im/application/providers/message_state_provider.dart';
import 'package:flare_im/application/providers/service_providers.dart';
import 'package:flare_im/domain/entities/conversation.dart';
import 'package:flare_im/domain/entities/message.dart';
import 'package:flare_im/domain/repositories/i_conversation_repository.dart';
import 'package:flare_im/domain/repositories/i_message_repository.dart';
import 'package:flare_im/domain/value_objects/conversation_type.dart';
import 'package:flare_im/domain/value_objects/message_content.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('core timeline snapshot updates active timeline', () {
    final container = ProviderContainer(
      overrides: [
        conversationRepositoryProvider.overrideWithValue(
          _UnusedConversationRepository(),
        ),
        messageRepositoryProvider.overrideWithValue(_UnusedMessageRepository()),
      ],
    );
    addTearDown(container.dispose);

    container
        .read(conversationProvider.notifier)
        .upsert(_conversation('c1', updatedAtMs: 1000));

    final message = _message('c1', 12, 'hello from web', timestampMs: 6000);
    container.read(messageProvider('c1').notifier).applyCoreSnapshot([message]);

    final messages = container.read(messageProvider('c1'));
    expect(messages, hasLength(1));
    expect(messages.single.content.previewText, 'hello from web');
  });

  test('core conversation snapshot updates conversation preview', () {
    final container = ProviderContainer(
      overrides: [
        conversationRepositoryProvider.overrideWithValue(
          _UnusedConversationRepository(),
        ),
        messageRepositoryProvider.overrideWithValue(_UnusedMessageRepository()),
      ],
    );
    addTearDown(container.dispose);

    container.read(conversationProvider.notifier).applyCoreSnapshot([
      _conversation(
        'c1',
        updatedAtMs: 6000,
        lastMessage: _message('c1', 12, 'hello from web', timestampMs: 6000),
      ),
    ]);

    final conversations = container.read(conversationProvider);
    expect(conversations, hasLength(1));
    expect(conversations.single.lastMessagePreview, 'hello from web');
    expect(conversations.single.updatedAt.millisecondsSinceEpoch, 6000);
  });

  test('core conversation delta updates conversation preview immediately', () {
    final container = ProviderContainer(
      overrides: [
        conversationRepositoryProvider.overrideWithValue(
          _UnusedConversationRepository(),
        ),
        messageRepositoryProvider.overrideWithValue(_UnusedMessageRepository()),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(conversationProvider.notifier);
    notifier.applyCoreSnapshot([
      _conversation(
        'c1',
        updatedAtMs: 1000,
        lastMessage: _message('c1', 1, 'old', timestampMs: 1000),
      ),
    ]);

    notifier.applyCoreDelta([
      CoreViewDeltaOp(
        op: 'update',
        key: 'c1',
        index: 0,
        item: _conversation(
          'c1',
          updatedAtMs: 7000,
          unreadCount: 3,
          lastMessage: _message('c1', 7, 'delta-new', timestampMs: 7000),
        ),
      ),
    ]);

    final conversations = container.read(conversationProvider);
    expect(conversations.single.unreadCount, 3);
    expect(conversations.single.lastMessagePreview, 'delta-new');
  });

  test(
    'core conversation update delta inserts a previously unseen conversation',
    () {
      final container = ProviderContainer(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(
            _UnusedConversationRepository(),
          ),
          messageRepositoryProvider.overrideWithValue(
            _UnusedMessageRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(conversationProvider.notifier);
      notifier.applyCoreSnapshot([
        _conversation(
          'old-group',
          updatedAtMs: 1000,
          lastMessage: _message('old-group', 1, 'old', timestampMs: 1000),
        ),
      ]);

      notifier.applyCoreDelta([
        CoreViewDeltaOp(
          op: 'update',
          key: 'web-active-group',
          index: 0,
          item: _conversation(
            'web-active-group',
            updatedAtMs: 8000,
            unreadCount: 1,
            lastMessage: _message(
              'web-active-group',
              8,
              'hello from web group',
              timestampMs: 8000,
            ),
          ),
        ),
      ]);

      final conversations = container.read(conversationProvider);
      expect(conversations.map((c) => c.conversationId), [
        'web-active-group',
        'old-group',
      ]);
      expect(conversations.first.lastMessagePreview, 'hello from web group');
      expect(conversations.first.unreadCount, 1);
    },
  );

  test('core timeline delta inserts latest message at the display tail', () {
    final container = ProviderContainer(
      overrides: [
        conversationRepositoryProvider.overrideWithValue(
          _UnusedConversationRepository(),
        ),
        messageRepositoryProvider.overrideWithValue(_UnusedMessageRepository()),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(messageProvider('c1').notifier);
    notifier.applyCoreSnapshot([
      _message('c1', 1, 'old', timestampMs: 1000, timelineKey: 'seq:1'),
    ]);

    notifier.applyCoreTimelineDelta(
      append: [
        _message(
          'c1',
          2,
          'delta-new',
          timestampMs: 2000,
          timelineKey: 'seq:2',
        ),
      ],
    );

    final messages = container.read(messageProvider('c1'));
    expect(messages.map((m) => m.content.previewText), ['old', 'delta-new']);
  });

  test('timeline load is replaced by the latest core snapshot', () async {
    final container = ProviderContainer(
      overrides: [
        conversationRepositoryProvider.overrideWithValue(
          _UnusedConversationRepository(),
        ),
        messageRepositoryProvider.overrideWithValue(
          _ListMessageRepository([
            _message('c1', 3, 'older from core', timestampMs: 3000),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);

    container
        .read(conversationProvider.notifier)
        .upsert(_conversation('c1', updatedAtMs: 1000));

    final newer = _message('c1', 12, 'newer from web', timestampMs: 6000);
    final notifier = container.read(messageProvider('c1').notifier);
    notifier.applyCoreSnapshot([newer]);

    await notifier.load();

    final messages = container.read(messageProvider('c1'));
    expect(messages.map((m) => m.content.previewText), ['older from core']);
  });

  test(
    'self send waits for core conversation delta before updating preview',
    () async {
      final container = ProviderContainer(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(
            _UnusedConversationRepository(),
          ),
          messageRepositoryProvider.overrideWithValue(
            _SendingMessageRepository(),
          ),
        ],
      );
      addTearDown(container.dispose);

      container
          .read(conversationProvider.notifier)
          .upsert(_conversation('c1', updatedAtMs: 1000));
      container.read(messageProvider('c1').notifier).applyCoreSnapshot([
        _message('c1', 1, 'old', timestampMs: 1000, timelineKey: 'seq:1'),
      ]);

      await container.read(messageProvider('c1').notifier).sendText('sent-now');

      final messages = container.read(messageProvider('c1'));
      final conversations = container.read(conversationProvider);
      expect(messages.map((m) => m.content.previewText), ['old', 'sent-now']);
      expect(messages.last.seq, 42);
      expect(messages.last.serverId, 'server-sent');
      expect(conversations.single.lastMessagePreview, isNull);
      expect(conversations.single.lastMessage, isNull);
      expect(conversations.single.unreadCount, 0);

      container.read(conversationProvider.notifier).applyCoreDelta([
        CoreViewDeltaOp(
          op: 'update',
          key: 'c1',
          index: 0,
          item: _conversation(
            'c1',
            updatedAtMs: 7000,
            lastMessage: _message(
              'c1',
              42,
              'sent-now',
              timestampMs: 7000,
              timelineKey: 'seq:42',
            ).copyWith(serverId: 'server-sent', senderId: 'me'),
          ),
        ),
      ]);

      final updatedConversations = container.read(conversationProvider);
      expect(updatedConversations.single.lastMessagePreview, 'sent-now');
      expect(updatedConversations.single.lastMessage?.seq, 42);
      expect(updatedConversations.single.lastMessage?.serverId, 'server-sent');
    },
  );

  test(
    'self send inserts a local pending row before sdk build completes',
    () async {
      final repo = _DelayedTextMessageRepository();
      final container = ProviderContainer(
        overrides: [
          conversationRepositoryProvider.overrideWithValue(
            _UnusedConversationRepository(),
          ),
          messageRepositoryProvider.overrideWithValue(repo),
        ],
      );
      addTearDown(container.dispose);

      container
          .read(conversationProvider.notifier)
          .upsert(_conversation('c1', updatedAtMs: 1000));
      final notifier = container.read(messageProvider('c1').notifier);
      notifier.applyCoreSnapshot([
        _message('c1', 1, 'old', timestampMs: 1000, timelineKey: 'seq:1'),
      ]);

      final sendFuture = notifier.sendText('instant');

      final pendingMessages = container.read(messageProvider('c1'));
      expect(pendingMessages.map((m) => m.content.previewText), [
        'old',
        'instant',
      ]);
      expect(pendingMessages.last.status, MessageStatus.sending);
      expect(pendingMessages.last.source, MessageSource.local);
      expect(pendingMessages.last.clientMsgId, startsWith('local:'));
      expect(repo.sentMessages, isEmpty);

      notifier.applyCoreSnapshot([
        _message('c1', 1, 'old', timestampMs: 1000, timelineKey: 'seq:1'),
      ]);
      final refreshedPendingMessages = container.read(messageProvider('c1'));
      expect(refreshedPendingMessages.map((m) => m.content.previewText), [
        'old',
        'instant',
      ]);
      expect(refreshedPendingMessages.last.status, MessageStatus.sending);

      repo.completeCreate();
      await sendFuture;

      final sentMessages = container.read(messageProvider('c1'));
      expect(sentMessages.map((m) => m.content.previewText), [
        'old',
        'instant',
      ]);
      expect(sentMessages.last.clientMsgId, 'client-delayed');
      expect(sentMessages.last.serverId, 'server-delayed');
      expect(sentMessages.last.seq, 43);
      expect(sentMessages.last.status, MessageStatus.sent);
      expect(repo.sentMessages.single.clientMsgId, 'client-delayed');
    },
  );

  test('core timeline snapshot preserves failed local send row', () async {
    final container = ProviderContainer(
      overrides: [
        conversationRepositoryProvider.overrideWithValue(
          _UnusedConversationRepository(),
        ),
        messageRepositoryProvider.overrideWithValue(
          _FailingSendMessageRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    container
        .read(conversationProvider.notifier)
        .upsert(_conversation('c1', updatedAtMs: 1000));

    final notifier = container.read(messageProvider('c1').notifier);
    notifier.applyCoreSnapshot([
      _message('c1', 1, 'old', timestampMs: 1000, timelineKey: 'seq:1'),
    ]);

    await notifier.sendText('offline-send');

    final failedMessages = container.read(messageProvider('c1'));
    expect(failedMessages.map((m) => m.content.previewText), [
      'old',
      'offline-send',
    ]);
    expect(failedMessages.last.status, MessageStatus.failed);
    expect(failedMessages.last.localUpload?.error, 'offline');

    notifier.applyCoreSnapshot([
      _message('c1', 1, 'old', timestampMs: 1000, timelineKey: 'seq:1'),
    ]);

    final refreshedMessages = container.read(messageProvider('c1'));
    expect(refreshedMessages.map((m) => m.content.previewText), [
      'old',
      'offline-send',
    ]);
    expect(refreshedMessages.last.status, MessageStatus.failed);
    expect(refreshedMessages.last.localUpload?.error, 'offline');
  });

  test('core timeline snapshot normalizes to display order', () {
    final container = ProviderContainer(
      overrides: [
        conversationRepositoryProvider.overrideWithValue(
          _UnusedConversationRepository(),
        ),
        messageRepositoryProvider.overrideWithValue(_UnusedMessageRepository()),
      ],
    );
    addTearDown(container.dispose);

    container.read(messageProvider('c1').notifier).applyCoreSnapshot([
      _message('c1', 9, 'newer-from-core', timestampMs: 9000),
      _message('c1', 1, 'older-from-core', timestampMs: 1000),
    ]);

    expect(
      container.read(messageProvider('c1')).map((m) => m.content.previewText),
      ['older-from-core', 'newer-from-core'],
    );
  });
}

Conversation _conversation(
  String id, {
  required int updatedAtMs,
  Message? lastMessage,
  int unreadCount = 0,
}) {
  return Conversation(
    conversationId: id,
    conversationType: ConversationType.single,
    displayName: id,
    avatarUrl: '',
    lastMessage: lastMessage,
    lastMessagePreview: lastMessage?.content.previewText,
    unreadCount: unreadCount,
    updatedAt: DateTime.fromMillisecondsSinceEpoch(updatedAtMs),
    createdAt: DateTime.fromMillisecondsSinceEpoch(1),
  );
}

Message _message(
  String conversationId,
  int seq,
  String text, {
  required int timestampMs,
  String? timelineKey,
}) {
  final ts = DateTime.fromMillisecondsSinceEpoch(timestampMs);
  return Message(
    serverId: 'm$seq',
    clientMsgId: '',
    conversationId: conversationId,
    senderId: 'web',
    senderName: 'web',
    senderDisplayName: 'Web',
    senderAvatar: '',
    seq: seq,
    timestamp: ts,
    clientTimestamp: ts,
    source: MessageSource.remote,
    status: MessageStatus.sent,
    timelineKey: timelineKey ?? 'seq:$seq',
    content: TextContent(text),
  );
}

final class _UnusedConversationRepository implements IConversationRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _UnusedMessageRepository implements IMessageRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _ListMessageRepository implements IMessageRepository {
  _ListMessageRepository(this.messages);

  final List<Message> messages;

  @override
  Future<List<Message>> getMessages({
    required String conversationId,
    int? beforeSeq,
    required int limit,
  }) async => messages
      .where((message) => message.conversationId == conversationId)
      .toList(growable: false);

  @override
  Future<List<Message>> openConversationTimeline({
    required String conversationId,
    required int limit,
  }) async => getMessages(conversationId: conversationId, limit: limit);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _SendingMessageRepository implements IMessageRepository {
  @override
  Future<core.Message> createTextMessage(
    String conversationId,
    String text,
  ) async {
    return core.Message(
      sender: const core.DisplayName(kind: core.DisplayNameKind.unnamed),
      serverId: '',
      clientMsgId: 'client-sent',
      conversationId: conversationId,
      conversationSeq: 0,
      createdAt: 7000,
      clientCreatedAt: 7000,
      messageType: 1,
      source: 2,
      status: 0,
      timelineKey: 'client:client-sent',
      timelineSortTs: 7000,
      content: core.MessageContent(
        contentType: core.MessageContentType.text,
        data: {'text': text},
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> sendCoreMessage(
    core.Message message, {
    MessageSendEventCallback? onProgress,
    MessageSendEventCallback? onSuccess,
    MessageSendEventCallback? onFailure,
  }) async {
    final ack = <String, dynamic>{
      'success': true,
      'clientMsgId': message.clientMsgId,
      'serverMsgId': 'server-sent',
      'conversationId': message.conversationId,
      'conversationSeq': 42,
    };
    onSuccess?.call(ack);
    return ack;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _DelayedTextMessageRepository implements IMessageRepository {
  final Completer<core.Message> _createCompleter = Completer<core.Message>();
  final List<core.Message> sentMessages = [];

  String? _conversationId;
  String? _text;

  @override
  Future<core.Message> createTextMessage(String conversationId, String text) {
    _conversationId = conversationId;
    _text = text;
    return _createCompleter.future;
  }

  void completeCreate() {
    if (_createCompleter.isCompleted) return;
    final conversationId = _conversationId ?? 'c1';
    final text = _text ?? 'instant';
    _createCompleter.complete(
      core.Message(
        sender: const core.DisplayName(kind: core.DisplayNameKind.unnamed),
        serverId: '',
        clientMsgId: 'client-delayed',
        conversationId: conversationId,
        conversationSeq: 0,
        createdAt: 7100,
        clientCreatedAt: 7100,
        messageType: 1,
        source: 2,
        status: 0,
        timelineKey: 'client:client-delayed',
        timelineSortTs: 7100,
        content: core.MessageContent(
          contentType: core.MessageContentType.text,
          data: {'text': text},
        ),
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> sendCoreMessage(
    core.Message message, {
    MessageSendEventCallback? onProgress,
    MessageSendEventCallback? onSuccess,
    MessageSendEventCallback? onFailure,
  }) async {
    sentMessages.add(message);
    final ack = <String, dynamic>{
      'success': true,
      'clientMsgId': message.clientMsgId,
      'serverMsgId': 'server-delayed',
      'conversationId': message.conversationId,
      'conversationSeq': 43,
    };
    onSuccess?.call(ack);
    return ack;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FailingSendMessageRepository implements IMessageRepository {
  @override
  Future<core.Message> createTextMessage(
    String conversationId,
    String text,
  ) async {
    return core.Message(
      sender: const core.DisplayName(kind: core.DisplayNameKind.unnamed),
      serverId: '',
      clientMsgId: 'client-failed',
      conversationId: conversationId,
      conversationSeq: 0,
      createdAt: 7200,
      clientCreatedAt: 7200,
      messageType: 1,
      source: 2,
      status: 0,
      timelineKey: 'client:client-failed',
      timelineSortTs: 7200,
      content: core.MessageContent(
        contentType: core.MessageContentType.text,
        data: {'text': text},
      ),
    );
  }

  @override
  Future<Map<String, dynamic>> sendCoreMessage(
    core.Message message, {
    MessageSendEventCallback? onProgress,
    MessageSendEventCallback? onSuccess,
    MessageSendEventCallback? onFailure,
  }) async {
    final ack = <String, dynamic>{
      'success': false,
      'clientMsgId': message.clientMsgId,
      'conversationId': message.conversationId,
      'reason': 'offline',
    };
    onFailure?.call(ack);
    return ack;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
