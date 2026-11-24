import 'dart:async';

import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart' as core;
import 'package:flare_core_flutter_update/flare_core_flutter_update.dart';
import 'package:flare_im/application/providers/locale_provider.dart';
import 'package:flare_im/infrastructure/sdk/flare_core_sdk_wrapper.dart';
import 'package:flare_im/interface/router/app_router.dart';
import 'package:flare_im/interface/widgets/composer/message_composer.dart';
import 'package:flare_im/shared/i18n/flare_locale.dart';
import 'package:flare_im_ui/flare_im_ui.dart'
    show FlareComposer, FlareStrings, flareStringsEnglish;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('one prompt host stands over every route', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    final routes = container.read(appRouterProvider).configuration.routes;
    final pages = routes.whereType<ShellRoute>().single.routes;

    expect(
      pages.whereType<GoRoute>().map((route) => route.path),
      containsAll(['/login', '/about']),
    );
    expect(pages.whereType<ShellRoute>(), hasLength(1));
    expect(routes.whereType<GoRoute>().map((route) => route.path), ['/']);
  });

  test('the Kit speaks the language the app shows', () {
    expect(kitStringsFor(FlareLocale.enUs), same(flareStringsEnglish));
    expect(
      kitStringsFor(FlareLocale.zhCn).updatePromptLater,
      const FlareStrings().updatePromptLater,
    );
  });

  group('the init overlay', () {
    test('the sign-in, a resumed session and the update center share one '
        'client', () async {
      var created = 0;
      final gate = Completer<void>();
      final sdk = SdkWrapper(
        createClient: (config) async {
          created += 1;
          await gate.future;
          return _FakeClient(_Events());
        },
      );
      const config = SdkConfig(endpoints: {'baseUrl': 'http://127.0.0.1:50050', 'websocketUrl': 'ws://127.0.0.1:60051'});

      final first = sdk.init(config);
      final second = sdk.init(config);
      await Future<void>.delayed(Duration.zero);
      gate.complete();
      await Future.wait([first, second]);

      expect(created, 1);
    });

    test('a failed init does not hold back the next one', () async {
      var created = 0;
      final sdk = SdkWrapper(
        createClient: (config) async {
          created += 1;
          if (created == 1) throw StateError('no library');
          return _FakeClient(_Events());
        },
      );
      const config = SdkConfig(endpoints: {'baseUrl': 'http://127.0.0.1:50050', 'websocketUrl': 'ws://127.0.0.1:60051'});

      await expectLater(sdk.init(config), throwsStateError);
      await sdk.init(config);

      expect(sdk.isInitialized, isTrue);
    });

    test('prepare sends the app keys again: the core replaces `app` whole',
        () async {
      final sdk = SdkWrapper(
        createClient: (config) async => _FakeClient(_Events()),
      );

      await sdk.init(
        const SdkConfig(
          endpoints: {'baseUrl': 'http://127.0.0.1:50050', 'websocketUrl': 'ws://127.0.0.1:60051'},
          app: {'distribution': 'direct', 'locale': 'en-US'},
        ),
      );

      expect(sdk.lastInitConfigForTest?['app'], {
        'distribution': 'direct',
        'locale': 'en-US',
      });
    });

    test('nothing to say leaves `app` to the platform', () {
      const config = SdkConfig(endpoints: {'baseUrl': 'http://127.0.0.1:50050', 'websocketUrl': 'ws://127.0.0.1:60051'}, app: {});
      expect(config.toInitConfig().containsKey('app'), isFalse);
    });
  });

  testWidgets('read only turns the composer off and says why', (tester) async {
    final updates = FlareUpdateController(
      engine: const _ReadOnlyEngine(),
      installer: const _NoInstaller(),
    )..install();
    addTearDown(updates.dispose);

    await tester.pumpWidget(
      ProviderScope(
        child: FlareUpdateScope(
          controller: updates,
          child: const MaterialApp(
            home: Scaffold(
              body: Align(
                alignment: Alignment.bottomCenter,
                child: MessageComposer(
                  conversationId: 'c1',
                  composeTargetName: 'Ann',
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final composer = tester.widget<FlareComposer>(find.byType(FlareComposer));
    expect(composer.disabled, isTrue);
    expect(composer.placeholder, const FlareStrings().composerReadOnlyUpdate);
  });
}

final class _Events implements core.EventsApi {
  @override
  Future<Map<String, Object?>> subscribeEventsBatch(
    Map<String, Object?> request,
  ) async => {'subscription': 1};

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _FakeClient implements core.FlareImClient {
  _FakeClient(this.events);

  @override
  final core.EventsApi events;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _ReadOnlyEngine implements FlareUpdateEngine {
  const _ReadOnlyEngine();

  @override
  Future<Map<String, Object?>> dispatch(
    String operation, [
    Map<String, Object?> params = const {},
  ]) async => {
    'state': 'required',
    'release': null,
    'prompt': 'none',
    'readOnly': true,
  };

  @override
  Stream<Map<String, Object?>> stateEvents() =>
      const Stream<Map<String, Object?>>.empty();
}

final class _NoInstaller implements FlareUpdateInstaller {
  const _NoInstaller();

  @override
  Future<FlareUpdateInstallResult> execute(
    FlareUpdateInstallPlan plan,
  ) async =>
      const FlareUpdateInstallResult(FlareUpdateOutcome.completed);

  @override
  Future<bool> canPrompt(FlareUpdateRelease release) async => true;

  @override
  Stream<FlareUpdateHandoff> handoffs() =>
      const Stream<FlareUpdateHandoff>.empty();

  @override
  Future<FlareUpdateInstallResult> completeHandoff() async =>
      const FlareUpdateInstallResult(FlareUpdateOutcome.completed);
}
