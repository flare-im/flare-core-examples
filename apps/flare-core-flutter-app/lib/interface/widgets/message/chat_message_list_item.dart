import 'dart:async';

import 'package:flare_im/application/providers/im_outbound_provider.dart';
import 'package:flare_im/application/providers/locale_provider.dart';
import 'package:flare_im/application/providers/message_state_provider.dart';
import 'package:flare_im/application/selectors/message_list_view_model.dart';
import 'package:flare_im/domain/entities/message.dart';
import 'package:flare_im/domain/value_objects/message_content.dart';
import 'package:flare_im/interface/widgets/message/message.dart';
import 'package:flare_im/shared/i18n/flare_messages.dart';
import 'package:flare_im_ui/flare_im_ui.dart' show FlareDatePill, FlareSizes;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 在已加载会话消息中查找被引用方展示名（先按 `quotedMessageId` 命中，再按 `quotedSenderId`）。
void _runReaction(
  BuildContext context,
  FlareChatCopy i18n,
  Future<void> Function() fn,
) {
  unawaited(() async {
    try {
      await fn();
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(i18n.reactionFailed(e))));
    }
  }());
}

String? _resolveQuotedSenderFromMessageList(
  List<Message> list,
  QuoteContent quote,
) {
  final qid = quote.quotedMessageId.trim();
  if (qid.isNotEmpty) {
    for (final m in list) {
      if (m.serverId.isEmpty || m.serverId != qid) continue;
      final d = m.senderDisplayName.trim();
      if (d.isNotEmpty) return d;
      final n = m.senderName.trim();
      if (n.isNotEmpty) return n;
      return null;
    }
  }
  final sid = (quote.quotedSenderId ?? '').trim();
  if (sid.isEmpty) return null;
  for (final m in list) {
    if (m.senderId != sid) continue;
    final d = m.senderDisplayName.trim();
    if (d.isNotEmpty) return d;
    final n = m.senderName.trim();
    if (n.isNotEmpty) return n;
  }
  return null;
}

/// 单条聊天行：独立 Widget + [messageProvider] 的 [select]，仅该行数据变化时重建。
class ChatMessageListItem extends ConsumerWidget {
  const ChatMessageListItem({
    super.key,
    required this.conversationId,
    required this.messageKey,
    required this.currentUserId,
    required this.onEditOwnText,
    this.onStartReply,
    this.multiSelectMode = false,
    this.multiSelectSelected = false,
    this.onToggleMultiSelect,
    this.onStartMultiSelect,
  });

  final String conversationId;
  final String messageKey;
  final String currentUserId;
  final Future<void> Function(Message message) onEditOwnText;
  final void Function(String messageKey)? onStartReply;
  final bool multiSelectMode;
  final bool multiSelectSelected;
  final VoidCallback? onToggleMultiSelect;
  final void Function(String messageKey)? onStartMultiSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final vm = ref.watch(
      messageProvider(
        conversationId,
      ).select((list) => messageRowViewModelForKey(list, messageKey)),
    );
    if (vm == null) return const SizedBox.shrink();

    final i18n = ref.watch(flareMessagesProvider).chat;
    final im = ref.read(imOutboundProvider);
    final message = vm.message;
    final me = currentUserId;
    final isSelf = me.isNotEmpty && message.senderId == me;
    final isNotification = message.content is NotificationContent;
    final canReply =
        !isNotification &&
        !message.isRecalled &&
        (message.serverId.trim().isNotEmpty ||
            message.clientMsgId.trim().isNotEmpty);
    final pinned = messagePinnedFromExtra(message);
    final copyable = messageCopyPlainText(message) != null;

    final String? quotedSenderResolved = message.content is QuoteContent
        ? ref.watch(
            messageProvider(conversationId).select(
              (list) => _resolveQuotedSenderFromMessageList(
                list,
                message.content as QuoteContent,
              ),
            ),
          )
        : null;

