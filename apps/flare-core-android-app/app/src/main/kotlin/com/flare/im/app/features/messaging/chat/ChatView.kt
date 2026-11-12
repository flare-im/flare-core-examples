package com.flare.im.app.features.messaging.chat

import androidx.compose.material3.MaterialTheme

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.IconButton
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.flare.im.app.R
import com.flare.im.app.core.FlareAppStore
import com.flare.im.app.core.designsystem.FlareTheme
import com.flare.im.app.features.messaging.composer.ComposerBar
import com.flare.im.app.features.messaging.messagerow.MessageRow
import com.flare.im.app.features.shell.EmptyState
import com.flare.im.app.features.shell.StatusDot
import com.flare.im.app.features.shell.statusLabel
import com.flare.im.ui.BottomSheet
import com.flare.im.ui.ConversationHeader
import com.flare.im.ui.ConversationIdentity
import com.flare.im.ui.ConversationHeaderAction
import com.flare.im.ui.ConversationHeaderCapabilities
import com.flare.im.ui.FlareSettingKind
import com.flare.im.ui.FlareStatusTone
import com.flare.im.ui.LocalFlareToast
import com.flare.im.ui.SettingsItem
import com.flare.im.ui.SettingsList
import com.flare.im.ui.SettingsSection

/** 聊天屏：返回 + 标题头(状态副标题 + 会话内搜索 + 聊天设置) + 时间线 + 输入区(ComposerBar)。 */
@Composable
fun ChatScreen(store: FlareAppStore) {
    val colors = FlareTheme.colors
    val tk = FlareTheme.tokens
    val vm = store.messagingViewModel
    val conversation by vm.selectedConversation.collectAsState()
    val messages by vm.selectedMessages.collectAsState()
    val me by vm.currentUserId.collectAsState()
    val status by store.environment.runtimeStatus.collectAsState()
    val updateStatus by store.updateCenter.state.collectAsState()
    val selectedId by store.environment.selectedConversationId.collectAsState()
    var searchOpen by remember { mutableStateOf(false) }
    var settingsOpen by remember { mutableStateOf(false) }

    // 屏幕上的会话报给引擎：它的新消息在前台不再提醒（前后台由 MainActivity 报）。
    DisposableEffect(selectedId) {
        val shown = selectedId
        if (shown != null) store.alerts.chatShown(shown)
        onDispose { if (shown != null) store.alerts.chatHidden(shown) }
    }

    Column(Modifier.fillMaxSize()) {
        ConversationHeader(
            identity = ConversationIdentity(
                id = conversation?.conversationId ?: "",
                title = conversation?.appTitle ?: "",
            ),
            capabilities = ConversationHeaderCapabilities(setOf("search", "details")),
            actions = listOf(
                ConversationHeaderAction("search", stringResource(R.string.chat_search_title), "search"),
                ConversationHeaderAction("details", stringResource(R.string.chat_settings_title), "more"),
            ),
            showBack = true,
            onBack = { store.environment.setSelectedConversationId(null) },
            onAction = {
                when (it.id) {
                    "search" -> searchOpen = true
                    "details" -> settingsOpen = true
                }
            },
        )
        if (messages.isEmpty()) {
            Box(Modifier.weight(1f)) { EmptyState(stringResource(R.string.chat_empty_title), stringResource(R.string.chat_empty_message)) }
        } else {
            LazyColumn(Modifier.weight(1f).padding(horizontal = tk.md), contentPadding = PaddingValues(vertical = tk.md), verticalArrangement = Arrangement.spacedBy(tk.sm)) {
                items(messages, key = { it.appStableId }) { m -> MessageRow(m, outgoing = m.core.senderId == me, vm = vm) }
            }
        }
        ComposerBar(vm, conversation?.appTitle ?: "", readOnly = updateStatus?.readOnly == true)
    }

    if (searchOpen) InChatSearchSheet(store) { searchOpen = false }
    if (settingsOpen) ConversationSettingsSheet(store) { settingsOpen = false }
}

private const val MUTE_ROW = "mute"
private const val NOTIFY_ALL_ROW = "notifyAll"

