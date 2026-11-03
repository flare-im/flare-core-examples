import 'dart:async';

import 'package:flare_im/infrastructure/sdk/flare_core_sdk_wrapper.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Process-wide SDK facade owned by Riverpod.
final sdkWrapperProvider = Provider<SdkWrapper>((ref) {
  final sdk = SdkWrapper();
  ref.onDispose(() => unawaited(sdk.dispose()));
  return sdk;
});
