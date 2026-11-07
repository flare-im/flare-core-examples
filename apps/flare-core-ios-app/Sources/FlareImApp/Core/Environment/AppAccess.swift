import Foundation

/// The access configuration this build hands the core SDK (`sdkConfig.access`). Line choice, protocol racing and
/// reconnecting are the SDK's, and so are connect tokens: it issues them on the Core API of the access point it uses.
/// The app only passes this on. Read from the process environment first (on a simulator, `SIMCTL_CHILD_` + the name), then Info.plist
/// (the build settings in project.yml).
struct AppAccess: @unchecked Sendable {
    /// `sdkConfig.access`.
    let access: [String: Any]

    /// The local stack's entry points (a simulator reaches the host on the loopback address). Ports:
    /// IM `flare-core-server/config/services/access-gateway.toml` (WebSocket 60051, QUIC 60052), Core HTTP and media
    /// `flare-core-server/config/services/api-gateway.toml` and `media.toml` (50050).
    enum LocalDevelopment {
        static let wsURL = "ws://127.0.0.1:60051"
        static let coreApiURL = "http://127.0.0.1:50050"
    }

    /// No usable access configuration: a release build needs its production one and never falls back to development.
    struct ConfigurationError: Error, CustomStringConvertible {
        let description: String
    }

    /// - `FLARE_ACCESS_JSON`: the whole `access` object as given (production: `bootstrapId`, `trustRoots`, `seed`,
    ///   `trustMode: production`; or a complete development one, for example with `accessPoints` for a second entry).
    /// - Otherwise, debug builds only (`allowDevelopment`), development endpoints from `FLARE_DEV_WS_URL`,
    ///   `FLARE_DEV_QUIC_URL` (QUIC only when given), `FLARE_DEV_CORE_API_URL` and `FLARE_DEV_MEDIA_URL` (Core HTTP
    ///   when missing), each defaulting to ``LocalDevelopment``.
    /// A release build without `FLARE_ACCESS_JSON`, or with a development one, throws.
    static func resolve(lookup: (String) -> String?, allowDevelopment: Bool) throws -> AppAccess {
        let access: [String: Any]
        if let raw = lookup("FLARE_ACCESS_JSON") {
            guard let data = raw.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw ConfigurationError(description: "FLARE_ACCESS_JSON is not a JSON object")
            }
            if !allowDevelopment, (object["trustMode"] as? String) == "development" || object["developmentEndpoints"] != nil {
                throw ConfigurationError(description: "a release build cannot use development access (FLARE_ACCESS_JSON)")
            }
            access = object
        } else {
            guard allowDevelopment else {
                throw ConfigurationError(description: "a release build needs its production access configuration in FLARE_ACCESS_JSON")
            }
            let coreApi = lookup("FLARE_DEV_CORE_API_URL") ?? LocalDevelopment.coreApiURL
            var endpoints: [String: Any] = [
                "wsUrl": lookup("FLARE_DEV_WS_URL") ?? LocalDevelopment.wsURL,
                "coreApiUrl": coreApi,
                "mediaUrl": lookup("FLARE_DEV_MEDIA_URL") ?? coreApi,
            ]
            if let quic = lookup("FLARE_DEV_QUIC_URL") { endpoints["quicUrl"] = quic }
            access = ["trustMode": "development", "developmentEndpoints": endpoints]
        }
        return AppAccess(access: access)
    }

    /// What the release manifest is picked by, as far as the build says. The SDK fills in the rest of `app` from the
    /// bundle: the version, the build, the locale, and the distribution from the App Store receipt when none is set.
    static var updateApp: [String: Any] {
        var app: [String: Any] = ["channel": lookup("FLARE_UPDATE_CHANNEL") ?? "stable"]
        if let distribution = lookup("FLARE_UPDATE_DISTRIBUTION") { app["distribution"] = distribution }
        return app
    }

    /// Environment first, then Info.plist; blank counts as unset.
    static func lookup(_ name: String) -> String? {
        for value in [ProcessInfo.processInfo.environment[name], Bundle.main.object(forInfoDictionaryKey: name) as? String] {
            if let raw = value?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty { return raw }
        }
        return nil
    }

    /// Debug builds may run on development endpoints; release builds never.
    static var allowsDevelopmentAccess: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    /// This build's configuration, read once. A build without a usable one stops here with the reason.
    static let current: AppAccess = {
        do {
            return try resolve(lookup: lookup, allowDevelopment: allowsDevelopmentAccess)
        } catch {
            fatalError("FlareIM access configuration: \(error)")
        }
    }()
}
