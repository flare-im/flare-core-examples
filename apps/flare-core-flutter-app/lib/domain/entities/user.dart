import 'package:equatable/equatable.dart';

/// 用户实体
class User extends Equatable {
  final String userId;
  final String nickname;
  final String? avatar;
  final String? remark;
  final String? signature;
  final int? gender; // 0: 未知, 1: 男, 2: 女
  final String? phone;
  final String? email;
  final DateTime? birthday;
  final String? region;
  final Map<String, String> extra;

  const User({
    required this.userId,
    required this.nickname,
    this.avatar,
    this.remark,
    this.signature,
    this.gender,
    this.phone,
    this.email,
    this.birthday,
    this.region,
    this.extra = const {},
  });

  factory User.fromCore(Map<String, Object?> core) {
    return User.fromCoreMap(core);
  }

  /// 从 Core SDK 下行的用户/在线状态 Map 构造领域用户。
  ///
  /// 当前 Core Flutter 绑定的 presence 查询返回 JSON Map，示例 App 在领域层只保留
  /// 稳定用户资料字段；未知字段进入 [extra] 作为扩展信息。
  factory User.fromCoreMap(Map<String, Object?> core) {
    final userId = _firstString(core, const ['userId', 'id', 'uid']);
    final nickname = _firstString(core, const [
      'nickname',
      'nickName',
      'displayName',
      'name',
      'username',
      'userName',
    ]);
    final avatar = _firstStringOrNull(core, const [
      'avatar',
      'avatarUrl',
      'portrait',
    ]);
    return User(
      userId: userId,
      nickname: nickname.isEmpty ? userId : nickname,
      avatar: avatar,
      remark: _firstStringOrNull(core, const ['remark', 'alias']),
      signature: _firstStringOrNull(core, const ['signature', 'bio']),
      gender: _firstIntOrNull(core, const ['gender', 'sex']),
      phone: _firstStringOrNull(core, const ['phone', 'mobile']),
      email: _firstStringOrNull(core, const ['email']),
      birthday: _firstDateTimeOrNull(core, const ['birthday', 'birthdate']),
      region: _firstStringOrNull(core, const ['region', 'location']),
      extra: _stringExtra(core),
    );
  }

  @override
  List<Object?> get props => [userId];

  /// 获取显示名称（优先使用备注）
  String get displayName => remark ?? nickname;

  /// 复制并更新
  User copyWith({
    String? userId,
    String? nickname,
    String? avatar,
    String? remark,
    String? signature,
    int? gender,
    String? phone,
    String? email,
    DateTime? birthday,
    String? region,
    Map<String, String>? extra,
  }) {
    return User(
      userId: userId ?? this.userId,
      nickname: nickname ?? this.nickname,
      avatar: avatar ?? this.avatar,
      remark: remark ?? this.remark,
      signature: signature ?? this.signature,
      gender: gender ?? this.gender,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      birthday: birthday ?? this.birthday,
      region: region ?? this.region,
      extra: extra ?? this.extra,
    );
  }

  static String _firstString(Map<String, Object?> map, List<String> keys) {
    return _firstStringOrNull(map, keys) ?? '';
  }

  static String? _firstStringOrNull(
    Map<String, Object?> map,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = map[key];
      if (value == null) continue;
      final text = value.toString().trim();
      if (text.isNotEmpty) return text;
    }
    return null;
  }

  static int? _firstIntOrNull(Map<String, Object?> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is int) return value;
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value.trim());
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  static DateTime? _firstDateTimeOrNull(
    Map<String, Object?> map,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = map[key];
      if (value is int && value > 0) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      if (value is num && value > 0) {
        return DateTime.fromMillisecondsSinceEpoch(value.toInt());
      }
      if (value is String && value.trim().isNotEmpty) {
        final parsed = DateTime.tryParse(value.trim());
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  static Map<String, String> _stringExtra(Map<String, Object?> map) {
    final extra = <String, String>{};
    for (final entry in map.entries) {
      final value = entry.value;
      if (value == null) continue;
      if (value is Map || value is Iterable) continue;
      extra[entry.key] = value.toString();
    }
    return extra;
  }
}
