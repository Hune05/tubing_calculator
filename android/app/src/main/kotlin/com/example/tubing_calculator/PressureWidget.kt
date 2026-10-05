package com.example.tubing_calculator

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BlurMaskFilter
import android.graphics.Canvas
import android.graphics.Paint
import android.graphics.RectF
import android.os.Build
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.math.cos
import kotlin.math.sin

/**
 * 압력시험 타이머 위젯 세 가지(다이얼·큰 숫자·미니 링).
 * 앱 "압력 시험 > 시험 기록" 탭이 돌리는 유지시간을 홈 화면에서 본다. 앱이 시작·완료 시각을 넘겨 주면
 * (MethodChannel field/widget의 pt) 남은 시간은 위젯이 스스로 센다(Chronometer, 앱이 꺼져 있어도).
 * 링·막대의 진행은 그림이라 유지 중에는 20초마다 다시 그린다(PressureRefreshReceiver). 완료 시각에도 한 번 그린다.
 * 알림은 앱이 따로 예약한 유지시간 알림이 울린다. 누르면 앱의 시험 기록 탭이 열린다(시작·종료 입력은 앱에서).
 */
object PressureTimer {
    private const val REQUEST = 918410
    private const val TICK_MS = 20_000L

    private fun pi(c: Context): PendingIntent {
        val i = Intent(c, PressureRefreshReceiver::class.java).apply {
            action = "com.example.tubing_calculator.PT_REFRESH"
        }
        return PendingIntent.getBroadcast(c, REQUEST, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    private fun hasWidgets(c: Context): Boolean {
        val m = AppWidgetManager.getInstance(c)
        return listOf(
            PressureDialWidgetProvider::class.java,
            PressureDigitWidgetProvider::class.java,
            PressureMiniWidgetProvider::class.java,
            PressureAppWidgetProvider::class.java
        ).any { m.getAppWidgetIds(ComponentName(c, it)).isNotEmpty() }
    }

    /** 유지 중이면 다음 그리기(20초 뒤 또는 완료 시각 중 빠른 쪽)를 예약하고, 아니면 취소한다. */
    fun scheduleRefresh(c: Context) {
        val am = c.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(pi(c))
        val s = FieldWidgetStore.pt(c) ?: return
        if (s.optString("phase") != "running") return
        val now = System.currentTimeMillis()
        val due = s.optLong("dueMs", 0L)
        if (due <= now) return
        val next = if (hasWidgets(c)) minOf(due, now + TICK_MS) else due
        val exact = Build.VERSION.SDK_INT < 31 || am.canScheduleExactAlarms()
        try {
            if (exact) am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next, pi(c))
            else am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next, pi(c))
        } catch (e: SecurityException) {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, next, pi(c))
        }
    }

    fun hm(ms: Long): String = SimpleDateFormat("HH:mm", Locale.KOREA).format(Date(ms))

    /** 앱 유지시간 타이머 줄과 같은 글: 시작은 초까지, 완료 예정은 분까지. */
    fun hms(ms: Long): String = SimpleDateFormat("HH:mm:ss", Locale.KOREA).format(Date(ms))

    fun minText(m: Double): String = if (m % 1.0 == 0.0) "${m.toInt()}분" else "${m}분"
}

class PressureRefreshReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        FieldWidgetStore.refreshAll(context)
        PressureTimer.scheduleRefresh(context)
    }
}

