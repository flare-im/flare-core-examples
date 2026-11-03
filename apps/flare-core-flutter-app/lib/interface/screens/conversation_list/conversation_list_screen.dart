import 'dart:async';

import 'package:flare_im/application/outbound/im_outbound_facade.dart';
import 'package:flare_im/application/providers/auth_state_provider.dart';
import 'package:flare_im/application/providers/conversation_state_provider.dart';
import 'package:flare_im/application/providers/im_outbound_provider.dart';
import 'package:flare_im/application/providers/locale_provider.dart';
import 'package:flare_im/application/providers/sdk_runtime_status_provider.dart';
import 'package:flare_im/domain/entities/conversation.dart';
import 'package:flare_im/domain/entities/user.dart';
import 'package:flare_im/domain/value_objects/conversation_type.dart';
import 'package:flare_im/interface/theme/flare_im_design.dart';
import 'package:flare_im/interface/widgets/conversation_filter_bar.dart';
import 'package:flare_im/interface/widgets/conversation_item/conversation_item.dart';
import 'package:flare_im/interface/widgets/unread_badge.dart';
import 'package:flare_im/shared/i18n/flare_locale.dart';
import 'package:flare_im/shared/i18n/flare_messages.dart';
import 'package:flare_im/shared/layout/workbench_layout.dart';
// Design-source app: delegate only genuine 1:1 presentational primitives to the
// kit. Here the account presence dot maps exactly onto FlarePresenceDot.
import 'package:flare_im_ui/flare_im_ui.dart'
    show
        FlareConversationSliverList,
        FlareEmptyState,
        FlareFormField,
        FlareIconButton,
        FlareInput,
        FlarePresenceDot,
        FlareSegmentedControl;
import 'package:flare_im_ui/flare_im_ui.dart' as kit_sizes show FlareSizes;
import 'package:flutter/material.dart' hide ConnectionState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// 会话列表（设计稿：白底、大标题、右上搜索灰圆 + 紫圆加号、扁平会话行）
class ConversationListScreen extends ConsumerStatefulWidget {
  const ConversationListScreen({super.key, this.embedInWorkbench = false});

  /// 嵌入 [WorkbenchShell] 宽屏左栏时为 true。
  final bool embedInWorkbench;

  @override
  ConsumerState<ConversationListScreen> createState() =>
      _ConversationListScreenState();
}

