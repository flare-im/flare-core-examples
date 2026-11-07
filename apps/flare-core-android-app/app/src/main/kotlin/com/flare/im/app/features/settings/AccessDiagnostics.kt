package com.flare.im.app.features.settings

import android.util.Log
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.AnnotatedString
import com.flare.im.api.access.AccessApi
import com.flare.im.app.R
import com.flare.im.model.command.AccessImportRecoveryRequest
import com.flare.im.model.command.AccessPinRequest
import com.flare.im.model.entity.AccessPointInfo
import com.flare.im.model.entity.AccessStatus
import com.flare.im.ui.AccessDiagnostics
import com.flare.im.ui.FlareAccessConnectAck
import com.flare.im.ui.FlareAccessPoint
import com.flare.im.ui.FlareAccessRecovering
import com.flare.im.ui.FlareAccessStatus
import com.flare.im.ui.FlareScreen
import com.flare.im.ui.FlareStatusTone
import com.flare.im.ui.LocalFlareToast
import com.flare.im.ui.flareStrings
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch
import org.json.JSONObject

/** A `flare-recover://` link as the system handed it, unchanged; null for anything else. The core verifies it. */
fun parseRecoveryLink(raw: String?): String? =
    raw?.trim()?.takeIf { it.startsWith("flare-recover://", ignoreCase = true) }

/** `access.getStatus` as the kit's diagnostics page takes it. */
fun AccessStatus.toKitStatus(): FlareAccessStatus = FlareAccessStatus(
    loaded = loaded,
    serial = serial,
    source = source,
    stale = stale,
    developmentMode = developmentMode,
    regionId = regionId?.ifEmpty { null },
    accessPointId = accessPointId?.ifEmpty { null },
    protocol = protocol?.ifEmpty { null },
    connectAck = connectAck?.let { FlareAccessConnectAck(it.accessPointId, it.accessPointMismatch) },
    recovering = recovering?.let { FlareAccessRecovering(it.rounds, it.nextRoundAtMs) },
)

/** One row of `access.listAccessPoints` as the kit's diagnostics page takes it. */
fun AccessPointInfo.toKitPoint(): FlareAccessPoint = FlareAccessPoint(
    accessPointId = accessPointId,
    regionId = regionId.ifEmpty { null },
    host = host.ifEmpty { null },
    status = status,
    rttMs = rttMs,
    breaker = breaker,
    pinned = pinned,
    current = current,
)

/**
 * The host of the network and line page: it reads `access.*`, hands the results to the kit's [AccessDiagnostics] and
 * carries out what the kit reports. What the page says and which line can be pinned are the kit's.
 *
 * One lives with the app store, so a recovery link opened from outside and the page it opens read the same outcome.
 */
