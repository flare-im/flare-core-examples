import 'dart:async';
import 'dart:io' show File;

import 'package:flare_im/domain/repositories/i_media_repository.dart';
import 'package:flare_im/domain/value_objects/media_storage.dart';
import 'package:flare_im/domain/value_objects/message_content.dart';

/// 本机媒体用例：保存消息里的图片 / 视频 / 文件到「下载位置」、读写下载位置、
/// 量和清本地媒体缓存，以及时间线上的图从哪里画（[resolvePicture]）。
class MediaStorageService {
  MediaStorageService(
    this._repository, {
    DateTime Function()? now,
    bool Function(String path)? fileExists,
  }) : _now = now ?? DateTime.now,
       _fileExists = fileExists ?? _defaultFileExists;

  final IMediaRepository _repository;
  final DateTime Function() _now;
  final bool Function(String path) _fileExists;

  /// 一个签名地址只复用这么久：核心在后台缓存好之后，本机副本很快就能接手。
  static const pictureUrlLifetime = Duration(seconds: 20);

  final Map<String, String> _pictureCopies = {};
  final Map<String, (String, DateTime)> _pictureUrls = {};
  final Map<String, Future<PictureAccess?>> _pictureLookups = {};

  Future<DownloadLocation> downloadLocation() =>
      _repository.getDownloadLocation();

  Future<DownloadLocation> setDownloadLocation(String? directory) =>
      _repository.setDownloadLocation(directory);

  /// 本地媒体缓存的大小；量不出来（SDK 还没就绪、旧核心）时为 null。
  Future<int?> mediaCacheBytes() async {
    try {
      return await _repository.mediaCacheBytes();
    } catch (_) {
      return null;
    }
  }

  Future<void> clearMediaCache() async {
    await _repository.clearMediaCache();
    _pictureCopies.clear();
  }

  /// [content] 有没有东西能存到本机；本机文件只算当前用户自己的消息（[ownMessage]），
  /// 见 [mediaSaveTargetFor]。
  bool canSave(MessageContent content, {bool ownMessage = false}) =>
      mediaSaveTargetFor(content, now: _now(), ownMessage: ownMessage) != null;

  /// 把一条消息里的图片、视频或文件存进「下载位置」：看过的图直接从本地缓存拷出，
  /// 别的按核心里存的 id 下载。本机文件只用于当前用户自己的消息（[ownMessage]）。
  /// 没有东西可存、或核心写不进去时抛错。
  Future<SavedMediaFile> saveMessageMedia(
    MessageContent content, {
    bool ownMessage = false,
  }) {
    final target = mediaSaveTargetFor(
      content,
      now: _now(),
      ownMessage: ownMessage,
    );
    if (target == null) {
      return Future.error(StateError('nothing to save'));
    }
    return _repository.saveToDownloadLocation(target);
  }

  /// 已经知道的画法（不等核心）：本机副本，或还没过期的签名地址。
  PictureAccess? peekPicture(String fileId) {
    final local = _pictureCopies[fileId];
    if (local != null) {
      if (_fileExists(local)) return PictureAccess(localPath: local);
      _pictureCopies.remove(fileId);
    }
    final recent = _pictureUrls[fileId];
    if (recent != null && _now().difference(recent.$2) < pictureUrlLifetime) {
      return PictureAccess(url: recent.$1);
    }
    return null;
  }

  /// 时间线上一张图从哪里画：核心媒体缓存里有就画本机副本；没有就用签名地址，
  /// 同时核心在后台把它缓存下来，看过一次的图以后从磁盘读。同一张图同时只问一次，
  /// 结果短暂记住，免得每次重建都去问。问不到（SDK 没就绪、出错）时为 null，
  /// 调用方照旧画消息自带的地址。
  Future<PictureAccess?> resolvePicture(String fileId) {
    final id = fileId.trim();
    if (id.isEmpty) return Future.value();
    final known = peekPicture(id);
    if (known != null) return Future.value(known);
    // 回调不能返回 remove 的结果：那正是这个 Future 自己，whenComplete 会等它自己。
    return _pictureLookups[id] ??= _lookUpPicture(id).whenComplete(() {
      _pictureLookups.remove(id);
    });
  }

  Future<PictureAccess?> _lookUpPicture(String fileId) async {
    try {
      final access = await _repository.resolvePicture(fileId);
      final local = access.localPath;
      if (local != null && local.isNotEmpty) {
        _pictureCopies[fileId] = local;
        _pictureUrls.remove(fileId);
        return PictureAccess(localPath: local);
      }
      final url = access.url;
      if (url == null || url.isEmpty) return null;
      _pictureUrls[fileId] = (url, _now());
      return PictureAccess(url: url);
    } catch (_) {
      return null;
    }
  }
}

bool _defaultFileExists(String path) {
  try {
    return File(path).existsSync();
  } catch (_) {
    return false;
  }
}
