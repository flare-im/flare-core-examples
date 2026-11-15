import FlareNotificationService

/// 通知扩展：按应用写在 App Group 里的通知快照重渲染标题与发送者名字，并记下到达回执。全部逻辑在
/// `FlareNotificationServiceBase` 里，这里只给出 App Group：与 `project.yml` 里两个目标的 entitlements、
/// `PushNotifications` 的推送配置是同一个。
final class NotificationService: FlareNotificationServiceBase {
    override var appGroupIdentifier: String { "group.com.flare.im.example.app" }
}
