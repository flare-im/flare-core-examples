import 'dart:async' show unawaited;

import 'package:flare_im/app.dart';
import 'package:flare_im/infrastructure/media/composer_pack_assets.dart';
import 'package:flare_im/infrastructure/media/emoji_pack_i18n.dart';
import 'package:flare_im/infrastructure/platform/download_location_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // macOS 沙盒：上次自选的下载文件夹，凭书签拿回写权限（保存时核心直接写进去）。
  unawaited(DownloadLocationHost.restoreAccess());
  await Future.wait([
    EmojiPackI18n.ensureLoaded(),
    ComposerPackAssets.ensureLoaded(),
  ]);
  runApp(const ProviderScope(child: FlareImApp()));
}
