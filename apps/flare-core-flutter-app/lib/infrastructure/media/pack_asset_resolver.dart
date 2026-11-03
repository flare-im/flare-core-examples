import 'package:flare_im/infrastructure/media/composer_pack_assets.dart';

/// 与 Tauri `composerStickers.ts` / `StickerView.vue` 一致：用 `package_id` + `sticker_id` 映射到打包资源。
///
/// - 磁盘目录 `stickers/default/` → 协议里 `package_id = gifs`
/// - `stickers/classic/` → `package_id = classic`
class PackAssetResolver {
  PackAssetResolver._();

  /// 协议中 default 目录对应的包 id（与 Tauri `DEFAULT_STICKER_PACKAGE_ID` 一致）
  static const String stickerPackageGifs = 'gifs';

  /// `package_id` → `assets/stickers/` 下子目录名
  static String stickerSubdirForPackageId(String? packageId) {
    final p = packageId?.trim() ?? '';
    if (p.isEmpty) return 'default';
    if (p == stickerPackageGifs) return 'default';
    return p;
  }

  /// 贴纸资源路径（供 [Image.asset]）：使用 `package_id` + `sticker_id` 映射打包资源。
  static String? stickerAssetPath({
    required String stickerId,
    String? packageId,
  }) {
    final sid = stickerId.trim();
    if (sid.isEmpty) return null;

    final pid = packageId?.trim();
    if (pid == null || pid.isEmpty) return null;

    final manifestAsset = ComposerPackAssets.stickerAssetPath(
      stickerId: sid,
      packageId: pid,
    );
    if (manifestAsset != null) return manifestAsset;

    final subdir = stickerSubdirForPackageId(pid);
    return 'assets/stickers/$subdir/$sid.webp';
  }

  /// 表情 key → `assets/emoji/<key>.webp`（与 Tauri `composerEmojiAssets.ts` 一致）
  static String emojiPackAssetPath(String packKey) {
    final k = packKey.trim();
    final manifestAsset = ComposerPackAssets.emojiAssetPath(k);
    if (manifestAsset != null) return manifestAsset;
    return 'assets/emoji/$k.webp';
  }
}
