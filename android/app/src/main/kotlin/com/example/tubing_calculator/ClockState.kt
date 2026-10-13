package com.example.tubing_calculator

import android.content.Context
import android.os.SystemClock
import android.view.View
import android.widget.RemoteViews
import com.google.android.gms.tasks.Tasks
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.Source
import org.json.JSONObject
import java.util.Calendar
import java.util.Locale
import java.util.concurrent.TimeUnit

/**
 * 출퇴근 위젯의 상태(10-13). 앱(attendance_clock.dart의 clockStatus·encodeClockWidgetPayload)과 같은 규칙으로
 * 서버 기록에서 직접 만든다 — 둘을 같이 고칠 것.
 *
 * 예전에는 앱을 열어야만 위젯 값이 바뀌어, 다른 기기에서 찍은 출퇴근·자정을 넘긴 근무·위젯으로 찍은 퇴근의
 * 근무 시간(기본 휴게를 안 뺌)이 틀리게 보였다. 이제 30분마다(위젯 갱신)·자정·소정 퇴근 시각에
 * 서버(안 되면 폰 사본)를 읽어 다시 그린다(ClockSync). 앱이 넘겨 준 설정(기본 휴게·소정 출근·퇴근)은 "opts" 칸에 둔다.
 */
object ClockState {
    const val COLLECTION = "attendance_records"
    val OFF_TYPES = setOf("연차", "월차", "결근")
    private const val OVERNIGHT_START_MIN = 15 * 60
    private const val OVERNIGHT_MAX_MIN = 12 * 60 // 앱 kMaxOvernightMinutes와 같게
    private const val BREAK_LEGAL_AUTO = -1 // 앱 kBreakLegalAuto

    class Rec(val type: String, val checkIn: String?, val checkOut: String?, val breakMin: Int? = null, val memo: String? = null)

    /** 앱 근태 설정: 기본 휴게(-1이면 법정 최소), 소정 출근·퇴근("HH:mm"). */
    class Opts(val defBrk: Int = BREAK_LEGAL_AUTO, val start: String? = null, val end: String? = null) {
        fun toJson(): JSONObject = JSONObject().put("defBrk", defBrk).apply {
            if (start != null) put("start", start)
            if (end != null) put("end", end)
        }

        companion object {
            fun from(o: JSONObject?): Opts = if (o == null) Opts() else Opts(
                o.optInt("defBrk", BREAK_LEGAL_AUTO),
                o.optString("start").ifEmpty { null },
                o.optString("end").ifEmpty { null },
            )
        }
    }

    /** 앱이 마지막으로 넘겨 준 설정. */
    fun opts(c: Context): Opts = Opts.from(FieldWidgetStore.clock(c)?.optJSONObject("opts"))

    fun dateKey(c: Calendar) = String.format(
        Locale.US, "%04d-%02d-%02d", c.get(Calendar.YEAR), c.get(Calendar.MONTH) + 1, c.get(Calendar.DAY_OF_MONTH)
    )

    fun hhmm(c: Calendar) = String.format(Locale.US, "%02d:%02d", c.get(Calendar.HOUR_OF_DAY), c.get(Calendar.MINUTE))

    /** "HH:mm" → 그 날 0시부터 분. 모양이 틀리면 null. */
    fun minutesOf(v: String?): Int? {
        if (v == null) return null
        val p = v.split(":")
        if (p.size != 2) return null
        val h = p[0].toIntOrNull() ?: return null
        val m = p[1].toIntOrNull() ?: return null
        if (h !in 0..23 || m !in 0..59) return null
        return h * 60 + m
    }

    /** 출근~퇴근 사이 분(자정 넘김 처리). 같은 시각이면 null. */
    fun stayMinutes(inT: String?, outT: String?): Int? {
        val a = minutesOf(inT) ?: return null
        val b = minutesOf(outT) ?: return null
        var d = b - a
        if (d == 0) return null
        if (d < 0) d += 24 * 60
        return d
    }

    /** 분 → "8:43". */
    fun hmm(min: Int): String {
        val m = min.coerceAtLeast(0)
        return String.format(Locale.US, "%d:%02d", m / 60, m % 60)
    }

