import 'dart:async';

import 'package:flare_im/application/providers/im_outbound_provider.dart';
import 'package:flare_im/application/providers/locale_provider.dart';
import 'package:flare_im/application/providers/update_provider.dart';
import 'package:flare_im/infrastructure/paths/sdk_data_url.dart';
import 'package:flare_im/interface/screens/login/login_error_text.dart';
import 'package:flare_im/shared/config/app_config_loader.dart';
import 'package:flare_im/shared/config/app_defaults_model.dart';
import 'package:flare_im/shared/session/saved_session_store.dart';
import 'package:flare_im_ui/flare_im_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

// 登录页:统一登录规格 v2。视觉取自 kit 设计 token,**表单用 kit 组件搭建**
// (FlareFormField + FlareInput,来自 flare_im_ui)。字段只有用户 ID:连哪套服务、走哪种
// 协议是构建期的接入配置(shared/config/access_config.dart)与核心的选路,登录页没有服务器
// 设置;也没有 access token / TLS 证书输入(SDK 托管:核心向网关签发并自动刷新;TLS CA
// 走默认配置)。

/// Flare IM account entry, composed entirely from the shared authentication shell.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _userIdController;

  AppDefaults _defaults = AppDefaults.fallback;
  bool _isLoading = false;
  String? _errorMessage;
  String? _loginStage;

  @override
  void initState() {
    super.initState();
    _userIdController = TextEditingController();
    unawaited(_bootstrapConfig());
  }

  Future<void> _bootstrapConfig() async {
    final d = await AppConfigLoader.load();
    if (!mounted) return;
    setState(() {
      _defaults = d;
      if (_userIdController.text.trim().isEmpty) {
        _userIdController.text = d.defaultUserId;
      }
    });
  }

  @override
  void dispose() {
    _userIdController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (_isLoading || _userIdController.text.trim().isEmpty) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _loginStage = ref.read(flareMessagesProvider).login.stagePreparing;
    });

    try {
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
        tenantId: _defaults.tenantId,
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
      await SavedSessionStore.save(SavedSessionProfile(userId: userId));

      if (mounted) {
        context.go('/conversations');
      }
    } catch (e) {
      if (mounted) {
        // 服务端可能拒绝了这个版本：这时没有会话，也就没有事件告诉更新中心。
        ref.read(updateControllerProvider).onLoginFailed();
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

  @override
  Widget build(BuildContext context) {
    final l10n = ref.watch(flareMessagesProvider).login;
    return Scaffold(
      body: FlareAuthShell(
        product: l10n.brandTitle,
        tagline: l10n.brandSubtitle,
        headline: l10n.brandHeadline,
        description: l10n.brandDescription,
        title: l10n.welcomeTitle,
        subtitle: l10n.welcomeSubtitle,
        footer: l10n.footerPrimary,
        child: AutofillGroup(
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                FlareFormField(
                  label: l10n.userIdLabel,
                  hint: l10n.userIdHint,
                  required: true,
                  child: FlareInput(
                    controller: _userIdController,
                    semanticLabel: l10n.userIdLabel,
                    placeholder: l10n.userIdPlaceholder,
                    autofillHints: const [AutofillHints.username],
                    disabled: _isLoading,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: (_) => _handleLogin(),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: FlareSizes.spacingMd),
                  FlareStatusBanner(
                    text: _errorMessage!,
                    tone: FlareStatusTone.danger,
                  ),
                ],
                if (_isLoading && _loginStage != null) ...[
                  const SizedBox(height: FlareSizes.spacingMd),
                  FlareStatusBanner(text: _loginStage!),
                ],
                const SizedBox(height: FlareSizes.spacing2xl),
                FlareButton(
                  block: true,
                  size: FlareControlSize.lg,
                  loading: _isLoading,
                  disabled: _isLoading || _userIdController.text.trim().isEmpty,
                  onPressed: _handleLogin,
                  child: Text(l10n.loginButton),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
