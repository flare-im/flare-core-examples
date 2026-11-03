import Combine
import FlareCoreAppleSDK
import SwiftUI

/// 设置特性 ViewModel：外观/登录默认值的读写绑定、会话只读态，以及诊断刷新与会话清理动作。
/// SettingsView 只依赖它，不再直接碰 `store`/`environment`/`sdkLab`。
@MainActor
final class SettingsViewModel: ObservableObject {
    private let session: AppSession
    private let environment: AppEnvironment
    private let sdkLab: SdkLabViewModel
    private weak var lifecycle: AppLifecycle?
    /// 清缓存后让时间线忘掉记住的本地副本。
    private weak var messaging: MessagingViewModel?
    private var cancellables = Set<AnyCancellable>()

    init(
        session: AppSession,
        environment: AppEnvironment,
        sdkLab: SdkLabViewModel,
        lifecycle: AppLifecycle? = nil
    ) {
        self.session = session
        self.environment = environment
        self.sdkLab = sdkLab
        self.lifecycle = lifecycle
        for publisher in [session.objectWillChange, environment.objectWillChange] {
            publisher.sink { [weak self] in self?.objectWillChange.send() }.store(in: &cancellables)
        }
    }

    /// 由组合根在装配后回填（打破 store ↔ VM 强引用环）。
    func bind(lifecycle: AppLifecycle) {
        self.lifecycle = lifecycle
    }

    func bind(messaging: MessagingViewModel) {
        self.messaging = messaging
    }

    var themeChoice: Binding<ThemeChoice> {
        Binding(get: { self.environment.themeChoice }, set: { self.environment.themeChoice = $0 })
    }

    func draftBinding<Value>(_ keyPath: WritableKeyPath<LoginDraft, Value>) -> Binding<Value> {
        Binding(
            get: { self.environment.loginDraft[keyPath: keyPath] },
            set: { newValue in
                var draft = self.environment.loginDraft
                draft[keyPath: keyPath] = newValue
                self.environment.loginDraft = draft
            }
        )
    }

    var currentUserId: String? { session.currentUserId }
    var connectionState: ConnectionState { session.connectionState }
    var runtimeStatus: RuntimeStatus { environment.runtimeStatus }

    func refreshDiagnostics() async { await sdkLab.refreshDiagnostics() }
    func logout() async { await lifecycle?.logout() }
    func dispose() async { await lifecycle?.dispose() }

    // MARK: - 媒体缓存管理（SDK 托管的磁盘缓存：用量 / 上限 / 清空）
    @Published private(set) var cacheUsage: MediaCacheUsage?
    /// 用量那一行的文字：`12.3 MB / 256.0 MB · 4 files`，没读到时为 nil（界面显示 —）。
    var cacheStats: String? { cacheUsage?.summary }

    // 这三个都是**用户动作**，失败必须让用户知道。
    //
    // 原来一律 `try?` 吞掉：点"清空缓存"什么都没发生、改上限没生效，
    // 界面照样一片祥和 —— 用户以为做成了。这里走统一的 `environment.run`（Lab 记录），
    // 并把成败交还给界面去说（设置页不显示 lastError，只靠它等于没说）。
    // 读取（stats）保持静默降级：拿不到就不显示，不值得打扰用户。

    func refreshCacheStats() async {
        guard let client = session.client else { return }
        if let raw = try? await client.media.getMediaCacheStats() {
            cacheUsage = MediaCacheUsage(raw)
        }
    }

    @discardableResult
    func setCacheMaxBytes(_ bytes: Int64) async -> Bool {
        guard let client = session.client else { return false }
        var ok = false
        await environment.run("media.setMediaCacheMaxBytes") {
            _ = try await client.media.setMediaCacheMaxBytes(["maxBytes": AnySendable(bytes)])
            ok = true
        }
        await refreshCacheStats()
        return ok
    }

    /// 清空 SDK 媒体缓存；看过的图片之后会重新下载。返回是否清掉了。
    @discardableResult
    func clearCache() async -> Bool {
        guard let client = session.client else { return false }
        var ok = false
        await environment.run("media.clearMediaCache") {
            try await client.media.clearMediaCache()
            ok = true
        }
        if ok { messaging?.forgetPictureCopies() }
        await refreshCacheStats()
        return ok
    }

    // MARK: - 下载位置（「保存」写到哪：核心 media.user_download_get_directory）

    /// iOS 默认是本应用 Documents/flare（Info.plist 开了文件共享，「文件」App 里看得到）；
    /// iOS 不能任选文件夹（要逐个安全书签），所以只显示位置，自定义了才给「恢复默认位置」。
    @Published private(set) var downloadLocation: DownloadLocationState?

    func refreshDownloadLocation() async {
        guard let client = session.client else { return }
        if let raw = try? await client.media.getUserDownloadDirectory() {
            downloadLocation = DownloadLocationState(raw)
        }
    }

    /// 回到平台默认位置（不带 directory 即默认）。返回是否成功。
    @discardableResult
    func resetDownloadLocation() async -> Bool {
        guard let client = session.client else { return false }
        var ok = false
        await environment.run("media.setUserDownloadDirectory") {
            downloadLocation = DownloadLocationState(try await client.media.setUserDownloadDirectory([:]))
            ok = true
        }
        return ok
    }
}
