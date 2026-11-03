package com.flare.im.app.core.domain

import com.flare.im.api.FlareImClient
import com.flare.im.app.core.domain.AppMessage
import com.flare.im.model.command.NormalizeRichDocFromMarkdownRequest
import com.flare.im.model.command.message.build.*
import com.flare.im.model.content.AudioContentPayload
import com.flare.im.model.content.ImageContentPayload
import com.flare.im.model.content.StickerContentPayload
import com.flare.im.model.content.VideoContentPayload
import com.flare.im.model.media.MediaSourceInfo
import com.flare.im.model.entity.Message
import com.flare.im.model.entity.MessageContent
import com.flare.im.model.common.enums.MessageContentType
import org.json.JSONArray
import org.json.JSONObject

/** Composer / SDK Lab 可触发的构建操作。 */
enum class MessageBuildOp {
    CreateText, CreateEmoji, CreateSticker, CreateLocation, CreateCard, CreateRichDoc,
    CreateImage, CreateVideo, CreateAudio, CreateFile, CreateLinkCard, CreateMiniProgram,
    CreateForward, CreateQuote, CreateTask, CreateVote, CreateSchedule,
    CreateNotification, CreateAnnouncement, CreatePlaceholder,
}

/**
 * 把无类型 `payload` 经 SDK `messageBuilder` 门面构建为 typed Core message。
 * 无状态消息构建器；forward/quote 默认值经 `selectedMessages` 显式入参。
 */
