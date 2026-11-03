import 'dart:async';

import 'package:flare_im/application/providers/im_outbound_provider.dart';
import 'package:flare_im/application/providers/locale_provider.dart';
import 'package:flare_im/domain/value_objects/transport_mode.dart';
import 'package:flare_im/infrastructure/paths/sdk_data_url.dart';
import 'package:flare_im/interface/screens/login/login_error_text.dart';
import 'package:flare_im/shared/config/app_config_loader.dart';
import 'package:flare_im/shared/config/app_defaults_model.dart';
import 'package:flare_im/shared/session/saved_session_store.dart';
import 'package:flare_im_ui/flare_im_ui.dart'
    show
        FlareColors,
        FlareSizes,
        FlareInput,
        FlareFormField,
        FlareSegmentedControl,
        FlareBrandLogo,
        FlareBrandLogoVariant;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// 登录页:统一登录规格 v2。视觉取自 kit 设计 token,**表单用 kit 组件搭建**
// (FlareFormField + FlareInput + FlareSegmentedControl,来自 flare_im_ui)。
// 字段:用户 ID + 协议三选(WebSocket/QUIC/竞速) + WebSocket URL + Gateway URL + QUIC URL。
// 不再有 access token / TLS 证书输入(SDK 托管:核心向 Gateway 签发并自动刷新;
// TLS CA 走默认配置)。功能/绑定保持不变,仅重做视觉与字段集。

/// 登录页专用布局常量(不属于通用 token 标尺的展示尺寸;四端保持同值)。
class _LoginSpec {
  static const double logoSize = 64;
  static const double buttonHeight = 48;
  static const double gridStep = 40;
  static const double formMaxWidth = 430;
  static const double titleSize = 24;
  static const double welcomeSize = 22;
}

/// 协议三选顺序(与 FlareSegmentedControl 索引对应)。
const List<SdkTransportMode> _transportOrder = [
  SdkTransportMode.websocket,
  SdkTransportMode.quic,
  SdkTransportMode.race,
];

