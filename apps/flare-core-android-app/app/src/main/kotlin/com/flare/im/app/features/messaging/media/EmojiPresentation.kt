package com.flare.im.app.features.messaging.media

/** 表情包 / 贴纸资产解析。资产在 `assets/{emoji,stickers}/`。 */
object EmojiPresentation {
    data class StickerAsset(val packageId: String, val stickerId: String) {
        val id: String get() = "$packageId/$stickerId"
    }

    /** Composer 表情面板的内置表情包 key。 */
    val composerEmojiKeys = listOf(
        "shushing_face", "sleepy_face", "smirking_face", "angry_face", "exploding_head", "expressionless_face",
        "anxious_face_with_sweat", "enraged_face", "alien_monster", "blue_heart", "revolving_hearts", "alien",
        "anger_symbol", "pensive_face", "angry_face_with_horns", "anguished_face", "face_screaming_in_fear", "face_with_open_mouth",
        "beaming_face_with_smiling_eyes", "growing_heart", "broken_heart",
    )

    /** Composer 贴纸面板的内置贴纸（classic 001-012）。 */
    val composerStickers = (1..12).map { StickerAsset("classic", "%03d".format(it)) }

    private val packKeyRegex = Regex("^[a-z][a-z0-9_]*$")
    private val inlinePackRegex = Regex("\\[([a-z][a-z0-9_]*)]")

    fun emojiAssetPath(key: String): String = "emoji/$key.webp"

    fun stickerAssetPath(packageId: String, stickerId: String): String =
        "stickers/${stickerSubdirectory(packageId)}/$stickerId.webp"

    fun stickerSubdirectory(packageId: String): String = if (packageId == "gifs") "default" else packageId

    /** 归一化表情包 key：去 `[]` + 校验形如 `lower_snake`。 */
    fun normalizedPackKey(value: String?): String? {
        val trimmed = value?.trim().orEmpty()
        if (trimmed.isEmpty()) return null
        val raw = if (trimmed.startsWith("[") && trimmed.endsWith("]") && trimmed.length > 2) {
            trimmed.substring(1, trimmed.length - 1)
        } else trimmed
        return if (packKeyRegex.matches(raw)) raw else null
    }

    /** 文本是否整体是单个表情包 token（如 `[broken_heart]`），用于"独立大图"渲染。 */
    fun lonePackKey(value: String?): String? {
        val trimmed = value?.trim().orEmpty()
        val match = inlinePackRegex.matchEntire(trimmed) ?: return null
        return match.groupValues[1]
    }

    /** 单个 unicode emoji（如 😂），用于放大渲染。 */
    fun singleEmoji(value: String?): String? {
        val trimmed = value?.trim().orEmpty()
        if (trimmed.isEmpty()) return null
        val cp = trimmed.codePointCount(0, trimmed.length)
        if (cp != 1) return null
        val first = trimmed.codePointAt(0)
        return if (Character.getType(first) == Character.OTHER_SYMBOL.toInt() ||
            (first in 0x1F000..0x1FAFF) || (first in 0x2600..0x27BF)
        ) trimmed else null
    }
}
