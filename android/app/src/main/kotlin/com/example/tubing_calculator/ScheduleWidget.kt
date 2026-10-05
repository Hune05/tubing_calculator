package com.example.tubing_calculator

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.util.SizeF
import android.view.View
import android.widget.RemoteViews
import java.util.Calendar
import java.util.Locale

/**
 * "내 일정" 위젯: 오늘·내일 일정(안 끝낸 것)을 시간 순으로 보여 준다.
 * 앱이 모아 넘긴 목록(MethodChannel field/widget의 sched)만 읽는다(통신 없음).
 * 목록을 받은 날짜와 오늘이 다르면 날짜를 밀어서(어제 일정 빼고, 내일 → 오늘) 그린다.
 * 줄이면 다음 일정 한 줄, 키우면 목록. 누르면 앱의 내 일정 화면이 열린다.
 */
internal class SchedLine(val header: Boolean, val time: String, val text: String)

class ScheduleWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) manager.updateAppWidget(id, build(context, id))
    }

    override fun onDeleted(context: Context, ids: IntArray) {
        WidgetCfg.clear(context, ids)
    }

    companion object {
        private const val MAX_ROWS = 7
        private val WEEK = arrayOf("일", "월", "화", "수", "목", "금", "토")

        private fun dayLabel(offset: Int): String {
            val c = Calendar.getInstance()
            c.add(Calendar.DAY_OF_MONTH, offset)
            val base = "${c.get(Calendar.MONTH) + 1}월 ${c.get(Calendar.DAY_OF_MONTH)}일 (${WEEK[c.get(Calendar.DAY_OF_WEEK) - 1]})"
            return when (offset) { 0 -> "오늘 · $base"; 1 -> "내일 · $base"; else -> base }
        }

        private fun todayKey(): String {
            val c = Calendar.getInstance()
            return String.format(Locale.US, "%04d-%02d-%02d", c.get(Calendar.YEAR), c.get(Calendar.MONTH) + 1, c.get(Calendar.DAY_OF_MONTH))
        }

        /** 받은 날짜와 오늘 사이 날 수(받은 날이 오늘이면 0, 못 읽으면 null). */
        private fun daysSince(date: String): Int? {
            val p = date.split("-")
            if (p.size != 3) return null
            return try {
                val a = Calendar.getInstance().apply { clear(); set(p[0].toInt(), p[1].toInt() - 1, p[2].toInt(), 12, 0, 0) }
                val t = Calendar.getInstance().apply { set(Calendar.HOUR_OF_DAY, 12); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0) }
                Math.round((t.timeInMillis - a.timeInMillis) / 86_400_000.0).toInt()
            } catch (e: Exception) {
                null
            }
        }

        /** 보여 줄 줄들과 오늘 남은 일정 수(목록을 아직 못 받았으면 null). */
        private fun lines(c: Context): Pair<List<SchedLine>, Int>? {
            val s = FieldWidgetStore.sched(c) ?: return null
            val shift = daysSince(s.optString("date")) ?: return null
            val arr = s.optJSONArray("items") ?: return Pair(emptyList(), 0)
            val items = ArrayList<Triple<Int, String, String>>()
            for (i in 0 until arr.length()) {
                val o = arr.optJSONObject(i) ?: continue
                val d = o.optInt("d", 0) - shift
                if (d < 0) continue
                items.add(Triple(d, o.optString("t"), o.optString("x")))
            }
            val todayN = items.count { it.first == 0 }
            val out = ArrayList<SchedLine>()
            var lastDay = -1
            for (e in items) {
                if (e.first != lastDay) {
                    out.add(SchedLine(true, "", dayLabel(e.first)))
                    lastDay = e.first
                }
                out.add(SchedLine(false, e.second, e.third))
            }
            return Pair(out, todayN)
        }

        fun build(c: Context, id: Int = 0): RemoteViews {
            val data = lines(c)
            val small = buildSmall(c, data)
            val large = buildLarge(c, data)
            if (!WidgetCfg.bgOn(c, id)) {
                WidgetCfg.applyPlain(small, intArrayOf(R.id.sch_s_count), intArrayOf(R.id.sch_s_next), intArrayOf(), intArrayOf())
                val main = ArrayList<Int>()
                main.add(R.id.sch_title)
                val sub = arrayListOf(R.id.sch_empty, R.id.sch_count)
                WidgetCfg.applyPlain(large, main.toIntArray(), sub.toIntArray(), intArrayOf(), intArrayOf())
                for (r in rowIds) {
                    large.setTextColor(r.second, 0xFF7DE3EA.toInt())
                    large.setTextColor(r.third, 0xFFFFFFFF.toInt())
                }
            }
            return Adaptive.views(
                c, id, small, large, SizeF(180f, 40f), SizeF(180f, 150f),
                R.id.widget_sch_s_root, R.id.widget_sch_root
            )
        }

        // (줄, 시간 칸, 글 칸)
        private val rowIds: List<Triple<Int, Int, Int>> = listOf(
            Triple(R.id.sch_r1, R.id.sch_t1, R.id.sch_x1),
            Triple(R.id.sch_r2, R.id.sch_t2, R.id.sch_x2),
            Triple(R.id.sch_r3, R.id.sch_t3, R.id.sch_x3),
            Triple(R.id.sch_r4, R.id.sch_t4, R.id.sch_x4),
            Triple(R.id.sch_r5, R.id.sch_t5, R.id.sch_x5),
            Triple(R.id.sch_r6, R.id.sch_t6, R.id.sch_x6),
            Triple(R.id.sch_r7, R.id.sch_t7, R.id.sch_x7)
        )

        private fun buildSmall(c: Context, data: Pair<List<SchedLine>, Int>?): RemoteViews {
            val v = RemoteViews(c.packageName, R.layout.widget_schedule_small)
            if (data == null) {
                v.setTextViewText(R.id.sch_s_next, "앱을 한 번 열면 채워집니다")
                v.setTextViewText(R.id.sch_s_count, "")
            } else {
                val next = data.first.firstOrNull { !it.header }
                v.setTextViewText(
                    R.id.sch_s_next,
                    when {
                        next == null -> "오늘·내일 일정이 없습니다"
                        next.time.isEmpty() -> next.text
                        else -> "${next.time} ${next.text}"
                    }
                )
                v.setTextViewText(R.id.sch_s_count, if (data.second == 0) "" else "${data.second}건")
            }
            v.setOnClickPendingIntent(R.id.widget_sch_s_root, FieldWidgetStore.openAppIntent(c, "schedule:open", 376))
            return v
        }

        private fun buildLarge(c: Context, data: Pair<List<SchedLine>, Int>?): RemoteViews {
            val v = RemoteViews(c.packageName, R.layout.widget_schedule)
            var shown = emptyList<SchedLine>()
            var more = 0
            if (data == null) {
                v.setTextViewText(R.id.sch_count, "")
                v.setViewVisibility(R.id.sch_empty, View.VISIBLE)
                v.setTextViewText(R.id.sch_empty, "앱을 한 번 열면 채워집니다")
            } else {
                v.setTextViewText(R.id.sch_count, if (data.second == 0) "오늘 없음" else "오늘 ${data.second}건")
                val all = data.first
                if (all.isEmpty()) {
                    v.setViewVisibility(R.id.sch_empty, View.VISIBLE)
                    v.setTextViewText(R.id.sch_empty, "오늘·내일 일정이 없습니다")
                } else {
                    v.setViewVisibility(R.id.sch_empty, View.GONE)
                    if (all.size > MAX_ROWS) {
                        shown = all.take(MAX_ROWS - 1)
                        more = all.drop(MAX_ROWS - 1).count { !it.header }
                    } else {
                        shown = all
                    }
                }
            }
            for ((i, r) in rowIds.withIndex()) {
                val (row, t, x) = r
                val last = more > 0 && i == shown.size
                if (i < shown.size) {
                    val l = shown[i]
                    v.setViewVisibility(row, View.VISIBLE)
                    if (l.header) {
                        v.setViewVisibility(t, View.GONE)
                        v.setTextViewText(x, l.text)
                        v.setTextColor(x, 0xFF6B7280.toInt())
                        v.setTextViewTextSize(x, android.util.TypedValue.COMPLEX_UNIT_SP, 14f)
                    } else {
                        v.setViewVisibility(t, View.VISIBLE)
                        v.setTextViewText(t, l.time.ifEmpty { "종일" })
                        v.setTextViewText(x, l.text)
                        v.setTextColor(x, 0xFF1F2933.toInt())
                        v.setTextViewTextSize(x, android.util.TypedValue.COMPLEX_UNIT_SP, 18f)
                    }
                } else if (last) {
                    v.setViewVisibility(row, View.VISIBLE)
                    v.setViewVisibility(t, View.GONE)
                    v.setTextViewText(x, "외 ${more}건")
                    v.setTextColor(x, 0xFF6B7280.toInt())
                    v.setTextViewTextSize(x, android.util.TypedValue.COMPLEX_UNIT_SP, 14f)
                } else {
                    v.setViewVisibility(row, View.GONE)
                }
            }
            v.setOnClickPendingIntent(R.id.widget_sch_root, FieldWidgetStore.openAppIntent(c, "schedule:open", 375))
            return v
        }
    }
}
