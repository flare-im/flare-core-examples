package com.flare.im.app.features.auth

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.outlined.Login
import androidx.compose.material.icons.outlined.ErrorOutline
import androidx.compose.material.icons.outlined.ExpandMore
import androidx.compose.material.icons.outlined.Storage
import androidx.compose.material3.CircularProgressIndicator
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.RoundRect
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.asAndroidPath
import androidx.compose.ui.platform.LocalConfiguration
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlin.math.PI
import kotlin.math.tan
import com.flare.im.app.R
import com.flare.im.app.core.FlareAppStore
import com.flare.im.app.core.domain.LoginTransportMode
import com.flare.im.ui.FlareBrandLogo
import com.flare.im.ui.FlareBrandLogoVariant
import com.flare.im.ui.FlareSizes
import com.flare.im.ui.FormField
import com.flare.im.ui.Input
import com.flare.im.ui.SegmentedControl
import com.flare.im.ui.flareColors

// 登录屏:统一登录规格 v2。视觉取自 kit 设计 token,**表单用 kit 组件搭建**
// (FormField + Input + SegmentedControl,来自 com.flare.im.ui)。
// 字段:用户 ID + 协议三选(WebSocket/QUIC/竞速) + WebSocket URL + Gateway URL + QUIC URL。
// 不再有 access token 输入(SDK 托管:核心向 Gateway 签发并自动刷新)。
// 状态/绑定沿用 AuthViewModel(LoginDraft 已含独立 wsUrl/quicUrl/httpUrl)。

/** 登录页专用布局常量(不属于通用 token 标尺的展示尺寸;四端保持同值)。 */
private object LoginSpec {
    val logoSize = 64.dp
    val logoIcon = 33.dp
    val buttonHeight = 48.dp
    val gridStep = 40.dp
    val formMaxWidth = 430.dp
    val titleSize = 24.sp
    val welcomeSize = 22.sp
}

/** 协议三选顺序(与 SegmentedControl 索引对应)。 */
private val transportOrder = listOf(
    LoginTransportMode.WebSocket,
    LoginTransportMode.Quic,
    LoginTransportMode.Race,
)

@Composable
fun LoginScreen(store: FlareAppStore) {
    val auth = store.authViewModel
    val draft by auth.loginDraft.collectAsState()
    val validation by auth.validationMessage.collectAsState()
    val error by auth.lastError.collectAsState()
    val busy by auth.isBusy.collectAsState()
    val kc = flareColors()

    // 紫色品牌头铺到状态栏下：状态栏图标改浅色(白)，离开登录页恢复。
    val view = LocalView.current
    DisposableEffect(Unit) {
        val window = (view.context as? android.app.Activity)?.window
        val controller = window?.let { androidx.core.view.WindowCompat.getInsetsController(it, view) }
        val previous = controller?.isAppearanceLightStatusBars
        controller?.isAppearanceLightStatusBars = false
        onDispose { if (previous != null) controller.isAppearanceLightStatusBars = previous }
    }

    Box(Modifier.fillMaxSize().background(kc.bgPrimary)) {
        Column(Modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
            BrandHeader()
            Column(
                Modifier.widthIn(max = LoginSpec.formMaxWidth).align(Alignment.CenterHorizontally)
                    .fillMaxWidth().navigationBarsPadding()
                    .padding(horizontal = FlareSizes.spacingXl).padding(top = 30.dp, bottom = 42.dp),
                verticalArrangement = Arrangement.spacedBy(FlareSizes.spacingLg),
            ) {
                LoginForm(store, draft, validation, error, busy)
            }
        }
        if (busy) {
            Box(Modifier.fillMaxSize().background(Color.Black.copy(alpha = 0.06f)), Alignment.Center) {
                CircularProgressIndicator(color = kc.primary)
            }
        }
    }
}