/// 登录页（统一规格：上部品牌渐变区 + 下部白底表单，品牌渐变主按钮）
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _userIdController;
  late final TextEditingController _serverUrlController;
  late final TextEditingController _httpUrlController;
  late final TextEditingController _quicUrlController;

  AppDefaults _defaults = AppDefaults.fallback;
  SdkTransportMode _transportMode = SdkTransportMode.websocket;
  bool _isLoading = false;
  bool _serverOpen = false;
  String? _errorMessage;
  String? _loginStage;

  @override
  void initState() {
    super.initState();
    _userIdController = TextEditingController();
    _serverUrlController = TextEditingController(
      text: AppDefaults.fallback.defaultWsUrl,
    );
    _httpUrlController = TextEditingController(
      text: AppDefaults.fallback.httpUrl,
    );
    _quicUrlController = TextEditingController(
      text: AppDefaults.fallback.defaultQuicUrl,
    );
    unawaited(_bootstrapConfig());
  }

  Future<void> _bootstrapConfig() async {
    final d = await AppConfigLoader.load();
    if (!mounted) return;
    setState(() {
      _defaults = d;
      _serverUrlController.text = d.defaultWsUrl;
      _httpUrlController.text = d.httpUrl;
      _quicUrlController.text = d.defaultQuicUrl;
      _transportMode = d.defaultTransportMode;
      if (_userIdController.text.trim().isEmpty) {
        _userIdController.text = d.defaultUserId;
      }
    });
  }

  @override
  void dispose() {
    _userIdController.dispose();
    _serverUrlController.dispose();
    _httpUrlController.dispose();
    _quicUrlController.dispose();
    super.dispose();
  }

  String get _effectiveWsUrl {
    final t = _serverUrlController.text.trim();
    return t.isNotEmpty ? t : _defaults.defaultWsUrl;
  }

  String get _effectiveHttpUrl {
    final t = _httpUrlController.text.trim();
    return t.isNotEmpty ? t : _defaults.httpUrl;
  }

  String get _effectiveQuicUrl {
    final t = _quicUrlController.text.trim();
    return t.isNotEmpty ? t : _defaults.defaultQuicUrl;
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _loginStage = ref.read(flareMessagesProvider).login.stagePreparing;
    });

    try {
      final wsUrl = _effectiveWsUrl;
      final im = ref.read(imOutboundProvider);
      final dataUrl = await resolveSdkDataUrl();
      if (mounted) {
        setState(
          () => _loginStage = ref
              .read(flareMessagesProvider)
              .login
              .stageInitializing,
        );
      }
      // SDK 托管:核心向 Gateway 签发接入 token 并自动刷新;客户端从不持有签名密钥。
      await im.authEnsureSdkInitialized(
        wsUrl: wsUrl,
        transportMode: _transportMode,
        quicUrl: _effectiveQuicUrl,
        tenantId: _defaults.tenantId,
        httpUrl: _effectiveHttpUrl,
        tlsCaCertPath: _defaults.defaultTlsCaCertPath,
        tlsCaCert: _defaults.defaultTlsCaCert,
        dataUrl: dataUrl,
      );

      final userId = _userIdController.text.trim();
      if (mounted) {
        setState(
          () => _loginStage = ref
              .read(flareMessagesProvider)
              .login
              .stageConnecting,
        );
      }
      await im.authLogin(userId, null);
      await SavedSessionStore.save(
        SavedSessionProfile(
          userId: userId,
          wsUrl: wsUrl,
          transportMode: _transportMode,
          quicUrl: _effectiveQuicUrl,
          tlsCaCertPath: _defaults.defaultTlsCaCertPath,
          httpUrl: _effectiveHttpUrl,
        ),
      );

      if (mounted) {
        context.go('/conversations');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = friendlyLoginError(
            e,
            ref.read(flareMessagesProvider),
          );
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loginStage = null;
        });
      }
    }
  }

  double _headerHeight(BuildContext context) {
    final h = MediaQuery.sizeOf(context).height;
    return (h * 0.32).clamp(252.0, 320.0);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(flareMessagesProvider).login;
    final c = FlareColors.of(Theme.of(context).brightness);

    return Scaffold(
      backgroundColor: c.bgPrimary,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _brandHeader(context, c, l10n),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                FlareSizes.spacingXl,
                30,
                FlareSizes.spacingXl,
                42,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: _LoginSpec.formMaxWidth,
                  ),
                  child: _form(context, c, l10n),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _brandHeader(BuildContext context, FlareColors c, dynamic l10n) {
    return SizedBox(
      height: _headerHeight(context),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [c.primaryActive, c.primary, c.info],
          ),
        ),
        child: Stack(
          children: [
            Positioned.fill(child: CustomPaint(painter: _LoginGridPainter())),
            SafeArea(
              bottom: false,
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const FlareBrandLogo(
                      size: _LoginSpec.logoSize,
                      variant: FlareBrandLogoVariant.plate,
                    ),
                    const SizedBox(height: FlareSizes.spacingLg),
                    Text(
                      l10n.brandTitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                        fontSize: _LoginSpec.titleSize,
                      ),
                    ),
                    const SizedBox(height: FlareSizes.spacingXs),
                    Text(
                      l10n.brandSubtitle,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.88),
                        fontSize: FlareSizes.fontSizeLg,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _form(BuildContext context, FlareColors c, dynamic l10n) {
    final protocolIndex = _transportOrder.indexOf(_transportMode).clamp(0, 2);
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.welcomeTitle,
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
              fontSize: _LoginSpec.welcomeSize,
            ),
          ),
          const SizedBox(height: FlareSizes.spacingSm),
          Text(
            l10n.welcomeSubtitle,
            style: TextStyle(
              color: c.textSecondary,
              fontSize: FlareSizes.fontSizeLg,
            ),
          ),
          const SizedBox(height: FlareSizes.spacingLg),
          FlareFormField(
            label: l10n.userIdLabel,
            hint: l10n.userIdHint,
            child: FlareInput(
              controller: _userIdController,
              placeholder: l10n.userIdPlaceholder,
              onSubmitted: (_) => _handleLogin(),
            ),
          ),
          const SizedBox(height: FlareSizes.spacingLg),
          FlareFormField(
            label: l10n.protocol,
            child: FlareSegmentedControl(
              options: ['WebSocket', 'QUIC', l10n.transportRace as String],
              selectedIndex: protocolIndex,
              onSelect: (i) =>
                  setState(() => _transportMode = _transportOrder[i]),
            ),
          ),
          const SizedBox(height: FlareSizes.spacingLg),
          _serverSection(c),
          if (_errorMessage != null) ...[
            const SizedBox(height: FlareSizes.spacingMd),
            _errorBanner(c, _errorMessage!),
          ],
          const SizedBox(height: FlareSizes.spacingXl),
          if (_isLoading && _loginStage != null) ...[
            Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: c.primary,
                  ),
                ),
                const SizedBox(width: FlareSizes.spacingSm),
                Expanded(
                  child: Text(
                    _loginStage!,
                    style: TextStyle(
                      color: c.textSecondary,
                      fontWeight: FontWeight.w600,
                      fontSize: FlareSizes.fontSizeSm,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: FlareSizes.spacingMd),
          ],
          _signInButton(c, l10n),
          const SizedBox(height: FlareSizes.spacingLg),
          Text(
            l10n.footerPrimary,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: c.textTertiary,
              height: 1.45,
              fontSize: FlareSizes.fontSizeSm,
            ),
          ),
          const SizedBox(height: FlareSizes.spacingXs),
          Text(
            l10n.footerSecondary,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: c.textTertiary,
              fontSize: FlareSizes.fontSizeXs,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  /// 服务器地址区：默认收起，点击展开 WebSocket / Gateway / QUIC URL。
  Widget _serverSection(FlareColors c) {
    final l10n = ref.watch(flareMessagesProvider).login;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.bgSecondary,
        borderRadius: BorderRadius.circular(FlareSizes.radiusLg),
        border: Border.all(color: c.borderPrimary),
      ),
      child: Padding(
        padding: const EdgeInsets.all(FlareSizes.spacingLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              onTap: () => setState(() => _serverOpen = !_serverOpen),
              child: Row(
                children: [
                  Icon(Icons.dns_outlined, size: 18, color: c.textSecondary),
                  const SizedBox(width: FlareSizes.spacingSm),
                  Expanded(
                    child: Text(
                      l10n.serverToggle,
                      style: TextStyle(
                        color: c.textPrimary,
                        fontWeight: FontWeight.w600,
                        fontSize: FlareSizes.fontSizeLg,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _serverOpen ? 0.5 : 0,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(
                      Icons.expand_more,
                      size: 20,
                      color: c.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
            if (_serverOpen) ...[
              const SizedBox(height: FlareSizes.spacingLg),
              FlareFormField(
                label: l10n.wsAddress,
                child: FlareInput(
                  controller: _serverUrlController,
                  placeholder: 'ws://host:60051/ws',
                ),
              ),
              const SizedBox(height: FlareSizes.spacingLg),
              FlareFormField(
                label: l10n.gatewayAddress,
                hint: l10n.gatewayHint,
                child: FlareInput(
                  controller: _httpUrlController,
                  placeholder: 'http://host:50050',
                ),
              ),
              const SizedBox(height: FlareSizes.spacingLg),
              FlareFormField(
                label: l10n.quicAddress,
                child: FlareInput(
                  controller: _quicUrlController,
                  placeholder: 'quic://host:60052',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// 渐变登录按钮（48 高，radiusLg 圆角；禁用降透明度）。
  Widget _signInButton(FlareColors c, dynamic l10n) {
    final radius = BorderRadius.circular(FlareSizes.radiusLg);
    return Opacity(
      opacity: _isLoading ? 0.55 : 1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(colors: [c.primary, c.info]),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: _isLoading ? null : _handleLogin,
            child: SizedBox(
              height: _LoginSpec.buttonHeight,
              child: Center(
                child: _isLoading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.login_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                          const SizedBox(width: FlareSizes.spacingSm),
                          Text(
                            l10n.loginButton,
                            style: const TextStyle(
                              fontSize: FlareSizes.fontSize2xl,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _errorBanner(FlareColors c, String message) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.error.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(FlareSizes.radiusLg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(FlareSizes.spacingMd),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline, color: c.error, size: 18),
            const SizedBox(width: FlareSizes.spacingMd),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: FlareSizes.fontSizeSm,
                ),
                maxLines: 3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 品牌头细网格：白 @0.11、步长 40（与 iOS/Android 一致）。
class _LoginGridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.11)
      ..strokeWidth = 1;
    for (double x = 0; x <= size.width; x += _LoginSpec.gridStep) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y <= size.height; y += _LoginSpec.gridStep) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
