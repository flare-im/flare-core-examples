import 'dart:async';

import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart' as core
    show ConnectionPhase;
import 'package:flare_im/application/outbound/im_outbound_facade.dart';
import 'package:flare_im/application/providers/auth_state_provider.dart';
import 'package:flare_im/application/providers/conversation_state_provider.dart';
import 'package:flare_im/application/providers/im_outbound_provider.dart';
import 'package:flare_im/application/providers/locale_provider.dart';
import 'package:flare_im/application/providers/message_state_provider.dart';
import 'package:flare_im/domain/entities/conversation.dart';
import 'package:flare_im/domain/value_objects/conversation_type.dart';
import 'package:flare_im/interface/theme/flare_im_design.dart';
import 'package:flare_im/shared/i18n/flare_messages.dart';
import 'package:flare_im/shared/layout/workbench_layout.dart';
import 'package:flare_im_ui/flare_im_ui.dart' as kit_sizes show FlareSizes;
import 'package:flare_im_ui/flare_im_ui.dart' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// 会话详情侧栏（对齐 Vue `ConversationDetails`）。
class ConversationDetailsPanel extends ConsumerWidget {
  const ConversationDetailsPanel({
    super.key,
    required this.conversationId,
    this.onClose,
  });

  final String conversationId;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i18n = ref.watch(flareMessagesProvider).details;
    final connection = ref.watch(connectionStatusProvider)?.phase;
    final chatCopy = ref.watch(flareMessagesProvider).chat;
    // 详情页的一行连接说明（不是横幅）：在线、连接中，或已断开等待核心恢复。
    final connectionLabel = switch (connection) {
      core.ConnectionPhase.online => chatCopy.connectionStable,
      null ||
      core.ConnectionPhase.idle ||
      core.ConnectionPhase.connecting ||
      core.ConnectionPhase.syncing ||
      core.ConnectionPhase.switching ||
      core.ConnectionPhase.reconnecting => chatCopy.connectionConnecting,
      core.ConnectionPhase.waitingForNetwork ||
      core.ConnectionPhase.serviceUnavailable ||
      core.ConnectionPhase.actionRequired => chatCopy.connectionDisconnected,
    };
    final list = ref.watch(conversationProvider);
    final conversation = conversationById(list, conversationId);
    final messages = ref.watch(messageProvider(conversationId.trim()));
    final latestId = messages.isEmpty
        ? ''
        : (messages.last.serverId.isNotEmpty
              ? messages.last.serverId
              : messages.last.clientMsgId);

    if (conversation == null) {
      return _EmptyPane(title: i18n.emptyTitle, hint: i18n.emptyHint);
    }

    final outbound = ref.read(imOutboundProvider);
    final c = conversation;
    final title = c.displayTitle;
    final subtitle = _subtitle(c, i18n);

    return Material(
      color: FlareImDesign.card,
      child: SafeArea(
        left: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            if (onClose != null)
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: onClose,
                ),
              ),
            _Hero(
              title: title,
              subtitle: subtitle,
              avatarKey: c.conversationId,
              connectionLabel: connectionLabel,
              tags: [
                if (c.isPinned) i18n.pinTag,
                if (c.isMuted) i18n.muteTag,
                if (c.isArchived) i18n.archivedTag,
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ActionChip(
                  label: i18n.sync,
                  onPressed: () => unawaited(
                    outbound.chatPullServerAndMarkRead(conversationId),
                  ),
                ),
                _ActionChip(
                  label: i18n.markRead,
                  onPressed: () => unawaited(
                    outbound.chatEnterLoadAndMarkRead(conversationId),
                  ),
                ),
                _ActionChip(
                  label: i18n.markUnread,
                  onPressed: () => unawaited(
                    outbound.conversationMarkUnread(conversationId),
                  ),
                ),
                _ActionChip(
                  label: c.isPinned ? i18n.unpin : i18n.pin,
                  onPressed: () => unawaited(
                    outbound.conversationPin(conversationId, !c.isPinned),
                  ),
                ),
                _ActionChip(
                  label: c.isMuted ? i18n.unmute : i18n.mute,
                  onPressed: () => unawaited(
                    outbound.conversationSetMuted(conversationId, !c.isMuted),
                  ),
                ),
                _ActionChip(
                  label: c.isArchived ? i18n.unarchive : i18n.archive,
                  onPressed: () => unawaited(
                    outbound.conversationSetArchived(
                      conversationId,
                      !c.isArchived,
                    ),
                  ),
                ),
                _ActionChip(
                  label: i18n.clearHistory,
                  onPressed: () => unawaited(
                    _confirmClear(context, ref, outbound, conversationId, i18n),
                  ),
                ),
                _ActionChip(
                  label: i18n.delete,
                  danger: true,
                  onPressed: () => unawaited(
                    _confirmDelete(
                      context,
                      ref,
                      outbound,
                      conversationId,
                      i18n,
                    ),
                  ),
                ),
              ],
            ),
            if (c.isLargeGroup) ...[
              const SizedBox(height: 16),
              _NotifyAllSetting(
                key: ValueKey(c.conversationId),
                conversation: c,
              ),
            ],
            const SizedBox(height: 20),
            Text(
              i18n.statusSection,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: kit_sizes.FlareSizes.fontSizeLg,
              ),
            ),
            const SizedBox(height: 8),
            _InfoRow(label: 'Conversation ID', value: c.conversationId),
            _InfoRow(label: 'Unread', value: '${c.unreadCount}'),
            _InfoRow(label: 'Messages', value: '${messages.length}'),
            _InfoRow(label: 'Latest', value: latestId.isEmpty ? '-' : latestId),
            const SizedBox(height: 16),
            Text(
              i18n.extensions,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: kit_sizes.FlareSizes.fontSizeLg,
              ),
            ),
            const SizedBox(height: 8),
            ListTile(
              dense: true,
              leading: const Icon(Icons.search_rounded),
              title: Text(ref.watch(flareMessagesProvider).search.title),
              onTap: () => navigateToMessageSearch(
                context,
                conversationId: conversationId,
              ),
            ),
            ListTile(
              dense: true,
              leading: const Icon(Icons.tune_rounded),
              title: Text(i18n.openSdkLab),
              onTap: () => context.push('/sdk-lab'),
            ),
          ],
        ),
      ),
    );
  }

  String _subtitle(Conversation c, FlareDetailsCopy i18n) {
    if (c.conversationType == ConversationType.group) {
      return i18n.membersCount(c.membersCount);
    }
    final peer = c.peerUserId?.trim() ?? '';
    return peer.isNotEmpty ? peer : c.conversationId;
  }

  Future<void> _confirmClear(
    BuildContext context,
    WidgetRef ref,
    ImOutboundFacade outbound,
    String cid,
    FlareDetailsCopy i18n,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(i18n.clearHistory),
        content: const Text('仅清空本机聊天记录，不影响服务端。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ref.read(flareMessagesProvider).login.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(i18n.clearHistory),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await outbound.conversationClearLocalHistory(cid);
    ref.read(messageProvider(cid).notifier).load();
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    ImOutboundFacade outbound,
    String cid,
    FlareDetailsCopy i18n,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(i18n.delete),
        content: const Text('删除后将从列表移除该会话。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(ref.read(flareMessagesProvider).login.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: FlareImDesign.destructive,
            ),
            child: Text(i18n.delete),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    await outbound.conversationDelete(cid);
    if (context.mounted) {
      if (isWorkbenchWide(context)) {
        context.go('/conversations');
      } else {
        context.pop();
      }
    }
  }
}

