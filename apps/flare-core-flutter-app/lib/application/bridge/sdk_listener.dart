import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart' as core;
import 'package:flare_im/application/bus/event_bus.dart';
import 'package:flare_im/application/providers/auth_state_provider.dart';
import 'package:flare_im/application/providers/sdk_provider.dart';
import 'package:flare_im/domain/entities/conversation.dart';
import 'package:flare_im/domain/entities/message.dart';
import 'package:flare_im/infrastructure/mappers/sdk_model_mapper.dart';
import 'package:flare_im/infrastructure/sdk/flare_core_sdk_wrapper.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// SDK event bridge: converts typed SDK listener callbacks into app events.
class SdkImEventEmitter extends ConsumerStatefulWidget {
  const SdkImEventEmitter({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SdkImEventEmitter> createState() => _SdkImEventEmitterState();
}

class _SdkImEventEmitterState extends ConsumerState<SdkImEventEmitter> {
  core.EventSubscription? _subscription;
  late final SdkWrapper _sdk;

  @override
  void initState() {
    super.initState();
    _sdk = ref.read(sdkWrapperProvider);
    _ensureSubscription();
  }

  @override
  void dispose() {
    _teardown();
    super.dispose();
  }

  void _teardown() {
    _subscription?.unsubscribe();
    _subscription = null;
  }

  void _ensureSubscription() {
    _subscription ??= _sdk.addEventListener(const _AppSdkEventListener());
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(currentUserProvider, (prev, next) {
      if (next != null) {
        _ensureSubscription();
      }
    });
    return widget.child;
  }
}

final class _AppSdkEventListener extends core.FlareImEventListener {
  const _AppSdkEventListener();

  @override
  void onInitializing(core.LifecycleEvent event) => _fireLifecycle(event);

  @override
  void onInitialized(core.LifecycleEvent event) => _fireLifecycle(event);

  @override
  void onInitFailed(core.LifecycleEvent event) => _fireLifecycle(event);

  @override
  void onLoginSucceeded(core.LifecycleEvent event) => _fireLifecycle(event);

  @override
  void onLoginFailed(core.LifecycleEvent event) => _fireLifecycle(event);

  @override
  void onLoggedOut(core.LifecycleEvent event) => _fireLifecycle(event);

  @override
  void onDisposed(core.LifecycleEvent event) => _fireLifecycle(event);

  @override
  void onConnectionStatusChanged(core.ConnectionStatus event) {
    debugPrint(
      'flare sdk event connection.status phase=${event.phase.name} '
      'ap=${event.accessPointId ?? ''} protocol=${event.protocol ?? ''} '
      'reason=${event.reason ?? ''}',
    );
    imEventBus.fire(ConnectionStatusChangedEvent(event));
  }

  @override
  void onAccessSwitched(core.AccessSwitchedEvent event) {
    debugPrint(
      'flare sdk event access.switched ${event.from.ap}/${event.from.protocol} '
      '-> ${event.to.ap}/${event.to.protocol} reason=${event.reason}',
    );
  }

  @override
  void onAccessChanged(core.AccessChangedEvent event) {
    debugPrint(
      'flare sdk event access.changed serial=${event.serial} '
      'source=${event.source} stale=${event.stale}',
    );
  }

  /// The update center takes `update://state` through its own engine.
  @override
  void onUpdateState(core.UpdateStatus event) {}

  @override
  void onMessageReceived(core.MessageReceivedEvent event) {
    final message = SdkModelMapper.messageFromCore(event.message);
    if (message.conversationId.trim().isEmpty) return;
    debugPrint(
      'flare sdk event message.received cid=${message.conversationId} '
      'seq=${message.seq} server=${message.serverId}',
    );
    imEventBus.fire(IncomingMessagesEvent([message]));
  }

  @override
  void onMessageReceivedBatch(core.MessageReceivedBatchEvent event) {
    final messages = event.messages
        .where((message) => message.conversationId.trim().isNotEmpty)
        .map(SdkModelMapper.messageFromCore)
        .toList(growable: false);
    if (messages.isEmpty) return;
    debugPrint(
      'flare sdk event message.received_batch count=${messages.length} '
      'cids=${messages.map((m) => m.conversationId).toSet().join(',')} '
      'lastSeq=${messages.map((m) => m.seq).fold<int>(0, (a, b) => a > b ? a : b)}',
    );
    imEventBus.fire(IncomingMessagesEvent(messages));
  }

  @override
  void onMessageSendAck(core.MessageSendAckEvent event) {
    imEventBus.fire(
      MessageSendAckEvent(SdkModelMapper.sendAckJsonFromCore(event.ack)),
    );
  }

  @override
  void onMessageSendFailed(core.MessageSendFailedEvent event) {
    imEventBus.fire(
      SdkMessageSendFailedEvent(SdkModelMapper.sendFailureJsonFromCore(event)),
    );
  }

  @override
  void onMessageRecalled(core.MessageMutationEvent event) {
    _fireRecall(event);
  }

  @override
  void onMessageEdited(core.MessageMutationEvent event) {
    _fireConversationId(event.conversationId);
  }

  @override
  void onMessageDeleted(core.MessageMutationEvent event) {
    _fireConversationId(event.conversationId);
  }

  @override
  void onMessageReadReceipt(core.ReadReceiptEvent event) {
    final conversationId = event.conversationId.trim();
    if (conversationId.isEmpty || event.readSeq <= 0) return;
    imEventBus.fire(
      MessageReadReceiptEvent(
        conversationId: conversationId,
        readSeq: event.readSeq,
        readerUserId: event.userId.trim().isEmpty ? null : event.userId.trim(),
      ),
    );
  }

  @override
  void onMessageReactionChanged(core.ReactionChangedEvent event) {
    if (event.conversationId.isEmpty ||
        event.serverMsgId.isEmpty ||
        event.userId.isEmpty ||
        event.emoji.isEmpty ||
        (event.action != 1 && event.action != 2)) {
      return;
    }
    imEventBus.fire(
      MessageReactionChangedEvent(
        conversationId: event.conversationId,
        serverMsgId: event.serverMsgId,
        userId: event.userId,
        emoji: event.emoji,
        action: event.action,
      ),
    );
  }

  @override
  void onInputStatusChanged(core.TypingEvent event) {
    if (event.conversationId.isEmpty || event.userId.isEmpty) return;
    imEventBus.fire(
      TypingEvent(
        conversationId: event.conversationId,
        userId: event.userId,
        isTyping: event.typing,
      ),
    );
  }

  @override
  void onTypingAggregateChanged(core.TypingAggregateEvent event) {
    final conversationId = event.conversationId.trim();
    if (conversationId.isEmpty) return;
    imEventBus.fire(
      TypingAggregateEvent(
        conversationId: conversationId,
        userIds: event.typingUserIds,
      ),
    );
  }

  @override
  void onMessageBurned(core.MessageMutationEvent event) {
    _fireConversationId(event.conversationId);
  }

  @override
  void onMessagePinned(core.MessageMutationEvent event) {
    _fireConversationId(event.conversationId);
  }

  @override
  void onMessageUnpinned(core.MessageMutationEvent event) {
    _fireConversationId(event.conversationId);
  }

  @override
  void onMessagePluginStateChanged(core.MessageMutationEvent event) {
    _fireConversationId(event.conversationId);
  }

  // This Core reference app hosts no plugin client packages, so plugin
  // realtime packets and catalog changes have no consumer here.
  @override
  void onPluginRealtime(core.PluginRealtimeEvent event) {}

  @override
  void onPluginCatalogChanged(core.PluginCatalogChangedEvent event) {}

  @override
  void onViewUpdated(core.ViewUpdate event) {
    final snapshot = event.snapshot;
    final delta = event.delta;
    debugPrint(
      'flare sdk event view.updated kind=${event.kind} '
      'snapshot=${snapshot?.viewType ?? ''} delta=${delta?.viewType ?? ''} '
      'revision=${event.revision}',
    );
    final timelineView = timelineViews[event.viewId];
    if (timelineView != null) {
      // 版本号逐次加 1；比已应用的旧就丢弃，跳号时取快照整体替换。
      if (event.revision <= timelineView.revision) return;
      if (event.revision != timelineView.revision + 1) {
        imEventBus.fire(TimelineViewResyncEvent(event.viewId));
        return;
      }
      timelineViews[event.viewId] = (
        conversationId: timelineView.conversationId,
        revision: event.revision,
      );
    }
    if (event.kind == 'delta') {
      if (delta == null) return;
      if (delta.viewType == 'conversationList') {
        imEventBus.fire(
          ConversationListViewDeltaEvent(
            ops: _conversationDeltaOps(delta),
            totalUnread: delta.totalUnread,
          ),
        );
        return;
      }
      if (delta.viewType == 'timeline') {
        final fromDelta = delta.conversation?.conversationId.trim() ?? '';
        final conversationId = fromDelta.isNotEmpty
            ? fromDelta
            : timelineView?.conversationId ?? '';
        if (conversationId.isEmpty) return;
        List<Message> rows(List<core.Message>? messages) => [
          for (final message in messages ?? const <core.Message>[])
            SdkModelMapper.messageFromCore(message),
        ];
        imEventBus.fire(
          TimelineViewDeltaEvent(
            conversationId: conversationId,
            prepend: rows(delta.prepend),
            append: rows(delta.append),
            upsert: rows(delta.upsert),
            remove: delta.remove ?? const [],
            hasMore: delta.hasOlder,
          ),
        );
      }
      return;
    }
    if (snapshot == null) return;
    final data = snapshot.data;
    if (snapshot.viewType == 'conversationList' &&
        data is core.HomeTimelineSnapshot) {
      imEventBus.fire(
        ConversationListViewSnapshotEvent(
          SdkModelMapper.conversationsFromCoreHomeTimeline(data),
        ),
      );
      return;
    }
    if (snapshot.viewType == 'timeline' &&
        data is core.TimelineViewSnapshot) {
      final messages = SdkModelMapper.messagesFromCoreTimelineView(data);
      final fromSnapshot = SdkModelMapper.conversationIdFromCoreTimelineView(
        data,
        messages,
      );
      final conversationId = fromSnapshot.isNotEmpty
          ? fromSnapshot
          : timelineView?.conversationId ?? '';
      if (conversationId.isEmpty) return;
      imEventBus.fire(
        TimelineViewSnapshotEvent(
          conversationId: conversationId,
          messages: messages,
          hasMore: data.hasOlder,
        ),
      );
    }
  }

  List<CoreViewDeltaOp<Conversation>> _conversationDeltaOps(
    core.ViewDelta delta,
  ) {
    return [
      for (final op in delta.ops ?? const <core.ViewDeltaOp>[])
        CoreViewDeltaOp<Conversation>(
          op: op.op,
          key: op.key,
          index: op.index,
          fromIndex: op.fromIndex,
          item: op.item == null
              ? null
              : SdkModelMapper.conversationFromCore(
                  core.conversationFromJson(op.item!),
                ),
        ),
    ];
  }

  @override
  void onNewConversation(core.ConversationEvent event) {
    _fireConversationChanged(event);
  }

  @override
  void onConversationChanged(core.ConversationEvent event) {
    _fireConversationChanged(event);
  }

  @override
  void onTotalUnreadMessageCountChanged(core.ConversationEvent event) {
    final conversationId = event.conversationId?.trim() ?? '';
    if (conversationId.isEmpty) {
      imEventBus.fire(const ConversationUpdateEvent());
      return;
    }
    imEventBus.fire(
      UnreadUpdateEvent(
        conversationId: conversationId,
        unreadCount: event.unreadCount ?? 0,
      ),
    );
  }

  @override
  void onConversationDeleted(core.ConversationEvent event) {
    _fireConversationChanged(event);
  }

  @override
  void onSyncServerStart(core.SyncEvent event) {
    imEventBus.fire(
      SdkSyncUpdatedEvent(SdkModelMapper.syncJsonFromCore(event)),
    );
  }

  @override
  void onSyncServerFinish(core.SyncEvent event) {
    imEventBus.fire(
      SdkSyncUpdatedEvent(SdkModelMapper.syncJsonFromCore(event)),
    );
  }

  @override
  void onSyncServerFailed(core.SyncEvent event) {
    imEventBus.fire(
      SdkSyncUpdatedEvent(SdkModelMapper.syncJsonFromCore(event)),
    );
  }

  @override
  void onSyncProgress(core.ProgressEvent event) {
    imEventBus.fire(
      SdkProgressUpdatedEvent(SdkModelMapper.progressJsonFromCore(event)),
    );
  }

  @override
  void onUploadProgress(core.ProgressEvent event) {
    imEventBus.fire(
      SdkProgressUpdatedEvent(SdkModelMapper.progressJsonFromCore(event)),
    );
  }

  @override
  void onDownloadProgress(core.ProgressEvent event) {
    imEventBus.fire(
      SdkProgressUpdatedEvent(SdkModelMapper.progressJsonFromCore(event)),
    );
  }

  void _fireLifecycle(core.LifecycleEvent event) {
    imEventBus.fire(
      SdkLifecycleUpdatedEvent(SdkModelMapper.lifecycleJsonFromCore(event)),
    );
  }

  void _fireConversationChanged(core.ConversationEvent event) {
    _fireConversationId(event.conversationId);
  }

  void _fireConversationId(String? rawConversationId) {
    final conversationId = rawConversationId?.trim() ?? '';
    imEventBus.fire(
      ConversationUpdateEvent(
        conversationId: conversationId.isEmpty ? null : conversationId,
      ),
    );
  }

  void _fireRecall(core.MessageMutationEvent event) {
    final conversationId = event.conversationId.trim();
    final messageId = (event.serverMsgId ?? event.messageId ?? '').trim();
    if (conversationId.isEmpty || messageId.isEmpty) return;
    imEventBus.fire(
      RecallMessageEvent(conversationId: conversationId, messageId: messageId),
    );
  }
}
