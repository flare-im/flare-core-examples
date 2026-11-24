import FlareCorePushBridge
import Combine
import FlareCoreAppleSDK
import FlareIMUI
import FlarePlatformPush
import Foundation

/// 点一条通知（系统通知或应用内横幅）要打开的会话。每次点击一个新值，同一会话点两次也会再打开一次。
struct PushOpenRequest: Identifiable, Equatable {
    let id = UUID()
    let conversationId: String
}

/// 应用的推送接线：持有进程里唯一的 `PlatformPush`，登录或恢复会话后接上核心客户端，退出时交给模块登出；
/// 按账号记住首次通知引导答过没有；把通知点击交给已登录界面。
///
/// 权限的读取与变化、提示怎么出、令牌怎么登记、登出清什么都是推送模块与核心的事，这里只做应用自己的部分：
/// 何时接上、何时问权限、点了去哪。
@MainActor
final class PushNotifications: ObservableObject {
    static let shared = PushNotifications()

    /// 系统通知权限，跟着模块的 `permissionChanges()`；进程没启动推送（单测、macOS 宿主）或还没读到时为 nil。
    @Published private(set) var permission: PlatformPushPermissionStatus?
    /// 当前账号答过首次通知引导（开启、前往设置、以后再说，或把面板划掉）。
    @Published private(set) var promptAnswered = false
    /// 点击通知要打开的会话，已登录界面取走后清空。
    @Published private(set) var openRequest: PushOpenRequest?

    /// 推送接线的失败（宿主调用、系统接口），交给 SDK 实验室的记录。
    var onError: (@MainActor (String) -> Void)?

    /// 推送模块。系统通知中心只弱引用代理，它随进程常驻（只有 `shared` 一个实例）。
    let push = PlatformPush(configuration: PushNotifications.configuration, onError: { error in
        let detail = String(describing: error)
        Task { @MainActor in PushNotifications.shared.onError?(detail) }
    })

    /// 通知扩展与后台刷新：App Group、扩展、后台刷新标识与 `project.yml` 一致（应用包名前加 `group.`、后加 `.refresh`）。
    /// 后台刷新任务在 `launch()` 里随模块启动登记，必须赶在启动返回之前。
    nonisolated static let configuration = PlatformPushConfiguration(
        appGroupIdentifier: "group.com.flare.im.example.app",
        hasNotificationServiceExtension: true,
        backgroundRefreshTaskIdentifier: "com.flare.im.example.app.refresh"
    )
    /// 接上宿主的账号（租户/用户）；引导只对已登录的账号显示。
    @Published private var account: String?

    private init() {}

    /// 从 `application(_:didFinishLaunchingWithOptions:)` 调一次：通知中心代理要在它返回之前装上，冷启动的点击才送得到。
    func launch() {
        guard !push.isStarted else { return }
        // 令牌登记带应用界面的语言：系统语言可能是这个应用没有的，服务端兜底文案要和界面一致。
        // 应用里没有自己的语言切换（iOS 换语言会重启应用），启动时给一次就够。
        push.setLocale(KitStrings.localeTag)
        push.start()
        let routes = push.routes()
        let permissions = push.permissionChanges()
        Task { [weak self] in
            for await route in routes {
                self?.receive(route)
            }
        }
        Task { [weak self] in
            for await status in permissions {
                self?.permission = status
            }
        }
    }

    /// 登录或恢复会话之后：把这个客户端接成推送宿主。会话恢复前到的那次点击在这时才解析出会话。
    func signedIn(client: any FlareImClientProtocol, tenantId: String, userId: String) {
        let account = "\(tenantId)/\(userId)"
        self.account = account
        promptAnswered = UserDefaults.standard.bool(forKey: Self.promptAnsweredKey(account))
        push.attach(CorePushHost(client: client))
    }

    /// 登出或释放客户端之前：模块摘下宿主，清掉本 SDK 的通知与角标，下一个账号重新登记令牌。
    func signedOut() async {
        account = nil
        promptAnswered = false
        openRequest = nil
        await push.signOut()
    }

    /// 会话列表的首次通知引导：已登录、这个账号还没答过、通知没开（没问过时请求，关着时引导去系统设置）。
    var showsPrompt: Bool {
        guard account != nil, !promptAnswered else { return false }
        return permission == .notDetermined || permission == .denied
    }

    /// 答过首次引导：这个账号不再出现，换账号登录会再问一次。设置页的通知行随时可用。
    func answerPrompt() {
        guard let account, !promptAnswered else { return }
        UserDefaults.standard.set(true, forKey: Self.promptAnsweredKey(account))
        promptAnswered = true
    }

    /// 弹系统授权框（模块从不自己弹）。回答经 `permissionChanges()` 回来。
    func requestPermission() async {
        await push.requestAuthorization()
    }

    /// 系统设置里本应用的通知页。
    func openSettings() async {
        _ = await push.openNotificationSettings()
    }

    /// 设置页的通知行：还没问过就弹授权框，开着或关着都去系统设置里改；还没读到权限时先读一次。
    func changeFromSettings() async {
        switch permission {
        case .notDetermined?:
            await requestPermission()
        case .granted?, .denied?:
            await openSettings()
        case nil:
            _ = await push.permissionStatus()
        }
    }

    /// 取走待打开的会话。
    func takeOpenRequest() -> PushOpenRequest? {
        guard let request = openRequest else { return nil }
        openRequest = nil
        return request
    }

    /// 打开一条通知指向的会话：系统通知的点击，或点了应用内横幅。已登录界面取走后打开。
    func open(conversationId: String) {
        guard account != nil, !conversationId.isEmpty else { return }
        openRequest = PushOpenRequest(conversationId: conversationId)
    }

    private func receive(_ route: PlatformTapRoute) {
        open(conversationId: route.conversationId)
    }

    nonisolated static func promptAnsweredKey(_ account: String) -> String {
        "flare.push.promptAnswered.\(account)"
    }
}

/// 模块的三态权限在 kit 组件里的说法。
extension PlatformPushPermissionStatus {
    /// 设置页「新消息通知」的状态。
    var notificationStatus: FlareNotificationStatus {
        switch self {
        case .granted: return .on
        case .denied: return .off
        case .notDetermined: return .notTurnedOn
        }
    }

    /// 首次通知引导：没问过时请求，关着时引导去系统设置，开着时不画。
    var promptState: FlarePermissionState {
        switch self {
        case .notDetermined: return .undetermined
        case .denied: return .denied
        case .granted: return .granted
        }
    }
}
