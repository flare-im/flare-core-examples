import 'package:shared_preferences/shared_preferences.dart';

/// 热启动会话档案：登录成功后保存，下次启动免登录直接
/// prepare(本地库) → 本地出图 → 后台 connect。
/// 连哪套服务是构建期的接入配置，不随会话保存；token 由 SDK 托管签发，也无需持久化。
class SavedSessionProfile {
  final String userId;

  const SavedSessionProfile({required this.userId});
}

class SavedSessionStore {
  static const _kUserId = 'flare.savedSession.userId';

  static Future<void> save(SavedSessionProfile profile) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUserId, profile.userId);
  }

  static Future<SavedSessionProfile?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final userId = (prefs.getString(_kUserId) ?? '').trim();
    if (userId.isEmpty) return null;
    return SavedSessionProfile(userId: userId);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kUserId);
  }
}
