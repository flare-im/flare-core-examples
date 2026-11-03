import 'package:flare_im/application/providers/conversation_state_provider.dart';
import 'package:flare_im/application/providers/service_providers.dart';
import 'package:flare_im/domain/entities/conversation.dart';
import 'package:flare_im/domain/entities/message.dart';
import 'package:flare_im/domain/repositories/i_conversation_repository.dart';
import 'package:flare_im/domain/value_objects/conversation_type.dart';
import 'package:flare_im/domain/value_objects/message_content.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('core conversation snapshot replaces local preview when newer', () {
    final container = ProviderContainer(
      overrides: [
        conversationRepositoryProvider.overrideWithValue(
          _UnusedConversationRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(conversationProvider.notifier);
    notifier.upsert(
      _conversation(
        'c1',
        updatedAtMs: 3000,
        unreadCount: 9,
        lastMessage: _message('c1', 3, 'local-older', timestampMs: 3000),
      ),
    );

    notifier.applyCoreSnapshot([
      _conversation(
        'c1',
        updatedAtMs: 5000,
        unreadCount: 0,
        lastMessage: _message('c1', 5, 'core-newer', timestampMs: 5000),
      ),
    ]);

    final state = container.read(conversationProvider);
    expect(state, hasLength(1));
    expect(state.single.lastMessagePreview, 'core-newer');
    expect(state.single.unreadCount, 0);
  });

  test('core conversation snapshot replaces newer local preview', () {
    final container = ProviderContainer(
      overrides: [
        conversationRepositoryProvider.overrideWithValue(
          _UnusedConversationRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(conversationProvider.notifier);
    notifier.upsert(
      _conversation(
        'c1',
        updatedAtMs: 6000,
        unreadCount: 0,
        lastMessage: _message('c1', 12, 'local-newer', timestampMs: 6000),
      ),
    );

    notifier.applyCoreSnapshot([
      _conversation(
        'c1',
        updatedAtMs: 3000,
        unreadCount: 5,
        lastMessage: _message('c1', 3, 'core-older', timestampMs: 3000),
      ),
    ]);

    final state = container.read(conversationProvider);
    expect(state, hasLength(1));
    expect(state.single.lastMessagePreview, 'core-older');
    expect(state.single.unreadCount, 5);
    expect(state.single.updatedAt.millisecondsSinceEpoch, 3000);
  });

  test('bootstrap home timeline uses core snapshot preview', () async {
    final container = ProviderContainer(
      overrides: [
        conversationRepositoryProvider.overrideWithValue(
          _BootstrapConversationRepository([
            _conversation(
              'c1',
              updatedAtMs: 3000,
              lastMessage: _message('c1', 3, 'core-older', timestampMs: 3000),
            ),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(conversationProvider.notifier);
    notifier.upsert(
      _conversation(
        'c1',
        updatedAtMs: 6000,
        lastMessage: _message('c1', 12, 'local-newer', timestampMs: 6000),
      ),
    );

    final count = await notifier.bootstrapHomeTimeline();

    final state = container.read(conversationProvider);
    expect(count, 1);
    expect(state, hasLength(1));
    expect(state.single.lastMessagePreview, 'core-older');
    expect(state.single.updatedAt.millisecondsSinceEpoch, 3000);
  });

  test('core conversation snapshot preserves core order', () {
    final container = ProviderContainer(
      overrides: [
        conversationRepositoryProvider.overrideWithValue(
          _UnusedConversationRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(conversationProvider.notifier).applyCoreSnapshot([
      _conversation('older', updatedAtMs: 1000),
      _conversation('newer', updatedAtMs: 2000),
    ]);

    expect(
      container.read(conversationProvider).map((item) => item.conversationId),
      ['older', 'newer'],
    );
  });

  test('core conversation snapshot accepts thin core row as authoritative', () {
    final container = ProviderContainer(
      overrides: [
        conversationRepositoryProvider.overrideWithValue(
          _UnusedConversationRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(conversationProvider.notifier);
    notifier.upsert(
      _conversation(
        'c1',
        updatedAtMs: 5000,
        unreadCount: 0,
        lastMessage: _message('c1', 12, 'local-preview', timestampMs: 5000),
      ),
    );

    notifier.applyCoreSnapshot([
      _conversation('c1', updatedAtMs: 6000, unreadCount: 5),
    ]);

    final state = container.read(conversationProvider);
    expect(state, hasLength(1));
    expect(state.single.lastMessage, isNull);
    expect(state.single.unreadCount, 5);
    expect(state.single.updatedAt.millisecondsSinceEpoch, 6000);
  });

  test('core conversation snapshot drops invalid empty ids', () {
    final container = ProviderContainer(
      overrides: [
        conversationRepositoryProvider.overrideWithValue(
          _UnusedConversationRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(conversationProvider.notifier).applyCoreSnapshot([
      _conversation('', updatedAtMs: 2000),
      _conversation('valid', updatedAtMs: 1000),
    ]);

    expect(container.read(conversationProvider), hasLength(1));
    expect(container.read(conversationProvider).single.conversationId, 'valid');
  });
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
    senderId: 'bob',
    senderName: 'bob',
    senderDisplayName: 'Bob',
    senderAvatar: '',
    seq: seq,
    timestamp: ts,
    clientTimestamp: ts,
    source: MessageSource.remote,
    status: MessageStatus.sent,
    content: TextContent(text),
  );
}

final class _UnusedConversationRepository implements IConversationRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _BootstrapConversationRepository
    implements IConversationRepository {
  _BootstrapConversationRepository(this.conversations);

  final List<Conversation> conversations;

  @override
  Future<List<Conversation>> bootstrapHomeTimeline({
    int conversationLimit = 100,
  }) async => conversations;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
