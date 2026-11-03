package com.flare.im.app.core.platform

import android.content.Context
import android.net.Uri
import android.provider.OpenableColumns
import androidx.activity.result.ActivityResultLauncher
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.activity.result.ActivityResultRegistry
import com.flare.im.ui.FlareCapabilitySupport
import com.flare.im.ui.FlarePickFilesOptions
import com.flare.im.ui.FlarePickImagesOptions
import com.flare.im.ui.FlarePickedFile
import com.flare.im.ui.FlarePlatformAdapter
import com.flare.im.ui.FlarePlatformCapabilities
import com.flare.im.ui.FlarePlatformErrorCode
import com.flare.im.ui.FlarePlatformResult
import kotlinx.coroutines.CompletableDeferred

/**
 * Android host implementation of the kit's Layer 5 platform contract
 * (spec/platform-contract.json).
 *
 * The kit's composer asks `capabilities` what this host can do and calls the
 * adapter to do it; nothing in the kit branches on "is this Android". The
 * pickers are ActivityResult contracts registered once against the activity's
 * [ActivityResultRegistry], so a suspend call can await a result that arrives
 * after a configuration change.
 *
 * An empty selection is CANCELLED, never an empty success — the contract is
 * explicit that "the user backed out" is not "the user picked nothing".
 */
class AndroidPlatformAdapter(
    private val context: Context,
    registry: ActivityResultRegistry,
    private val widthDp: () -> Int,
) : FlarePlatformAdapter {

    override val capabilities: FlarePlatformCapabilities
        get() = androidHostCapabilities(widthDp())

    private var pendingFiles: CompletableDeferred<List<Uri>>? = null
    private var pendingMedia: CompletableDeferred<List<Uri>>? = null

    private val openDocuments: ActivityResultLauncher<Array<String>> =
        registry.register("flare-pick-files", ActivityResultContracts.OpenMultipleDocuments()) { uris ->
            pendingFiles?.complete(uris ?: emptyList())
            pendingFiles = null
        }

    private val pickMedia: ActivityResultLauncher<PickVisualMediaRequest> =
        registry.register("flare-pick-media", ActivityResultContracts.PickMultipleVisualMedia()) { uris ->
            pendingMedia?.complete(uris ?: emptyList())
            pendingMedia = null
        }

    override suspend fun pickFiles(options: FlarePickFilesOptions): FlarePlatformResult<List<FlarePickedFile>> {
        val awaiting = CompletableDeferred<List<Uri>>()
        pendingFiles?.complete(emptyList())
        pendingFiles = awaiting
        val mimeTypes = options.accept.ifEmpty { listOf("*/*") }.toTypedArray()
        return runCatching { openDocuments.launch(mimeTypes) }
            .fold(
                onSuccess = { settle(awaiting.await(), options.multiple) },
                onFailure = { error ->
                    pendingFiles = null
                    FlarePlatformResult.Err(com.flare.im.ui.normalizeFlarePlatformError(error))
                },
            )
    }

    override suspend fun pickImages(options: FlarePickImagesOptions): FlarePlatformResult<List<FlarePickedFile>> {
        val awaiting = CompletableDeferred<List<Uri>>()
        pendingMedia?.complete(emptyList())
        pendingMedia = awaiting
        val request = PickVisualMediaRequest(
            if (options.video) ActivityResultContracts.PickVisualMedia.ImageAndVideo
            else ActivityResultContracts.PickVisualMedia.ImageOnly,
        )
        return runCatching { pickMedia.launch(request) }
            .fold(
                onSuccess = { settle(awaiting.await(), options.multiple) },
                onFailure = { error ->
                    pendingMedia = null
                    FlarePlatformResult.Err(com.flare.im.ui.normalizeFlarePlatformError(error))
                },
            )
    }

    private fun settle(uris: List<Uri>, multiple: Boolean): FlarePlatformResult<List<FlarePickedFile>> =
        settlePickedUris(uris.map(::describe), multiple)

    /** Reads the display name / size the provider exposes; both are optional per the contract. */
    private fun describe(uri: Uri): FlarePickedFile {
        var name = uri.lastPathSegment.orEmpty()
        var size: Long? = null
        runCatching {
            context.contentResolver.query(uri, null, null, null, null)?.use { cursor ->
                if (!cursor.moveToFirst()) return@use
                val nameIndex = cursor.getColumnIndex(OpenableColumns.DISPLAY_NAME)
                if (nameIndex >= 0 && !cursor.isNull(nameIndex)) name = cursor.getString(nameIndex)
                val sizeIndex = cursor.getColumnIndex(OpenableColumns.SIZE)
                if (sizeIndex >= 0 && !cursor.isNull(sizeIndex)) size = cursor.getLong(sizeIndex)
            }
        }
        return FlarePickedFile(
            name = name,
            size = size,
            mimeType = runCatching { context.contentResolver.getType(uri) }.getOrNull(),
            uri = uri.toString(),
        )
    }
}

/**
 * What this host declares it can do: everything an Android phone / tablet
 * determines on its own, plus the two pickers [AndroidPlatformAdapter] performs.
 */
internal fun androidHostCapabilities(widthDp: Int): FlarePlatformCapabilities =
    FlarePlatformCapabilities.android(widthDp = widthDp).copy(
        filePicker = FlareCapabilitySupport.Supported,
        imagePicker = FlareCapabilitySupport.Supported,
    )

/**
 * Contract rule: an empty selection is CANCELLED, never an empty success; a
 * single-select request keeps only the first file even if the system picker
 * returned more.
 */
internal fun settlePickedUris(files: List<FlarePickedFile>, multiple: Boolean): FlarePlatformResult<List<FlarePickedFile>> {
    if (files.isEmpty()) return FlarePlatformResult.failure(FlarePlatformErrorCode.CANCELLED, "no selection")
    return FlarePlatformResult.Ok(if (multiple) files else files.take(1))
}
