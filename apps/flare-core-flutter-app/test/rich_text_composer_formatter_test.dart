import 'package:flare_im/interface/widgets/composer/rich_text_composer_formatter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('serializes active inline styles without mutating editor text', () {
    const formatting = RichComposerFormatting(
      inlineStyles: {
        RichComposerInlineStyle.bold,
        RichComposerInlineStyle.link,
      },
    );

    expect(
      RichComposerMarkdownSerializer.serialize('flare', formatting),
      '**[flare](https://)**',
    );
  });

  test('serializes block styles per paragraph', () {
    const formatting = RichComposerFormatting(
      blockStyle: RichComposerBlockStyle.orderedList,
    );

    expect(
      RichComposerMarkdownSerializer.serialize('one\ntwo', formatting),
      '1. one\n2. two',
    );
  });

  test('toggles a single block style like the iOS composer selection', () {
    const formatting = RichComposerFormatting();

    final heading = formatting.toggleBlock(RichComposerBlockStyle.heading);
    final quote = heading.toggleBlock(RichComposerBlockStyle.quote);
    final body = quote.toggleBlock(RichComposerBlockStyle.quote);

    expect(heading.blockStyle, RichComposerBlockStyle.heading);
    expect(quote.blockStyle, RichComposerBlockStyle.quote);
    expect(body.blockStyle, RichComposerBlockStyle.body);
  });
}