class _ConversationListScreenState
    extends ConsumerState<ConversationListScreen> {
  late final ImOutboundFacade _imOutbound;
  final _searchController = TextEditingController();
  bool _searchOpen = false;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _imOutbound = ref.read(imOutboundProvider);
    Future.microtask(() {
      if (!mounted) return;
      unawaited(_imOutbound.conversationListReload());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool _matchesConversation(Conversation c, String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return true;
    final last = c.lastMessagePreview ?? '';
    final fields = [
      c.displayTitle,
      c.conversationId,
      c.draft ?? '',
      last,
      c.lastMessage?.senderDisplayName ?? '',
      c.lastMessage?.senderName ?? '',
    ];
    return fields.any((v) => v.toLowerCase().contains(q));
  }

  @override
  Widget build(BuildContext context) {
    final layout = ref.watch(conversationListSliverIdsProvider);
    final conversations = ref.watch(conversationProvider);
    final currentUser = ref.watch(currentUserProvider);
    final connectionState = ref.watch(connectionStateProvider);
    final runtimeStatus = ref.watch(sdkRuntimeStatusProvider);
    final i18n = ref.watch(flareMessagesProvider);
    final query = _searchQuery.trim();
    final visibleIds = query.isEmpty
        ? layout
        : ConversationListSliverIds(
            pinnedIds: conversations
                .where((c) => c.isPinned && _matchesConversation(c, query))
                .map((c) => c.conversationId)
                .toList(),
            restIds: conversations
                .where((c) => !c.isPinned && _matchesConversation(c, query))
                .map((c) => c.conversationId)
                .toList(),
          );
    final visibleConversationIds = [
      ...visibleIds.pinnedIds,
      ...visibleIds.restIds,
    ];

    return Scaffold(
      backgroundColor: FlareImDesign.mobileCanvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 12, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            i18n.conversation.title,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: kit_sizes.FlareSizes.fontSize4xl,
                                  letterSpacing: 0,
                                  color: FlareImDesign.foreground,
                                ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        const UnreadBadge(),
                      ],
                    ),
                  ),
                  FlareIconButton(
                    icon: _searchOpen ? 'close' : 'search',
                    semanticLabel: i18n.search.title,
                    backgroundColor: FlareImDesign.listHeaderIconCircleBg,
                    tintColor: FlareImDesign.mutedForeground,
                    customSize: 44,
                    onPressed: () {
                      setState(() => _searchOpen = !_searchOpen);
                      if (!_searchOpen) {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      }
                    },
                  ),
                  const SizedBox(width: 10),
                  FlareIconButton(
                    icon: 'add',
                    semanticLabel: i18n.conversation.startChat,
                    backgroundColor: FlareImDesign.brandPurple,
                    tintColor: Colors.white,
                    customSize: 48,
                    onPressed: () => _showStartChatDialog(context, ref),
                  ),
                  const SizedBox(width: 10),
                  FlareIconButton(
                    icon: 'more',
                    semanticLabel: i18n.composer.more,
                    backgroundColor: FlareImDesign.listHeaderIconCircleBg,
                    tintColor: FlareImDesign.mutedForeground,
                    customSize: 44,
                    onPressed: () => _showMoreSheet(currentUser),
                  ),
                ],
              ),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              child: _searchOpen
                  ? Padding(
                      key: const ValueKey('conversation-search-open'),
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: TextField(
                        controller: _searchController,
                        autofocus: true,
                        textInputAction: TextInputAction.search,
                        onChanged: (value) =>
                            setState(() => _searchQuery = value),
                        decoration: InputDecoration(
                          hintText: i18n.conversation.searchPlaceholder,
                          prefixIcon: const Icon(
                            Icons.search_rounded,
                            size: 20,
                          ),
                          suffixIcon: _searchQuery.isEmpty
                              ? null
                              : IconButton(
                                  tooltip: i18n.t('conversation.clearSearch'),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() => _searchQuery = '');
                                  },
                                  icon: const Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                  ),
                                ),
                          filled: true,
                          fillColor: FlareImDesign.listHeaderIconCircleBg,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 13,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(18),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            ConversationFilterBar(
              onFilterChanged: (_) =>
                  unawaited(_imOutbound.conversationListReload()),
            ),
            const SizedBox(height: 8),
            _ConnectionStateBanner(state: connectionState, i18n: i18n),
            _RuntimeStatusBanner(status: runtimeStatus),
            const Divider(
              height: 1,
              thickness: 1,
              color: FlareImDesign.mobileDivider,
            ),
            Expanded(
              child: RefreshIndicator(
                color: FlareImDesign.brandPurple,
                onRefresh: () => _imOutbound.conversationListReload(),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    // 容器收敛到 kit 的 sliver 变体：统一空态/加载态 sliver 结构，
                    // 行仍由 app 的 ConversationListSliverItem 按-id 切片订阅构建
                    // （单会话更新只重建该行，性能模型不变）。
                    FlareConversationSliverList(
                      ids: visibleConversationIds,
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      emptyPlaceholder: Padding(
                        padding: const EdgeInsets.all(32),
                        child: _ConversationEmptyState(
                          i18n: i18n,
                          searching: query.isNotEmpty,
                          status: runtimeStatus,
                          onStartChat: () => _showStartChatDialog(context, ref),
                        ),
                      ),
                      rowBuilder: (context, id) =>
                          ConversationListSliverItem(conversationId: id),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showMoreSheet(User? currentUser) async {
    final i18n = ref.read(flareMessagesProvider);
    final flareLocale = ref.read(flareLocaleProvider);
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: FlareImDesign.mobileCanvas,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _AccountSheetHeader(user: currentUser, i18n: i18n),
                const SizedBox(height: 14),
                _MoreActionTile(
                  icon: Icons.home_work_outlined,
                  title: i18n.t('conversation.homeSnapshot'),
                  subtitle: i18n.t('conversation.homeSnapshotDesc'),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    final count = await _imOutbound
                        .conversationBootstrapHomeTimeline();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          i18n
                              .t('conversation.homeSnapshotLoaded')
                              .replaceAll('{count}', '$count'),
                        ),
                      ),
                    );
                  },
                ),
                _MoreActionTile(
                  icon: Icons.playlist_add_check_rounded,
                  title: i18n.t('conversation.batchSync'),
                  subtitle: i18n.t('conversation.batchSyncDesc'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    final ids = ref
                        .read(conversationProvider)
                        .map((c) => c.conversationId)
                        .take(20)
                        .toList(growable: false);
                    unawaited(_showBulkSyncDialog(ids));
                  },
                ),
                _MoreActionTile(
                  icon: Icons.settings_outlined,
                  title: i18n.nav.settings,
                  subtitle: i18n.settings.appearance,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.push('/settings');
                  },
                ),
                _MoreActionTile(
                  icon: Icons.search_rounded,
                  title: i18n.search.title,
                  subtitle: i18n.search.global,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.push('/search');
                  },
                ),
                _MoreActionTile(
                  icon: Icons.language_rounded,
                  title: i18n.conversation.language,
                  subtitle: flareLocale == FlareLocale.zhCn
                      ? i18n.conversation.languageZh
                      : i18n.conversation.languageEn,
                  onTap: () async {
                    final next = flareLocale == FlareLocale.zhCn
                        ? FlareLocale.enUs
                        : FlareLocale.zhCn;
                    await ref
                        .read(flareLocaleProvider.notifier)
                        .setLocale(next);
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                  },
                ),
                _MoreActionTile(
                  icon: Icons.tune_rounded,
                  title: i18n.nav.sdkLab,
                  subtitle: i18n.conversation.sdkLabSubtitle,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    context.push('/sdk-lab');
                  },
                ),
                _MoreActionTile(
                  icon: Icons.person_outline_rounded,
                  title: i18n.t('conversation.profile'),
                  subtitle: i18n.t('conversation.profileDesc'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(i18n.t('conversation.profileTodo')),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                _MoreActionTile(
                  icon: Icons.logout_rounded,
                  title: i18n.t('conversation.logout'),
                  subtitle: i18n.t('conversation.logoutDesc'),
                  danger: true,
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _handleLogout();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _showStartChatDialog(BuildContext context, WidgetRef ref) async {
    final i18n = ref.read(flareMessagesProvider);
    final input = await showDialog<_StartChatDialogResult>(
      context: context,
      builder: (ctx) => const _StartChatDialog(),
    );

    if (input == null || !context.mounted) return;
    final raw = input.raw.trim();
    if (raw.isEmpty) return;

    final im = ref.read(imOutboundProvider);
    final Conversation? conv;
    try {
      if (input.type == ConversationType.single) {
        conv = await im.conversationOpenSingleChat(raw);
      } else {
        final currentUserId = ref.read(currentUserProvider)?.userId ?? '';
        final userIds = _parseIdList(raw, include: currentUserId);
        conv = await im.conversationOpenGroupChat(
          userIds,
          displayName: input.displayName.trim().isEmpty
              ? null
              : input.displayName.trim(),
        );
      }
    } catch (error, stackTrace) {
      debugPrint('conversation open failed: $error\n$stackTrace');
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_conversationOpenFailureText(error))),
      );
      return;
    }

    if (!context.mounted) return;
    if (conv == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(i18n.t('conversation.notFound'))));
      return;
    }
    if (conv.conversationId.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(i18n.t('conversation.emptyCid'))));
      return;
    }
    im.conversationSetSelected(conv);
    navigateToChat(context, conv.conversationId);
  }

  String _conversationOpenFailureText(Object error) {
    final i18n = ref.read(flareMessagesProvider);
    if (error is FormatException && error.message.contains('conversationId')) {
      return i18n.t('conversation.invalidConv');
    }
    return i18n.t('conversation.openFailed');
  }

  Future<void> _showBulkSyncDialog(List<String> initialIds) async {
    final i18n = ref.read(flareMessagesProvider);
    final idsCtrl = TextEditingController(text: initialIds.join('\n'));
    try {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(i18n.t('conversation.batchSync')),
          content: TextField(
            controller: idsCtrl,
            minLines: 6,
            maxLines: 10,
            decoration: InputDecoration(
              labelText: 'conversationId',
              hintText: i18n.t('conversation.batchSyncHint'),
              alignLabelWithHint: true,
              border: const OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(i18n.t('conversation.cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(i18n.t('conversation.refresh')),
            ),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      final ids = _parseIdList(idsCtrl.text);
      if (ids.isEmpty) return;
      for (final id in ids) {
        await _imOutbound.conversationSync(id);
      }
      await _imOutbound.conversationListReload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            i18n
                .t('conversation.synced')
                .replaceAll('{count}', '${ids.length}'),
          ),
        ),
      );
    } finally {
      idsCtrl.dispose();
    }
  }

  Future<void> _handleLogout() async {
    final i18n = ref.read(flareMessagesProvider);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(i18n.t('conversation.logout')),
        content: Text(i18n.t('conversation.logoutConfirm')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(i18n.t('conversation.cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(i18n.t('conversation.confirm')),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await _imOutbound.authLogout();
      if (mounted) {
        context.go('/login');
      }
    }
  }

  List<String> _parseIdList(String raw, {String? include}) {
    final ids = raw
        .split(RegExp(r'[\s,，;；]+'))
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList();
    final extra = include?.trim();
    if (extra != null && extra.isNotEmpty) ids.insert(0, extra);
    return ids.toSet().toList(growable: false);
  }
}

final class _StartChatDialogResult {
  const _StartChatDialogResult({
    required this.type,
    required this.raw,
    required this.displayName,
  });

  final ConversationType type;
  final String raw;
  final String displayName;
}

class _StartChatDialog extends ConsumerStatefulWidget {
  const _StartChatDialog();

  @override
  ConsumerState<_StartChatDialog> createState() => _StartChatDialogState();
}

class _StartChatDialogState extends ConsumerState<_StartChatDialog> {
  final _idCtrl = TextEditingController();
  final _displayNameCtrl = TextEditingController();
  var _type = ConversationType.single;

  @override
  void dispose() {
    _idCtrl.dispose();
    _displayNameCtrl.dispose();
    super.dispose();
  }

  bool get _canSubmit => _idCtrl.text.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    final i18n = ref.watch(flareMessagesProvider);
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: Text(i18n.t('conversation.startTitle')),
      // 用 kit 表单基元（FlareSegmentedControl + FlareFormField/FlareInput）重搭，
      // 与登录页同一套设计；保留「直接输入 userId」范式（示例无通讯录）。
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FlareFormField(
            label: i18n.t('conversation.typeLabel'),
            child: FlareSegmentedControl(
              options: [
                i18n.t('conversation.direct'),
                i18n.t('conversation.group'),
              ],
              selectedIndex: _type == ConversationType.group ? 1 : 0,
              onSelect: (index) => setState(() {
                _type = index == 1
                    ? ConversationType.group
                    : ConversationType.single;
              }),
            ),
          ),
          const SizedBox(height: 14),
          FlareFormField(
            label: _type == ConversationType.single
                ? 'peer userId'
                : i18n.t('conversation.memberIds'),
            child: FlareInput(
              controller: _idCtrl,
              placeholder: _type == ConversationType.single
                  ? i18n.t('conversation.peerHint')
                  : i18n.t('conversation.membersHint'),
              multiline: _type == ConversationType.group,
              autofocus: true,
              onChanged: (_) => setState(() {}),
            ),
          ),
          if (_type == ConversationType.group) ...[
            const SizedBox(height: 12),
            FlareFormField(
              label: i18n.t('conversation.groupName'),
              child: FlareInput(
                controller: _displayNameCtrl,
                placeholder: i18n.t('conversation.groupNameHint'),
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(i18n.t('conversation.cancel')),
        ),
        FilledButton(
          onPressed: _canSubmit
              ? () => Navigator.pop(
                  context,
                  _StartChatDialogResult(
                    type: _type,
                    raw: _idCtrl.text,
                    displayName: _displayNameCtrl.text,
                  ),
                )
              : null,
          child: Text(i18n.t('conversation.open')),
        ),
      ],
    );
  }
}