object MessageBuilder {
    suspend fun build(
        client: FlareImClient,
        conversationId: String,
        op: MessageBuildOp,
        payload: Map<String, Any?>,
        selectedMessages: List<AppMessage>,
    ): Message {
        val mb = client.messageBuilder
        return when (op) {
            MessageBuildOp.CreateText -> mb.buildText(
                BuildTextMessageRequest(conversationId, str(payload, "text", "Hello from Android SDK")),
            )
            MessageBuildOp.CreateEmoji -> mb.buildEmoji(
                BuildEmojiMessageRequest(conversationId, str(payload, "emoji", "wave")),
            )
            MessageBuildOp.CreateSticker -> {
                val stickerId = str(payload, "stickerId", "flare-default")
                val packageId = str(payload, "packageId", "default")
                mb.buildSticker(
                    BuildStickerMessageRequest(
                        conversationId, stickerId, packageId,
                        StickerContentPayload(
                            stickerId = stickerId, packageId = packageId,
                            url = optStr(payload, "url"), format = optStr(payload, "format") ?: "webp",
                        ),
                    ),
                )
            }
            MessageBuildOp.CreateLocation -> mb.buildLocation(
                BuildLocationMessageRequest(
                    conversationId,
                    dbl(payload, "latitude", 31.2304), dbl(payload, "longitude", 121.4737),
                    str(payload, "title", "Location"), str(payload, "address", "Shanghai"),
                ),
            )
            MessageBuildOp.CreateCard -> mb.buildCard(
                BuildCardMessageRequest(
                    conversationId, str(payload, "id", "demo-card"),
                    str(payload, "cardType", "user"), str(payload, "title", "Card"),
                    str(payload, "subtitle", ""), str(payload, "avatar", ""),
                ),
            )
            MessageBuildOp.CreateRichDoc -> {
                val markdown = str(payload, "markdown", "## Hello from Android SDK")
                // 用 SDK 把 Markdown 规范化为 RichDoc v2（core 实现）；失败回退本地 docJson。
                val normalized = runCatching {
                    mb.normalizeRichDocFromMarkdown(NormalizeRichDocFromMarkdownRequest(markdown))
                }.getOrNull()
                val plainText = normalized?.plainText?.ifBlank { null } ?: str(payload, "plainText", markdown)
                mb.buildRichDoc(
                    BuildRichDocMessageRequest(
                        conversationId = conversationId,
                        docJson = normalized?.docJson?.ifBlank { null } ?: str(payload, "docJson", richDocJson(plainText)),
                        contentSchema = normalized?.contentSchema?.ifBlank { null } ?: str(payload, "contentSchema", "rich_doc"),
                        plainText = plainText,
                        inputFormat = str(payload, "inputFormat", "markdown"),
                        inputFormatVersion = normalized?.version?.takeIf { it > 0 } ?: int(payload, "inputFormatVersion", 1),
                        sourcePayload = mapOf("markdown" to markdown),
                        title = str(payload, "title", "Rich Doc"),
                        searchText = normalized?.searchText?.ifBlank { null } ?: str(payload, "searchText", plainText),
                    ),
                )
            }
            MessageBuildOp.CreateImage -> mb.buildImage(makeImageRequest(conversationId, payload))
            MessageBuildOp.CreateVideo -> mb.buildVideo(makeVideoRequest(conversationId, payload))
            MessageBuildOp.CreateAudio -> mb.buildAudio(makeAudioRequest(conversationId, payload))
            MessageBuildOp.CreateFile -> {
                val data = buildMap<String, Any?> {
                    put("fileId", str(payload, "fileId", "demo-file"))
                    put("name", str(payload, "fileName", "report.pdf"))
                    optStr(payload, "url")?.let { put("url", it) }
                    optStr(payload, "mimeType")?.let { put("mimeType", it) }
                    longOrNull(payload, "size")?.let { put("size", it) }
                }
                mb.buildWithContent(
                    BuildWithContentMessageRequest(conversationId, MessageContent(MessageContentType.FILE, data)),
                )
            }
            MessageBuildOp.CreateLinkCard -> mb.buildLinkCard(
                BuildLinkCardMessageRequest(
                    conversationId, str(payload, "url", "https://flare.local"),
                    str(payload, "title", "Flare Link"), str(payload, "description", "Link card from Android SDK"),
                    str(payload, "thumbnailUrl", ""), str(payload, "siteName", "Flare"),
                ),
            )
            MessageBuildOp.CreateMiniProgram -> mb.buildMiniProgram(
                BuildMiniProgramMessageRequest(
                    conversationId, str(payload, "appId", "flare-mini"),
                    str(payload, "pagePath", "/"), str(payload, "title", "Flare Mini Program"),
                    str(payload, "thumbnailUrl", ""), mapOf("source" to "android-example"),
                ),
            )
            MessageBuildOp.CreateForward -> {
                // 必须传**完整消息**而不是 id 存根：转发载荷要把原文嵌进去，
                // 核心侧 forward_item_from_source 会读 content / senderId / conversationId。
                // 早先按 ForwardSourceMessage 传，反序列化成 IMMessage 时缺必填字段
                // 直接 INVALID_PARAMETER，转发每次都失败；契约已改成 Message。
                val src = requireNotNull(selectedMessages.lastOrNull()) {
                    "Select a message to forward first."
                }
                mb.buildForward(
                    BuildForwardMessageRequest(
                        conversationId, true, str(payload, "title", "Forwarded message"),
                        listOf(src.core),
                    ),
                )
            }
            MessageBuildOp.CreateQuote -> {
                val last = selectedMessages.lastOrNull()
                val quoted = last?.core?.content ?: MessageContent(MessageContentType.TEXT, mapOf("text" to (last?.previewText ?: "")))
                mb.buildQuote(
                    BuildQuoteMessageRequest(
                        conversationId,
                        str(payload, "quotedMessageId", last?.core?.serverId ?: ""),
                        str(payload, "text", "Quoted from Android SDK Lab"),
                        last?.core?.senderId, last?.previewText, quoted,
                    ),
                )
            }
            MessageBuildOp.CreateTask -> mb.buildTask(
                BuildTaskMessageRequest(
                    conversationId, str(payload, "taskId", "task-${System.currentTimeMillis()}"),
                    str(payload, "title", "Task"), str(payload, "status", "todo"),
                    strList(payload, "participantUserIds"),
                ),
            )
            MessageBuildOp.CreateVote -> mb.buildVote(
                BuildVoteMessageRequest(
                    conversationId, str(payload, "voteId", "vote-${System.currentTimeMillis()}"),
                    str(payload, "title", "Vote"), strList(payload, "options", listOf("A", "B")),
                ),
            )
            MessageBuildOp.CreateSchedule -> {
                val start = System.currentTimeMillis() + 1_800_000
                mb.buildSchedule(
                    BuildScheduleMessageRequest(
                        conversationId, str(payload, "scheduleId", "schedule-${System.currentTimeMillis()}"),
                        str(payload, "title", "Schedule"),
                        long(payload, "startTimeMs", start), long(payload, "endTimeMs", start + 3_600_000),
                        strList(payload, "participantUserIds"),
                    ),
                )
            }
            MessageBuildOp.CreateNotification -> mb.buildNotification(
                BuildNotificationMessageRequest(
                    conversationId, str(payload, "title", "Notification"),
                    str(payload, "body", "Notification from Android SDK"),
                ),
            )
            MessageBuildOp.CreateAnnouncement -> mb.buildAnnouncement(
                BuildAnnouncementMessageRequest(
                    conversationId, str(payload, "title", "Announcement"),
                    str(payload, "body", "Announcement from Android SDK"),
                ),
            )
            MessageBuildOp.CreatePlaceholder -> mb.buildPlaceholder(
                BuildPlaceholderMessageRequest(conversationId, str(payload, "reason", "Capability unavailable")),
            )
        }
    }

