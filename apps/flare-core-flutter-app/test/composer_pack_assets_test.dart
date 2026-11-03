import 'package:flare_im/infrastructure/media/composer_pack_assets.dart';
import 'package:flare_im/interface/widgets/message/emoji_plain_text_segments.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('emoji pack exposes strict lower snake protocol keys', (
    tester,
  ) async {
    await ComposerPackAssets.ensureLoaded();

    final keys = ComposerPackAssets.sortedEmojiKeys;
    expect(keys, contains('beaming_face_with_smiling_eyes'));
    expect(keys, contains('red_heart'));
    expect(keys.where((key) => key.contains('-')), isEmpty);
    expect(keys.where((key) => RegExp(r'[A-Z]').hasMatch(key)), isEmpty);
    expect(
      ComposerPackAssets.hasEmojiWebp('beaming_face_with_smiling_eyes'),
      isTrue,
    );
    expect(
      ComposerPackAssets.hasEmojiWebp('beaming_face_with_smiling_eyes-BxAw'),
      isFalse,
    );
  });

  testWidgets('plain text emoji parser resolves canonical pack keys', (
    tester,
  ) async {
    await ComposerPackAssets.ensureLoaded();

    final parts = splitPlainTextForEmojiDisplay(
      'hello [beaming_face_with_smiling_eyes]',
    );

    expect(
      parts.whereType<PlainEmojiPackSegment>().map((part) => part.key),
      contains('beaming_face_with_smiling_eyes'),
    );
  });
}
