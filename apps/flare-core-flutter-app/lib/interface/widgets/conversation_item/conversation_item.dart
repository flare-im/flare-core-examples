import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flare_im/application/providers/auth_state_provider.dart';
import 'package:flare_im/application/providers/conversation_state_provider.dart';
import 'package:flare_im/application/providers/im_outbound_provider.dart';
import 'package:flare_im/application/providers/locale_provider.dart';
import 'package:flare_im/domain/entities/conversation.dart';
import 'package:flare_im/domain/value_objects/conversation_type.dart';
import 'package:flare_im/domain/value_objects/message_content.dart';
import 'package:flare_im/infrastructure/mappers/storage_preview_format.dart';
import 'package:flare_im/infrastructure/media/composer_static_asset_image.dart';
import 'package:flare_im/infrastructure/media/emoji_pack_i18n.dart';
import 'package:flare_im/infrastructure/media/network_image_policy.dart';
import 'package:flare_im/infrastructure/media/pack_asset_resolver.dart';
import 'package:flare_im/interface/theme/flare_im_design.dart';
import 'package:flare_im/interface/widgets/message/plain_text_emoji_rich.dart';
import 'package:flare_im/shared/i18n/flare_messages.dart';
import 'package:flare_im/shared/layout/workbench_layout.dart';
import 'package:flare_im_ui/flare_im_ui.dart' as kit_theme show FlareColors;
import 'package:flare_im_ui/flare_im_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 会话列表项（设计稿：圆形头像 + 首字母淡色底、标题/时间、摘要 + 紫未读角标）
class ConversationItem extends ConsumerWidget {
  final Conversation conversation;

  const ConversationItem({super.key, required this.conversation});

  String _lineTitle(Conversation c, [FlareMessages? m]) {
    final t = c.displayTitle.trim();
    if (t.isNotEmpty) return t;
    final id = c.conversationId.trim();
    if (id.isEmpty) return m?.t('conversation.untitled') ?? '会话';
    return id.length > 18 ? '${id.substring(0, 14)}…' : id;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messages = ref.watch(flareMessagesProvider);
    final titleText = _lineTitle(conversation, messages);
    final selected = ref.watch(
      selectedConversationProvider.select(
        (value) => value?.conversationId == conversation.conversationId,
      ),
    );
    void openConversation() {
      unawaited(_openConversation(context, ref));
    }

    // 通用外壳（头像 / 标题 / 时间 / 未读 / 静音图标 / 置顶点）交给 kit 的
    // FlareConversationRow（四端一致）；app 只注入媒体资源预览，kit 管理状态前缀。
    final data = ConversationRowData(
      id: conversation.conversationId,
      title: titleText,
      avatarUrl: isHttpOrHttpsUrl(conversation.avatarUrl)
          ? conversation.avatarUrl
          : null,
      timestampLabel: _formatTime(conversation.updatedAt, messages),
      unreadCount: conversation.unreadCount,
      pinned: conversation.isPinned,
      muted: conversation.isMuted,
      mentioned: conversation.isMentioned,
      draftPreview: conversation.draft,
      preview: formatStoragePreview(
        conversation.lastMessagePreview ?? '',
        locale: messages.locale.code,
      ),
    );

    return FlareConversationRow(
      item: data,
      draftLabel: messages.conversation.draftPrefix,
      mentionLabel: messages.t('conversation.mentionPrefix'),
      active: selected,
      onSelect: openConversation,
      onLongPress: () => _showConversationMenu(context, ref),
      swipeActions: [
        FlareConversationSwipeAction(
          conversation.isPinned
              ? FlareConversationAction.unpin
              : FlareConversationAction.pin,
          messages.t(
            conversation.isPinned ? 'conversation.unpin' : 'conversation.pin',
          ),
        ),
        FlareConversationSwipeAction(
          FlareConversationAction.delete,
          messages.t('conversation.delete'),
        ),
      ],
      onAction: (action) {
        final outbound = ref.read(imOutboundProvider);
        if (action == FlareConversationAction.delete) {
          unawaited(_confirmDelete(context, ref));
        } else if (action == FlareConversationAction.pin ||
            action == FlareConversationAction.unpin) {
          unawaited(
            outbound.conversationPin(
              conversation.conversationId,
              action == FlareConversationAction.pin,
            ),
          );
        }
      },
      previewSpansBuilder: (rowContext, base) =>
          _previewSpans(rowContext, base, messages),
    );
  }

  /// 组装最后一条消息预览的富文本 span：草稿 / @我 前缀 + 群昵称前缀 +
  /// 表情/贴纸内联缩略图，供 kit [FlareConversationRow.previewSpansBuilder] 渲染。
  List<InlineSpan> _previewSpans(
    BuildContext context,
    TextStyle base,
    FlareMessages messages,
  ) {
    return _mediaPreviewSpans(context, base, messages) ??
        _previewSpanChildren(context, base, messages);
  }

