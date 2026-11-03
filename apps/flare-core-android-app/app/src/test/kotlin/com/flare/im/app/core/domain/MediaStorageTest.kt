package com.flare.im.app.core.domain

import com.flare.im.model.common.enums.MessageContentType
import com.flare.im.model.entity.MessageContent
import java.util.Calendar
import java.util.Date
import java.util.TimeZone
import kotlin.test.Test
import kotlin.test.assertEquals
import kotlin.test.assertFalse
import kotlin.test.assertNull
import kotlin.test.assertTrue

/**
 * 保存到本机 / 下载位置 / 缓存 / 显示缓存的 app 一半：交给核心的保存请求、核心回答的读法、
 * 路径说成人话、系统文件夹选择器的文件夹换成核心要的路径。
 */
class MediaStorageTest {
    private val at: Date = Calendar.getInstance(TimeZone.getDefault()).apply {
        clear()
        set(2026, Calendar.SEPTEMBER, 27, 9, 5, 7)
    }.time

    private fun content(type: MessageContentType, vararg data: Pair<String, Any?>) = MessageContent(type, mapOf(*data))

    @Test fun aPictureIsSavedByItsStoredIdUnderACameraStyleName() {
        val image = content(MessageContentType.IMAGE, "source" to mapOf("imageId" to "img-1", "url" to "https://cdn/x"))
        assertEquals(
            mapOf("fileId" to "img-1", "fileName" to "IMG_20260927_090507", "downloadKey" to "img-1"),
            mediaSaveRequest(image, now = at),
        )
        assertEquals("img-1", pictureFileIdOf(image))
    }

    @Test fun videosVoiceAndFilesKeepTheirKindOfName() {
        assertEquals("VID_20260927_090507", mediaSaveRequest(content(MessageContentType.VIDEO, "videoId" to "v"), now = at)?.get("fileName"))
        assertEquals("AUD_20260927_090507", mediaSaveRequest(content(MessageContentType.AUDIO, "audioId" to "a"), now = at)?.get("fileName"))
        // A file keeps the sender's name, never a path.
        val file = content(MessageContentType.FILE, "fileId" to "f-1", "fileName" to "../需求稿.pdf")
        assertEquals(mapOf("fileId" to "f-1", "fileName" to "需求稿.pdf", "downloadKey" to "f-1"), mediaSaveRequest(file, now = at))
        assertNull(pictureFileIdOf(file))
    }

    @Test fun withoutAStoredIdOnlyAWebAddressOrALocalFileCanBeSaved() {
        assertEquals(
            mapOf("sourceUrl" to "https://cdn/a.png", "fileName" to "IMG_20260927_090507"),
            mediaSaveRequest(content(MessageContentType.IMAGE, "url" to "https://cdn/a.png"), now = at),
        )
        // A picture this account sent, still on this device, is copied from its path…
        val own = content(MessageContentType.IMAGE, "sourceUrl" to "file:///data/user/0/app/cache/p.jpg")
        assertEquals(
            mapOf("sourcePath" to "/data/user/0/app/cache/p.jpg", "fileName" to "IMG_20260927_090507"),
            mediaSaveRequest(own, allowLocalSource = true, now = at),
        )
        // An own message whose original is still here copies it even when it also has a stored id: no network.
        val sent = content(MessageContentType.IMAGE, "imageId" to "img-7", "sourceUrl" to "/data/user/0/app/cache/p.jpg")
        assertEquals(
            mapOf("sourcePath" to "/data/user/0/app/cache/p.jpg", "fileName" to "IMG_20260927_090507", "downloadKey" to "img-7"),
            mediaSaveRequest(sent, allowLocalSource = true, now = at) { true },
        )
        // Gone from this device: the stored id.
        assertEquals("img-7", mediaSaveRequest(sent, allowLocalSource = true, now = at) { false }?.get("fileId"))
        // …but someone else's message never names a file here (that would copy the app's own files out).
        assertEquals("img-7", mediaSaveRequest(sent, now = at) { true }?.get("fileId"))
        assertNull(mediaSaveRequest(own, now = at))
        assertNull(mediaSaveRequest(content(MessageContentType.FILE, "localPath" to "/data/user/0/com.flare.im.app/databases/im.db"), now = at))
        assertNull(mediaSaveRequest(content(MessageContentType.IMAGE, "url" to "content://media/1"), allowLocalSource = true, now = at))
        assertNull(mediaSaveRequest(content(MessageContentType.TEXT, "text" to "hi"), now = at))
        assertNull(mediaSaveRequest(null, now = at))
    }

    @Test fun anAlbumShowsAndSavesItsFirstPicture() {
        val album = content(MessageContentType.IMAGE_GROUP, "images" to listOf(mapOf("imageId" to "a"), mapOf("imageId" to "b")))
        assertEquals("a", pictureFileIdOf(album))
        assertEquals("a", mediaSaveRequest(album, now = at)?.get("fileId"))
    }

