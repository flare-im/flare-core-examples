import 'dart:async';
import 'dart:io';

import 'package:extended_text_field/extended_text_field.dart';
import 'package:flare_im/application/outbound/im_outbound_facade.dart';
import 'package:flare_im/application/providers/active_chat_stack_provider.dart';
import 'package:flare_im/application/providers/auth_state_provider.dart';
import 'package:flare_im/application/providers/chat_outbound_provider.dart';
import 'package:flare_im/application/providers/conversation_state_provider.dart';
import 'package:flare_im/application/providers/im_outbound_provider.dart';
import 'package:flare_im/application/providers/im_sync_state_provider.dart';
import 'package:flare_im/application/providers/locale_provider.dart';
import 'package:flare_im/application/providers/message_state_provider.dart';
import 'package:flare_im/application/providers/workbench_ui_provider.dart';
import 'package:flare_im/application/selectors/message_list_view_model.dart';
import 'package:flare_im/domain/entities/message.dart';
import 'package:flare_im/domain/value_objects/conversation_type.dart' as im;
import 'package:flare_im/domain/value_objects/message_content.dart';
import 'package:flare_im/infrastructure/mappers/sdk_model_mapper.dart';
import 'package:flare_im/infrastructure/media/plain_text_markdown_detect.dart';
import 'package:flare_im/interface/router/app_router.dart';
import 'package:flare_im/interface/theme/flare_im_design.dart';
import 'package:flare_im/interface/widgets/composer/composer_emoji_span_builder.dart';
import 'package:flare_im/interface/widgets/composer/message_composer.dart';
import 'package:flare_im/interface/widgets/composer/sdk_message_build_catalog.dart';
import 'package:flare_im/interface/widgets/composer/sdk_message_build_sheet.dart';
import 'package:flare_im/interface/widgets/conversation_details_panel.dart';
import 'package:flare_im/interface/widgets/location/location_picker_sheet.dart';
import 'package:flare_im/interface/widgets/message/chat_message_list_item.dart';
import 'package:flare_im/shared/i18n/flare_messages.dart';
import 'package:flare_im/shared/layout/workbench_layout.dart';
import 'package:flare_im_ui/flare_im_ui.dart'
    show FlareEmptyState, FlareMessageSliverList;
