package com.flare.im.app.features.messaging.messagerow

import androidx.compose.material3.MaterialTheme

import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalClipboardManager
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.unit.dp
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.outlined.DeleteForever
import androidx.compose.material.icons.outlined.EditNote
import androidx.compose.material.icons.filled.Check
import androidx.compose.material3.Icon
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import com.flare.im.app.core.domain.MessageDelivery
import com.flare.im.app.core.domain.MessageDeliveryState
import androidx.compose.material.icons.filled.Warning
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.width
import com.flare.im.app.R
import com.flare.im.model.common.enums.MessageContentType
import com.flare.im.app.core.designsystem.FlareTheme
import com.flare.im.app.core.domain.AppMessage
import com.flare.im.app.core.domain.MessageBuildOp
import com.flare.im.app.core.domain.PictureAccess
import com.flare.im.app.features.messaging.MessagingViewModel
import com.flare.im.app.features.messaging.media.rememberMediaSaver
import com.flare.im.ui.FlareAudioContent
import com.flare.im.ui.FlareCardContent
import com.flare.im.ui.FlareConversationKind
import com.flare.im.ui.FlareEmojiContent
import com.flare.im.ui.FlareFileContent
import com.flare.im.ui.FlareGenericContent
import com.flare.im.ui.FlareImageContent
import com.flare.im.ui.FlareLocationContent
import com.flare.im.ui.FlareMessageContent
import com.flare.im.ui.FlareMessageData
import com.flare.im.ui.FlareMessageDeliveryStatus
import com.flare.im.ui.FlareNotificationContent
import com.flare.im.ui.FlarePlaceholderContent
import com.flare.im.ui.FlareStickerContent
import com.flare.im.ui.FlareTextContent
import com.flare.im.ui.FlareVideoContent
import com.flare.im.ui.FlarePollContent
import com.flare.im.ui.FlareTaskContent
import com.flare.im.ui.FlareCalendarContent
import com.flare.im.ui.FlareMiniAppContent
import com.flare.im.ui.FlareAnnouncementContent
import com.flare.im.ui.FlareLinkCardContent
import com.flare.im.ui.FlareMessageActionAvailability
import com.flare.im.ui.FlareMessageMenuEntry
import com.flare.im.ui.FlareMessageMenuGroup
import com.flare.im.ui.MessageActionSheet
import com.flare.im.ui.MessageBubble
import com.flare.im.ui.flareColors
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlinx.coroutines.Job
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.launch

