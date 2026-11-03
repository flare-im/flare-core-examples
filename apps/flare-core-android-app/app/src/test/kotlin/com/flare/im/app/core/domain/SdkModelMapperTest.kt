package com.flare.im.app.core.domain

import com.flare.im.model.common.enums.ConversationType
import com.flare.im.model.common.enums.MessageContentType
import com.flare.im.model.entity.Conversation
import com.flare.im.model.entity.ConversationTimelineSnapshot
import com.flare.im.model.entity.Message
import com.flare.im.model.entity.MessageContent
import com.flare.im.model.entity.MessageLocalState
import com.flare.im.model.entity.MessagePreview
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertTrue

class SdkModelMapperTest {
    @Test
    fun conversationFromCoreUsesAppDisplaySemanticsDirectly() {
        val conversation = Conversation(
            conversationId = "c-1",
            conversationType = ConversationType.SINGLE,
            displayName = "",
            channelId = "alice",
            remark = " Alice ",
            draft = " ping ",
            lastMessagePreview = "hello",
            unreadCount = 3,
            updatedAt = 100,
            updatedAtTs = 200,
        )

        val appConversation = SdkModelMapper.conversationFromCore(conversation)

        assertEquals(conversation, appConversation.core)
        assertEquals("Alice", appConversation.appTitle)
        assertEquals("Draft: ping", appConversation.appPreview)
        assertEquals(200, appConversation.appSortTimestamp)
        assertEquals("A", appConversation.avatarLabel)
        assertTrue(appConversation.isAttentionRequired)
    }

    @Test
    fun conversationPreviewFallsBackToStructuredPreview() {
        val conversation = Conversation(
            conversationId = "c-2",
            conversationType = ConversationType.GROUP,
            displayName = "General",
            lastMessage = MessagePreview(text = " from structured preview "),
            updatedAt = 10,
        )

        val appConversation = SdkModelMapper.conversationFromCore(conversation)

        assertEquals("from structured preview", appConversation.appPreview)
        assertFalse(appConversation.isAttentionRequired)
    }

    @Test
    fun messageFromCoreKeepsTypedContentAndStableIdentity() {
        val message = Message(
            serverId = "server-1",
            clientMsgId = "client-1",
            conversationId = "c-1",
            senderId = "alice",
            senderDisplayName = " Alice ",
            conversationSeq = 7,
            createdAt = 1_000,
            clientCreatedAt = 900,
            content = MessageContent(
                contentType = MessageContentType.TEXT,
                data = mapOf("text" to " hello "),
            ),
            timelineKey = "timeline-c-1-7",
            timelineSortTs = 1_200,
        )

        val appMessage = SdkModelMapper.messageFromCore(message)

        assertEquals(message, appMessage.core)
        assertEquals("timeline-c-1-7", appMessage.appStableId)
        assertEquals(1_200, appMessage.appSortTimestamp)
        assertEquals("Alice", appMessage.senderTitle)
        assertEquals("hello", appMessage.previewText)
        assertFalse(appMessage.isLocalOnly)
    }

    @Test
    fun messageFallsBackToLocalStateAndContentTypeLabel() {
        val message = Message(
            conversationId = "c-1",
            clientMsgId = "client-local",
            senderId = "bob",
            content = MessageContent(
                contentType = MessageContentType.IMAGE,
                data = emptyMap(),
            ),
            localState = MessageLocalState(isLocal = true, sortTs = 99),
        )

        val appMessage = SdkModelMapper.messageFromCore(message)

        assertEquals("client-local", appMessage.appStableId)
        assertEquals(99, appMessage.appSortTimestamp)
        assertEquals("bob", appMessage.senderTitle)
        assertEquals("Image", appMessage.previewText)
        assertTrue(appMessage.isLocalOnly)
    }

    @Test
    fun timelineFromCoreMapsNestedTypedModels() {
        val conversation = Conversation(
            conversationId = "c-1",
            conversationType = ConversationType.GROUP,
            displayName = "General",
        )
        val message = Message(
            conversationId = "c-1",
            serverId = "m-1",
            content = MessageContent(
                contentType = MessageContentType.TEXT,
                data = mapOf("text" to "hi"),
            ),
        )

        val timeline = SdkModelMapper.timelineFromCore(
            ConversationTimelineSnapshot(
                conversation = conversation,
                messages = listOf(message),
                hasMore = true,
            ),
        )

        assertEquals("c-1", timeline.conversation?.conversationId)
        assertEquals(listOf("hi"), timeline.messages.map { it.previewText })
        assertTrue(timeline.hasMore)
    }
}