  List<InlineSpan> _previewSpanChildren(
    BuildContext context,
    TextStyle baseStyle,
    FlareMessages messages,
  ) {
    final c = conversation;
    final raw = c.lastMessagePreview ?? '';
    final t = formatStoragePreview(raw, locale: messages.locale.code).trim();
    if (t.isNotEmpty && t != ' ') {
      if (c.conversationType == ConversationType.group &&
          c.lastMessage != null) {
        final nick = c.lastMessage!.senderDisplayName.trim().isNotEmpty
            ? c.lastMessage!.senderDisplayName.trim()
            : c.lastMessage!.senderName.trim();
        if (nick.isNotEmpty) {
          return [
            TextSpan(text: '$nick: ', style: baseStyle),
            ...plainTextEmojiInlineSpans(
              context,
              text: t,
              style: baseStyle,
              secondaryForeground: kit_theme.FlareColors.of(
                context,
              ).textSecondary,
              inlineEmojiEm: 1.72,
              localeTag: messages.locale.code,
            ),
          ];
        }
      }
      return plainTextEmojiInlineSpans(
        context,
        text: t,
        style: baseStyle,
        secondaryForeground: kit_theme.FlareColors.of(context).textSecondary,
        inlineEmojiEm: 1.72,
        localeTag: messages.locale.code,
      );
    }
    return [
      TextSpan(text: messages.conversation.noMessagePreview, style: baseStyle),
    ];
  }

  /// 纯表情 / 贴纸消息：内联缩略图 + 文案标签（作为 [WidgetSpan] 融入单行富预览）。
  /// 非该类消息返回 `null`，回退到文本 span。
  List<InlineSpan>? _mediaPreviewSpans(
    BuildContext context,
    TextStyle base,
    FlareMessages messages,
  ) {
    final content = conversation.lastMessage?.content;
    final rawPreview = conversation.lastMessagePreview ?? '';
    final stickerContent = content is StickerContent ? content : null;
    final emojiKey = content is EmojiContent
        ? content.emoji.trim()
        : storagePreviewEmojiKey(rawPreview);
    final isSticker =
        stickerContent != null || storagePreviewIsSticker(rawPreview);

    if (!isSticker && (emojiKey == null || emojiKey.isEmpty)) return null;

    final prefix = _groupPreviewPrefix();
    final label = isSticker
        ? messages.conversation.previewSticker
        : EmojiPackI18n.packLabel(emojiKey!, locale: messages.locale.code);
    final thumb = isSticker
        ? _stickerPreviewThumb(stickerContent, messages)
        : _emojiPreviewThumb(emojiKey!, messages);

    return [
      if (prefix.isNotEmpty) TextSpan(text: prefix, style: base),
      WidgetSpan(alignment: PlaceholderAlignment.middle, child: thumb),
      const WidgetSpan(child: SizedBox(width: 5)),
      TextSpan(text: label, style: base),
    ];
  }

  String _groupPreviewPrefix() {
    if (conversation.conversationType != ConversationType.group ||
        conversation.lastMessage == null) {
      return '';
    }
    final nick = conversation.lastMessage!.senderDisplayName.trim().isNotEmpty
        ? conversation.lastMessage!.senderDisplayName.trim()
        : conversation.lastMessage!.senderName.trim();
    return nick.isEmpty ? '' : '$nick: ';
  }

  Widget _emojiPreviewThumb(String key, FlareMessages messages) {
    return ComposerStaticAssetImage(
      assetPath: PackAssetResolver.emojiPackAssetPath(key),
      width: 20,
      height: 20,
      fit: BoxFit.contain,
      decodeSize: 64,
      error: _previewFallbackIcon(Icons.emoji_emotions_outlined),
    );
  }

