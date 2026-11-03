import 'package:flare_im/infrastructure/media/composer_static_asset_image.dart';
import 'package:flare_im/infrastructure/media/emoji_pack_i18n.dart';
import 'package:flare_im/infrastructure/media/pack_asset_resolver.dart';
import 'package:flare_im_ui/flare_im_ui.dart' as kit_sizes show FlareSizes;
import 'package:flare_im_ui/flare_im_ui.dart' as kit_theme show FlareColors;
import 'package:flutter/material.dart';

/// `assets/emoji/<key>.webp` 缩略图，与会话内 `[key]` 与 [ComposerEmojiSpanBuilder] 一致。
class ComposerEmojiPackThumb extends StatelessWidget {
  const ComposerEmojiPackThumb({
    super.key,
    required this.emojiKey,
    required this.onTap,
    this.locale,
    this.padding = const EdgeInsets.all(4),
    this.decodeSize = 96,
  });

  final String emojiKey;
  final VoidCallback onTap;
  final String? locale;
  final EdgeInsets padding;
  final int decodeSize;

  @override
  Widget build(BuildContext context) {
    final path = PackAssetResolver.emojiPackAssetPath(emojiKey);
    return Tooltip(
      message: EmojiPackI18n.packLabel(emojiKey, locale: locale),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Padding(
            padding: padding,
            child: ComposerStaticAssetImage(
              assetPath: path,
              fit: BoxFit.contain,
              decodeSize: decodeSize,
              error: Center(
                child: Text(
                  EmojiPackI18n.packLabel(emojiKey, locale: locale),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: kit_sizes.FlareSizes.fontSizeXs,
                    color: kit_theme.FlareColors.of(context).textSecondary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