/// 超过 1000 人的群默认只在 @我 时提醒：「接收全部消息通知」打开后每条新消息都提醒。开关先动，核心没写成时回到
/// 核心的值并提示。
class _NotifyAllSetting extends ConsumerStatefulWidget {
  const _NotifyAllSetting({super.key, required this.conversation});

  final Conversation conversation;

  @override
  ConsumerState<_NotifyAllSetting> createState() => _NotifyAllSettingState();
}

class _NotifyAllSettingState extends ConsumerState<_NotifyAllSetting> {
  static const _row = 'notifyAll';

  /// 正在送去核心的选择，核心答复前开关显示它。
  bool? _pending;

  /// 每拨一次加一：只有最近一次的答复收起它的选择。
  int _flips = 0;

  Future<void> _toggle(bool on) async {
    final flip = ++_flips;
    final copy = ref.read(flareMessagesProvider).details;
    setState(() => _pending = on);
    try {
      await ref
          .read(imOutboundProvider)
          .conversationSetNotifyAll(widget.conversation.conversationId, on);
    } catch (_) {
      if (mounted) {
        ui.FlareToast.show(
          context,
          message: copy.notifyAllFailed,
          variant: ui.FlareToastVariant.error,
        );
      }
    } finally {
      // A newer flip of the same switch keeps showing until its own answer.
      if (mounted && flip == _flips) setState(() => _pending = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final copy = ref.watch(flareMessagesProvider).details;
    final enabled = _pending ?? widget.conversation.notifyAll;
    return ui.FlareSettingsList(
      shrinkWrap: true,
      sections: [
        ui.FlareSettingsSection(
          items: [
            ui.FlareSettingsItem(
              key: _row,
              label: copy.notifyAll,
              kind: ui.FlareSettingKind.toggle,
              value: enabled,
            ),
          ],
          footer: copy.notifyAllHint,
        ),
      ],
      onToggle: (item, on) {
        if (item.key == _row) unawaited(_toggle(on));
      },
    );
  }
}

class _EmptyPane extends StatelessWidget {
  const _EmptyPane({required this.title, required this.hint});
  final String title;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: kit_sizes.FlareSizes.fontSize3xl,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              hint,
              textAlign: TextAlign.center,
              style: const TextStyle(color: FlareImDesign.mutedForeground),
            ),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.title,
    required this.subtitle,
    required this.avatarKey,
    required this.connectionLabel,
    required this.tags,
  });

  final String title;
  final String subtitle;
  final String avatarKey;
  final String connectionLabel;
  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ui.FlareAvatar(userId: avatarKey, displayName: title),
        const SizedBox(height: 12),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: kit_sizes.FlareSizes.fontSize3xl,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: const TextStyle(
            color: FlareImDesign.mutedForeground,
            fontSize: kit_sizes.FlareSizes.fontSizeMd,
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          alignment: WrapAlignment.center,
          children: [
            _TagChip(label: connectionLabel),
            for (final t in tags) _TagChip(label: t),
          ],
        ),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  const _TagChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: FlareImDesign.listHeaderIconCircleBg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: kit_sizes.FlareSizes.fontSizeSm,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.onPressed,
    this.danger = false,
  });

  final String label;
  final VoidCallback onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      label: Text(label),
      onPressed: onPressed,
      backgroundColor: danger
          ? FlareImDesign.destructive.withValues(alpha: 0.08)
          : FlareImDesign.listHeaderIconCircleBg,
      labelStyle: TextStyle(
        color: danger ? FlareImDesign.destructive : FlareImDesign.foreground,
        fontWeight: FontWeight.w600,
        fontSize: kit_sizes.FlareSizes.fontSizeMd,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: kit_sizes.FlareSizes.fontSizeSm,
                color: FlareImDesign.mutedForeground,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: kit_sizes.FlareSizes.fontSizeSm,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
