import 'package:flare_im/application/providers/auth_state_provider.dart';
import 'package:flare_im/application/providers/push_provider.dart';
import 'package:flare_im_ui/flare_im_ui.dart'
    show
        FlarePermissionChoice,
        FlarePermissionKind,
        FlarePermissionPrompt,
        FlarePermissionState;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 登录后来到会话列表、通知还没开时问一次（Kit 权限提示的软询问，底部面板）：系统授权框还会弹时「开启通知」，
/// 弹不出来了「前往设置」。选了哪个（含关掉面板）都按账号记住，之后不再主动问，设置里随时能开。
Future<void> askForNotificationsOnce(BuildContext context, WidgetRef ref) async {
  final push = ref.read(pushNotificationsProvider);
  final userId = ref.read(currentUserProvider)?.userId.trim() ?? '';
  if (!await push.claimSoftAsk(userId)) return;
  final canRequest = await push.canRequestPermission();
  if (!context.mounted) return;
  final choice = await FlarePermissionPrompt.show(
    context,
    kind: FlarePermissionKind.notifications,
    state: canRequest
        ? FlarePermissionState.undetermined
        : FlarePermissionState.denied,
    softAsk: true,
  );
  if (choice == null) return;
  await push.answerSoftAsk(userId);
  switch (choice) {
    case FlarePermissionChoice.request:
      await push.requestPermission();
    case FlarePermissionChoice.openSettings:
      await push.openSettings();
    case FlarePermissionChoice.dismiss:
      break;
  }
}
