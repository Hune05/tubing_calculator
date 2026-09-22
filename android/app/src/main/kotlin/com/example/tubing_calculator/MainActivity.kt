package com.example.tubing_calculator

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    // 현장 탭 "한 단계씩" 화면이 떠 있을 때만 볼륨 단추를 가로채 앱에 넘긴다.
    // 그 밖에는 원래대로 음량을 조절한다.
    private var captureVolumeKeys = false
    private var volumeChannel: MethodChannel? = null

    // 카톡 등에서 "공유"로 받은 도면(사진·PDF). 앱 안 폴더로 복사해 두고, 앱이 "take"로 가져간다.
    private var drawingChannel: MethodChannel? = null
    private var pendingDrawing: Map<String, String>? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        volumeChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "field/volume_keys"
        ).also { ch ->
            ch.setMethodCallHandler { call, result ->
                when (call.method) {
                    "setCapture" -> {
                        captureVolumeKeys = call.arguments as? Boolean ?: false
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
        drawingChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "field/shared_drawing"
        ).also { ch ->
            ch.setMethodCallHandler { call, result ->
                when (call.method) {
                    "take" -> {
                        result.success(pendingDrawing)
                        pendingDrawing = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
        // 앱이 꺼져 있을 때 공유로 열린 경우.
        readSharedDrawing(intent)?.let { pendingDrawing = it }
    }

    // 앱이 떠 있을 때 공유로 다시 들어온 경우.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        val d = readSharedDrawing(intent) ?: return
        pendingDrawing = d
        drawingChannel?.invokeMethod("received", null)
    }

    private fun readSharedDrawing(intent: Intent?): Map<String, String>? {
        if (intent?.action != Intent.ACTION_SEND) return null
        val uri: Uri = (if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(Intent.EXTRA_STREAM) as? Uri
        }) ?: return null
        // 화면을 다시 만들 때 같은 공유를 두 번 받지 않게 한 번 읽으면 지운다.
        intent.action = null
        val mime = intent.type ?: contentResolver.getType(uri) ?: ""
        val ext = when {
            mime == "application/pdf" -> "pdf"
            mime.contains("png") -> "png"
            else -> "jpg"
        }
        return try {
            val dir = File(filesDir, "shared_drawings").apply { mkdirs() }
            val out = File(dir, "drawing_${System.currentTimeMillis()}.$ext")
            val input = contentResolver.openInputStream(uri) ?: return null
            input.use { src -> out.outputStream().use { src.copyTo(it) } }
            mapOf("path" to out.absolutePath, "mime" to mime)
        } catch (e: Exception) {
            null
        }
    }

    override fun dispatchKeyEvent(event: KeyEvent): Boolean {
        if (captureVolumeKeys &&
            (event.keyCode == KeyEvent.KEYCODE_VOLUME_UP ||
                event.keyCode == KeyEvent.KEYCODE_VOLUME_DOWN)
        ) {
            if (event.action == KeyEvent.ACTION_DOWN && event.repeatCount == 0) {
                val dir = if (event.keyCode == KeyEvent.KEYCODE_VOLUME_UP) "up" else "down"
                volumeChannel?.invokeMethod("volume", dir)
            }
            return true
        }
        return super.dispatchKeyEvent(event)
    }
}