  Widget _stickerPreviewThumb(StickerContent? content, FlareMessages messages) {
    final assetPath = content == null
        ? null
        : PackAssetResolver.stickerAssetPath(
            stickerId: content.stickerId,
            packageId: content.packageId,
          );
    if (assetPath != null) {
      return ComposerStaticAssetImage(
        assetPath: assetPath,
        width: 22,
        height: 22,
        fit: BoxFit.contain,
        decodeSize: 72,
        error: _previewFallbackIcon(Icons.sticky_note_2_outlined),
      );
    }
    final url = content?.url?.trim() ?? '';
    if (isHttpOrHttpsUrl(url)) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(5),
        child: CachedNetworkImage(
          imageUrl: url,
          width: 22,
          height: 22,
          fit: BoxFit.cover,
          errorWidget: (context, url, error) =>
              _previewFallbackIcon(Icons.sticky_note_2_outlined),
        ),
      );
    }
    return _previewFallbackIcon(Icons.sticky_note_2_outlined);
  }

  Widget _previewFallbackIcon(IconData icon) {
    return Container(
      width: 20,
      height: 20,
      decoration: BoxDecoration(
        color: FlareImDesign.brandPurple.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: FlareImDesign.brandPurple.withValues(alpha: 0.22),
        ),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: 13, color: FlareImDesign.brandPurple),
    );
  }

  Future<void> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final messages = ref.read(flareMessagesProvider);
    // 组件库的危险确认呈现器:手机上是底部面板,宽屏交给居中模态框。
    final confirmed = await FlareDangerConfirm.show(
      context,
      title: messages.t('conversation.deleteConv'),
      description: messages.t('conversation.deleteConfirm'),
      target: _lineTitle(conversation, messages),
      confirmText: messages.t('conversation.confirm'),
      cancelText: messages.t('conversation.cancel'),
    );
    if (confirmed && context.mounted) {
      await ref
          .read(imOutboundProvider)
          .conversationDelete(conversation.conversationId);
    }
  }

  void _showConversationMenu(BuildContext context, WidgetRef ref) {
    final messages = ref.read(flareMessagesProvider);
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FlareConversationActionSheet(
                conversation: FlareConversationActionSnapshot(
                  id: conversation.conversationId,
                  title: _lineTitle(conversation, messages),
                  pinned: conversation.isPinned,
                ),
                capabilities: const FlareConversationActionCapabilities(
                  pin: true,
                  delete: true,
                ),
                pinText: messages.t('conversation.pin'),
                unpinText: messages.t('conversation.unpin'),
                deleteText: messages.t('conversation.deleteConv'),
                onAction: (_, action) {
                  Navigator.pop(sheetContext);
                  if (action == FlareConversationAction.delete) {
                    unawaited(_confirmDelete(context, ref));
                  } else {
                    unawaited(
                      ref
                          .read(imOutboundProvider)
                          .conversationPin(
                            conversation.conversationId,
                            action == FlareConversationAction.pin,
                          ),
                    );
                  }
                },
              ),
              FlareSettingsRow(
                item: FlareSettingsItem(
                  key: 'sync',
                  label: messages.t('conversation.syncThis'),
                  icon: 'refresh',
                  kind: FlareSettingKind.value,
                ),
                onSelect: (_) async {
                  Navigator.pop(sheetContext);
                  await ref
                      .read(imOutboundProvider)
                      .conversationSync(conversation.conversationId);
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(messages.t('conversation.syncedThis')),
                      ),
                    );
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatTime(DateTime time, FlareMessages m) {
    final now = DateTime.now();
    final diff = now.difference(time);

    if (diff.inDays == 0) {
      return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return m.t('conversation.yesterday');
    } else if (diff.inDays < 7) {
      final weekdays = m.t('conversation.weekdays').split(',');
      return weekdays[time.weekday - 1];
    } else {
      return '${time.month}/${time.day}';
    }
  }

  Future<void> _openConversation(BuildContext context, WidgetRef ref) async {
    final im = ref.read(imOutboundProvider);
    var target = conversation;

    if (conversation.conversationType == ConversationType.group) {
      final memberIds = _memberIdsForCanonicalGroupOpen(ref, conversation);
      if (memberIds.length >= 2) {
        try {
          final resolved = await im.conversationOpenGroupChat(
            memberIds,
            displayName: conversation.displayTitle,
          );
          final resolvedId = resolved?.conversationId.trim() ?? '';
          if (resolved != null && resolvedId.isNotEmpty) {
            target = resolved;
          }
        } catch (error, stackTrace) {
          debugPrint(
            'canonical group resolve failed '
            'conversation=${conversation.conversationId}: $error\n$stackTrace',
          );
        }
      }
    }

    if (!context.mounted) return;
    im.conversationSetSelected(target);
    navigateToChat(context, target.conversationId);
  }

  List<String> _memberIdsForCanonicalGroupOpen(
    WidgetRef ref,
    Conversation conversation,
  ) {
    final ids = <String>{
      for (final id in conversation.memberUserIds)
        if (id.trim().isNotEmpty) id.trim(),
      ..._memberIdsFromDisplayText(conversation.displayName),
      ..._memberIdsFromDisplayText(conversation.conversationId),
    };
    final self = ref.read(currentUserProvider)?.userId.trim() ?? '';
    if (self.isNotEmpty) ids.add(self);
    return ids.toList(growable: false)..sort();
  }

  Set<String> _memberIdsFromDisplayText(String value) {
    final raw = value.trim();
    if (raw.isEmpty) return const {};

    var text = raw;
    final usersMatch = RegExp(
      r'users\s*[:：](.+)$',
      caseSensitive: false,
    ).firstMatch(text);
    if (usersMatch != null) {
      text = usersMatch.group(1) ?? '';
    } else {
      final parenMatch = RegExp(r'[（(]([^()（）]+)[）)]').firstMatch(text);
      if (parenMatch != null) {
        text = parenMatch.group(1) ?? '';
      }
    }

    final parts = text
        .split(RegExp(r'[\s,，、;；|/]+'))
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toSet();
    return parts.length >= 2 ? parts : const {};
  }
}

/// 按 [conversationId] 订阅 [conversationProvider] 单行切片，配合 [SliverList] 做局部刷新。
class ConversationListSliverItem extends ConsumerWidget {
  const ConversationListSliverItem({super.key, required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.watch(
      conversationProvider.select(
        (list) => conversationById(list, conversationId),
      ),
    );
    if (c == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: ConversationItem(conversation: c),
    );
  }
}
