package com.flare.im.app.features.messaging.messagerow

import androidx.compose.material3.MaterialTheme

import android.net.Uri
import android.widget.MediaController
import android.widget.VideoView
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.viewinterop.AndroidView
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.flare.im.app.R
import com.flare.im.app.core.designsystem.FlareTheme
import com.flare.im.app.core.platform.FlareLocalImage
import com.flare.im.ui.ImagePreview
import com.flare.im.ui.EmptyState
import com.flare.im.ui.FlareEmptyStateTone
import com.flare.im.ui.FlareThemeProvider
import com.flare.im.ui.VideoPlayer
import com.flare.im.ui.flareStrings
import java.io.File

/** Platform image-loader slot for the public design-kit preview. */
@Composable
internal fun MediaPreviewDialog(path: String, onDownload: (() -> Unit)? = null, onDismiss: () -> Unit) {
    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        ImagePreview(
            show = true,
            imageSrc = path,
            onClose = onDismiss,
            // The kit's download key; the host saves (through the core).
            onDownload = onDownload,
            image = {
                FlareLocalImage(
                    path = path,
                    contentDescription = stringResource(R.string.msg_preview_a11y),
                    modifier = Modifier.fillMaxWidth(),
                    maxPx = 2048,
                    contentScale = ContentScale.Fit,
                ) {
                    androidx.compose.material3.Text(
                        "Cannot preview",
                        style = MaterialTheme.typography.bodyLarge,
                        color = Color.White,
                        modifier = Modifier.padding(FlareTheme.tokens.lg),
                    )
                }
            },
        )
    }
}

/** Android owns the decoder/system transport controls, the kit owns the modal. */
@Composable
internal fun PlatformPlaybackDialog(path: String, onDownload: (() -> Unit)? = null, onDismiss: () -> Unit) {
    val context = LocalContext.current
    val player = remember { VideoView(context) }
    val controls = remember { MediaController(context) }
    var ready by remember { mutableStateOf(false) }
    var failed by remember { mutableStateOf(false) }
    var attempt by remember { mutableStateOf(0) }
    val strings = flareStrings()

    DisposableEffect(player) {
        controls.setAnchorView(player)
        player.setMediaController(controls)
        player.setOnPreparedListener { ready = true; controls.show(0) }
        player.setOnErrorListener { _, _, _ -> failed = true; true }
        onDispose {
            controls.hide()
            player.setOnPreparedListener(null)
            player.setOnErrorListener(null)
            player.stopPlayback()
        }
    }
    LaunchedEffect(path, attempt) {
        ready = false
        failed = false
        player.stopPlayback()
        val uri = if (path.startsWith("/")) Uri.fromFile(File(path)) else Uri.parse(path)
        if (uri.scheme?.lowercase() !in listOf("http", "https", "content", "file")) {
            failed = true
        } else {
            runCatching { player.setVideoURI(uri) }.onFailure { failed = true }
        }
    }
    Dialog(onDismissRequest = onDismiss, properties = DialogProperties(usePlatformDefaultWidth = false)) {
        VideoPlayer(show = true, videoSrc = path, onClose = onDismiss, onDownload = onDownload, player = {
            Box(Modifier.fillMaxSize()) {
                AndroidView(factory = { player }, modifier = Modifier.fillMaxSize())
                if (!ready || failed) {
                    FlareThemeProvider(mode = com.flare.im.ui.FlareThemeMode.Dark) {
                        EmptyState(
                            title = if (failed) "Cannot play this media" else "Loading",
                            loading = !failed,
                            tone = if (failed) FlareEmptyStateTone.Error else FlareEmptyStateTone.Normal,
                            actionText = if (failed) strings.retry else null,
                            onAction = if (failed) ({ attempt += 1 }) else null,
                        )
                    }
                }
            }
        })
    }
}
