package im.flare.core.demo

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.flare.im.FlareCoreSdk
import com.flare.im.api.FlareImClient
import com.flare.im.model.command.message.SendMessageRequest
import com.flare.im.model.command.message.build.BuildTextMessageRequest
import com.flare.im.model.command.message.build.BuildFileMessageRequest
import com.flare.im.model.entity.Conversation
import com.flare.im.model.entity.CoreEndpoints
import com.flare.im.model.entity.Message
import com.flare.im.model.query.ListMessagesRequest
import com.flare.im.ui.Button
import com.flare.im.ui.FlareThemeProvider
import com.flare.im.ui.Input
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File

class MainActivity : ComponentActivity() {
    private val sdk by lazy { FlareCoreSdk.createClient(applicationContext) }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        setContent {
            FlareThemeProvider {
                Surface { CoreWorkbench(sdk, "file://${filesDir.absolutePath}") }
            }
        }
    }
}

@Composable
private fun CoreWorkbench(sdk: FlareImClient, dataUrl: String) {
    var baseUrl by remember { mutableStateOf("") }
    var websocketUrl by remember { mutableStateOf("") }
    var quicUrl by remember { mutableStateOf("") }
    var mediaUrl by remember { mutableStateOf("") }
    var tenant by remember { mutableStateOf("") }
    var user by remember { mutableStateOf("") }
    var token by remember { mutableStateOf("") }
    var peer by remember { mutableStateOf("") }
    var draft by remember { mutableStateOf("") }
    var conversations by remember { mutableStateOf(listOf<Conversation>()) }
    var selected by remember { mutableStateOf<Conversation?>(null) }
    var messages by remember { mutableStateOf(listOf<Message>()) }
    var online by remember { mutableStateOf(false) }
    var busy by remember { mutableStateOf(false) }
    var status by remember { mutableStateOf("") }
    val scope = rememberCoroutineScope()
    val context = LocalContext.current
    var refreshRequest by remember { mutableIntStateOf(0) }

    suspend fun refresh() {
        val request = ++refreshRequest
        val active = selected
        val rows = sdk.conversations.listConversations().conversations
        val history = active?.let { conversation ->
            sdk.messages.listMessages(ListMessagesRequest(conversation.conversationId, limit = 50)).messages
                .sortedBy { it.conversationSeq }
        }.orEmpty()
        if (online && selected == active && request == refreshRequest) {
            conversations = rows
            messages = history
        }
    }

    fun action(block: suspend () -> Unit) {
        if (busy) return
        busy = true
        scope.launch {
            try {
                status = ""
                block()
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (error: Exception) {
                status = error.message ?: "SDK operation failed"
            } finally {
                busy = false
            }
        }
    }

    fun refreshOnEvent() {
        scope.launch {
            try {
                if (online) refresh()
            } catch (cancelled: CancellationException) {
                throw cancelled
            } catch (error: Exception) {
                if (online) status = error.message ?: "Refresh failed"
            }
        }
    }

    LaunchedEffect(online, selected?.conversationId) {
        if (!online) return@LaunchedEffect
        val received = sdk.events.onMessageReceived { refreshOnEvent() }
        val batch = sdk.events.onMessageReceivedBatch { refreshOnEvent() }
        try {
            refreshOnEvent()
            kotlinx.coroutines.awaitCancellation()
        } finally {
            sdk.events.removeEventListener(received)
            sdk.events.removeEventListener(batch)
        }
    }

    fun endpoints() = CoreEndpoints(baseUrl = baseUrl.trim(), websocketUrl = websocketUrl.trim(),
        quicUrl = quicUrl.trim().ifBlank { null }, mediaBaseUrl = mediaUrl.trim().ifBlank { null })

    val pickFile = rememberLauncherForActivityResult(ActivityResultContracts.GetContent()) { uri ->
        val conversation = selected
        if (uri != null && conversation != null) action {
            val temp = withContext(Dispatchers.IO) {
                File.createTempFile("demo-attachment-", ".bin", context.cacheDir).also { target ->
                    try {
                        val source = checkNotNull(context.contentResolver.openInputStream(uri))
                        source.use { input -> target.outputStream().use { output -> input.copyTo(output) } }
                    } catch (error: Exception) {
                        target.delete()
                        throw error
                    }
                }
            }
            try {
                val upload = sdk.media.uploadFile(mapOf("absolutePath" to temp.absolutePath))
                val fileId = checkNotNull(upload["fileId"] as? String) { "Media service returned no file ID" }
                val message = sdk.messageBuilder.buildFile(BuildFileMessageRequest(conversation.conversationId, fileId))
                sdk.messages.sendMessage(SendMessageRequest(message))
                refresh()
            } finally {
                temp.delete()
            }
        }
    }

    LazyColumn(Modifier.fillMaxSize().padding(16.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        item {
            Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Text("Flare Core", style = MaterialTheme.typography.headlineMedium)
                Input(baseUrl, { baseUrl = it }, placeholder = "Core HTTP base URL")
                Input(websocketUrl, { websocketUrl = it }, placeholder = "WebSocket URL")
                Input(quicUrl, { quicUrl = it }, placeholder = "QUIC URL (optional)")
                Input(mediaUrl, { mediaUrl = it }, placeholder = "Media base URL (optional)")
                if (!online) {
                    Input(tenant, { tenant = it }, placeholder = "Tenant ID")
                    Input(user, { user = it }, placeholder = "User ID")
                    Input(token, { token = it }, placeholder = "Access token", secure = true)
                    Button("Sign in", loading = busy, onClick = { action {
                        val endpoint = endpoints()
                        val development = BuildConfig.DEBUG && endpoint.baseUrl.startsWith("http://")
                        sdk.init(mapOf("environment" to if (development) "development" else "production", "sdkConfig" to mapOf(
                            "dataUrl" to dataUrl, "tenantId" to tenant.trim(),
                            "endpoints" to buildMap {
                                put("baseUrl", endpoint.baseUrl); put("websocketUrl", endpoint.websocketUrl)
                                endpoint.quicUrl?.let { put("quicUrl", it) }
                                endpoint.mediaBaseUrl?.let { put("mediaBaseUrl", it) }
                            },
                            "auth" to if (development) emptyMap<String, Any>() else null,
                        )))
                        sdk.login(buildMap { put("userId", user.trim()); if (token.isNotBlank()) put("token", token.trim()) })
                        token = ""
                        online = true
                    } })
                } else {
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Button("Apply endpoints", disabled = busy, onClick = { action {
                            status = "Endpoint revision ${sdk.connection.replaceEndpoints(endpoints()).revision}"
                        } })
                        Button("Sign out", disabled = busy, onClick = { action {
                            sdk.logout(); online = false; selected = null; messages = emptyList(); conversations = emptyList()
                        } })
                    }
                    Input(peer, { peer = it }, placeholder = "Peer user ID")
                    Button("Open chat", disabled = busy || peer.isBlank(), onClick = { action {
                        selected = sdk.conversations.getOneConversation(mapOf("sourceId" to peer.trim(), "conversationType" to "single"))
                        refresh()
                    } })
                }
                if (status.isNotEmpty()) Text(status)
            }
        }
        if (online) items(conversations, key = { it.conversationId }) { conversation ->
            Button(conversation.channelId, disabled = busy, onClick = { selected = conversation; messages = emptyList() })
        }
        items(messages) { message ->
            Text("${message.senderId}: ${message.content?.data?.get("text") ?: message.content?.contentType.orEmptyLabel()}")
        }
        selected?.let { conversation -> item {
            Input(draft, { draft = it }, placeholder = "Message", multiline = true)
            Button("Attach file", disabled = busy, onClick = { pickFile.launch("*/*") })
            Button("Send", disabled = busy || draft.isBlank(), onClick = { action {
                val message = sdk.messageBuilder.buildText(BuildTextMessageRequest(conversation.conversationId, draft))
                sdk.messages.sendMessage(SendMessageRequest(message))
                draft = ""
                refresh()
            } })
        } }
    }
}

private fun Any?.orEmptyLabel(): String = this?.toString() ?: "Message"
