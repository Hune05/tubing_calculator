package com.example.tubing_calculator

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.BroadcastReceiver
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
 * 압력시험 타이머 위젯: 앱 "압력 시험 > 시험 기록" 탭이 돌리고 있는 유지시간을 홈 화면에서 본다.
 * 앱이 시작·완료 시각을 넘겨 주면(MethodChannel field/widget의 pt) 위젯이 남은 시간을 스스로 센다(앱이 꺼져 있어도).
 * 완료 시각이 되면 PressureRefreshReceiver가 위젯을 다시 그려 "유지시간 완료"로 바꾼다. 알림은 앱이 따로 예약한 것이 울린다.
 * 누르면 앱의 시험 기록 탭이 열린다(시작·종료 입력은 앱에서).
 */
object PressureTimer {
    private const val REQUEST = 918410

    private fun pi(c: Context): PendingIntent {
        val i = Intent(c, PressureRefreshReceiver::class.java).apply {
            action = "com.example.tubing_calculator.PT_REFRESH"
        }
        return PendingIntent.getBroadcast(c, REQUEST, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    /** 유지 중이면 완료 시각에 위젯을 다시 그리도록 예약하고, 아니면 취소한다. */
    fun scheduleRefresh(c: Context) {
        val am = c.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(pi(c))
        val s = FieldWidgetStore.pt(c) ?: return
        if (s.optString("phase") != "running") return
        val due = s.optLong("dueMs", 0L)
        if (due <= System.currentTimeMillis()) return
        val exact = Build.VERSION.SDK_INT < 31 || am.canScheduleExactAlarms()
        try {
            if (exact) am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, due, pi(c))
            else am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, due, pi(c))
        } catch (e: SecurityException) {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, due, pi(c))
        }
    }

    fun hm(ms: Long): String = SimpleDateFormat("HH:mm", Locale.KOREA).format(Date(ms))

    fun minText(m: Double): String =
        if (m % 1.0 == 0.0) "${m.toInt()}분" else "${m}분"
}

class PressureRefreshReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        FieldWidgetStore.refreshAll(context)
    }
}

class PressureWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) manager.updateAppWidget(id, build(context, id))
    }

    override fun onDeleted(context: Context, ids: IntArray) {
        WidgetCfg.clear(context, ids)
    }

    companion object {
        /** 상태를 글로 풀어 둔 것(카드·한 줄 모양이 같이 쓴다). */
        private class Face(
            val title: String, val chip: String, val big: String, val remainMs: Long, val sub: String, val done: Boolean
        )

        private fun face(c: Context): Face {
            val s = FieldWidgetStore.pt(c)
            val line = s?.optString("line").orEmpty()
            val title = if (line.isEmpty()) "압력시험" else "압력시험 · $line"
            val hold = s?.optDouble("holdMin", 0.0) ?: 0.0
            val now = System.currentTimeMillis()
            return when (s?.optString("phase")) {
                "running" -> {
                    val start = s.optLong("startMs", 0L)
                    val due = s.optLong("dueMs", 0L)
                    if (due > now) {
                        Face(title, "유지 중", "", due - now, "시작 ${PressureTimer.hm(start)} · 완료 ${PressureTimer.hm(due)}", false)
                    } else {
                        Face(title, "완료", "유지시간 완료", 0L, "종료 압력을 앱에서 기록하세요 (${PressureTimer.minText(hold)} 지남)", true)
                    }
                }
                "ended" -> {
                    val start = s.optLong("startMs", 0L)
                    val end = s.optLong("endMs", 0L)
                    Face(title, "종료", "시험 종료", 0L, "${PressureTimer.hm(start)} ~ ${PressureTimer.hm(end)} · 유지 ${PressureTimer.minText(hold)}", true)
                }
                else -> Face(title, "시험 전", "시험 전", 0L, "앱 시험 기록 탭에서 시작하면 여기 남은 시간이 나옵니다", false)
            }
        }

        fun build(c: Context, id: Int = 0): RemoteViews {
            val small = buildSmall(c)
            val large = buildLarge(c)
            if (!WidgetCfg.bgOn(c, id)) {
                WidgetCfg.applyPlain(small, intArrayOf(R.id.pt_s_text, R.id.pt_s_timer), intArrayOf(R.id.pt_s_sub), intArrayOf(), intArrayOf())
                WidgetCfg.applyPlain(large, intArrayOf(R.id.pt_big, R.id.pt_timer), intArrayOf(R.id.pt_title, R.id.pt_sub), intArrayOf(), intArrayOf())
                small.setInt(R.id.pt_s_btn_open, "setBackgroundResource", R.drawable.widget_circle_plain)
                large.setInt(R.id.pt_btn_open, "setBackgroundResource", R.drawable.widget_circle_plain)
            }
            return Adaptive.views(
                c, id, small, large, SizeF(110f, 40f), SizeF(180f, 100f),
                R.id.widget_pt_s_root, R.id.widget_pt_root
            )
        }

        private fun buildLarge(c: Context): RemoteViews {
            val v = RemoteViews(c.packageName, R.layout.widget_pt)
            val f = face(c)
            v.setTextViewText(R.id.pt_title, f.title)
            v.setTextViewText(R.id.pt_chip, f.chip)
            v.setTextViewText(R.id.pt_sub, f.sub)
            if (f.remainMs > 0L) {
                v.setViewVisibility(R.id.pt_timer, View.VISIBLE)
                v.setViewVisibility(R.id.pt_big, View.GONE)
                v.setChronometerCountDown(R.id.pt_timer, true)
                v.setChronometer(R.id.pt_timer, SystemClock.elapsedRealtime() + f.remainMs, null, true)
            } else {
                v.setViewVisibility(R.id.pt_timer, View.GONE)
                v.setViewVisibility(R.id.pt_big, View.VISIBLE)
                v.setTextViewText(R.id.pt_big, f.big)
                v.setChronometer(R.id.pt_timer, SystemClock.elapsedRealtime(), null, false)
            }
            val open = FieldWidgetStore.openAppIntent(c, "pressure:open", 360)
            v.setOnClickPendingIntent(R.id.widget_pt_root, open)
            v.setOnClickPendingIntent(R.id.pt_btn_open, open)
            return v
        }

        private fun buildSmall(c: Context): RemoteViews {
            val v = RemoteViews(c.packageName, R.layout.widget_pt_small)
            val f = face(c)
            v.setTextViewText(R.id.pt_s_sub, f.title)
            if (f.remainMs > 0L) {
                v.setViewVisibility(R.id.pt_s_timer, View.VISIBLE)
                v.setViewVisibility(R.id.pt_s_text, View.GONE)
                v.setChronometerCountDown(R.id.pt_s_timer, true)
                v.setChronometer(R.id.pt_s_timer, SystemClock.elapsedRealtime() + f.remainMs, null, true)
            } else {
                v.setViewVisibility(R.id.pt_s_timer, View.GONE)
                v.setViewVisibility(R.id.pt_s_text, View.VISIBLE)
                v.setTextViewText(R.id.pt_s_text, f.big)
                v.setChronometer(R.id.pt_s_timer, SystemClock.elapsedRealtime(), null, false)
            }
            val open = FieldWidgetStore.openAppIntent(c, "pressure:open", 361)
            v.setOnClickPendingIntent(R.id.widget_pt_s_root, open)
            v.setOnClickPendingIntent(R.id.pt_s_btn_open, open)
            return v
        }
    }
}
