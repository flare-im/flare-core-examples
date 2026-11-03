import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart' as core;
import 'package:flare_im/domain/entities/user.dart';
import 'package:flare_im/domain/repositories/i_auth_repository.dart';
import 'package:flare_im/domain/value_objects/conversation_type.dart';
import 'package:flare_im/domain/value_objects/transport_mode.dart';
import 'package:flare_im/infrastructure/sdk/flare_core_sdk_wrapper.dart';

class AuthRepositoryImpl implements IAuthRepository {
  final SdkWrapper _sdk;

  AuthRepositoryImpl(this._sdk);

  @override
  bool get isSdkInitialized => _sdk.isInitialized;

  @override
  Future<void> initSdk({
    required String wsUrl,
    required SdkTransportMode transportMode,
    required String quicUrl,
    required String tenantId,
    required String httpUrl,
    String? tlsCaCertPath,
    String? tlsCaCert,
    String? dataUrl,
  }) async {
    await _sdk.init(
      SdkConfig(
        wsUrl: wsUrl,
        transportMode: transportMode,
        quicUrl: quicUrl,
        tlsCaCertPath: tlsCaCertPath,
        tlsCaCert: tlsCaCert,
        dataUrl: dataUrl,
        tenantId: tenantId,
        httpUrl: httpUrl,
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
  Future<ConnectionState> getConnectionState() async {
    if (!_sdk.isInitialized) return ConnectionState.disconnected;
    final state = await _sdk.getConnectionState();
    switch (state) {
      case core.ConnectionState.connecting:
        return ConnectionState.connecting;
      case core.ConnectionState.connected:
      case core.ConnectionState.ready:
        return ConnectionState.connected;
      case core.ConnectionState.reconnecting:
        return ConnectionState.reconnecting;
      case core.ConnectionState.disconnected:
        return ConnectionState.disconnected;
    }
  }

  @override
  Future<String> sdkVersion() async {
    return _sdk.sdkVersionSync();
  }
}
