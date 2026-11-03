package com.flare.im.app.core.domain

import java.io.File
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Android 的送达状态必须与**核心** `domain::message_delivery_state` 逐位一致。
 *
 * 向量由核心生成（`cargo test action_availability_vectors`）；
 * 规则一改这里就红，逼你回来看 Android 是否要跟着改。
 *
 * ⚠️ 不能用 `org.json`：JVM 单测里它是**桩实现**，每个方法都直接抛
 * RuntimeException（表现为读文件那一行崩掉，很容易误判成路径写错）。
 * 这里用正则按字段取值，够用且没有额外依赖。
 */
class MessageDeliveryVectorsTest {

    private data class Case(
        val label: String,
        val isSelf: Boolean,
        val status: Int,
        val isRead: Boolean,
        val isPending: Boolean,
        val isFailed: Boolean,
        val expected: String,
    )

    private fun parseCases(json: String): List<Case> {
        // 每个 case 形如 { "deliveryState": "...", "expected": {...}, "input": {...}, "label": "..." }
        val blocks = json.split("\"deliveryState\"").drop(1)
        return blocks.map { block ->
            fun bool(name: String) =
                Regex("\"$name\":\\s*(true|false)").find(block)?.groupValues?.get(1) == "true"
            fun int(name: String) =
                Regex("\"$name\":\\s*(-?\\d+)").find(block)?.groupValues?.get(1)?.toInt() ?: 0
            Case(
                label = Regex("\"label\":\\s*\"([^\"]*)\"").find(block)?.groupValues?.get(1) ?: "?",
                isSelf = bool("isSelf"),
                status = int("status"),
                isRead = bool("isRead"),
                isPending = bool("isPending"),
                isFailed = bool("isFailed"),
                expected = Regex("^:\\s*\"([a-z]+)\"").find(block)?.groupValues?.get(1) ?: "?",
            )
        }
    }

    @Test
    fun `送达状态与核心一致`() {
        val file = File("../../../sdk-spec/message-action-vectors.json")
        assertTrue("向量文件不存在: ${file.absolutePath}", file.exists())
        val cases = parseCases(file.readText())
        assertTrue("向量太少，这条门禁形同虚设（解析到 ${cases.size} 条）", cases.size >= 10)
        for (case in cases) {
            val actual = MessageDelivery.state(
                isSelf = case.isSelf,
                status = case.status,
                isRead = case.isRead,
                isPending = case.isPending,
                isFailed = case.isFailed,
            ).name.lowercase()
            assertEquals("与核心不一致：${case.label}", case.expected, actual)
        }
    }
}
