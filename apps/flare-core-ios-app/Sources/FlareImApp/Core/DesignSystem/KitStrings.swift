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
        let language = Bundle.main.preferredLocalizations.first ?? "en"
        return language.hasPrefix("zh") ? FlareStrings() : english
    }

    private static var english: FlareStrings {
        var strings = FlareStrings()
        strings.back = "Back"
        strings.cancel = "Cancel"
        strings.clear = "Clear"
        strings.close = "Close"
        strings.delete = "Delete"
        strings.play = "Play"
        strings.recent = "Recent"
        strings.retry = "Retry"
        strings.select = "Select"
        strings.send = "Send"
        strings.sticker = "Sticker"
        strings.timeRange = "Time range"
        strings.typing = "Typing…"

        strings.actionCard = "Contact card"
        strings.actionFile = "File"
        strings.actionImage = "Image"
        strings.actionLocation = "Location"

        strings.composerPlaceholder = "Message"
        strings.composerReply = "Reply"
        strings.cancelReply = "Cancel reply"

        strings.voiceHoldButtonLabel = "Hold to talk"
        strings.voiceHoldButtonRecording = "Release to send · swipe up to cancel"
        strings.releaseToCancel = "Release to cancel"
        strings.showTranscript = "Show transcript"
        strings.hideTranscript = "Hide transcript"

        strings.createPoll = "Create poll"
        strings.submitPoll = "Create poll"
        strings.pollQuestionHint = "Ask a question"
        strings.addOption = "Add option"
        strings.removeOption = "Remove option"
        strings.allowMultiple = "Allow multiple answers"

        strings.emptyStickerPack = "This sticker pack is empty"

        strings.messageActionSheetLabel = "Message actions"
        strings.messageActionSheetEmpty = "No actions available"
        strings.messageActionReply = "Reply"
        strings.messageActionForward = "Forward"
        strings.messageActionRecall = "Recall"
        strings.messageActionResend = "Resend"
        strings.messageActionMultiSelect = "Multi-select"
        strings.messageActionMark = "Mark"
        strings.messageActionPin = "Pin message"
        strings.messageActionPinSelf = "Pin for me"
        strings.messageActionUnpin = "Unpin"
        strings.messageActionCopy = "Copy"
        strings.messageActionPreview = "Preview"
        strings.messageActionSave = "Save"
        strings.messageActionEdit = "Edit"
        strings.messageActionDelete = "Delete"

        strings.messageListEmpty = "No messages"
        strings.messageListLoadOlder = "Load earlier messages"
        strings.messagePending = "Waiting to send"
        strings.messageSending = "Sending"
        strings.messageSent = "Sent"
        strings.messageRead = "Read"
        strings.messageFailed = "Failed to send"

        strings.conversationRowDraft = "[Draft] "
        strings.conversationRowMention = "[@me] "
        strings.conversationActionSheetPin = "Pin"
        strings.conversationActionSheetUnpin = "Unpin"
        strings.conversationActionSheetMute = "Mute"
        strings.conversationActionSheetUnmute = "Unmute"
        strings.conversationActionSheetArchive = "Archive"
        strings.conversationActionSheetUnarchive = "Unarchive"
        strings.conversationActionSheetMarkRead = "Mark as read"
        strings.conversationActionSheetHide = "Hide"
        strings.conversationActionSheetEmpty = "No actions available"

        strings.workspaceFrameLoading = "Loading"
        strings.workspaceFrameEmpty = "Nothing here yet"
        strings.workspaceFrameFailure = "Couldn't load"
        return strings
    }
}