    fun makeImageRequest(conversationId: String, payload: Map<String, Any?>): BuildImageMessageRequest {
        val imageId = str(payload, "imageId", "demo-image")
        return BuildImageMessageRequest(
            conversationId, imageId,
            ImageContentPayload(
                imageId = imageId,
                source = mediaSource(imageId, payload, includeImageId = true),
                description = str(payload, "description", "Image from Android SDK"),
            ),
        )
    }

    fun makeVideoRequest(conversationId: String, payload: Map<String, Any?>): BuildVideoMessageRequest {
        val videoId = str(payload, "videoId", "demo-video")
        return BuildVideoMessageRequest(
            conversationId, videoId,
            VideoContentPayload(
                videoId = videoId,
                source = mediaSource(videoId, payload, includeImageId = false),
                description = str(payload, "description", "Video from Android SDK"),
            ),
        )
    }

    fun makeAudioRequest(conversationId: String, payload: Map<String, Any?>): BuildAudioMessageRequest {
        val audioId = str(payload, "audioId", "demo-audio")
        val durationMs = intOrNull(payload, "durationMs") ?: 18000
        return BuildAudioMessageRequest(
            conversationId, audioId,
            AudioContentPayload(
                audioId = audioId,
                source = mediaSource(audioId, payload, includeImageId = false),
                durationMs = durationMs,
            ),
        )
    }

    private fun mediaSource(id: String, payload: Map<String, Any?>, includeImageId: Boolean) = MediaSourceInfo(
        uuid = id,
        imageId = if (includeImageId) id else null,
        url = optStr(payload, "sourceUrl") ?: optStr(payload, "url"),
        mimeType = optStr(payload, "mimeType"),
        size = longOrNull(payload, "size"),
        width = intOrNull(payload, "width"),
        height = intOrNull(payload, "height"),
        durationMs = intOrNull(payload, "durationMs"),
    )

    // MARK: payload readers
    private fun str(p: Map<String, Any?>, k: String, default: String): String =
        when (val v = p[k]) { null -> default; is String -> v; else -> v.toString() }
    private fun optStr(p: Map<String, Any?>, k: String): String? =
        (p[k] as? String)?.trim()?.takeIf { it.isNotEmpty() } ?: p[k]?.toString()?.takeIf { p[k] != null }
    private fun dbl(p: Map<String, Any?>, k: String, default: Double): Double =
        when (val v = p[k]) { is Double -> v; is Int -> v.toDouble(); is String -> v.toDoubleOrNull() ?: default; else -> default }
    private fun int(p: Map<String, Any?>, k: String, default: Int): Int = intOrNull(p, k) ?: default
    private fun intOrNull(p: Map<String, Any?>, k: String): Int? =
        when (val v = p[k]) { is Int -> v; is Long -> v.toInt(); is Double -> v.toInt(); is String -> v.toIntOrNull(); else -> null }
    private fun long(p: Map<String, Any?>, k: String, default: Long): Long = longOrNull(p, k) ?: default
    private fun longOrNull(p: Map<String, Any?>, k: String): Long? =
        when (val v = p[k]) { is Long -> v; is Int -> v.toLong(); is Double -> v.toLong(); is String -> v.toLongOrNull(); else -> null }
    private fun strList(p: Map<String, Any?>, k: String, default: List<String> = emptyList()): List<String> =
        when (val v = p[k]) {
            is List<*> -> v.mapNotNull { it?.toString() }
            is String -> v.split(',', ' ', '\n').map { it.trim() }.filter { it.isNotEmpty() }.ifEmpty { default }
            else -> default
        }

    private fun richDocJson(text: String): String {
        val children = JSONArray()
        text.split("\n").forEach { paragraph ->
            val block = JSONObject().put("type", "paragraph")
            val kids = JSONArray()
            if (paragraph.isNotEmpty()) kids.put(JSONObject().put("type", "text").put("text", paragraph))
            block.put("children", kids)
            children.put(block)
        }
        return JSONObject().put("type", "doc").put("version", 2).put("children", children).toString()
    }
}
