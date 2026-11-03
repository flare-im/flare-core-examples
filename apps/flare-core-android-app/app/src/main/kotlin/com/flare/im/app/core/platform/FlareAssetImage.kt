package com.flare.im.app.core.platform

import android.graphics.BitmapFactory
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.Dp

/**
 * 平台桥：从 `assets/` 解码 webp（emoji/sticker）为 Compose 图像。
 * 唯一接触 Android 图形 API 的地方；视图层只调它。
 * 解码结果按 assetPath 记忆缓存，避免每帧重解码（smoothness）。
 */
@Composable
fun FlareAssetImage(
    assetPath: String,
    contentDescription: String?,
    size: Dp,
    fallback: @Composable () -> Unit = {},
) {
    val context = LocalContext.current
    val bitmap: ImageBitmap? = remember(assetPath) {
        runCatching {
            context.assets.open(assetPath).use { BitmapFactory.decodeStream(it)?.asImageBitmap() }
        }.getOrNull()
    }
    if (bitmap != null) {
        Image(bitmap = bitmap, contentDescription = contentDescription, modifier = Modifier.size(size), contentScale = ContentScale.Fit)
    } else {
        fallback()
    }
}