/** SDK data/action adapter around the public design-kit message bubble. */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun MessageRow(message: AppMessage, outgoing: Boolean, vm: MessagingViewModel) {
    var menu by remember { mutableStateOf(false) }
    var previewPath by remember { mutableStateOf<String?>(null) }
    var playbackPath by remember { mutableStateOf<String?>(null) }
    var playbackIsVideo by remember { mutableStateOf(false) }
    // 保存到本机 is the core's; the saver says 正在保存… / 已保存到 … / why not.
    val saveMedia = rememberMediaSaver(vm)
    // A picture is drawn from the core's cached copy once it has one (`media.resolve_access` with autoCache):
    // seen pictures are not downloaded again. Only this answer ever becomes the kit's localPath.
    val picture by produceState<PictureAccess?>(null, message.appStableId) { value = vm.resolvePicture(message) }
    val mediaScope = rememberCoroutineScope()
    var mediaJob by remember { mutableStateOf<Job?>(null) }
    val pending by vm.pendingMessageKeys.collectAsState()
    val failed by vm.failedMessageKeys.collectAsState()
    val clipboard = LocalClipboardManager.current
    val me by vm.currentUserId.collectAsState()
    // 送达状态：判定用核心那一份（MessageDelivery，由 sdk-spec 向量钉住）。
    val deliveryState = MessageDelivery.state(
        isSelf = outgoing,
        status = message.core.status,
        isRead = message.core.isRead,
        isPending = message.appStableId in pending,
        isFailed = message.appStableId in failed,
    )
    val presentation = message.toPresentation(deliveryState, picture)

    Column(Modifier.fillMaxWidth()) {
        Box {
            Box(
                Modifier.fillMaxWidth().combinedClickable(
                    onClick = {},
                    onLongClick = { if (!message.core.isRecalled) menu = true },
                ),
            ) {
                MessageBubble(
                    message = presentation,
                    currentUserId = me.orEmpty(),
                    conversationKind = FlareConversationKind.Group,
                    onMediaAction = { _, media ->
                        mediaJob?.cancel()
                        if (media is FlareFileContent) {
                            // A file has nothing to preview here: its tap keeps it, in the download location.
                            saveMedia(message)
                        } else if (media is FlareImageContent || media is FlareVideoContent || media is FlareAudioContent) {
                            mediaJob = mediaScope.launch {
                                val path = vm.resolveMediaUrl(message)
                                ensureActive()
                                if (media is FlareImageContent) previewPath = path
                                else {
                                    playbackIsVideo = media is FlareVideoContent
                                    playbackPath = path
                                }
                            }
                        }
                    },
                    onResend = if (outgoing) ({ vm.retry(message) }) else null,
                )
            }
            MessageActionMenu(message, menu, clipboard, vm, onSave = { saveMedia(message) }) { menu = it }
        }

        ReactionStrip(message, me, vm)
    }
    // The preview's and the video player's download keys save the message through the core.
    previewPath?.let { p -> MediaPreviewDialog(p, onDownload = { saveMedia(message) }) { previewPath = null } }
    playbackPath?.let { p ->
        PlatformPlaybackDialog(p, onDownload = if (playbackIsVideo) ({ saveMedia(message) }) else null) { playbackPath = null }
    }
}

private fun AppMessage.toPresentation(deliveryState: MessageDeliveryState, picture: PictureAccess? = null): FlareMessageData {
    val rawTimestamp = core.createdAt.takeIf { it > 0L } ?: core.clientCreatedAt
    val timestampMs = if (rawTimestamp in 1 until 10_000_000_000L) rawTimestamp * 1000 else rawTimestamp
    return FlareMessageData(
        id = appStableId,
        senderId = core.senderId,
        senderName = senderTitle,
        senderAvatarUrl = core.senderAvatar.takeIf { it.isNotBlank() },
        content = if (core.isRecalled) {
            FlareNotificationContent("Message recalled")
        } else {
            core.content.toPresentationContent(previewText, picture)
        },
        timeLabel = SimpleDateFormat("HH:mm", Locale.getDefault()).format(Date(timestampMs)),
        status = when (deliveryState) {
            MessageDeliveryState.NONE -> FlareMessageDeliveryStatus.Sent
            MessageDeliveryState.SENDING -> FlareMessageDeliveryStatus.Sending
            MessageDeliveryState.FAILED -> FlareMessageDeliveryStatus.Failed
            MessageDeliveryState.DELIVERED -> FlareMessageDeliveryStatus.Sent
            MessageDeliveryState.READ -> FlareMessageDeliveryStatus.Read
        },
        edited = core.isEdited,
    )
}

/**
 * [picture] is the core's answer for this message's picture: its cached copy becomes the kit's `localPath` (next to
 * the URL when there is one) and its signed URL stands in when the message carries no address of its own.
 */
