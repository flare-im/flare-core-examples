package com.flare.im.app.features.sdklab

import androidx.compose.material3.MaterialTheme

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AssistChip
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.unit.dp
import com.flare.im.app.R
import com.flare.im.app.core.FlareAppStore
import com.flare.im.app.core.designsystem.FlareTheme

/** SDK Lab 屏：分组探针按钮 + 结果控制台。从 FlareApp.kt 拆出（每特性一屏文件）。 */
@Composable
fun SdkLabScreen(store: FlareAppStore) {
    val tk = FlareTheme.tokens
    val colors = FlareTheme.colors
    val lab = store.sdkLabViewModel
    val results by lab.labResults.collectAsState()
    val cid = store.environment.selectedConversationId.collectAsState().value ?: ""
    Column(Modifier.fillMaxSize().padding(tk.lg)) {
        Text(stringResource(R.string.lab_title), style = MaterialTheme.typography.titleLarge, color = colors.textPrimary, modifier = Modifier.padding(bottom = tk.sm))
        Column(Modifier.weight(1f).verticalScroll(rememberScrollState())) {
            LabGroup("Diagnostics", listOf("Refresh" to { lab.refreshDiagnostics() }))
            LabGroup("Lifecycle", listOf(
                "Prepare" to { lab.runPrepare() }, "Heartbeat" to { lab.runHeartbeatInterval() },
                "AppState" to { lab.runSetHeartbeatAppState() }, "NAT" to { lab.runSetHeartbeatNatTimeout() },
                "isConnected" to { lab.runIsConnected() }, "sessionActive" to { lab.runSessionActive() },
                "connect" to { lab.runConnect() }, "currentUserId" to { lab.runCurrentUserId() },
                "updateToken" to { lab.runUpdateAccessToken() }, "network" to { lab.runNotifyNetworkChange() },
                "disconnect" to { lab.runDisconnect() }, "uninit" to { lab.runUninit() }, "hardReset" to { lab.runHardReset() },
            ))
            LabGroup("Conversations", listOf(
                "list" to { lab.runListConversations() }, "paginated" to { lab.runListConversationsPaginated() },
                "raw" to { lab.runListRawConversations() }, "archived" to { lab.runListConversationsIncludingArchived() },
            ))
            LabGroup("Messages", listOf(
                "listMessages" to { lab.runListMessages(cid) }, "createText" to { lab.runCreateTextMessage(cid) },
                "sendNoOss" to { lab.runSendMessageNoOss(cid) },
            ))
            LabGroup("Builder", listOf(
                "catalog" to { lab.refreshBuilderCatalog() }, "md" to { lab.runNormalizeMarkdown() },
                "html" to { lab.runNormalizeHtml() }, "docJson" to { lab.runNormalizeDocJson() },
            ))
            LabGroup("Media", listOf(
                "stats" to { lab.runMediaCacheStats() }, "url" to { lab.runMediaUrl() }, "temp" to { lab.runTempDownloadUrl() },
                "resolve" to { lab.runResolveMediaAccess() }, "cache" to { lab.runCacheRemoteMedia() }, "uploadFile" to { lab.runUploadFile() },
                "uploadImage" to { lab.runUploadImage() }, "uploadVideo" to { lab.runUploadVideo() }, "uploadBytes" to { lab.runUploadBytes() },
                "delete" to { lab.runDeleteFile() }, "maxBytes" to { lab.runSetCacheMaxBytes() }, "root" to { lab.runSetCacheRoot() },
                "clear" to { lab.runClearMediaCache() }, "getSub" to { lab.runGetDownloadSubfolder() }, "setSub" to { lab.runSetDownloadSubfolder() },
                "savedPath" to { lab.runGetDownloadSavedPath() }, "delRecord" to { lab.runDeleteDownloadRecord() }, "cancel" to { lab.runCancelDownload() },
                "download" to { lab.runDownloadToDownloads() },
            ))
            LabGroup("Capabilities", listOf(
                "list" to { lab.refreshCapabilities() }, "dispatch" to { lab.runDispatchCapability() }, "grant" to { lab.runGrantCapability() },
                "revoke" to { lab.runRevokeCapability() }, "callSignal" to { lab.runSendCallSignal() },
            ))
            LabGroup("Presence", listOf("current" to { lab.runPresenceCurrent() }, "batch+sub" to { lab.runPresenceBatchSubscribe() }))
            LabGroup("Sync", listOf("summaries" to { lab.runSyncSummaries() }, "conversation" to { lab.runSyncConversation(cid) }, "messages" to { lab.runSyncMessages(cid) }))
            LabGroup("Events", listOf("subscribe" to { lab.runSubscribeEvents() }, "batch" to { lab.runSubscribeEventsBatch() }, "unsubAll" to { lab.runUnsubscribeAll() }))
        }
        HorizontalDivider(color = colors.hairline)
        if (results.isEmpty()) {
            Text(stringResource(R.string.lab_no_ops), style = MaterialTheme.typography.bodyMedium, color = colors.textTertiary, modifier = Modifier.padding(tk.sm))
        } else {
            LazyColumn(Modifier.heightIn(max = 220.dp)) {
                items(results.reversed(), key = { it.id }) { r ->
                    Text("[${r.status}] ${r.operation} ${r.detail}", style = MaterialTheme.typography.bodySmall, color = colors.textSecondary, modifier = Modifier.padding(vertical = 2.dp))
                }
            }
        }
    }
}

@Composable
private fun LabGroup(title: String, actions: List<Pair<String, () -> Unit>>) {
    val tk = FlareTheme.tokens
    val colors = FlareTheme.colors
    Column(Modifier.padding(vertical = tk.sm)) {
        Text(title, style = MaterialTheme.typography.labelMedium, color = colors.textTertiary)
        Row(Modifier.horizontalScroll(rememberScrollState()), horizontalArrangement = Arrangement.spacedBy(tk.xs)) {
            actions.forEach { (label, action) ->
                AssistChip(onClick = action, label = { Text(label, style = MaterialTheme.typography.bodySmall) })
            }
        }
    }
}
