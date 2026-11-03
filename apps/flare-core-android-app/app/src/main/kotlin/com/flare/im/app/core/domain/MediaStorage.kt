package com.flare.im.app.core.domain

import com.flare.im.model.common.enums.MessageContentType
import com.flare.im.model.entity.MessageContent
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/*
 * 媒体「保存到本机」「下载位置」「缓存」的 app 一半（无 UI、无 SDK 调用，可单测）：
 * 选出交给核心的保存请求、把核心的回答读成模型、把路径说成人话。
 * 真正的保存是核心的 `media.download_to_user_directory`（缓存命中拷缓存，否则拉附件；临时文件写完再改名；
 * 名字没有扩展名时按类型补上），这里不碰网络、不碰文件。
 */

/** The stored media id of [content] for its type (`source.imageId`, `videoId`, `audioId`, `fileId` …), else null. */
fun mediaFileIdOf(content: MessageContent?): String? {
    val data = content?.data ?: return null
    val keys = when (content.contentType) {
        MessageContentType.IMAGE -> listOf("imageId", "fileId", "mediaId")
        MessageContentType.IMAGE_GROUP -> return firstAlbumImage(data)?.let { nonBlank(it["imageId"]) ?: nonBlank(it["fileId"]) }
        MessageContentType.VIDEO -> listOf("videoId", "fileId", "mediaId")
        MessageContentType.AUDIO -> listOf("audioId", "fileId", "mediaId")
        MessageContentType.FILE -> listOf("fileId", "mediaId")
        else -> return null
    }
    for (key in keys) nonBlank(data[key])?.let { return it }
    val source = data["source"] as? Map<*, *> ?: return null
    for (key in keys) nonBlank(source[key])?.let { return it }
    return null
}

/** The stored id of the picture an image message shows (an album's first picture), for the display cache. */
fun pictureFileIdOf(content: MessageContent?): String? = when (content?.contentType) {
    MessageContentType.IMAGE, MessageContentType.IMAGE_GROUP -> mediaFileIdOf(content)
    else -> null
}

/**
 * The request for `media.download_to_user_directory` that saves [content]: its stored id when it has one — the core
 * copies its cached copy or signs a fresh attachment URL — else its own web address (http(s) only) or a file on this
 * device. The name is camera-style for pictures, videos and voice (`IMG_yyyyMMdd_HHmmss`) and the sender's for a file;
 * the core adds the extension from the media type. Null when the message names nothing that can be saved.
 *
 * A file on this device is a source only when [allowLocalSource] — a message this account sent. A received
 * message's address is the sender's string: taken as a path it would copy any file the app can read (its own
 * database) into shared storage. When the original of an own message is still here ([localExists]) it is copied
 * as it is — no network — even when the message also has a stored id.
 */
fun mediaSaveRequest(
    content: MessageContent?,
    allowLocalSource: Boolean = false,
    now: Date = Date(),
    localExists: (String) -> Boolean = { false },
): Map<String, Any?>? {
    val data = content?.data ?: return null
    val prefix = when (content.contentType) {
        MessageContentType.IMAGE, MessageContentType.IMAGE_GROUP -> "IMG"
        MessageContentType.VIDEO -> "VID"
        MessageContentType.AUDIO -> "AUD"
        MessageContentType.FILE -> null
        else -> return null
    }
    val name = prefix?.let { friendlyMediaName(it, now) }
        ?: nonBlank(data["fileName"])?.substringAfterLast('/')?.substringAfterLast('\\')
        ?: friendlyMediaName("FILE", now)
    val fileId = mediaFileIdOf(content)
    val source = data["source"] as? Map<*, *>
    val address = listOf("sourceUrl", "url", "path", "localPath").firstNotNullOfOrNull { nonBlank(data[it]) ?: nonBlank(source?.get(it)) }
    val localPath = address?.takeIf { allowLocalSource }?.let { a ->
        when {
            a.startsWith("file://") -> a.removePrefix("file://").takeIf { it.startsWith("/") }
            a.startsWith("/") -> a
            else -> null
        }
    }
    if (localPath != null && localExists(localPath)) {
        return mapOf("sourcePath" to localPath, "fileName" to name) + (fileId?.let { mapOf("downloadKey" to it) } ?: emptyMap())
    }
    if (fileId != null) return mapOf("fileId" to fileId, "fileName" to name, "downloadKey" to fileId)
    return when {
        address == null -> null
        address.startsWith("https://", ignoreCase = true) || address.startsWith("http://", ignoreCase = true) ->
            mapOf("sourceUrl" to address, "fileName" to name)
        localPath != null -> mapOf("sourcePath" to localPath, "fileName" to name)
        else -> null
    }
}