/** 渐变品牌头：对角品牌渐变 + 细网格 + F logo + 品牌名/标语。 */
@Composable
private fun BrandHeader() {
    val kc = flareColors()
    val screenH = LocalConfiguration.current.screenHeightDp
    val headerH = (screenH * 0.32f).coerceIn(252f, 320f).dp
    Box(
        Modifier.fillMaxWidth().heightIn(min = headerH)
            .background(Brush.linearGradient(listOf(kc.primaryActive, kc.primary, kc.info), start = Offset.Zero, end = Offset.Infinite)),
        Alignment.Center,
    ) {
        Canvas(Modifier.matchParentSize()) {
            val step = LoginSpec.gridStep.toPx()
            val line = Color.White.copy(alpha = 0.11f)
            var x = 0f
            while (x <= size.width) { drawLine(line, Offset(x, 0f), Offset(x, size.height), 1f); x += step }
            var y = 0f
            while (y <= size.height) { drawLine(line, Offset(0f, y), Offset(size.width, y), 1f); y += step }
        }
        Column(
            Modifier.windowInsetsPadding(WindowInsets.statusBars).padding(vertical = FlareSizes.spacing2xl),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(FlareSizes.spacingLg),
        ) {
            FlareBrandLogo(size = LoginSpec.logoSize, variant = FlareBrandLogoVariant.Plate)
            Column(horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(FlareSizes.spacingXs)) {
                Text(stringResource(R.string.brand_name), color = Color.White, fontSize = LoginSpec.titleSize, fontWeight = FontWeight.Black)
                Text(stringResource(R.string.brand_tagline), color = Color.White.copy(alpha = 0.88f), fontSize = 14.sp)
            }
        }
    }
}

@Composable
private fun LoginForm(
    store: FlareAppStore,
    draft: com.flare.im.app.core.domain.LoginDraft,
    validation: String?,
    error: String?,
    busy: Boolean,
) {
    val kc = flareColors()
    val auth = store.authViewModel

    Text(stringResource(R.string.auth_welcome), fontSize = LoginSpec.welcomeSize, fontWeight = FontWeight.Bold, color = kc.textPrimary)
    Text(stringResource(R.string.auth_enter_id), fontSize = 14.sp, color = kc.textSecondary)

    FormField(label = stringResource(R.string.auth_user_id), hint = stringResource(R.string.auth_id_hint)) {
        Input(
            value = draft.userId,
            onValueChange = { auth.updateDraft { d -> d.copy(userId = it) }; auth.clearValidation() },
            placeholder = stringResource(R.string.auth_user_id_placeholder),
        )
    }

    validation?.let {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(FlareSizes.spacingSm)) {
            Icon(Icons.Outlined.ErrorOutline, null, tint = kc.error, modifier = Modifier.size(14.dp))
            Text(it, fontSize = 12.sp, color = kc.error)
        }
    }

    val protocolIndex = transportOrder.indexOf(draft.transportMode).coerceAtLeast(0)
    val transportLabels = listOf("WebSocket", "QUIC", stringResource(R.string.auth_transport_race))
    FormField(label = stringResource(R.string.auth_protocol)) {
        SegmentedControl(
            options = transportLabels,
            selectedIndex = protocolIndex,
            onSelect = { auth.updateDraft { d -> d.copy(transportMode = transportOrder[it]) } },
        )
    }

    ServerAddressSection(store, draft)

    error?.let { raw ->
        val it = if (LoginErrorText.isTokenRejected(raw)) stringResource(R.string.auth_token_rejected) else raw
        LoginErrorBanner(it)
    }

    GradientSignInButton(busy = busy, enabled = !busy) { auth.submit() }

    Text(
        stringResource(R.string.auth_footer),
        fontSize = 12.sp,
        color = kc.textTertiary,
        modifier = Modifier.fillMaxWidth(),
        textAlign = TextAlign.Center,
    )
}