    final bubble = SdkMessageBubbleAdapter(
      message: message,
      showAvatar: vm.showAvatar,
      currentUserId: me,
      quotedSenderResolvedName: quotedSenderResolved,
      onCopy: copyable
          ? () => copyMessageToClipboard(context, message, i18n)
          : null,
      onReply: canReply && onStartReply != null
          ? () => onStartReply!(messageKey)
          : null,
      onForward: () {
        final id = message.serverId.trim().isNotEmpty
            ? message.serverId.trim()
            : message.clientMsgId.trim();
        if (id.isEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(i18n.forwardWhileSending)));
          return;
        }
        unawaited(() async {
          try {
            await im.chatForwardMessages(
              conversationId,
              messageIds: [id],
              merge: false,
              title: i18n.forwardMessage,
            );
            if (!context.mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(i18n.forwardedToCurrent)));
          } catch (e) {
            if (!context.mounted) return;
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(i18n.forwardFailed(e))));
          }
        }());
      },
      onMultiSelect: onStartMultiSelect != null
          ? () => onStartMultiSelect!(messageKey)
          : null,
      onMark: message.serverId.isNotEmpty
          ? () {
              unawaited(() async {
                try {
                  await im.chatMarkMessageImportant(message.serverId);
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(i18n.markedImportant)));
                } catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text(i18n.markFailed(e))));
                }
              }());
            }
          : null,
      onPinToggle: message.serverId.isNotEmpty
          ? () {
              if (pinned) {
                im.chatUnpinMessage(message.serverId);
              } else {
                im.chatPinMessage(message.serverId);
              }
            }
          : null,
      onPinForSelf: message.serverId.isNotEmpty && !pinned
          ? () => im.chatPinMessageForSelf(message.serverId)
          : null,
      pinToggleLabel: pinned ? i18n.unpin : i18n.pinMessage,
      onResend:
          isSelf &&
              message.isFailed &&
              message.content is TextContent &&
              message.clientMsgId.trim().isNotEmpty
          ? () => im.chatResendFailedText(conversationId, message.clientMsgId)
          : null,
      // 己方消息：第二排固定显示「撤回」；不可撤回时点按提示（与稿式三格一致）。
      onRecall: isSelf
          ? () {
              if (message.isRecalled) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(i18n.recalled)));
                return;
              }
              if (message.serverId.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(i18n.recallWhileSending)),
                );
                return;
              }
              if (!message.canRecall) {
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(SnackBar(content: Text(i18n.recallExpired)));
                return;
              }
              im.chatRecall(conversationId, message.serverId);
            }
          : null,
      onDeleteForEveryone: message.serverId.isNotEmpty
          ? () async =>
                im.chatDeleteByServerId(conversationId, message.serverId)
          : null,
      onDeleteForSelf: message.serverId.isNotEmpty
          ? () async => im.chatDeleteForSelf(conversationId, message.serverId)
          : null,
      showDeleteForEveryoneOption: isSelf && message.serverId.isNotEmpty,
      onEdit:
          isSelf &&
              message.canEdit &&
              (message.content is TextContent ||
                  message.content is RichDocContent)
          ? () => onEditOwnText(message)
          : null,
      onReaction: message.serverId.isNotEmpty && !message.isRecalled
          ? (emoji) => _runReaction(
              context,
              i18n,
              () => im.chatAddReaction(conversationId, message.serverId, emoji),
            )
          : null,
      onRemoveReaction: message.serverId.isNotEmpty && !message.isRecalled
          ? (emoji) => _runReaction(
              context,
              i18n,
              () => im.chatRemoveReaction(
                conversationId,
                message.serverId,
                emoji,
              ),
            )
          : null,
    );

    final column = Column(
      children: [
        if (vm.showTime) _ChatTimeDivider(time: message.timestamp),
        bubble,
      ],
    );

    if (!multiSelectMode) {
      return column;
    }

    return InkWell(
      onTap: onToggleMultiSelect,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 10, right: 4),
            child: Checkbox(
              value: multiSelectSelected,
              onChanged: (_) => onToggleMultiSelect?.call(),
            ),
          ),
          Expanded(child: column),
        ],
      ),
    );
  }
}

class _ChatTimeDivider extends ConsumerWidget {
  const _ChatTimeDivider({required this.time});

  final DateTime time;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i18n = ref.watch(flareMessagesProvider).chat;
    return Padding(
      padding: const EdgeInsets.only(
        top: FlareSizes.spacingMd,
        bottom: FlareSizes.spacingSm,
      ),
      child: FlareDatePill(label: _formatFeishuStyleDividerTime(time, i18n)),
    );
  }

  /// 飞书式：当日仅 `HH:mm`；昨天带「昨天」；同年 `M月d日`；跨年带年份（文案随语言）。
  String _formatFeishuStyleDividerTime(DateTime time, FlareChatCopy i18n) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(time.year, time.month, time.day);
    final yesterday = today.subtract(const Duration(days: 1));
    String two(int n) => n.toString().padLeft(2, '0');
    final hm = '${two(time.hour)}:${two(time.minute)}';
    if (day == today) return hm;
    if (day == yesterday) return i18n.yesterdayAt(hm);
    if (time.year == now.year) {
      return i18n.dateMonthDayAt(time.month, time.day, hm);
    }
    return i18n.dateFullAt(time.year, time.month, time.day, hm);
  }
}