class _ConnectionStateBanner extends StatelessWidget {
  const _ConnectionStateBanner({required this.state, required this.i18n});

  final ConnectionState state;
  final FlareMessages i18n;

  @override
  Widget build(BuildContext context) {
    if (state == ConnectionState.connected) return const SizedBox.shrink();
    final connecting = state == ConnectionState.connecting;
    final reconnecting = state == ConnectionState.reconnecting;
    final color = reconnecting || connecting
        ? FlareImDesign.brandPurple
        : FlareImDesign.danger;
    final title = reconnecting
        ? i18n.connection.reconnecting
        : connecting
        ? i18n.chat.connectionConnecting
        : i18n.chat.connectionDisconnected;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: Padding(
        key: ValueKey('connection-${state.name}'),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.16)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                if (connecting || reconnecting)
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: color,
                    ),
                  )
                else
                  Icon(Icons.cloud_off_rounded, size: 19, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$title · ${i18n.chat.connectionSendingHint}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: color,
                      fontSize: kit_sizes.FlareSizes.fontSizeSm,
                      height: 1.25,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RuntimeStatusBanner extends StatelessWidget {
  const _RuntimeStatusBanner({required this.status});

  final SdkRuntimeStatus status;

  @override
  Widget build(BuildContext context) {
    if (!status.shouldShowInline) return const SizedBox.shrink();
    final isFailure = status.isFailure;
    final color = isFailure ? FlareImDesign.danger : FlareImDesign.brandPurple;
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 180),
      child: Padding(
        key: ValueKey('${status.phase}-${status.title}-${status.progress}'),
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: color.withValues(alpha: isFailure ? 0.08 : 0.07),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withValues(alpha: 0.16)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (status.isBusy)
                      SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: color,
                        ),
                      )
                    else
                      Icon(
                        isFailure
                            ? Icons.error_outline_rounded
                            : Icons.check_circle_outline_rounded,
                        size: 19,
                        color: color,
                      ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            status.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: color,
                              fontSize: kit_sizes.FlareSizes.fontSizeMd,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            status.detail,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: FlareImDesign.mutedForeground,
                              fontSize: kit_sizes.FlareSizes.fontSizeSm,
                              height: 1.25,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (status.progress != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      minHeight: 3,
                      value: (status.progress!.clamp(0, 100)) / 100,
                      backgroundColor: color.withValues(alpha: 0.10),
                      valueColor: AlwaysStoppedAnimation<Color>(color),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AccountSheetHeader extends StatelessWidget {
  const _AccountSheetHeader({required this.user, required this.i18n});

  final User? user;
  final FlareMessages i18n;

  @override
  Widget build(BuildContext context) {
    final account = (user?.userId.trim().isNotEmpty ?? false)
        ? user!.userId.trim()
        : i18n.t('conversation.notLoggedIn');
    final name = user?.displayName.trim();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: FlareImDesign.mobileDivider),
      ),
      child: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: FlareImDesign.brandPurple.withValues(
                  alpha: 0.12,
                ),
                child: Text(
                  account.substring(0, 1).toUpperCase(),
                  style: const TextStyle(
                    color: FlareImDesign.brandPurple,
                    fontSize: kit_sizes.FlareSizes.fontSize4xl,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const Positioned(
                right: -1,
                bottom: -1,
                child: FlarePresenceDot(
                  color: FlareImDesign.presenceOnline,
                  size: 13,
                  ringColor: Colors.white,
                  ringWidth: 2,
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  i18n.conversation.currentAccount,
                  style: const TextStyle(
                    color: FlareImDesign.mutedForeground,
                    fontSize: kit_sizes.FlareSizes.fontSizeSm,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  account,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: FlareImDesign.foreground,
                    fontSize: kit_sizes.FlareSizes.fontSize2xl,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                if (name != null && name.isNotEmpty && name != account)
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: FlareImDesign.mutedForeground,
                      fontSize: kit_sizes.FlareSizes.fontSizeSm,
                    ),
                  ),
              ],
            ),
          ),
          const Icon(
            Icons.verified_user_outlined,
            size: 22,
            color: FlareImDesign.brandPurple,
          ),
        ],
      ),
    );
  }
}