internal fun com.flare.im.model.entity.MessageContent?.toPresentationContent(
    fallback: String,
    picture: PictureAccess? = null,
): FlareMessageContent {
    val content = this ?: return FlarePlaceholderContent(fallback)
    val duration = (content.data["durationSec"] as? Number)?.toInt()
        ?: ((content.data["durationMs"] as? Number)?.toInt() ?: 0) / 1000
    return when (content.contentType) {
        MessageContentType.TEXT, MessageContentType.RICH_TEXT, MessageContentType.QUOTE,
        MessageContentType.FORWARD, MessageContentType.THREAD ->
            FlareTextContent(content.str("text", "plainText", "body", "markdown") ?: fallback)
        MessageContentType.IMAGE, MessageContentType.IMAGE_GROUP -> {
            val url = imagePath(content) ?: picture?.url
            if (url == null && picture?.localPath == null) FlarePlaceholderContent(fallback)
            else FlareImageContent(url.orEmpty(), alt = content.str("description", "title"), localPath = picture?.localPath)
        }
        MessageContentType.VIDEO ->
            imagePath(content)?.let { FlareVideoContent(it, content.str("thumbnailUrl", "poster"), duration) }
                ?: FlarePlaceholderContent(fallback)
        MessageContentType.AUDIO -> FlareAudioContent(imagePath(content).orEmpty(), duration)
        MessageContentType.FILE -> FlareFileContent(
            content.str("fileName", "filename", "name") ?: fallback,
            imagePath(content).orEmpty(),
            (content.data["size"] as? Number)?.toInt() ?: 0,
        )
        MessageContentType.LOCATION -> FlareLocationContent(
            content.str("title", "name", "address") ?: "Location",
            content.str("address").orEmpty(),
        )
        MessageContentType.STICKER -> FlareStickerContent(
            url = imagePath(content).orEmpty(),
            packageId = content.str("packageId", "package_id"),
            stickerId = content.str("stickerId", "id"),
        )
        MessageContentType.EMOJI -> FlareEmojiContent(content.str("emoji", "key") ?: fallback)
        MessageContentType.CARD ->
            FlareCardContent(
                content.str("title", "name") ?: fallback,
                content.str("subtitle", "description"),
                content.str("thumbnailUrl", "imageUrl"),
            )
        MessageContentType.LINK_CARD -> FlareLinkCardContent(
            url = content.str("url").orEmpty(), title = content.str("title") ?: fallback,
            description = content.str("description", "summary"), imageUrl = content.str("thumbnailUrl", "imageUrl"))
        MessageContentType.VOTE -> FlarePollContent(
            id = content.str("voteId").orEmpty(), title = content.str("headline", "title") ?: fallback,
            options = (content.data["options"] as? List<*>)?.filterIsInstance<String>().orEmpty())
        MessageContentType.TASK -> FlareTaskContent(
            id = content.str("taskId").orEmpty(), title = content.str("title") ?: fallback,
            detail = content.str("detail", "description").orEmpty(),
            done = (content.data["metadata"] as? Map<*, *>)?.get("done").toString() == "true")
        MessageContentType.SCHEDULE -> FlareCalendarContent(
            id = content.str("scheduleId").orEmpty(), title = content.str("title") ?: fallback,
            timeRange = content.str("timeRange").orEmpty())
        MessageContentType.MINI_PROGRAM -> FlareMiniAppContent(
            appId = content.str("appId").orEmpty(), title = content.str("title") ?: fallback,
            pagePath = content.str("pagePath").orEmpty(), thumbnailUrl = content.str("thumbnailUrl"),
            description = content.str("description"))
        MessageContentType.ANNOUNCEMENT -> FlareAnnouncementContent(
            id = content.str("announcementId").orEmpty(), title = content.str("headline", "title") ?: fallback,
            body = content.str("body").orEmpty())
        MessageContentType.SYSTEM, MessageContentType.NOTIFICATION ->
            FlareNotificationContent(fallback)
        MessageContentType.CUSTOM, MessageContentType.PLACEHOLDER ->
            FlareGenericContent(content.contentType.name.lowercase(), fallback)
    }
}

