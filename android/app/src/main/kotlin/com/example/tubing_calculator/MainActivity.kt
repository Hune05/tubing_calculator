package com.example.tubing_calculator

import android.Manifest
import android.app.Activity
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build
import android.provider.ContactsContract
import android.provider.OpenableColumns
import android.view.KeyEvent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import androidx.core.content.ContextCompat
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

    // 폰 연락처에서 사용자가 고른 한 명의 이름·전화번호·이메일만 읽는다(앱은 연락처 전체를 읽지 않는다).
    private var contactChannel: MethodChannel? = null
    private var pendingContact: MethodChannel.Result? = null

    companion object {
        const val EXTRA_WIDGET_ACTION = "widget_action"
        const val REQ_CONTACT_PERMISSION = 7101
        const val REQ_CONTACT_PICK = 7102
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
                            call.argument<String>("summary"),
                            call.argument<String>("clock"),
                            call.argument<String>("pt")
                        )
                        FieldWidgetStore.refreshAll(applicationContext)
                        result.success(null)
                    }
                    "takeAction" -> {
                        result.success(pendingWidgetAction)
                        pendingWidgetAction = null
                    }
                    // 퇴근 깜빡 알림 예약: at(epoch ms)이 있으면 그 시각으로 잡고, 없으면 취소한다.
                    "clockOutReminder" -> {
                        val at = call.argument<Number>("at")?.toLong()
                        if (at == null) {
                            ClockReminder.cancel(applicationContext)
                        } else {
                            ClockReminder.schedule(applicationContext, at)
                        }
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
        }
        contactChannel = MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            "field/contact_pick"
        ).also { ch ->
            ch.setMethodCallHandler { call, result ->
                when (call.method) {
                    "pick" -> startContactPick(result)
                    else -> result.notImplemented()
                }
            }
        }
        readWidgetAction(intent)?.let { pendingWidgetAction = it }
        // 앱이 꺼져 있을 때 공유로 열린 경우.
        readSharedDrawing(intent)?.let { pendingDrawing = it }
    }

    private fun startContactPick(result: MethodChannel.Result) {
        if (pendingContact != null) {
            result.error("busy", "이미 연락처를 고르는 중입니다.", null)
            return
        }
        pendingContact = result
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.READ_CONTACTS)
            == PackageManager.PERMISSION_GRANTED
        ) {
            launchContactPicker()
        } else {
            requestPermissions(arrayOf(Manifest.permission.READ_CONTACTS), REQ_CONTACT_PERMISSION)
        }
    }

    private fun launchContactPicker() {
        try {
            startActivityForResult(
                Intent(Intent.ACTION_PICK, ContactsContract.Contacts.CONTENT_URI),
                REQ_CONTACT_PICK
            )
        } catch (e: Exception) {
            finishContact { it.error("picker", "연락처 선택창을 열 수 없습니다.", null) }
        }
    }

    private fun finishContact(block: (MethodChannel.Result) -> Unit) {
        val r = pendingContact ?: return
        pendingContact = null
        block(r)
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode != REQ_CONTACT_PERMISSION) return
        if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            launchContactPicker()
        } else {
            finishContact { it.error("denied", "연락처 접근이 허용되지 않았습니다.", null) }
        }
    }

    @Deprecated("Deprecated in Java")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != REQ_CONTACT_PICK) return
        val uri = data?.data
        if (resultCode != Activity.RESULT_OK || uri == null) {
            finishContact { it.success(null) }
            return
        }
        try {
            var id: String? = null
            var name = ""
            contentResolver.query(
                uri,
                arrayOf(ContactsContract.Contacts._ID, ContactsContract.Contacts.DISPLAY_NAME),
                null, null, null
            )?.use { c ->
                if (c.moveToFirst()) {
                    id = c.getString(0)
                    name = c.getString(1) ?: ""
                }
            }
            val contactId = id
            val phones = LinkedHashSet<String>()
            val emails = LinkedHashSet<String>()
            if (contactId != null) {
                contentResolver.query(
                    ContactsContract.CommonDataKinds.Phone.CONTENT_URI,
                    arrayOf(ContactsContract.CommonDataKinds.Phone.NUMBER),
                    ContactsContract.CommonDataKinds.Phone.CONTACT_ID + "=?",
                    arrayOf(contactId), null
                )?.use { c ->
                    while (c.moveToNext()) {
                        c.getString(0)?.trim()?.takeIf { it.isNotEmpty() }?.let { phones.add(it) }
                    }
                }
                contentResolver.query(
                    ContactsContract.CommonDataKinds.Email.CONTENT_URI,
                    arrayOf(ContactsContract.CommonDataKinds.Email.ADDRESS),
                    ContactsContract.CommonDataKinds.Email.CONTACT_ID + "=?",
                    arrayOf(contactId), null
                )?.use { c ->
                    while (c.moveToNext()) {
                        c.getString(0)?.trim()?.takeIf { it.isNotEmpty() }?.let { emails.add(it) }
                    }
                }
            }
            finishContact {
                it.success(
                    mapOf(
                        "name" to name,
                        "phones" to phones.toList(),
                        "emails" to emails.toList()
                    )
                )
            }
        } catch (e: Exception) {
            finishContact { it.error("read", "연락처를 읽을 수 없습니다.", null) }
        }
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
