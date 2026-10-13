package com.example.tubing_calculator

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.os.SystemClock
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

// 홈 화면 위젯 세 개("빠른 실행", "오늘 요약", "출퇴근")가 쓰는 자료와 그리는 곳.
// 앱(Dart)이 MethodChannel "field/widget"의 update로 자료를 넘기면 여기에 저장하고 위젯을 다시 그린다.
// 위젯은 통신 없이 이 저장된 자료만 읽는다(발전소처럼 통신이 없어도 뜬다).
// 위젯을 누르면 MainActivity를 "widget_action" 값과 함께 열고, 앱이 그 값을 보고 해당 기능을 연다.
// 출퇴근 위젯의 [출근]·[퇴근] 단추만은 앱을 열지 않고 ClockPunch(ClockPunch.kt)가 바로 기록한다.

/**
 * 가변식 위젯 도우미. 안드로이드 12(API 31) 이상에서는 [small]·[large] 두 모양을 함께 넘기면
 * 위젯 크기를 줄이고 늘릴 때 시스템이 알맞은 모양을 고른다(작게 줄이면 한 줄, 키우면 카드).
 * 그보다 낮은 버전은 큰 모양만 쓴다. 크기는 dp, "이 크기 이상이면 이 모양" 기준이다.
 */
object Adaptive {
    /**
     * 크기 단계는 작게(한 줄) → [mid](제목+한 줄/컴팩트) → 크게(카드) 세 단계다. [mid]가 없으면 두 단계.
     * 시스템은 "위젯이 이 크기 이상이면 이 모양"으로 가장 큰 모양을 고른다.
     */
    fun views(
        c: Context, id: Int, small: RemoteViews, large: RemoteViews, smallDp: SizeF, largeDp: SizeF,
        smallRoot: Int, largeRoot: Int, mid: RemoteViews? = null, midDp: SizeF? = null, midRoot: Int = 0,
        glass: Boolean = false,
    ): RemoteViews {
        // 위젯 하나마다 따로 저장한 설정(WidgetCfg): 배경 투명도, 모양(자동·한 줄·카드).
        // [glass]: 흰 글자 위젯(출퇴근)은 "배경 켬"일 때 어두운 반투명 카드.
        if (WidgetCfg.bgOn(c, id)) {
            val a = WidgetCfg.alpha(c, id)
            val bg = if (glass) WidgetCfg.glassRes(a) else WidgetCfg.bgRes(a)
            small.setInt(smallRoot, "setBackgroundResource", bg)
            large.setInt(largeRoot, "setBackgroundResource", bg)
            mid?.setInt(midRoot, "setBackgroundResource", bg)
        } else {
            small.setInt(smallRoot, "setBackgroundColor", 0)
            large.setInt(largeRoot, "setBackgroundColor", 0)
            mid?.setInt(midRoot, "setBackgroundColor", 0)
        }
        return when (WidgetCfg.mode(c, id)) {
            WidgetCfg.MODE_SMALL -> small
            WidgetCfg.MODE_LARGE -> large
            else -> if (Build.VERSION.SDK_INT >= 31) {
                if (mid != null && midDp != null) {
                    RemoteViews(mapOf(smallDp to small, midDp to mid, largeDp to large))
                } else {
                    RemoteViews(mapOf(smallDp to small, largeDp to large))
                }
            } else {
                large
            }
        }
    }
}

object FieldWidgetStore {
    private const val PREFS = "field_widget_prefs"
    private const val KEY_QUICK = "quick"
    private const val KEY_SUMMARY = "summary"
    private const val KEY_CLOCK = "clock"
    private const val KEY_PT = "pt"
    private const val KEY_SCHED = "sched"

