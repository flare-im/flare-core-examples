import AVFoundation
import Foundation

// Image decoding lives in Core/Platform/PlatformImage.swift (`platformImageSize`).

func composerMediaDirectory() throws -> URL {
    let directory = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("FlareComposerMedia", isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    return directory
}

func copyFileToComposerCache(
    sourceURL: URL,
    id: String,
    preferredExtension: String? = nil
) throws -> URL {
    let ext = preferredExtension?.nilIfBlank ?? sourceURL.pathExtension.nilIfBlank ?? "bin"
    let destination = try composerMediaDirectory().appendingPathComponent("\(id).\(ext)")
    if FileManager.default.fileExists(atPath: destination.path) {
        try FileManager.default.removeItem(at: destination)
    }
    try FileManager.default.copyItem(at: sourceURL, to: destination)
    return destination
}

func mediaDurationMs(url: URL) async -> Int? {
    let asset = AVURLAsset(url: url)
    guard let duration = try? await asset.load(.duration) else { return nil }
    let seconds = CMTimeGetSeconds(duration)
    guard seconds.isFinite, seconds > 0 else { return nil }
    return Int((seconds * 1000).rounded())
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

