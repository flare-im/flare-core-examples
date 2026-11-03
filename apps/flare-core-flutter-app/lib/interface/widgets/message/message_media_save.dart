import 'dart:async';

import 'package:flare_im/application/providers/locale_provider.dart';
import 'package:flare_im/application/providers/service_providers.dart';
import 'package:flare_im/domain/entities/message.dart';
import 'package:flare_im/domain/value_objects/media_storage.dart';
import 'package:flare_im/infrastructure/platform/download_location_host.dart';
import 'package:flare_im/shared/i18n/flare_messages.dart';
import 'package:flare_im_ui/flare_im_ui.dart' as ui;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// [message] 是不是当前登录用户（[currentUserId]）自己发的。
bool isOwnMessage(Message message, String currentUserId) {
  final me = currentUserId.trim();
  return me.isNotEmpty && message.senderId == me;
}

/// [message] 里有没有能存到本机的图片、视频或文件。本机文件只算自己的消息：
/// 别人消息里的路径是对方写的字（见 [mediaSaveTargetFor]）。
bool messageMediaSavable(Message message, {required String currentUserId}) =>
    !message.isRecalled &&
    mediaSaveTargetFor(
          message.content,
          ownMessage: isOwnMessage(message, currentUserId),
        ) !=
        null;

/// 保存 [message] 里的图片、视频或文件：由核心 SDK 存进「下载位置」（看过的图直接从
/// 本地缓存拷出）。先提示「正在保存…」，成功时写明存到了哪个文件夹，桌面端可以直接在
/// 文件管理器里显示它；失败时说没存上，自选的文件夹不能写了要说清楚。
///
/// 图片预览的下载键、视频播放器的下载键、长按菜单「保存」和点文件卡片都走这里。
Future<void> saveMessageMedia(
  BuildContext context,
  WidgetRef ref,
  Message message, {
  required String currentUserId,
}) async {
  final messages = ref.read(flareMessagesProvider);
  final service = ref.read(mediaStorageServiceProvider);
  final dismissSaving = ui.FlareToast.show(
    context,
    message: messages.chat.saving,
  );
  try {
    final saved = await service.saveMessageMedia(
      message.content,
      ownMessage: isOwnMessage(message, currentUserId),
    );
    dismissSaving();
    if (!context.mounted) return;
    final reveal = DownloadLocationHost.canReveal;
    ui.FlareToast.show(
      context,
      message: messages.chat.savedTo(shortDownloadLocation(saved.directory)),
      variant: ui.FlareToastVariant.success,
      actionLabel: reveal ? messages.chat.showInFolder : null,
      onAction: reveal
          ? () => unawaited(DownloadLocationHost.reveal(saved.path))
          : null,
    );
  } catch (error) {
    dismissSaving();
    if (!context.mounted) return;
    ui.FlareToast.show(
      context,
      message: mediaSaveFailureText(error, messages),
      variant: ui.FlareToastVariant.error,
    );
  }
}

/// 自选的文件夹不能写了（被删、换了盘、沙盒权限没了）要说清楚，别的失败只说没存上。
String mediaSaveFailureText(Object error, FlareMessages messages) {
  final text = '$error';
  return text.contains('not writable') || text.contains('not usable')
      ? messages.settings.downloadLocationUnwritable
      : messages.chat.saveFailed;
}
