import 'dart:async';

import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart'
    show ConnectionStatus;
import 'package:flare_im/application/providers/sdk_provider.dart';
import 'package:flare_im/application/providers/service_providers.dart';
import 'package:flare_im/application/services/auth_service.dart';
import 'package:flare_im/domain/entities/user.dart';
import 'package:flare_im/infrastructure/paths/sdk_data_url.dart';
import 'package:flare_im/infrastructure/sdk/flare_core_sdk_wrapper.dart';
import 'package:flare_im/shared/config/app_config_loader.dart';
import 'package:flare_im/shared/session/saved_session_store.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 当前用户状态
final currentUserProvider = StateNotifierProvider<CurrentUserNotifier, User?>((
  ref,
) {
  final authService = ref.watch(authServiceProvider);
  return CurrentUserNotifier(authService);
});

class CurrentUserNotifier extends StateNotifier<User?> {
  final AuthService _authService;

  CurrentUserNotifier(this._authService) : super(null);

  /// 登录
  Future<void> login(String userId, [String? token]) async {
    final user = await _authService.login(userId, token);
    state = user;
  }

  /// 登出（同时清除热启动会话档案）。被踢或登录过期时服务端通常已经拒绝了这个会话，
  /// 登出请求可能失败，本地会话也照样清掉。
  Future<void> logout() async {
    await _clearSavedSessionQuietly();
    try {
      await _authService.logout();
    } finally {
      state = null;
    }
  }

  Future<void> _clearSavedSessionQuietly() async {
    try {
      await SavedSessionStore.clear();
    } catch (e) {
      debugPrint('saved session clear failed: $e');
    }
  }

  Future<bool>? _resumeInFlight;

  /// 热启动：本地会话档案存在时 prepare(开库) 直接本地出图，
  /// 连接与首次同步在后台补齐。成功返回 true，UI 可直进会话列表。
  Future<bool> resumeSavedSession() {
    if (state != null) return Future.value(true);
    return _resumeInFlight ??= _resumeSavedSessionInner().whenComplete(() {
      _resumeInFlight = null;
    });
  }

  Future<bool> _resumeSavedSessionInner() async {
    final SavedSessionProfile? profile;
    try {
      profile = await SavedSessionStore.load();
    } catch (e) {
      // 偏好存储不可用（如测试环境无插件）时按无档案处理，走登录页。
      debugPrint('saved session store unavailable: $e');
      return false;
    }
    if (profile == null) return false;
    final startedAt = DateTime.now();
    try {
      final defaults = await AppConfigLoader.load();
      final dataUrl = await resolveSdkDataUrl();
      await _authService.initSdk(
        tenantId: defaults.tenantId,
        tlsCaCertPath: defaults.defaultTlsCaCertPath,
        tlsCaCert: defaults.defaultTlsCaCert,
        dataUrl: dataUrl,
      );
      final user = await _authService.prepareLocalSession(profile.userId);
      state = user;
      debugPrint(
        'session resume local ready in '
        '${DateTime.now().difference(startedAt).inMilliseconds}ms',
      );
      unawaited(_connectResumedSessionInBackground(profile.userId));
      return true;
    } catch (e) {
      debugPrint('session resume failed: $e');
      await _clearSavedSessionQuietly();
      state = null;
      return false;
    }
  }

  Future<void> _connectResumedSessionInBackground(String userId) async {
    try {
      // 不传 token：SDK 向网关签发并自动刷新（应用托管形态由登录页显式传 token）。
      await _authService.connectSession(userId);
      debugPrint('session resume connected');
    } catch (e) {
      // 没网等链路能自己恢复的失败核心按成功返回，走不到这里；这里只有终态错误。本地视图照常可用，
      // 连接状态由 Kit 横幅（connection://status）呈现。
      debugPrint('session resume connect failed (local view remains): $e');
    }
  }

  /// 刷新用户信息
  Future<void> refresh() async {
    final user = await _authService.getCurrentUser();
    state = user;
  }
}

/// 核心的连接状态（`connection://status`），每来一个就整体替换；SDK 还没上报时为 null。
/// 横幅交给 Kit 的 ConnectionNotice。
final connectionStatusProvider =
    StateNotifierProvider<ConnectionStatusNotifier, ConnectionStatus?>((ref) {
      return ConnectionStatusNotifier(ref.watch(sdkWrapperProvider));
    });

class ConnectionStatusNotifier extends StateNotifier<ConnectionStatus?> {
  ConnectionStatusNotifier(this._sdk) : super(null);

  final SdkWrapper _sdk;

  /// A `connection://status` event.
  void apply(ConnectionStatus status) => state = status;

  /// Reads the core's current status (events do not replay: a screen or a
  /// login that starts late begins from the truth).
  Future<void> refresh() async {
    if (!_sdk.isInitialized) return;
    try {
      state = await _sdk.connectionStatus();
    } catch (e) {
      debugPrint('connection status unavailable: $e');
    }
  }
}

/// 是否已登录
final isLoggedInProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user != null;
});
