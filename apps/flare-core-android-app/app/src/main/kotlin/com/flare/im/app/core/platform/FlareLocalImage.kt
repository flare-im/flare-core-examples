package com.flare.im.app.core.platform

import android.graphics.BitmapFactory
import android.net.Uri
import androidx.compose.foundation.Image
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.ImageBitmap
import androidx.compose.ui.graphics.asAndroidBitmap
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import java.io.File
import kotlin.math.max

/**
 * 平台桥：异步把本地图片（content:// URI / file:// / 纯文件路径）解码为 Compose 图像。
 * 在 IO 线程解码 + 按 maxPx 降采样（避免大图 OOM 与主线程 jank，smoothness 预算）。
 * 加载本地图片资源。失败回退 fallback。
 */
@Composable
fun FlareLocalImage(
    path: String,
    contentDescription: String?,
    modifier: Modifier = Modifier,
    maxPx: Int = 1024,
    contentScale: ContentScale = ContentScale.Crop,
    fallback: @Composable () -> Unit = {},
) {
    val context = LocalContext.current
    val cacheKey = "$path#$maxPx"
    var bitmap by remember(cacheKey) { mutableStateOf(ImageMemoryCache.get(cacheKey)) }
    var failed by remember(cacheKey) { mutableStateOf(false) }

    LaunchedEffect(cacheKey) {
        if (bitmap != null) return@LaunchedEffect // 命中内存缓存，免重解码/重下载
        val decoded = withContext(Dispatchers.IO) {
            runCatching {
                // 一次性读到内存：http(s) 下载 / content:// / file:// / 纯路径。
                val bytes = when {
                    path.startsWith("http://") || path.startsWith("https://") ->
                        (java.net.URL(path).openConnection() as java.net.HttpURLConnection)
                            .apply { connectTimeout = 8000; readTimeout = 8000 }
                            .inputStream.use { it.readBytes() }
                    path.startsWith("content://") || path.startsWith("file://") ->
                        context.contentResolver.openInputStream(Uri.parse(path))?.use { it.readBytes() }
                    else -> File(path).takeIf { it.exists() }?.readBytes()
                } ?: return@runCatching null
                // 先读边界算降采样，再按采样率解码（避免大图 OOM）。
                val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
                BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
                val longest = max(bounds.outWidth, bounds.outHeight).coerceAtLeast(1)
                var sample = 1
                while (longest / sample > maxPx) sample *= 2
                val opts = BitmapFactory.Options().apply { inSampleSize = sample }
                BitmapFactory.decodeByteArray(bytes, 0, bytes.size, opts)?.asImageBitmap()
            }.getOrNull()
        }
        if (decoded != null) {
            ImageMemoryCache.put(cacheKey, decoded)
            bitmap = decoded
        } else {
            failed = true
        }
    }

    val bmp = bitmap
    when {
        bmp != null -> Image(bitmap = bmp, contentDescription = contentDescription, modifier = modifier, contentScale = contentScale)
        failed -> fallback()
        else -> fallback() // 解码中也先占位
    }
}

/** 进程级内存解码缓存（LRU，按位图字节计量，约 1/8 堆）：磁盘缓存之上再加一层内存层，
 *  滚动/重组时直接复用已解码位图，避免重解码/重下载（smoothness）。 */
private object ImageMemoryCache {
    private val cache = object : android.util.LruCache<String, ImageBitmap>(
        (Runtime.getRuntime().maxMemory() / 8).coerceAtMost(Int.MAX_VALUE.toLong()).toInt(),
    ) {
        override fun sizeOf(key: String, value: ImageBitmap): Int =
            runCatching { value.asAndroidBitmap().allocationByteCount }.getOrDefault(1).coerceAtLeast(1)
    }

    fun get(key: String): ImageBitmap? = cache.get(key)
    fun put(key: String, value: ImageBitmap) { cache.put(key, value) }
}