class AccessDiagnosticsHost(
    private val access: suspend () -> AccessApi,
    private val subscribeLinkEvents: (onLinkEvent: () -> Unit) -> () -> Unit,
    private val scope: CoroutineScope,
    private val warn: (String, Throwable) -> Unit = { message, error -> Log.w("FlareAccess", message, error) },
) {
    var status by mutableStateOf<FlareAccessStatus?>(null)
        private set
    var accessPoints by mutableStateOf<List<FlareAccessPoint>>(emptyList())
        private set
    var refreshing by mutableStateOf(false)
        private set
    var refreshOutcome by mutableStateOf<String?>(null)
        private set
    var importing by mutableStateOf(false)
        private set
    var importOutcome by mutableStateOf<String?>(null)
        private set
    var importCode by mutableStateOf<String?>(null)
        private set
    var exporting by mutableStateOf(false)
        private set
    var exportOutcome by mutableStateOf<String?>(null)
        private set

    /** The page over the whole app: settings, the connection notice and a recovery link all open it there. */
    var presented by mutableStateOf(false)

    /** Bumped by every read: a slower read that started earlier must not put an older directory back. */
    private var reads = 0

    /** Runs an action past the page: closing it must not drop an import under way. */
    fun launch(action: suspend AccessDiagnosticsHost.() -> Unit) {
        scope.launch { action() }
    }

    /** [block]'s failure as a value; a cancellation stays a cancellation. */
    private inline fun <T> attempt(what: String, block: () -> T): T? = try {
        block()
    } catch (cancelled: CancellationException) {
        throw cancelled
    } catch (error: Throwable) {
        warn(what, error)
        null
    }

    suspend fun reload() {
        val read = ++reads
        attempt("reading the access directory failed") {
            val api = access()
            val nextStatus = api.getStatus()
            val nextPoints = api.listAccessPoints()
            if (read == reads) {
                status = nextStatus.toKitStatus()
                accessPoints = nextPoints.map { it.toKitPoint() }
            }
        }
    }

    /** Reads now and again on every link event; the returned function stops following. The first read brings the client up. */
    fun follow(): () -> Unit {
        var stop: (() -> Unit)? = null
        var stopped = false
        launch {
            reload()
            if (!stopped) stop = subscribeLinkEvents { launch { reload() } }
        }
        return {
            stopped = true
            stop?.invoke()
        }
    }

    /** False when the core refused: the line left the directory meanwhile. */
    suspend fun pin(accessPointId: String): Boolean {
        val pinned = attempt("pinning an access point failed") {
            access().pin(AccessPinRequest(accessPointId = accessPointId))
            true
        } ?: false
        reload()
        return pinned
    }

    suspend fun unpin() {
        attempt("unpinning failed") { access().unpin() }
        reload()
    }

    suspend fun refresh() {
        refreshing = true
        refreshOutcome = null
        val outcome = attempt("refreshing the access manifest failed") { access().refresh().outcome }
        refreshing = false
        refreshOutcome = outcome ?: "failed"
        reload()
    }

    /** A bad link comes back as `rejected` with its code; only a configuration problem throws, and that is no reason to say nothing. */
    suspend fun importRecovery(link: String) {
        importing = true
        importOutcome = null
        importCode = null
        val imported = attempt("importing a recovery link failed") {
            access().importRecovery(AccessImportRecoveryRequest(link = link))
        }
        importing = false
        importOutcome = imported?.outcome ?: "rejected"
        importCode = imported?.code
        reload()
    }

    /** A recovery link from outside the app: imported at once, and the page opens to say what became of it. */
    fun openRecoveryLink(link: String) {
        presented = true
        launch { importRecovery(link) }
    }

    suspend fun exportDiagnostics(writeClipboard: (String) -> Unit) {
        exporting = true
        exportOutcome = null
        val copied = attempt("copying the diagnostics failed") {
            writeClipboard(JSONObject(access().exportDiagnostics()).toString(2))
            true
        } ?: false
        exporting = false
        exportOutcome = if (copied) "copied" else "failed"
    }
}

/**
 * Network and lines: settings, the connection notice's "diagnose" and a recovery link all open this page. The body is
 * the kit's [AccessDiagnostics]; the reads and calls are in [AccessDiagnosticsHost].
 */
@Composable
fun AccessDiagnosticsScreen(model: AccessDiagnosticsHost, onBack: () -> Unit) {
    val context = LocalContext.current
    val toast = LocalFlareToast.current
    val clipboard = LocalClipboardManager.current
    DisposableEffect(model) {
        val stop = model.follow()
        onDispose { stop() }
    }
    FlareScreen(title = flareStrings().accessDiagnosticsTitle, onBack = onBack, padded = true) {
        AccessDiagnostics(
            status = model.status,
            accessPoints = model.accessPoints,
            refreshing = model.refreshing,
            refreshOutcome = model.refreshOutcome,
            importing = model.importing,
            importOutcome = model.importOutcome,
            importCode = model.importCode,
            exporting = model.exporting,
            exportOutcome = model.exportOutcome,
            onPin = { id ->
                model.launch {
                    if (!pin(id)) toast.show(context.getString(R.string.settings_access_pin_failed), tone = FlareStatusTone.Danger)
                }
            },
            onUnpin = { model.launch { unpin() } },
            onRefresh = { model.launch { refresh() } },
            onImportRecovery = { link -> model.launch { importRecovery(link) } },
            onExportDiagnostics = {
                model.launch { exportDiagnostics { text -> clipboard.setText(AnnotatedString(text)) } }
            },
        )
    }
}
