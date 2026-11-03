import 'package:flare_im/infrastructure/media/composer_static_asset_image.dart';
import 'package:flare_im/infrastructure/media/emoji_pack_i18n.dart';
import 'package:flare_im/infrastructure/media/pack_asset_resolver.dart';
import 'package:flare_im/infrastructure/media/plain_text_markdown_detect.dart';
import 'package:flare_im/interface/theme/flare_im_design.dart';
import 'package:flare_im/interface/widgets/message/emoji_plain_text_segments.dart';
import 'package:flare_im_ui/flare_im_ui.dart' as kit_sizes show FlareSizes;
import 'package:flare_im_ui/flare_im_ui.dart' as kit_theme show FlareColors;
import 'package:flutter/material.dart';

// 纯文本 + `[pack_key]` 行内表情（非 Markdown 才拆表情）。
///
/// * [plainTextEmojiInlineSpans]：拼进外层 `Text.rich`（如「昵称：」+ 摘要）。
/// * [PlainTextEmojiRich]：整段字符串的独立组件（转发摘要、链接说明等）。
/// * [buildPlainTextEmojiLayoutPlan]：聊天气泡内正文 + 行数测量（供 [TextView] 与送达状态并排）。

int plainTextEmojiLayoutLineCount(
  BuildContext context,
  InlineSpan span,
  double maxWidth,
) {
  if (!maxWidth.isFinite || maxWidth <= 0) return 1;
  final tp = TextPainter(
    text: span,
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    textAlign: TextAlign.start,
    maxLines: null,
    locale: Localizations.maybeLocaleOf(context),
  )..layout(maxWidth: maxWidth);
  final metrics = tp.computeLineMetrics();
  return metrics.isEmpty ? 1 : metrics.length;
}

/// 将 [text] 转为可嵌入 `Text.rich` 的片段（不含整段「单表情大图」分支，适合转发预览等）。
List<InlineSpan> plainTextEmojiInlineSpans(
  BuildContext context, {
  required String text,
  required TextStyle style,
  required Color secondaryForeground,
  double inlineEmojiEm = 1.72,
  String? localeTag,
}) {
  final locale =
      localeTag ?? Localizations.maybeLocaleOf(context)?.toLanguageTag();
  if (PlainTextMarkdownDetect.isMarkdown(text)) {
    return [TextSpan(text: text, style: style)];
  }
  final parts = splitPlainTextForEmojiDisplay(text);
  if (!plainTextHasEmojiOrUnknown(parts)) {
    return [TextSpan(text: text, style: style)];
  }
  final fontSize = style.fontSize ?? 14;
  final height = style.height ?? 1.2;
  final inlineSize = fontSize * inlineEmojiEm;
  final decode = (inlineSize * 2).round().clamp(64, 128);
  final unknownS = TextStyle(
    color: secondaryForeground,
    fontSize: fontSize,
    fontWeight: FontWeight.w500,
    height: height,
  );
  final spans = <InlineSpan>[];
  for (final p in parts) {
    if (p is PlainTextRunSegment) {
      if (p.text.isNotEmpty) spans.add(TextSpan(text: p.text, style: style));
    } else if (p is PlainEmojiPackSegment) {
      final path = PackAssetResolver.emojiPackAssetPath(p.key);
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: ComposerStaticAssetImage(
              assetPath: path,
              width: inlineSize,
              height: inlineSize,
              fit: BoxFit.contain,
              decodeSize: decode,
              error: Text(
                EmojiPackI18n.formatBracket(p.key, locale: locale),
                style: unknownS,
              ),
            ),
          ),
        ),
      );
    } else if (p is PlainEmojiUnknownSegment) {
      spans.add(
        TextSpan(
          text: EmojiPackI18n.formatBracket(p.key, locale: locale),
          style: unknownS,
        ),
      );
    }
  }
  return spans;
}

