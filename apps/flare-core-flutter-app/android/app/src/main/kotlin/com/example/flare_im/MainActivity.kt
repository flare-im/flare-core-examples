package com.example.flare_im

import android.media.RingtoneManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // 应用内横幅的提示音（`flare.im/sound`）：系统的通知提示音（用户在系统设置里选的那一个），跟着通知音量与静音。
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "flare.im/sound").setMethodCallHandler { call, result ->
            when (call.method) {
                "message" -> {
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)?.let { sound ->
                        runCatching { RingtoneManager.getRingtone(applicationContext, sound)?.play() }
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
