package com.flare.im.app.core.designsystem

import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.res.stringResource
import com.flare.im.app.R
import com.flare.im.ui.FlareStrings

/**
 * The strings the kit renders itself — accessibility labels, delivery states, composer tools,
 * action sheets. Their defaults are Chinese and a host with another UI language has to supply
 * them (see the kit's FlareStrings.kt); without this an English UI announced 返回 / 发送 / 已读.
 *
 * The language follows the app's own resources (`flare_kit_language`), so the kit and the app
 * can never disagree: `values-zh-rCN` keeps the kit defaults, every other locale gets English.
 * The table covers every kit string reachable from the screens this app composes.
 */
@Composable
fun rememberKitStrings(): FlareStrings {
    val language = stringResource(R.string.flare_kit_language)
    return remember(language) { if (language == "zh") FlareStrings() else englishKitStrings() }
}

private fun englishKitStrings() = FlareStrings {
    back = "Back"
    cancel = "Cancel"
    clear = "Clear"
    close = "Close"
    delete = "Delete"
    play = "Play"
    recent = "Recent"
    retry = "Retry"
    select = "Select"
    send = "Send"
    sticker = "Sticker"
    timeRange = "Time range"
    typing = "Typing…"

    actionCard = "Contact card"
    actionFile = "File"
    actionImage = "Image"
    actionLocation = "Location"

    composerPlaceholder = "Message"
    composerEmoji = "Emoji"
    composerMention = "Mention"
    composerVoice = "Voice"
    composerImage = "Image"
    composerRichText = "Rich text"
    composerMore = "More"
    composerReply = "Reply"
    composerReplyStripLabel = "Reply"
    cancelReply = "Cancel reply"
    composerExpandInput = "Expand input"
    composerCollapseInput = "Collapse input"
    composerFormatBold = "Bold"
    composerFormatItalic = "Italic"
    composerFormatStrike = "Strikethrough"
    composerFormatCode = "Code"
    composerFormatHeading = "Heading"
    composerFormatQuote = "Quote"
    composerFormatLink = "Link"
    composerFormatBullet = "Bulleted list"
    composerFormatOrdered = "Numbered list"

    inlineVoiceComposerStart = "Start recording"
    inlineVoiceComposerPause = "Pause recording"
    inlineVoiceComposerResume = "Resume recording"
    inlineVoiceComposerPreview = "Play or pause preview"
    inlineVoiceComposerDiscard = "Discard recording"
    inlineVoiceComposerKeyboard = "Back to keyboard and discard recording"
    inlineVoiceComposerAllowMicrophone = "Allow microphone access"
    inlineVoiceComposerSendFailed = "Couldn't send, tap to retry"
    voiceHoldButtonLabel = "Hold to talk"
    voiceHoldButtonRecording = "Release to send · swipe up to cancel"
    voiceHoldButtonCancel = "Release to cancel"
    releaseToCancel = "Release to cancel"
    showTranscript = "Show transcript"
    hideTranscript = "Hide transcript"

    createPoll = "Create poll"
    submitPoll = "Create poll"
    pollQuestionHint = "Ask a question"
    addOption = "Add option"
    removeOption = "Remove option"
    allowMultiple = "Allow multiple answers"

    emojiStickerPickerEmoji = "Emoji"
    emptyStickerPack = "This sticker pack is empty"

    messageActionSheetLabel = "Message actions"
    messageActionSheetEmpty = "No actions available"
    messageActionReply = "Reply"
    messageActionForward = "Forward"
    messageActionRecall = "Recall"
    messageActionResend = "Resend"
    messageActionMultiSelect = "Multi-select"
    messageActionMark = "Mark"
    messageActionPin = "Pin message"
    messageActionPinSelf = "Pin for me"
    messageActionUnpin = "Unpin"
    messageActionCopy = "Copy"
    messageActionPreview = "Preview"
    messageActionSave = "Save"
    messageActionEdit = "Edit"
    messageActionDelete = "Delete"

    messageListEmpty = "No messages"
    messageListLoadOlder = "Load earlier messages"
    messagePending = "Waiting to send"
    messageSending = "Sending"
    messageSent = "Sent"
    messageRead = "Read"
    messageFailed = "Failed to send"

    conversationRowDraft = "[Draft] "
    conversationRowMention = "[@me] "
    conversationActionSheetPin = "Pin"
    conversationActionSheetUnpin = "Unpin"
    conversationActionSheetMute = "Mute"
    conversationActionSheetUnmute = "Unmute"
    conversationActionSheetArchive = "Archive"
    conversationActionSheetUnarchive = "Unarchive"
    conversationActionSheetMarkRead = "Mark as read"
    conversationActionSheetHide = "Hide"
    conversationActionSheetEmpty = "No actions available"

    workspaceFrameLoading = "Loading"
    workspaceFrameEmpty = "Nothing here yet"
    workspaceFrameFailure = "Couldn't load"
}
