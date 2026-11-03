import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 与 Rust [`parse_data_url_to_path`] / Tauri `resolveSdkDataUrl` 对齐：`SdkConfig.data_url` 须为 `file://` 根目录。
///
/// 使用应用支持目录下的 `flare_im_sdk`，供 SQLite 与媒体缓存落盘。
Future<String> resolveSdkDataUrl() async {
  final base = await getApplicationSupportDirectory();
  final root = '${base.path}${Platform.pathSeparator}flare_im_sdk';
  await Directory(root).create(recursive: true);
  return toFileDataUrl(root);
}

/// 绝对路径 → `file://...`（与 core `parse_data_url_to_path` 可解析格式一致）。
String toFileDataUrl(String absolutePath) {
  return Uri.file(absolutePath).toString();
}
