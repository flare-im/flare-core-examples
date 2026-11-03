package com.flare.im.app.features.messaging

import java.io.File
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * 消息菜单的三条约束，钉的是**源码形态**：
 * 真正的失败要在真机上长按一条别人的消息、看到 Recall、点下去才暴露，
 * 而形态判据是确定的。
 */
class MessageMenuGatingTest {

    private val menuSource: String by lazy {
        File("src/main/kotlin/com/flare/im/app/features/messaging/messagerow/MessageRowView.kt")
            .readText()
    }

    @Test
    fun `长按面板是 kit 的 MessageActionSheet，按核心的判定渲染`() {
        assertTrue(
            "面板必须消费核心的 action_availability",
            menuSource.contains("vm.actionAvailability(message)"),
        )
        // 标准动作的门控、文案、分组在 kit 里（kit 有逐项单测）；app 把核心的答案原样交过去，
        // 不能再自己拼一份动作列表或自己画菜单——那正是 Pin/Unpin 同列、别人的消息也能撤回的来路。
        assertTrue("面板必须是 kit 的 MessageActionSheet", menuSource.contains("MessageActionSheet("))
        assertTrue("核心的可用性原样交给 kit", menuSource.contains("availability = allowed"))
        assertFalse(
            "不能再用 Material 下拉菜单自己画",
            Regex("""import androidx\.compose\.material3\.DropdownMenu""").containsMatchIn(menuSource),
        )
    }

    @Test
    fun `菜单文案走字符串资源，不硬编码`() {
        for (hardcoded in listOf("\"Recall\"", "\"Delete for me\"", "\"Edit text\"", "\"Forward\"")) {
            assertFalse("菜单文案 $hardcoded 必须迁进 strings.xml", menuSource.contains(hardcoded))
        }
        assertTrue(menuSource.contains("R.string.msg_action_delete_everyone"))
    }

    @Test
    fun `编辑不得把原文替换成写死的占位串`() {
        val vmSource = File(
            "src/main/kotlin/com/flare/im/app/features/messaging/MessagingViewModel.kt",
        ).readText()
        // 判据要看**赋值形态**而不是字符串出现：注释里引用这个旧串是合理的
        // （说明为什么不能这么写），把注释也算成违规会让门禁误报。
        assertFalse(
            "编辑必须用调用方传入的正文——写死占位串等于把用户的内容删了",
            Regex("""\"text\"\s+to\s+\"[^\"]*Edited from Android""").containsMatchIn(vmSource),
        )
        assertTrue(vmSource.contains("\"text\" to text"))
    }

    @Test
    fun `回应与标记按核心的参数契约发请求`() {
        val vmSource = File(
            "src/main/kotlin/com/flare/im/app/features/messaging/MessagingViewModel.kt",
        ).readText()
        // add_reaction / remove_reaction 读 emoji；mark_by_message_id 要 markType + color，
        // unmark_by_message_id 要 markType。字段不对时核心回 INVALID_PARAMETER，只进实验室日志，
        // 界面上点了没反应——真机上长按回应、标记时实测过。
        assertTrue(vmSource.contains("addReaction(req + (\"emoji\" to reaction))"))
        assertTrue(vmSource.contains("removeReaction(req + (\"emoji\" to reaction))"))
        assertFalse(Regex("""\"reaction\"\s+to\s+reaction""").containsMatchIn(vmSource))
        assertTrue(
            Regex("""markMessageById\(req \+ \("markType" to \w+\) \+ \("color" to \w+\)\)""").containsMatchIn(vmSource),
        )
        assertTrue(Regex("""unmarkMessageById\(req \+ \("markType" to \w+\)\)""").containsMatchIn(vmSource))
    }
}
