import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// 资源网格内使用：只解码 **首帧**，避免动画 WebP 在选择器里循环播放；会话内仍可用普通 [Image.asset] 展示动态效果。
class ComposerStaticAssetImage extends StatefulWidget {
  const ComposerStaticAssetImage({
    super.key,
    required this.assetPath,
    this.fit = BoxFit.contain,
    this.width,
    this.height,
    this.decodeSize = 112,
    this.error,
  });

  final String assetPath;
  final BoxFit fit;
  final double? width;
  final double? height;

  /// 解码缩放边长（降低内存与 CPU）
  final int decodeSize;
  final Widget? error;

  static final Map<String, MemoryImage> _cache = {};

  @override
  State<ComposerStaticAssetImage> createState() =>
      _ComposerStaticAssetImageState();
}

class _ComposerStaticAssetImageState extends State<ComposerStaticAssetImage> {
  MemoryImage? _provider;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant ComposerStaticAssetImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.assetPath != widget.assetPath) {
      _failed = false;
      _provider = null;
      _resolve();
    }
  }

  Future<void> _resolve() async {
    final path = widget.assetPath;
    final cached = ComposerStaticAssetImage._cache[path];
    if (cached != null) {
      if (mounted) setState(() => _provider = cached);
      return;
    }
    try {
      final data = await rootBundle.load(path);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(),
        targetWidth: widget.decodeSize,
        targetHeight: widget.decodeSize,
      );
      final frame = await codec.getNextFrame();
      final img = frame.image;
      final bd = await img.toByteData(format: ui.ImageByteFormat.png);
      img.dispose();
      if (bd == null) {
        if (mounted) setState(() => _failed = true);
        return;
      }
      final mem = MemoryImage(bd.buffer.asUint8List());
      ComposerStaticAssetImage._cache[path] = mem;
      if (ComposerStaticAssetImage._cache.length > 180) {
        final firstKey = ComposerStaticAssetImage._cache.keys.first;
        ComposerStaticAssetImage._cache.remove(firstKey);
      }
      if (mounted) setState(() => _provider = mem);
    } catch (_) {
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) {
      return widget.error ??
          Icon(
            Icons.broken_image_outlined,
            size: 22,
            color: Theme.of(context).colorScheme.outline,
          );
    }
    final p = _provider;
    if (p == null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    return Image(
      image: p,
      width: widget.width,
      height: widget.height,
      fit: widget.fit,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
    );
  }
}
