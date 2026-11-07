import 'dart:async';

import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart' as core;
import 'package:flare_core_flutter_update_ui/flare_core_flutter_update_ui.dart'
    show flutterUpdateController;
import 'package:flare_im/application/providers/auth_state_provider.dart';
import 'package:flare_im/application/providers/locale_provider.dart';
import 'package:flare_im/application/providers/sdk_provider.dart';
import 'package:flare_im/application/providers/service_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The update center, one for the app. [UpdateHost] starts it once the SDK is
/// initialized; a signed-in session also starts it, in case that first init
/// failed.
final updateControllerProvider = Provider<core.FlareUpdateController>((ref) {
  final sdk = ref.watch(sdkWrapperProvider);
  final ready = ref.watch(sdkReadyProvider);
  final controller = flutterUpdateController(
    core.FlareClientUpdateEngine(
      update: () async {
        await ready();
        return sdk.update;
      },
      addEventListener: sdk.addEventListener,
    ),
    onError: (error, _) => debugPrint('[update] ${error.runtimeType}'),
  );
  ref.listen(isLoggedInProvider, (_, loggedIn) {
    if (!loggedIn) return;
    controller
      ..install()
      ..onLoginSucceeded();
  });
  // The language read back at start can land after the first init, and the
  // person can change it at any time. The notes follow at once.
  ref.listen(flareLocaleProvider, (_, locale) {
    unawaited(controller.setLocale(locale.code));
  });
  ref.onDispose(() => unawaited(controller.dispose()));
  return controller;
});
