import 'dart:async';

import 'package:flare_im/application/providers/service_providers.dart';
import 'package:flare_im/application/services/auth_service.dart';
import 'package:flare_im/domain/entities/user.dart';
import 'package:flare_im/domain/value_objects/conversation_type.dart';
import 'package:flare_im/infrastructure/paths/sdk_data_url.dart';
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

  /// 登出（同时清除热启动会话档案）
  Future<void> logout() async {
    await _clearSavedSessionQuietly();
    await _authService.logout();
    state = null;
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
        wsUrl: profile.wsUrl.isNotEmpty ? profile.wsUrl : defaults.defaultWsUrl,
        transportMode: profile.transportMode,
        quicUrl: profile.quicUrl.isNotEmpty
            ? profile.quicUrl
            : defaults.defaultQuicUrl,
        tenantId: defaults.tenantId,
        httpUrl: profile.httpUrl.isNotEmpty ? profile.httpUrl : defaults.httpUrl,
        tlsCaCertPath: profile.tlsCaCertPath.isNotEmpty
            ? profile.tlsCaCertPath
            : defaults.defaultTlsCaCertPath,
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
      // 离线也保持本地视图可用；连接状态由 connection watcher 呈现。
      debugPrint('session resume connect failed (local view remains): $e');
    }
  }

  /// 刷新用户信息
  Future<void> refresh() async {
    final user = await _authService.getCurrentUser();
    state = user;
  }
}

/// 连接状态
final connectionStateProvider =
    StateNotifierProvider<ConnectionStateNotifier, ConnectionState>((ref) {
      final authService = ref.watch(authServiceProvider);
      return ConnectionStateNotifier(authService);
    });

class ConnectionStateNotifier extends StateNotifier<ConnectionState> {
  final AuthService _authService;

  ConnectionStateNotifier(this._authService)
    : super(ConnectionState.disconnected);

  /// 刷新连接状态
  Future<void> refresh() async {
    final state = await _authService.getConnectionState();
    this.state = state;
  }
}

/// 是否已登录
final isLoggedInProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider);
  return user != null;
});
