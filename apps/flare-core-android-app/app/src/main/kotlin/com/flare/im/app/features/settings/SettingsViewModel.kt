package com.flare.im.app.features.settings

import com.flare.im.model.command.UpdateUserNotificationSettingsRequest
import com.flare.im.model.entity.ConnectionStatus
import com.flare.im.model.entity.MultiDeviceAlertPolicy
import com.flare.im.model.entity.NotificationPreview
import com.flare.im.model.entity.QuietHours
import com.flare.im.model.entity.UserNotificationSettings
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
import com.flare.im.ui.FlareMultiDeviceAlert
import com.flare.im.ui.FlareNotificationAlertPreferences
import com.flare.im.ui.FlareNotificationPreview
import com.flare.im.ui.FlareQuietHours
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
    val connectionStatus: StateFlow<ConnectionStatus?> = session.connectionStatus

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

    // ---- 通知提醒（用户级设置：勿扰时段、通知预览、多设备；同一账号的所有设备共用一份，核心 notification 模块读写）----
    /** 设置页显示的值。改动先显示再写（乐观）；写失败退回核心存着的值。 */
    private val _alertPreferences = MutableStateFlow(FlareNotificationAlertPreferences())
    val alertPreferences: StateFlow<FlareNotificationAlertPreferences> = _alertPreferences.asStateFlow()

    /** 读到过一次之前各行只显示、不接受操作。 */
    private val _alertSettingsLoaded = MutableStateFlow(false)
    val alertSettingsLoaded: StateFlow<Boolean> = _alertSettingsLoaded.asStateFlow()

    /** 核心存着的设置。它的版本随写入带回去：别的设备同时改过时整次写入被拒。 */
    private var storedAlerts: UserNotificationSettings? = null
    private var savingAlerts = false

    /** 读一次（设置页出现时）；正在写的时候不读，写完自会带回存好的值。 */
    fun refreshAlertSettings() = scope.launch {
        if (savingAlerts) return@launch
        val sdk = session.client ?: return@launch
        runCatching { sdk.notification.getSettings() }
            .onSuccess(::adoptAlerts)
            .onFailure { environment.appendLab("notification.get_settings", "error", it.message ?: "$it") }
    }

    /**
     * 一行改了：先显示，再把与核心存着的值的差别写进去；写的期间又改了就接着写最新的。写失败（别的设备同时改过也在内）
     * 退回存着的值并重读一次，重读拿到的就是别处改过的新值，然后 [onFailed] 让设置页说一声。
     */
    fun changeAlertPreferences(next: FlareNotificationAlertPreferences, onFailed: () -> Unit) = scope.launch {
        val sdk = session.client ?: return@launch
        var stored = storedAlerts ?: return@launch
        _alertPreferences.value = next
        if (savingAlerts) return@launch
        savingAlerts = true
        try {
            while (true) {
                val target = _alertPreferences.value
                val request = alertSettingsChanges(stored, target) ?: break
                stored = runCatching { sdk.notification.updateSettings(request) }.getOrElse { error ->
                    environment.appendLab("notification.update_settings", "error", error.message ?: "$error")
                    _alertPreferences.value = alertPreferencesOf(stored, _alertPreferences.value.quietHours)
                    runCatching { sdk.notification.getSettings() }.onSuccess(::adoptAlerts)
                    onFailed()
                    return@launch
                }
                storedAlerts = stored
                // 写的期间没再改：换成核心存好的值；又改过就留着新值，下一轮接着写。
                if (_alertPreferences.value == target) _alertPreferences.value = alertPreferencesOf(stored, target.quietHours)
            }
        } finally {
            savingAlerts = false
        }
    }

    private fun adoptAlerts(settings: UserNotificationSettings) {
        storedAlerts = settings
        _alertPreferences.value = alertPreferencesOf(settings, _alertPreferences.value.quietHours)
        _alertSettingsLoaded.value = true
    }
}

/** 核心存着的设置在 kit 里的样子。没有勿扰时段时开关关着，时间沿用 [shown] 那一段：关了再打开还是原来的时间。 */
internal fun alertPreferencesOf(settings: UserNotificationSettings, shown: FlareQuietHours): FlareNotificationAlertPreferences {
    val stored = settings.quietHours
    return FlareNotificationAlertPreferences(
        quietHours = if (stored == null) {
            shown.copy(enabled = false)
        } else {
            FlareQuietHours(
                enabled = true,
                startMinute = stored.startMinute,
                endMinute = stored.endMinute,
                weekdays = stored.weekdays,
                allowMentions = stored.allowMentions,
            )
        },
        preview = when (settings.preview) {
            NotificationPreview.FULL -> FlareNotificationPreview.Full
            NotificationPreview.SENDER_ONLY -> FlareNotificationPreview.SenderOnly
            NotificationPreview.HIDDEN -> FlareNotificationPreview.Hidden
        },
        multiDevice = when (settings.multiDevice) {
            MultiDeviceAlertPolicy.DELAY -> FlareMultiDeviceAlert.Delay
            MultiDeviceAlertPolicy.IMMEDIATE -> FlareMultiDeviceAlert.Immediate
            MultiDeviceAlertPolicy.BADGE_ONLY -> FlareMultiDeviceAlert.BadgeOnly
        },
    )
}

/** 从核心存着的 [stored] 改成 [next] 要写的那几项，基于 [stored] 的版本；没有要写的时为 null。 */
internal fun alertSettingsChanges(
    stored: UserNotificationSettings,
    next: FlareNotificationAlertPreferences,
): UpdateUserNotificationSettingsRequest? {
    val current = alertPreferencesOf(stored, next.quietHours)
    val quietChanged = next.quietHours != current.quietHours
    val quietHours = if (quietChanged && next.quietHours.enabled) {
        QuietHours(
            allowMentions = next.quietHours.allowMentions,
            endMinute = next.quietHours.endMinute,
            startMinute = next.quietHours.startMinute,
            weekdays = next.quietHours.weekdays,
        )
    } else {
        null
    }
    val clearQuietHours = quietChanged && !next.quietHours.enabled
    val preview = when {
        next.preview == current.preview -> null
        next.preview == FlareNotificationPreview.Full -> NotificationPreview.FULL
        next.preview == FlareNotificationPreview.SenderOnly -> NotificationPreview.SENDER_ONLY
        else -> NotificationPreview.HIDDEN
    }
    val multiDevice = when {
        next.multiDevice == current.multiDevice -> null
        next.multiDevice == FlareMultiDeviceAlert.Delay -> MultiDeviceAlertPolicy.DELAY
        next.multiDevice == FlareMultiDeviceAlert.Immediate -> MultiDeviceAlertPolicy.IMMEDIATE
        else -> MultiDeviceAlertPolicy.BADGE_ONLY
    }
    if (quietHours == null && !clearQuietHours && preview == null && multiDevice == null) return null
    return UpdateUserNotificationSettingsRequest(
        quietHours = quietHours,
        clearQuietHours = clearQuietHours,
        preview = preview,
        multiDevice = multiDevice,
        baseSettingsVersion = stored.settingsVersion,
    )
}
