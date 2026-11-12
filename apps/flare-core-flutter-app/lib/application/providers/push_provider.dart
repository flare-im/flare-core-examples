import 'package:flare_core_flutter_push/flare_core_flutter_push.dart'
    show FlarePushBackgroundStatus, FlarePushPermissionStatus;
import 'package:flare_im/application/providers/sdk_provider.dart';
import 'package:flare_im/application/services/push_notifications_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 系统推送：宿主是这个应用的核心客户端。
final pushNotificationsProvider = Provider<PushNotificationsService>((ref) {
  final sdk = ref.watch(sdkWrapperProvider);
  return PushNotificationsService(host: sdk.pushHost);
});

/// 系统通知权限，跟着原生模块（启动、申请之后与每次回到前台重读，变了才发）；没有系统推送的平台不出值。
final pushPermissionProvider =
    StreamProvider.autoDispose<FlarePushPermissionStatus>(
      (ref) => ref.watch(pushNotificationsProvider).permissionChanges,
    );

/// 后台限制，跟着原生模块（启动与每次回到前台重读，用户从电池设置回来就是新值）；只有 Android 出值。
final pushBackgroundProvider =
    StreamProvider.autoDispose<FlarePushBackgroundStatus>(
      (ref) => ref.watch(pushNotificationsProvider).backgroundChanges,
    );