import 'package:flare_im_ui/flare_im_ui.dart' as kit_sizes show FlareSizes;
import 'package:flare_im_ui/flare_im_ui.dart' as kit_theme show FlareColors;
import 'package:flare_im_ui/flare_im_ui.dart' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String conversationId;
  final bool embedInWorkbench;

  const ChatScreen({
    super.key,
    required this.conversationId,
    this.embedInWorkbench = false,
  });

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> with RouteAware {
  static const _foregroundRefreshInterval = Duration(seconds: 4);

  /// 回调 / 弹窗 / 提示等一次性读取语言文案（非 build 响应式路径）。
  FlareChatCopy get _c => ref.read(flareMessagesProvider).chat;

  final _scrollController = ScrollController();
  final _composerKey = GlobalKey<MessageComposerState>();
  bool _loadingOlder = false;
  late final ActiveChatStackNotifier _activeChatStack;
  late final ImOutboundFacade _imOutbound;
  ModalRoute<dynamic>? _route;
  bool _isForeground = false;
  final Set<String> _subscribedPresenceUserIds = <String>{};
  final Set<String> _presenceQueriedUserIds = <String>{};
  List<String>? _lastRenderedMessageKeys;
  int _tailFollowGeneration = 0;
  final Set<Timer> _tailFollowTimers = <Timer>{};
  Timer? _foregroundRefreshTimer;
  bool _foregroundRefreshInFlight = false;

  /// 引用回复：列表稳定键 + 输入区展示用快照。
  String? _replyTargetMessageKey;
  ComposerReplyQuote? _replyQuoteSnapshot;

  bool _multiSelectMode = false;
  final Set<String> _multiSelectKeys = <String>{};

  String get _cid => widget.conversationId.trim();

  void _flushComposerDraftNow() {
    _composerKey.currentState?.flushDraftNow();
  }

  void _clearReplyTarget() {
    setState(() {
      _replyTargetMessageKey = null;
      _replyQuoteSnapshot = null;
    });
  }

  void _exitMultiSelect() {
    setState(() {
      _multiSelectMode = false;
      _multiSelectKeys.clear();
    });
  }

  void _toggleMultiSelectKey(String messageKey) {
    setState(() {
      if (_multiSelectKeys.contains(messageKey)) {
        _multiSelectKeys.remove(messageKey);
      } else {
        _multiSelectKeys.add(messageKey);
      }
    });
  }

  void _startMultiSelectWith(String messageKey) {
    setState(() {
      _multiSelectMode = true;
      _multiSelectKeys
        ..clear()
        ..add(messageKey);
    });
  }

  void _startReplyToMessageKey(String messageKey) {
    final list = ref.read(messageProvider(_cid));
    final vm = messageRowViewModelForKey(list, messageKey);
    final m = vm?.message;
    if (m == null) return;
    final name = m.senderDisplayName.trim().isNotEmpty
        ? m.senderDisplayName.trim()
        : (m.senderName.trim().isNotEmpty ? m.senderName.trim() : m.senderId);
    setState(() {
      _replyTargetMessageKey = messageKey;
      _replyQuoteSnapshot = ComposerReplyQuote(
        senderName: name,
        preview: m.content.previewText,
      );
    });
  }

  @override
  void initState() {
    super.initState();
    _activeChatStack = ref.read(activeChatStackProvider.notifier);
    _imOutbound = ref.read(imOutboundProvider);
    _scrollController.addListener(_onScrollNearTop);
    Future.microtask(() async {
      if (!mounted) return;
      await _imOutbound.chatEnterLoadAndMarkRead(_cid);
    });
  }

  @override
  void didUpdateWidget(covariant ChatScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.conversationId != widget.conversationId) {
      final oldCid = oldWidget.conversationId.trim();
      _replyTargetMessageKey = null;
      _replyQuoteSnapshot = null;
      _multiSelectMode = false;
      _multiSelectKeys.clear();
      _lastRenderedMessageKeys = null;
      _cancelTailFollowTimers();
      if (_isForeground && oldCid.isNotEmpty) {
        _activeChatStack.remove(oldCid);
        _activeChatStack.push(_cid);
      }
      Future.microtask(() async {
        if (!mounted) return;
        await _imOutbound.chatEnterLoadAndMarkRead(_cid);
        unawaited(_refreshForegroundTimeline());
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == null || route == _route) return;
    if (_route != null) {
      appRouteObserver.unsubscribe(this);
    }
    _route = route;
    appRouteObserver.subscribe(this, route);
    _setForeground(route.isCurrent);
  }

  void _setForeground(bool active) {
    if (_isForeground == active) return;
    _isForeground = active;
    Future<void>(() {
      if (active) {
        if (!mounted) return;
        _activeChatStack.push(_cid);
        _startForegroundRefreshTimer();
        return;
      }
      _activeChatStack.remove(_cid);
      _stopForegroundRefreshTimer();
    });
  }

  @override
  void didPush() => _setForeground(true);

  @override
  void didPopNext() => _setForeground(true);

  @override
  void didPushNext() => _setForeground(false);

  @override
  void didPop() => _setForeground(false);

  @override
  void dispose() {
    _flushComposerDraftNow();
    appRouteObserver.unsubscribe(this);
    _setForeground(false);
    _cancelTailFollowTimers();
    _stopForegroundRefreshTimer();
    _scrollController.removeListener(_onScrollNearTop);
    _scrollController.dispose();
    super.dispose();
  }

  void _startForegroundRefreshTimer() {
    if (_foregroundRefreshTimer != null) return;
    unawaited(_refreshForegroundTimeline());
    _foregroundRefreshTimer = Timer.periodic(_foregroundRefreshInterval, (_) {
      unawaited(_refreshForegroundTimeline());
    });
  }

  void _stopForegroundRefreshTimer() {
    _foregroundRefreshTimer?.cancel();
    _foregroundRefreshTimer = null;
  }

  Future<void> _refreshForegroundTimeline() async {
    if (!mounted || !_isForeground || _foregroundRefreshInFlight) return;
    final cid = _cid;
    if (cid.isEmpty) return;
    _foregroundRefreshInFlight = true;
    try {
      await _imOutbound.chatPullServer(cid);
    } catch (e, st) {
      debugPrint('foreground timeline refresh failed ($cid): $e\n$st');
    } finally {
      _foregroundRefreshInFlight = false;
    }
  }

  /// 正向时间线：offset 接近 0 时加载更早消息。
  void _onScrollNearTop() {
    if (!_scrollController.hasClients || _loadingOlder) return;
    final pos = _scrollController.position;
    if (!pos.hasPixels || pos.maxScrollExtent <= 0) return;
    if (!_isNearTimelineBottom()) {
      _tailFollowGeneration += 1;
    }
    if (pos.pixels > 320) return;
    unawaited(_loadOlderPage());
  }

  bool _isNearTimelineBottom() {
    if (!_scrollController.hasClients) return true;
    final pos = _scrollController.position;
    if (!pos.hasPixels) return true;
    return (pos.maxScrollExtent - pos.pixels) <= 180;
  }

  void _scrollTimelineToBottom({bool animated = true}) {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    final target = pos.maxScrollExtent;
    if ((target - pos.pixels).abs() < 1) return;
    if (!animated) {
      _scrollController.jumpTo(target);
      return;
    }
    unawaited(
      _scrollController.animateTo(
        target,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOutCubic,
      ),
    );
  }

  void _followTimelineTailIfNeeded(MessageListKeysSignal keysSignal) {
    final nextKeys = keysSignal.orderedKeys;
    final previousKeys = _lastRenderedMessageKeys;
    final shouldFollow = _shouldFollowTimelineTail(previousKeys, nextKeys);
    _lastRenderedMessageKeys = List<String>.of(nextKeys);
    if (!shouldFollow) return;
    _scheduleTimelineTailFollow(animated: previousKeys != null);
  }

  void _scheduleTimelineTailFollow({required bool animated}) {
    _cancelTailFollowTimers();
    final generation = ++_tailFollowGeneration;
    void scroll({required bool animated}) {
      if (!mounted) return;
      if (generation != _tailFollowGeneration) return;
      _scrollTimelineToBottom(animated: animated);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      scroll(animated: animated);
    });

    for (final delay in const [
      Duration(milliseconds: 80),
      Duration(milliseconds: 180),
      Duration(milliseconds: 420),
      Duration(milliseconds: 760),
    ]) {
      late final Timer timer;
      timer = Timer(delay, () {
        _tailFollowTimers.remove(timer);
        scroll(animated: false);
      });
      _tailFollowTimers.add(timer);
    }
  }

  void _cancelTailFollowTimers() {
    _tailFollowGeneration += 1;
    for (final timer in _tailFollowTimers) {
      timer.cancel();
    }
    _tailFollowTimers.clear();
  }

  bool _shouldFollowTimelineTail(
    List<String>? previousKeys,
    List<String> nextKeys,
  ) {
    if (nextKeys.isEmpty) return false;
    if (previousKeys == null) return true;
    if (previousKeys.isEmpty) return true;
    final tailChanged = previousKeys.last != nextKeys.last;
    final appendedAtTail =
        nextKeys.length > previousKeys.length &&
        nextKeys.length >= previousKeys.length &&
        _hasSamePrefix(previousKeys, nextKeys);
    if (!tailChanged && !appendedAtTail) return false;
    return _isNearTimelineBottom();
  }

  bool _hasSamePrefix(List<String> prefix, List<String> list) {
    if (prefix.length > list.length) return false;
    for (var i = 0; i < prefix.length; i += 1) {
      if (prefix[i] != list[i]) return false;
    }
    return true;
  }

  Future<void> _loadOlderPage() async {
    if (_loadingOlder || !mounted) return;
    _loadingOlder = true;
    try {
      await ref.read(imOutboundProvider).chatLoadMore(_cid);
    } catch (e, st) {
      debugPrint('loadMore failed: $e\n$st');
    } finally {
      if (mounted) _loadingOlder = false;
    }
  }

  Future<void> _onRefresh() async {
    await ref.read(imOutboundProvider).chatPullServerAndMarkRead(_cid);
  }

  void _dismissComposerMoreGrid() {
    _composerKey.currentState?.dismissMoreFeatureGrid();
  }

  Future<void> _ensurePeerPresence(String peerUserId) async {
    final uid = peerUserId.trim();
    if (uid.isEmpty) return;
    try {
      if (_subscribedPresenceUserIds.add(uid)) {
        await _imOutbound.chatSubscribeUserPresence([uid]);
      }
      if (!_presenceQueriedUserIds.add(uid)) return;
      final presences = await _imOutbound.chatBatchGetUserPresence([uid]);
      final raw = presences[uid];
      final user = SdkModelMapper.userFromPresenceEntry(uid, raw);
      if (user != null && mounted) {
        ref.read(userDirectoryProvider.notifier).upsert(user);
      }
      if (raw is Map) {
        final online = raw['isOnline'] == true;
        if (mounted) {
          ref.read(presenceMapProvider.notifier).setOnline(uid, online);
        }
      } else if (raw is bool && mounted) {
        ref.read(presenceMapProvider.notifier).setOnline(uid, raw);
      }
    } catch (e, st) {
      debugPrint('ensure peer presence failed: $e\n$st');
      _subscribedPresenceUserIds.remove(uid);
      _presenceQueriedUserIds.remove(uid);
    }
  }

  Future<void> _syncConversationMeta() async {
    await ref.read(imOutboundProvider).chatSyncConversationMeta(_cid);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_c.syncRequested)));
  }

  void _openMessageSearch() {
    navigateToMessageSearch(context, conversationId: _cid);
  }

  Future<void> _openConversationDetails() async {
    if (isWorkbenchWide(context)) {
      ref.read(workbenchDetailsOpenProvider.notifier).state = true;
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: FlareImDesign.card,
      builder: (ctx) => SizedBox(
        height: MediaQuery.sizeOf(ctx).height * 0.88,
        child: ConversationDetailsPanel(
          conversationId: _cid,
          onClose: () => Navigator.pop(ctx),
        ),
      ),
    );
  }

  Future<void> _handleOutboundSendText(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;
    final key = _replyTargetMessageKey;
    if (key != null && key.isNotEmpty) {
      final list = ref.read(messageProvider(_cid));
      final vm = messageRowViewModelForKey(list, key);
      final quoted = vm?.message;
      if (quoted == null || quoted.isRecalled) {
        _clearReplyTarget();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(_c.quoteFallbackPlain)));
        }
        await ref
            .read(imOutboundProvider)
            .chatSendTextAndClearDraft(_cid, trimmed);
        return;
      }
      try {
        await ref
            .read(imOutboundProvider)
            .chatSendQuoteTextAndClearDraft(_cid, trimmed, quoted);
        _clearReplyTarget();
      } catch (e, st) {
        debugPrint('send quote failed: $e\n$st');
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_c.quoteSendFailed(e))));
      }
      return;
    }
    await ref.read(imOutboundProvider).chatSendTextAndClearDraft(_cid, trimmed);
  }

  Future<void> _handleOutboundEmoji(String packKey) async {
    final key = packKey.trim();
    if (key.isEmpty) return;
    if (_replyTargetMessageKey != null) {
      _clearReplyTarget();
    }
    await ref.read(messageProvider(_cid).notifier).sendEmoji(key);
  }

  Future<void> _handleOutboundSticker(ComposerStickerPick pick) async {
    if (_replyTargetMessageKey != null) {
      _clearReplyTarget();
    }
    await ref
        .read(messageProvider(_cid).notifier)
        .sendSticker(
          stickerId: pick.stickerId,
          packageId: pick.packageId,
          url: pick.assetPath,
          width: 120,
          height: 120,
          stickerFormat: 'webp',
        );
  }

  Future<void> _handleOutboundRichDoc(
    ChatRichDocInputFormat format,
    String source,
  ) async {
    if (_replyTargetMessageKey != null) {
      _clearReplyTarget();
    }
    try {
      await ref
          .read(imOutboundProvider)
          .chatSendRichDoc(
            _cid,
            format: _richDocWireFormat(format),
            source: source,
          );
    } catch (e, st) {
      debugPrint('send rich doc failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_c.richTextSendFailed(e))));
    }
  }

  String _richDocWireFormat(ChatRichDocInputFormat format) {
    return switch (format) {
      ChatRichDocInputFormat.markdown => 'markdown',
      ChatRichDocInputFormat.html => 'html',
      ChatRichDocInputFormat.docJson => 'docJson',
    };
  }

  Future<void> _handleOutboundBusinessMessage(
    ChatBusinessMessageKind kind,
  ) async {
    if (_replyTargetMessageKey != null) {
      _clearReplyTarget();
    }
    try {
      switch (kind) {
        case ChatBusinessMessageKind.location:
          await _showSendLocationDialog();
        case ChatBusinessMessageKind.contactCard:
          await _showSendContactCardDialog();
        case ChatBusinessMessageKind.schedule:
          await _showSendScheduleDialog();
        case ChatBusinessMessageKind.task:
          await _showSendTaskDialog();
      }
    } catch (e, st) {
      debugPrint('send business message failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_c.sendFailed(e))));
    }
  }

  String _newBusinessId(String prefix) {
    final me = ref.read(currentUserProvider)?.userId.trim() ?? 'local';
    final ts = DateTime.now().microsecondsSinceEpoch;
    return '${prefix}_${me.hashCode.abs().toRadixString(16)}_$ts';
  }

  List<String> _splitUserIds(String raw) => raw
      .split(RegExp(r'[,，\s]+'))
      .map((e) => e.trim())
      .where((e) => e.isNotEmpty)
      .toList();

  Map<String, String>? _parseStringMapLines(String raw) {
    final out = <String, String>{};
    for (final line in raw.split(RegExp(r'\r?\n'))) {
      final t = line.trim();
      if (t.isEmpty || t.startsWith('#')) continue;
      final eq = t.indexOf('=');
      final col = t.indexOf(':');
      var sep = -1;
      if (eq >= 0 && (col < 0 || eq <= col)) {
        sep = eq;
      } else if (col >= 0) {
        sep = col;
      }
      if (sep < 0) continue;
      final key = t.substring(0, sep).trim();
      final value = t.substring(sep + 1).trim();
      if (key.isNotEmpty) out[key] = value;
    }
    return out.isEmpty ? null : out;
  }

  List<Map<String, dynamic>> _parseImageGroupLines(String raw) {
    final out = <Map<String, dynamic>>[];
    for (final line in raw.split(RegExp(r'\r?\n'))) {
      final t = line.trim();
      if (t.isEmpty || t.startsWith('#')) continue;
      final pipe = t.indexOf('|');
      final imageId = pipe >= 0 ? t.substring(0, pipe).trim() : '';
      final url = pipe >= 0 ? t.substring(pipe + 1).trim() : t;
      out.add({
        'uuid': '',
        'imageId': imageId.isNotEmpty || !url.startsWith('http')
            ? (imageId.isNotEmpty ? imageId : url)
            : '',
        'url': url.startsWith('http') ? url : '',
        'mimeType': '',
        'size': 0,
        'width': 0,
        'height': 0,
        'format': 0,
        'animated': false,
      });
    }
    return out;
  }

  String? _nonEmpty(String? value) {
    final t = (value ?? '').trim();
    return t.isEmpty ? null : t;
  }

  int? _intOrNull(String? value) {
    final t = (value ?? '').trim();
    if (t.isEmpty) return null;
    return int.tryParse(t);
  }

  double _requiredDouble(Map<String, String> values, String key, String label) {
    final v = double.tryParse((values[key] ?? '').trim());
    if (v == null) throw StateError(_c.mustBeNumber(label));
    return v;
  }

  ({String op, Map<String, dynamic> params}) _buildSdkMessageParams(
    SdkMessageBuildKind kind,
    Map<String, String> values,
  ) {
    switch (kind) {
      case SdkMessageBuildKind.threadReply:
        return (
          op: 'create_thread_reply',
          params: {
            'threadId': (values['threadId'] ?? '').trim(),
            'text': values['text'] ?? '',
          },
        );
      case SdkMessageBuildKind.imageGroup:
        final images = _parseImageGroupLines(values['imageLines'] ?? '');
        if (images.isEmpty) throw StateError(_c.atLeastOneImageRow);
        return (
          op: 'create_with_content',
          params: {
            'content': {
              'contentType': 'image_group',
              'images': images,
              'description': (values['description'] ?? '').trim(),
              'metadata':
                  _parseStringMapLines(values['metadata'] ?? '') ??
                  <String, String>{},
            },
          },
        );
      case SdkMessageBuildKind.location:
        return (
          op: 'create_location',
          params: {
            'longitude': _requiredDouble(values, 'longitude', _c.longitude),
            'latitude': _requiredDouble(values, 'latitude', _c.latitude),
            if (_nonEmpty(values['title']) != null)
              'title': _nonEmpty(values['title']),
            if (_nonEmpty(values['address']) != null)
              'address': _nonEmpty(values['address']),
            if (_intOrNull(values['zoom']) != null)
              'zoom': _intOrNull(values['zoom']),
            if (_nonEmpty(values['snapshotUrl']) != null)
              'snapshotUrl': _nonEmpty(values['snapshotUrl']),
            if (_nonEmpty(values['snapshotLocalPath']) != null)
              'snapshotLocalPath': _nonEmpty(values['snapshotLocalPath']),
          },
        );
      case SdkMessageBuildKind.card:
        return (op: 'create_card', params: _compact(values));
      case SdkMessageBuildKind.sticker:
        return (
          op: 'create_sticker',
          params: {
            'stickerId': (values['stickerId'] ?? '').trim(),
            if (_nonEmpty(values['packageId']) != null)
              'packageId': _nonEmpty(values['packageId']),
            if (_nonEmpty(values['url']) != null)
              'url': _nonEmpty(values['url']),
            if (_intOrNull(values['width']) != null)
              'width': _intOrNull(values['width']),
            if (_intOrNull(values['height']) != null)
              'height': _intOrNull(values['height']),
            if (_nonEmpty(values['format']) != null)
              'format': _nonEmpty(values['format']),
          },
        );
      case SdkMessageBuildKind.linkCard:
        return (op: 'create_link_card', params: _compact(values));
      case SdkMessageBuildKind.miniProgram:
        return (
          op: 'create_mini_program',
          params: {
            'appId': (values['appId'] ?? '').trim(),
            if (_nonEmpty(values['title']) != null)
              'title': _nonEmpty(values['title']),
            if (_nonEmpty(values['path']) != null)
              'path': _nonEmpty(values['path']),
            if (_nonEmpty(values['thumbnailUrl']) != null)
              'thumbnailUrl': _nonEmpty(values['thumbnailUrl']),
            if (_parseStringMapLines(values['extra'] ?? '') != null)
              'extra': _parseStringMapLines(values['extra'] ?? ''),
          },
        );
      case SdkMessageBuildKind.notification:
        return (op: 'create_notification', params: _compact(values));
      case SdkMessageBuildKind.vote:
        final options = (values['options'] ?? '')
            .split(RegExp(r'\r?\n'))
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();
        if (options.length < 2) throw StateError(_c.voteMinOptions);
        return (
          op: 'create_vote',
          params: {
            'voteId': (values['voteId'] ?? '').trim(),
            'title': (values['title'] ?? '').trim(),
            'options': options,
            if (_splitUserIds(values['participantUserIds'] ?? '').isNotEmpty)
              'participantUserIds': _splitUserIds(
                values['participantUserIds'] ?? '',
              ),
          },
        );
      case SdkMessageBuildKind.task:
        return (
          op: 'create_task',
          params: {
            'taskId': (values['taskId'] ?? '').trim(),
            'title': (values['title'] ?? '').trim(),
            if (_nonEmpty(values['status']) != null)
              'status': _nonEmpty(values['status']),
            if (_splitUserIds(values['participantUserIds'] ?? '').isNotEmpty)
              'participantUserIds': _splitUserIds(
                values['participantUserIds'] ?? '',
              ),
          },
        );
      case SdkMessageBuildKind.schedule:
        final startDelta = _intOrNull(values['startAfterMinutes']) ?? 60;
        final duration = _intOrNull(values['durationMinutes']) ?? 60;
        final start = DateTime.now().add(Duration(minutes: startDelta));
        final end = start.add(Duration(minutes: duration <= 0 ? 60 : duration));
        return (
          op: 'create_schedule',
          params: {
            'scheduleId': (values['scheduleId'] ?? '').trim(),
            'title': (values['title'] ?? '').trim(),
            'startTimeMs': start.millisecondsSinceEpoch,
            'endTimeMs': end.millisecondsSinceEpoch,
            if (_splitUserIds(values['participantUserIds'] ?? '').isNotEmpty)
              'participantUserIds': _splitUserIds(
                values['participantUserIds'] ?? '',
              ),
          },
        );
      case SdkMessageBuildKind.announcement:
        return (op: 'create_announcement', params: _compact(values));
      case SdkMessageBuildKind.custom:
        return (
          op: 'create_custom',
          params: {'type': (values['type'] ?? '').trim()},
        );
      case SdkMessageBuildKind.placeholder:
        return (
          op: 'create_placeholder',
          params: {'reason': (values['reason'] ?? '').trim()},
        );
    }
  }

  Map<String, dynamic> _compact(Map<String, String> values) {
    final out = <String, dynamic>{};
    for (final e in values.entries) {
      final v = e.value.trim();
      if (v.isNotEmpty) out[e.key] = v;
    }
    return out;
  }

  Widget _businessTextField(
    TextEditingController controller, {
    required String label,
    String? hint,
    IconData? icon,
    TextInputType? keyboardType,
    ValueChanged<String>? onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        onChanged: onChanged,
        style: TextStyle(
          fontSize: kit_sizes.FlareSizes.fontSizeXl,
          height: 1.25,
          fontWeight: FontWeight.w500,
          color: kit_theme.FlareColors.of(context).textPrimary,
        ),
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          prefixIcon: icon == null
              ? null
              : Icon(
                  icon,
                  size: 19,
                  color: kit_theme.FlareColors.of(context).textSecondary,
                ),
          filled: true,
          fillColor: kit_theme.FlareColors.of(context).bgSecondary,
          floatingLabelBehavior: FloatingLabelBehavior.always,
          labelStyle: TextStyle(
            fontSize: kit_sizes.FlareSizes.fontSizeSm,
            fontWeight: FontWeight.w600,
            color: kit_theme.FlareColors.of(context).textSecondary,
          ),
          hintStyle: TextStyle(
            fontSize: kit_sizes.FlareSizes.fontSizeLg,
            color: kit_theme.FlareColors.of(
              context,
            ).textSecondary.withValues(alpha: 0.78),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 13,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: kit_theme.FlareColors.of(context).borderSecondary,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: kit_theme.FlareColors.of(context).borderSecondary,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: kit_theme.FlareColors.of(context).primary,
              width: 1.4,
            ),
          ),
        ),
      ),
    );
  }

  Future<bool> _showBusinessMessageDialog({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accent,
    required List<Widget> fields,
  }) async {
    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.38),
      builder: (ctx) {
        return AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.only(
            left: 22,
            right: 22,
            bottom: MediaQuery.viewInsetsOf(ctx).bottom,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 360),
              child: Material(
                color: Colors.transparent,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: kit_theme.FlareColors.of(context).bgPrimary,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.16),
                        blurRadius: 28,
                        offset: const Offset(0, 16),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 18),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 46,
                                height: 46,
                                decoration: BoxDecoration(
                                  color: accent.withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Icon(icon, color: accent, size: 25),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize:
                                            kit_sizes.FlareSizes.fontSize4xl,
                                        height: 1.2,
                                        fontWeight: FontWeight.w800,
                                        color: kit_theme.FlareColors.of(
                                          context,
                                        ).textPrimary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      subtitle,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize:
                                            kit_sizes.FlareSizes.fontSizeSm,
                                        height: 1.25,
                                        color: kit_theme.FlareColors.of(
                                          context,
                                        ).textSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          ...fields,
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor: kit_theme.FlareColors.of(
                                      context,
                                    ).primary,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 13,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: Text(
                                    _c.cancel,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: kit_theme.FlareColors.of(
                                      context,
                                    ).primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 13,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: Text(
                                    _c.send,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
    return ok == true;
  }

  Future<void> _showSendLocationDialog() async {
    final picked = await showLocationPickerSheet(context);
    if (picked == null || !mounted) return;
    await ref
        .read(imOutboundProvider)
        .chatSendLocation(
          _cid,
          latitude: picked.latitude,
          longitude: picked.longitude,
          title: picked.title,
          address: picked.address,
          zoom: picked.zoom,
          snapshotUrl: picked.snapshotUrl,
        );
  }

  Future<void> _showSendContactCardDialog() async {
    final me = ref.read(currentUserProvider);
    final id = TextEditingController(text: me?.userId ?? '');
    final name = TextEditingController(
      text: me?.displayName ?? me?.userId ?? '',
    );
    final subtitle = TextEditingController(text: _c.defaultUserName);
    final avatar = TextEditingController(text: me?.avatar ?? '');
    try {
      final ok = await _showBusinessMessageDialog(
        title: _c.sendCard,
        subtitle: _c.sendCardDesc,
        icon: Icons.badge_rounded,
        accent: kit_theme.FlareColors.of(context).primaryActive,
        fields: [
          _businessTextField(
            id,
            label: _c.userId,
            icon: Icons.alternate_email_rounded,
          ),
          _businessTextField(
            name,
            label: _c.displayName,
            icon: Icons.person_outline_rounded,
          ),
          _businessTextField(
            subtitle,
            label: _c.subtitleLabel,
            icon: Icons.short_text_rounded,
          ),
          _businessTextField(
            avatar,
            label: _c.avatarUrlOptional,
            hint: 'https://...',
            icon: Icons.image_outlined,
          ),
        ],
      );
      if (!ok) return;
      await ref
          .read(imOutboundProvider)
          .chatSendContactCard(
            _cid,
            id: id.text,
            cardType: 'user',
            title: name.text,
            subtitle: subtitle.text,
            avatar: avatar.text,
          );
    } finally {
      id.dispose();
      name.dispose();
      subtitle.dispose();
      avatar.dispose();
    }
  }

  Future<void> _showSendTaskDialog() async {
    final title = TextEditingController(text: _c.taskTitleDefault);
    final status = TextEditingController(text: 'todo');
    final participants = TextEditingController();
    try {
      final ok = await _showBusinessMessageDialog(
        title: _c.sendTask,
        subtitle: _c.taskCardDesc,
        icon: Icons.task_alt_rounded,
        accent: kit_theme.FlareColors.of(context).robot,
        fields: [
          _businessTextField(
            title,
            label: _c.taskTitleLabel,
            icon: Icons.check_circle_outline_rounded,
          ),
          _businessTextField(
            status,
            label: _c.statusLabel,
            hint: 'todo / doing / done',
            icon: Icons.flag_outlined,
          ),
          _businessTextField(
            participants,
            label: _c.participantIds,
            hint: _c.commaOrSpaceSeparated,
            icon: Icons.group_outlined,
          ),
        ],
      );
      if (!ok) return;
      await ref
          .read(imOutboundProvider)
          .chatSendTask(
            _cid,
            taskId: _newBusinessId('task'),
            title: title.text,
            status: status.text,
            participantUserIds: _splitUserIds(participants.text),
          );
    } finally {
      title.dispose();
      status.dispose();
      participants.dispose();
    }
  }

  Future<void> _showSendScheduleDialog() async {
    final title = TextEditingController(text: _c.scheduleTitleDefault);
    final startAfterMinutes = TextEditingController(text: '30');
    final durationMinutes = TextEditingController(text: '60');
    final participants = TextEditingController();
    try {
      final ok = await _showBusinessMessageDialog(
        title: _c.sendSchedule,
        subtitle: _c.scheduleCardDesc,
        icon: Icons.calendar_month_rounded,
        accent: kit_theme.FlareColors.of(context).important,
        fields: [
          _businessTextField(
            title,
            label: _c.scheduleTitleLabel,
            icon: Icons.event_note_outlined,
          ),
          _businessTextField(
            startAfterMinutes,
            label: _c.minutesUntilStart,
            icon: Icons.schedule_rounded,
            keyboardType: TextInputType.number,
          ),
          _businessTextField(
            durationMinutes,
            label: _c.durationMinutes,
            icon: Icons.timelapse_rounded,
            keyboardType: TextInputType.number,
          ),
          _businessTextField(
            participants,
            label: _c.participantIds,
            hint: _c.commaOrSpaceSeparated,
            icon: Icons.group_outlined,
          ),
        ],
      );
      if (!ok) return;
      final startDelta = int.tryParse(startAfterMinutes.text.trim()) ?? 30;
      final duration = int.tryParse(durationMinutes.text.trim()) ?? 60;
      final start = DateTime.now().add(Duration(minutes: startDelta));
      final end = start.add(Duration(minutes: duration <= 0 ? 60 : duration));
      await ref
          .read(imOutboundProvider)
          .chatSendSchedule(
            _cid,
            scheduleId: _newBusinessId('schedule'),
            title: title.text,
            startTimeMs: start.millisecondsSinceEpoch,
            endTimeMs: end.millisecondsSinceEpoch,
            participantUserIds: _splitUserIds(participants.text),
          );
    } finally {
      title.dispose();
      startAfterMinutes.dispose();
      durationMinutes.dispose();
      participants.dispose();
    }
  }

  /// The first picked path, or null when the picker was dismissed; other
  /// contract errors surface as a snackbar.
  String? _pickedPath(ui.FlarePlatformResult<List<ui.FlarePickedFile>> result) {
    if (result.isOk) {
      final path = result.valueOrNull?.firstOrNull?.path?.trim() ?? '';
      return path.isEmpty ? null : path;
    }
    final error = result.errorOrNull!;
    if (error.code == ui.FlarePlatformErrorCode.cancelled) return null;
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_c.sendFailed(error.message ?? error.code.name)),
        ),
      );
    }
    return null;
  }

  Future<void> _pickAndSendImage() async {
    final path = _pickedPath(await ui.FlarePlatform.of(context).pickImages());
    if (path == null) return;
    await ref.read(messageProvider(_cid).notifier).sendImageByPath(path);
  }

  Future<void> _pickAndSendVideo() async {
    final path = _pickedPath(
      await ui.FlarePlatform.of(
        context,
      ).pickFiles(const ui.FlarePickFilesOptions(accept: ['video/*'])),
    );
    if (path == null) return;
    await ref.read(messageProvider(_cid).notifier).sendVideoByPath(path);
  }

  Future<void> _pickAndSendFile({List<String> accept = const []}) async {
    final path = _pickedPath(
      await ui.FlarePlatform.of(
        context,
      ).pickFiles(ui.FlarePickFilesOptions(accept: accept)),
    );
    if (path == null) return;
    await ref.read(messageProvider(_cid).notifier).sendFileByPath(path);
  }

  Future<void> _pickAndSendAudio() async {
    final platform = ui.FlarePlatform.of(context);
    final mode = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.mic),
              title: Text(_c.holdToRecord),
              subtitle: Text(_c.releaseToSendSlideCancel),
              onTap: () => Navigator.of(ctx).pop('record_hold'),
            ),
            ListTile(
              leading: const Icon(Icons.library_music),
              title: Text(_c.pickAudioFile),
              onTap: () => Navigator.of(ctx).pop('pick'),
            ),
          ],
        ),
      ),
    );
    if (mode == null) return;
    if (mode == 'record_hold') {
      await _recordAndSendAudio();
      return;
    }
    final path = _pickedPath(
      await platform.pickFiles(
        const ui.FlarePickFilesOptions(accept: ['audio/*']),
      ),
    );
    if (path == null) return;
    await ref.read(messageProvider(_cid).notifier).sendAudioByPath(path);
  }

  Future<void> _recordAndSendAudio() async {
    final recorder = AudioRecorder();
    String? recordedPath;
    bool isRecording = false;
    bool cancelOnRelease = false;
    double startGlobalY = 0;
    try {
      final hasPermission = await recorder.hasPermission();
      if (!hasPermission) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(_c.noMicPermission)));
        return;
      }

      final tmp = await getTemporaryDirectory();
      final dir = Directory('${tmp.path}/flare_rec');
      if (!dir.existsSync()) {
        dir.createSync(recursive: true);
      }
      final path =
          '${dir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';

      if (!mounted) return;
      await showDialog<void>(
        context: context,
        barrierDismissible: true,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setDialogState) {
            Future<void> startRecord(LongPressStartDetails details) async {
              if (isRecording) return;
              startGlobalY = details.globalPosition.dy;
              cancelOnRelease = false;
              await recorder.start(
                const RecordConfig(
                  encoder: AudioEncoder.aacLc,
                  bitRate: 64000,
                  sampleRate: 44100,
                ),
                path: path,
              );
              setDialogState(() {
                isRecording = true;
              });
            }

            Future<void> finishRecord() async {
              if (!isRecording) return;
              final out = await recorder.stop();
              setDialogState(() {
                isRecording = false;
              });
              if (cancelOnRelease) {
                final p = (out ?? '').trim();
                if (p.isNotEmpty) {
                  final f = File(p);
                  if (f.existsSync()) {
                    f.deleteSync();
                  }
                }
                if (ctx.mounted) Navigator.of(ctx).pop();
                return;
              }
              recordedPath = (out ?? '').trim();
              if (ctx.mounted) Navigator.of(ctx).pop();
            }

            return AlertDialog(
              title: Text(_c.holdToRecord),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onLongPressStart: startRecord,
                    onLongPressMoveUpdate: (d) {
                      if (!isRecording) return;
                      final shouldCancel =
                          (startGlobalY - d.globalPosition.dy) > 70;
                      if (shouldCancel != cancelOnRelease) {
                        setDialogState(() {
                          cancelOnRelease = shouldCancel;
                        });
                      }
                    },
                    onLongPressEnd: (_) async {
                      await finishRecord();
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      width: 160,
                      height: 160,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: cancelOnRelease
                            ? Colors.red.withValues(alpha: 0.2)
                            : Theme.of(
                                ctx,
                              ).colorScheme.primary.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(80),
                        border: Border.all(
                          color: cancelOnRelease
                              ? Colors.red
                              : Theme.of(ctx).colorScheme.primary,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        isRecording
                            ? (cancelOnRelease
                                  ? _c.releaseToCancel
                                  : _c.releaseToSend)
                            : _c.holdToRecord,
                        style: TextStyle(
                          color: cancelOnRelease
                              ? Colors.red
                              : Theme.of(ctx).colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    isRecording ? _c.slideUpToCancel : _c.holdButtonToRecord,
                    style: Theme.of(ctx).textTheme.bodySmall,
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () async {
                    if (isRecording) {
                      cancelOnRelease = true;
                      await finishRecord();
                    } else if (ctx.mounted) {
                      Navigator.of(ctx).pop();
                    }
                  },
                  child: Text(_c.close),
                ),
              ],
            );
          },
        ),
      );
      final trimmed = (recordedPath ?? '').trim();
      if (trimmed.isNotEmpty && mounted) {
        await ref.read(messageProvider(_cid).notifier).sendAudioByPath(trimmed);
      }
    } on MissingPluginException {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_c.recordPluginNotLoaded)));
    } on PlatformException catch (e) {
      if (!mounted) return;
      final msg = (e.message ?? '').trim();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            msg.isEmpty ? _c.recordFailedRetry : _c.recordFailed(msg),
          ),
        ),
      );
    } finally {
      await recorder.dispose();
    }
  }

  Future<void> _handlePickMedia(ComposerPickMediaKind kind) async {
    try {
      switch (kind) {
        case ComposerPickMediaKind.image:
          await _pickAndSendImage();
          break;
        case ComposerPickMediaKind.video:
          await _pickAndSendVideo();
          break;
        case ComposerPickMediaKind.imageOrVideo:
          final path = _pickedPath(
            await ui.FlarePlatform.of(context).pickFiles(
              const ui.FlarePickFilesOptions(accept: ['image/*', 'video/*']),
            ),
          );
          if (path == null) return;
          final ext = path.contains('.')
              ? path.split('.').last.toLowerCase()
              : '';
          final isVideo = const {
            'mp4',
            'mov',
            'm4v',
            'avi',
            'webm',
            'mkv',
          }.contains(ext);
          if (isVideo) {
            await ref
                .read(messageProvider(_cid).notifier)
                .sendVideoByPath(path);
          } else {
            await ref
                .read(messageProvider(_cid).notifier)
                .sendImageByPath(path);
          }
          break;
        case ComposerPickMediaKind.audio:
          await _pickAndSendAudio();
          break;
        case ComposerPickMediaKind.file:
        case ComposerPickMediaKind.folder:
          await _pickAndSendFile();
          break;
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_c.sendFailed(e))));
    }
  }

  Future<void> _editOwnMessage(Message message) async {
    final content = message.content;
    if (content is TextContent) {
      await _editOwnTextMessage(message, content.text);
      return;
    }
    if (content is RichDocContent) {
      await _editOwnRichDocMessage(message, content);
    }
  }

  Future<void> _editOwnTextMessage(Message message, String text) async {
    final controller = TextEditingController(text: text);
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              title: Text(_c.editMessage),
              content: ExtendedTextField(
                controller: controller,
                maxLines: 4,
                specialTextSpanBuilder:
                    PlainTextMarkdownDetect.isMarkdown(controller.text)
                    ? null
                    : ComposerEmojiSpanBuilder(
                        inlineSize: 15 * 1.72,
                        localeTag: Localizations.maybeLocaleOf(
                          dialogCtx,
                        )?.toLanguageTag(),
                      ),
                onChanged: (_) => setDialogState(() {}),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(_c.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(_c.save),
                ),
              ],
            );
          },
        ),
      );
      if (ok != true || !mounted) return;
      final next = controller.text.trim();
      if (next.isEmpty || next == text) return;
      await ref
          .read(imOutboundProvider)
          .chatEditOwnText(_cid, message.serverId, next);
    } finally {
      controller.dispose();
    }
  }

  Future<void> _editOwnRichDocMessage(
    Message message,
    RichDocContent content,
  ) async {
    final initialDocJson = content.docJson.trim();
    final initialPlain = content.plainText.trim();
    final initialFormat = initialDocJson.isNotEmpty
        ? ChatRichDocInputFormat.docJson
        : ChatRichDocInputFormat.markdown;
    final controller = TextEditingController(
      text: initialDocJson.isNotEmpty ? initialDocJson : initialPlain,
    );
    var selected = initialFormat;
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final label = switch (selected) {
              ChatRichDocInputFormat.markdown => 'Markdown',
              ChatRichDocInputFormat.html => 'HTML',
              ChatRichDocInputFormat.docJson => 'Doc JSON',
            };
            return AlertDialog(
              title: Text(_c.editRichText),
              content: SizedBox(
                width: 560,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: SegmentedButton<ChatRichDocInputFormat>(
                        segments: const [
                          ButtonSegment(
                            value: ChatRichDocInputFormat.markdown,
                            label: Text('Markdown'),
                          ),
                          ButtonSegment(
                            value: ChatRichDocInputFormat.html,
                            label: Text('HTML'),
                          ),
                          ButtonSegment(
                            value: ChatRichDocInputFormat.docJson,
                            label: Text('JSON'),
                          ),
                        ],
                        selected: {selected},
                        showSelectedIcon: false,
                        onSelectionChanged: (next) {
                          setDialogState(() => selected = next.first);
                        },
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: controller,
                      maxLines: 10,
                      minLines: 6,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      decoration: InputDecoration(
                        labelText: label,
                        filled: true,
                        fillColor: kit_theme.FlareColors.of(
                          context,
                        ).bgSecondary,
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(_c.cancel),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: Text(_c.save),
                ),
              ],
            );
          },
        ),
      );
      if (ok != true || !mounted) return;
      final next = controller.text.trim();
      if (next.isEmpty) return;
      if (selected == initialFormat &&
          next == (initialDocJson.isNotEmpty ? initialDocJson : initialPlain)) {
        return;
      }
      await ref
          .read(imOutboundProvider)
          .chatEditOwnRichDoc(
            _cid,
            message.serverId,
            format: _richDocWireFormat(selected),
            source: next,
          );
    } catch (e, st) {
      debugPrint('edit rich doc failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_c.richTextEditFailed(e))));
    } finally {
      controller.dispose();
    }
  }

  List<Message> _selectedMessages() {
    if (_multiSelectKeys.isEmpty) return const [];
    final list = ref.read(messageProvider(_cid));
    final out = <Message>[];
    for (final key in _multiSelectKeys) {
      final m = messageRowViewModelForKey(list, key)?.message;
      if (m != null) out.add(m);
    }
    return out;
  }

  String _messageOperationId(Message message) {
    final sid = message.serverId.trim();
    if (sid.isNotEmpty) return sid;
    return message.clientMsgId.trim();
  }

  Future<void> _showSdkMessageBuildMenu() async {
    _dismissComposerMoreGrid();
    final draft = await showSdkMessageBuildSheet(context);
    if (draft == null || !mounted) return;
    try {
      final request = _buildSdkMessageParams(draft.kind, draft.values);
      await ref
          .read(imOutboundProvider)
          .chatSendMessageBuild(_cid, request.op, request.params);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_c.sdkMessageSent)));
    } catch (e, st) {
      debugPrint('send sdk message build failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_c.sendFailed(e))));
    }
  }

  Future<void> _forwardSelected({required bool merge}) async {
    final selected = _selectedMessages();
    final ids = selected
        .map(_messageOperationId)
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    if (ids.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_c.nothingToForward)));
      return;
    }
    try {
      await ref
          .read(imOutboundProvider)
          .chatForwardMessages(
            _cid,
            messageIds: ids,
            merge: merge,
            title: merge
                ? _c.forwardMergedCount(ids.length)
                : _c.forwardMessage,
          );
      _exitMultiSelect();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_c.forwardedToCurrent)));
    } catch (e, st) {
      debugPrint('forward selected failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_c.forwardFailed(e))));
    }
  }

  Future<void> _deleteSelectedForSelf() async {
    final ids = _selectedMessages()
        .map(_messageOperationId)
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    if (ids.isEmpty) return;
    try {
      for (final id in ids) {
        await ref.read(imOutboundProvider).chatDeleteForSelf(_cid, id);
      }
      _exitMultiSelect();
    } catch (e, st) {
      debugPrint('delete selected failed: $e\n$st');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_c.deleteFailed(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final outbound = ref.read(imOutboundProvider);
    ref.listen<ChatOutboundEvent?>(chatOutboundProvider(_cid), (prev, next) {
      if (next == null) return;
      final bus = ref.read(chatOutboundProvider(_cid).notifier);
      switch (next) {
        case ChatOutboundSendText(:final text):
          unawaited(_handleOutboundSendText(text));
        case ChatOutboundSendEmojiPackKey(:final packKey):
          unawaited(_handleOutboundEmoji(packKey));
        case ChatOutboundSendSticker(:final pick):
          unawaited(_handleOutboundSticker(pick));
        case ChatOutboundSendRichDoc(:final format, :final source):
          unawaited(_handleOutboundRichDoc(format, source));
        case ChatOutboundRequestBusinessMessage(:final kind):
          unawaited(_handleOutboundBusinessMessage(kind));
      }
      bus.clear();
    });

    final conversationList = ref.watch(conversationProvider);
    final selectedConversation = ref.watch(selectedConversationProvider);
    final routeSelectedConversation =
        selectedConversation?.conversationId.trim() == _cid
        ? selectedConversation
        : null;
    final conversation =
        routeSelectedConversation ?? conversationById(conversationList, _cid);
    final keysSignal = ref.watch(
      messageProvider(_cid).select(messageListKeysSignal),
    );
    _followTimelineTailIfNeeded(keysSignal);
    final me = ref.watch(currentUserProvider)?.userId ?? '';
    final typingCount = ref.watch(
      typingProvider(_cid).select(
        (t) => t.typingUserIds
            .where((uid) => uid.trim().isNotEmpty && uid != me)
            .length,
      ),
    );
    final conn = ref.watch(connectionStateProvider);
    final chat = ref.watch(flareMessagesProvider).chat;

    final title = conversation?.displayTitle.trim().isNotEmpty == true
        ? conversation!.displayTitle
        : chat.chatTitle;
    final peerUserId =
        conversation?.conversationType == im.ConversationType.single
        ? (conversation?.peerUserId ?? '').trim()
        : '';
    final peerOnline = peerUserId.isEmpty
        ? null
        : ref.watch(userOnlineProvider(peerUserId));
    if (peerUserId.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_ensurePeerPresence(peerUserId));
      });
    }
    final typingText = typingCount <= 0
        ? ''
        : typingCount == 1
        ? chat.peerTyping
        : chat.typingMany(typingCount);

    final i18n = ref.watch(flareMessagesProvider);
    final canPop = !widget.embedInWorkbench && Navigator.canPop(context);
    final chatCanvas = Theme.of(context).brightness == Brightness.light
        ? FlareImDesign.chatMessageListCanvas
        : kit_theme.FlareColors.of(context).bgSecondary;

    return Scaffold(
      backgroundColor: chatCanvas,
      appBar: ui.FlareConversationHeader(
        identity: ui.FlareConversationIdentity(
          id: _cid,
          title: _multiSelectMode
              ? i18n.chat.multiSelectCountOf(_multiSelectKeys.length)
              : title,
          kind: peerUserId.isEmpty
              ? ui.FlareConversationHeaderKind.group
              : ui.FlareConversationHeaderKind.direct,
          presence: peerOnline == null
              ? null
              : peerOnline
              ? ui.FlarePresence.online
              : ui.FlarePresence.offline,
          subtitle: peerOnline == null
              ? null
              : peerOnline
              ? chat.online
              : chat.offline,
          typingText: typingText,
        ),
        configuration: const ui.FlareConversationHeaderConfiguration(
          replaceDefaults: true,
        ),
        showBack: _multiSelectMode || canPop,
        onBack: () {
          _dismissComposerMoreGrid();
          if (_multiSelectMode) {
            _exitMultiSelect();
          } else {
            _flushComposerDraftNow();
            Navigator.of(context).maybePop();
          }
        },
        actions: _multiSelectMode
            ? [
                ui.FlareConversationHeaderAction(
                  id: 'forward',
                  label: chat.forwardSingle,
                  icon: 'share',
                  enabled: _multiSelectKeys.isNotEmpty,
                ),
                ui.FlareConversationHeaderAction(
                  id: 'merge',
                  label: chat.forwardMerged,
                  icon: 'copy',
                  enabled: _multiSelectKeys.length >= 2,
                ),
                ui.FlareConversationHeaderAction(
                  id: 'delete',
                  label: chat.deleteSelfShort,
                  icon: 'trash',
                  enabled: _multiSelectKeys.isNotEmpty,
                ),
              ]
            : [
                ui.FlareConversationHeaderAction(
                  id: 'search',
                  label: i18n.chat.searchMessages,
                  icon: 'search',
                ),
                ui.FlareConversationHeaderAction(
                  id: 'sdk',
                  label: chat.sdkMessageType,
                  icon: 'code',
                  placement: ui.FlareConversationHeaderActionPlacement.add,
                ),
                ui.FlareConversationHeaderAction(
                  id: 'details',
                  label: i18n.chat.conversationDetails,
                  icon: 'info',
                  placement: ui.FlareConversationHeaderActionPlacement.overflow,
                ),
                ui.FlareConversationHeaderAction(
                  id: 'sync_meta',
                  label: i18n.chat.syncConversation,
                  icon: 'refresh',
                  placement: ui.FlareConversationHeaderActionPlacement.overflow,
                ),
                ui.FlareConversationHeaderAction(
                  id: 'pull_server',
                  label: i18n.chat.pullFromServer,
                  icon: 'download',
                  placement: ui.FlareConversationHeaderActionPlacement.overflow,
                ),
                ui.FlareConversationHeaderAction(
                  id: 'recall_last',
                  label: chat.recallLatestSelf,
                  icon: 'undo',
                  placement: ui.FlareConversationHeaderActionPlacement.overflow,
                ),
              ],
        onAction: (action) async {
          _dismissComposerMoreGrid();
          switch (action.id) {
            case 'forward':
              await _forwardSelected(merge: false);
            case 'merge':
              await _forwardSelected(merge: true);
            case 'delete':
              await _deleteSelectedForSelf();
            case 'sdk':
              await _showSdkMessageBuildMenu();
            case 'details':
              await _openConversationDetails();
            case 'search':
              _openMessageSearch();
            case 'sync_meta':
              await _syncConversationMeta();
            case 'pull_server':
              await _onRefresh();
            case 'recall_last':
              final own = ref
                  .read(messageProvider(_cid))
                  .where((m) => m.senderId == me)
                  .firstOrNull;
              if (own != null && own.serverId.isNotEmpty) {
                await outbound.chatRecall(_cid, own.serverId);
              }
          }
        },
      ),
      body: Column(
        children: [
          // 与 Tauri Chat 状态条一致：仅在非稳定已连接时展示（Ready 时不占位）
          if (conn != im.ConnectionState.connected)
            Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => _dismissComposerMoreGrid(),
              child: _connectionStatusBanner(conn),
            ),
          Expanded(
            child: Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => _dismissComposerMoreGrid(),
              child: ColoredBox(
                color: chatCanvas,
                child: RefreshIndicator(
                  onRefresh: _onRefresh,
                  // 容器收敛到 kit host-rows sliver 变体：kit 统一空态/加载 + 内边距
                  // sliver 外壳，host 仍持 CustomScrollView/滚动控制器（尾随+翻旧）
                  // 与每行 ChatMessageListItem（多选/引用/编辑等附能）。
                  child: CustomScrollView(
                    controller: _scrollController,
                    physics: const AlwaysScrollableScrollPhysics(),
                    slivers: [
                      FlareMessageSliverList(
                        keys: keysSignal.orderedKeys,
                        padding: const EdgeInsets.fromLTRB(
                          FlareImDesign.messageBubbleListHorizontalPad,
                          8,
                          FlareImDesign.messageBubbleListHorizontalPad,
                          20,
                        ),
                        emptyPlaceholder: FlareEmptyState(
                          icon: 'chats',
                          title: chat.noMessages,
                          description: chat.pullToSync,
                        ),
                        rowBuilder: (context, key) => ChatMessageListItem(
                          key: ValueKey<String>(key),
                          conversationId: _cid,
                          messageKey: key,
                          currentUserId: me,
                          onEditOwnText: _editOwnMessage,
                          onStartReply: _startReplyToMessageKey,
                          multiSelectMode: _multiSelectMode,
                          multiSelectSelected: _multiSelectKeys.contains(key),
                          onToggleMultiSelect: () => _toggleMultiSelectKey(key),
                          onStartMultiSelect: _startMultiSelectWith,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          KeyedSubtree(
            key: ValueKey(_cid),
            child: MessageComposer(
              key: _composerKey,
              conversationId: _cid,
              onVoiceSend: (path, durationMs) async {
                final target = _cid;
                await ref
                    .read(messageProvider(target).notifier)
                    .sendAudioByPath(path);
                return true;
              },
              composeTargetName:
                  conversation?.displayTitle.trim().isNotEmpty == true
                  ? conversation!.displayTitle.trim()
                  : null,
              initialText: conversation?.draft,
              replyQuote: _replyQuoteSnapshot,
              onClearReply: _replyQuoteSnapshot != null
                  ? _clearReplyTarget
                  : null,
              onTypingChanged: (v) {
                outbound.chatSetTyping(_cid, v);
              },
              onDraftChanged: (t) {
                unawaited(
                  outbound.chatSaveDraft(_cid, t.trim().isEmpty ? null : t),
                );
              },
              onPickMedia: (kind) {
                unawaited(_handlePickMedia(kind));
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _connectionStatusBanner(im.ConnectionState conn) {
    final i18n = ref.read(flareMessagesProvider).chat;
    final ok = conn == im.ConnectionState.connected;
    final reconnecting = conn == im.ConnectionState.reconnecting;
    final connecting = conn == im.ConnectionState.connecting;
    final fg = ok
        ? kit_theme.FlareColors.of(context).primary
        : kit_theme.FlareColors.of(context).textSecondary;
    final String text;
    if (ok) {
      text = i18n.connectionStable;
    } else if (reconnecting) {
      text =
          '${ref.read(flareMessagesProvider).connection.reconnecting} · ${i18n.connectionSendingHint}';
    } else if (connecting) {
      text = '${i18n.connectionConnecting} · ${i18n.connectionSendingHint}';
    } else {
      text = '${i18n.connectionDisconnected} · ${i18n.connectionSendingHint}';
    }
    return Material(
      color: kit_theme.FlareColors.of(context).bgSelected,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (reconnecting || connecting) ...[
              SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2, color: fg),
              ),
              const SizedBox(width: 8),
            ],
            Flexible(
              child: Text(
                text,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: kit_sizes.FlareSizes.fontSizeSm,
                  fontWeight: FontWeight.w500,
                  color: fg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