/** 长按动作面板：kit 的 [MessageActionSheet]。哪些动作可用由**核心**判定（`domain::message_actions`），
 *  标准动作的文案、图标和分组归 kit；这里只问核心、隐藏本 app 没实现的动作、分发用户选中的动作。
 *
 *  曾经是一个无条件全显的静态列表：Pin 与 Unpin 同时出现、别人的消息上也显示
 *  Recall、图片上也显示 Edit —— 点了必然失败。后来又用 Material 的下拉菜单自己画了一份，
 *  和另外三端的 kit 面板长得不一样。 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun MessageActionMenu(
    message: AppMessage,
    expanded: Boolean,
    clipboard: androidx.compose.ui.platform.ClipboardManager,
    vm: MessagingViewModel,
    onSave: () -> Unit,
    onExpandedChange: (Boolean) -> Unit,
) {
    var availability by remember(message.appStableId) { mutableStateOf<FlareMessageActionAvailability?>(null) }
    var editing by remember { mutableStateOf(false) }

    // 面板打开时才问核心：长按是低频动作，一次 FFI 往返远在 100ms 交互预算之内。
    // 答案回来之前不弹面板（否则先弹出一个空弹层）；核心说此刻一个动作都没有，就不打开。
    LaunchedEffect(expanded, message.appStableId) {
        if (!expanded) return@LaunchedEffect
        availability = null
        val answer = vm.actionAvailability(message)
        availability = answer
        if (answer == FlareMessageActionAvailability()) onExpandedChange(false)
    }

    if (editing) {
        MessageEditDialog(
            initial = message.previewText,
            onDismiss = { editing = false },
            onConfirm = { text ->
                editing = false
                vm.messageAction("edit", message, text = text)
            },
        )
    }

    val allowed = availability
    if (!expanded || allowed == null) return
    ModalBottomSheet(
        onDismissRequest = { onExpandedChange(false) },
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = flareColors().bgSecondary,
    ) {
        MessageActionSheet(
            availability = allowed,
            // 这个 app 没有多选，也没有消息预览。
            hiddenActions = setOf("multiSelect", "preview"),
            actions = listOfNotNull(
                FlareMessageMenuEntry("editRich", stringResource(R.string.msg_action_edit_rich), "rich-text")
                    .takeIf { allowed.canEdit },
                FlareMessageMenuEntry(
                    "deleteEveryone", stringResource(R.string.msg_action_delete_everyone),
                    "delete", FlareMessageMenuGroup.Destructive,
                ).takeIf { allowed.canDelete && allowed.canRecall },
            ),
            onAction = { id ->
                onExpandedChange(false)
                when (id) {
                    "resend" -> vm.retry(message)
                    "reply" -> vm.replyTo(message)
                    "forward" -> vm.buildAndSend(MessageBuildOp.CreateForward)
                    "copy" -> clipboard.setText(AnnotatedString(message.previewText))
                    "edit" -> { editing = true }
                    "save" -> onSave()
                    "delete" -> vm.messageAction("deleteSelf", message)
                    // recall / pin / pinSelf / unpin / mark / editRich / deleteEveryone 都是同名的消息操作
                    else -> vm.messageAction(id, message)
                }
            },
            onReact = { emoji ->
                onExpandedChange(false)
                vm.messageAction("react", message, emoji)
            },
        )
        // 面板延伸到手势条下面，最后一组要让开它。
        Spacer(Modifier.navigationBarsPadding())
    }
}

/** 编辑消息：曾经点一下"编辑"就把原文替换成写死的 "Edited from Android example"，
 *  没有任何输入入口 —— 用户的内容就这么没了。 */
@Composable
private fun MessageEditDialog(initial: String, onDismiss: () -> Unit, onConfirm: (String) -> Unit) {
    var text by remember { mutableStateOf(initial) }
    androidx.compose.material3.AlertDialog(
        onDismissRequest = onDismiss,
        title = { Text(stringResource(R.string.msg_edit_title)) },
        text = {
            androidx.compose.material3.OutlinedTextField(
                value = text,
                onValueChange = { text = it },
                label = { Text(stringResource(R.string.msg_edit_hint)) },
                singleLine = false,
            )
        },
        confirmButton = {
            androidx.compose.material3.TextButton(
                onClick = { if (text.isNotBlank()) onConfirm(text) },
            ) { Text(stringResource(R.string.action_confirm)) }
        },
        dismissButton = {
            androidx.compose.material3.TextButton(onClick = onDismiss) {
                Text(stringResource(R.string.action_cancel))
            }
        },
    )
}


