package com.flare.im.app.features.messaging.composer

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.KeyboardActions
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.outlined.*
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Stop
import androidx.compose.material.icons.automirrored.outlined.Article
import androidx.compose.material.icons.automirrored.outlined.Send
import androidx.compose.foundation.horizontalScroll
import androidx.compose.material.icons.outlined.Add
import androidx.compose.material.icons.outlined.AlternateEmail
import androidx.compose.material.icons.outlined.Close
import androidx.compose.material.icons.outlined.Code
import androidx.compose.material.icons.outlined.EmojiEmotions
import androidx.compose.material.icons.outlined.FormatBold
import androidx.compose.material.icons.automirrored.outlined.FormatListBulleted
import androidx.compose.material.icons.outlined.FormatItalic
import androidx.compose.material.icons.outlined.FormatListNumbered
import androidx.compose.material.icons.outlined.FormatQuote
import androidx.compose.material.icons.outlined.FormatStrikethrough
import androidx.compose.material.icons.outlined.Image
import androidx.compose.material.icons.outlined.MicNone
import androidx.compose.material.icons.outlined.Title
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.TextRange
import androidx.compose.ui.text.input.TextFieldValue
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.unit.dp
import com.flare.im.app.R
import com.flare.im.app.core.designsystem.FlareTheme
import com.flare.im.app.core.domain.MessageBuildOp
import com.flare.im.app.core.platform.AudioRecorder
import com.flare.im.app.core.platform.FlareAssetImage
import com.flare.im.app.features.messaging.MessagingViewModel
import com.flare.im.app.features.messaging.media.EmojiPresentation
import com.flare.im.ui.FlareCapabilitySupport
import com.flare.im.ui.FlarePickFilesOptions
import com.flare.im.ui.FlarePickImagesOptions
import com.flare.im.ui.FlarePickedFile
import com.flare.im.ui.FlarePlatformErrorCode
import com.flare.im.ui.FlarePlatformResult
import com.flare.im.ui.callFlarePlatform
import com.flare.im.ui.flarePlatform
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.launch

/** 输入区：文本 + 表情/贴纸面板 + 扩展构建菜单 +
 *  录音 + 图片选择 + 发送。自持状态，仅依赖 [MessagingViewModel]。 */
@Composable
fun ComposerBar(vm: MessagingViewModel, conversationTitle: String) {
    val conversation by vm.selectedConversation.collectAsState()
    val reply by vm.replyTarget.collectAsState()
    val runtimeStatus by vm.runtimeStatus.collectAsState()
    var emojiPanel by remember { mutableStateOf(false) }
    var formOp by remember { mutableStateOf<MessageBuildOp?>(null) }
    // Layer 5：选择器由宿主适配器执行（MainActivity 装配），这里只读能力决定入口是否存在。
    val platform = flarePlatform()
    val capabilities = platform.capabilities
    val pickerScope = rememberCoroutineScope()
    val allOps = listOf(MessageBuildOp.CreateVideo, MessageBuildOp.CreateLocation, MessageBuildOp.CreateFile, MessageBuildOp.CreateCard, MessageBuildOp.CreateTask, MessageBuildOp.CreateVote, MessageBuildOp.CreateSchedule, MessageBuildOp.CreateRichDoc, MessageBuildOp.CreateLinkCard, MessageBuildOp.CreateSticker)
    val ops = if (capabilities.filePicker == FlareCapabilitySupport.Unsupported) {
        allOps.filterNot { it == MessageBuildOp.CreateFile }
    } else {
        allOps
    }
    Column {
        if (emojiPanel) EmojiStickerPanel(vm) { emojiPanel = false }
        com.flare.im.ui.Composer(
            conversationKey = conversation?.conversationId ?: "",
            placeholder = stringResource(R.string.composer_hint, conversationTitle),
            disabled = runtimeStatus.isBlocking,
            replyTo = reply?.let { com.flare.im.ui.FlareReplyTarget(it.core.senderId, it.previewText) },
            onCancelReply = { vm.cancelReply() },
            onSend = { vm.sendText(it) },
            onSendRich = { vm.buildAndSend(MessageBuildOp.CreateRichDoc, mapOf("markdown" to it)) },
            onEmoji = { emojiPanel = !emojiPanel },
            onImage = if (capabilities.imagePicker == FlareCapabilitySupport.Unsupported) null else {
                {
                    pickerScope.pick(
                        vm = vm,
                        operation = "platform.pickImages",
                        request = { platform.pickImages(FlarePickImagesOptions(multiple = false)) },
                    ) { picked -> vm.sendPickedImage(picked.uri ?: picked.path ?: "") }
                }
            },
            enableVoice = true,
            onVoiceSend = { path, duration -> vm.sendVoiceClip(path, duration) },
            actions = ops.map { com.flare.im.ui.FlareComposerAction(it.name, it.name.removePrefix("Create"), when (it) {
                MessageBuildOp.CreateVideo -> "video"
                MessageBuildOp.CreateLocation -> "location"
                MessageBuildOp.CreateFile -> "file"
                MessageBuildOp.CreateCard -> "card"
                MessageBuildOp.CreateTask -> "check"
                MessageBuildOp.CreateVote -> "poll"
                MessageBuildOp.CreateSchedule -> "calendar"
                MessageBuildOp.CreateLinkCard -> "link"
                MessageBuildOp.CreateSticker -> "emoji"
                else -> "file"
            }) },
            onAction = { action ->
                ops.find { it.name == action.id }?.let { op ->
                    when {
                        op == MessageBuildOp.CreateFile -> pickerScope.pick(
                            vm = vm,
                            operation = "platform.pickFiles",
                            request = { platform.pickFiles(FlarePickFilesOptions(multiple = false)) },
                        ) { picked -> vm.sendPickedFile(picked.name, picked.uri ?: picked.path, picked.mimeType, picked.size) }
                        op in formOps -> formOp = op
                        else -> vm.buildAndSend(op)
                    }
                }
            },
        )
    }
    formOp?.let { ComposerFormDialog(it, vm) { formOp = null } }
}

