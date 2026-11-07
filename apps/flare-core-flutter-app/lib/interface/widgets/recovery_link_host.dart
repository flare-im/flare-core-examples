import 'dart:async';

import 'package:flare_core_flutter_lifecycle/flare_core_flutter_lifecycle.dart'
    show flutterOpenedLinks;
import 'package:flare_im/application/providers/access_diagnostics_provider.dart';
import 'package:flare_im/interface/router/app_router.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Takes the recovery links macOS opens the app with, and the one Windows and
/// Linux start it with. On Android and iOS the engine hands them to the router,
/// whose redirect does the same.
class RecoveryLinkHost extends ConsumerStatefulWidget {
  const RecoveryLinkHost({
    super.key,
    this.launchArguments = const [],
    required this.child,
  });

  /// `main`'s arguments.
  final List<String> launchArguments;

  final Widget child;

  @override
  ConsumerState<RecoveryLinkHost> createState() => _RecoveryLinkHostState();
}

class _RecoveryLinkHostState extends ConsumerState<RecoveryLinkHost> {
  StreamSubscription<String>? _links;

  @override
  void initState() {
    super.initState();
    // After the first frame: a launch link comes at once, and the router has
    // to be up to take it. macOS keeps its link until someone listens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _links = flutterOpenedLinks(
        launchArguments: widget.launchArguments,
      ).listen(_open);
    });
  }

  @override
  void dispose() {
    unawaited(_links?.cancel());
    super.dispose();
  }

  void _open(String link) {
    final location = Uri.tryParse(link);
    final recovery = location == null ? null : recoveryLinkOf(location);
    if (recovery == null) return;
    unawaited(ref.read(accessDiagnosticsProvider).importRecovery(recovery));
    ref.read(appRouterProvider).go('/network');
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
