import 'package:flare_im/application/bridge/event_to_store.dart';
import 'package:flare_im/application/bus/event_bus.dart';
import 'package:flare_im/application/providers/active_chat_stack_provider.dart';
import 'package:flare_im/application/providers/conversation_state_provider.dart';
import 'package:flare_im/application/providers/message_state_provider.dart';
import 'package:flare_im/application/providers/service_providers.dart';
import 'package:flare_im/domain/entities/conversation.dart';
import 'package:flare_im/domain/entities/message.dart';
import 'package:flare_im/domain/repositories/i_conversation_repository.dart';
import 'package:flare_im/domain/repositories/i_message_repository.dart';
import 'package:flare_im/domain/value_objects/conversation_filter.dart';
import 'package:flare_im/domain/value_objects/conversation_type.dart';
import 'package:flare_im/domain/value_objects/message_content.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('core conversation view snapshot updates latest preview', (
    tester,
  ) async {
    final repo = _ReloadConversationRepository(const []);
    final container = ProviderContainer(
      overrides: [conversationRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    final notifier = container.read(conversationProvider.notifier);
    notifier.upsert(
      _conversation(
        'c1',
        updatedAtMs: 1000,
        unreadCount: 0,
        lastMessage: _message('c1', 1, 'old-preview', timestampMs: 1000),
      ),
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ImEventToStoreBridge(child: SizedBox.shrink()),
      ),
    );

    imEventBus.fire(
      ConversationListViewSnapshotEvent([
        _conversation(
          'c1',
          updatedAtMs: 2000,
          unreadCount: 4,
          lastMessage: _message('c1', 2, 'web-new', timestampMs: 2000),
        ),
      ]),
    );
    await tester.pump();

    final state = container.read(conversationProvider);
    expect(repo.getConversationsCalls, 0);
    expect(state.single.unreadCount, 4);
    expect(state.single.lastMessagePreview, 'web-new');
  });

  testWidgets('conversation update event waits for core view snapshot', (
    tester,
  ) async {
    final repo = _ReloadConversationRepository(const []);
    final container = ProviderContainer(
      overrides: [conversationRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);

    container
        .read(conversationProvider.notifier)
        .upsert(
          _conversation(
            'c1',
            updatedAtMs: 1000,
            lastMessage: _message('c1', 1, 'stale', timestampMs: 1000),
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ImEventToStoreBridge(child: SizedBox.shrink()),
      ),
    );

    imEventBus.fire(const ConversationUpdateEvent(conversationId: 'c1'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();

    expect(repo.getConversationsCalls, 0);
    expect(
      container
          .read(conversationProvider)
          .single
          .lastMessage
          ?.content
          .previewText,
      'stale',
    );

    imEventBus.fire(
      ConversationListViewSnapshotEvent([
        _conversation(
          'c1',
          updatedAtMs: 3000,
          lastMessage: _message(
            'c1',
            3,
            'conversation-updated',
            timestampMs: 3000,
          ),
        ),
      ]),
    );
    await tester.pump();

    expect(
      container
          .read(conversationProvider)
          .single
          .lastMessage
          ?.content
          .previewText,
      'conversation-updated',
    );
  });

  testWidgets('incoming foreground message inserts into active timeline', (
    tester,
  ) async {
    final beforeMessage = _message('c1', 11, 'before', timestampMs: 5000);
    final foregroundMessage = _message(
      'c1',
      12,
      'foreground',
      timestampMs: 6000,
    );
    final conversationRepo = _ReloadConversationRepository([
      _conversation(
        'c1',
        updatedAtMs: 6000,
        unreadCount: 0,
        lastMessage: foregroundMessage,
      ),
    ]);
    final messageRepo = _RecordingMessageRepository([
      beforeMessage,
      foregroundMessage,
    ]);
    final container = ProviderContainer(
      overrides: [
        conversationRepositoryProvider.overrideWithValue(conversationRepo),
        messageRepositoryProvider.overrideWithValue(messageRepo),
      ],
    );
    addTearDown(container.dispose);

    container
        .read(conversationProvider.notifier)
        .upsert(
          _conversation(
            'c1',
            updatedAtMs: 1000,
            unreadCount: 3,
            lastMessage: _message('c1', 1, 'old', timestampMs: 1000),
          ),
        );
    container.read(activeChatStackProvider.notifier).push('c1');
    container.read(messageProvider('c1').notifier).applyCoreSnapshot([
      beforeMessage,
    ]);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ImEventToStoreBridge(child: SizedBox.shrink()),
      ),
    );

    imEventBus.fire(IncomingMessagesEvent([foregroundMessage]));
    await tester.pump();
    await tester.pump();

    expect(conversationRepo.markAsReadConversationId, 'c1');
    expect(conversationRepo.markAsReadSeq, 12);
    expect(
      container.read(messageProvider('c1')).map((m) => m.content.previewText),
      ['before', 'foreground'],
    );
    expect(container.read(conversationProvider).single.unreadCount, 0);
  });

  testWidgets('incoming selected desktop conversation updates timeline', (
    tester,
  ) async {
    final beforeMessage = _message('c1', 11, 'before', timestampMs: 5000);
    final desktopMessage = _message('c1', 12, 'desktop-new', timestampMs: 7000);
    final conversationRepo = _ReloadConversationRepository([
      _conversation(
        'c1',
        updatedAtMs: 7000,
        unreadCount: 0,
        lastMessage: desktopMessage,
      ),
    ]);
    final container = ProviderContainer(
      overrides: [
        conversationRepositoryProvider.overrideWithValue(conversationRepo),
        messageRepositoryProvider.overrideWithValue(
          _RecordingMessageRepository([beforeMessage, desktopMessage]),
        ),
      ],
    );
    addTearDown(container.dispose);

    final selected = _conversation(
      'c1',
      updatedAtMs: 1000,
      unreadCount: 5,
      lastMessage: _message('c1', 1, 'old', timestampMs: 1000),
    );
    container.read(conversationProvider.notifier).upsert(selected);
    container.read(selectedConversationProvider.notifier).state = selected;
    container.read(messageProvider('c1').notifier).applyCoreSnapshot([
      beforeMessage,
    ]);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ImEventToStoreBridge(child: SizedBox.shrink()),
      ),
    );

    imEventBus.fire(IncomingMessagesEvent([desktopMessage]));
    await tester.pump();
    await tester.pump();

    expect(
      container.read(messageProvider('c1')).map((m) => m.content.previewText),
      ['before', 'desktop-new'],
    );
    expect(conversationRepo.markAsReadConversationId, 'c1');
    expect(conversationRepo.markAsReadSeq, 12);
  });

  testWidgets('sdk send failed event marks active local message failed', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        messageRepositoryProvider.overrideWithValue(
          _RecordingMessageRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(activeChatStackProvider.notifier).push('c1');
    container.read(messageProvider('c1').notifier).mergeIncomingMessages([
      _localSendingMessage('c1', clientMsgId: 'client-failed'),
    ]);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ImEventToStoreBridge(child: SizedBox.shrink()),
      ),
    );

    imEventBus.fire(
      const SdkMessageSendFailedEvent({
        'clientMsgId': 'client-failed',
        'reason': 'offline',
      }),
    );
    await tester.pump();

    final message = container.read(messageProvider('c1')).single;
    expect(message.status, MessageStatus.failed);
    expect(message.localUpload?.error, 'offline');
  });

  testWidgets('incoming background message waits for core view deltas', (
    tester,
  ) async {
    final conversationRepo = _ReloadConversationRepository(const []);
    final container = ProviderContainer(
      overrides: [
        conversationRepositoryProvider.overrideWithValue(conversationRepo),
        messageRepositoryProvider.overrideWithValue(
          _RecordingMessageRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    container
        .read(conversationProvider.notifier)
        .upsert(
          _conversation(
            'c1',
            updatedAtMs: 1000,
            unreadCount: 2,
            lastMessage: _message('c1', 1, 'old', timestampMs: 1000),
          ),
        );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const ImEventToStoreBridge(child: SizedBox.shrink()),
      ),
    );

    imEventBus.fire(
      IncomingMessagesEvent([
        _message('c1', 7, 'background-new', timestampMs: 7000),
      ]),
    );
    await tester.pump();

    final messages = container.read(messageProvider('c1'));
    final conversations = container.read(conversationProvider);
    expect(conversationRepo.getConversationsCalls, 0);
    expect(messages, isEmpty);
    expect(conversations.single.lastMessagePreview, 'old');
    expect(conversations.single.unreadCount, 2);

    imEventBus.fire(
      TimelineViewDeltaEvent(
        conversationId: 'c1',
        append: [_message('c1', 7, 'background-new', timestampMs: 7000)],
      ),
    );
    imEventBus.fire(
      ConversationListViewDeltaEvent(
        ops: [
          CoreViewDeltaOp(
            op: 'update',
            key: 'c1',
            index: 0,
            item: _conversation(
              'c1',
              updatedAtMs: 7000,
              unreadCount: 3,
              lastMessage: _message(
                'c1',
                7,
                'background-new',
                timestampMs: 7000,
              ),
            ),
          ),
        ],
      ),
    );
    await tester.pump();

    expect(
      container.read(messageProvider('c1')).map((m) => m.content.previewText),
      ['background-new'],
    );
    final updatedConversations = container.read(conversationProvider);
    expect(updatedConversations.single.lastMessagePreview, 'background-new');
    expect(updatedConversations.single.unreadCount, 3);
  });
}

