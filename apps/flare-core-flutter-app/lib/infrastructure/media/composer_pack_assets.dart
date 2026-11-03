import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 与 Tauri `composerStickers.ts` 的 [ComposerStickerItem] 对齐。
final class ComposerStickerPackItem {
  final String id;
  final String stickerId;

  /// 协议包 id：`default` 目录 → `gifs`，`classic` → `classic`。
  final String packageId;
  final String assetPath;
  final String alt;

  const ComposerStickerPackItem({
    required this.id,
    required this.stickerId,
    required this.packageId,
    required this.assetPath,
    required this.alt,
  });
}

/// 一次解析 [AssetManifest]，供会话内 `[key]` 展示与输入面板共用。
abstract final class ComposerPackAssets {
  ComposerPackAssets._();

  static Set<String>? _emojiKeys;
  static Map<String, String>? _emojiAssetByKey;
  static Map<String, String>? _stickerAssetByProtocolKey;
  static List<ComposerStickerPackItem>? _stickers;
  static final RegExp _emojiProtocolKey = RegExp(r'^[a-z][a-z0-9_]*$');

  static Future<void> ensureLoaded() async {
    if (_emojiKeys != null) return;
    _emojiKeys = {};
    _emojiAssetByKey = {};
    _stickerAssetByProtocolKey = {};
    final stickerList = <ComposerStickerPackItem>[];
    final hasEmojiManifest = await _ingestManifestAssets(stickerList);
    void ingestPath(String path) {
      if (path.startsWith('assets/emoji/') && path.endsWith('.webp')) {
        if (hasEmojiManifest) return;
        final stem = path.substring('assets/emoji/'.length, path.length - 5);
        if (_isEmojiProtocolKey(stem) && !_emojiAssetByKey!.containsKey(stem)) {
          _emojiKeys!.add(stem);
          _emojiAssetByKey![stem] = path;
        }
      } else if (path.startsWith('assets/stickers/') &&
          path.endsWith('.webp')) {
        final parsed = _parseStickerPath(path);
        if (parsed != null &&
            !_stickerAssetByProtocolKey!.containsKey(
              '${parsed.packageId}/${parsed.stickerId}',
            )) {
          stickerList.add(parsed);
          _stickerAssetByProtocolKey!['${parsed.packageId}/${parsed.stickerId}'] =
              parsed.assetPath;
        }
      }
    }

    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      for (final path in manifest.listAssets()) {
        ingestPath(path);
      }
    } catch (error, stackTrace) {
      _logAssetLoadFailure('AssetManifest', error, stackTrace);
      try {
        final raw = await rootBundle.loadString('AssetManifest.json');
        final map = jsonDecode(raw) as Map<String, dynamic>;
        for (final path in map.keys) {
          ingestPath(path);
        }
      } catch (error, stackTrace) {
        _logAssetLoadFailure('AssetManifest.json', error, stackTrace);
        _emojiKeys = {};
      }
    }