/** A camera-style name: `IMG_20260927_090507`. */
fun friendlyMediaName(prefix: String, at: Date): String =
    prefix + "_" + SimpleDateFormat("yyyyMMdd_HHmmss", Locale.US).format(at)

/** One "save to device" as the core answered it. */
data class SavedMedia(val path: String, val directory: String, val fileName: String, val fromCache: Boolean)

fun savedMediaFrom(raw: Map<String, Any?>): SavedMedia {
    val path = nonBlank(raw["path"]).orEmpty()
    return SavedMedia(
        path = path,
        directory = nonBlank(raw["directory"]) ?: path.substringBeforeLast('/', ""),
        fileName = nonBlank(raw["fileName"]) ?: path.substringAfterLast('/'),
        fromCache = raw["fromCache"] == true,
    )
}

/** Where "save to device" writes: the folder in effect, and whether the user chose it. */
data class DownloadLocation(val directory: String, val defaultDirectory: String, val isCustom: Boolean)

fun downloadLocationFrom(raw: Map<String, Any?>): DownloadLocation = DownloadLocation(
    directory = nonBlank(raw["directory"]).orEmpty(),
    defaultDirectory = nonBlank(raw["defaultDirectory"]).orEmpty(),
    isCustom = raw["isCustom"] == true || nonBlank(raw["customDirectory"]) != null,
)

/** Where a picture is drawn from: the core's cached copy ([localPath]) or a signed [url]. */
data class PictureAccess(val localPath: String? = null, val url: String? = null)

/** `media.resolve_access` → [PictureAccess]; the core answers camelCase, snake_case is read too. */
fun pictureAccessFrom(raw: Map<String, Any?>?): PictureAccess {
    if (raw == null) return PictureAccess()
    val remote = raw["remote"] as? Map<*, *>
    return PictureAccess(
        localPath = nonBlank(raw["localPath"]) ?: nonBlank(raw["local_path"]),
        url = nonBlank(remote?.get("url")) ?: nonBlank(remote?.get("cdnUrl")) ?: nonBlank(remote?.get("cdn_url")),
    )
}

/** What a picture id resolved to ([access]), when, and whether a signed URL has had its second look. */
data class PictureAccessEntry(val access: PictureAccess, val resolvedAtMs: Long, val rechecked: Boolean)

/**
 * When a picture's last `media.resolve_access` answer is still good. The core caches a missed picture in the
 * background (`autoCache`), so a signed URL is asked again once, [RECHECK_MS] later, to pick up the local copy; after
 * that it stands until shortly before the link expires ([URL_TTL_MS]). A local copy stands while its file is there.
 */
object PictureAccessPolicy {
    const val RECHECK_MS = 5_000L
    const val URL_TTL_MS = 50 * 60 * 1000L

    fun reusable(entry: PictureAccessEntry, nowMs: Long, localExists: Boolean): Boolean {
        if (entry.access.localPath != null) return localExists
        val age = nowMs - entry.resolvedAtMs
        return if (entry.rechecked) age < URL_TTL_MS else age < RECHECK_MS
    }

    fun next(previous: PictureAccessEntry?, access: PictureAccess, nowMs: Long): PictureAccessEntry =
        PictureAccessEntry(access, nowMs, rechecked = access.localPath == null && previous != null && previous.access.localPath == null)
}

/** The core's media cache (`media.cache_stats`, snake_case): bytes, files and limit. */
data class MediaCacheStats(val totalBytes: Long?, val entryCount: Long?, val maxBytes: Long?)

