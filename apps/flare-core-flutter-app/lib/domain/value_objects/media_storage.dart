import 'package:equatable/equatable.dart';
import 'package:flare_im/domain/value_objects/message_content.dart';

/// 「下载位置」：保存到本机的图片、视频、文件写进哪个文件夹（核心 SDK 的
/// `media.user_download_*`）。默认位置由核心按平台给出：桌面是「下载/flare」，
/// Android 是共享存储 `Download/flare`，iOS 是「文件」App 可见的 `Documents/flare`。
class DownloadLocation extends Equatable {
  const DownloadLocation({
    required this.directory,
    required this.defaultDirectory,
    required this.isCustom,
  });

  /// 实际生效的文件夹（绝对路径）。
  final String directory;

  /// 平台默认文件夹（没有自选时生效）。
  final String defaultDirectory;

  /// 用户自选过文件夹。
  final bool isCustom;

  @override
  List<Object?> get props => [directory, defaultDirectory, isCustom];
}

/// 一次「保存到本机」的结果。
class SavedMediaFile extends Equatable {
  const SavedMediaFile({
    required this.path,
    required this.directory,
    required this.fileName,
    this.sizeBytes = 0,
    this.fromCache = false,
  });

  /// 保存后的文件（绝对路径）。
  final String path;

  /// 文件所在的文件夹。
  final String directory;

  /// 实际文件名（同名时核心加 ` (n)`，没扩展名时按类型补）。
  final String fileName;
  final int sizeBytes;

  /// 取自本地媒体缓存（没有走网络）。
  final bool fromCache;

  @override
  List<Object?> get props => [path, directory, fileName, sizeBytes, fromCache];
}

/// 保存一条消息里的图片、视频或文件要交给核心的东西：优先核心里存的 [fileId]
/// （命中本地缓存时直接拷出，不走网络）；还没上传完的自己的消息用本机的 [sourcePath]；
/// 只带网址的消息用 [sourceUrl]。
class MediaSaveTarget extends Equatable {
  const MediaSaveTarget({
    required this.fileName,
    this.fileId,
    this.sourcePath,
    this.sourceUrl,
  });

  /// 保存成的名字：发送方给的文件名，或 `IMG_…` / `VID_…`（核心按类型补扩展名）。
  final String fileName;
  final String? fileId;
  final String? sourcePath;
  final String? sourceUrl;

  @override
  List<Object?> get props => [fileName, fileId, sourcePath, sourceUrl];
}

/// 一张图从哪里画：核心媒体缓存里的本机副本，或一个短时签名地址。
class PictureAccess extends Equatable {
  const PictureAccess({this.localPath, this.url});

  final String? localPath;
  final String? url;

  @override
  List<Object?> get props => [localPath, url];
}

/// [content] 能保存时要交给核心的目标；贴纸、文本、语音等不能保存的内容为 null。
///
/// 名字：文件用发送方给的文件名；图片 / 视频用 `IMG_yyyyMMdd_HHmmss` /
/// `VID_yyyyMMdd_HHmmss`（[now] 的本地时间），扩展名由核心按文件类型补上。
///
/// 本机文件（[MediaSaveTarget.sourcePath]）只取当前登录用户自己的消息（[ownMessage]）：
/// 核心按「本机文件 > 网址 > 文件 id」取来源，且不检查 `sourcePath`；别人消息里的路径是
/// 对方写的字，照着存会把这台设备上的文件（比如 SDK 数据库）拷进下载文件夹。
/// 别人的消息只用文件 id 或 http(s) 网址，都没有就不能保存。
MediaSaveTarget? mediaSaveTargetFor(
  MessageContent content, {
  DateTime? now,
  bool ownMessage = false,
}) {
  final stamp = _saveStamp(now ?? DateTime.now());
  return switch (content) {
    FileContent(:final fileId, :final url, :final localPath, :final filename) =>
      _target(
        fileName: filename.trim().isEmpty ? 'file' : filename.trim(),
        fileId: fileId,
        addresses: [url, localPath],
        allowLocalFile: ownMessage,
      ),
    ImageContent(:final fileId, :final url, :final localPath) => _target(
      fileName: 'IMG_$stamp',
      fileId: fileId,
      addresses: [url, localPath],
      allowLocalFile: ownMessage,
    ),
    VideoContent(:final fileId, :final url, :final localPath) => _target(
      fileName: 'VID_$stamp',
      fileId: fileId,
      addresses: [url, localPath],
      allowLocalFile: ownMessage,
    ),
    _ => null,
  };
}

MediaSaveTarget? _target({
  required String fileName,
  required String? fileId,
  required List<String?> addresses,
  required bool allowLocalFile,
}) {
  final id = fileId?.trim() ?? '';
  if (id.isNotEmpty) return MediaSaveTarget(fileName: fileName, fileId: id);
  for (final raw in addresses) {
    final value = raw?.trim() ?? '';
    if (value.isEmpty) continue;
    final uri = Uri.tryParse(value);
    final scheme = uri?.scheme.toLowerCase() ?? '';
    if (scheme == 'http' || scheme == 'https') {
      return MediaSaveTarget(fileName: fileName, sourceUrl: value);
    }
    if (!allowLocalFile) continue;
    if (scheme == 'file') {
      return MediaSaveTarget(fileName: fileName, sourcePath: uri!.toFilePath());
    }
    if (value.startsWith('/') || RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(value)) {
      return MediaSaveTarget(fileName: fileName, sourcePath: value);
    }
  }
  return null;
}

String _saveStamp(DateTime t) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${t.year}${two(t.month)}${two(t.day)}_'
      '${two(t.hour)}${two(t.minute)}${two(t.second)}';
}