    /** 분 → "1시간 30분". */
    fun minutesText(m: Int): String {
        val h = m / 60
        val r = m % 60
        return if (r == 0) "${h}시간" else if (h == 0) "${r}분" else "${h}시간 ${r}분"
    }

    /** 앱 legalBreakMinutes: 4시간 이상 30분, 8시간 30분 이상 1시간. */
    private fun legalBreak(stay: Int) = if (stay >= 510) 60 else if (stay >= 240) 30 else 0

    /** 앱 breakMinutesFor: 기록에 적은 휴게, 없으면 기본 휴게. */
    fun breakFor(r: Rec, stay: Int, o: Opts): Int =
        (r.breakMin ?: if (o.defBrk == BREAK_LEGAL_AUTO) legalBreak(stay) else o.defBrk).coerceIn(0, stay)

    fun isOpen(r: Rec?): Boolean =
        r != null && r.type !in OFF_TYPES && minutesOf(r.checkIn) != null && r.checkOut == null

    private fun dayStart(c: Calendar) = (c.clone() as Calendar).apply {
        set(Calendar.HOUR_OF_DAY, 0)
        set(Calendar.MINUTE, 0)
        set(Calendar.SECOND, 0)
        set(Calendar.MILLISECOND, 0)
    }

    private fun at(day: Calendar, min: Int) = dayStart(day).apply { add(Calendar.MINUTE, min) }

    /** 앱 lastCheckOutText: 가장 가까운 지난 퇴근 "어제 17:30 퇴근"·"10월 3일 17:30 퇴근"(일주일 안). */
    private fun lastOut(recs: Map<String, Rec>, now: Calendar): String? {
        for (i in 1..7) {
            val d = (now.clone() as Calendar).apply { add(Calendar.DAY_OF_MONTH, -i) }
            val out = recs[dateKey(d)]?.checkOut
            if (out != null && minutesOf(out) != null) {
                val name = if (i == 1) "어제" else "${d.get(Calendar.MONTH) + 1}월 ${d.get(Calendar.DAY_OF_MONTH)}일"
                return "$name $out 퇴근"
            }
        }
        return null
    }

    /** 기록으로 위젯 상태(앱 encodeClockWidgetPayload와 같은 칸)를 만든다. */
    fun build(recs: Map<String, Rec>, now: Calendar, o: Opts): JSONObject {
        val d = dayStart(now)
        val y = (d.clone() as Calendar).apply { add(Calendar.DAY_OF_MONTH, -1) }
        val t = recs[dateKey(d)]
        val yr = recs[dateKey(y)]
        val out = JSONObject().put("date", dateKey(d)).put("opts", o.toJson())

        fun working(r: Rec, start: Calendar, sub: String): JSONObject {
            out.put("phase", "working").put("big", "").put("sub", sub).put("since", start.timeInMillis)
            if (r.breakMin != null) out.put("brk", r.breakMin)
            if (!r.memo.isNullOrBlank()) out.put("memo", r.memo.trim())
            return out
        }

        // 오늘 출근을 이미 찍었으면 오늘이 먼저다. 어제 오후 3시 이후 출근해 12시간 안이면 밤샘 근무 중.
        val todayStarted = minutesOf(t?.checkIn) != null
        var yOpen = false
        if (isOpen(yr) && !todayStarted) {
            yOpen = true
            val m = minutesOf(yr!!.checkIn)!!
            val start = at(y, m)
            val elapsed = (now.timeInMillis - start.timeInMillis) / 60000
            if (m >= OVERNIGHT_START_MIN && elapsed in 0..OVERNIGHT_MAX_MIN.toLong()) {
                return working(yr, start, "${yr.checkIn} 출근 (어제)")
            }
        }
        if (t != null && t.type in OFF_TYPES) {
            return out.put("phase", "off").put("big", "쉬는 날").put("sub", "오늘은 ${t.type}입니다")
        }
        val inM = minutesOf(t?.checkIn)
        if (t == null || inM == null) {
            out.put("phase", "ready").put("big", "출근 전").put(
                "sub",
                when {
                    yOpen -> "어제 퇴근을 안 찍었습니다"
                    minutesOf(o.start) != null -> "소정 ${o.start} 출근"
                    else -> "오늘 출근 전"
                }
            )
            lastOut(recs, now)?.let { out.put("last", it) }
            return out
        }
        if (t.checkOut == null) return working(t, at(d, inM), "${t.checkIn} 출근")
        val stay = stayMinutes(t.checkIn, t.checkOut)
        out.put("phase", "done").put("sub", "${t.checkIn} ~ ${t.checkOut}")
        if (stay == null) {
            out.put("big", "--:--")
        } else {
            val brk = breakFor(t, stay, o)
            out.put("big", hmm(stay - brk)).put("brkUsed", brk)
        }
        if (t.breakMin != null) out.put("brk", t.breakMin)
        if (!t.memo.isNullOrBlank()) out.put("memo", t.memo.trim())
        return out
    }
}

