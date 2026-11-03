import 'package:flare_im/application/providers/service_providers.dart';
import 'package:flare_im/domain/value_objects/media_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 设置页「下载位置」一行：读不到（SDK 还没就绪）时为 null，那一行不写位置。
final downloadLocationProvider = FutureProvider.autoDispose<DownloadLocation?>((
  ref,
) async {
  try {
    return await ref.watch(mediaStorageServiceProvider).downloadLocation();
  } catch (_) {
    return null;
  }
});

/// 设置页「图片与文件缓存」一行的大小；量不出来时为 null。
final mediaCacheBytesProvider = FutureProvider.autoDispose<int?>(
  (ref) => ref.watch(mediaStorageServiceProvider).mediaCacheBytes(),
);

/// 时间线上一张图（按核心里存的 id）从哪里画，见 `MediaStorageService.resolvePicture`。
/// 行滚出屏幕就释放；再回来时服务里记住的结果让它立刻有答案。
final pictureAccessProvider = FutureProvider.autoDispose
    .family<PictureAccess?, String>(
      (ref, fileId) =>
          ref.watch(mediaStorageServiceProvider).resolvePicture(fileId),
    );
