import Foundation

/// 热启动会话档案：登录成功后保存，下次启动免登录直接
/// prepare(本地库) → 本地出图 → 后台 connect。
/// 接入 token 由 SDK 向网关签发并自动刷新，无需持久化。
enum SavedSessionStore {
    private static let userIdKey = "flare.savedSession.userId"
    private static let wsUrlKey = "flare.savedSession.wsUrl"
    private static let transportModeKey = "flare.savedSession.transportMode"
    private static let quicUrlKey = "flare.savedSession.quicUrl"
    private static let tlsCaCertPathKey = "flare.savedSession.tlsCaCertPath"
    private static let httpUrlKey = "flare.savedSession.httpUrl"
    private static let tenantIdKey = "flare.savedSession.tenantId"
    private static let dataSubfolderKey = "flare.savedSession.dataSubfolder"

    static func save(draft: LoginDraft) {
        let defaults = UserDefaults.standard
        defaults.set(draft.userId, forKey: userIdKey)
        defaults.set(draft.wsUrl, forKey: wsUrlKey)
        defaults.set(draft.transportMode.rawValue, forKey: transportModeKey)
        defaults.set(draft.quicUrl, forKey: quicUrlKey)
        defaults.set(draft.tlsCaCertPath, forKey: tlsCaCertPathKey)
        // httpUrl 即 SDK 托管 token 端点(auth.tokenEndpoint):resume 重连要靠它向网关签发。
        // 不持久化则热启动回退默认地址,自定义网关登录后刷新会指错端点。
        defaults.set(draft.httpUrl, forKey: httpUrlKey)
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
        if let wsUrl = defaults.string(forKey: wsUrlKey), !wsUrl.isEmpty {
            draft.wsUrl = wsUrl
        }
        if let raw = defaults.string(forKey: transportModeKey),
           let mode = LoginTransportMode(rawValue: raw) {
            draft.transportMode = mode
        }
        if let quicUrl = defaults.string(forKey: quicUrlKey), !quicUrl.isEmpty {
            draft.quicUrl = quicUrl
        }
        if let tlsPath = defaults.string(forKey: tlsCaCertPathKey), !tlsPath.isEmpty {
            draft.tlsCaCertPath = tlsPath
        }
        if let httpUrl = defaults.string(forKey: httpUrlKey), !httpUrl.isEmpty {
            draft.httpUrl = httpUrl
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
        for key in [
            userIdKey, wsUrlKey, transportModeKey, quicUrlKey,
            tlsCaCertPathKey, httpUrlKey, tenantIdKey, dataSubfolderKey
        ] {
            defaults.removeObject(forKey: key)
        }
    }
}
