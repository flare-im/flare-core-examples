package com.flare.im.app.features.settings

import com.flare.im.api.ConnectionState
import com.flare.im.app.core.data.AppEnvironment
import com.flare.im.app.core.domain.DownloadLocation
import com.flare.im.app.core.domain.MediaCacheStats
import com.flare.im.app.core.domain.downloadLocationFrom
import com.flare.im.app.core.domain.formatCacheStats
import com.flare.im.app.core.domain.mediaCacheStatsFrom
import com.flare.im.app.core.domain.LoginDraft
import com.flare.im.app.core.domain.ThemeChoice
import com.flare.im.app.core.session.AppLifecycle
import com.flare.im.app.core.session.AppSession
import com.flare.im.app.features.sdklab.SdkLabViewModel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.launch

/** 设置特性 ViewModel：主题/登录默认值 + 会话态 + 诊断/登出/释放。 */
class SettingsViewModel(
    private val session: AppSession,
    private val environment: AppEnvironment,
    private val sdkLab: SdkLabViewModel,
    private val scope: CoroutineScope,
    /** Called after the core's media cache was cleared, so pictures resolved to cached copies are asked again. */
    private val onCacheCleared: () -> Unit = {},
) {
    private var lifecycle: AppLifecycle? = null
    fun bind(lifecycle: AppLifecycle) { this.lifecycle = lifecycle }

    val theme: StateFlow<ThemeChoice> = environment.theme
    val loginDraft: StateFlow<LoginDraft> = environment.loginDraft
    val currentUserId: StateFlow<String?> = session.currentUserId
    val connectionState: StateFlow<ConnectionState> = session.connectionState

    fun setTheme(value: ThemeChoice) = environment.setTheme(value)
    fun updateDraft(transform: (LoginDraft) -> LoginDraft) = environment.updateLoginDraft(transform)

    fun refreshDiagnostics() { sdkLab.refreshDiagnostics() }
    fun logout() = scope.launch { lifecycle?.logout() }
    fun dispose() = scope.launch { lifecycle?.dispose() }

    // ---- 媒体缓存管理（用 SDK 托管的磁盘缓存：用量 / 上限 / 清空）----
    // `media.cache_stats` 回的是 snake_case（total_bytes / max_bytes / entry_count）；此前按 camelCase 读，
    // 用量永远显示「—」。
    private val _cacheStats = MutableStateFlow<MediaCacheStats?>(null)
    val cacheStats: StateFlow<MediaCacheStats?> = _cacheStats.asStateFlow()

    fun cacheStatsText(stats: MediaCacheStats?): String? = stats?.let(::formatCacheStats)

    fun refreshCacheStats() = scope.launch { session.client?.let { loadCacheStats(it) } }

    fun setCacheMaxBytes(bytes: Long) = scope.launch {
        val sdk = session.client ?: return@launch
        runCatching { sdk.media.setMediaCacheMaxBytes(mapOf("maxBytes" to bytes)) }
            .onFailure { environment.appendLab("media.set_cache_max_bytes", "error", it.message ?: "$it") }
        loadCacheStats(sdk)
    }

    /** Empties the core's media cache; throws when the core could not (the confirm dialog shows it and stays open). */
    suspend fun clearCache() {
        val sdk = session.client ?: error("Login before clearing the cache")
        sdk.media.clearMediaCache()
        onCacheCleared()
        loadCacheStats(sdk)
    }

    private suspend fun loadCacheStats(sdk: com.flare.im.api.FlareImClient) {
        runCatching { sdk.media.getMediaCacheStats() }
            .onSuccess { _cacheStats.value = mediaCacheStatsFrom(it) }
            .onFailure { environment.appendLab("media.cache_stats", "error", it.message ?: "$it") }
    }

    // ---- 下载位置（核心 `media.user_download_*`：默认共享存储 Download/flare，可改成用户选的文件夹）----
    private val _downloadLocation = MutableStateFlow<DownloadLocation?>(null)
    val downloadLocation: StateFlow<DownloadLocation?> = _downloadLocation.asStateFlow()

    fun refreshDownloadLocation() = scope.launch {
        val sdk = session.client ?: return@launch
        runCatching { sdk.media.getUserDownloadDirectory() }
            .onSuccess { _downloadLocation.value = downloadLocationFrom(it) }
            .onFailure { environment.appendLab("media.user_download_get_directory", "error", it.message ?: "$it") }
    }

    /**
     * Makes [directory] the download location (null = the platform default). The core checks it can write there and
     * refuses otherwise; the failure goes to [onDone] so the screen can say which folder was refused.
     */
    fun setDownloadLocation(directory: String?, onDone: (Result<DownloadLocation>) -> Unit) = scope.launch {
        val result = runCatching {
            val sdk = session.client ?: error("Login before choosing a download location")
            downloadLocationFrom(sdk.media.setUserDownloadDirectory(mapOf("directory" to directory)))
        }
        result.onSuccess { _downloadLocation.value = it }
            .onFailure { environment.appendLab("media.user_download_set_directory", "error", it.message ?: "$it") }
        onDone(result)
    }
}
