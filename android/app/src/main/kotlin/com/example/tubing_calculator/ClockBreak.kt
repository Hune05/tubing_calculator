package com.example.tubing_calculator

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * 휴게 알람: "10:00 ~ 10:15"처럼 쉬는 시간대를 정해 두면 시작할 때와 끝날 때 폰이 알려 준다.
 * 출퇴근 위젯의 [휴게] 단추가 여는 창(ClockQuickActivity)에서 정한다.
 * 근태 기록(휴게시간)은 바꾸지 않는다: 근로시간 계산에서 법정 휴게를 대신하면 오히려 틀어질 수 있어서,
 * 이것은 알림과 위젯 칩 표시만 한다. 폰을 껐다 켜면 예약이 사라지므로 다시 켤 때 [rescheduleAll]로
 * 다시 건다(FieldDaily, 10-09).
 */
object ClockBreak {
    const val CHANNEL_ID = "attendance_break_channel"
    private const val PREFS = "field_widget_prefs"
    private const val KEY = "breaks"
    private const val MAX = 6

    class Item(val id: Int, val start: Long, val end: Long)

    private fun prefs(c: Context) = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun fmt(ms: Long): String = SimpleDateFormat("HH:mm", Locale.KOREA).format(Date(ms))

    fun label(i: Item): String = "${fmt(i.start)} ~ ${fmt(i.end)}"

    /** 아직 안 끝난 휴게 알람(시작 순). 지난 것은 정리한다. */
    fun list(c: Context): List<Item> {
        val raw = prefs(c).getString(KEY, null) ?: return emptyList()
        val now = System.currentTimeMillis()
        val out = ArrayList<Item>()
        try {
            val a = JSONArray(raw)
            for (i in 0 until a.length()) {
                val o = a.getJSONObject(i)
                val it = Item(o.getInt("id"), o.getLong("start"), o.getLong("end"))
                if (it.end > now) out.add(it)
            }
        } catch (e: Exception) {
            return emptyList()
        }
        out.sortBy { it.start }
        return out
    }

    private fun save(c: Context, items: List<Item>) {
        val a = JSONArray()
        for (i in items) a.put(JSONObject().put("id", i.id).put("start", i.start).put("end", i.end))
        prefs(c).edit().putString(KEY, a.toString()).apply()
    }

    private fun pending(c: Context, req: Int, kind: String, item: Item?, id: Int): PendingIntent {
        val i = Intent(c, ClockBreakAlarmReceiver::class.java).apply {
            action = "com.example.tubing_calculator.BREAK_$kind"
            putExtra("kind", kind)
            putExtra("id", id)
            if (item != null) {
                putExtra("start", item.start)
                putExtra("end", item.end)
            }
        }
        return PendingIntent.getBroadcast(c, req, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
    }

    private fun setAlarm(c: Context, whenMs: Long, pi: PendingIntent) {
        val am = c.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        // SCHEDULE_EXACT_ALARM은 안드로이드 14부터 기본으로 꺼져 있어 그때는 최대 1시간 늦게 울렸다.
        // 매니페스트의 USE_EXACT_ALARM(자동 허용)으로 정시에 울린다. 알람시계 방식(setAlarmClock)도 같은 권한이 필요하다.
        val exact = Build.VERSION.SDK_INT < 31 || am.canScheduleExactAlarms()
        try {
            if (exact) am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, whenMs, pi)
            else am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, whenMs, pi)
        } catch (e: SecurityException) {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, whenMs, pi)
        }
    }

    /** 휴게 알람을 하나 더한다. 성공하면 null, 안 되면 이유 글. */
    fun add(c: Context, startMs: Long, endMs: Long): String? {
        val now = System.currentTimeMillis()
        if (endMs <= now) return "이미 지난 시간입니다. 지금 이후 시간을 골라 주세요."
        val cur = list(c)
        if (cur.size >= MAX) return "휴게 알람은 최대 ${MAX}개까지입니다. 지난 것을 지워 주세요."
        if (cur.any { startMs < it.end && endMs > it.start }) return "이미 정한 휴게 시간과 겹칩니다."
        val id = (now / 1000 % 1000000).toInt()
        val item = Item(id, startMs, endMs)
        if (startMs > now) setAlarm(c, startMs, pending(c, id * 2, "start", item, id))
        setAlarm(c, endMs, pending(c, id * 2 + 1, "end", item, id))
        save(c, cur + item)
        FieldWidgetStore.refreshAll(c)
        return null
    }

    /** 저장해 둔 남은 휴게 알람을 다시 건다(폰을 다시 켜면 예약이 사라진다). */
    fun rescheduleAll(c: Context) {
        val now = System.currentTimeMillis()
        for (item in list(c)) {
            if (item.start > now) setAlarm(c, item.start, pending(c, item.id * 2, "start", item, item.id))
            setAlarm(c, item.end, pending(c, item.id * 2 + 1, "end", item, item.id))
        }
    }

    fun remove(c: Context, id: Int) {
        val am = c.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(pending(c, id * 2, "start", null, id))
        am.cancel(pending(c, id * 2 + 1, "end", null, id))
        save(c, list(c).filter { it.id != id })
        FieldWidgetStore.refreshAll(c)
    }

    /** 위젯 칩에 보일 글: 지금 쉬는 중이거나 가장 가까운 휴게 "휴게 10:00 ~ 10:15". 없으면 null. */
    fun chipText(c: Context): String? = list(c).firstOrNull()?.let { "휴게 " + label(it) }

    fun notify(c: Context, kind: String, start: Long, end: Long) {
        val nm = c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "휴게 시간 알림", NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "정해 둔 휴게 시간이 시작·끝날 때 알림"
                }
            )
        }
        val isStart = kind == "start"
        val b = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(c, CHANNEL_ID)
        else @Suppress("DEPRECATION") Notification.Builder(c)
        b.setSmallIcon(R.drawable.ic_stat_notify)
            .setContentTitle(if (isStart) "휴게 시작" else "휴게 끝")
            .setContentText(if (isStart) "${fmt(start)} ~ ${fmt(end)}" else "${fmt(end)} 휴게 시간이 끝났습니다.")
            .setAutoCancel(true)
            .setContentIntent(FieldWidgetStore.openAppIntent(c, "attendance:open", 350))
        nm.notify(920000 + (if (isStart) 0 else 1) + (start / 60000 % 1000).toInt() * 2, b.build())
    }
}

class ClockBreakAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        val kind = intent.getStringExtra("kind") ?: return
        ClockBreak.notify(context, kind, intent.getLongExtra("start", 0L), intent.getLongExtra("end", 0L))
        FieldWidgetStore.refreshAll(context)
    }
}
