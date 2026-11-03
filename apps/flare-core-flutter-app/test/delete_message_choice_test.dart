import 'package:flare_im/interface/widgets/message/message_long_press_menu.dart';
import 'package:flare_im/shared/i18n/flare_locale.dart';
import 'package:flare_im/shared/i18n/flare_messages.dart';
import 'package:flare_im_ui/flare_im_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// 删除消息的二选一走组件库的 FlareModal:标题命名路由,选项在正文里,取消是底部按钮。
void main() {
  final i18n = FlareMessages.of(FlareLocale.zhCn).chat;

  Future<BuildContext> pumpHost(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            captured = context;
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    );
    return captured;
  }

  testWidgets('the choice is a kit Modal; picking an option runs it', (
    tester,
  ) async {
    final ran = <String>[];
    final context = await pumpHost(tester);
    final done = showDeleteMessageChoiceDialog(
      context,
      i18n: i18n,
      showDeleteForEveryone: true,
      onDeleteForSelf: () async => ran.add('self'),
      onDeleteForEveryone: () async => ran.add('everyone'),
    );
    await tester.pumpAndSettle();
    expect(
      find.ancestor(
        of: find.text(i18n.menuDeleteSelf),
        matching: find.byType(FlareModal),
      ),
      findsOneWidget,
    );
    expect(find.text(i18n.menuDeleteMessage), findsOneWidget);
    expect(find.widgetWithText(FlareButton, i18n.cancel), findsOneWidget);

    await tester.tap(find.text(i18n.menuDeleteForAll));
    await tester.pumpAndSettle();
    await done;
    expect(ran, ['everyone']);
    expect(find.byType(FlareModal), findsNothing);
  });

  testWidgets('cancel closes it without deleting anything', (tester) async {
    final ran = <String>[];
    final context = await pumpHost(tester);
    final done = showDeleteMessageChoiceDialog(
      context,
      i18n: i18n,
      showDeleteForEveryone: false,
      onDeleteForSelf: () async => ran.add('self'),
      onDeleteForEveryone: () async => ran.add('everyone'),
    );
    await tester.pumpAndSettle();
    expect(find.text(i18n.menuDeleteForAll), findsNothing);
    await tester.tap(find.widgetWithText(FlareButton, i18n.cancel));
    await tester.pumpAndSettle();
    await done;
    expect(ran, isEmpty);
    expect(find.byType(FlareModal), findsNothing);
  });
}
