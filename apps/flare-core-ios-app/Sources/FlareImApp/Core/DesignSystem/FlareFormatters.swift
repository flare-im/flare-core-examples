import Foundation
import FlareIMUI
import FlareCoreAppleSDK

enum FlareFormatters {
    static let shortTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }()

    static let shortDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()

    static let monthDayTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("MMMdjm")
        return formatter
    }()

    static let yearMonthDayTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.setLocalizedDateFormatFromTemplate("yMMMdjm")
        return formatter
    }()

    static func dateFromMillis(_ millis: UInt64?) -> Date? {
        guard let millis, millis > 0 else { return nil }
        return Date(timeIntervalSince1970: TimeInterval(millis) / 1000)
    }

    static func relativeMillis(_ millis: UInt64?) -> String {
        guard let date = dateFromMillis(millis) else { return "" }
        return shortTime.string(from: date)
    }

    static func errorText(_ error: Error) -> String {
        if let flare = error as? FlareSdkException {
            if flare.code == "native_error_10", flare.operation == "sdk.login" {
                return String(localized: "Login failed: cannot reach the Flare server. Make sure it is running and check the current protocol and server address.")
            }
            // 核心抛的是 i18n key（如 sdk.message.card.avatar.invalid_url），
            // 直接透出 message 会把这串 key 显示给用户。交给 kit 统一翻成人话。
            let raw = flare.errorDescription ?? flare.message
            return humanizedError(raw)
        }
        return humanizedError(error.localizedDescription)
    }

    private static func humanizedError(_ raw: String) -> String {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, !value.hasPrefix("sdk.") else {
            return String(localized: "The operation failed.")
        }
        return value
    }

    static func jsonPreview(_ value: Any) -> String {
        let object: Any
        if let map = value as? [String: AnySendable] {
            object = unwrap(map)
        } else if let list = value as? [AnySendable] {
            object = list.map { $0.value }
        } else if let sendable = value as? AnySendable {
            object = sendable.value
        } else {
            object = value
        }
        guard JSONSerialization.isValidJSONObject(object),
              let data = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: data, encoding: .utf8)
        else {
            return String(describing: object)
        }
        return text
    }

    static func unwrap(_ map: [String: AnySendable]) -> [String: Any] {
        map.mapValues { unwrapValue($0.value) }
    }

    static func unwrapValue(_ value: Any) -> Any {
        if let sendable = value as? AnySendable {
            return unwrapValue(sendable.value)
        }
        if let map = value as? [String: AnySendable] {
            return unwrap(map)
        }
        if let array = value as? [AnySendable] {
            return array.map { unwrapValue($0.value) }
        }
        return value
    }
}

func sendableMap(_ values: [String: Any]) -> [String: AnySendable] {
    values.mapValues { AnySendable($0) }
}

func sendableJSON(_ text: String) -> [String: AnySendable] {
    guard let data = text.data(using: .utf8),
          let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    else {
        return [:]
    }
    return sendableMap(object)
}

func stringField(_ map: [String: AnySendable], _ key: String) -> String {
    if let value = map[key]?.value as? String { return value }
    if let value = map[key]?.value as? CustomStringConvertible { return value.description }
    return ""
}

func boolField(_ map: [String: AnySendable], _ key: String) -> Bool? {
    if let value = map[key]?.value as? Bool { return value }
    if let value = map[key]?.value as? String { return value == "true" }
    return nil
}
