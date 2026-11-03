package com.flare.im.app.features.messaging.conversationlist

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import com.flare.im.app.R
import com.flare.im.app.core.FlareAppStore
import com.flare.im.app.core.designsystem.FlareTheme
import com.flare.im.app.core.domain.AppConversation
import com.flare.im.app.core.domain.ConversationFilter
import com.flare.im.app.features.shell.EmptyState
import com.flare.im.app.features.shell.StatusDot
import com.flare.im.app.features.shell.statusLabel
import com.flare.im.ui.FlareConversationAction
import com.flare.im.ui.FlareSizes

/** 会话列表屏：眉标头 + 过滤 + 列表 + 起会话。 */
@Composable
fun ConversationListScreen(store: FlareAppStore) {
    val colors = FlareTheme.colors
    val tk = FlareTheme.tokens
    val vm = store.messagingViewModel
    val conversations by vm.visibleConversations.collectAsState()
    val filter by store.environment.filter.collectAsState()
    val status by store.environment.runtimeStatus.collectAsState()
    val all by vm.conversations.collectAsState()

    var startOpen by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { if (all.isEmpty()) vm.bootstrapHome() }
    if (startOpen) StartConversationDialog(store) { startOpen = false }

    Column(Modifier.fillMaxSize()) {
        Row(Modifier.fillMaxWidth().padding(tk.lg), verticalAlignment = Alignment.Top) {
            Column(Modifier.weight(1f)) {
                Text(stringResource(R.string.brand_eyebrow), style = MaterialTheme.typography.labelSmall, color = colors.textSecondary)
                Text(stringResource(R.string.conversations_title), style = MaterialTheme.typography.headlineLarge, color = colors.textPrimary)
                Row(verticalAlignment = Alignment.CenterVertically) {
                    StatusDot(status)
                    Spacer(Modifier.width(tk.xs))
                    Text(
                        stringResource(R.string.conversations_subtitle, all.size, all.count { it.core.isPinned }, statusLabel(status)),
                        style = MaterialTheme.typography.labelMedium, color = colors.textSecondary,
                    )
                }
            }
            IconButton(onClick = { startOpen = true }) {
                Box(Modifier.size(40.dp).clip(CircleShape).background(colors.brand), Alignment.Center) {
                    Text("+", color = colors.outgoingText, style = MaterialTheme.typography.titleLarge)
                }
            }
        }
        val filterOptions = ConversationFilter.entries.map { f ->
            com.flare.im.ui.FlareFilterTabOption(value = f.name, label = stringResource(f.titleRes))
        }
        Box(Modifier.padding(horizontal = tk.lg).padding(bottom = tk.sm)) {
            com.flare.im.ui.FilterTabs(
                options = filterOptions,
                selected = filter.name,
                onSelect = { value ->
                    store.environment.setFilter(ConversationFilter.valueOf(value)); vm.refreshConversations()
                },
            )
        }
        HorizontalDivider(color = colors.hairline)
        // 容器收敛到 kit host-rows 变体：统一空态/加载 + LazyColumn 外壳，
        // 每行仍由 app 的 ConversationRow 构建（保留点击/长按等附能）。
        com.flare.im.ui.ConversationListContainer(
            items = conversations,
            key = { it.conversationId },
            empty = {
                EmptyState(
                    stringResource(R.string.conversations_empty_title),
                    stringResource(R.string.conversations_empty_message),
                )
            },
        ) { c -> ConversationRow(store, c) }
    }
}

/** 非 @Composable 处的运行时中英切换(时间/标签)。@Composable 处一律用 stringResource。 */
private fun tr(zh: String, en: String): String =
    if (java.util.Locale.getDefault().language.equals("zh", ignoreCase = true)) zh else en

/** Feishu-style relative time label for the inbox row (HH:mm today / Yesterday / M/d / yyyy/M/d). */
private fun conversationTimeLabel(millis: Long): String {
    if (millis <= 0L) return ""
    val cal = java.util.Calendar.getInstance()
    val nowYear = cal.get(java.util.Calendar.YEAR)
    val nowDoy = cal.get(java.util.Calendar.DAY_OF_YEAR)
    cal.timeInMillis = millis
    val year = cal.get(java.util.Calendar.YEAR)
    val doy = cal.get(java.util.Calendar.DAY_OF_YEAR)
    val loc = java.util.Locale.getDefault()
    return when {
        year == nowYear && doy == nowDoy -> java.text.SimpleDateFormat("HH:mm", loc).format(cal.time)
        year == nowYear && doy == nowDoy - 1 -> tr("昨天", "Yesterday")
        year == nowYear -> java.text.SimpleDateFormat("M/d", loc).format(cal.time)
        else -> java.text.SimpleDateFormat("yyyy/M/d", loc).format(cal.time)
    }
}

