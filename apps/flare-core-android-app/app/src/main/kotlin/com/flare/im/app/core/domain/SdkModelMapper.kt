package com.flare.im.app.core.domain

import com.flare.im.app.core.domain.AppConversation
import com.flare.im.app.core.domain.AppMessage
import com.flare.im.app.core.domain.AppTimelineSnapshot
import com.flare.im.model.entity.Conversation
import com.flare.im.model.entity.ConversationTimelineSnapshot
import com.flare.im.model.entity.Message

object SdkModelMapper {
    fun conversationFromCore(conversation: Conversation): AppConversation =
        AppConversation(conversation)

    fun conversationsFromCore(conversations: List<Conversation>): List<AppConversation> =
        conversations.map(::conversationFromCore)

    fun messageFromCore(message: Message): AppMessage =
        AppMessage(message)

    fun messagesFromCore(messages: List<Message>): List<AppMessage> =
        messages.map(::messageFromCore)

    fun timelineFromCore(snapshot: ConversationTimelineSnapshot): AppTimelineSnapshot =
        AppTimelineSnapshot(
            conversation = snapshot.conversation?.let(::conversationFromCore),
            messages = messagesFromCore(snapshot.messages),
            hasMore = snapshot.hasMore,
        )
}
