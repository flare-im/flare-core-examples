import FlareCoreAppleSDK
import FlareIMUI
import Foundation

// "Save to device", the download location and the picture cache on plain values. Saving and caching are the
// core's (`media.download_to_user_directory`, `media.resolve_access` with `autoCache`, `media.cache_stats`);
// these rules only say what to ask for and how to word the answer.

/// What one "save to device" asks the core for (`media.download_to_user_directory`).
struct MediaSaveTarget: Equatable, Sendable {
    /// The stored file: the core copies its cached copy, else fetches the attachment.
    var fileId: String?
    /// A web address, for a message that names no stored file.
    var sourceUrl: String?
    /// The name to save under. The core adds the extension from the file's type when it has none, and a
    /// number when the name is taken.
    var fileName: String

    /// The request the SDK takes.
    var request: [String: AnySendable] {
        var request: [String: AnySendable] = ["fileName": AnySendable(fileName)]
        if let fileId { request["fileId"] = AnySendable(fileId) }
        if let sourceUrl { request["sourceUrl"] = AnySendable(sourceUrl) }
        return request
    }

    /// `yyyyMMdd_HHmmss` in the device's time zone — the camera-roll style name of a saved picture or video.
    static func stamp(_ date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: date)
    }

    /// What saving `content` asks for: a picture as `IMG_…`, a video as `VID_…`, a voice message as `AUD_…`, a
    /// file under the name its sender gave it (without folders). The stored file id when the message has one,
    /// else its web address when that passes the kit's URL gate; nil when there is nothing to save.
    static func of(_ content: MessageContent?, now: Date = Date(), timeZone: TimeZone = .current) -> MediaSaveTarget? {
        guard let content else { return nil }
        let stamp = Self.stamp(now, timeZone: timeZone)
        let name: String
        switch content.contentType {
        case .image, .imageGroup: name = "IMG_\(stamp)"
        case .video: name = "VID_\(stamp)"
        case .audio: name = "AUD_\(stamp)"
        case .file:
            name = content.fileDisplayName.components(separatedBy: CharacterSet(charactersIn: "/\\")).last?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        default: return nil
        }
        if let fileId = content.mediaFileId?.trimmingCharacters(in: .whitespacesAndNewlines), !fileId.isEmpty {
            return MediaSaveTarget(fileId: fileId, sourceUrl: nil, fileName: name)
        }
        guard let safe = safeExternalURL(content.mediaSourceURL?.absoluteString) else { return nil }
        return MediaSaveTarget(fileId: nil, sourceUrl: safe, fileName: name)
    }
}

/// The result of one save, in the words the person sees.
enum MediaSaveOutcome: Equatable, Sendable {
    /// Saved: the folder it went to and the file.
    case saved(directory: String, path: String)
    case failed(String)

    /// The core's answer (`{path, directory, fileName, sizeBytes, fromCache, downloadKey}`).
    static func from(_ raw: [String: AnySendable]) -> MediaSaveOutcome {
        let path = (raw["path"]?.value as? String) ?? ""
        let directory = (raw["directory"]?.value as? String) ?? (path as NSString).deletingLastPathComponent
        guard !path.isEmpty else { return .failed(MediaSaveCopy.failed) }
        return .saved(directory: directory, path: path)
    }

    /// A failed save: a folder that can no longer be written is worth saying; anything else is "try again".
    static func failure(_ error: Error) -> MediaSaveOutcome {
        let text = "\(error) \(FlareFormatters.errorText(error))".lowercased()
        return .failed(text.contains("not writable") || text.contains("not usable")
            ? MediaSaveCopy.unwritable : MediaSaveCopy.failed)
    }
}

/// The copy a save shows (String Catalog in the runner, zh-Hans next to the English keys).
enum MediaSaveCopy {
    static var saving: String { String(localized: "Saving…") }
    static func savedTo(_ location: String) -> String { String(localized: "Saved to \(location)") }
    static var failed: String { String(localized: "Could not save. Try again.") }
    static var unwritable: String { String(localized: "This folder cannot be written to. Choose another one.") }
    static var nothingToSave: String { String(localized: "This message has nothing to save.") }
    static var showInFolder: String { String(localized: "Show in folder") }
}

/// Where saved files go, in words a person can find them by.
enum DownloadLocationLabel {
    /// The default folder's name inside Documents (the core's `subfolder`).
    static let defaultSubfolder = "flare"

    /// The Files-app path for the default folder in this app's Documents (visible in the Files app because
    /// Info.plist turns on file sharing); any other folder by its last two levels.
    static func label(directory: String, documents: String = documentsPath) -> String {
        let folder = canonical(directory)
        if !folder.isEmpty, folder == canonical((documents as NSString).appendingPathComponent(defaultSubfolder)) {
            return String(localized: "Files app › this app › flare")
        }
        return short(directory)
    }

    /// `…/parent/folder` for a deep path; a short one as it is.
    static func short(_ directory: String) -> String {
        let parts = directory.split(separator: "/").map(String.init)
        guard parts.count > 3 else { return directory }
        return "…/" + parts.suffix(2).joined(separator: "/")
    }

    static var documentsPath: String {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first?.path ?? ""
    }

    /// The same folder written the same way: `/private/var` and `/var` are one place on iOS.
    static func canonical(_ path: String) -> String {
        let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        var standard = URL(fileURLWithPath: trimmed).standardizedFileURL.path
        if standard.hasPrefix("/private/") { standard.removeFirst("/private".count) }
        while standard.count > 1, standard.hasSuffix("/") { standard.removeLast() }
        return standard
    }