final class _ReloadConversationRepository implements IConversationRepository {
  _ReloadConversationRepository(this.conversations);

  final List<Conversation> conversations;
  int getConversationsCalls = 0;
  String? markAsReadConversationId;
  int? markAsReadSeq;

  @override
  Future<List<Conversation>> getConversations({
    ConversationFilter filter = ConversationFilter.all,
    String? keyword,
  }) async {
    getConversationsCalls += 1;
    return conversations;
  }

  @override
  Future<void> markAsRead(String conversationId, int readSeq) async {
    markAsReadConversationId = conversationId;
    markAsReadSeq = readSeq;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _RecordingMessageRepository implements IMessageRepository {
  _RecordingMessageRepository([List<Message> messages = const []])
    : _messages = List.unmodifiable(messages);

  final List<Message> _messages;

  @override
  Future<List<Message>> getMessages({
    required String conversationId,
    int? beforeSeq,
    required int limit,
  }) async {
    final scoped = _messages
        .where((message) => message.conversationId == conversationId)
        .toList(growable: false);
    return scoped.take(limit).toList(growable: false);
  }

  @override
  Future<void> syncMessages({
    required String conversationId,
    int lastSeq = 0,
    int limit = 50,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Conversation _conversation(
  String id, {
  required int updatedAtMs,
  int unreadCount = 0,
  Message? lastMessage,
}) {
  final updatedAt = DateTime.fromMillisecondsSinceEpoch(updatedAtMs);
  return Conversation(
    conversationId: id,
    conversationType: ConversationType.single,
    displayName: id,
    avatarUrl: '',
    lastMessage: lastMessage,
    lastMessagePreview: lastMessage?.content.previewText,
    unreadCount: unreadCount,
    updatedAt: updatedAt,
    createdAt: DateTime.fromMillisecondsSinceEpoch(1),
  );
}

Message _message(
  String conversationId,
  int seq,
  String text, {
  required int timestampMs,
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
    content: TextContent(text),
  );
}

Message _localSendingMessage(
  String conversationId, {
  required String clientMsgId,
}) {
  final ts = DateTime.fromMillisecondsSinceEpoch(9000);
  return Message(
    serverId: '',
    clientMsgId: clientMsgId,
    conversationId: conversationId,
    senderId: 'me',
    senderName: 'me',
    senderDisplayName: 'Me',
    senderAvatar: '',
    seq: 0,
    timestamp: ts,
    clientTimestamp: ts,
    source: MessageSource.local,
    status: MessageStatus.sending,
    timelineKey: 'client:$clientMsgId',
    content: const TextContent('pending'),
  );
}