/** 서버 기록을 읽어 출퇴근 위젯을 다시 그린다(앱을 열지 않아도 다른 기기에서 찍은 것이 보이게). */
object ClockSync {
    private const val MIN_GAP_MS = 60_000L

    @Volatile
    private var lastRun = 0L

    /** 뒤에서 읽고 다시 그린다. 1분 안에 또 부르면 건너뛴다. 끝나면 [done]. */
    fun refresh(c: Context, done: (() -> Unit)? = null) {
        val now = System.currentTimeMillis()
        if (now - lastRun < MIN_GAP_MS) {
            done?.invoke()
            return
        }
        lastRun = now
        val app = c.applicationContext
        Thread {
            try {
                refreshNow(app)
            } catch (e: Exception) {
                // 못 읽으면 그대로 둔다(통신 없음·로그인 전).
            } finally {
                done?.invoke()
            }
        }.start()
    }

    /** 지금 읽어 다시 그린다(화면 스레드에서 부르지 말 것). 로그인 전이거나 못 읽으면 false. */
    fun refreshNow(c: Context): Boolean {
        val uid = FirebaseAuth.getInstance().currentUser?.uid ?: return false
        val now = Calendar.getInstance()
        val recs = load(uid, now) ?: return false
        save(c, ClockState.build(recs, now, ClockState.opts(c)))
        return true
    }

    /** 일주일 전부터 오늘까지의 기록(지난 퇴근 줄까지). 서버 → 안 되면 폰 사본. 둘 다 안 되면 null. */
    fun load(uid: String, now: Calendar): MutableMap<String, ClockState.Rec>? {
        val from = (now.clone() as Calendar).apply { add(Calendar.DAY_OF_MONTH, -7) }
        val q = FirebaseFirestore.getInstance().collection(ClockState.COLLECTION)
            .whereEqualTo("uid", uid)
            .whereGreaterThanOrEqualTo("date", ClockState.dateKey(from))
            .whereLessThanOrEqualTo("date", ClockState.dateKey(now))
        val snap = try {
            Tasks.await(q.get(Source.SERVER), 5, TimeUnit.SECONDS)
        } catch (e: Exception) {
            try {
                Tasks.await(q.get(Source.CACHE), 3, TimeUnit.SECONDS)
            } catch (e2: Exception) {
                return null
            }
        }
        val out = HashMap<String, ClockState.Rec>()
        for (d in snap.documents) {
            val date = d.getString("date") ?: continue
            out[date] = ClockState.Rec(
                d.getString("type") ?: "정상근무", d.getString("checkIn"), d.getString("checkOut"),
                d.getLong("breakMin")?.toInt(), d.getString("memo")?.takeIf { it.isNotBlank() }
            )
        }
        return out
    }

    /** 상태를 저장하고 위젯을 다시 그린다. */
    fun save(c: Context, state: JSONObject) {
        FieldWidgetStore.save(c, null, null, state.toString())
        FieldWidgetStore.refreshAll(c)
    }
}

