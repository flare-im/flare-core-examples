// 引用回复展示条数据。
class ComposerReplyQuote {
  final String senderName;
  final String preview;

  const ComposerReplyQuote({required this.senderName, required this.preview});

  bool get isVisible {
    return senderName.trim().isNotEmpty || preview.trim().isNotEmpty;
  }
}

// 附件菜单类型（图 / 视频 / 文件等）。
enum ComposerPickMediaKind {
  /// 相册多选图片+视频
  imageOrVideo,
  image,
  video,
  audio,
  file,
  folder,
}

// 贴纸选择结果，交给上层发送。
class ComposerStickerPick {
  final String stickerId;
  final String packageId;
  final String assetPath;

  const ComposerStickerPick({
    required this.stickerId,
    required this.packageId,
    required this.assetPath,
  });
}
