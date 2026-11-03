import 'package:extended_text_field/extended_text_field.dart';
import 'package:flare_im/interface/widgets/composer/message_composer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('rich text toolbar toggles styles without inserting markdown', (
    tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: MessageComposer(
                conversationId: 'c1',
                initialText: 'flare link',
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('富文本'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('链接'));
    await tester.pumpAndSettle();

    final field = tester.widget<ExtendedTextField>(
      find.byType(ExtendedTextField),
    );
    expect(field.controller?.text, 'flare link');
  });
}
