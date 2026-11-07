import 'dart:async';

import 'package:flare_core_flutter_update_ui/flare_core_flutter_update_ui.dart'
    show FlareUpdateResourceScope, FlareUpdateScope;
import 'package:flare_im/application/providers/locale_provider.dart';
import 'package:flare_im/application/providers/service_providers.dart';
import 'package:flare_im/application/providers/update_provider.dart';
import 'package:flare_im/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Starts the update center and hands it to every page, with this run's
/// resource packs over the Kit's built-in resources. It starts once the SDK is
/// initialized, not at sign-in: a build the server refuses has to offer the
/// update before anyone can sign in.
class UpdateHost extends ConsumerStatefulWidget {
  const UpdateHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<UpdateHost> createState() => _UpdateHostState();
}

class _UpdateHostState extends ConsumerState<UpdateHost> {
  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  /// A failed init is the sign-in page's to explain; signing in starts the
  /// update center too.
  Future<void> _start() async {
    try {
      await ref.read(sdkReadyProvider)();
    } catch (error) {
      debugPrint('Update center not started: ${error.runtimeType}');
      return;
    }
    if (mounted) ref.read(updateControllerProvider).install();
  }

  @override
  Widget build(BuildContext context) {
    final controller = ref.watch(updateControllerProvider);
    return FlareUpdateResourceScope(
      controller: controller,
      locale: ref.watch(flareLocaleProvider).code,
      materialTheme: AppTheme.material,
      child: FlareUpdateScope(controller: controller, child: widget.child),
    );
  }
}
