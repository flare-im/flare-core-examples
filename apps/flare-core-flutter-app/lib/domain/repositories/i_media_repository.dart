import 'package:flare_im/domain/value_objects/media_storage.dart';

/// 本机媒体：「下载位置」、保存到本机、本地媒体缓存（核心 SDK 的 `media.*`）。
abstract class IMediaRepository {
  /// 当前的下载位置。
  Future<DownloadLocation> getDownloadLocation();

  /// 改下载位置：一个 app 能写的绝对路径，或 null 回到平台默认。文件夹不能写时抛错。
  Future<DownloadLocation> setDownloadLocation(String? directory);

  /// 把 [target] 存进下载位置（`media.download_to_user_directory`）。
  Future<SavedMediaFile> saveToDownloadLocation(MediaSaveTarget target);

  /// 按核心里存的 id 取一张图：本地缓存有就给本机副本；没有就给短时地址，
  /// 并由核心在后台把它缓存下来（`autoCache`）。
  Future<PictureAccess> resolvePicture(String fileId);

  /// 本地媒体缓存占用的字节数（看过的图、存过的文件）。
  Future<int?> mediaCacheBytes();

  Future<void> clearMediaCache();
}