    stickerList.sort(_compareStickerItems);
    _stickers = stickerList;
  }

  static Future<bool> _ingestManifestAssets(
    List<ComposerStickerPackItem> stickerList,
  ) async {
    var hasEmojiManifest = false;
    try {
      final raw = await rootBundle.loadString('assets/emoji/manifest.json');
      final json = jsonDecode(raw);
      final items = json is Map ? json['items'] : null;
      if (items is List) {
        hasEmojiManifest = true;
        for (final item in items.whereType<Map>()) {
          final id = '${item['id'] ?? ''}'.trim();
          final asset = '${item['asset'] ?? ''}'.trim();
          if (id.isEmpty || asset.isEmpty) continue;
          if (!_isEmojiProtocolKey(id)) continue;
          _emojiKeys!.add(id);
          _emojiAssetByKey![id] = asset;
        }
      }
    } catch (error, stackTrace) {
      _logAssetLoadFailure('assets/emoji/manifest.json', error, stackTrace);
    }

    try {
      final raw = await rootBundle.loadString('assets/stickers/manifest.json');
      final json = jsonDecode(raw);
      final packs = json is Map ? json['packs'] : null;
      if (packs is List) {
        for (final pack in packs.whereType<Map>()) {
          final packageId = '${pack['id'] ?? 'compressed'}'.trim();
          final items = pack['items'];
          if (items is! List) continue;
          for (final item in items.whereType<Map>()) {
            final id = '${item['id'] ?? ''}'.trim();
            final asset = '${item['asset'] ?? ''}'.trim();
            if (id.isEmpty || asset.isEmpty) continue;
            final protocolKey = '$packageId/$id';
            if (_stickerAssetByProtocolKey!.containsKey(protocolKey)) continue;
            stickerList.add(
              ComposerStickerPackItem(
                id: 'composer-sticker-$packageId-$id',
                stickerId: id,
                packageId: packageId,
                assetPath: asset,
                alt: '贴纸 $id',
              ),
            );
            _stickerAssetByProtocolKey![protocolKey] = asset;
          }
        }
      }
    } catch (error, stackTrace) {
      _logAssetLoadFailure('assets/stickers/manifest.json', error, stackTrace);
    }
    return hasEmojiManifest;
  }

  static void _logAssetLoadFailure(
    String source,
    Object error,
    StackTrace stackTrace,
  ) {
    debugPrint(
      'ComposerPackAssets: failed to load $source: $error\n$stackTrace',
    );
  }

  static bool _isEmojiProtocolKey(String key) =>
      _emojiProtocolKey.hasMatch(key);

  static ComposerStickerPackItem? _parseStickerPath(String path) {
    const prefix = 'assets/stickers/';
    if (!path.startsWith(prefix) || !path.endsWith('.webp')) return null;
    final rel = path.substring(prefix.length, path.length - 5);
    final slash = rel.lastIndexOf('/');
    if (slash < 0) return null;
    final subdir = rel.substring(0, slash);
    final stem = rel.substring(slash + 1);
    if (stem.isEmpty) return null;
    final packageId = subdir == 'default' ? 'gifs' : subdir;
    return ComposerStickerPackItem(
      id: 'composer-sticker-$packageId-$stem',
      stickerId: stem,
      packageId: packageId,
      assetPath: path,
      alt: '贴纸 $stem',
    );
  }

  static int _packSortRank(String packageId) {
    if (packageId == 'classic') return 0;
    if (packageId == 'gifs') return 1;
    return 2;
  }

  static int _compareStickerItems(
    ComposerStickerPackItem a,
    ComposerStickerPackItem b,
  ) {
    final ra = _packSortRank(a.packageId);
    final rb = _packSortRank(b.packageId);
    if (ra != rb) return ra.compareTo(rb);
    return _naturalCompareStrings(a.stickerId, b.stickerId);
  }

  static int _naturalCompareStrings(String a, String b) {
    final na = int.tryParse(a);
    final nb = int.tryParse(b);
    if (na != null && nb != null) return na.compareTo(nb);
    return a.compareTo(b);
  }

  /// 是否存在 `assets/emoji/<key>.webp`（与 Tauri `keyToUrl` 语义一致）。
  static bool hasEmojiWebp(String key) {
    final k = key.trim();
    if (k.isEmpty) return false;
    return _emojiKeys?.contains(k) ?? false;
  }

  static List<String> get sortedEmojiKeys {
    final list = _emojiKeys?.toList() ?? <String>[];
    list.sort();
    return list;
  }

  static List<ComposerStickerPackItem> get allStickers =>
      List.unmodifiable(_stickers ?? const []);

  static String? emojiAssetPath(String key) => _emojiAssetByKey?[key.trim()];

  static String? stickerAssetPath({
    required String stickerId,
    required String packageId,
  }) {
    return _stickerAssetByProtocolKey?['${packageId.trim()}/${stickerId.trim()}'];
  }

  static List<ComposerStickerPackItem> stickersForPackage(String packageId) {
    return allStickers.where((s) => s.packageId == packageId).toList();
  }

  /// 贴纸分包 id 顺序（与 [_compareStickerItems] 包顺序一致），供底栏 Tab 使用。
  static List<String> get stickerPackageIdsInOrder {
    final ids = <String>{};
    for (final s in allStickers) {
      ids.add(s.packageId);
    }
    final list = ids.toList();
    list.sort((a, b) {
      final ra = _packSortRank(a);
      final rb = _packSortRank(b);
      if (ra != rb) return ra.compareTo(rb);
      return a.compareTo(b);
    });
    return list;
  }

  /// 某包内第一张贴纸（用于底栏小预览）。
  static ComposerStickerPackItem? firstStickerInPackage(String packageId) {
    final list = stickersForPackage(packageId);
    return list.isEmpty ? null : list.first;
  }
}
