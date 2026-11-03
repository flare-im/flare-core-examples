import Foundation
import FlareIMUI
import SwiftUI

enum EmojiPresentation {
    struct DisplaySegment: Identifiable, Equatable {
        enum Kind: Equatable {
            case text(String)
            case emoji(String)
        }

        let id: Int
        let kind: Kind
    }

    static let composerEmojiKeys = [
        "shushing_face", "sleepy_face", "smirking_face", "angry_face", "exploding_head", "expressionless_face",
        "anxious_face_with_sweat", "enraged_face", "alien_monster", "blue_heart", "revolving_hearts", "alien",
        "anger_symbol", "pensive_face", "angry_face_with_horns", "anguished_face", "face_screaming_in_fear", "face_with_open_mouth",
        "beaming_face_with_smiling_eyes", "growing_heart", "broken_heart"
    ]

    static let composerStickers = [
        StickerAsset(packageId: "classic", stickerId: "001"),
        StickerAsset(packageId: "classic", stickerId: "002"),
        StickerAsset(packageId: "classic", stickerId: "003"),
        StickerAsset(packageId: "classic", stickerId: "004"),
        StickerAsset(packageId: "classic", stickerId: "005"),
        StickerAsset(packageId: "classic", stickerId: "006"),
        StickerAsset(packageId: "classic", stickerId: "007"),
        StickerAsset(packageId: "classic", stickerId: "008"),
        StickerAsset(packageId: "classic", stickerId: "009"),
        StickerAsset(packageId: "classic", stickerId: "010"),
        StickerAsset(packageId: "classic", stickerId: "011"),
        StickerAsset(packageId: "classic", stickerId: "012")
    ]

    static func singleEmoji(in value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 1, let character = trimmed.first else { return nil }
        return character.isStandaloneEmoji ? trimmed : nil
    }

    static func isSingleEmoji(_ value: String) -> Bool {
        singleEmoji(in: value) != nil
    }

    static func normalizedPackKey(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let raw: String
        if trimmed.hasPrefix("["), trimmed.hasSuffix("]"), trimmed.count > 2 {
            raw = String(trimmed.dropFirst().dropLast())
        } else {
            raw = trimmed
        }
        guard raw.range(of: #"^[a-z][a-z0-9_]*$"#, options: .regularExpression) != nil else { return nil }
        return emojiURL(for: raw) == nil ? nil : raw
    }

    static func lonePackKey(in value: String) -> String? {
        normalizedPackKey(value)
    }

    static func displaySegments(in value: String) -> [DisplaySegment] {
        guard !value.isEmpty else { return [] }
        guard let regex = try? NSRegularExpression(pattern: #"\[([a-z][a-z0-9_]*)\]"#) else {
            return [DisplaySegment(id: 0, kind: .text(value))]
        }

        let range = NSRange(value.startIndex..<value.endIndex, in: value)
        let matches = regex.matches(in: value, range: range)
        guard !matches.isEmpty else {
            return [DisplaySegment(id: 0, kind: .text(value))]
        }

        var segments: [DisplaySegment] = []
        var cursor = value.startIndex
        var nextId = 0

        func appendText(_ text: String) {
            guard !text.isEmpty else { return }
            if let last = segments.last, case .text(let existing) = last.kind {
                segments[segments.count - 1] = DisplaySegment(id: last.id, kind: .text(existing + text))
            } else {
                segments.append(DisplaySegment(id: nextId, kind: .text(text)))
                nextId += 1
            }
        }

        func appendEmoji(_ key: String) {
            segments.append(DisplaySegment(id: nextId, kind: .emoji(key)))
            nextId += 1
        }

        for match in matches {
            guard let tokenRange = Range(match.range(at: 0), in: value) else { continue }
            if cursor < tokenRange.lowerBound {
                appendText(String(value[cursor..<tokenRange.lowerBound]))
            }

            if let keyRange = Range(match.range(at: 1), in: value) {
                let key = String(value[keyRange])
                if emojiURL(for: key) != nil {
                    appendEmoji(key)
                } else {
                    appendText(String(value[tokenRange]))
                }
            } else {
                appendText(String(value[tokenRange]))
            }
            cursor = tokenRange.upperBound
        }

        if cursor < value.endIndex {
            appendText(String(value[cursor..<value.endIndex]))
        }
        return segments
    }

    static func hasDisplayEmoji(in value: String) -> Bool {
        displaySegments(in: value).contains { segment in
            if case .emoji = segment.kind {
                return true
            }
            return false
        }
    }

    // Emoji/sticker assets now come from the flare-im-design kit's bundled central
    // source (FlareIMUI). The app keeps its richer animated FlareAssetImageView
    // rendering but no longer carries a local resource copy.
    static func emojiURL(for key: String) -> URL? {
        FlareEmojiStickerCatalog.shared.emojiImageURL(key)
    }

    static func stickerURL(packageId: String, stickerId: String) -> URL? {
        FlareEmojiStickerCatalog.shared.stickerImageURL(stickerId: stickerId, packageId: packageId)
    }
}

struct StickerAsset: Identifiable, Hashable {
    let packageId: String
    let stickerId: String

    var id: String { "\(packageId)/\(stickerId)" }
}

struct FlareAssetImageView: View {
    let url: URL?
    let fallbackSystemImage: String
    let accessibilityLabel: String
    var size: CGFloat
    var travel: CGFloat = 4
    var rotation: Double = 3
    var isAnimated = true

    @State private var lifted = false

    var body: some View {
        assetImage
            .frame(width: size, height: size)
            .scaleEffect(usesFallbackMotion ? (lifted ? 1.04 : 0.98) : 1)
            .offset(y: usesFallbackMotion ? (lifted ? -travel : travel * 0.25) : 0)
            .rotationEffect(.degrees(usesFallbackMotion ? (lifted ? rotation : -rotation * 0.35) : 0))
            .animation(
                usesFallbackMotion
                    ? .easeInOut(duration: 0.82).repeatForever(autoreverses: true)
                    : .default,
                value: lifted
            )
            .onAppear {
                guard usesFallbackMotion else {
                    lifted = false
                    return
                }
                lifted = true
            }
            .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    private var assetImage: some View {
        if let url {
            if isAnimated {
                PlatformAnimatedImageView(
                    url: url,
                    fallbackSystemImage: fallbackSystemImage,
                    accessibilityLabel: accessibilityLabel
                )
            } else if let image = Image(localFileURL: url) {
                image
                    .resizable()
                    .scaledToFit()
            } else {
                fallbackImage
            }
        } else {
            fallbackImage
        }
    }

    private var fallbackImage: some View {
        Image(systemName: fallbackSystemImage)
            .font(.system(size: size * 0.58, weight: .semibold))
            .foregroundStyle(FlareDesign.textSecondary)
    }

    private var usesFallbackMotion: Bool {
        isAnimated && url == nil
    }
}

private extension Character {
    var isStandaloneEmoji: Bool {
        unicodeScalars.contains { scalar in
            scalar.properties.isEmojiPresentation ||
                (scalar.properties.isEmoji && scalar.properties.generalCategory == .otherSymbol)
        }
    }
}