    @Test fun theCoreAnswersAreRead() {
        assertEquals(
            SavedMedia("/storage/emulated/0/Download/flare/IMG_1.jpg", "/storage/emulated/0/Download/flare", "IMG_1.jpg", true),
            savedMediaFrom(
                mapOf(
                    "path" to "/storage/emulated/0/Download/flare/IMG_1.jpg", "directory" to "/storage/emulated/0/Download/flare",
                    "fileName" to "IMG_1.jpg", "sizeBytes" to 10, "fromCache" to true, "downloadKey" to "img-1",
                ),
            ),
        )
        assertEquals(
            DownloadLocation("/storage/emulated/0/Download/flare", "/storage/emulated/0/Download/flare", false),
            downloadLocationFrom(
                mapOf(
                    "directory" to "/storage/emulated/0/Download/flare", "defaultDirectory" to "/storage/emulated/0/Download/flare",
                    "customDirectory" to null, "isCustom" to false, "subfolder" to "flare",
                ),
            ),
        )
        assertEquals(PictureAccess(localPath = "/cache/a.jpg"), pictureAccessFrom(mapOf("source" to "local", "localPath" to "/cache/a.jpg")))
        assertEquals(PictureAccess(url = "https://s/a"), pictureAccessFrom(mapOf("source" to "remote", "remote" to mapOf("url" to "https://s/a"))))
        assertEquals(PictureAccess(), pictureAccessFrom(null))
        // cache_stats is snake_case: read as camelCase the usage was always "—".
        val stats = mediaCacheStatsFrom(mapOf("total_bytes" to 5_242_880L, "entry_count" to 3, "max_bytes" to 1_073_741_824L, "effective_root" to "/x"))
        assertEquals(MediaCacheStats(5_242_880L, 3, 1_073_741_824L), stats)
        assertEquals("5.0 MB / 1.0 GB · 3 files", formatCacheStats(stats))
        assertEquals("—", formatByteSize(null))
        assertEquals("512 B", formatByteSize(512))
    }

    @Test fun theSavedToFolderReadsLikeThePhoneShowsIt() {
        assertEquals("Download/flare", shortDownloadLocation("/storage/emulated/0/Download/flare"))
        assertEquals("Documents/Flare", shortDownloadLocation("/sdcard/Documents/Flare/"))
        assertEquals("…/files/downloads", shortDownloadLocation("/data/user/0/com.flare.im.app/files/downloads"))
    }

    @Test fun aPickedFolderBecomesThePathTheCoreSavesInto() {
        val external = "com.android.externalstorage.documents"
        assertEquals("/storage/emulated/0/Download/Foo", treeDocumentPath(external, "primary:Download/Foo"))
        assertEquals("/storage/emulated/0/Documents/Notes", treeDocumentPath(external, "home:Notes"))
        assertEquals("/storage/1234-ABCD/DCIM", treeDocumentPath(external, "1234-ABCD:DCIM"))
        assertEquals("/storage/emulated/0/Download/Bar", treeDocumentPath("com.android.providers.downloads.documents", "raw:/storage/emulated/0/Download/Bar"))
        assertNull(treeDocumentPath("com.android.providers.downloads.documents", "msf:42"))
        assertNull(treeDocumentPath("com.google.android.apps.docs.storage", "doc=1"))
        assertNull(treeDocumentPath(external, null))
    }

    @Test fun aFolderTheCoreRefusesIsNamedAsSuch() {
        assertTrue(isUnwritableFolderError(IllegalStateException("PERMISSION_DENIED: download directory is not writable: os error 13")))
        assertFalse(isUnwritableFolderError(IllegalStateException("http chunk: connection reset")))
    }

    @Test fun aSignedUrlIsAskedAgainOnceThenOnlyNearItsExpiry() {
        val first = PictureAccessPolicy.next(null, PictureAccess(url = "https://s/a"), nowMs = 0)
        assertTrue(PictureAccessPolicy.reusable(first, PictureAccessPolicy.RECHECK_MS - 1, localExists = false))
        assertFalse(PictureAccessPolicy.reusable(first, PictureAccessPolicy.RECHECK_MS, localExists = false))
        val second = PictureAccessPolicy.next(first, PictureAccess(url = "https://s/a?2"), nowMs = 6_000)
        assertTrue(second.rechecked)
        assertTrue(PictureAccessPolicy.reusable(second, 6_000 + 60_000, localExists = false))
        assertFalse(PictureAccessPolicy.reusable(second, 6_000 + PictureAccessPolicy.URL_TTL_MS, localExists = false))
        val local = PictureAccessPolicy.next(second, PictureAccess(localPath = "/cache/a.jpg"), nowMs = 7_000)
        assertTrue(PictureAccessPolicy.reusable(local, Long.MAX_VALUE, localExists = true))
        assertFalse(PictureAccessPolicy.reusable(local, 7_001, localExists = false))
    }
}
