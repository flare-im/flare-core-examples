package com.flare.im.app.core.domain

import com.flare.im.model.common.enums.ConversationType
import com.flare.im.model.entity.Conversation

/** Groups above this many members alert only on mentions unless the member turns on all messages. */
const val LARGE_GROUP_MEMBERS = 1000

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

    /** 超过 1000 人的群：默认只在 @我 时提醒，成员可以打开「接收全部消息通知」。 */
    val isLargeGroup: Boolean
        get() = core.conversationType == ConversationType.GROUP && core.membersCount > LARGE_GROUP_MEMBERS

    val avatarLabel: String
        get() = appTitle
            .split(" ")
            .mapNotNull { it.firstOrNull()?.uppercaseChar()?.toString() }
            .take(2)
            .joinToString("")
            .ifBlank { "#" }
}
