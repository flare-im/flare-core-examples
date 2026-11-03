import 'package:flare_im/domain/repositories/i_media_repository.dart';
import 'package:flare_im/domain/value_objects/media_storage.dart';
import 'package:flare_im/infrastructure/sdk/flare_core_sdk_wrapper.dart';

/// [IMediaRepository] over the core SDK `media.*` operations.
class MediaRepositoryImpl implements IMediaRepository {
  MediaRepositoryImpl(this._sdk);

  final SdkWrapper _sdk;

  /// Never reach the native library before `init`: the calls below would load
  /// it and run against no session.
  void _requireSdk() {
    if (!_sdk.isInitialized) {
      throw StateError('flare sdk is not initialized');
    }
  }

  @override
  Future<DownloadLocation> getDownloadLocation() async {
    _requireSdk();
    return downloadLocationFromCore(await _sdk.getUserDownloadDirectory());
  }

  @override
  Future<DownloadLocation> setDownloadLocation(String? directory) async {
    _requireSdk();
    final trimmed = directory?.trim();
    return downloadLocationFromCore(
      await _sdk.setUserDownloadDirectory(
        trimmed == null || trimmed.isEmpty ? null : trimmed,
      ),
    );
  }

  @override
  Future<SavedMediaFile> saveToDownloadLocation(MediaSaveTarget target) async {
    _requireSdk();
    return savedMediaFileFromCore(
      await _sdk.downloadToUserDirectory(
        fileName: target.fileName,
        fileId: target.fileId,
        sourceUrl: target.sourceUrl,
        sourcePath: target.sourcePath,
      ),
    );
  }

  @override
  Future<PictureAccess> resolvePicture(String fileId) async {
    _requireSdk();
    return pictureAccessFromCore(
      await _sdk.resolveMediaAccess(fileId, autoCache: true),
    );
  }

  @override
  Future<int?> mediaCacheBytes() async {
    _requireSdk();
    return mediaCacheBytesFromCore(await _sdk.mediaCacheStats());
  }

  @override
  Future<void> clearMediaCache() async {
    _requireSdk();
    await _sdk.clearMediaCache();
  }
}

/// `media.user_download_get_directory` / `_set_directory` (camelCase).
DownloadLocation downloadLocationFromCore(Map<String, dynamic> raw) {
  final directory = _text(raw['directory']);
  final fallback = _text(raw['defaultDirectory']);
  return DownloadLocation(
    directory: directory.isNotEmpty ? directory : fallback,
    defaultDirectory: fallback.isNotEmpty ? fallback : directory,
    isCustom: raw['isCustom'] == true,
  );
}

/// `media.download_to_user_directory` (camelCase).
SavedMediaFile savedMediaFileFromCore(Map<String, dynamic> raw) {
  final path = _text(raw['path']);
  if (path.isEmpty) {
    throw StateError('download_to_user_directory returned no path');
  }
  final directory = _text(raw['directory']);
  final name = _text(raw['fileName']);
  return SavedMediaFile(
    path: path,
    directory: directory.isNotEmpty ? directory : _parentOf(path),
    fileName: name.isNotEmpty ? name : path.split(RegExp(r'[\\/]')).last,
    sizeBytes: (raw['sizeBytes'] as num?)?.toInt() ?? 0,
    fromCache: raw['fromCache'] == true,
  );
}

/// `media.resolve_access`: `{source, localPath?, remote?{url, cdnUrl?}}`.
PictureAccess pictureAccessFromCore(Map<String, dynamic> raw) {
  final local = _text(raw['localPath']);
  if (local.isNotEmpty) return PictureAccess(localPath: local);
  final remote = raw['remote'];
  final url = remote is Map
      ? _firstNonEmpty([_text(remote['url']), _text(remote['cdnUrl'])])
      : '';
  return PictureAccess(url: url.isEmpty ? null : url);
}

/// `media.cache_stats` is snake_case: `{total_bytes, entry_count, ...}`.
int? mediaCacheBytesFromCore(Map<String, dynamic> raw) {
  final total = raw['total_bytes'] ?? raw['totalBytes'];
  return total is num ? total.toInt() : null;
}

String _text(Object? value) => value is String ? value.trim() : '';

String _firstNonEmpty(List<String> values) =>
    values.firstWhere((v) => v.isNotEmpty, orElse: () => '');

String _parentOf(String path) {
  final cut = path.lastIndexOf(RegExp(r'[\\/]'));
  return cut <= 0 ? path : path.substring(0, cut);
}
