package com.example.tubing_calculator

import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.OpenableColumns
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

    // 홈 화면 위젯을 눌러 열렸을 때의 동작("quick:제목" 등). 앱이 "takeAction"으로 가져간다.
    private var widgetChannel: MethodChannel? = null
    private var pendingWidgetAction: String? = null

    companion object {
        const val EXTRA_WIDGET_ACTION = "widget_action"
    }

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
        widgetChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "field/widget"
        ).also { ch ->
            ch.setMethodCallHandler { call, result ->
                when (call.method) {
                    "update" -> {
                        FieldWidgetStore.save(
                            applicationContext,
                            call.argument<String>("quick"),
                            call.argument<String>("summary")
                        )
                        FieldWidgetStore.refreshAll(applicationContext)
                        result.success(null)
                    }
                    "takeAction" -> {
                        result.success(pendingWidgetAction)
                        pendingWidgetAction = null
                    }
                    else -> result.notImplemented()
                }
            }
        }
        readWidgetAction(intent)?.let { pendingWidgetAction = it }
        // 앱이 꺼져 있을 때 공유로 열린 경우.
        readSharedDrawing(intent)?.let { pendingDrawing = it }
    }

    // 앱이 떠 있을 때 공유로 다시 들어온 경우.
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        readWidgetAction(intent)?.let {
            pendingWidgetAction = it
            widgetChannel?.invokeMethod("received", null)
            return
        }
        val d = readSharedDrawing(intent) ?: return
        pendingDrawing = d
        drawingChannel?.invokeMethod("received", null)
    }

    private fun readWidgetAction(intent: Intent?): String? {
        val a = intent?.getStringExtra(EXTRA_WIDGET_ACTION) ?: return null
        // 화면을 다시 만들 때 같은 위젯 동작을 두 번 하지 않게 한 번 읽으면 지운다.
        intent.removeExtra(EXTRA_WIDGET_ACTION)
        return a
    }

    private fun displayName(uri: Uri): String? = try {
        contentResolver.query(uri, arrayOf(OpenableColumns.DISPLAY_NAME), null, null, null)?.use { c ->
            if (c.moveToFirst()) c.getString(0) else null
        }
    } catch (e: Exception) {
        null
    } ?: uri.lastPathSegment

    private fun readSharedDrawing(intent: Intent?): Map<String, String>? {
        val action = intent?.action
        if (action != Intent.ACTION_SEND && action != Intent.ACTION_VIEW) return null
        val uri: Uri = (if (action == Intent.ACTION_VIEW) {
            val d = intent.data
            // 딥링크(tubingapp:// 등)는 여기서 다루지 않는다
            if (d == null || (d.scheme != "content" && d.scheme != "file")) return null
            d
        } else if (Build.VERSION.SDK_INT >= 33) {
            intent.getParcelableExtra(Intent.EXTRA_STREAM, Uri::class.java)
        } else {
            @Suppress("DEPRECATION")
            intent.getParcelableExtra(Intent.EXTRA_STREAM) as? Uri
        }) ?: return null
        // 화면을 다시 만들 때 같은 공유를 두 번 받지 않게 한 번 읽으면 지운다.
        intent.action = null
        val mime = intent.type ?: contentResolver.getType(uri) ?: ""
        // 파일 이름의 확장자를 먼저 본다(DXF·DWG는 mime이 제각각이다).
        val shownName = displayName(uri) ?: ""
        val nameExt = shownName.takeIf { it.isNotEmpty() }?.substringAfterLast('.', "")?.lowercase() ?: ""
        val ext = when {
            nameExt in listOf("pdf", "dxf", "dwg", "png", "jpg", "jpeg", "webp") -> nameExt
            mime == "application/pdf" -> "pdf"
            mime.contains("dxf") -> "dxf"
            mime.contains("dwg") || mime.contains("autocad") || mime.contains("acad") -> "dwg"
            mime.contains("png") -> "png"
            mime.startsWith("image/") -> "jpg"
            else -> return null
        }
        return try {
            val dir = File(filesDir, "shared_drawings").apply { mkdirs() }
            val out = File(dir, "drawing_${System.currentTimeMillis()}.$ext")
            val input = contentResolver.openInputStream(uri) ?: return null
            input.use { src -> out.outputStream().use { src.copyTo(it) } }
            mapOf("path" to out.absolutePath, "mime" to mime, "name" to shownName)
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
