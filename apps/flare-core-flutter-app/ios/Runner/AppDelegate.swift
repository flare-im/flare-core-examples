import AudioToolbox
import Flutter
import UIKit
import flare_core_flutter_push

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // 系统推送：通知中心的代理与 APNs 回调要在启动结束前就位。插件在场景连接时才注册，晚于这里；
    // 冷启动的点击和推送拉起的后台启动都靠这一步。
    FlareCoreFlutterPushPlugin.prepare()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "FlareSoundChannel") {
      FlareSoundChannel.register(with: registrar.messenger())
    }
  }
}

/// 应用内横幅的提示音（`flare.im/sound`）：系统的新消息提示音，跟着静音开关与铃声音量。
enum FlareSoundChannel {
  /// 系统自带的新消息提示音。
  private static let messageSound: SystemSoundID = 1007

  static func register(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(name: "flare.im/sound", binaryMessenger: messenger)
    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "message":
        AudioServicesPlaySystemSound(messageSound)
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
