import Combine
import Foundation

/// 跨特性共享的 App 外壳状态 + 操作基建。从 god-store 抽出,作为各 ViewModel 的共享依赖。
///
/// 收纳三类原本散在 god-store 里的横切关注点:
/// 1. **UI / 导航**:当前分栏、会话过滤、主题、详情面板开合。
/// 2. **共享配置**:`loginDraft` —— LoginView 与 SettingsView 共同编辑同一份。
/// 3. **操作基建**:统一的 `run()`(busy / 运行态 / 错误 / Lab 记录),供所有 ViewModel 复用 ——
///    避免每个 VM 各写一套 try/catch,也避免反向依赖容器(无 retain cycle)。
@MainActor
final class AppEnvironment: ObservableObject {
    // 1. UI / 导航
    @Published var section: AppSection = .conversations
    @Published var filter: ConversationFilter = .all
    @Published var themeChoice: ThemeChoice = .system
    @Published var detailsOpen = true
    /// 当前选中的会话(多特性共享:会话列表绑定、聊天/搜索读取)。
    @Published var selectedConversationId: String?

    // 2. 共享配置(LoginView 与 SettingsView 共用)
    @Published var loginDraft = LoginDraft()

    // 3. 操作状态 + Lab 日志(全局)
    @Published private(set) var isBusy = false
    @Published private(set) var runtimeStatus: RuntimeStatus = .idle
    @Published private(set) var lastError: String?
    @Published private(set) var labResults: [LabResult] = []

    private let session: AppSession

    init(session: AppSession) {
        self.session = session
    }

    /// 登录等多阶段操作回报进度用。
    func setRuntimeStatus(_ status: RuntimeStatus) {
        runtimeStatus = status
        if status == .ready || status == .idle {
            lastError = nil
        }
    }

    /// 统一操作执行:置忙 → 跑 → 成功收敛运行态 / 失败记错误 + Lab。原 god-store `perform` 的归宿。
    func run(_ operation: String, showBusy: Bool = true, body: () async throws -> Void) async {
        if showBusy { isBusy = true }
        if showBusy { lastError = nil }
        do {
            try await body()
            if showBusy {
                setRuntimeStatus(session.isLoggedIn ? .ready : .idle)
            }
        } catch {
            let text = FlareFormatters.errorText(error)
            if showBusy {
                lastError = text
                runtimeStatus = (error is AppStoreError) ? .unavailable(text) : .error(text)
                appendLab(operation, status: "error", detail: text)
            } else {
                appendLab(operation, status: "warn", detail: text)
            }
        }
        if showBusy { isBusy = false }
    }

    func appendLab(_ operation: String, status: String, detail: String) {
        labResults.insert(LabResult(time: Date(), operation: operation, status: status, detail: detail), at: 0)
        if labResults.count > 120 { labResults.removeLast(labResults.count - 120) }
    }
}