/** 지금 상태를 글과 숫자로 풀어 둔 것(세 위젯이 같이 쓴다). */
internal class PtFace(
    val state: String,       // running / done / ended / idle
    val line: String,        // 라인 번호(없으면 빈 글)
    val chip: String,        // 유지 중 / 완료 / 종료 / 시험 전
    val remainMs: Long,      // running일 때 남은 시간
    val fraction: Float,     // 링에 채울 남은 비율(0~1)
    val label: String,       // 큰 시간 위의 작은 글
    val big: String,         // running이 아닐 때 큰 글
    val sub: String,         // 아랫줄(한 줄)
    val startMs: Long = 0L,
    val dueMs: Long = 0L,
    val endMs: Long = 0L,
    val holdText: String = "",
    val times2: String = ""   // 두 줄로 쓸 때(시작 / 완료 예정)
) {
    val title: String get() = if (line.isEmpty()) "압력시험 타이머" else "압력시험 · $line"

    companion object {
        fun of(c: Context): PtFace {
            val s = FieldWidgetStore.pt(c)
            val line = s?.optString("line").orEmpty()
            val hold = s?.optDouble("holdMin", 0.0) ?: 0.0
            val now = System.currentTimeMillis()
            return when (s?.optString("phase")) {
                "running" -> {
                    val start = s.optLong("startMs", 0L)
                    val due = s.optLong("dueMs", 0L)
                    if (due > now) {
                        val total = (due - start).coerceAtLeast(1L)
                        PtFace("running", line, "유지 중", due - now, ((due - now).toFloat() / total).coerceIn(0f, 1f),
                            "남은 시간", "", "시작 ${PressureTimer.hms(start)} · 완료 예정 ${PressureTimer.hm(due)}", start, due, 0L, PressureTimer.minText(hold),
                            "시작 ${PressureTimer.hms(start)}\n완료 예정 ${PressureTimer.hm(due)}")
                    } else {
                        PtFace("done", line, "완료", 0L, 1f, "유지시간", "완료", "시작 ${PressureTimer.hms(start)} · 완료 예정 ${PressureTimer.hm(due)}", start, due, 0L, PressureTimer.minText(hold),
                            "시작 ${PressureTimer.hms(start)}\n완료 예정 ${PressureTimer.hm(due)}")
                    }
                }
                "ended" -> {
                    val start = s.optLong("startMs", 0L)
                    val end = s.optLong("endMs", 0L)
                    PtFace("ended", line, "종료", 0L, 0f, "시험", "종료",
                        "시작 ${PressureTimer.hms(start)} · 종료 ${PressureTimer.hms(end)}", start, 0L, end, PressureTimer.minText(hold),
                        "시작 ${PressureTimer.hms(start)}\n종료 ${PressureTimer.hms(end)}")
                }
                else -> PtFace("idle", line, "시험 전", 0L, 0f, "압력시험", "시험 전", "앱 시험 기록 탭에서 시작", 0L, 0L, 0L, PressureTimer.minText(hold))
            }
        }
    }
}

/** 다이얼(눈금 + 남은 시간 호 + 바늘)을 그림으로 만든다. 투명 바탕이라 위젯의 어두운 바탕 위에 얹힌다. */
internal object PtRing {
    private const val ACCENT = 0xFF3B82F6.toInt()
    private const val DONE = 0xFF34D399.toInt()
    private const val GRAY = 0xFF6B7280.toInt()

    fun draw(px: Int, fraction: Float, state: String): Bitmap {
        val bmp = Bitmap.createBitmap(px, px, Bitmap.Config.ARGB_8888)
        val cv = Canvas(bmp)
        val r = px / 2f
        val accent = when (state) { "done" -> DONE; "running" -> ACCENT; else -> GRAY }

        // 눈금 60개(5개마다 길게)
        val tick = Paint(Paint.ANTI_ALIAS_FLAG).apply { strokeCap = Paint.Cap.ROUND; color = 0xFF8A9099.toInt() }
        for (i in 0 until 60) {
            val major = i % 5 == 0
            val a = Math.toRadians(i * 6.0 - 90.0)
            val outer = r * 0.97f
            val inner = outer - r * (if (major) 0.09f else 0.045f)
            tick.strokeWidth = px * (if (major) 0.013f else 0.007f)
            cv.drawLine(r + cos(a).toFloat() * inner, r + sin(a).toFloat() * inner, r + cos(a).toFloat() * outer, r + sin(a).toFloat() * outer, tick)
        }

        val ar = r * 0.76f
        val rect = RectF(r - ar, r - ar, r + ar, r + ar)
        val sw = px * 0.075f

        // 바탕 호(트랙)
        val track = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE; strokeWidth = sw; color = 0xFF2B3138.toInt() }
        cv.drawCircle(r, r, ar, track)

