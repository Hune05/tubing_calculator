package com.example.tubing_calculator

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.BroadcastReceiver
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.SystemClock
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * 압력시험 타이머 위젯(앱 시험 기록 탭의 유지시간 타이머 모양).
 * 앱 "압력 시험 > 시험 기록" 탭이 돌리는 유지시간을 홈 화면에서 본다. 앱이 시작·완료 시각을 넘겨 주면
 * (MethodChannel field/widget의 pt) 남은 시간은 위젯이 스스로 센다(Chronometer, 앱이 꺼져 있어도).
 * 진행 막대는 유지 중에는 20초마다 다시 그린다(PressureRefreshReceiver). 완료 시각에도 한 번 그린다.
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
        return m.getAppWidgetIds(ComponentName(c, PressureAppWidgetProvider::class.java)).isNotEmpty()
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
        // 8차(10-09): 20초마다 폰을 깨웠다(RTC_WAKEUP). 위젯 다시 그리기는 화면이 켜져 있을 때만 쓸모가
        // 있으니 깨우지 않는 알람으로 둔다. 꺼져 있는 동안 지난 것은 화면을 켜면 바로 온다.
        // 완료 알림은 앱이 따로 예약한 알림이 울린다(이것과 상관없다).
        try {
            if (exact) am.setExact(AlarmManager.RTC, next, pi(c))
            else am.setWindow(AlarmManager.RTC, next, 5_000L, pi(c))
        } catch (e: SecurityException) {
            am.setWindow(AlarmManager.RTC, next, 5_000L, pi(c))
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

/** 시:분:초 글(앱 유지시간 타이머의 경과 시간과 같은 모양). */
private fun clockText(ms: Long): String {
    val t = (ms / 1000).coerceAtLeast(0L)
    val h = t / 3600
    val m = t % 3600 / 60
    val sec = t % 60
    return if (h > 0) String.format(Locale.US, "%d:%02d:%02d", h, m, sec) else String.format(Locale.US, "%02d:%02d", m, sec)
}

/**
 * 앱 "시험 기록" 탭의 유지시간 타이머(상태, 큰 경과 시간, 남은 시간, 시작·완료 예정)를 크게 옮긴 위젯.
 * 경과 시간은 위로, 남은 시간은 아래로 센다(Chronometer). 상태 색: 유지 중 파랑, 완료 초록.
 * 줄이면 한 줄(이름 + 남은 시간)로 바뀐다(안드로이드 12 이상).
 */
class PressureAppWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) manager.updateAppWidget(id, build(context))
        PressureTimer.scheduleRefresh(context)
    }

    companion object {
        private const val BLUE = 0xFF2563EB.toInt()
        private const val GREEN = 0xFF16A34A.toInt()
        private const val GRAY = 0xFF6B7280.toInt()

        fun build(c: Context): RemoteViews {
            val large = buildLarge(c)
            if (Build.VERSION.SDK_INT < 31) return large
            return RemoteViews(mapOf(SizeF(180f, 40f) to buildSmall(c), SizeF(180f, 150f) to large))
        }

        private fun buildSmall(c: Context): RemoteViews {
            val v = RemoteViews(c.packageName, R.layout.widget_pt_app_small)
            val f = PtFace.of(c)
            v.setTextViewText(R.id.pta_s_status, when (f.state) {
                "running" -> "유지 중 · 시작 ${PressureTimer.hms(f.startMs)}"
                "done" -> "유지시간 완료 (${f.holdText})"
                "ended" -> "종료"
                else -> "시작 전"
            })
            v.setTextViewText(R.id.pta_s_label, if (f.remainMs > 0L) "남은 시간" else f.label)
            if (f.remainMs > 0L) {
                v.setViewVisibility(R.id.pta_s_remain, View.VISIBLE)
                v.setViewVisibility(R.id.pta_s_text, View.GONE)
                v.setChronometerCountDown(R.id.pta_s_remain, true)
                v.setChronometer(R.id.pta_s_remain, SystemClock.elapsedRealtime() + f.remainMs, null, true)
            } else {
                v.setViewVisibility(R.id.pta_s_remain, View.GONE)
                v.setViewVisibility(R.id.pta_s_text, View.VISIBLE)
                v.setTextViewText(R.id.pta_s_text, f.big)
                v.setChronometer(R.id.pta_s_remain, SystemClock.elapsedRealtime(), null, false)
                v.setTextColor(R.id.pta_s_text, if (f.state == "done") GREEN else GRAY)
            }
            v.setOnClickPendingIntent(R.id.widget_pta_s_root, FieldWidgetStore.openAppIntent(c, "pressure:open", 374))
            return v
        }

        private fun buildLarge(c: Context): RemoteViews {
            val v = RemoteViews(c.packageName, R.layout.widget_pt_app)
            val f = PtFace.of(c)
            val now = System.currentTimeMillis()
            val color = when (f.state) { "running" -> BLUE; "done" -> GREEN; else -> GRAY }
            v.setTextViewText(R.id.pta_line, f.line)
            v.setTextViewText(R.id.pta_status, when (f.state) { "running" -> "유지 중"; "done" -> "유지시간 완료"; "ended" -> "종료"; else -> "시작 전" })
            v.setTextColor(R.id.pta_status, color)

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

            // 진행 막대: 유지 중 파랑(경과 비율), 완료 초록(가득)
            v.setViewVisibility(R.id.pta_bar, if (f.state == "running") View.VISIBLE else View.GONE)
            v.setViewVisibility(R.id.pta_bar_done, if (f.state == "done") View.VISIBLE else View.GONE)
            if (f.state == "running") v.setProgressBar(R.id.pta_bar, 1000, ((1f - f.fraction) * 1000).toInt(), false)

            // 남은 시간: 유지 중이면 줄어드는 시계, 아니면 글
            if (f.remainMs > 0L) {
                v.setTextViewText(R.id.pta_remain_label, "남은 시간")
                v.setTextColor(R.id.pta_remain_label, BLUE)
                v.setViewVisibility(R.id.pta_remain, View.VISIBLE)
                v.setChronometerCountDown(R.id.pta_remain, true)
                v.setChronometer(R.id.pta_remain, SystemClock.elapsedRealtime() + f.remainMs, null, true)
            } else {
                v.setViewVisibility(R.id.pta_remain, View.GONE)
                v.setChronometer(R.id.pta_remain, SystemClock.elapsedRealtime(), null, false)
                v.setTextColor(R.id.pta_remain_label, color)
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