/** 출퇴근 위젯 그리기(날씨 위젯처럼: 아이콘 · 큰 숫자와 아랫줄 · 오른쪽 작은 글과 단추 하나). */
object ClockView {
    const val SMALL = 0
    const val MID = 1
    const val LARGE = 2

    /**
     * 저장된 상태를 오늘 기준으로 본다. 날짜가 지났으면 null(출근 전으로 그리고, 위젯 갱신 때 서버에서 다시 읽는다).
     * 밤샘 근무 중(오후 3시 이후 출근, 12시간 안)은 날짜가 지나도 그대로 근무 중.
     */
    fun current(c: Context): JSONObject? {
        val s = FieldWidgetStore.clock(c) ?: return null
        val now = Calendar.getInstance()
        if (s.optString("date") == ClockState.dateKey(now)) return s
        if (s.optString("phase") == "working") {
            val since = s.optLong("since", 0L)
            if (since > 0L) {
                val start = Calendar.getInstance().apply { timeInMillis = since }
                val m = start.get(Calendar.HOUR_OF_DAY) * 60 + start.get(Calendar.MINUTE)
                val elapsed = (now.timeInMillis - since) / 60000
                if (m >= 15 * 60 && elapsed in 0..(12 * 60).toLong()) return s
            }
        }
        return null
    }