/// 聊天气泡内完整逻辑（含 Markdown 跳过拆表情、整段单 `[key]` 大图等）+ 行数测量。
({Widget body, int Function(double maxWidth) measureLines})
buildPlainTextEmojiLayoutPlan(
  BuildContext context, {
  required String text,
  required TextStyle textStyle,
  required Color secondaryForeground,
  double inlineEmojiEm = 1.72,
  String? localeTag,
  required double stickerLikeMaxSide,
  bool inlineOnly = false,
}) {
  final locale =
      localeTag ?? Localizations.maybeLocaleOf(context)?.toLanguageTag();
  final fontSize = textStyle.fontSize ?? FlareImDesign.messageBubbleFontSize;
  final textHeight = textStyle.height ?? FlareImDesign.messageBubbleTextHeight;
  final fg = textStyle.color ?? kit_theme.FlareColors.of(context).textPrimary;
  final base = TextStyle(fontSize: fontSize, height: textHeight);

  int plainLines(double w) => plainTextEmojiLayoutLineCount(
    context,
    TextSpan(text: text, style: textStyle),
    w,
  );

  if (PlainTextMarkdownDetect.isMarkdown(text)) {
    return (body: Text(text, style: textStyle), measureLines: plainLines);
  }

  if (!inlineOnly) {
    final lonePack = resolveLoneEmojiPackInText(text);
    if (lonePack != null) {
      return (
        body: SizedBox(
          width: stickerLikeMaxSide,
          height: stickerLikeMaxSide,
          child: Image.asset(
            PackAssetResolver.emojiPackAssetPath(lonePack.key),
            fit: BoxFit.contain,
            gaplessPlayback: true,
            errorBuilder: (context, error, stackTrace) => Text(
              EmojiPackI18n.formatBracket(lonePack.key, locale: locale),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: secondaryForeground,
                fontSize: kit_sizes.FlareSizes.fontSize4xl,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
        measureLines: (_) => 1,
      );
    }

    final loneUnknown = resolveLoneEmojiBracketUnknown(text);
    if (loneUnknown != null) {
      return (
        body: Text(
          EmojiPackI18n.formatBracket(loneUnknown.key, locale: locale),
          style: TextStyle(
            color: secondaryForeground,
            fontSize: kit_sizes.FlareSizes.fontSize4xl,
            fontWeight: FontWeight.w500,
          ),
        ),
        measureLines: (_) => 1,
      );
    }
  }

  final parts = splitPlainTextForEmojiDisplay(text);
  if (!plainTextHasEmojiOrUnknown(parts)) {
    return (body: Text(text, style: textStyle), measureLines: plainLines);
  }

  final spans = <InlineSpan>[];
  final measureSpans = <InlineSpan>[];
  final inlineSize = fontSize * inlineEmojiEm;
  final decode = (inlineSize * 2).round().clamp(64, 128);

  for (final p in parts) {
    if (p is PlainTextRunSegment) {
      if (p.text.isNotEmpty) {
        final s = TextStyle(color: fg, fontSize: fontSize, height: textHeight);
        spans.add(TextSpan(text: p.text, style: s));
        measureSpans.add(TextSpan(text: p.text, style: s));
      }
    } else if (p is PlainEmojiPackSegment) {
      final path = PackAssetResolver.emojiPackAssetPath(p.key);
      spans.add(
        WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: ComposerStaticAssetImage(
              assetPath: path,
              width: inlineSize,
              height: inlineSize,
              fit: BoxFit.contain,
              decodeSize: decode,
              error: Text(
                EmojiPackI18n.formatBracket(p.key, locale: locale),
                style: TextStyle(
                  color: secondaryForeground,
                  fontSize: kit_sizes.FlareSizes.fontSizeMd,
                  fontWeight: FontWeight.w500,
                  height: textHeight,
                ),
              ),
            ),
          ),
        ),
      );
      measureSpans.add(
        TextSpan(
          text: '■',
          style: base.copyWith(color: fg, fontWeight: FontWeight.w500),
        ),
      );
    } else if (p is PlainEmojiUnknownSegment) {
      final s = TextStyle(
        color: secondaryForeground,
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
        height: textHeight,
      );
      final t = EmojiPackI18n.formatBracket(p.key, locale: locale);
      spans.add(TextSpan(text: t, style: s));
      measureSpans.add(TextSpan(text: t, style: s));
    }
  }

  int richLines(double w) => plainTextEmojiLayoutLineCount(
    context,
    TextSpan(children: measureSpans),
    w,
  );

  return (
    body: Text.rich(TextSpan(children: spans), textAlign: TextAlign.start),
    measureLines: richLines,
  );
}

/// 独立展示一段含 `[pack_key]` 的正文（转发预览、合并详情、链接摘要等）。
class PlainTextEmojiRich extends StatelessWidget {
  final String text;
  final TextStyle style;
  final TextStyle? unknownBracketStyle;
  final double inlineEmojiEm;
  final TextAlign textAlign;
  final int? maxLines;
  final TextOverflow? overflow;

  /// `true`：不出现整段单表情大图，全部行内渲染（转发列表等）。
  final bool inlineOnly;

  const PlainTextEmojiRich({
    super.key,
    required this.text,
    required this.style,
    this.unknownBracketStyle,
    this.inlineEmojiEm = 1.72,
    this.textAlign = TextAlign.start,
    this.maxLines,
    this.overflow,
    this.inlineOnly = true,
  });

  @override
  Widget build(BuildContext context) {
    final secondaryColor =
        unknownBracketStyle?.color ??
        style.color?.withValues(alpha: 0.72) ??
        kit_theme.FlareColors.of(context).textSecondary;
    final ellipsize =
        overflow ?? (maxLines != null ? TextOverflow.ellipsis : null);

    if (!inlineOnly) {
      final plan = buildPlainTextEmojiLayoutPlan(
        context,
        text: text,
        textStyle: style,
        secondaryForeground: secondaryColor,
        inlineEmojiEm: inlineEmojiEm,
        stickerLikeMaxSide: FlareImDesign.messageStickerLikeAssetMaxSide,
        inlineOnly: false,
      );
      return plan.body;
    }

    if (PlainTextMarkdownDetect.isMarkdown(text)) {
      return Text(
        text,
        style: style,
        textAlign: textAlign,
        maxLines: maxLines,
        overflow: ellipsize,
      );
    }

    final spans = plainTextEmojiInlineSpans(
      context,
      text: text,
      style: style,
      secondaryForeground: secondaryColor,
      inlineEmojiEm: inlineEmojiEm,
    );

    return Text.rich(
      TextSpan(children: spans),
      textAlign: textAlign,
      maxLines: maxLines,
      overflow: ellipsize,
    );
  }
}
