package com.flare.im.app.core.domain

import com.flare.im.model.entity.Conversation

data class AppConversation(
    val core: Conversation,
) {
    val conversationId: String
        get() = core.conversationId

    val appTitle: String
        get() = core.remark.nonBlank()
            ?: core.displayName.nonBlank()
            ?: core.channelId.nonBlank()
            ?: core.conversationId.nonBlank()
            ?: "Conversation"

    val appPreview: String
        get() = core.draft.nonBlank()?.let { "Draft: $it" }
            // The core stores previews in its storage format ({"k":"im.preview.…","a":{…}}); the list
            // showed that JSON verbatim. Decode it the same way message previews already are.
            ?: core.lastMessagePreview.nonBlank()?.formatStoragePreview()
            ?: core.lastMessage?.previewText()
            ?: core.description.nonBlank()
            ?: "No messages yet"

    val appSortTimestamp: Long
        get() = core.updatedAtTs
            ?: core.lastMessageAt
            ?: core.updatedAt.takeIf { it > 0L }
            ?: core.createdAt

    val isAttentionRequired: Boolean
        get() = core.unreadCount > 0 || core.mentionMe || core.mentionCount > 0

    val avatarLabel: String
        get() = appTitle
            .split(" ")
            .mapNotNull { it.firstOrNull()?.uppercaseChar()?.toString() }
            .take(2)
            .joinToString("")
            .ifBlank { "#" }
}