/**
 * 聊天设置：免打扰；超过 1000 人的群另有「接收全部消息通知」（大群默认只在 @我 时提醒）。全部消息通知的开关先动，
 * 核心没写成时回到核心的值并提示。
 */
@Composable
private fun ConversationSettingsSheet(store: FlareAppStore, onDismiss: () -> Unit) {
    val vm = store.messagingViewModel
    val conversation by vm.selectedConversation.collectAsState()
    val pending by vm.notifyAllPending.collectAsState()
    val toast = LocalFlareToast.current
    val title = stringResource(R.string.chat_settings_title)
    val muteLabel = stringResource(R.string.chat_settings_mute)
    val notifyAllLabel = stringResource(R.string.chat_settings_notify_all)
    val notifyAllHint = stringResource(R.string.chat_settings_notify_all_hint)
    val notSaved = stringResource(R.string.chat_settings_notify_all_not_saved)
    val current = conversation ?: return

    val sections = buildList {
        add(SettingsSection(items = listOf(SettingsItem(MUTE_ROW, muteLabel, kind = FlareSettingKind.Toggle, value = current.core.isMuted))))
        if (current.isLargeGroup) {
            val notifyAll = pending[current.conversationId] ?: current.core.notifyAll
            add(
                SettingsSection(
                    items = listOf(SettingsItem(NOTIFY_ALL_ROW, notifyAllLabel, kind = FlareSettingKind.Toggle, value = notifyAll)),
                    footer = notifyAllHint,
                ),
            )
        }
    }
    BottomSheet(onClose = onDismiss, title = title) {
        SettingsList(
            sections = sections,
            onToggle = { item, on ->
                when (item.key) {
                    MUTE_ROW -> vm.conversationAction("mute", current)
                    NOTIFY_ALL_ROW -> vm.setNotifyAll(current, on) { toast.show(notSaved, tone = FlareStatusTone.Danger) }
                }
            },
            scrollable = false,
        )
    }
}

/** 会话内消息搜索：复用 SearchViewModel 的 conversation-scoped 搜索。 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun InChatSearchSheet(store: FlareAppStore, onDismiss: () -> Unit) {
    val colors = FlareTheme.colors
    val tk = FlareTheme.tokens
    val searchVm = store.searchViewModel
    val draft by searchVm.draft.collectAsState()
    val results by searchVm.results.collectAsState()
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    ModalBottomSheet(onDismissRequest = onDismiss, sheetState = sheetState, containerColor = colors.surface) {
        Column(Modifier.fillMaxWidth().padding(horizontal = tk.lg).padding(bottom = tk.lg)) {
            Text(stringResource(R.string.chat_search_title), style = MaterialTheme.typography.titleMedium, color = colors.textPrimary)
            Spacer(Modifier.height(tk.sm))
            com.flare.im.ui.FormField(label = stringResource(R.string.chat_search_hint)) {
                com.flare.im.ui.Input(
                    value = draft.keyword,
                    onValueChange = { v -> searchVm.updateDraft { it.copy(keyword = v, conversationScoped = true) } },
                )
            }
            Spacer(Modifier.height(tk.sm))
            TextButton(onClick = { searchVm.updateDraft { it.copy(conversationScoped = true) }; searchVm.search() }) {
                Text(stringResource(R.string.chat_search_action), color = colors.brand)
            }
            HorizontalDivider(color = colors.hairline)
            if (results.isEmpty()) {
                Box(Modifier.fillMaxWidth().height(120.dp), Alignment.Center) {
                    Text(stringResource(R.string.chat_search_empty), style = MaterialTheme.typography.bodyMedium, color = colors.textTertiary)
                }
            } else {
                LazyColumn(Modifier.fillMaxWidth().heightIn(max = 360.dp)) {
                    items(results, key = { it.appStableId }) { m ->
                        Column(Modifier.fillMaxWidth().padding(vertical = tk.sm)) {
                            Text(m.core.senderId, style = MaterialTheme.typography.labelMedium, color = colors.textSecondary)
                            Text(m.previewText, style = MaterialTheme.typography.bodyMedium, color = colors.textPrimary, maxLines = 2, overflow = TextOverflow.Ellipsis)
                        }
                    }
                }
            }
        }
    }
}
