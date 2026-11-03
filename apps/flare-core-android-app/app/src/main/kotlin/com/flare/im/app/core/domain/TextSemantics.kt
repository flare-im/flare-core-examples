package com.flare.im.app.core.domain

import com.flare.im.model.common.enums.MessageContentType
import com.flare.im.model.entity.MessageContent
import com.flare.im.model.entity.MessagePreview
import org.json.JSONObject
import java.util.Locale

internal fun String?.nonBlank(): String? = this?.trim()?.takeIf { it.isNotEmpty() }

internal fun MessagePreview.previewText(): String =
    text.nonBlank()?.formatStoragePreview() ?: localized("消息", "Message")

internal fun MessageContent.previewText(): String {
    if (contentType == MessageContentType.STICKER) return bracket(localized("贴纸", "Sticker"))
    if (contentType == MessageContentType.EMOJI) {
        return data["emoji"].asPreviewText()
            ?: data["key"].asPreviewText()
            ?: bracket(localized("表情", "Emoji"))
    }

    val preferredKeys = when (contentType) {
        MessageContentType.TEXT -> listOf("text", "body", "markdown", "html")
        MessageContentType.QUOTE -> listOf("text", "quotedTextPreview", "quotePreview")
        MessageContentType.FILE -> listOf("fileName", "filename", "name", "title")
        MessageContentType.IMAGE,
        MessageContentType.VIDEO,
        MessageContentType.AUDIO,
        MessageContentType.IMAGE_GROUP -> listOf("caption", "title", "name", "url")
        MessageContentType.LOCATION -> listOf("title", "address", "name")
        MessageContentType.CARD,
        MessageContentType.LINK_CARD,
        MessageContentType.MINI_PROGRAM -> listOf("title", "description", "url")
        MessageContentType.SYSTEM,
        MessageContentType.NOTIFICATION,
        MessageContentType.ANNOUNCEMENT -> listOf("text", "title", "body")
        MessageContentType.VOTE,
        MessageContentType.TASK,
        MessageContentType.SCHEDULE,
        MessageContentType.FORWARD,
        MessageContentType.THREAD,
        MessageContentType.RICH_TEXT,
        MessageContentType.CUSTOM,
        MessageContentType.PLACEHOLDER,
        // STICKER/EMOJI are returned earlier; listed here only to keep `when` exhaustive.
        MessageContentType.STICKER,
        MessageContentType.EMOJI -> listOf("title", "text", "summary", "hint")
    }

    val rawPreview = preferredKeys.firstNotNullOfOrNull { key -> data[key].asPreviewText() }
        ?: data.values.firstNotNullOfOrNull { value -> value.asPreviewText() }
    return rawPreview?.formatStoragePreview()
        ?: contentType.displayName()
}

internal fun String.formatStoragePreview(): String {
    val text = trim()
    if (!text.startsWith("{")) return this
    return runCatching {
        val payload = JSONObject(text)
        val key = payload.optString("k")
        if (!key.startsWith("im.preview.")) return@runCatching this
        val args = payload.optJSONObject("a") ?: JSONObject()
        when (key) {
            "im.preview.user_text" -> args.optString("t").ifBlank { this }
            "im.preview.sticker" -> bracket(localized("贴纸", "Sticker"))
            "im.preview.emoji" -> args.optString("e").ifBlank { bracket(localized("表情", "Emoji")) }
            "im.preview.rich_text" -> joinPreview(args.optString("title"), args.optString("body")).ifBlank {
                bracket(localized("富文本", "Rich text"))
            }
            "im.preview.image" -> if (args.optBoolean("m")) bracket(localized("动图", "GIF")) else args.optString("d").ifBlank {
                bracket(localized("图片", "Image"))
            }
            "im.preview.video" -> args.optString("d").ifBlank { bracket(localized("视频", "Video")) }
            "im.preview.audio" -> args.optString("d").ifBlank { bracket(localized("语音", "Voice")) }
            "im.preview.file" -> args.optString("n").ifBlank { bracket(localized("文件", "File")) }
            "im.preview.location" -> args.optString("label").let { label ->
                if (label.isBlank()) bracket(localized("位置", "Location")) else "${bracket(localized("位置", "Location"))} $label"
            }
            "im.preview.card" -> args.optString("label").let { label ->
                if (label.isBlank()) bracket(localized("名片", "Contact")) else "${bracket(localized("名片", "Contact"))} $label"
            }
            "im.preview.vote" -> bracket(localized("投票", "Vote"))
            "im.preview.task" -> args.optString("t").let { title ->
                if (title.isBlank()) bracket(localized("任务", "Task")) else "${bracket(localized("任务", "Task"))} $title"
            }
            "im.preview.schedule" -> bracket(localized("日程", "Schedule"))
            "im.preview.announcement" -> args.optString("t").let { title ->
                if (title.isBlank()) bracket(localized("公告", "Announcement")) else "${bracket(localized("公告", "Announcement"))} $title"
            }
            else -> args.optString("t")
                .ifBlank { args.optString("body") }
                .ifBlank { args.optString("title") }
                .ifBlank { bracket(localized("消息", "Message")) }
        }
    }.getOrDefault(this)
}

private fun Any?.asPreviewText(): String? =
    when (this) {
        is String -> nonBlank()
        is Number,
        is Boolean -> toString()
        else -> null
    }

private fun MessageContentType.displayName(): String =
    name.lowercase()
        .split("_")
        .joinToString(" ") { part ->
            part.replaceFirstChar { char -> char.titlecase() }
        }

private fun localized(zh: String, en: String): String =
    if (Locale.getDefault().language.equals("zh", ignoreCase = true)) zh else en

private fun bracket(value: String): String = "[$value]"

private fun joinPreview(vararg values: String): String =
    values.map { it.trim() }.filter { it.isNotEmpty() }.joinToString(" ")