/** Inline title tags for a conversation row (Group / Bot / Official), mapped into the kit. */
private fun conversationRowTags(c: AppConversation): List<com.flare.im.ui.ConversationRowTag> = buildList {
    if (c.core.conversationType == com.flare.im.model.common.enums.ConversationType.GROUP) {
        add(com.flare.im.ui.ConversationRowTag(tr("群聊", "Group"), com.flare.im.ui.FlareTagTone.Info))
    }
    c.core.role?.trim()?.takeIf { it.isNotEmpty() }?.let { role ->
        val lower = role.lowercase()
        val label = when {
            lower.contains("bot") || lower.contains("robot") -> tr("机器人", "Bot")
            lower.contains("official") -> tr("官方", "Official")
            else -> role.take(10)
        }
        add(com.flare.im.ui.ConversationRowTag(label, com.flare.im.ui.FlareTagTone.Warning))
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ConversationRow(store: FlareAppStore, c: AppConversation) {
    val vm = store.messagingViewModel
    var menu by remember { mutableStateOf(false) }
    Box {
        com.flare.im.ui.ConversationRow(
            item = com.flare.im.ui.ConversationRowData(
                id = c.conversationId,
                title = c.appTitle,
                avatarUrl = c.core.avatarUrl.takeIf { it.isNotBlank() },
                preview = c.appPreview,
                timestampLabel = conversationTimeLabel(c.appSortTimestamp),
                unreadCount = c.core.unreadCount,
                pinned = c.core.isPinned,
                muted = c.core.isMuted,
                mentioned = c.core.mentionMe,
                draftPreview = c.core.draft,
                tags = conversationRowTags(c),
            ),
            onSelect = { vm.openConversation(c.conversationId) },
            onLongPress = { menu = true },
        )
        if (menu) {
            // Open at full content height: half-expanded, the host rows sat below the fold and the
            // last one under the gesture bar.
            ModalBottomSheet(onDismissRequest = { menu = false }, sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)) {
                com.flare.im.ui.ConversationActionSheet(
                    conversation = com.flare.im.ui.FlareConversationActionSnapshot(
                        id = c.conversationId, title = c.appTitle, pinned = c.core.isPinned,
                        muted = c.core.isMuted, archived = c.core.isArchived),
                    capabilities = com.flare.im.ui.FlareConversationActionCapabilities(
                        pin = true, mute = true, archive = true, delete = true),
                    onAction = { _, action ->
                        menu = false
                        val command = when (action) {
                            FlareConversationAction.Pin, FlareConversationAction.Unpin -> "pin"
                            FlareConversationAction.Mute, FlareConversationAction.Unmute -> "mute"
                            FlareConversationAction.Archive, FlareConversationAction.Unarchive -> "archive"
                            FlareConversationAction.Delete -> "delete"
                            else -> null
                        }
                        command?.let { vm.conversationAction(it, c) }
                    },
                )
                // Host actions the kit sheet has no entry for. One card on the kit groups' surface and
                // radius — as bare rows they read as a second, unstyled menu — and the sheet content
                // keeps clear of the gesture bar, which the last row used to run into.
                Column(
                    Modifier.fillMaxWidth()
                        .padding(horizontal = FlareSizes.spacingSm)
                        .padding(top = FlareSizes.spacingSm)
                        .clip(RoundedCornerShape(FlareSizes.radius2xl))
                        .background(com.flare.im.ui.flareColors().bgPrimary)
                        .padding(horizontal = FlareSizes.spacingMd, vertical = FlareSizes.spacingXs),
                ) {
                    com.flare.im.ui.SettingsRow(
                        item = com.flare.im.ui.SettingsItem(key = "unread", label = stringResource(R.string.conv_mark_unread),
                            kind = com.flare.im.ui.FlareSettingKind.Value),
                        onSelect = { menu = false; vm.conversationAction("unread", c) },
                    )
                    com.flare.im.ui.SettingsRow(
                        item = com.flare.im.ui.SettingsItem(key = "clear", label = stringResource(R.string.conv_clear_local),
                            kind = com.flare.im.ui.FlareSettingKind.Value, danger = true),
                        onSelect = { menu = false; vm.conversationAction("clear", c) },
                    )
                }
                Spacer(Modifier.navigationBarsPadding().height(FlareSizes.spacingSm))
            }
        }
    }
}

/** 起会话对话框（单聊/群聊）。 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun StartConversationDialog(store: FlareAppStore, onDismiss: () -> Unit) {
    val tk = FlareTheme.tokens
    val vm = store.messagingViewModel
    val draft by vm.startConversationDraft.collectAsState()
    var group by remember { mutableStateOf(false) }
    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = {
            TextButton(onClick = { if (group) vm.openGroupConversation() else vm.openPeerConversation(); onDismiss() }) {
                Text(stringResource(R.string.action_open))
            }
        },
        dismissButton = { TextButton(onClick = onDismiss) { Text(stringResource(R.string.action_cancel)) } },
        title = { Text(stringResource(R.string.conversations_start), style = MaterialTheme.typography.titleMedium) },
        text = {
            Column {
                com.flare.im.ui.SegmentedControl(
                    options = listOf(stringResource(R.string.conv_direct), stringResource(R.string.conv_group)),
                    selectedIndex = if (group) 1 else 0,
                    onSelect = { i -> group = (i == 1) },
                )
                Spacer(Modifier.height(tk.sm))
                if (group) {
                    com.flare.im.ui.FormField(label = stringResource(R.string.conv_member_ids)) {
                        com.flare.im.ui.Input(
                            value = draft.groupUserIds,
                            onValueChange = { v -> vm.updateStartDraft { it.copy(groupUserIds = v) } },
                        )
                    }
                } else {
                    com.flare.im.ui.FormField(label = stringResource(R.string.conv_peer_id)) {
                        com.flare.im.ui.Input(
                            value = draft.peerUserId,
                            onValueChange = { v -> vm.updateStartDraft { it.copy(peerUserId = v) } },
                        )
                    }
                }
            }
        },
    )
}
