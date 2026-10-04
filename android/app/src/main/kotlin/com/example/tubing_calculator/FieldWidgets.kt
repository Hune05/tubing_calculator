package com.example.tubing_calculator

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.view.View
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject

// 홈 화면 위젯 세 개("빠른 실행", "오늘 요약", "출퇴근")가 쓰는 자료와 그리는 곳.
// 앱(Dart)이 MethodChannel "field/widget"의 update로 자료를 넘기면 여기에 저장하고 위젯을 다시 그린다.
// 위젯은 통신 없이 이 저장된 자료만 읽는다(발전소처럼 통신이 없어도 뜬다).
// 위젯을 누르면 MainActivity를 "widget_action" 값과 함께 열고, 앱이 그 값을 보고 해당 기능을 연다.

object FieldWidgetStore {
    private const val PREFS = "field_widget_prefs"
    private const val KEY_QUICK = "quick"
    private const val KEY_SUMMARY = "summary"
    private const val KEY_CLOCK = "clock"

    private fun prefs(c: Context) = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun save(c: Context, quick: String?, summary: String?, clock: String? = null) {
        val e = prefs(c).edit()
        if (quick != null) e.putString(KEY_QUICK, quick)
        if (summary != null) e.putString(KEY_SUMMARY, summary)
        if (clock != null) e.putString(KEY_CLOCK, clock)
        e.apply()
    }

    /** 빠른 실행 제목들(앱이 정해 준 순서, 최대 4개만 그린다). */
    fun quickTitles(c: Context): List<String> {
        val raw = prefs(c).getString(KEY_QUICK, null) ?: return emptyList()
        return try {
            val a = JSONArray(raw)
            (0 until a.length()).map { a.getString(it) }.filter { it.isNotBlank() }
        } catch (e: Exception) {
            emptyList()
        }
    }

    fun summary(c: Context): JSONObject? {
        val raw = prefs(c).getString(KEY_SUMMARY, null) ?: return null
        return try {
            JSONObject(raw)
        } catch (e: Exception) {
            null
        }
    }

    /** 출퇴근 위젯 값: {"date":"yyyy-MM-dd","phase":"ready|working|done|off","text":"..."} */
    fun clock(c: Context): JSONObject? {
        val raw = prefs(c).getString(KEY_CLOCK, null) ?: return null
        return try {
            JSONObject(raw)
        } catch (e: Exception) {
            null
        }
    }

    fun refreshAll(c: Context) {
        val mgr = AppWidgetManager.getInstance(c)
        val quickIds = mgr.getAppWidgetIds(ComponentName(c, QuickLaunchWidgetProvider::class.java))
        if (quickIds.isNotEmpty()) {
            val v = QuickLaunchWidgetProvider.build(c)
            for (id in quickIds) mgr.updateAppWidget(id, v)
        }
        val sumIds = mgr.getAppWidgetIds(ComponentName(c, SummaryWidgetProvider::class.java))
        if (sumIds.isNotEmpty()) {
            val v = SummaryWidgetProvider.build(c)
            for (id in sumIds) mgr.updateAppWidget(id, v)
        }
        val clockIds = mgr.getAppWidgetIds(ComponentName(c, ClockWidgetProvider::class.java))
        if (clockIds.isNotEmpty()) {
            val v = ClockWidgetProvider.build(c)
            for (id in clockIds) mgr.updateAppWidget(id, v)
        }
    }

    /** 위젯을 누르면 앱을 열면서 [action]을 넘긴다. [code]는 위젯 눌림마다 달라야 한다. */
    fun openAppIntent(c: Context, action: String, code: Int): PendingIntent {
        val i = Intent(c, MainActivity::class.java).apply {
            this.action = "com.example.tubing_calculator.WIDGET"
            data = Uri.parse("fieldwidget://action/$code")
            putExtra(MainActivity.EXTRA_WIDGET_ACTION, action)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
        }
        return PendingIntent.getActivity(
            c, code, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }
}

class QuickLaunchWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val views = build(context)
        for (id in ids) manager.updateAppWidget(id, views)
    }

    companion object {
        private val SLOTS = intArrayOf(
            R.id.quick_slot_1, R.id.quick_slot_2, R.id.quick_slot_3, R.id.quick_slot_4
        )

        fun build(c: Context): RemoteViews {
            val v = RemoteViews(c.packageName, R.layout.widget_quick)
            val titles = FieldWidgetStore.quickTitles(c).take(SLOTS.size)
            v.setViewVisibility(R.id.widget_quick_empty, if (titles.isEmpty()) View.VISIBLE else View.GONE)
            // 제목·빈 안내를 눌러도 앱은 열린다.
            v.setOnClickPendingIntent(R.id.widget_quick_root, FieldWidgetStore.openAppIntent(c, "open", 100))
            for ((i, slot) in SLOTS.withIndex()) {
                if (i < titles.size) {
                    v.setViewVisibility(slot, View.VISIBLE)
                    v.setTextViewText(slot, titles[i] + "  ›")
                    v.setOnClickPendingIntent(
                        slot, FieldWidgetStore.openAppIntent(c, "quick:" + titles[i], 101 + i)
                    )
                } else {
                    v.setViewVisibility(slot, View.GONE)
                }
            }
            return v
        }
    }
}

class SummaryWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val views = build(context)
        for (id in ids) manager.updateAppWidget(id, views)
    }

    companion object {
        private fun count(o: JSONObject?, key: String): Int? =
            if (o == null || !o.has(key) || o.isNull(key)) null else o.optInt(key, -1).takeIf { it >= 0 }

        fun build(c: Context): RemoteViews {
            val v = RemoteViews(c.packageName, R.layout.widget_summary)
            val s = FieldWidgetStore.summary(c)
            val date = s?.optString("date").orEmpty()
            v.setTextViewText(R.id.summary_title, if (date.isEmpty()) "오늘 요약" else "오늘 · $date")
            val sched = count(s, "schedule")
            val reports = count(s, "reports")
            val stock = count(s, "stock")
            val att = s?.optString("attendance").orEmpty()
            v.setTextViewText(
                R.id.summary_line_schedule,
                if (sched == null) "오늘 일정 —" else if (sched == 0) "오늘 남은 일정 없음" else "오늘 남은 일정 ${sched}건"
            )
            v.setTextViewText(
                R.id.summary_line_reports,
                if (reports == null) "일지 —" else if (reports == 0) "일지 다 씀" else "일지 안 쓴 프로젝트 ${reports}곳"
            )
            v.setTextViewText(
                R.id.summary_line_stock,
                if (stock == null) "자재 —" else if (stock == 0) "자재 부족 없음" else "자재 부족 ${stock}건"
            )
            v.setTextViewText(R.id.summary_line_attendance, if (att.isEmpty()) "오늘 근태 —" else "오늘 근태 $att")
            val at = s?.optString("updatedAt").orEmpty()
            v.setTextViewText(R.id.summary_updated, if (at.isEmpty()) "앱을 한 번 열면 채워집니다" else "$at 기준")
            v.setOnClickPendingIntent(R.id.widget_summary_root, FieldWidgetStore.openAppIntent(c, "summary", 200))
            return v
        }
    }
}

/**
 * 출퇴근 위젯: 오늘 상태 한 줄과 [출근]·[퇴근] 단추.
 * 단추를 누르면 앱이 잠깐 열리면서 근태 화면이 지금 시각으로 한 번 찍는다(앱 쪽이 이미 찍었는지 확인한다).
 * 앱이 마지막으로 넘긴 날짜가 오늘이 아니면(낡은 값) 상태를 믿지 않고 단추를 둘 다 보인다.
 */
class ClockWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val views = build(context)
        for (id in ids) manager.updateAppWidget(id, views)
    }

    companion object {
        fun build(c: Context): RemoteViews {
            val v = RemoteViews(c.packageName, R.layout.widget_clock)
            val s = FieldWidgetStore.clock(c)
            val today = SimpleDateFormat("yyyy-MM-dd", Locale.KOREA).format(Date())
            val fresh = s != null && s.optString("date") == today
            val phase = if (fresh) s!!.optString("phase") else ""
            val text = if (fresh) s!!.optString("text") else "앱을 한 번 열면 오늘 상태가 나옵니다"
            v.setTextViewText(R.id.clock_text, text.ifEmpty { "오늘 출퇴근" })
            val showIn = !fresh || phase == "ready"
            val showOut = !fresh || phase == "working"
            v.setViewVisibility(R.id.clock_btn_in, if (showIn) View.VISIBLE else View.GONE)
            v.setViewVisibility(R.id.clock_btn_out, if (showOut) View.VISIBLE else View.GONE)
            v.setOnClickPendingIntent(R.id.widget_clock_root, FieldWidgetStore.openAppIntent(c, "attendance:open", 300))
            v.setOnClickPendingIntent(R.id.clock_btn_in, FieldWidgetStore.openAppIntent(c, "attendance:in", 301))
            v.setOnClickPendingIntent(R.id.clock_btn_out, FieldWidgetStore.openAppIntent(c, "attendance:out", 302))
            return v
        }
    }
}