    /** 근무 중일 때 소정 퇴근 시각(epoch ms). 출근보다 뒤가 아니면(밤샘 등) null. */
    fun endMs(s: JSONObject): Long? {
        val since = s.optLong("since", 0L)
        val end = ClockState.minutesOf(s.optJSONObject("opts")?.optString("end")) ?: return null
        if (since <= 0L) return null
        val day = Calendar.getInstance().apply { timeInMillis = since }
        val at = (day.clone() as Calendar).apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            add(Calendar.MINUTE, end)
        }.timeInMillis
        return if (at > since) at else null
    }

    fun fill(c: Context, v: RemoteViews, kind: Int) {
        val s = current(c)
        val phase = s?.optString("phase")?.ifEmpty { null } ?: "ready"
        val working = phase == "working"

        // 상태 아이콘: 출근 전 회색 시계 · 근무 중 초록 · 퇴근 파랑 체크 · 쉬는 날 주황
        val (circle, icon) = when (phase) {
            "working" -> R.drawable.widget_circle_green to R.drawable.ic_widget_play
            "done" -> R.drawable.widget_circle_blue to R.drawable.ic_widget_check
            "off" -> R.drawable.widget_circle_orange to R.drawable.ic_widget_cup
            else -> R.drawable.widget_circle_grey to R.drawable.ic_widget_clock
        }
        v.setInt(R.id.clock_icon_bg, "setBackgroundResource", circle)
        v.setImageViewResource(R.id.clock_icon, icon)

        // 큰 숫자: 근무 중이면 출근 뒤 흐른 시간(위젯이 스스로 센다), 아니면 글
        val since = s?.optLong("since", 0L) ?: 0L
        val now = System.currentTimeMillis()
        if (working && since > 0L) {
            v.setViewVisibility(R.id.clock_timer, View.VISIBLE)
            v.setViewVisibility(R.id.clock_big, View.GONE)
            v.setChronometer(R.id.clock_timer, SystemClock.elapsedRealtime() - (now - since).coerceAtLeast(0L), null, true)
        } else {
            v.setViewVisibility(R.id.clock_timer, View.GONE)
            v.setViewVisibility(R.id.clock_big, View.VISIBLE)
            v.setChronometer(R.id.clock_timer, SystemClock.elapsedRealtime(), null, false)
            v.setTextViewText(R.id.clock_big, s?.optString("big")?.ifEmpty { null } ?: "출근 전")
        }
        v.setTextViewText(R.id.clock_sub, s?.optString("sub")?.ifEmpty { null } ?: "오늘 출근 전")

        val root = when (kind) {
            SMALL -> R.id.widget_clock_s_root
            MID -> R.id.widget_clock_c_root
            else -> R.id.widget_clock_root
        }
        // 위젯을 누르면 휴게·메모·근태 화면을 고르는 작은 창
        v.setOnClickPendingIntent(root, FieldWidgetStore.quickWindowIntent(c, ClockQuickActivity.MODE_MENU, 300))

        val showIn = phase == "ready"
        if (kind == SMALL) {
            v.setViewVisibility(R.id.clock_btn_icon, if (showIn || working) View.VISIBLE else View.GONE)
            v.setInt(R.id.clock_btn_icon, "setBackgroundResource", if (working) R.drawable.widget_circle_red else R.drawable.widget_circle_green)
            v.setImageViewResource(R.id.clock_btn_icon, if (working) R.drawable.ic_widget_stop else R.drawable.ic_widget_play)
            v.setOnClickPendingIntent(R.id.clock_btn_icon, FieldWidgetStore.punchIntent(c, if (working) "out" else "in", if (working) 322 else 321))
            return
        }

        // 오른쪽 위 작은 글: 출근 전 지난 퇴근 · 근무 중 퇴근까지(지나면 연장) 실시간 · 퇴근 뒤 휴게
        var info = ""
        var timer = false
        when (phase) {
            "ready" -> info = s?.optString("last").orEmpty()
            "working" -> {
                val end = s?.let { endMs(it) }
                if (end != null) {
                    timer = true
                    if (now < end) {
                        v.setChronometer(R.id.clock_info_timer, SystemClock.elapsedRealtime() + (end - now), "퇴근까지 %s", true)
                        v.setChronometerCountDown(R.id.clock_info_timer, true)
                        FieldDaily.scheduleClockEnd(c, end)
                    } else {
                        v.setChronometer(R.id.clock_info_timer, SystemClock.elapsedRealtime() - (now - end), "연장 %s", true)
                        v.setChronometerCountDown(R.id.clock_info_timer, false)
                    }
                } else if (s?.has("brk") == true) {
                    info = "휴게 " + brkText(s.optInt("brk"))
                }
            }
            "done" -> if (s?.has("brkUsed") == true) info = "휴게 " + brkText(s.optInt("brkUsed"))
        }
        if (!timer) v.setChronometer(R.id.clock_info_timer, SystemClock.elapsedRealtime(), null, false)
        v.setViewVisibility(R.id.clock_info_timer, if (timer) View.VISIBLE else View.GONE)
        v.setViewVisibility(R.id.clock_info, if (!timer && info.isNotEmpty()) View.VISIBLE else View.GONE)
        v.setTextViewText(R.id.clock_info, info)

        // 오른쪽 아래: 지금 해야 할 단추 하나(출근 전 [출근], 근무 중 [퇴근]), 퇴근 뒤엔 "오늘 근무 끝"
        v.setViewVisibility(R.id.clock_btn, if (showIn || working) View.VISIBLE else View.GONE)
        v.setTextViewText(R.id.clock_btn, if (working) "■ 퇴근" else "▶ 출근")
        v.setInt(R.id.clock_btn, "setBackgroundResource", if (working) R.drawable.widget_pill_red else R.drawable.widget_pill_green)
        v.setOnClickPendingIntent(R.id.clock_btn, FieldWidgetStore.punchIntent(c, if (working) "out" else "in", if (working) 302 else 301))
        v.setViewVisibility(R.id.clock_note, if (phase == "done") View.VISIBLE else View.GONE)
        v.setTextViewText(R.id.clock_note, "오늘 근무 끝")

        if (kind == LARGE) {
            val brk = if (working) ClockBreak.chipText(c) else null
            v.setViewVisibility(R.id.clock_brk_line, if (brk != null) View.VISIBLE else View.GONE)
            if (brk != null) v.setTextViewText(R.id.clock_brk_line, brk)
            val memo = if (working || phase == "done") s?.optString("memo").orEmpty() else ""
            v.setViewVisibility(R.id.clock_memo, if (memo.isNotBlank()) View.VISIBLE else View.GONE)
            v.setTextViewText(R.id.clock_memo, memo)
        }
    }

    private fun brkText(m: Int) = if (m <= 0) "없음" else ClockState.minutesText(m)
}
