package com.flare.im.app.core.domain

import com.flare.im.model.entity.Message

data class AppMessage(
    val core: Message,
) {
    val conversationId: String
        get() = core.conversationId

    val appStableId: String
        get() = core.timelineKey.nonBlank()
            ?: core.serverId.nonBlank()
            ?: core.clientMsgId.nonBlank()
            ?: core.conversationSeq.takeIf { it > 0L }?.let { "${core.conversationId}:seq:$it" }
            ?: "${core.conversationId}:local:$appSortTimestamp"

    val appSortTimestamp: Long
        get() = core.timelineSortTs.takeIf { it > 0L }
            ?: core.localState?.sortTs?.takeIf { it > 0L }
            ?: core.createdAt.takeIf { it > 0L }
            ?: core.clientCreatedAt

    val senderTitle: String
        get() = core.senderDisplayName.nonBlank()
            ?: core.senderName.nonBlank()
            ?: core.senderId.nonBlank()
            ?: "Unknown"

    val previewText: String
        get() = if (core.isRecalled) {
            "Message recalled"
        } else {
            core.content?.previewText()
                ?: core.quotePreview.nonBlank()
                ?: "Unsupported message"
        }

    val isLocalOnly: Boolean
        get() = core.localState?.isLocal == true || core.serverId.isBlank()

    val isFailed: Boolean
        get() = core.localState?.failed == true
}
