import 'dart:async';

import 'package:flare_core_flutter_push/flare_core_flutter_push.dart'
    show PlatformTapRoute;
import 'package:flare_im/application/providers/auth_state_provider.dart';
import 'package:flare_im/application/providers/locale_provider.dart';
import 'package:flare_im/application/providers/push_provider.dart';
import 'package:flare_im/domain/entities/user.dart';
import 'package:flare_im/interface/router/app_router.dart';
import 'package:flare_im/shared/i18n/flare_locale.dart';
import 'package:flare_im/shared/layout/workbench_layout.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// 系统推送在界面上的一端：令牌登记跟着应用内的语言；登录或恢复会话后接上宿主（推送与链路在线时的系统通知
/// 展示方），登出后交给原生模块登出；点击通知（推送的通知、Android 后台展示器与桌面的系统通知）打开那个会话。
///
/// 冷启动的点击早于登录：原生模块先留着，接上宿主后才放出来；这时可能还在启动跳转或登录页上，
/// 去向也先留着，等进了登录后的页面再打开。
class PushNotificationHost extends ConsumerStatefulWidget {
  const PushNotificationHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PushNotificationHost> createState() =>
      _PushNotificationHostState();
}

class _PushNotificationHostState extends ConsumerState<PushNotificationHost> {
  StreamSubscription<PlatformTapRoute>? _routes;
  GoRouter? _router;
  PlatformTapRoute? _pending;

  @override
  void initState() {
    super.initState();
    final push = ref.read(pushNotificationsProvider);
    if (!push.hasSystemNotifications) return;
    // 令牌登记带应用内选的语言：启动时给一次，切语言时再给，原生模块变了就重新登记。
    ref.listenManual<FlareLocale>(flareLocaleProvider, (_, locale) {
      unawaited(_report(push.setLocale(locale.code)));
    }, fireImmediately: true);
    ref.listenManual<User?>(currentUserProvider, (previous, next) {
      final before = previous?.userId ?? '';
      final after = next?.userId ?? '';
      if (before == after) return;
      if (after.isEmpty) {
        _pending = null;
        unawaited(_report(push.signedOut()));
      } else {
        // 去向只在接上宿主之后才有；原生模块在没人收的时候留着最近一条，晚些订阅不丢。
        _routes ??= push.routes.listen((route) {
          _pending = route;
          _openPending();
        });
        if (_router == null) {
          final router = ref.read(appRouterProvider);
          router.routerDelegate.addListener(_openPending);
          _router = router;
        }
        unawaited(_report(push.signedIn()));
      }
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _router?.routerDelegate.removeListener(_openPending);
    unawaited(_routes?.cancel());
    super.dispose();
  }

  /// 推送接入尽力而为：失败只记类型，不挡登录登出。
  Future<void> _report(Future<void> work) async {
    try {
      await work;
    } catch (error) {
      debugPrint('push: ${error.runtimeType}');
    }
  }

  /// 登录后的页面上才打开；导航放到这一轮事件之后，不在路由变化的通知里再改路由。
  void _openPending() {
    final route = _pending;
    final router = _router;
    if (route == null || router == null || !mounted) return;
    if (ref.read(currentUserProvider) == null) return;
    final location = router.routerDelegate.currentConfiguration.uri.path;
    if (location.isEmpty || location == '/' || location == '/login') return;
    _pending = null;
    final path = '/chat/${Uri.encodeComponent(route.conversationId)}';
    if (location == path) return;
    final wide = isWorkbenchWide(context);
    Timer.run(() {
      if (!mounted) return;
      if (wide) {
        router.go(path);
      } else {
        unawaited(router.push<void>(path));
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
