import 'package:flare_im/application/providers/access_diagnostics_provider.dart';
import 'package:flare_im/interface/router/app_router.dart';
import 'package:flare_im/interface/widgets/recovery_link_host.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

final class _RecordingDiagnostics extends AccessDiagnosticsController {
  _RecordingDiagnostics()
    : super(
        access: () async => throw UnimplementedError(),
        addEventListener: (_) => throw UnimplementedError(),
      );

  final links = <String>[];

  @override
  Future<void> importRecovery(String link) async => links.add(link);
}

void main() {
  Future<_RecordingDiagnostics> pumpHost(
    WidgetTester tester,
    List<String> launchArguments,
  ) async {
    final diagnostics = _RecordingDiagnostics();
    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const Text('home'),
        ),
        GoRoute(
          path: '/network',
          builder: (context, state) => const Text('network'),
        ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          accessDiagnosticsProvider.overrideWith((ref) => diagnostics),
          appRouterProvider.overrideWithValue(router),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          builder: (context, child) => RecoveryLinkHost(
            launchArguments: launchArguments,
            child: child!,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return diagnostics;
  }

  testWidgets('a launch link is imported and opens the network page', (
    tester,
  ) async {
    final diagnostics = await pumpHost(tester, const [
      '--flag',
      'flare-recover://v1?p=a&k=b&s=c',
    ]);

    expect(diagnostics.links, ['flare-recover://v1?p=a&k=b&s=c']);
    expect(find.text('network'), findsOneWidget);
  });

  testWidgets('other arguments leave the app where it is', (tester) async {
    final diagnostics = await pumpHost(tester, const ['--flag']);

    expect(diagnostics.links, isEmpty);
    expect(find.text('home'), findsOneWidget);
  });
}
