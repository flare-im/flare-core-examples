import 'package:flare_im/application/providers/locale_provider.dart';
import 'package:flare_im/application/providers/media_storage_provider.dart';
import 'package:flare_im/application/providers/service_providers.dart';
import 'package:flare_im/domain/entities/message.dart';
import 'package:flare_im/domain/value_objects/conversation_type.dart';
import 'package:flare_im/domain/value_objects/media_storage.dart';
import 'package:flare_im/domain/value_objects/message_content.dart';
import 'package:flare_im/infrastructure/media/network_image_policy.dart';
import 'package:flare_im/interface/widgets/media_viewer/image_preview_modal.dart';
import 'package:flare_im/interface/widgets/media_viewer/video_player_modal.dart';
import 'package:flare_im/interface/widgets/message/message_long_press_menu.dart';
import 'package:flare_im/interface/widgets/message/message_media_save.dart';
import 'package:flare_im_ui/flare_im_ui.dart' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// SDK-domain to design-kit adapter. Commands stay in the example; visual
/// structure, status, media, tokens, and accessibility stay in the kit.
class SdkMessageBubbleAdapter extends ConsumerWidget {
  const SdkMessageBubbleAdapter({
    super.key,
    required this.message,
    this.showAvatar = true,
    this.currentUserId = '',
    this.onRecall,
    this.onDeleteForEveryone,
    this.onDeleteForSelf,
    this.showDeleteForEveryoneOption = false,
    this.onEdit,
    this.onReaction,
    this.onRemoveReaction,
    this.onCopy,
    this.onReply,
    this.onForward,
    this.onMultiSelect,
    this.onMark,
    this.onPinToggle,
    this.onPinForSelf,
    required this.pinToggleLabel,
    this.onResend,
    this.quotedSenderResolvedName,
  });

