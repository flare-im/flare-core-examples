package com.flare.im.app.features.settings

import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.material3.MaterialTheme

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import com.flare.im.app.R
import com.flare.im.app.core.FlareAppStore
import com.flare.im.app.core.designsystem.FlareTheme
import com.flare.im.app.core.domain.ThemeChoice
import com.flare.im.app.core.domain.formatByteSize
import com.flare.im.app.core.domain.isUnwritableFolderError
import com.flare.im.app.core.domain.shortDownloadLocation
import com.flare.im.app.core.domain.treeDocumentPath
import com.flare.im.app.features.shell.SectionTitle
import com.flare.im.ui.BottomSheet
import com.flare.im.ui.FlareButtonVariant
import com.flare.im.ui.FlareConfirmOptions
import com.flare.im.ui.FlareControlSize
import com.flare.im.ui.FlareGroupedCard
import com.flare.im.ui.FlareGroupedCardDivider
import com.flare.im.ui.FlareSettingKind
import com.flare.im.ui.FlareStatusTone
import com.flare.im.ui.LocalFlareDialog
import com.flare.im.ui.LocalFlareToast
import com.flare.im.ui.SettingsItem
import com.flare.im.ui.SettingsRow
import kotlinx.coroutines.launch

/** 设置屏：主题 + 会话态 + 诊断/登出/释放 + 下载位置与媒体缓存。 */
@Composable
fun SettingsScreen(store: FlareAppStore) {
    val tk = FlareTheme.tokens
    val colors = FlareTheme.colors
    val vm = store.settingsViewModel
    val theme by vm.theme.collectAsState()
    val user by vm.currentUserId.collectAsState()
    val conn by vm.connectionState.collectAsState()
    val toast = LocalFlareToast.current
    val dialogs = LocalFlareDialog.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val location by vm.downloadLocation.collectAsState()
    val cacheStats by vm.cacheStats.collectAsState()
    var locationSheet by remember { mutableStateOf(false) }

    LaunchedEffect(Unit) {
        vm.refreshCacheStats()
        vm.refreshDownloadLocation()
    }

    fun locationFailed(error: Throwable) {
        toast.show(
            context.getString(if (isUnwritableFolderError(error)) R.string.settings_download_location_unwritable else R.string.settings_download_location_pick_failed),
            tone = FlareStatusTone.Danger,
        )
    }

    // 更改位置：the system folder picker. The core saves through paths, so the picked folder is named by its path
    // (`primary:Download/Foo` → /storage/emulated/0/Download/Foo) and the core checks it can write there.
    val folderPicker = rememberLauncherForActivityResult(ActivityResultContracts.OpenDocumentTree()) { uri ->
        if (uri == null) return@rememberLauncherForActivityResult
        val path = treeDocumentPath(
            uri.authority,
            runCatching { android.provider.DocumentsContract.getTreeDocumentId(uri) }.getOrNull(),
            primaryRoot = android.os.Environment.getExternalStorageDirectory().absolutePath,
        )
        if (path == null) {
            // A folder with no path behind it (a cloud drive) cannot be saved into.
            toast.show(context.getString(R.string.settings_download_location_pick_failed), tone = FlareStatusTone.Danger)
            return@rememberLauncherForActivityResult
        }
        vm.setDownloadLocation(path) { result ->
            result.onSuccess { locationSheet = false }.onFailure(::locationFailed)
        }
    }

    Column(Modifier.fillMaxSize().padding(tk.lg).verticalScroll(rememberScrollState())) {
        SectionTitle(stringResource(R.string.nav_settings))
        Text(stringResource(R.string.settings_appearance), style = MaterialTheme.typography.titleMedium, color = colors.textPrimary)
        Row(horizontalArrangement = Arrangement.spacedBy(tk.sm), modifier = Modifier.padding(vertical = tk.sm)) {
            ThemeChoice.entries.forEach { t ->
                FilterChip(theme == t, { vm.setTheme(t) }, { Text(t.name) }, colors = FilterChipDefaults.filterChipColors(selectedContainerColor = colors.brandSoft, selectedLabelColor = colors.brand))
            }
        }
        Spacer(Modifier.height(tk.md))
        Text(stringResource(R.string.settings_session), style = MaterialTheme.typography.titleMedium, color = colors.textPrimary)
        Text("User: ${user ?: "-"}", style = MaterialTheme.typography.bodyMedium, color = colors.textSecondary)
        Text("Connection: ${conn.name}", style = MaterialTheme.typography.bodyMedium, color = colors.textSecondary)
        Spacer(Modifier.height(tk.sm))
        Row(horizontalArrangement = Arrangement.spacedBy(tk.sm)) {
            com.flare.im.ui.Button(label = stringResource(R.string.settings_refresh_diagnostics), variant = com.flare.im.ui.FlareButtonVariant.Secondary, onClick = { vm.refreshDiagnostics() })
            com.flare.im.ui.Button(label = stringResource(R.string.action_logout), variant = com.flare.im.ui.FlareButtonVariant.Secondary, onClick = { vm.logout() })
            com.flare.im.ui.Button(label = stringResource(R.string.settings_dispose), variant = com.flare.im.ui.FlareButtonVariant.Secondary, onClick = { vm.dispose() })
        }

        Spacer(Modifier.height(tk.md))
        Text(stringResource(R.string.settings_media_cache), style = MaterialTheme.typography.titleMedium, color = colors.textPrimary)
        val notLoaded = stringResource(R.string.settings_not_loaded)
        val clearTitle = stringResource(R.string.settings_cache_clear)
        val clearDescription = stringResource(R.string.settings_clear_cache_confirm)
        val cancel = stringResource(R.string.action_cancel)
        val clearFailed = stringResource(R.string.settings_clear_cache_failed)
        val cleared = stringResource(R.string.settings_cache_cleared)
        // The kit's grouped rows (not a lazy list: this page scrolls as a whole).
        FlareGroupedCard(Modifier.padding(vertical = tk.sm)) {
            SettingsRow(
                SettingsItem(
                    "downloadLocation", stringResource(R.string.settings_download_location), "folder", FlareSettingKind.Navigation,
                    detail = location?.let { shortDownloadLocation(it.directory) } ?: notLoaded,
                ),
                onSelect = { locationSheet = true },
            )
            FlareGroupedCardDivider()
            SettingsRow(
                SettingsItem(
                    "mediaCache", stringResource(R.string.settings_cache_size), "storage", FlareSettingKind.Value,
                    detail = cacheStats?.let { formatByteSize(it.totalBytes) } ?: notLoaded,
                ),
            )
            FlareGroupedCardDivider()
            // Clearing is behind the kit's danger confirmation; a clear that failed keeps the dialog open with why.
            SettingsRow(
                SettingsItem("clearCache", clearTitle, "delete", FlareSettingKind.Action, danger = true),
                onSelect = {
                    scope.launch {
                        val done = dialogs.confirm(
                            FlareConfirmOptions(
                                title = clearTitle,
                                description = clearDescription,
                                confirmText = clearTitle,
                                cancelText = cancel,
                                action = { runCatching { vm.clearCache() }.onFailure { error(clearFailed) } },
                            ),
                        )
                        if (done) toast.show(cleared, tone = FlareStatusTone.Success)
                    }
                },
            )
        }
        Text(
            stringResource(R.string.settings_cache_usage, vm.cacheStatsText(cacheStats) ?: "—"),
            style = MaterialTheme.typography.bodyMedium, color = colors.textSecondary,
        )
        Row(horizontalArrangement = Arrangement.spacedBy(tk.sm), modifier = Modifier.padding(vertical = tk.sm)) {
            listOf(128L, 256L, 512L).forEach { mb ->
                com.flare.im.ui.Button(label = "${mb}MB", variant = com.flare.im.ui.FlareButtonVariant.Secondary, onClick = { vm.setCacheMaxBytes(mb * 1024 * 1024) })
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(tk.sm)) {
            com.flare.im.ui.Button(label = stringResource(R.string.settings_cache_refresh), variant = com.flare.im.ui.FlareButtonVariant.Secondary, onClick = { vm.refreshCacheStats() })
        }
    }

    if (locationSheet) {
        val current = location
        BottomSheet(onClose = { locationSheet = false }, title = stringResource(R.string.settings_download_location)) {
            Text(
                current?.directory ?: stringResource(R.string.settings_not_loaded),
                style = MaterialTheme.typography.bodyMedium, color = colors.textSecondary,
                modifier = Modifier.padding(bottom = tk.md),
            )
            val pickFailed = stringResource(R.string.settings_download_location_pick_failed)
            com.flare.im.ui.Button(
                label = stringResource(R.string.settings_download_location_change),
                size = FlareControlSize.Lg, block = true, icon = "folder",
                onClick = {
                    runCatching { folderPicker.launch(null) }
                        .onFailure { toast.show(pickFailed, tone = FlareStatusTone.Danger) }
                },
            )
            if (current?.isCustom == true) {
                Spacer(Modifier.height(tk.sm))
                com.flare.im.ui.Button(
                    label = stringResource(R.string.settings_download_location_reset),
                    variant = FlareButtonVariant.Secondary, size = FlareControlSize.Lg, block = true,
                    onClick = {
                        vm.setDownloadLocation(null) { result ->
                            result.onSuccess { locationSheet = false }.onFailure(::locationFailed)
                        }
                    },
                )
            }
        }
    }
}
