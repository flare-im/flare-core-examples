import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';

/// 「下载位置」的宿主一半：让人挑一个文件夹、在系统文件管理器里显示保存好的文件。
/// 文件夹本身（默认位置、自选位置、写入）由核心 SDK 管（`media.user_download_*`）。
///
/// macOS 的 app 在沙盒里：挑到的文件夹只在这次运行里可写，所以由宿主留一枚安全书签，
/// 下次启动凭书签拿回写权限（[restoreAccess]）；这一半走 app 自己的 `flare.im/files` 通道
/// （macos/Runner/MainFlutterWindow.swift 的 `FlareFilesChannel`）。
abstract final class DownloadLocationHost {
  static const MethodChannel channel = MethodChannel('flare.im/files');

  /// 这个平台能不能让人自选下载文件夹。iOS 只能存进「文件」App 里本应用的文件夹。
  static bool get canPick =>
      !kIsWeb &&
      (Platform.isMacOS ||
          Platform.isWindows ||
          Platform.isLinux ||
          Platform.isAndroid);

  /// 保存好的文件能不能在系统文件管理器里显示（桌面）。
  static bool get canReveal =>
      !kIsWeb && (Platform.isMacOS || Platform.isWindows || Platform.isLinux);

  /// 下载位置在「文件」App 里（iOS）。
  static bool get inFilesApp => !kIsWeb && Platform.isIOS;

  /// 让人挑一个文件夹，返回它的绝对路径；取消（或平台不支持）时为 null。
  static Future<String?> pickDirectory({String? initialDirectory}) async {
    if (!canPick) return null;
    try {
      final String? path;
      if (Platform.isMacOS) {
        path = await channel.invokeMethod<String>('pickDirectory', {
          'initialDirectory': ?initialDirectory,
        });
      } else {
        path = await FilePicker.platform.getDirectoryPath(
          initialDirectory: initialDirectory,
        );
      }
      return (path == null || path.isEmpty) ? null : path;
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    } on UnimplementedError {
      return null;
    }
  }

  /// macOS：拿回上次挑的文件夹的写权限（启动时调用一次）。其他平台什么都不做。
  static Future<void> restoreAccess() async {
    if (kIsWeb || !Platform.isMacOS) return;
    try {
      await channel.invokeMethod<String>('restoreDirectoryAccess');
    } on MissingPluginException {
      // 测试宿主没有这条通道。
    } on PlatformException {
      // 书签失效：保存时核心会说文件夹不能写，页面据此请人重选。
    }
  }

  /// 回到默认位置后，丢掉旧文件夹的书签。
  static Future<void> forgetDirectory() async {
    if (kIsWeb || !Platform.isMacOS) return;
    try {
      await channel.invokeMethod<void>('forgetDirectory');
    } on MissingPluginException {
      // 测试宿主没有这条通道。
    } on PlatformException {
      // 没有书签可丢。
    }
  }

  /// 在系统文件管理器里显示 [path]（选中它）。返回是否做到了。
  static Future<bool> reveal(String path) async {
    if (!canReveal || path.isEmpty) return false;
    try {
      if (Platform.isMacOS) {
        return await channel.invokeMethod<bool>('reveal', {'path': path}) ??
            false;
      }
      if (Platform.isWindows) {
        await Process.run('explorer.exe', ['/select,', path]);
        return true;
      }
      await Process.run('xdg-open', [File(path).parent.path]);
      return true;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    } on ProcessException {
      return false;
    }
  }
}

/// 给人看的文件夹：用户目录写成 `~`，太长只留最后两级。
/// macOS 沙盒里 `HOME` 是容器目录，容器里的「下载」同样写成 `~/Downloads`。
String shortDownloadLocation(String directory, {String? home}) {
  var shown = directory.trim();
  if (shown.isEmpty) return shown;
  final homeDir = home ?? (kIsWeb ? '' : (Platform.environment['HOME'] ?? ''));
  final container = RegExp(r'^/Users/[^/]+/Library/Containers/[^/]+/Data');
  final inContainer = container.firstMatch(shown);
  if (inContainer != null) {
    shown = '~${shown.substring(inContainer.end)}';
  } else if (homeDir.isNotEmpty &&
      (shown == homeDir || shown.startsWith('$homeDir/'))) {
    shown = '~${shown.substring(homeDir.length)}';
  }
  final parts = shown
      .split(RegExp(r'[\\/]'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.length > 3) {
    shown = '…/${parts.sublist(parts.length - 2).join('/')}';
  }
  return shown;
}
