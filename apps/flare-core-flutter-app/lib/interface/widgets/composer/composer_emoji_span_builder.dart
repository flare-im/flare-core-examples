import 'package:extended_text_field/extended_text_field.dart';
import 'package:flare_im/infrastructure/media/composer_pack_assets.dart';
import 'package:flare_im/infrastructure/media/emoji_pack_i18n.dart';
import 'package:flare_im/infrastructure/media/pack_asset_resolver.dart';
import 'package:flutter/material.dart';

/// 与 [plainTextEmojiInlineSpans] / `TextView` 一致：`[pack_key]` → 行内 webp 或括号文案。
///
/// 供 [ExtendedTextField] 在输入框内渲染表情，底层文本仍为 `[drooling_face]` 等。
class ComposerEmojiSpanBuilder extends RegExpSpecialTextSpanBuilder {
  ComposerEmojiSpanBuilder({required this.inlineSize, this.localeTag});

  final double inlineSize;
  final String? localeTag;

  @override
  List<RegExpSpecialText> get regExps => [
    _EmojiPackBracketPattern(inlineSize, localeTag),
  ];
}

final class _EmojiPackBracketPattern extends RegExpSpecialText {
  _EmojiPackBracketPattern(this.inlineSize, this.localeTag);

  final double inlineSize;
  final String? localeTag;

  @override
  RegExp get regExp => RegExp(r'\[([a-z][a-z0-9_]*)\]');

  @override
  InlineSpan finishText(
    int start,
    Match match, {
    TextStyle? textStyle,
    SpecialTextGestureTapCallback? onTap,
  }) {
    final key = match.group(1)!;
    final full = match.group(0)!;
    if (ComposerPackAssets.hasEmojiWebp(key)) {
      final path = PackAssetResolver.emojiPackAssetPath(key);
      return ImageSpan(
        AssetImage(path),
        imageWidth: inlineSize,
        imageHeight: inlineSize,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        start: start,
        actualText: full,
      );
    }
    return SpecialTextSpan(
      text: EmojiPackI18n.formatBracket(key, locale: localeTag),
      actualText: full,
      start: start,
      style:
          textStyle?.copyWith(fontWeight: FontWeight.w500) ??
          TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: textStyle?.fontSize,
            height: textStyle?.height,
          ),
    );
  }
}
