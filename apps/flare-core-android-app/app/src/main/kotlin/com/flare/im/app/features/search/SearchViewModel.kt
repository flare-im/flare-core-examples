package com.flare.im.app.features.search

import com.flare.im.api.FlareImClient
import com.flare.im.app.core.data.AppEnvironment
import com.flare.im.app.core.session.AppSession
import com.flare.im.app.core.domain.AppMessage
import com.flare.im.app.core.domain.SdkModelMapper
import com.flare.im.model.common.enums.MessageSearchKind
import com.flare.im.model.query.MessageSearchQuery
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch

data class SearchDraft(
    val keyword: String = "",
    val senderId: String = "",
    val conversationScoped: Boolean = false,
    val includeRecalled: Boolean = false,
)

/** 搜索特性 ViewModel：searchMessages / ByQuery / InConversation。 */
class SearchViewModel(
    private val session: AppSession,
    private val environment: AppEnvironment,
    private val scope: CoroutineScope,
) {
    private val client: FlareImClient? get() = session.client

    private val _draft = MutableStateFlow(SearchDraft())
    val draft: StateFlow<SearchDraft> = _draft.asStateFlow()
    fun updateDraft(transform: (SearchDraft) -> SearchDraft) = _draft.update(transform)

    private val _results = MutableStateFlow<List<AppMessage>>(emptyList())
    val results: StateFlow<List<AppMessage>> = _results.asStateFlow()

    fun search() = scope.launch {
        val d = _draft.value
        val conversationId = if (d.conversationScoped) environment.selectedConversationId.value else null
        environment.run("message.search") {
            val sdk = client ?: error("Login before searching messages")
            val query = MessageSearchQuery(
                conversationId = conversationId,
                fromTime = null,
                includeRecalled = d.includeRecalled,
                keyword = d.keyword.ifBlank { null },
                kinds = emptyList<MessageSearchKind>(),
                limit = 50,
                senderId = d.senderId.ifBlank { null },
                toTime = null,
            )
            val response = when {
                conversationId != null -> sdk.messages.searchMessagesInConversation(query)
                d.senderId.isNotBlank() -> sdk.messages.searchMessagesByQuery(query)
                else -> sdk.messages.searchMessages(query)
            }
            _results.value = SdkModelMapper.messagesFromCore(response.messages)
            environment.appendLab("message.search", "ok", "${_results.value.size} results")
        }
    }
}
