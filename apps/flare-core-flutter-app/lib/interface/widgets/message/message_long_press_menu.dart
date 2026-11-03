import 'package:flare_im/domain/entities/message.dart';
import 'package:flare_im/domain/value_objects/message_content.dart';
import 'package:flare_im/shared/i18n/flare_messages.dart';
import 'package:flare_im_ui/flare_im_ui.dart' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

String? messageCopyPlainText(Message message) {
  if (message.isRecalled) return null;
  final content = message.content;
  if (content is TextContent) {
    return content.text.trim().isEmpty ? null : content.text;
  }
  return content.previewText.trim().isEmpty ? null : content.previewText;
}

bool messagePinnedFromExtra(Message message) {
  final value = message.extra['pinned']?.trim().toLowerCase();
  return value == 'true' || value == '1' || value == 'yes';
}

Future<void> showDeleteMessageChoiceDialog(
  BuildContext context, {
  Future<void> Function()? onDeleteForSelf,
  Future<void> Function()? onDeleteForEveryone,
  required bool showDeleteForEveryone,
  required FlareChatCopy i18n,
}) async {
  final canDeleteForEveryone =
      showDeleteForEveryone && onDeleteForEveryone != null;
  if (onDeleteForSelf == null && !canDeleteForEveryone) return;
  // 组件库的居中模态框(FlareModal):选项是正文,取消在它的底部按钮行。
  await ui.FlareModal.show<void>(
    context,
    builder: (dialogContext) => ui.FlareModal(
      title: i18n.menuDeleteMessage,
      footer: [
        ui.FlareButton(
          label: i18n.cancel,
          variant: ui.FlareButtonVariant.secondary,
          onPressed: () => Navigator.of(dialogContext).pop(),
        ),
      ],
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (onDeleteForSelf != null)
            ListTile(
              leading: const Icon(Icons.visibility_off_outlined),
              title: Text(i18n.menuDeleteSelf),
              subtitle: Text(i18n.menuDeleteSelfHint),
              onTap: () async {
                Navigator.of(dialogContext).pop();
                await onDeleteForSelf();
              },
            ),
          if (canDeleteForEveryone)
            ListTile(
              leading: const Icon(Icons.delete_forever_outlined),
              title: Text(i18n.menuDeleteForAll),
              subtitle: Text(i18n.menuDeleteForAllHint),
              onTap: () async {
                Navigator.of(dialogContext).pop();
                await onDeleteForEveryone();
              },
            ),
        ],
      ),
    ),
  );
}

Future<void> showMessageLongPressMenu(
  BuildContext context, {
  void Function(String emoji)? onPickReaction,
  VoidCallback? onReply,
  VoidCallback? onForward,
  VoidCallback? onRecall,
  VoidCallback? onMultiSelect,
  VoidCallback? onMark,
  VoidCallback? onPinToggle,
  VoidCallback? onPinForSelf,
  required String pinLabel,
  VoidCallback? onCopy,
  VoidCallback? onSave,
  VoidCallback? onEdit,
  Future<void> Function()? onDeleteForSelf,
  Future<void> Function()? onDeleteForEveryone,
  bool showDeleteForEveryoneOption = false,
  required FlareChatCopy i18n,
}) async {
  final entries = <ui.FlareMessageMenuEntry>[
    if (onReply != null)
      ui.FlareMessageMenuEntry(
        id: 'reply',
        label: i18n.menuReply,
        icon: 'reply',
        group: ui.FlareMessageMenuGroup.primary,
      ),
    if (onForward != null)
      ui.FlareMessageMenuEntry(
        id: 'forward',
        label: i18n.menuForward,
        icon: 'forward',
        group: ui.FlareMessageMenuGroup.primary,
      ),
    if (onRecall != null)
      ui.FlareMessageMenuEntry(
        id: 'recall',
        label: i18n.menuRecall,
        icon: 'recall',
        group: ui.FlareMessageMenuGroup.primary,
      ),
    if (onMultiSelect != null)
      ui.FlareMessageMenuEntry(
        id: 'multiSelect',
        label: i18n.menuMultiSelect,
        icon: 'multi-select',
      ),
    if (onMark != null)
      ui.FlareMessageMenuEntry(id: 'mark', label: i18n.menuMark, icon: 'mark'),
    if (onPinToggle != null)
      ui.FlareMessageMenuEntry(id: 'pin', label: pinLabel, icon: 'pin'),
    if (onPinForSelf != null)
      ui.FlareMessageMenuEntry(
        id: 'pinForSelf',
        label: i18n.menuPinSelf,
        icon: 'pin-self',
      ),
    if (onCopy != null)
      ui.FlareMessageMenuEntry(id: 'copy', label: i18n.menuCopy, icon: 'copy'),
    // 图片、视频、文件存进「下载位置」；与组件库标准动作同 id、同图标、同位置（复制之后）。
    if (onSave != null)
      ui.FlareMessageMenuEntry(
        id: 'save',
        label: i18n.menuSave,
        icon: 'download',
      ),
    if (onEdit != null)
      ui.FlareMessageMenuEntry(id: 'edit', label: i18n.menuEdit, icon: 'edit'),
    if (onDeleteForSelf != null ||
        (showDeleteForEveryoneOption && onDeleteForEveryone != null))
      ui.FlareMessageMenuEntry(
        id: 'delete',
        label: i18n.menuDelete,
        icon: 'delete',
        group: ui.FlareMessageMenuGroup.destructive,
      ),
  ];
  if (entries.isEmpty && onPickReaction == null) {
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(i18n.menuNoActions)));
    return;
  }

  final result = await ui.FlareMessageActionSheet.show(
    context,
    actions: entries,
    reactions: onPickReaction == null
        ? const []
        : const ['👍', '❤️', '😂', '🎉', '😮', '😢'],
    emptyText: i18n.menuNoActions,
  );
  if (!context.mounted || result == null) return;
  if (result.reaction case final reaction?) {
    onPickReaction?.call(reaction);
    return;
  }
  switch (result.actionId) {
    case 'reply':
      onReply?.call();
    case 'forward':
      onForward?.call();
    case 'recall':
      onRecall?.call();
    case 'multiSelect':
      onMultiSelect?.call();
    case 'mark':
      onMark?.call();
    case 'pin':
      onPinToggle?.call();
    case 'pinForSelf':
      onPinForSelf?.call();
    case 'copy':
      onCopy?.call();
    case 'save':
      onSave?.call();
    case 'edit':
      onEdit?.call();
    case 'delete':
      await showDeleteMessageChoiceDialog(
        context,
        onDeleteForSelf: onDeleteForSelf,
        onDeleteForEveryone: onDeleteForEveryone,
        showDeleteForEveryone: showDeleteForEveryoneOption,
        i18n: i18n,
      );
  }
}

void copyMessageToClipboard(
  BuildContext context,
  Message message,
  FlareChatCopy i18n,
) {
  final text = messageCopyPlainText(message);
  if (text == null || text.trim().isEmpty) {
    ScaffoldMessenger.maybeOf(
      context,
    )?.showSnackBar(SnackBar(content: Text(i18n.menuNothingToCopy)));
    return;
  }
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.maybeOf(
    context,
  )?.showSnackBar(SnackBar(content: Text(i18n.copied)));
}
