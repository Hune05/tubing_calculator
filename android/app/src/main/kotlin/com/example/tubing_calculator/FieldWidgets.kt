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
    fun views(
        c: Context, id: Int, small: RemoteViews, large: RemoteViews, smallDp: SizeF, largeDp: SizeF,
        smallRoot: Int, largeRoot: Int
    ): RemoteViews {
        // 위젯 하나마다 따로 저장한 설정(WidgetCfg): 배경 투명도, 모양(자동·한 줄·카드).
        if (WidgetCfg.bgOn(c, id)) {
            val bg = WidgetCfg.bgRes(WidgetCfg.alpha(c, id))
            small.setInt(smallRoot, "setBackgroundResource", bg)
            large.setInt(largeRoot, "setBackgroundResource", bg)
        } else {
            small.setInt(smallRoot, "setBackgroundColor", 0)
            large.setInt(largeRoot, "setBackgroundColor", 0)
        }
        return when (WidgetCfg.mode(c, id)) {
            WidgetCfg.MODE_SMALL -> small
            WidgetCfg.MODE_LARGE -> large
            else -> if (Build.VERSION.SDK_INT >= 31) {
                RemoteViews(mapOf(smallDp to small, largeDp to large))
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

    /** 출퇴근 위젯 값: {"date":"yyyy-MM-dd","phase":"ready|working|done|off","text":"...","since":출근 시각 epoch ms} */
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
        if (!WidgetCfg.bgOn(c, id)) {
            WidgetCfg.applyPlain(small, intArrayOf(R.id.quick_s_slot_1, R.id.quick_s_slot_2, R.id.quick_s_slot_3), intArrayOf(R.id.quick_s_empty), intArrayOf(), intArrayOf(R.id.quick_s_slot_1, R.id.quick_s_slot_2, R.id.quick_s_slot_3))
            WidgetCfg.applyPlain(large, intArrayOf(R.id.widget_quick_title, R.id.quick_slot_1_text, R.id.quick_slot_2_text, R.id.quick_slot_3_text, R.id.quick_slot_4_text), intArrayOf(R.id.widget_quick_empty), intArrayOf(), intArrayOf(R.id.quick_slot_1, R.id.quick_slot_2, R.id.quick_slot_3, R.id.quick_slot_4))
        }
            return Adaptive.views(
                c, id, small, large, SizeF(180f, 40f), SizeF(180f, 130f),
                R.id.widget_quick_s_root, R.id.widget_quick_root
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
        if (!WidgetCfg.bgOn(c, id)) {
            WidgetCfg.applyPlain(small, intArrayOf(R.id.summary_s_value_schedule, R.id.summary_s_value_reports, R.id.summary_s_value_stock, R.id.summary_s_value_attendance), intArrayOf(R.id.lbl_schedule, R.id.lbl_reports, R.id.lbl_stock, R.id.lbl_attendance), intArrayOf(), intArrayOf(R.id.sum_s_tile_1, R.id.sum_s_tile_2, R.id.sum_s_tile_3, R.id.sum_s_tile_4))
            WidgetCfg.applyPlain(large, intArrayOf(R.id.summary_title, R.id.summary_value_schedule, R.id.summary_value_reports, R.id.summary_value_stock, R.id.summary_value_attendance), intArrayOf(R.id.lbl_schedule, R.id.lbl_reports, R.id.lbl_stock, R.id.lbl_attendance, R.id.summary_updated), intArrayOf(), intArrayOf(R.id.sum_tile_1))
        }
            return Adaptive.views(
                c, id, small, large, SizeF(180f, 40f), SizeF(180f, 110f),
                R.id.widget_summary_s_root, R.id.widget_summary_root
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
 * 출퇴근 위젯: 출근 전에는 큰 시간(00:00)과 [시작] 단추 하나, 출근하면 흐르는 시간과 단추 셋
 * ([퇴근]=정지, [휴게], [메모])으로 늘어난다. 단추는 앱을 열지 않는다:
 * 시작·정지는 ClockPunch가 바로 기록하고, 휴게·메모는 위에서 내려오는 작은 창(ClockQuickActivity)에서 고른다.
 * 앱이 마지막으로 넘긴 날짜가 오늘이 아니면(낡은 값) 상태를 믿지 않고 시작 단추만 보인다.
 */
class ClockWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) manager.updateAppWidget(id, build(context, id))
    }

    override fun onDeleted(context: Context, ids: IntArray) {
        WidgetCfg.clear(context, ids)
    }

    companion object {
        fun build(c: Context, id: Int = 0): RemoteViews {
            val small = ClockSmallWidgetProvider.build(c)
            val large = buildLarge(c)
            if (!WidgetCfg.bgOn(c, id)) {
                WidgetCfg.applyPlain(small, intArrayOf(R.id.clock_s_text, R.id.clock_s_timer), intArrayOf(R.id.clock_s_sub), intArrayOf(), intArrayOf())
                WidgetCfg.applyPlain(large, intArrayOf(R.id.clock_big, R.id.clock_timer), intArrayOf(R.id.clock_sub), intArrayOf(), intArrayOf())
                // 배경이 없을 때 색 동그라미가 떠 보이지 않게 반투명 흰 테두리 동그라미로 바꾼다.
                for (b in intArrayOf(R.id.clock_s_btn_in, R.id.clock_s_btn_out)) small.setInt(b, "setBackgroundResource", R.drawable.widget_circle_plain)
                for (b in intArrayOf(R.id.clock_btn_in, R.id.clock_btn_out, R.id.clock_btn_break, R.id.clock_btn_memo)) large.setInt(b, "setBackgroundResource", R.drawable.widget_circle_plain)
            }
            return Adaptive.views(
                c, id, small, large, SizeF(110f, 40f), SizeF(180f, 110f),
                R.id.widget_clock_s_root, R.id.widget_clock_root
            )
        }

        fun buildLarge(c: Context): RemoteViews {
            val v = RemoteViews(c.packageName, R.layout.widget_clock)
            val s = FieldWidgetStore.clock(c)
            val today = SimpleDateFormat("yyyy-MM-dd", Locale.KOREA).format(Date())
            val fresh = s != null && s.optString("date") == today
            val phase = if (fresh) s!!.optString("phase") else ""
            val working = phase == "working"

            // 큰 글: 근무 중이면 출근 뒤 흐른 시간(위젯이 스스로 센다), 아니면 00:00·근무 시간 같은 글
            val since = if (fresh) s!!.optLong("since", 0L) else 0L
            if (working && since > 0L) {
                val elapsed = (System.currentTimeMillis() - since).coerceAtLeast(0L)
                v.setViewVisibility(R.id.clock_timer, View.VISIBLE)
                v.setViewVisibility(R.id.clock_big, View.GONE)
                v.setChronometer(R.id.clock_timer, SystemClock.elapsedRealtime() - elapsed, null, true)
            } else {
                v.setViewVisibility(R.id.clock_timer, View.GONE)
                v.setViewVisibility(R.id.clock_big, View.VISIBLE)
                v.setChronometer(R.id.clock_timer, SystemClock.elapsedRealtime(), null, false)
                val big = if (fresh) s!!.optString("big") else ""
                v.setTextViewText(R.id.clock_big, big.ifEmpty { "00:00" })
            }
            v.setTextViewText(
                R.id.clock_sub,
                if (fresh) s!!.optString("sub").ifEmpty { s.optString("text") } else "앱을 열면 오늘 상태가 나옵니다"
            )

            // 단추: 출근 전(또는 낡은 값)은 시작만, 근무 중은 정지·휴게·메모, 퇴근했거나 쉬는 날은 없음
            val showIn = !fresh || phase == "ready"
            v.setViewVisibility(R.id.clock_btn_in, if (showIn) View.VISIBLE else View.GONE)
            v.setViewVisibility(R.id.clock_btn_out, if (working) View.VISIBLE else View.GONE)
            v.setViewVisibility(R.id.clock_btn_break, if (working) View.VISIBLE else View.GONE)
            v.setViewVisibility(R.id.clock_btn_memo, if (working) View.VISIBLE else View.GONE)

            // 아래 칩: 휴게시간·메모(근무 중이거나 퇴근한 뒤)
            val brkText = ClockBreak.chipText(c)
            val memo = if (fresh) s!!.optString("memo") else ""
            val showBrk = working && brkText != null
            val showMemo = (working || phase == "done") && memo.isNotBlank()
            v.setViewVisibility(R.id.clock_chips, if (showBrk || showMemo) View.VISIBLE else View.GONE)
            v.setViewVisibility(R.id.clock_chip_break, if (showBrk) View.VISIBLE else View.GONE)
            v.setViewVisibility(R.id.clock_chip_memo, if (showMemo) View.VISIBLE else View.GONE)
            if (showBrk) v.setTextViewText(R.id.clock_chip_break, brkText)
            if (showMemo) v.setTextViewText(R.id.clock_chip_memo, memo)

            v.setOnClickPendingIntent(R.id.widget_clock_root, FieldWidgetStore.openAppIntent(c, "attendance:open", 300))
            v.setOnClickPendingIntent(R.id.clock_btn_in, FieldWidgetStore.punchIntent(c, "in", 301))
            v.setOnClickPendingIntent(R.id.clock_btn_out, FieldWidgetStore.punchIntent(c, "out", 302))
            v.setOnClickPendingIntent(R.id.clock_btn_break, FieldWidgetStore.quickWindowIntent(c, ClockQuickActivity.MODE_BREAK, 303))
            v.setOnClickPendingIntent(R.id.clock_btn_memo, FieldWidgetStore.quickWindowIntent(c, ClockQuickActivity.MODE_MEMO, 304))
            return v
        }
    }
}

/**
 * 출퇴근 작은 위젯(한 줄): 출근 전이면 상태 글과 [시작], 근무 중이면 흐르는 시간과 [정지]만 보인다.
 * 휴게·메모는 큰 모양에서만 쓴다. 단추는 앱을 열지 않고 바로 기록한다(ClockPunch).
 */
class ClockSmallWidgetProvider {
    companion object {
        fun build(c: Context): RemoteViews {
            val v = RemoteViews(c.packageName, R.layout.widget_clock_small)
            val s = FieldWidgetStore.clock(c)
            val today = SimpleDateFormat("yyyy-MM-dd", Locale.KOREA).format(Date())
            val fresh = s != null && s.optString("date") == today
            val phase = if (fresh) s!!.optString("phase") else ""
            val working = phase == "working"

            val since = if (fresh) s!!.optLong("since", 0L) else 0L
            if (working && since > 0L) {
                val elapsed = (System.currentTimeMillis() - since).coerceAtLeast(0L)
                v.setViewVisibility(R.id.clock_s_timer, View.VISIBLE)
                v.setViewVisibility(R.id.clock_s_text, View.GONE)
                v.setChronometer(R.id.clock_s_timer, SystemClock.elapsedRealtime() - elapsed, null, true)
            } else {
                v.setViewVisibility(R.id.clock_s_timer, View.GONE)
                v.setViewVisibility(R.id.clock_s_text, View.VISIBLE)
                v.setChronometer(R.id.clock_s_timer, SystemClock.elapsedRealtime(), null, false)
                val big = if (fresh) s!!.optString("big") else ""
                v.setTextViewText(R.id.clock_s_text, big.ifEmpty { "00:00" })
            }
            v.setTextViewText(
                R.id.clock_s_sub,
                if (fresh) s!!.optString("sub").ifEmpty { s.optString("text") } else "앱을 열면 상태가 나옵니다"
            )
            val showIn = !fresh || phase == "ready"
            v.setViewVisibility(R.id.clock_s_btn_in, if (showIn) View.VISIBLE else View.GONE)
            v.setViewVisibility(R.id.clock_s_btn_out, if (working) View.VISIBLE else View.GONE)
            v.setOnClickPendingIntent(R.id.widget_clock_s_root, FieldWidgetStore.openAppIntent(c, "attendance:open", 320))
            v.setOnClickPendingIntent(R.id.clock_s_btn_in, FieldWidgetStore.punchIntent(c, "in", 321))
            v.setOnClickPendingIntent(R.id.clock_s_btn_out, FieldWidgetStore.punchIntent(c, "out", 322))
            return v
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

        fun build(c: Context): RemoteViews {
            val v = RemoteViews(c.packageName, R.layout.widget_summary_small)
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
            v.setOnClickPendingIntent(R.id.widget_summary_s_root, FieldWidgetStore.openAppIntent(c, "summary", 330))
            return v
        }
    }
}

/** 빠른 실행 작은 위젯(3x1): 즐겨찾기 앞의 세 개를 한 줄에. 누르면 그 기능이 열린다. */
/** (등록하지 않는다) 가변식 위젯의 작은 모양만 만든다. */
class QuickSmallWidgetProvider {
    companion object {
        private val SLOTS = intArrayOf(R.id.quick_s_slot_1, R.id.quick_s_slot_2, R.id.quick_s_slot_3)

        fun build(c: Context): RemoteViews {
            val v = RemoteViews(c.packageName, R.layout.widget_quick_small)
            val titles = FieldWidgetStore.quickTitles(c).take(SLOTS.size)
            v.setViewVisibility(R.id.quick_s_empty, if (titles.isEmpty()) View.VISIBLE else View.GONE)
            v.setOnClickPendingIntent(R.id.widget_quick_s_root, FieldWidgetStore.openAppIntent(c, "open", 340))
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
