package com.flare.im.app.core.platform

import android.content.Context
import android.media.MediaRecorder
import android.os.Build
import java.io.File

/**
 * 平台桥：语音录制（MediaRecorder → m4a/AAC）。唯一接触 Android 录音 API 的地方
 *。
 */
class AudioRecorder(private val context: Context) {
    private var recorder: MediaRecorder? = null
    private var outputPath: String? = null
    private var startMs: Long = 0L

    val isRecording: Boolean get() = recorder != null

    /** 开始录音；失败返回 false。 */
    fun start(): Boolean {
        if (recorder != null) return false
        val dir = File(context.cacheDir, "FlareAudio").apply { mkdirs() }
        val file = File(dir, "audio-${System.currentTimeMillis()}.m4a")
        return runCatching {
            @Suppress("DEPRECATION")
            val r = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) MediaRecorder(context) else MediaRecorder()
            r.setAudioSource(MediaRecorder.AudioSource.MIC)
            r.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
            r.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
            r.setAudioEncodingBitRate(96_000)
            r.setAudioSamplingRate(44_100)
            r.setOutputFile(file.absolutePath)
            r.prepare()
            r.start()
            recorder = r
            outputPath = file.absolutePath
            startMs = System.currentTimeMillis()
            true
        }.getOrElse {
            runCatching { recorder?.release() }
            recorder = null
            false
        }
    }

    /** 停止并返回 (路径, 时长ms)；失败返回 null。 */
    fun stop(): Pair<String, Int>? {
        val r = recorder ?: return null
        val path = outputPath
        recorder = null
        return try {
            r.stop()
            r.release()
            val duration = (System.currentTimeMillis() - startMs).toInt().coerceAtLeast(1)
            path?.let { it to duration }
        } catch (error: Throwable) {
            runCatching { r.release() }
            path?.let { runCatching { File(it).delete() } }
            null
        }
    }

    fun cancel() {
        val r = recorder ?: return
        recorder = null
        runCatching { r.stop() }
        runCatching { r.release() }
        outputPath?.let { runCatching { File(it).delete() } }
    }
}
