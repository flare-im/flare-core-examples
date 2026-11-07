import Foundation

/// 热启动会话档案：登录成功后保存，下次启动免登录直接
/// prepare(本地库) → 本地出图 → 后台 connect。
/// 接入 token 由 SDK 向网关签发并自动刷新，无需持久化；连到哪里由构建期的接入配置（``AppAccess``）决定，也不在档案里。
enum SavedSessionStore {
    private static let userIdKey = "flare.savedSession.userId"
    private static let tlsCaCertPathKey = "flare.savedSession.tlsCaCertPath"
    private static let tenantIdKey = "flare.savedSession.tenantId"
    private static let dataSubfolderKey = "flare.savedSession.dataSubfolder"

    static func save(draft: LoginDraft) {
        let defaults = UserDefaults.standard
        defaults.set(draft.userId, forKey: userIdKey)
        defaults.set(draft.tlsCaCertPath, forKey: tlsCaCertPathKey)
        defaults.set(draft.tenantId, forKey: tenantIdKey)
        defaults.set(draft.dataSubfolder, forKey: dataSubfolderKey)
    }

    static func load() -> LoginDraft? {
        let defaults = UserDefaults.standard
        guard let userId = defaults.string(forKey: userIdKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !userId.isEmpty else {
            return nil
        }
        var draft = LoginDraft()
        draft.userId = userId
        if let tlsPath = defaults.string(forKey: tlsCaCertPathKey), !tlsPath.isEmpty {
            draft.tlsCaCertPath = tlsPath
        }
        if let tenantId = defaults.string(forKey: tenantIdKey), !tenantId.isEmpty {
            draft.tenantId = tenantId
        }
        if let subfolder = defaults.string(forKey: dataSubfolderKey), !subfolder.isEmpty {
            draft.dataSubfolder = subfolder
        }
        return draft
    }

    static func clear() {
        let defaults = UserDefaults.standard
        for key in [userIdKey, tlsCaCertPathKey, tenantIdKey, dataSubfolderKey] {
            defaults.removeObject(forKey: key)
        }
    }
}
