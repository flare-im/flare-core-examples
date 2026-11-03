import 'package:flare_im/application/providers/auth_state_provider.dart';
import 'package:flare_im/application/providers/sdk_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sdk_runtime_provider.freezed.dart';

@freezed
class SdkRuntimeSnapshot with _$SdkRuntimeSnapshot {
  const factory SdkRuntimeSnapshot({
    @Default(false) bool loading,
    @Default(<String, Object?>{}) Map<String, Object?> diagnostics,
    @Default(<String, Object?>{}) Map<String, Object?> capabilities,
    @Default(<String, Object?>{}) Map<String, Object?> userCapabilities,
    @Default(<String, Object?>{}) Map<String, Object?> mediaCache,
    String? error,
  }) = _SdkRuntimeSnapshot;
}

final sdkRuntimeProvider =
    StateNotifierProvider<SdkRuntimeNotifier, SdkRuntimeSnapshot>((ref) {
      return SdkRuntimeNotifier(ref);
    });

class SdkRuntimeNotifier extends StateNotifier<SdkRuntimeSnapshot> {
  SdkRuntimeNotifier(this._ref) : super(const SdkRuntimeSnapshot());

  final Ref _ref;

  Future<void> refresh() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final sdk = _ref.read(sdkWrapperProvider);
      final userId = _ref.read(currentUserProvider)?.userId ?? '';
      final diagnostics = await sdk.diagnosticsSnapshot();
      final capabilities = await sdk.listCapabilities();
      final userCapabilities = userId.isEmpty
          ? <String, Object?>{}
          : await sdk.listUserCapabilities(userId);
      final mediaCache = await sdk.mediaCacheStats();
      state = state.copyWith(
        loading: false,
        diagnostics: diagnostics,
        capabilities: capabilities,
        userCapabilities: userCapabilities,
        mediaCache: mediaCache,
      );
    } catch (error) {
      state = state.copyWith(loading: false, error: '$error');
    }
  }

  Future<void> clearMediaCache() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final sdk = _ref.read(sdkWrapperProvider);
      await sdk.clearMediaCache();
      final mediaCache = await sdk.mediaCacheStats();
      state = state.copyWith(loading: false, mediaCache: mediaCache);
    } catch (error) {
      state = state.copyWith(loading: false, error: '$error');
    }
  }
}
