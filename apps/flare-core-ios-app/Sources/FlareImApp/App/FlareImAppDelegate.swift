#if os(iOS)
import FlarePlatformPush
import UIKit

/// 应用代理，进程级的入口：通知中心代理要在启动返回之前装上（装晚了，冷启动的那次点击就丢了），
/// APNs 令牌与静默推送的系统回调也只到这里。推送的回调原样转给 ``PushNotifications``。
///
/// 被后台刷新或静默推送冷启动起来的进程没有界面：保存的会话在这里恢复（进程里唯一的 ``FlareAppStore``），推送宿主
/// 随之接上，不等界面。界面之后用的是同一个组合根、同一个客户端。
///
/// 运行器用 `@UIApplicationDelegateAdaptor(FlareImAppDelegate.self)` 装上它。
public final class FlareImAppDelegate: NSObject, UIApplicationDelegate {
    /// 静默推送到达时等启动那次会话恢复的上限。系统给静默推送约 30 秒，推送模块自己要用掉宿主调用的 3 秒、
    /// 唤醒的 20 秒与重新托管的 3.5 秒，这里只能再多等这么一点。
    static let remoteMessageResumeWaitMs: UInt64 = 2_000

    override public init() {
        super.init()
    }

    public func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        PushNotifications.shared.launch()
        // 本地会话档案在就恢复（只开本地库，不等网络），恢复成了推送宿主随之接上：后台刷新等宿主的那几秒里就能接上
        FlareAppStore.shared.resumeInBackground()
        return true
    }

    public func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        PushNotifications.shared.push.didRegisterForRemoteNotifications(deviceToken: deviceToken)
    }

    public func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        PushNotifications.shared.push.didFailToRegisterForRemoteNotifications(error: error)
    }

    /// 静默推送：推送模块交给核心处理（含一次有界唤醒），处理完才回调系统。推送把进程冷启动起来时会话还在恢复，
    /// 先等它接上宿主（有上限）：没有宿主时模块只能按载荷提示，引擎不唤醒、不同步。
    public func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        Task { @MainActor in
            await FlareAppStore.shared.waitForResumption(limitMs: Self.remoteMessageResumeWaitMs)
            PushNotifications.shared.push.didReceiveRemoteNotification(userInfo, fetchCompletionHandler: completionHandler)
        }
    }
}
#endif