  final Message message;
  final bool showAvatar;
  final String currentUserId;
  final VoidCallback? onRecall;
  final Future<void> Function()? onDeleteForEveryone;
  final Future<void> Function()? onDeleteForSelf;
  final bool showDeleteForEveryoneOption;
  final VoidCallback? onEdit;
  final void Function(String emoji)? onReaction;
  final void Function(String emoji)? onRemoveReaction;
  final VoidCallback? onCopy;
  final VoidCallback? onReply;
  final VoidCallback? onForward;
  final VoidCallback? onMultiSelect;
  final VoidCallback? onMark;
  final VoidCallback? onPinToggle;
  final VoidCallback? onPinForSelf;
  final String pinToggleLabel;
  final VoidCallback? onResend;
  final String? quotedSenderResolvedName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final i18n = ref.watch(flareMessagesProvider).chat;
    final presentation = _toPresentation(message, _pictureAccess(ref));
    final self = message.senderId == currentUserId;
    final own = isOwnMessage(message, currentUserId);
    final savable = messageMediaSavable(message, currentUserId: currentUserId);
    void save() =>
        saveMessageMedia(context, ref, message, currentUserId: currentUserId);
    return Column(
      crossAxisAlignment: self
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        ui.FlareMessageBubble(
          message: presentation,
          currentUserId: currentUserId,
          conversationKind: showAvatar
              ? ui.FlareConversationKind.group
              : ui.FlareConversationKind.single,
          rowPresentation: ui.FlareMessageRowPresentation(
            showAvatar: showAvatar && !self,
            reserveAvatarSpace: showAvatar && !self,
            showSenderName: showAvatar && !self,
          ),
          onLongPress: message.isRecalled
              ? null
              : (_) => showMessageLongPressMenu(
                  context,
                  onPickReaction: onReaction,
                  onReply: onReply,
                  onForward: onForward,
                  onRecall: onRecall,
                  onMultiSelect: onMultiSelect,
                  onMark: onMark,
                  onPinToggle: onPinToggle,
                  onPinForSelf: onPinForSelf,
                  pinLabel: pinToggleLabel,
                  onCopy: onCopy,
                  onSave: savable ? save : null,
                  onEdit: onEdit,
                  onDeleteForSelf: onDeleteForSelf,
                  onDeleteForEveryone: onDeleteForEveryone,
                  showDeleteForEveryoneOption: showDeleteForEveryoneOption,
                  i18n: i18n,
                ),
          onMediaAction: (_, content) async {
            if (content is ui.FlareImageContent) {
              // 画面上的那一份：宿主经 SDK 缓存解析出的本机副本，否则网址。
              final local = content.localPath?.trim() ?? '';
              final source = local.isNotEmpty
                  ? local
                  : _openableAddress(content.url, own);
              if (source.isEmpty) return;
              await ImagePreviewModal.show(
                context,
                imageUrl: source,
                onDownload: savable ? save : null,
              );
            } else if (content is ui.FlareVideoContent) {
              final source = _openableAddress(content.url, own);
              if (source.isEmpty) return;
              await VideoPlayerModal.show(
                context,
                videoUrl: source,
                posterUrl: content.poster,
                onDownload: savable ? save : null,
              );
            } else if (content is ui.FlareAudioContent) {
              await VideoPlayerModal.show(
                context,
                videoUrl: content.url,
                audioOnly: true,
              );
            } else if (content is ui.FlareFileContent) {
              // 点文件就存进「下载位置」（核心按消息里存的文件 id 取）。
              if (savable) save();
            }
          },
          onResend: onResend == null ? null : (_) => onResend!(),
        ),
        if (!message.isRecalled && (message.reactions?.isNotEmpty ?? false))
          ui.FlareReactionSummary(
            reactions: message.reactions!
                .map(
                  (reaction) => ui.FlareReactionGroup(
                    emoji: reaction.emoji,
                    count: reaction.count,
                    reactedBySelf: reaction.userIds.contains(currentUserId),
                  ),
                )
                .toList(),
            hideAdd: true,
            onToggle: (emoji) {
              final selected = message.reactions!.any(
                (reaction) =>
                    reaction.emoji == emoji &&
                    reaction.userIds.contains(currentUserId),
              );
              if (selected) {
                onRemoveReaction?.call(emoji);
              } else {
                onReaction?.call(emoji);
              }
            },
          ),
      ],
    );
  }

  /// 时间线上这张图从哪里画（按核心里存的 id 经 SDK 媒体缓存解析）：已经知道的
  /// 答案立刻用，没有时等 [pictureAccessProvider]；都没有时画消息自带的地址。
  /// 只有带存储 id 的图片才去问，别的消息不碰 SDK。
  PictureAccess? _pictureAccess(WidgetRef ref) {
    final content = message.content;
    if (message.isRecalled || content is! ImageContent) return null;
    final fileId = content.fileId?.trim() ?? '';
    if (fileId.isEmpty) return null;
    return ref.watch(pictureAccessProvider(fileId)).valueOrNull ??
        ref.read(mediaStorageServiceProvider).peekPicture(fileId);
  }

  ui.FlareMessageData _toPresentation(Message value, PictureAccess? picture) {
    final senderName = value.senderDisplayName.trim().isNotEmpty
        ? value.senderDisplayName.trim()
        : value.senderName.trim().isNotEmpty
        ? value.senderName.trim()
        : value.senderId;
    return ui.FlareMessageData(
      id: value.timelineKey.isNotEmpty
          ? value.timelineKey
          : value.serverId.isNotEmpty
          ? value.serverId
          : value.clientMsgId,
      senderId: value.senderId,
      senderName: senderName,
      senderAvatarUrl: value.senderAvatar.trim().isEmpty
          ? value.extra['avatarUrl']
          : value.senderAvatar,
      content: value.isRecalled
          ? const ui.FlareNotificationContent('Message recalled')
          : _toContent(value.content, picture),
      timeLabel:
          '${value.timestamp.hour.toString().padLeft(2, '0')}:${value.timestamp.minute.toString().padLeft(2, '0')}',
      status: switch (value.status) {
        MessageStatus.sending => ui.FlareMessageDeliveryStatus.sending,
        MessageStatus.sent => ui.FlareMessageDeliveryStatus.sent,
        // The kit draws delivered as sent (a single check); read is the double.
        MessageStatus.delivered => ui.FlareMessageDeliveryStatus.sent,
        MessageStatus.read => ui.FlareMessageDeliveryStatus.read,
        MessageStatus.failed => ui.FlareMessageDeliveryStatus.failed,
      },
      edited: value.isEdited,
    );
  }

  ui.FlareMessageContent _toContent(
    MessageContent content,
    PictureAccess? picture,
  ) {
    return switch (content) {
      TextContent(:final text) => ui.FlareTextContent(text),
      ImageContent(
        :final url,
        :final localPath,
        :final width,
        :final height,
        :final description,
      ) =>
        ui.FlareImageContent(
          url:
              _nonEmpty(picture?.url) ??
              (url.isNotEmpty ? url : localPath ?? ''),
          // 只放宿主经 SDK 缓存解析出的本机副本，绝不取消息内容里的路径。
          localPath: _nonEmpty(picture?.localPath),
          width: width?.toDouble(),
          height: height?.toDouble(),
          alt: description,
        ),
      VideoContent(
        :final url,
        :final localPath,
        :final thumbnailUrl,
        :final duration,
      ) =>
        ui.FlareVideoContent(
          url: url.isNotEmpty ? url : localPath ?? '',
          poster: thumbnailUrl,
          durationSec: duration ?? 0,
        ),
      AudioContent(:final url, :final localPath, :final duration) =>
        ui.FlareAudioContent(
          url: url.isNotEmpty ? url : localPath ?? '',
          durationSec: duration ?? 0,
        ),
      FileContent(:final url, :final localPath, :final filename, :final size) =>
        ui.FlareFileContent(
          name: filename,
          url: url.isNotEmpty ? url : localPath ?? '',
          sizeBytes: size ?? 0,
        ),
      LocationContent(
        :final title,
        :final address,
        :final latitude,
        :final longitude,
      ) =>
        ui.FlareLocationContent(
          name: title ?? address ?? 'Location',
          address: address ?? '',
          latitude: latitude,
          longitude: longitude,
        ),
      StickerContent(
        :final url,
        :final packageId,
        :final stickerId,
        :final width,
        :final height,
      ) =>
        ui.FlareStickerContent(
          url: url ?? '',
          packageId: packageId,
          stickerId: stickerId,
          width: width?.toDouble(),
          height: height?.toDouble(),
        ),
      EmojiContent(:final emoji) => ui.FlareEmojiContent(emoji),
      CardContent(:final title, :final subtitle, :final avatar) =>
        ui.FlareCardContent(
          title: title ?? content.previewText,
          subtitle: subtitle,
          imageUrl: avatar,
        ),
      LinkCardContent(
        :final url,
        :final title,
        :final summary,
        :final thumbnailUrl,
      ) =>
        ui.FlareLinkCardContent(
          url: url,
          title: title ?? url,
          description: summary,
          imageUrl: thumbnailUrl,
        ),
      NotificationContent() => ui.FlareNotificationContent(content.previewText),
      final VoteContent c => ui.FlarePollContent(
        id: c.voteId ?? '',
        title: c.headline ?? content.previewText,
        options: c.options,
      ),
      final TaskContent c => ui.FlareTaskContent(
        id: c.taskId ?? '',
        title: c.title ?? content.previewText,
        detail: c.detail ?? '',
        done: c.metadata['done'] == 'true',
      ),
      final ScheduleContent c => ui.FlareCalendarContent(
        id: c.scheduleId ?? '',
        title: c.title ?? content.previewText,
        timeRange: c.timeRange ?? '',
      ),
      final MiniProgramContent c => ui.FlareMiniAppContent(
        appId: c.appId,
        title: c.title ?? c.appId,
        pagePath: c.pagePath ?? '',
        thumbnailUrl: c.thumbnailUrl,
        description: c.description,
      ),
      final AnnouncementContent c => ui.FlareAnnouncementContent(
        id: c.announcementId ?? '',
        title: c.headline ?? content.previewText,
        body: c.body ?? '',
      ),
      _ => ui.FlareGenericContent(
        contentType: content.contentType,
        label: content.previewText,
      ),
    };
  }
}

/// 能打开的地址：别人消息里的本机路径是对方写的字，不打开这台设备上的文件；
/// 自己还在上传的消息才会指向本机文件。
String _openableAddress(String address, bool ownMessage) {
  final value = address.trim();
  if (ownMessage || !isLocalFileLikePath(value)) return value;
  return '';
}

String? _nonEmpty(String? value) {
  final trimmed = value?.trim() ?? '';
  return trimmed.isEmpty ? null : trimmed;
}
