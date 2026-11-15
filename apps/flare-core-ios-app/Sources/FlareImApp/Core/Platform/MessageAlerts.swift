import AudioToolbox
import FlareCoreAppleSDK
import FlareIMUI
import Foundation

/// 链路在线时引擎交来的应用内提醒：新消息横幅（kit `FlareInAppNotifications`，根上的 `InAppNotificationHost` 画它）
/// 与提示音，以及告诉引擎屏幕上是哪个会话。提不提醒、走系统通知还是横幅、响不响都由引擎决定，这里只照办；
/// 系统通知、通知中心的清除与角标归推送模块。
@MainActor
final class MessageAlerts: ObservableObject {
    /// 横幅呈现器，根上的 `InAppNotificationHost` 画它。
    let banners = FlareInAppNotifications()

    private let session: AppSession
    /// 屏幕上的聊天页所属会话；没有聊天页或应用在后台时为 nil。
    private var focused: String?
    /// 焦点按顺序报给引擎：上一次报完才报下一次。
    private var focusReport: Task<Void, Never>?

    init(session: AppSession) {
        self.session = session
    }

    /// 引擎的 `notification.present`：这里只接应用内横幅，系统通知由推送模块出。
    func present(_ presentation: NotificationPresentation) {
        guard presentation.surface == Self.inAppSurface else { return }
        banners.present(FlareInAppNotification(
            collapseId: presentation.collapseId,
            conversationId: presentation.conversationId,
            messageId: presentation.messageId.isEmpty ? nil : presentation.messageId,
            title: presentation.title,
            body: presentation.body,
            count: max(1, Int(presentation.count)),
            channel: FlareInAppNotificationChannel(rawValue: presentation.channel) ?? .messages
        ))
        if presentation.sound { AudioServicesPlaySystemSound(Self.messageSound) }
    }

    /// 引擎的 `notification.clear`：读过或删掉的会话，横幅也一并收走。
    func clear(_ event: NotificationClearEvent) {
        if event.all {
            banners.clearAll()
        } else {
            banners.clear(event.collapseIds)
        }
    }

    /// 聊天页出现、换了会话，或应用前后台切换。`foreground` 为 false 时应用在后台，当作屏幕上没有会话。
    func chatShown(_ conversationId: String, foreground: Bool) {
        setFocus(foreground ? conversationId : nil)
    }

    /// 聊天页离开屏幕；已经换成别的会话时不动。
    func chatHidden(_ conversationId: String) {
        guard focused == conversationId else { return }
        setFocus(nil)
    }

    /// 登录或恢复会话之后：这个客户端从这里得知屏幕上的会话。
    func signedIn() {
        report()
    }

    /// 登出或释放之前：横幅全部收走，屏幕上不再有这个账号的会话。
    func signedOut() {
        banners.clearAll()
        focused = nil
        report()
    }

    private func setFocus(_ conversationId: String?) {
        guard focused != conversationId else { return }
        focused = conversationId
        report()
    }

    /// 焦点不等登录、也不等网络；没有客户端时什么都不做，登录后 ``signedIn()`` 再报。
    private func report() {
        guard let client = session.client else { return }
        let request = SetNotificationFocusRequest(conversationId: focused)
        let previous = focusReport
        focusReport = Task {
            await previous?.value
            _ = try? await client.notification.setFocus(request)
        }
    }

    nonisolated static let inAppSurface = "inApp"
    /// 系统自带的新消息提示音。
    nonisolated static let messageSound: SystemSoundID = 1007
}