    /// The Files app opened on `directory` (`shareddocuments://`), on iOS only.
    static func filesAppURL(_ directory: String) -> URL? {
        #if os(iOS)
        guard !directory.isEmpty,
              let path = directory.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) else { return nil }
        return URL(string: "shareddocuments://\(path)")
        #else
        return nil
        #endif
    }
}

/// The download location as the settings page shows it (`media.user_download_get_directory`).
struct DownloadLocationState: Equatable, Sendable {
    var directory: String
    var isCustom: Bool

    init(directory: String, isCustom: Bool) {
        self.directory = directory; self.isCustom = isCustom
    }

    /// Nil when the answer names no folder.
    init?(_ raw: [String: AnySendable]) {
        let directory = ((raw["directory"]?.value as? String) ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !directory.isEmpty else { return nil }
        self.directory = directory
        isCustom = (raw["isCustom"]?.value as? Bool) ?? false
    }

    var label: String { DownloadLocationLabel.label(directory: directory) }
}

/// The core media cache as `media.cache_stats` reports it (snake_case on the wire).
struct MediaCacheUsage: Equatable, Sendable {
    var totalBytes: Int64
    var entryCount: Int
    var maxBytes: Int64?

    init(totalBytes: Int64, entryCount: Int, maxBytes: Int64?) {
        self.totalBytes = totalBytes; self.entryCount = entryCount; self.maxBytes = maxBytes
    }

    /// Nil when the answer carries no size.
    init?(_ raw: [String: AnySendable]) {
        func number(_ keys: String...) -> Int64? {
            for key in keys {
                let value = raw[key]?.value
                if let n = value as? Int64 { return n }
                if let n = value as? Int { return Int64(n) }
                if let n = value as? UInt64 { return Int64(clamping: n) }
                if let n = value as? Double { return Int64(n) }
                if let n = value as? NSNumber { return n.int64Value }
            }
            return nil
        }
        guard let total = number("total_bytes", "totalBytes") else { return nil }
        totalBytes = max(0, total)
        entryCount = Int(max(0, number("entry_count", "entryCount") ?? 0))
        maxBytes = number("max_bytes", "maxBytes")
    }

    /// `12.3 MB / 256.0 MB · 4 files` — the kit's byte format, the same on every platform.
    var summary: String {
        var text = formatBytes(Double(totalBytes)) ?? "0 B"
        if let maxBytes, let limit = formatBytes(Double(maxBytes)) { text += " / \(limit)" }
        text += " · " + String(localized: "\(entryCount) files")
        return text
    }
}

/// The pictures the SDK media cache holds, by stored file id (`media.resolve_access` with `autoCache`).
///
/// A picture the cache does not hold yet is fetched into it in the background by the core; the row asks again
/// on a later appearance and draws the local copy from then on. It is asked at most every ``retryAfter``
/// seconds and ``maxAsks`` times, so a picture too large to cache keeps its web address.
struct LocalPictureCopies {
    static let retryAfter: TimeInterval = 3
    static let maxAsks = 6

    private(set) var paths: [String: String] = [:]
    private var asks: [String: (count: Int, last: Date)] = [:]

    func path(_ fileId: String, exists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }) -> String? {
        guard let path = paths[fileId], exists(path) else { return nil }
        return path
    }

    /// Whether to ask the core about `fileId` now: no local copy (or one that is gone), not asked in the last
    /// ``retryAfter`` seconds, and asked fewer than ``maxAsks`` times.
    func shouldAsk(_ fileId: String, now: Date,
                   exists: (String) -> Bool = { FileManager.default.fileExists(atPath: $0) }) -> Bool {
        guard !fileId.isEmpty, path(fileId, exists: exists) == nil else { return false }
        guard let asked = asks[fileId] else { return true }
        return asked.count < Self.maxAsks && now.timeIntervalSince(asked.last) >= Self.retryAfter
    }

    mutating func record(_ fileId: String, localPath: String?, now: Date) {
        if let localPath, !localPath.isEmpty {
            paths[fileId] = localPath
            asks[fileId] = nil
        } else {
            paths[fileId] = nil
            asks[fileId] = ((asks[fileId]?.count ?? 0) + 1, now)
        }
    }

    mutating func reset() {
        paths = [:]
        asks = [:]
    }
}

/// Where a message picture is drawn from: the local copy the SDK media cache holds, else a fetchable URL.
struct PictureAccess: Equatable, Sendable {
    var localPath: String?
    var url: String?

    /// `media.resolve_access`'s answer (`{source, localPath?, remote?{url, cdnUrl}}`, camelCase).
    init(localPath: String?, url: String?) {
        self.localPath = localPath; self.url = url
    }

    init(_ raw: [String: AnySendable]) {
        func text(_ value: Any?) -> String? {
            let unwrapped = (value as? AnySendable)?.value ?? value
            guard let string = (unwrapped as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !string.isEmpty else { return nil }
            return string
        }
        localPath = text(raw["localPath"]?.value) ?? text(raw["local_path"]?.value)
        let remoteRaw = raw["remote"]?.value
        let remote = (remoteRaw as? [String: AnySendable]).map { $0.mapValues { $0.value as Any } }
            ?? (remoteRaw as? [String: Any]) ?? [:]
        url = text(remote["url"]) ?? text(remote["cdnUrl"]) ?? text(remote["cdn_url"])
    }
}
