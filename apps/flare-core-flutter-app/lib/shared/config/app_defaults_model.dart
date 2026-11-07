/// 与 [assets/config/app_defaults.json] 结构一致；解析失败时使用 [AppDefaults.fallback]。
class LoginCopy {
  const LoginCopy({
    required this.brandTitle,
    required this.subtitle,
    required this.welcomeTitle,
    required this.welcomeSubtitle,
    required this.userIdLabel,
    required this.userIdPlaceholder,
    required this.userHintRow,
    required this.primaryButton,
    required this.footerPrimary,
    required this.footerSecondary,
  });

  /// 顶部品牌区大标题（如 flare IM）
  final String brandTitle;

  /// 品牌区副标题 / Slogan（渐变头上的说明文案）
  final String subtitle;
  final String welcomeTitle;
  final String welcomeSubtitle;
  final String userIdLabel;
  final String userIdPlaceholder;

  /// 输入框下方提示行（带信息图标）
  final String userHintRow;
  final String primaryButton;
  final String footerPrimary;
  final String footerSecondary;

  static LoginCopy fromJson(Map<String, dynamic>? json) {
    if (json == null) return LoginCopy.fallback;
    String s(String k, String d) =>
        (json[k] as String?)?.trim().isNotEmpty == true ? json[k] as String : d;
    return LoginCopy(
      brandTitle: s('brandTitle', LoginCopy.fallback.brandTitle),
      subtitle: s('subtitle', LoginCopy.fallback.subtitle),
      welcomeTitle: s('welcomeTitle', LoginCopy.fallback.welcomeTitle),
      welcomeSubtitle: s('welcomeSubtitle', LoginCopy.fallback.welcomeSubtitle),
      userIdLabel: s('userIdLabel', LoginCopy.fallback.userIdLabel),
      userIdPlaceholder: s(
        'userIdPlaceholder',
        LoginCopy.fallback.userIdPlaceholder,
      ),
      userHintRow: s('userHintRow', LoginCopy.fallback.userHintRow),
      primaryButton: s('primaryButton', LoginCopy.fallback.primaryButton),
      footerPrimary: s('footerPrimary', LoginCopy.fallback.footerPrimary),
      footerSecondary: s('footerSecondary', LoginCopy.fallback.footerSecondary),
    );
  }

  static const LoginCopy fallback = LoginCopy(
    brandTitle: 'flare IM',
    subtitle: '安全、快速的即时通讯',
    welcomeTitle: '欢迎回来',
    welcomeSubtitle: '请输入您的用户 ID 完成登录',
    userIdLabel: '用户 ID',
    userIdPlaceholder: '请输入您的用户 ID',
    userHintRow: '用户 ID 由系统分配，可在账号设置中查看',
    primaryButton: '立即登录',
    footerPrimary: 'ID 由管理员分配，可在邀请邮件中查看',
    footerSecondary: '仅支持 ID 登录 · 安全连接已启用',
  );
}

/// 应用的非地址默认值。连哪套服务（接入配置与令牌端点）是构建期配置，见
/// `access_config.dart`。
class AppDefaults {
  const AppDefaults({
    required this.defaultTlsCaCertPath,
    required this.defaultTlsCaCert,
    required this.tenantId,
    required this.defaultUserId,
    required this.login,
  });

  /// 私有部署的信任 CA 文件路径，FLARE_TLS_CA_CERT_PATH / defaultTlsCaCertPath。
  final String defaultTlsCaCertPath;

  /// 内联信任 CA（PEM 或 base64 DER），FLARE_TLS_CA_CERT / defaultTlsCaCert。
  final String defaultTlsCaCert;
  final String tenantId;
  final String defaultUserId;
  final LoginCopy login;

  /// 未配置密钥时的占位值。见 [fallback] 里的说明。

  /// 当前密钥是否仍是占位值 —— 调用方应据此拒绝签发 token 并提示配置。

  static const AppDefaults fallback = AppDefaults(
    defaultTlsCaCertPath: '',
    defaultTlsCaCert: '',
    tenantId: '0',
    // 这里刻意放**占位串**而不是一个能用的密钥。
    //
    // 之前这里写的是某台开发机 logs/.dev-token-secret 里的真实值：它长得像正规
    // 密钥，没人会意识到要换，而它一旦随仓库公开，任何仍在用这个值的服务端都能
    // 被伪造 token。占位串换来的是启动时一次明确的失败，比一个"能跑但不安全"
    // 的默认值好。
    //
    // 本机的真实值在 flare-core-server/logs/.dev-token-secret（起后端时生成），
    // 或用 --dart-define=FLARE_TOKEN_SECRET=... 传入。
    defaultUserId: '',
    login: LoginCopy.fallback,
  );

  static AppDefaults fromJson(Map<String, dynamic> json) {
    const envTlsCaCertPath = String.fromEnvironment('FLARE_TLS_CA_CERT_PATH');
    const envTlsCaCert = String.fromEnvironment('FLARE_TLS_CA_CERT');
    final tlsCaCertPath = _firstNonEmpty([
      envTlsCaCertPath,
      json['defaultTlsCaCertPath'],
      json['tlsCaCertPath'],
    ]);
    final tenant = (json['tenantId'] as String?)?.trim();
    final userId = (json['userId'] as String?)?.trim();
    final loginJson = json['login'] as Map<String, dynamic>?;
    return AppDefaults(
      defaultTlsCaCertPath: tlsCaCertPath ?? fallback.defaultTlsCaCertPath,
      defaultTlsCaCert: _firstNonEmpty([envTlsCaCert, json['defaultTlsCaCert'], json['tlsCaCert']]) ?? fallback.defaultTlsCaCert,
      tenantId: (tenant != null && tenant.isNotEmpty)
          ? tenant
          : fallback.tenantId,
      defaultUserId: (userId != null && userId.isNotEmpty)
          ? userId
          : fallback.defaultUserId,
      login: LoginCopy.fromJson(loginJson),
    );
  }
}

String? _firstNonEmpty(Iterable<Object?> values) {
  for (final value in values) {
    final text = value?.toString().trim();
    if (text != null && text.isNotEmpty) return text;
  }
  return null;
}