    private fun prefs(c: Context) = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun save(c: Context, quick: String?, summary: String?, clock: String? = null, pt: String? = null, sched: String? = null) {
        val e = prefs(c).edit()
        if (quick != null) e.putString(KEY_QUICK, quick)
        if (summary != null) e.putString(KEY_SUMMARY, summary)
        if (clock != null) e.putString(KEY_CLOCK, clock)
        if (pt != null) e.putString(KEY_PT, pt)
        if (sched != null) e.putString(KEY_SCHED, sched)
        e.apply()
        if (pt != null) PressureTimer.scheduleRefresh(c)
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

    /** 출퇴근 위젯 값: {"date":"yyyy-MM-dd","phase":"ready|working|done|off","text":"...","since":출근 시각 epoch ms} */
    fun clock(c: Context): JSONObject? {
        val raw = prefs(c).getString(KEY_CLOCK, null) ?: return null
        return try {
            JSONObject(raw)
        } catch (e: Exception) {
            null
        }
    }

    /** 압력시험 값: {"phase":"running|ended|idle","line":"...","holdMin":30.0,"startMs":..,"dueMs":..,"endMs":..} */
    fun pt(c: Context): JSONObject? {
        val raw = prefs(c).getString(KEY_PT, null) ?: return null
        return try {
            JSONObject(raw)
        } catch (e: Exception) {
            null
        }
    }

    /** 내 일정 값: {"date":"yyyy-MM-dd","updatedAt":"HH:mm","todayCount":n,"items":[{"d":0|1,"t":"09:30","x":"제목"}]} */
    fun sched(c: Context): JSONObject? {
        val raw = prefs(c).getString(KEY_SCHED, null) ?: return null
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
            for (id in quickIds) mgr.updateAppWidget(id, QuickLaunchWidgetProvider.build(c, id))
        }
        val sumIds = mgr.getAppWidgetIds(ComponentName(c, SummaryWidgetProvider::class.java))
        if (sumIds.isNotEmpty()) {
            for (id in sumIds) mgr.updateAppWidget(id, SummaryWidgetProvider.build(c, id))
        }
        val clockIds = mgr.getAppWidgetIds(ComponentName(c, ClockWidgetProvider::class.java))
        if (clockIds.isNotEmpty()) {
            for (id in clockIds) mgr.updateAppWidget(id, ClockWidgetProvider.build(c, id))
        }
        for (id in mgr.getAppWidgetIds(ComponentName(c, ScheduleWidgetProvider::class.java))) mgr.updateAppWidget(id, ScheduleWidgetProvider.build(c, id))
        // 압력시험 타이머(앱 타이머형)
        for (id in mgr.getAppWidgetIds(ComponentName(c, PressureAppWidgetProvider::class.java))) mgr.updateAppWidget(id, PressureAppWidgetProvider.build(c))
        // 날짜가 바뀌면 다시 그리도록 다음 자정을 예약해 둔다(10-09).
        FieldDaily.scheduleNextDay(c)
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

    /** 앱을 열지 않고 출근·퇴근을 찍는 단추([kind]는 "in" 또는 "out"). */
    fun punchIntent(c: Context, kind: String, code: Int): PendingIntent {
        val i = Intent(c, ClockPunchReceiver::class.java).apply {
            action = "com.example.tubing_calculator.PUNCH_$kind"
            putExtra(ClockPunchReceiver.EXTRA_KIND, kind)
        }
        return PendingIntent.getBroadcast(
            c, code, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    /** [휴게]·[메모] 창(ClockQuickActivity)을 여는 단추. */
    fun quickWindowIntent(c: Context, mode: String, code: Int): PendingIntent {
        val i = Intent(c, ClockQuickActivity::class.java).apply {
            putExtra(ClockQuickActivity.EXTRA_MODE, mode)
            data = Uri.parse("fieldwidget://quick/$mode")
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        return PendingIntent.getActivity(
            c, code, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    fun todayText(): String {
        val now = Date()
        val day = SimpleDateFormat("M월 d일", Locale.KOREA).format(now)
        val wd = SimpleDateFormat("E", Locale.KOREA).format(now)
        return "$day ($wd)"
    }
}

class QuickLaunchWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) manager.updateAppWidget(id, build(context, id))
    }

    override fun onDeleted(context: Context, ids: IntArray) {
        WidgetCfg.clear(context, ids)
    }

    companion object {
        fun build(c: Context, id: Int = 0): RemoteViews {
            val small = QuickSmallWidgetProvider.build(c)
            val large = buildLarge(c)
            val mid = QuickSmallWidgetProvider.build(c, mid = true)
        if (!WidgetCfg.bgOn(c, id)) {
            WidgetCfg.applyPlain(small, intArrayOf(R.id.quick_s_slot_1, R.id.quick_s_slot_2, R.id.quick_s_slot_3), intArrayOf(R.id.quick_s_empty), intArrayOf(), intArrayOf(R.id.quick_s_slot_1, R.id.quick_s_slot_2, R.id.quick_s_slot_3))
            WidgetCfg.applyPlain(mid, intArrayOf(R.id.quick_m_title, R.id.quick_s_slot_1, R.id.quick_s_slot_2, R.id.quick_s_slot_3), intArrayOf(R.id.quick_s_empty), intArrayOf(), intArrayOf(R.id.quick_s_slot_1, R.id.quick_s_slot_2, R.id.quick_s_slot_3))
            WidgetCfg.applyPlain(large, intArrayOf(R.id.widget_quick_title, R.id.quick_slot_1_text, R.id.quick_slot_2_text, R.id.quick_slot_3_text, R.id.quick_slot_4_text), intArrayOf(R.id.widget_quick_empty), intArrayOf(), intArrayOf(R.id.quick_slot_1, R.id.quick_slot_2, R.id.quick_slot_3, R.id.quick_slot_4))
        }
            return Adaptive.views(
                c, id, small, large, SizeF(110f, 40f), SizeF(180f, 150f),
                R.id.widget_quick_s_root, R.id.widget_quick_root, mid, SizeF(150f, 72f), R.id.widget_quick_m_root
            )
        }

        private val SLOTS = intArrayOf(
            R.id.quick_slot_1, R.id.quick_slot_2, R.id.quick_slot_3, R.id.quick_slot_4
        )
        private val TEXTS = intArrayOf(
            R.id.quick_slot_1_text, R.id.quick_slot_2_text, R.id.quick_slot_3_text, R.id.quick_slot_4_text
        )

        fun buildLarge(c: Context): RemoteViews {
            val v = RemoteViews(c.packageName, R.layout.widget_quick)
            val titles = FieldWidgetStore.quickTitles(c).take(SLOTS.size)
            v.setViewVisibility(R.id.widget_quick_empty, if (titles.isEmpty()) View.VISIBLE else View.GONE)
            // 제목·빈 안내를 눌러도 앱은 열린다.
            v.setOnClickPendingIntent(R.id.widget_quick_root, FieldWidgetStore.openAppIntent(c, "open", 100))
            for ((i, slot) in SLOTS.withIndex()) {
                if (i < titles.size) {
                    v.setViewVisibility(slot, View.VISIBLE)
                    v.setTextViewText(TEXTS[i], titles[i])
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
        for (id in ids) manager.updateAppWidget(id, build(context, id))
    }

    override fun onDeleted(context: Context, ids: IntArray) {
        WidgetCfg.clear(context, ids)
    }

    companion object {
        private fun count(o: JSONObject?, key: String): Int? =
            if (o == null || !o.has(key) || o.isNull(key)) null else o.optInt(key, -1).takeIf { it >= 0 }

        /** 한 줄: 점(색)과 값. [n]이 null이면 아직 못 읽음(회색 점, "—"), 0이면 이상 없음(초록), 그 밖에는 주의(노랑). */
        private fun row(v: RemoteViews, dot: Int, value: Int, n: Int?, none: String, some: (Int) -> String) {
            v.setImageViewResource(
                dot,
                when {
                    n == null -> R.drawable.widget_dot_idle
                    n == 0 -> R.drawable.widget_dot_ok
                    else -> R.drawable.widget_dot_warn
                }
            )
            v.setTextViewText(value, if (n == null) "—" else if (n == 0) none else some(n))
        }

        fun build(c: Context, id: Int = 0): RemoteViews {
            val small = SummarySmallWidgetProvider.build(c)
            val large = buildLarge(c)
            val mid = SummarySmallWidgetProvider.build(c, mid = true)
        if (!WidgetCfg.bgOn(c, id)) {
            WidgetCfg.applyPlain(small, intArrayOf(R.id.summary_s_value_schedule, R.id.summary_s_value_reports, R.id.summary_s_value_stock, R.id.summary_s_value_attendance), intArrayOf(R.id.lbl_schedule, R.id.lbl_reports, R.id.lbl_stock, R.id.lbl_attendance), intArrayOf(), intArrayOf(R.id.sum_s_tile_1, R.id.sum_s_tile_2, R.id.sum_s_tile_3, R.id.sum_s_tile_4))
            WidgetCfg.applyPlain(mid, intArrayOf(R.id.summary_m_title, R.id.summary_s_value_schedule, R.id.summary_s_value_reports, R.id.summary_s_value_stock, R.id.summary_s_value_attendance), intArrayOf(R.id.lbl_schedule, R.id.lbl_reports, R.id.lbl_stock, R.id.lbl_attendance), intArrayOf(), intArrayOf(R.id.sum_s_tile_1, R.id.sum_s_tile_2, R.id.sum_s_tile_3, R.id.sum_s_tile_4))
            WidgetCfg.applyPlain(large, intArrayOf(R.id.summary_title, R.id.summary_value_schedule, R.id.summary_value_reports, R.id.summary_value_stock, R.id.summary_value_attendance), intArrayOf(R.id.lbl_schedule, R.id.lbl_reports, R.id.lbl_stock, R.id.lbl_attendance, R.id.summary_updated), intArrayOf(), intArrayOf(R.id.sum_tile_1))
        }
            return Adaptive.views(
                c, id, small, large, SizeF(110f, 40f), SizeF(200f, 130f),
                R.id.widget_summary_s_root, R.id.widget_summary_root, mid, SizeF(150f, 72f), R.id.widget_summary_m_root
            )
        }

        fun buildLarge(c: Context): RemoteViews {
            val v = RemoteViews(c.packageName, R.layout.widget_summary)
            val s = FieldWidgetStore.summary(c)
            val date = s?.optString("date").orEmpty()
            v.setTextViewText(R.id.summary_title, if (date.isEmpty()) "오늘 요약" else "오늘 · $date")
            row(v, R.id.summary_dot_schedule, R.id.summary_value_schedule, count(s, "schedule"), "없음") { "${it}건 남음" }
            row(v, R.id.summary_dot_reports, R.id.summary_value_reports, count(s, "reports"), "다 씀") { "${it}곳 안 씀" }
            row(v, R.id.summary_dot_stock, R.id.summary_value_stock, count(s, "stock"), "이상 없음") { "부족 ${it}건" }
            val att = s?.optString("attendance").orEmpty()
            v.setImageViewResource(
                R.id.summary_dot_attendance,
                if (att.isEmpty()) R.drawable.widget_dot_idle else R.drawable.widget_dot_ok
            )
            v.setTextViewText(R.id.summary_value_attendance, if (att.isEmpty()) "—" else att)
            val at = s?.optString("updatedAt").orEmpty()
            v.setTextViewText(R.id.summary_updated, if (at.isEmpty()) "앱을 한 번 열면 채워집니다" else "$at 기준")
            v.setOnClickPendingIntent(R.id.widget_summary_root, FieldWidgetStore.openAppIntent(c, "summary", 200))
            return v
        }
    }
}

/**
 * 출퇴근 위젯(10-13, 날씨 위젯처럼): 왼쪽 상태 아이콘 · 큰 숫자(근무 중이면 흐르는 시간) · 오른쪽 작은 글
 * (근무 중 "퇴근까지"·"연장" 실시간, 출근 전 지난 퇴근, 퇴근 뒤 휴게)과 지금 해야 할 단추 하나([출근]/[퇴근]).
 * 단추는 앱을 열지 않고 ClockPunch가 바로 기록한다. 위젯을 누르면 휴게·메모·근태 화면을 고르는 작은 창.
 * 그리기는 ClockView, 상태 규칙은 ClockState(ClockState.kt). 놓을 때와 30분마다 서버 기록을 읽어 다시 그린다.
 */
class ClockWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) manager.updateAppWidget(id, build(context, id))
        // 다른 기기에서 찍은 출퇴근·자정을 넘긴 근무도 맞게: 서버(안 되면 폰 사본)를 읽어 다시 그린다.
        val pending = goAsync()
        ClockSync.refresh(context) { pending.finish() }
    }

    override fun onDeleted(context: Context, ids: IntArray) {
        WidgetCfg.clear(context, ids)
    }

    companion object {
        fun build(c: Context, id: Int = 0): RemoteViews {
            val small = RemoteViews(c.packageName, R.layout.widget_clock_small).also { ClockView.fill(c, it, ClockView.SMALL) }
            val mid = RemoteViews(c.packageName, R.layout.widget_clock_compact).also { ClockView.fill(c, it, ClockView.MID) }
            val large = RemoteViews(c.packageName, R.layout.widget_clock).also { ClockView.fill(c, it, ClockView.LARGE) }
            // 글자는 늘 흰색이라 "배경 켬"이어도 흰 카드가 아니라 어두운 반투명 카드(glass)를 쓴다.
            return Adaptive.views(
                c, id, small, large, SizeF(60f, 40f), SizeF(200f, 120f),
                R.id.widget_clock_s_root, R.id.widget_clock_root, mid, SizeF(200f, 66f), R.id.widget_clock_c_root,
                glass = true,
            )
        }
    }
}

/** 오늘 요약 작은 위젯(3x1): 일정·일지·자재·근태를 숫자 하나씩 한 줄로. 누르면 앱이 열린다. */
/** (등록하지 않는다) 가변식 위젯의 작은 모양만 만든다. */
class SummarySmallWidgetProvider {
    companion object {
        private fun count(o: JSONObject?, key: String): Int? =
            if (o == null || !o.has(key) || o.isNull(key)) null else o.optInt(key, -1).takeIf { it >= 0 }

        private fun tile(v: RemoteViews, dot: Int, value: Int, n: Int?) {
            v.setImageViewResource(
                dot,
                when {
                    n == null -> R.drawable.widget_dot_idle
                    n == 0 -> R.drawable.widget_dot_ok
                    else -> R.drawable.widget_dot_warn
                }
            )
            v.setTextViewText(value, if (n == null) "—" else n.toString())
        }

        fun build(c: Context, mid: Boolean = false): RemoteViews {
            val v = RemoteViews(c.packageName, if (mid) R.layout.widget_summary_mid else R.layout.widget_summary_small)
            val s = FieldWidgetStore.summary(c)
            tile(v, R.id.summary_s_dot_schedule, R.id.summary_s_value_schedule, count(s, "schedule"))
            tile(v, R.id.summary_s_dot_reports, R.id.summary_s_value_reports, count(s, "reports"))
            tile(v, R.id.summary_s_dot_stock, R.id.summary_s_value_stock, count(s, "stock"))
            val att = s?.optString("attendance").orEmpty()
            v.setImageViewResource(
                R.id.summary_s_dot_attendance,
                if (att.isEmpty()) R.drawable.widget_dot_idle else R.drawable.widget_dot_ok
            )
            v.setTextViewText(
                R.id.summary_s_value_attendance,
                if (att.isEmpty()) "—" else if (att == "정상근무") "정상" else att
            )
            v.setOnClickPendingIntent(if (mid) R.id.widget_summary_m_root else R.id.widget_summary_s_root, FieldWidgetStore.openAppIntent(c, "summary", 330))
            return v
        }
    }
}

/** 빠른 실행 작은 위젯(3x1): 즐겨찾기 앞의 세 개를 한 줄에. 누르면 그 기능이 열린다. */
/** (등록하지 않는다) 가변식 위젯의 작은 모양만 만든다. */
class QuickSmallWidgetProvider {
    companion object {
        private val SLOTS = intArrayOf(R.id.quick_s_slot_1, R.id.quick_s_slot_2, R.id.quick_s_slot_3)

        fun build(c: Context, mid: Boolean = false): RemoteViews {
            val v = RemoteViews(c.packageName, if (mid) R.layout.widget_quick_mid else R.layout.widget_quick_small)
            val titles = FieldWidgetStore.quickTitles(c).take(SLOTS.size)
            v.setViewVisibility(R.id.quick_s_empty, if (titles.isEmpty()) View.VISIBLE else View.GONE)
            v.setOnClickPendingIntent(if (mid) R.id.widget_quick_m_root else R.id.widget_quick_s_root, FieldWidgetStore.openAppIntent(c, "open", 340))
            for ((i, slot) in SLOTS.withIndex()) {
                if (i < titles.size) {
                    v.setViewVisibility(slot, View.VISIBLE)
                    v.setTextViewText(slot, titles[i])
                    v.setOnClickPendingIntent(slot, FieldWidgetStore.openAppIntent(c, "quick:" + titles[i], 341 + i))
                } else {
                    v.setViewVisibility(slot, View.GONE)
                }
            }
            return v
        }
    }
}
