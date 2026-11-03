package com.flare.im.app

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.flare.im.app.core.domain.LoginDraft
import com.flare.im.app.core.domain.downloadLocationFrom
import com.flare.im.app.core.domain.isUnwritableFolderError
import com.flare.im.app.core.domain.mediaCacheStatsFrom
import com.flare.im.app.core.domain.mediaSaveRequest
import com.flare.im.app.core.domain.savedMediaFrom
import com.flare.im.app.core.session.AppSession
import com.flare.im.model.common.enums.MessageContentType
import com.flare.im.model.entity.MessageContent
import java.io.File
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

/**
 * 保存到本机走真实核心，不需要服务器和账号：app 的热启动本地半段（prepare 开本地库、不连网）。
 * 下载位置默认是共享存储的 Download/flare，保存把文件写进那里（名字没有扩展名时核心按类型补上），
 * 缓存根目录按核心的参数名设上、缓存统计按 snake_case 读得出来，自选文件夹核心会先探测能不能写。
 */
@RunWith(AndroidJUnit4::class)
class MediaSaveDeviceTest {
    private val context = InstrumentationRegistry.getInstrumentation().targetContext
    private val session = AppSession()
    private val saved = mutableListOf<File>()

    @After fun tearDown(): Unit = runBlocking {
        // `-e keepSaved true` leaves the saved picture in Download/flare, for a look with `adb shell ls`.
        if (InstrumentationRegistry.getArguments().getString("keepSaved") != "true") saved.forEach { it.delete() }
        runCatching { session.client?.media?.setUserDownloadDirectory(mapOf("directory" to null)) }
        runCatching { session.dispose() }
    }

    @Test fun anOwnPictureIsSavedIntoTheSharedDownloadFolder(): Unit = runBlocking {
        val dataDir = File(context.filesDir, "media-save-device-test").apply { mkdirs() }.absolutePath
        android.system.Os.setenv("HOME", dataDir, true)
        android.system.Os.setenv("TMPDIR", context.cacheDir.absolutePath, true)
        val sdk = session.resumeLocal(LoginDraft(userId = "media-save-device-test"), dataDir) {}

        // The platform default: shared storage's Download/flare (the core names it through EXTERNAL_STORAGE,
        // `/sdcard` on this image — the same folder).
        val location = downloadLocationFrom(sdk.media.getUserDownloadDirectory())
        assertEquals(SHARED_DOWNLOAD_FLARE, File(location.directory).canonicalPath)
        assertEquals("Download/flare", com.flare.im.app.core.domain.shortDownloadLocation(location.directory))
        assertFalse(location.isCustom)

        // A picture this account sent, still on this device: the core copies it (no network) under a camera-style
        // name and adds the extension from the file's type.
        val png = File(context.cacheDir, "outgoing-picture").apply { writeBytes(PNG_1X1) }
        val content = MessageContent(MessageContentType.IMAGE, mapOf("sourceUrl" to png.absolutePath))
        val request = mediaSaveRequest(content, allowLocalSource = true)
        assertNotNull(request)
        val result = savedMediaFrom(sdk.media.downloadToUserDirectory(request!!))
        val file = File(result.path).also { saved += it }
        assertEquals(SHARED_DOWNLOAD_FLARE, File(result.directory).canonicalPath)
        assertTrue(result.fileName, result.fileName.startsWith("IMG_") && result.fileName.endsWith(".png"))
        assertTrue("saved file exists: ${result.path}", file.isFile)
        assertEquals(PNG_1X1.size.toLong(), file.length())

        // The cache root the app sets (`absolutePath`) took effect, and the statistics answer snake_case —
        // read as camelCase the settings row said "—".
        val raw = sdk.media.getMediaCacheStats()
        assertEquals("$dataDir/media-cache", raw["effective_root"])
        val stats = mediaCacheStatsFrom(raw)
        assertNotNull(stats.totalBytes)
        assertNotNull(stats.maxBytes)

        // A folder the app can write to is accepted; a system folder is refused as not writable.
        val custom = File("/storage/emulated/0/Download/flare-device-test")
        val chosen = downloadLocationFrom(sdk.media.setUserDownloadDirectory(mapOf("directory" to custom.path)))
        assertTrue(chosen.isCustom)
        assertEquals(custom.path, chosen.directory)
        val refused = runCatching { sdk.media.setUserDownloadDirectory(mapOf("directory" to "/system/flare")) }
        assertTrue(refused.isFailure)
        assertTrue(refused.exceptionOrNull().toString(), refused.exceptionOrNull()?.let(::isUnwritableFolderError) == true)
        val reset = downloadLocationFrom(sdk.media.setUserDownloadDirectory(mapOf("directory" to null)))
        assertFalse(reset.isCustom)
        custom.delete()
    }

    private companion object {
        const val SHARED_DOWNLOAD_FLARE = "/storage/emulated/0/Download/flare"

        /** A 1×1 transparent PNG. */
        val PNG_1X1: ByteArray = android.util.Base64.decode(
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkYAAAAAYAAjCB0C8AAAAASUVORK5CYII=",
            android.util.Base64.DEFAULT,
        )
    }
}
