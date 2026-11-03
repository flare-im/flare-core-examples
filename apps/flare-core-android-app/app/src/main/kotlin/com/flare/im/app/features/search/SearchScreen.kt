package com.flare.im.app.features.search

import androidx.compose.material3.MaterialTheme

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import com.flare.im.app.R
import com.flare.im.app.core.FlareAppStore
import com.flare.im.app.core.designsystem.FlareTheme
import com.flare.im.app.features.shell.SectionTitle

/** 搜索屏：关键词 → searchMessages/ByQuery/InConversation 结果。 */
@Composable
fun SearchScreen(store: FlareAppStore) {
    val tk = FlareTheme.tokens
    val colors = FlareTheme.colors
    val vm = store.searchViewModel
    val draft by vm.draft.collectAsState()
    val results by vm.results.collectAsState()
    Column(Modifier.fillMaxSize().padding(tk.lg)) {
        SectionTitle(stringResource(R.string.nav_search))
        com.flare.im.ui.FormField(label = stringResource(R.string.chat_search_hint)) {
            com.flare.im.ui.Input(
                value = draft.keyword,
                onValueChange = { v -> vm.updateDraft { it.copy(keyword = v) } },
                onSubmit = { vm.search() },
            )
        }
        Spacer(Modifier.height(tk.sm))
        com.flare.im.ui.Button(
            label = stringResource(R.string.nav_search),
            variant = com.flare.im.ui.FlareButtonVariant.Primary,
            onClick = { vm.search() },
        )
        Spacer(Modifier.height(tk.md))
        LazyColumn(verticalArrangement = Arrangement.spacedBy(tk.sm)) {
            items(results, key = { it.appStableId }) { m ->
                Column { Text(m.senderTitle, style = MaterialTheme.typography.labelMedium, color = colors.brand); Text(m.previewText, style = MaterialTheme.typography.bodyMedium, color = colors.textPrimary) }
            }
        }
    }
}