/** 表情回应条：每个 emoji + 计数为可点 chip，点己有=取消、点他人=追加。 */
@Composable
private fun ReactionStrip(message: AppMessage, me: String?, vm: MessagingViewModel) {
    val reactions = message.core.reactions
    if (reactions.isEmpty()) return
    val colors = FlareTheme.colors
    val tk = FlareTheme.tokens
    Row(
        Modifier.padding(top = 2.dp).horizontalScroll(rememberScrollState()),
        horizontalArrangement = Arrangement.spacedBy(tk.xs),
    ) {
        reactions.forEach { r ->
            val mine = me != null && me in r.userIds
            Row(
                Modifier.clip(tk.pill)
                    .background(if (mine) colors.brandSoft else colors.surfaceAlt)
                    .clickable { vm.messageAction(if (mine) "unreact" else "react", message, r.emoji) }
                    .padding(horizontal = tk.sm, vertical = 2.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(r.emoji, style = MaterialTheme.typography.bodySmall)
                if (r.count > 0) {
                    Spacer(Modifier.width(2.dp))
                    Text("${r.count}", style = MaterialTheme.typography.bodySmall, color = if (mine) colors.brand else colors.textSecondary)
                }
            }
        }
    }
}

/** 送达状态指示：贴在气泡右下角，与 iOS DeliveryStatusGlyph 同视觉。
 *
 *  全部用图标而不是文字：文字（"发送中…" / "发送失败 · 点击重试"）在气泡里放不下，
 *  而且会把气泡撑成一个奇怪的宽度。失败图标可点重发。 */
@Composable
private fun MessageDeliveryStatus(
    state: MessageDeliveryState,
    onBubble: Boolean,
    onRetry: () -> Unit,
) {
    val colors = FlareTheme.colors
    val glyph = 14.dp
    val onBubbleTint = colors.outgoingText.copy(alpha = 0.9f)
    // contentDescription 走资源；semantics {} 是非 @Composable 作用域，须先在此提前取值。
    val descSending = stringResource(R.string.msg_status_sending)
    val descFailed = stringResource(R.string.msg_status_failed_retry)
    val descRead = stringResource(R.string.msg_status_read)
    val descDelivered = stringResource(R.string.msg_status_delivered)
    when (state) {
        MessageDeliveryState.NONE -> Unit
        MessageDeliveryState.SENDING -> CircularProgressIndicator(
            strokeWidth = 1.5.dp,
            color = if (onBubble) onBubbleTint else colors.textTertiary,
            modifier = Modifier.size(glyph).semantics { contentDescription = descSending },
        )
        MessageDeliveryState.FAILED -> Icon(
            Icons.Default.Warning,
            contentDescription = descFailed,
            tint = colors.danger,
            modifier = Modifier.size(glyph).clickable { onRetry() },
        )
        MessageDeliveryState.DELIVERED, MessageDeliveryState.READ -> Row(
            horizontalArrangement = Arrangement.spacedBy((-5).dp),
            modifier = Modifier.semantics {
                contentDescription = if (state == MessageDeliveryState.READ) descRead else descDelivered
            },
        ) {
            val tint = when {
                state == MessageDeliveryState.READ && onBubble -> colors.outgoingText
                state == MessageDeliveryState.READ -> colors.brand
                onBubble -> onBubbleTint.copy(alpha = 0.65f)
                else -> colors.textTertiary
            }
            Icon(Icons.Default.Check, contentDescription = null, tint = tint, modifier = Modifier.size(glyph))
            if (state == MessageDeliveryState.READ) {
                Icon(Icons.Default.Check, contentDescription = null, tint = tint, modifier = Modifier.size(glyph))
            }
        }
    }
}
