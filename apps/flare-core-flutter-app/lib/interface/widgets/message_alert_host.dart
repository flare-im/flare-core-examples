import 'dart:async';

import 'package:flare_core_flutter_sdk/flare_core_flutter_sdk.dart' as core
    show NotificationPresentation;
import 'package:flare_im/application/bus/event_bus.dart';
import 'package:flare_im/application/providers/active_chat_stack_provider.dart';
import 'package:flare_im/application/providers/auth_state_provider.dart';
import 'package:flare_im/application/providers/sdk_provider.dart';
import 'package:flare_im/domain/entities/user.dart';
import 'package:flare_im/infrastructure/platform/message_sound.dart';
import 'package:flare_im/interface/router/app_router.dart';
import 'package:flare_im/shared/layout/workbench_layout.dart';
import 'package:flare_im_ui/flare_im_ui.dart'
    show
        FlareInAppNotification,
        FlareInAppNotificationChannel,
        FlareInAppNotificationHost,
        FlareInAppNotifications;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 链路在线时引擎交来的应用内提醒：新消息横幅（Kit 的横幅宿主，盖在所有页面之上）与提示音，以及告诉引擎屏幕上
/// 是哪个会话。提不提醒、走系统通知还是横幅、响不响都由引擎决定，这里只照办；系统通知、通知中心的清除与角标归
/// 原生推送模块。
///
/// 屏幕上的会话 = 前台的聊天页（[foregroundChatConversationIdProvider]），且应用在前台。
class MessageAlertHost extends ConsumerStatefulWidget {
  const MessageAlertHost({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<MessageAlertHost> createState() => _MessageAlertHostState();
}

class _MessageAlertHostState extends ConsumerState<MessageAlertHost> {
  final _banners = FlareInAppNotifications();
  StreamSubscription<NotificationPresentEvent>? _presented;
  StreamSubscription<NotificationClearedEvent>? _cleared;
  late final AppLifecycleListener _lifecycle;
  bool _foreground = true;

  /// 焦点按顺序报给引擎：上一次报完才报下一次。
  Future<void> _focusReport = Future<void>.value();

  @override
  void initState() {
    super.initState();
    _presented = imEventBus.on<NotificationPresentEvent>().listen(
      (event) => _present(event.presentation),
    );
    _cleared = imEventBus.on<NotificationClearedEvent>().listen(_clear);
    final state = WidgetsBinding.instance.lifecycleState;
    _foreground = state == null || _isForeground(state);
    _lifecycle = AppLifecycleListener(
      onStateChange: (state) {
        final foreground = _isForeground(state);
        if (foreground == _foreground) return;
        _foreground = foreground;
        _reportFocus();
      },
    );
    ref.listenManual<String?>(
      foregroundChatConversationIdProvider,
      (_, _) => _reportFocus(),
    );
    ref.listenManual<User?>(currentUserProvider, (previous, next) {
      final before = previous?.userId ?? '';
      final after = next?.userId ?? '';
      if (before == after) return;
      // 登出：这个账号的横幅全部收走。登录或恢复会话：新客户端从这里得知屏幕上的会话。
      if (after.isEmpty) _banners.clearAll();
      _reportFocus();
    }, fireImmediately: true);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    unawaited(_presented?.cancel());
    unawaited(_cleared?.cancel());
    _banners.dispose();
    super.dispose();
  }

  /// 前台：可见（resumed，或短暂失去输入焦点的 inactive）；hidden、paused 等都算后台。
  static bool _isForeground(AppLifecycleState state) =>
      state == AppLifecycleState.resumed || state == AppLifecycleState.inactive;

  /// 引擎的 `notification.present`：这里只接应用内横幅，系统通知由原生推送模块出。
  void _present(core.NotificationPresentation presentation) {
    if (presentation.surface != 'inApp') return;
    _banners.present(
      FlareInAppNotification(
        collapseId: presentation.collapseId,
        conversationId: presentation.conversationId,
        messageId: presentation.messageId.isEmpty
            ? null
            : presentation.messageId,
        title: presentation.title,
        body: presentation.body,
        count: presentation.count < 1 ? 1 : presentation.count,
        channel: _channelOf(presentation.channel),
      ),
    );
    if (presentation.sound) unawaited(MessageSound.play());
  }

  /// 引擎的 `notification.clear`：读过或删掉的会话，横幅也一并收走。
  void _clear(NotificationClearedEvent event) {
    if (event.all) {
      _banners.clearAll();
    } else {
      _banners.clear(event.collapseIds);
    }
  }

  void _reportFocus() {
    final conversationId = _foreground
        ? ref.read(foregroundChatConversationIdProvider)
        : null;
    final sdk = ref.read(sdkWrapperProvider);
    _focusReport = _focusReport
        .then((_) => sdk.setNotificationFocus(conversationId))
        .catchError((Object error) {
          debugPrint('notification focus: ${error.runtimeType}');
        });
  }

  /// 点开横幅：打开那个会话，与点系统通知走同一种跳转。聊天页不支持定位到某条消息，只打开会话。
  void _open(String conversationId, String? messageId) {
    if (conversationId.isEmpty || ref.read(currentUserProvider) == null) return;
    final router = ref.read(appRouterProvider);
    final path = '/chat/${Uri.encodeComponent(conversationId)}';
    if (router.routerDelegate.currentConfiguration.uri.path == path) return;
    if (isWorkbenchWide(context)) {
      router.go(path);
    } else {
      unawaited(router.push<void>(path));
    }
  }

  static FlareInAppNotificationChannel _channelOf(String wire) =>
      switch (wire) {
        'quiet' => FlareInAppNotificationChannel.quiet,
        'mentions' => FlareInAppNotificationChannel.mentions,
        'urgent' => FlareInAppNotificationChannel.urgent,
        _ => FlareInAppNotificationChannel.messages,
      };

  @override
  Widget build(BuildContext context) => FlareInAppNotificationHost(
    notifications: _banners,
    onOpen: _open,
    child: widget.child,
  );
}
