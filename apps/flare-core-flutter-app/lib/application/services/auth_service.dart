import 'package:flare_im/domain/entities/user.dart';
import 'package:flare_im/domain/repositories/i_auth_repository.dart';

class AuthService {
  final IAuthRepository _repo;

  AuthService(this._repo);

  bool get isSdkInitialized => _repo.isSdkInitialized;

  Future<void> initSdk({
    required String tenantId,
    String? tlsCaCertPath,
    String? tlsCaCert,
    String? dataUrl,
  }) => _repo.initSdk(
    tenantId: tenantId,
    tlsCaCertPath: tlsCaCertPath,
    tlsCaCert: tlsCaCert,
    dataUrl: dataUrl,
  );

  Future<User> login(String userId, [String? token]) => _repo.login(userId, token);

  /// 本地半段登录（热启动本地出图）。
  Future<User> prepareLocalSession(String userId) =>
      _repo.prepareLocalSession(userId);

  /// 网络半段（热启动后台建连）。
  Future<void> connectSession(String userId, [String? token]) =>
      _repo.connectSession(userId, token);

  Future<void> logout() => _repo.logout();

  Future<User?> getCurrentUser() => _repo.getCurrentUser();

  Future<String> sdkVersion() => _repo.sdkVersion();
}