/**
 * 跑一次适配器选择操作：CANCELLED（含空选择）静默，其余错误码进 Lab 日志。
 * 宿主不写 try/catch —— [callFlarePlatform] 已把抛出归一化成契约错误码。
 */
private fun CoroutineScope.pick(
    vm: MessagingViewModel,
    operation: String,
    request: suspend () -> FlarePlatformResult<List<FlarePickedFile>>,
    onPicked: (FlarePickedFile) -> Unit,
) {
    launch {
        when (val result = callFlarePlatform(timeoutMs = 120_000) { request() }) {
            is FlarePlatformResult.Ok -> result.value.firstOrNull()?.let(onPicked)
            is FlarePlatformResult.Err -> if (result.error.code != FlarePlatformErrorCode.CANCELLED) {
                vm.notePlatformError(operation, "${result.error.code}: ${result.error.message ?: ""}")
            }
        }
    }
}

/** 表情 + 贴纸选择面板：委托 kit 的选择器（157 表情 + 全部贴纸包，中心源资源），点选即发送。 */
@Composable
private fun EmojiStickerPanel(vm: MessagingViewModel, onClose: () -> Unit) {
    com.flare.im.ui.FlareEmojiStickerPicker(
        emojiLabel = "Emoji",
        onInsertEmoji = { key ->
            vm.buildAndSend(MessageBuildOp.CreateEmoji, mapOf("emoji" to key)); onClose()
        },
        onSendSticker = { packageId, stickerId ->
            vm.buildAndSend(MessageBuildOp.CreateSticker, mapOf("stickerId" to stickerId, "packageId" to packageId)); onClose()
        },
    )
}

// 这些 build op 弹表单收集输入（其余直接用默认内容发送）。
private val formOps = setOf(
    MessageBuildOp.CreateVote, MessageBuildOp.CreateLocation, MessageBuildOp.CreateCard,
    MessageBuildOp.CreateLinkCard, MessageBuildOp.CreateTask, MessageBuildOp.CreateRichDoc,
)

private data class FormSpec(val title: String, val fields: List<Triple<String, String, String>>)

private fun formSpec(op: MessageBuildOp): FormSpec = when (op) {
    MessageBuildOp.CreateVote -> FormSpec("New vote", listOf(
        Triple("title", "Question", "Lunch?"),
        Triple("options", "Options (comma-separated)", "Pizza,Sushi,Salad"),
    ))
    MessageBuildOp.CreateLocation -> FormSpec("Share location", listOf(
        Triple("title", "Title", "Office"),
        Triple("address", "Address", "Shanghai"),
        Triple("latitude", "Latitude", "31.2304"),
        Triple("longitude", "Longitude", "121.4737"),
    ))
    MessageBuildOp.CreateCard -> FormSpec("Card", listOf(
        Triple("title", "Title", "Card"),
        Triple("subtitle", "Subtitle", ""),
    ))
    MessageBuildOp.CreateLinkCard -> FormSpec("Link card", listOf(
        Triple("url", "URL", "https://flare.local"),
        Triple("title", "Title", "Flare"),
        Triple("description", "Description", ""),
    ))
    MessageBuildOp.CreateTask -> FormSpec("Task", listOf(
        Triple("title", "Task title", "Task"),
        Triple("participantUserIds", "Participants (comma)", ""),
    ))
    MessageBuildOp.CreateRichDoc -> FormSpec("Rich doc", listOf(
        Triple("title", "Title", "Rich Doc"),
        Triple("markdown", "Markdown", "## Heading\n\n- point one\n- **bold** point"),
    ))
    else -> FormSpec(op.name, emptyList())
}

private fun convertFormField(key: String, value: String): Any? = when (key) {
    "options", "participantUserIds" -> value.split(",").map { it.trim() }.filter { it.isNotEmpty() }
    "latitude", "longitude" -> value.toDoubleOrNull() ?: 0.0
    else -> value
}

/** 富消息构建表单：按 build op 收集字段 → buildAndSend(payload)。 */
@Composable
private fun ComposerFormDialog(op: MessageBuildOp, vm: MessagingViewModel, onDismiss: () -> Unit) {
    val tk = FlareTheme.tokens
    val spec = remember(op) { formSpec(op) }
    val values = remember(op) { mutableStateMapOf<String, String>().apply { spec.fields.forEach { put(it.first, it.third) } } }
    val multiline = setOf("options", "participantUserIds", "description", "markdown")
    AlertDialog(
        onDismissRequest = onDismiss,
        confirmButton = {
            com.flare.im.ui.Button(label = stringResource(R.string.composer_form_send), onClick = {
                vm.buildAndSend(op, values.mapValues { (k, v) -> convertFormField(k, v) })
                onDismiss()
            })
        },
        dismissButton = { com.flare.im.ui.Button(label = stringResource(R.string.action_cancel), variant = com.flare.im.ui.FlareButtonVariant.Secondary, onClick = onDismiss) },
        title = { Text(spec.title, style = MaterialTheme.typography.titleMedium) },
        text = {
            Column(verticalArrangement = Arrangement.spacedBy(tk.sm)) {
                spec.fields.forEach { (key, label, _) ->
                    com.flare.im.ui.FormField(label = label) {
                        com.flare.im.ui.Input(
                            value = values[key] ?: "",
                            onValueChange = { values[key] = it },
                            multiline = key in multiline,
                        )
                    }
                }
            }
        },
    )
}
