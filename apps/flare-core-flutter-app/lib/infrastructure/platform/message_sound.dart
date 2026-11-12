import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// 应用内横幅的提示音：系统自带的那一个，走 app 自己的 `flare.im/sound` 通道由原生一侧放（Android 是用户在系统
/// 设置里选的通知提示音，iOS 是系统的新消息提示音，macOS 是系统提示音），跟着系统的音量与静音。没有原生一侧的
/// 平台什么都不放。
abstract final class MessageSound {
  static const _channel = MethodChannel('flare.im/sound');

  static Future<void> play() async {
    try {
      await _channel.invokeMethod<void>('message');
    } on MissingPluginException {
      // 这个平台没有接提示音。
    } on PlatformException catch (error) {
      debugPrint('message sound: ${error.code}');
    }
  }
}
