package com.flare.im.app.features.messaging.messagerow

import com.flare.im.model.entity.MessageContent

// 消息内容字段解析与判定（无 UI）。各内容视图复用，集中在此避免散落。

/** 取首个非空字符串字段（content.data[key]）。 */
internal fun MessageContent.str(vararg keys: String): String? =
    keys.firstNotNullOfOrNull { (data[it] as? String)?.takeIf { s -> s.isNotBlank() } }

/** 媒体本地直链 / 远端 URL 候选字段。 */
internal fun imagePath(content: MessageContent?): String? =
    content?.str("sourceUrl", "url", "path", "localPath")?.takeIf { it.isNotBlank() }
