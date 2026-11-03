import 'package:flare_im/application/bridge/event_to_store.dart';
import 'package:flare_im/application/bridge/sdk_listener.dart';
import 'package:flutter/material.dart';

/// 实时链路外壳：必须先挂载 [ImEventToStoreBridge] 再挂 [SdkImEventEmitter]，
/// 保证 EventBus 订阅早于 SDK 登录后的首批同步回推。
class SdkEventScope extends StatelessWidget {
  const SdkEventScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ImEventToStoreBridge(child: SdkImEventEmitter(child: child));
  }
}
