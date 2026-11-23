import FlareIMUI
import Foundation

/// The strings the kit renders itself — accessibility labels, delivery states, composer tools,
/// action sheets. Their defaults are Chinese and a host with another UI language has to supply
/// them; without this an English UI showed 回复 / 撤回 / 删除 in the message action sheet.
///
/// The language follows the app bundle's own localization, so the kit and the app can never
/// disagree: a Chinese localization keeps the kit defaults, every other one gets English. The
/// wording matches the Android example's table for every key both kits have.
enum KitStrings {
    static var current: FlareStrings {
        forLanguage(Bundle.main.preferredLocalizations.first ?? "en")
    }

    /// The language the app shows, for what the update center and the push registration word in it: the system's can
    /// be one this app has no localization for.
    static var localeTag: String {
        isChinese ? "zh-CN" : "en-US"
    }

    private static var isChinese: Bool {
        (Bundle.main.preferredLocalizations.first ?? "en").hasPrefix("zh")
    }

    static func forLanguage(_ language: String) -> FlareStrings {
        language.hasPrefix("zh") ? chinese : english
    }

    private static let chinese = FlareStrings()

    /// Inherit generated English first; keep only deliberate app wording here.
    private static let english: FlareStrings = {
        var strings = FlareStrings.english

        strings.actionImage = "Image"

        strings.composerPlaceholder = "Message"

        strings.voiceHoldButtonRecording = "Release to send · swipe up to cancel"

        strings.emptyStickerPack = "This sticker pack is empty"

        strings.messageActionRecall = "Recall"
        strings.messageActionResend = "Resend"
        strings.messageActionMultiSelect = "Multi-select"
        strings.messageActionPinSelf = "Pin for me"

        strings.messageListEmpty = "No messages"
        strings.messageFailed = "Failed to send"

        strings.conversationRowMention = "[@me] "

        strings.workspaceFrameEmpty = "Nothing here yet"
        strings.workspaceFrameFailure = "Couldn't load"
        return strings
    }()
}