fun mediaCacheStatsFrom(raw: Map<String, Any?>): MediaCacheStats {
    fun num(vararg keys: String): Long? = keys.firstNotNullOfOrNull { (raw[it] as? Number)?.toLong() }
    return MediaCacheStats(
        totalBytes = num("total_bytes", "totalBytes", "usedBytes"),
        entryCount = num("entry_count", "entryCount"),
        maxBytes = num("max_bytes", "maxBytes"),
    )
}

/** Human bytes: `—` unknown, then B, KB, MB, GB with one decimal. */
fun formatByteSize(bytes: Long?): String = when {
    bytes == null || bytes < 0 -> "—"
    bytes < 1024 -> "$bytes B"
    bytes < 1024L * 1024 -> "%.1f KB".format(Locale.US, bytes / 1024.0)
    bytes < 1024L * 1024 * 1024 -> "%.1f MB".format(Locale.US, bytes / 1_048_576.0)
    else -> "%.1f GB".format(Locale.US, bytes / 1_073_741_824.0)
}

/** "12.0 MB / 1.0 GB · 3 files" — the cache row's usage line. */
fun formatCacheStats(stats: MediaCacheStats): String = buildString {
    append(formatByteSize(stats.totalBytes))
    stats.maxBytes?.let { append(" / ${formatByteSize(it)}") }
    stats.entryCount?.let { append(" · $it files") }
}

private val PRIMARY_STORAGE_ROOTS = listOf(Regex("^/storage/emulated/\\d+/"), Regex("^/sdcard/"), Regex("^/storage/self/primary/"))

/** [directory] as a person reads it: `Download/flare` rather than `/storage/emulated/0/Download/flare`. */
fun shortDownloadLocation(directory: String): String {
    val trimmed = directory.trim().trimEnd('/')
    if (trimmed.isEmpty()) return trimmed
    for (root in PRIMARY_STORAGE_ROOTS) {
        if (root.containsMatchIn("$trimmed/")) return "$trimmed/".replaceFirst(root, "").trimEnd('/').ifEmpty { trimmed }
    }
    val parts = trimmed.split('/').filter(String::isNotEmpty)
    return if (parts.size <= 3) trimmed else "…/" + parts.takeLast(2).joinToString("/")
}

/**
 * The folder path behind a folder the system picker returned (`ACTION_OPEN_DOCUMENT_TREE`): its provider
 * [authority] and tree document id. `primary:Download/Foo` → `/storage/emulated/0/Download/Foo`, `home:Foo` →
 * `…/Documents/Foo`, a memory card `1234-ABCD:Foo` → `/storage/1234-ABCD/Foo`, the Downloads provider's `raw:/…`
 * as it is; a folder with no path behind it (a cloud drive) is null — the core saves through paths.
 */
fun treeDocumentPath(authority: String?, treeDocumentId: String?, primaryRoot: String = "/storage/emulated/0"): String? {
    val id = treeDocumentId?.trim().orEmpty()
    if (id.isEmpty()) return null
    return when (authority) {
        "com.android.providers.downloads.documents" ->
            id.removePrefix("raw:").takeIf { id.startsWith("raw:") && it.startsWith("/") }?.trimEnd('/')
        "com.android.externalstorage.documents" -> {
            val volume = id.substringBefore(':')
            val relative = id.substringAfter(':', "").trim('/')
            val base = when {
                volume.equals("primary", ignoreCase = true) -> primaryRoot
                volume.equals("home", ignoreCase = true) -> "$primaryRoot/Documents"
                volume.isNotEmpty() && ':' in id -> "/storage/$volume"
                else -> return null
            }
            if (relative.isEmpty()) base else "$base/$relative"
        }
        else -> null
    }
}

/** Whether [error] is the core refusing the folder itself (not writable / not usable / not a path). */
fun isUnwritableFolderError(error: Throwable): Boolean {
    val text = generateSequence(error) { it.cause }.mapNotNull { it.message }.joinToString(" ").lowercase()
    return listOf("not writable", "not usable", "permission denied", "permission_denied", "must be an absolute path")
        .any { it in text }
}

private fun firstAlbumImage(data: Map<String, Any?>): Map<*, *>? =
    (data["images"] as? List<*>)?.firstOrNull() as? Map<*, *>

private fun nonBlank(value: Any?): String? = (value as? String)?.trim()?.takeIf(String::isNotEmpty)