class _MoreActionTile extends StatelessWidget {
  const _MoreActionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final fg = danger ? FlareImDesign.danger : FlareImDesign.foreground;
    final iconColor = danger ? FlareImDesign.danger : FlareImDesign.brandPurple;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 20, color: iconColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: fg,
                          fontSize: kit_sizes.FlareSizes.fontSizeXl,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: FlareImDesign.mutedForeground,
                          fontSize: kit_sizes.FlareSizes.fontSizeSm,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right_rounded,
                  size: 22,
                  color: danger
                      ? FlareImDesign.danger.withValues(alpha: 0.68)
                      : FlareImDesign.mutedForeground.withValues(alpha: 0.72),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConversationEmptyState extends StatelessWidget {
  const _ConversationEmptyState({
    required this.i18n,
    required this.searching,
    required this.status,
    required this.onStartChat,
  });

  final FlareMessages i18n;
  final bool searching;
  final SdkRuntimeStatus status;
  final VoidCallback onStartChat;

  @override
  Widget build(BuildContext context) {
    // App owns the status-aware mapping (which icon/title/hint/action fits the
    // current runtime state); the visual is the kit's FlareEmptyState so the
    // placeholder stays consistent with every other empty state in the app.
    final preparing = !searching && status.isBusy;
    final failed = !searching && status.isFailure;
    final actionable = !searching && !preparing;
    return FlareEmptyState(
      icon: searching
          ? 'search'
          : failed
          ? 'error'
          : preparing
          ? 'refresh'
          : 'chats',
      title: searching
          ? i18n.conversation.emptySearchTitle
          : failed
          ? status.title
          : preparing
          ? status.title
          : i18n.conversation.emptyTitle,
      description: searching
          ? i18n.conversation.emptySearchHint
          : failed
          ? status.detail
          : preparing
          ? status.detail
          : i18n.conversation.emptyHint,
      actionText: actionable ? i18n.conversation.startChat : null,
      onAction: actionable ? onStartChat : null,
    );
  }
}