/** 服务器地址区：默认收起，点击展开 WebSocket / Gateway / QUIC URL。 */
@Composable
private fun ServerAddressSection(store: FlareAppStore, draft: com.flare.im.app.core.domain.LoginDraft) {
    val kc = flareColors()
    val auth = store.authViewModel
    var open by remember { mutableStateOf(false) }
    Column(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(FlareSizes.radiusLg))
            .background(kc.bgSecondary)
            .border(1.dp, kc.borderPrimary, RoundedCornerShape(FlareSizes.radiusLg))
            .padding(FlareSizes.spacingLg),
        verticalArrangement = Arrangement.spacedBy(FlareSizes.spacingLg),
    ) {
        Row(
            Modifier.fillMaxWidth().clickable { open = !open },
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(FlareSizes.spacingSm),
        ) {
            Icon(Icons.Outlined.Storage, null, tint = kc.textSecondary, modifier = Modifier.size(18.dp))
            Text(stringResource(R.string.auth_server_address), fontSize = 14.sp, fontWeight = FontWeight.Medium, color = kc.textPrimary)
            Spacer(Modifier.weight(1f))
            Icon(Icons.Outlined.ExpandMore, null, tint = kc.textTertiary, modifier = Modifier.size(20.dp).rotate(if (open) 180f else 0f))
        }
        AnimatedVisibility(open) {
            Column(verticalArrangement = Arrangement.spacedBy(FlareSizes.spacingLg)) {
                FormField(label = stringResource(R.string.auth_ws_url)) {
                    Input(value = draft.wsUrl, onValueChange = { auth.updateDraft { d -> d.copy(wsUrl = it) } }, placeholder = "ws://host:60051/ws")
                }
                FormField(label = stringResource(R.string.auth_gateway_url), hint = stringResource(R.string.auth_gateway_hint)) {
                    Input(value = draft.httpUrl, onValueChange = { auth.updateDraft { d -> d.copy(httpUrl = it) } }, placeholder = "http://host:50050")
                }
                FormField(label = stringResource(R.string.auth_quic_url)) {
                    Input(value = draft.quicUrl, onValueChange = { auth.updateDraft { d -> d.copy(quicUrl = it) } }, placeholder = "quic://host:60052")
                }
            }
        }
    }
}

/** 渐变登录按钮（48 高，radiusLg 圆角；禁用降透明度）。 */
@Composable
private fun GradientSignInButton(busy: Boolean, enabled: Boolean, onClick: () -> Unit) {
    val kc = flareColors()
    Box(
        Modifier.fillMaxWidth().height(LoginSpec.buttonHeight).clip(RoundedCornerShape(FlareSizes.radiusLg))
            .background(Brush.horizontalGradient(listOf(kc.primary, kc.info)))
            .then(if (enabled) Modifier.clickable(onClick = onClick) else Modifier)
            .alpha(if (enabled) 1f else 0.55f),
        Alignment.Center,
    ) {
        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.spacedBy(FlareSizes.spacingSm)) {
            Icon(Icons.AutoMirrored.Outlined.Login, null, tint = Color.White, modifier = Modifier.size(18.dp))
            Text(
                stringResource(if (busy) R.string.auth_signing_in else R.string.auth_sign_in),
                color = Color.White, fontSize = 16.sp, fontWeight = FontWeight.Bold,
            )
        }
    }
}

/** 登录失败横幅：警告图标 + 标题 + 详情，error 淡底圆角。 */
@Composable
private fun LoginErrorBanner(message: String) {
    val kc = flareColors()
    Row(
        Modifier.fillMaxWidth().clip(RoundedCornerShape(FlareSizes.radiusLg)).background(kc.error.copy(alpha = 0.11f)).padding(FlareSizes.spacingMd),
        horizontalArrangement = Arrangement.spacedBy(FlareSizes.spacingMd),
    ) {
        Icon(Icons.Outlined.ErrorOutline, null, tint = kc.error, modifier = Modifier.size(18.dp).padding(top = 1.dp))
        Column(verticalArrangement = Arrangement.spacedBy(FlareSizes.spacingXs)) {
            Text(stringResource(R.string.auth_error_title), fontSize = 13.sp, fontWeight = FontWeight.Bold, color = kc.textPrimary)
            Text(message, fontSize = 12.sp, color = kc.textSecondary, maxLines = 3)
        }
    }
}
