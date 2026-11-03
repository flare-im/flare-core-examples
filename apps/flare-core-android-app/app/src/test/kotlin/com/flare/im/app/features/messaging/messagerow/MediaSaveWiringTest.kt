package com.flare.im.app.features.messaging.messagerow

import com.flare.im.app.core.domain.PictureAccess
import com.flare.im.model.common.enums.MessageContentType
import com.flare.im.model.entity.MessageContent
import com.flare.im.ui.FlareImageContent
import com.flare.im.ui.FlarePlaceholderContent
import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 保存到本机与显示缓存的接线：图片画核心缓存的本地副本（只有核心的回答会成为 kit 的 localPath），
 * 保存走核心 `media.download_to_user_directory` 并且一定告诉用户结果。后两条钉的是源码形态：
 * 真正的失败要在真机上点保存、什么都没发生才暴露，而形态判据是确定的。
 */
class MediaSaveWiringTest {
    private fun source(path: String) = File("src/main/kotlin/com/flare/im/app/$path").readText()

    @Test
    fun `核心缓存的副本成为 kit 的 localPath，地址一并保留`() {
        val image = MessageContent(MessageContentType.IMAGE, mapOf("source" to mapOf("imageId" to "img-1")))
        val cached = image.toPresentationContent("[图片]", PictureAccess(localPath = "/cache/img-1.jpg", url = null)) as FlareImageContent
        assertEquals("/cache/img-1.jpg", cached.localPath)
        assertEquals("", cached.url)
        val remote = image.toPresentationContent("[图片]", PictureAccess(url = "https://s/img-1")) as FlareImageContent
        assertEquals("https://s/img-1", remote.url)
        assertNull(remote.localPath)
        // 核心还没回答：占位，而不是一张画不出来的图。
        assertTrue(image.toPresentationContent("[图片]") is FlarePlaceholderContent)
        // 消息里自带的本机地址从来不是 localPath。
        val own = MessageContent(MessageContentType.IMAGE, mapOf("localPath" to "/etc/passwd"))
            .toPresentationContent("[图片]") as FlareImageContent
        assertNull(own.localPath)
    }

    @Test
    fun `保存走核心的下载位置，且结果说给用户`() {
        val vm = source("features/messaging/MessagingViewModel.kt")
        assertTrue(vm.contains("sdk.media.downloadToUserDirectory(request)"))
        assertFalse("旧的直链 op 不再从界面调用", vm.contains("downloadFileToDownloads("))
        val row = source("features/messaging/messagerow/MessageRowView.kt")
        assertTrue("长按「保存」", row.contains("\"save\" -> onSave()"))
        assertTrue("预览与视频播放器的下载键", row.contains("MediaPreviewDialog(p, onDownload = { saveMedia(message) })"))
        assertTrue(row.contains("PlatformPlaybackDialog(p, onDownload = if (playbackIsVideo) ({ saveMedia(message) }) else null)"))
        val feedback = source("features/messaging/media/MediaSaveFeedback.kt")
        assertTrue("保存中、成功、失败都要有 toast", feedback.contains("R.string.media_saving") &&
            feedback.contains("R.string.media_saved_to") && feedback.contains("R.string.media_save_failed"))
    }

    @Test
    fun `缓存根目录按核心的参数名传`() {
        val session = source("core/session/AppSession.kt")
        assertTrue(session.contains("setMediaCacheRoot(mapOf(\"absolutePath\" to"))
        assertFalse(session.contains("setMediaCacheRoot(mapOf(\"root\" to"))
    }
}
