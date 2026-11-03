package com.flare.im.app.core.domain

data class AppTimelineSnapshot(
    val conversation: AppConversation?,
    val messages: List<AppMessage>,
    val hasMore: Boolean,
)
