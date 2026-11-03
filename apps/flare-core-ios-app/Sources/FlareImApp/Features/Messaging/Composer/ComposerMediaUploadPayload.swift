import FlareCoreAppleSDK
import Foundation

enum ComposerMediaUploadPayload {
    static func imagePayload(localPayload: [String: Any], uploaded: [String: AnySendable]) -> [String: Any] {
        let uploadedMap = normalizedMediaMap(unwrap(uploaded))
        let mediaId = string(uploadedMap, "fileId", "file_id", "mediaId", "media_id", "id", "uuid", "objectId", "object_id", "key") ??
            string(localPayload, "imageId") ??
            "image-\(UUID().uuidString)"
        var payload: [String: Any] = [
            "imageId": mediaId,
            "mimeType": string(uploadedMap, "mimeType", "mime_type", "contentType", "content_type", "type") ??
                string(localPayload, "mimeType") ??
                "image/jpeg"
        ]
        if let description = string(localPayload, "description") {
            payload["description"] = description
        }
        if let sourceUrl = preferredRemoteURL(uploadedMap) {
            payload["sourceUrl"] = sourceUrl
        }
        if let size = int64(uploadedMap, "size", "fileSize", "file_size", "bytes") ?? int64(localPayload, "size") {
            payload["size"] = size
        }
        if let width = int(localPayload, "width") {
            payload["width"] = width
        }
        if let height = int(localPayload, "height") {
            payload["height"] = height
        }
        return payload
    }

    static func audioPayload(localPayload: [String: Any], uploaded: [String: AnySendable]) -> [String: Any] {
        let uploadedMap = normalizedMediaMap(unwrap(uploaded))
        let mediaId = string(uploadedMap, "fileId", "file_id", "mediaId", "media_id", "id", "uuid", "objectId", "object_id", "key") ??
            string(localPayload, "audioId") ??
            "audio-\(UUID().uuidString)"
        var payload: [String: Any] = [
            "audioId": mediaId,
            "description": string(localPayload, "description") ?? String(localized: "Voice message"),
            "mimeType": string(uploadedMap, "mimeType", "mime_type", "contentType", "content_type", "type") ??
                string(localPayload, "mimeType") ??
                "audio/mp4"
        ]
        if let sourceUrl = preferredRemoteURL(uploadedMap) {
            payload["sourceUrl"] = sourceUrl
        }
        if let size = int64(uploadedMap, "size", "fileSize", "file_size", "bytes") ?? int64(localPayload, "size") {
            payload["size"] = size
        }
        if let durationMs = int(localPayload, "durationMs") {
            payload["durationMs"] = durationMs
        }
        return payload
    }

    private static func preferredRemoteURL(_ map: [String: Any]) -> String? {
        string(
            map,
            "cdnUrl", "cdn_url",
            "mediaUrl", "media_url",
            "downloadUrl", "download_url",
            "accessUrl", "access_url",
            "tempUrl", "temp_url",
            "sourceUrl", "source_url",
            "url"
        )
    }

    private static func normalizedMediaMap(_ map: [String: Any]) -> [String: Any] {
        var result = map
        for key in ["data", "file", "media", "result", "payload"] {
            if let nested = map[key] as? [String: Any] {
                for (nestedKey, nestedValue) in nested where result[nestedKey] == nil {
                    result[nestedKey] = nestedValue
                }
            }
        }
        return result
    }

    private static func unwrap(_ map: [String: AnySendable]) -> [String: Any] {
        map.mapValues { unwrap($0.value) }
    }

    private static func unwrap(_ value: Any) -> Any {
        if let sendable = value as? AnySendable {
            return unwrap(sendable.value)
        }
        if let map = value as? [String: AnySendable] {
            return unwrap(map)
        }
        if let map = value as? [String: Any] {
            return map.mapValues { unwrap($0) }
        }
        if let list = value as? [AnySendable] {
            return list.map { unwrap($0.value) }
        }
        if let list = value as? [Any] {
            return list.map { unwrap($0) }
        }
        return value
    }

    private static func string(_ map: [String: Any], _ keys: String...) -> String? {
        for key in keys {
            if let value = map[key] as? String, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value
            }
        }
        return nil
    }

    private static func int(_ map: [String: Any], _ keys: String...) -> Int? {
        for key in keys {
            if let value = map[key] as? Int { return value }
            if let value = map[key] as? Int32 { return Int(value) }
            if let value = map[key] as? Int64 { return Int(value) }
            if let value = map[key] as? UInt64 { return Int(value) }
            if let value = map[key] as? Double { return Int(value) }
            if let value = map[key] as? String, let parsed = Int(value) { return parsed }
        }
        return nil
    }

    private static func int64(_ map: [String: Any], _ keys: String...) -> Int64? {
        for key in keys {
            if let value = map[key] as? Int64 { return value }
            if let value = map[key] as? Int { return Int64(value) }
            if let value = map[key] as? Int32 { return Int64(value) }
            if let value = map[key] as? UInt64 { return Int64(value) }
            if let value = map[key] as? Double { return Int64(value) }
            if let value = map[key] as? String, let parsed = Int64(value) { return parsed }
        }
        return nil
    }
}
