import Combine
import SwiftUI

/// 登录特性 ViewModel：拥有登录表单的 UI 态（校验）、对 `loginDraft` 的读写绑定，
/// 以及把提交动作委派给 [AppLifecycle]。LoginView 只依赖它，不再直接碰 `store`/`environment`。
@MainActor
final class AuthViewModel: ObservableObject {
    @Published var validationMessage: String?

    private let environment: AppEnvironment
    private weak var lifecycle: AppLifecycle?
    private var cancellables = Set<AnyCancellable>()

    init(environment: AppEnvironment, lifecycle: AppLifecycle? = nil) {
        self.environment = environment
        self.lifecycle = lifecycle
        environment.objectWillChange
            .sink { [weak self] in self?.objectWillChange.send() }
            .store(in: &cancellables)
    }

    /// 由组合根在装配后回填（打破 store ↔ VM 强引用环）。
    func bind(lifecycle: AppLifecycle) {
        self.lifecycle = lifecycle
    }

    var loginDraft: LoginDraft { environment.loginDraft }
    var isBusy: Bool { environment.isBusy }
    var lastError: String? { environment.lastError }
    var canLogin: Bool { !environment.isBusy }

    /// 字段绑定：经此读写 `environment.loginDraft` 的任一属性。
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

    var visibleServerAddress: Binding<String> {
        Binding {
            self.environment.loginDraft.visibleServerAddress
        } set: { value in
            var draft = self.environment.loginDraft
            draft.setVisibleServerAddress(value)
            self.environment.loginDraft = draft
        }
    }

    var secondaryServerAddress: Binding<String> {
        Binding {
            self.environment.loginDraft.secondaryServerAddress ?? ""
        } set: { value in
            var draft = self.environment.loginDraft
            draft.setSecondaryServerAddress(value)
            self.environment.loginDraft = draft
        }
    }

    func clearValidation() { validationMessage = nil }

    func submit() async {
        let userId = environment.loginDraft.userId.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !userId.isEmpty else {
            validationMessage = String(localized: "Enter user ID")
            return
        }
        if userId != environment.loginDraft.userId {
            var draft = environment.loginDraft
            draft.userId = userId
            environment.loginDraft = draft
        }
        validationMessage = nil
        await lifecycle?.login()
    }
}
