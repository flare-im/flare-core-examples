import Foundation

struct AppEndpoints: @unchecked Sendable {
    let endpoints: [String: Any]
    let environment: String

    init(endpoints: [String: Any], environment: String = "production") {
        self.endpoints = endpoints
        self.environment = environment
    }

    struct ConfigurationError: Error, CustomStringConvertible {
        let description: String
    }

    static func resolve(lookup: (String) -> String?, allowDevelopment: Bool) throws -> AppEndpoints {
        let environment = allowDevelopment ? "development" : "production"
        if let raw = lookup("FLARE_CORE_ENDPOINTS_JSON") {
            guard let object = try? JSONSerialization.jsonObject(with: Data(raw.utf8)) as? [String: Any],
                  let base = object["baseUrl"] as? String, !base.isEmpty,
                  let websocket = object["websocketUrl"] as? String, !websocket.isEmpty else {
                throw ConfigurationError(description: "Configure baseUrl and websocketUrl")
            }
            return AppEndpoints(endpoints: object, environment: environment)
        }
        guard allowDevelopment else {
            throw ConfigurationError(description: "Configure FLARE_CORE_ENDPOINTS_JSON")
        }
        var endpoints = [
            "baseUrl": lookup("FLARE_DEV_CORE_API_URL") ?? "http://127.0.0.1:50050",
            "websocketUrl": lookup("FLARE_DEV_WS_URL") ?? "ws://127.0.0.1:60051",
        ]
        endpoints["quicUrl"] = lookup("FLARE_DEV_QUIC_URL")
        endpoints["mediaBaseUrl"] = lookup("FLARE_DEV_MEDIA_URL")
        return AppEndpoints(endpoints: endpoints, environment: environment)
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
    static var allowsDevelopmentEndpoints: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }

    /// This build's configuration, read once. A build without a usable one stops here with the reason.
    static let current: AppEndpoints = {
        do {
            return try resolve(lookup: lookup, allowDevelopment: allowsDevelopmentEndpoints)
        } catch {
            fatalError("FlareIM endpoint configuration: \(error)")
        }
    }()
}
