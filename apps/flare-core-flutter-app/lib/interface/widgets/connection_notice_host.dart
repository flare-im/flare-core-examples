import 'dart:async' show unawaited;

import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart' as core;
import 'package:flare_core_flutter_update_ui/flare_core_flutter_update_ui.dart'
    show FlareUpdateScope;
import 'package:flare_im/application/providers/auth_state_provider.dart';
import 'package:flare_im/application/providers/im_outbound_provider.dart';
import 'package:flare_im/application/providers/sdk_provider.dart';
import 'package:flare_im_ui/flare_im_ui.dart'
    show
        FlareConnectionNotice,
        FlareConnectionPhase,
        FlareConnectionQuality,
        FlareConnectionStatus;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// The core's `connection://status` as the kit's connection notice takes it,
/// field for field (null before the SDK has reported one).
FlareConnectionStatus? kitConnectionStatus(core.ConnectionStatus? status) {
  if (status == null) return null;
  final quality = status.quality;
  return FlareConnectionStatus(
    phase: FlareConnectionPhase.values.byName(status.phase.name),
    quality: quality == null
        ? null
        : FlareConnectionQuality.values.byName(quality.name),
    nextRetryAt: status.nextRetryAt,
    attempt: status.attempt,
    reason: status.reason,
    developmentMode: status.developmentMode,
  );
}

/// The connection notice: the SDK status handed to the kit's
/// [FlareConnectionNotice] unchanged, which decides what shows, when, and
/// which action it offers. This widget only performs the actions: retry now
/// asks the core to reconnect; sign in again (kicked or expired) signs out
/// locally, even when the server already refused the session, and returns to
/// the login page; update now goes to the update center; diagnose opens the
/// network and line page.
class ConnectionNoticeHost extends ConsumerWidget {
  const ConnectionNoticeHost({super.key, this.padding = EdgeInsets.zero});

  /// Around the banner (nothing is drawn while it is hidden).
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(connectionStatusProvider);
    final updates = FlareUpdateScope.controllerOf(context);
    return Padding(
      padding: padding,
      child: FlareConnectionNotice(
        status: kitConnectionStatus(status),
        onRetry: () => _reconnectNow(ref),
        onSignIn: () => _signInAgain(context, ref),
        onUpdate: updates == null ? null : () => unawaited(updates.update()),
        onDiagnose: () => context.push('/network'),
      ),
    );
  }

  Future<void> _reconnectNow(WidgetRef ref) async {
    try {
      await ref.read(sdkWrapperProvider).reconnectNow();
    } catch (e) {
      // What happens next shows on the notice itself.
      debugPrint('reconnect now refused: $e');
    }
  }

  Future<void> _signInAgain(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(imOutboundProvider).authLogout();
    } catch (e) {
      debugPrint('sign out after the session ended failed: $e');
    }
    if (context.mounted) context.go('/login');
  }
}