        // 가운데 원판
        val disc = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.FILL; color = 0xFF1C2127.toInt() }
        cv.drawCircle(r, r, r * 0.60f, disc)
        val rim = Paint(Paint.ANTI_ALIAS_FLAG).apply { style = Paint.Style.STROKE; strokeWidth = px * 0.012f; color = 0xFF343C45.toInt() }
        cv.drawCircle(r, r, r * 0.60f, rim)

        if (fraction > 0.001f) {
            val sweep = 360f * fraction
            val glow = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE; strokeWidth = sw * 1.5f; color = accent; alpha = 120
                strokeCap = Paint.Cap.ROUND; maskFilter = BlurMaskFilter(px * 0.03f, BlurMaskFilter.Blur.NORMAL)
            }
            cv.drawArc(rect, -90f, sweep, false, glow)
            val arc = Paint(Paint.ANTI_ALIAS_FLAG).apply {
                style = Paint.Style.STROKE; strokeWidth = sw; color = accent; strokeCap = Paint.Cap.ROUND
            }
            cv.drawArc(rect, -90f, sweep, false, arc)

            if (state == "running") {
                // 남은 시간이 끝나는 자리를 가리키는 바늘
                val a = Math.toRadians(-90.0 + sweep)
                val needle = Paint(Paint.ANTI_ALIAS_FLAG).apply { strokeCap = Paint.Cap.ROUND; color = 0xFF93C5FD.toInt(); strokeWidth = px * 0.014f }
                cv.drawLine(r + cos(a).toFloat() * r * 0.50f, r + sin(a).toFloat() * r * 0.50f, r + cos(a).toFloat() * r * 0.98f, r + sin(a).toFloat() * r * 0.98f, needle)
                val dot = Paint(Paint.ANTI_ALIAS_FLAG).apply { color = 0xFFFFFFFF.toInt() }
                cv.drawCircle(r + cos(a).toFloat() * ar, r + sin(a).toFloat() * ar, sw * 0.28f, dot)
            }
        }
        return bmp
    }
}

private fun openIntent(c: Context, code: Int) = FieldWidgetStore.openAppIntent(c, "pressure:open", code)

/** 가운데 시간 칸을 상태에 맞게 채운다: 유지 중이면 줄어드는 시계, 아니면 글. */
private fun fillTime(v: RemoteViews, timerId: Int, textId: Int, f: PtFace) {
    if (f.remainMs > 0L) {
        v.setViewVisibility(timerId, View.VISIBLE)
        v.setViewVisibility(textId, View.GONE)
        v.setChronometerCountDown(timerId, true)
        v.setChronometer(timerId, SystemClock.elapsedRealtime() + f.remainMs, null, true)
    } else {
        v.setViewVisibility(timerId, View.GONE)
        v.setViewVisibility(textId, View.VISIBLE)
        v.setTextViewText(textId, f.big)
        v.setChronometer(timerId, SystemClock.elapsedRealtime(), null, false)
    }
}

private fun density(c: Context) = c.resources.displayMetrics.density

class PressureDialWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) manager.updateAppWidget(id, build(context))
        PressureTimer.scheduleRefresh(context)
    }

    companion object {
        fun build(c: Context): RemoteViews {
            val v = RemoteViews(c.packageName, R.layout.widget_pt_dial)
            val f = PtFace.of(c)
            val px = (260 * density(c)).toInt().coerceIn(300, 720)
            v.setImageViewBitmap(R.id.ptd_ring, PtRing.draw(px, f.fraction, f.state))
            v.setTextViewText(R.id.ptd_title, f.title)
            v.setTextViewText(R.id.ptd_label, f.label)
            v.setTextViewText(R.id.ptd_sub, if (f.times2.isEmpty()) f.sub else f.times2)
            fillTime(v, R.id.ptd_timer, R.id.ptd_text, f)
            v.setOnClickPendingIntent(R.id.widget_ptd_root, openIntent(c, 370))
            return v
        }
    }
}

class PressureDigitWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) manager.updateAppWidget(id, build(context))
        PressureTimer.scheduleRefresh(context)
    }

    companion object {
        fun build(c: Context): RemoteViews {
            val v = RemoteViews(c.packageName, R.layout.widget_pt_digit)
            val f = PtFace.of(c)
            v.setTextViewText(R.id.ptb_line, f.line)
            v.setTextViewText(R.id.ptb_chip, f.chip)
            v.setTextViewText(R.id.ptb_sub, f.sub)
            v.setTextViewText(R.id.ptb_label, if (f.state == "running") "남은 시간" else f.label)
            fillTime(v, R.id.ptb_timer, R.id.ptb_text, f)
            // 막대는 남은 비율(1000분율)
            v.setProgressBar(R.id.ptb_bar, 1000, (f.fraction * 1000).toInt(), false)
            v.setOnClickPendingIntent(R.id.widget_ptb_root, openIntent(c, 371))
            return v
        }
    }
}

class PressureMiniWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) manager.updateAppWidget(id, build(context))
        PressureTimer.scheduleRefresh(context)
    }

    companion object {
        fun build(c: Context): RemoteViews {
            val v = RemoteViews(c.packageName, R.layout.widget_pt_mini)
            val f = PtFace.of(c)
            val px = (150 * density(c)).toInt().coerceIn(200, 480)
            v.setImageViewBitmap(R.id.ptm_ring, PtRing.draw(px, f.fraction, f.state))
            v.setTextViewText(R.id.ptm_label, if (f.dueMs > 0L && f.state != "ended") "~${PressureTimer.hm(f.dueMs)} 완료" else f.label)
            fillTime(v, R.id.ptm_timer, R.id.ptm_text, f)
            v.setOnClickPendingIntent(R.id.widget_ptm_root, openIntent(c, 372))
            return v
        }
    }
}

/** 시:분:초 글(앱 유지시간 타이머의 경과 시간과 같은 모양). */
private fun clockText(ms: Long): String {
    val t = (ms / 1000).coerceAtLeast(0L)
    val h = t / 3600
    val m = t % 3600 / 60
    val sec = t % 60
    return if (h > 0) String.format(Locale.US, "%d:%02d:%02d", h, m, sec) else String.format(Locale.US, "%02d:%02d", m, sec)
}

/**
 * 앱 "시험 기록" 탭의 유지시간 타이머(상태, 큰 경과 시간, 남은 시간)를 크게 옮긴 위젯.
 * 경과 시간은 위로 세고(Chronometer) 남은 시간은 아래로 센다. 끝나면 경과 시간이 멈춘 채 "유지시간 완료 (N분)"가 된다.
 */
class PressureAppWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) manager.updateAppWidget(id, build(context))
        PressureTimer.scheduleRefresh(context)
    }

    companion object {
        fun build(c: Context): RemoteViews {
            val v = RemoteViews(c.packageName, R.layout.widget_pt_app)
            val f = PtFace.of(c)
            val now = System.currentTimeMillis()
            v.setTextViewText(R.id.pta_line, f.line)
            v.setTextViewText(R.id.pta_status, when (f.state) { "running" -> "유지 중"; "done" -> "유지시간 완료"; "ended" -> "종료"; else -> "시작 전" })

            // 큰 경과 시간: 진행 중(완료 뒤에도 종료 전까지)은 계속 센다
            val counting = f.state == "running" || f.state == "done"
            if (counting) {
                v.setViewVisibility(R.id.pta_elapsed, View.VISIBLE)
                v.setViewVisibility(R.id.pta_elapsed_text, View.GONE)
                v.setChronometerCountDown(R.id.pta_elapsed, false)
                v.setChronometer(R.id.pta_elapsed, SystemClock.elapsedRealtime() - (now - f.startMs).coerceAtLeast(0L), null, true)
            } else {
                v.setViewVisibility(R.id.pta_elapsed, View.GONE)
                v.setViewVisibility(R.id.pta_elapsed_text, View.VISIBLE)
                v.setTextViewText(R.id.pta_elapsed_text, if (f.state == "ended") clockText(f.endMs - f.startMs) else "00:00")
                v.setChronometer(R.id.pta_elapsed, SystemClock.elapsedRealtime(), null, false)
            }

            // 남은 시간: 유지 중이면 줄어드는 시계, 아니면 글
            if (f.remainMs > 0L) {
                v.setTextViewText(R.id.pta_remain_label, "남은 시간")
                v.setViewVisibility(R.id.pta_remain, View.VISIBLE)
                v.setChronometerCountDown(R.id.pta_remain, true)
                v.setChronometer(R.id.pta_remain, SystemClock.elapsedRealtime() + f.remainMs, null, true)
            } else {
                v.setViewVisibility(R.id.pta_remain, View.GONE)
                v.setChronometer(R.id.pta_remain, SystemClock.elapsedRealtime(), null, false)
                v.setTextViewText(
                    R.id.pta_remain_label,
                    when (f.state) {
                        "done" -> "유지시간 완료 (${f.holdText})"
                        "ended" -> "유지시간 ${f.holdText} · 종료"
                        else -> "유지시간 ${f.holdText}"
                    }
                )
            }
            v.setTextViewText(R.id.pta_times, if (f.state == "idle") "" else f.sub)
            v.setViewVisibility(R.id.pta_times, if (f.state == "idle") View.GONE else View.VISIBLE)
            v.setOnClickPendingIntent(R.id.widget_pta_root, FieldWidgetStore.openAppIntent(c, "pressure:open", 373))
            return v
        }
    }
}
