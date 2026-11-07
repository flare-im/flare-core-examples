import 'package:flare_core_flutter_update_ui/flare_core_flutter_update_ui.dart'
    show flutterAppConfig;
import 'package:flare_im/domain/entities/user.dart';
import 'package:flare_im/domain/repositories/i_auth_repository.dart';
import 'package:flare_im/infrastructure/sdk/flare_core_sdk_wrapper.dart';
import 'package:flare_im/shared/config/access_config.dart';

class AuthRepositoryImpl implements IAuthRepository {
  final SdkWrapper _sdk;

  /// The language the app shows: update notes follow it, not the system's.
  final String? Function()? _locale;

  AuthRepositoryImpl(this._sdk, {String? Function()? locale}) : _locale = locale;

  @override
  bool get isSdkInitialized => _sdk.isInitialized;

  @override
  Future<void> initSdk({
    required String tenantId,
    String? tlsCaCertPath,
    String? tlsCaCert,
    String? dataUrl,
  }) async {
    await _sdk.init(
      SdkConfig(
        access: resolveAccessConfig(),
        app: flutterAppConfig(locale: _locale?.call()),
        tlsCaCertPath: tlsCaCertPath,
        tlsCaCert: tlsCaCert,
        dataUrl: dataUrl,
        tenantId: tenantId,
      ),
    );
  }

  @override
  Future<User> login(String userId, [String? token]) async {
    await _sdk.login(userId, token);
    return User(userId: userId, nickname: userId);
  }

  @override
  Future<User> prepareLocalSession(String userId) async {
    await _sdk.prepareLocal(userId);
    return User(userId: userId, nickname: userId);
  }

  @override
  Future<void> connectSession(String userId, [String? token]) {
    return _sdk.connectRemote(userId, token);
  }

  @override
  Future<void> logout() async {
    if (_sdk.isInitialized) {
      await _sdk.logout();
    }
  }

  @override
  Future<User?> getCurrentUser() async {
    if (!_sdk.isInitialized) return null;
    final id = await _sdk.currentUserId();
    if (id.isEmpty) return null;
    return User(userId: id, nickname: id);
  }

  @override
  Future<String> sdkVersion() async {
    return _sdk.sdkVersionSync();
  }
}
