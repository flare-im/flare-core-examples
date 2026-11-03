import 'package:flare_im/domain/entities/user.dart';
import 'package:flare_im/domain/value_objects/conversation_type.dart';
import 'package:flare_im/domain/value_objects/transport_mode.dart';

abstract class IAuthRepository {
  /// 幂等初始化原生 SDK（示例登录前调用；具体 URL 由 UI 传入，不依赖 FFI 类型泄漏到 interface）。
  Future<void> initSdk({
    required String wsUrl,
    required SdkTransportMode transportMode,
    required String quicUrl,
    required String tenantId,
    required String httpUrl,
    String? tlsCaCertPath,
    String? tlsCaCert,
    String? dataUrl,
  });

  bool get isSdkInitialized;

  Future<User> login(String userId, [String? token]);

  /// 本地半段登录：开库 + 装配引擎，不连网 — 热启动本地出图用。
  Future<User> prepareLocalSession(String userId);

  /// 网络半段：建立连接并完成首次同步（热启动在后台调用）。
  Future<void> connectSession(String userId, [String? token]);

  /// 调用 `flare_sdk_logout`，不释放 SDK 句柄
  Future<void> logout();

  Future<User?> getCurrentUser();

  Future<ConnectionState> getConnectionState();

  Future<String> sdkVersion();
}
