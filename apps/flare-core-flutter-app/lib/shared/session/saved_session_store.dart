import 'package:flare_im/domain/value_objects/transport_mode.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 热启动会话档案：登录成功后保存，下次启动免登录直接
/// prepare(本地库) → 本地出图 → 后台 connect。
/// dev token 由本地 secret 重新生成，无需持久化。
class SavedSessionProfile {
  final String userId;
  final String wsUrl;
  final SdkTransportMode transportMode;
  final String quicUrl;
  final String tlsCaCertPath;
  // httpUrl 即 SDK 托管 token 端点(auth.tokenEndpoint):resume 重连靠它向网关签发。
  // 不持久化则热启动回退默认地址,自定义网关登录后刷新会指错端点。
  final String httpUrl;

  const SavedSessionProfile({
    required this.userId,
    required this.wsUrl,
    required this.transportMode,
    required this.quicUrl,
    required this.tlsCaCertPath,
    this.httpUrl = '',
  });
}

class SavedSessionStore {
  static const _kUserId = 'flare.savedSession.userId';
  static const _kWsUrl = 'flare.savedSession.wsUrl';
  static const _kTransportMode = 'flare.savedSession.transportMode';
  static const _kQuicUrl = 'flare.savedSession.quicUrl';
  static const _kTlsCaCertPath = 'flare.savedSession.tlsCaCertPath';
  static const _kHttpUrl = 'flare.savedSession.httpUrl';

  static Future<void> save(SavedSessionProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserId, profile.userId);
    await prefs.setString(_kWsUrl, profile.wsUrl);
    await prefs.setString(_kTransportMode, profile.transportMode.name);
    await prefs.setString(_kQuicUrl, profile.quicUrl);
    await prefs.setString(_kTlsCaCertPath, profile.tlsCaCertPath);
    await prefs.setString(_kHttpUrl, profile.httpUrl);
  }

  static Future<SavedSessionProfile?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = (prefs.getString(_kUserId) ?? '').trim();
    if (userId.isEmpty) return null;
    final transportName = prefs.getString(_kTransportMode) ?? '';
    final transportMode = SdkTransportMode.values.firstWhere(
      (mode) => mode.name == transportName,
      orElse: () => SdkTransportMode.websocket,
    );
    return SavedSessionProfile(
      userId: userId,
      wsUrl: (prefs.getString(_kWsUrl) ?? '').trim(),
      transportMode: transportMode,
      quicUrl: (prefs.getString(_kQuicUrl) ?? '').trim(),
      tlsCaCertPath: (prefs.getString(_kTlsCaCertPath) ?? '').trim(),
      httpUrl: (prefs.getString(_kHttpUrl) ?? '').trim(),
    );
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserId);
    await prefs.remove(_kWsUrl);
    await prefs.remove(_kTransportMode);
    await prefs.remove(_kQuicUrl);
    await prefs.remove(_kTlsCaCertPath);
    await prefs.remove(_kHttpUrl);
  }
}
