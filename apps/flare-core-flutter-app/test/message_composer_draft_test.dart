import 'package:flare_im/interface/widgets/composer/draft_idle_scheduler.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('saves non-empty draft after five idle seconds', (tester) async {
    final drafts = <String>[];
    final scheduler = _scheduler(drafts.add);

    scheduler.schedule('hello');
    await tester.pump(const Duration(seconds: 4, milliseconds: 999));
    expect(drafts, isEmpty);

    await tester.pump(const Duration(milliseconds: 1));
    expect(drafts, ['hello']);
    scheduler.dispose();
  });

  testWidgets('editing before the idle window resets draft save', (
    tester,
  ) async {
    final drafts = <String>[];
    final scheduler = _scheduler(drafts.add);

    scheduler.schedule('hel');
    await tester.pump(const Duration(seconds: 4));
    scheduler.schedule('hello');
    await tester.pump(const Duration(seconds: 4, milliseconds: 999));
    expect(drafts, isEmpty);

    await tester.pump(const Duration(milliseconds: 1));
    expect(drafts, ['hello']);
    scheduler.dispose();
  });

  testWidgets('sending cancels pending draft save', (tester) async {
    final drafts = <String>[];
    final scheduler = _scheduler(drafts.add);

    scheduler.schedule('hello');
    await tester.pump(const Duration(seconds: 4));
    scheduler.cancel();
    await tester.pump(const Duration(seconds: 5));

    expect(drafts, isEmpty);
    scheduler.dispose();
  });

  testWidgets('flush saves pending draft immediately before idle delay', (
    tester,
  ) async {
    final drafts = <String>[];
    final scheduler = _scheduler(drafts.add);

    scheduler.schedule('hello');
    await tester.pump(const Duration(seconds: 1));
    scheduler.flush();
    expect(drafts, ['hello']);

    await tester.pump(const Duration(seconds: 5));
    expect(drafts, ['hello']);
    scheduler.dispose();
  });

  testWidgets('empty content is not saved as draft', (tester) async {
    final drafts = <String>[];
    final scheduler = _scheduler(drafts.add);

    scheduler.schedule('   ');
    await tester.pump(const Duration(seconds: 5));

    expect(drafts, isEmpty);
    scheduler.dispose();
  });
}

DraftIdleScheduler _scheduler(void Function(String text) onSave) =>
    DraftIdleScheduler(delay: const Duration(seconds: 5), onSave: onSave);
