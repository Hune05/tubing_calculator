package com.example.tubing_calculator

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.graphics.drawable.Icon
import android.os.Build
import org.json.JSONObject
import java.util.Calendar

/**
 * 퇴근 깜빡 알림(소정 퇴근 시각 30분 뒤에도 퇴근을 안 찍었을 때)을 안드로이드가 직접 예약한다.
 *
 * 앱(Dart)이 근태를 고칠 때는 MethodChannel "field/widget"의 clockOutReminder로 시각을 정해 주고(없으면 취소),
 * 위젯 단추(ClockPunch)로 출근했을 때는 앱이 꺼져 있어도 여기서 설정을 읽어 스스로 예약한다.
 * 설정(알림 켬·소정 퇴근 시각)은 앱이 SharedPreferences에 쓴 값(FlutterSharedPreferences, 키 앞에 "flutter.")을 읽는다.
 * 알림이 울릴 때 위젯 상태가 "근무 중"이 아니면(그 사이 퇴근을 찍음) 울리지 않는다.
 * 알림에는 [퇴근 찍기] 단추가 있어 앱을 열지 않고 바로 찍을 수 있다. 폰을 껐다 켜면 예약은 사라지고 앱을 열면 다시 잡힌다.
 */
object ClockReminder {
    const val CHANNEL_ID = "attendance_clock_out_channel"
    const val NOTIF_ID = 918500
    private const val REQUEST = 918501
    private const val DELAY_MIN = 30

    private fun alarmIntent(c: Context): PendingIntent {
        val i = Intent(c, ClockOutAlarmReceiver::class.java).apply {
            action = "com.example.tubing_calculator.CLOCK_OUT_REMINDER"
        }
        return PendingIntent.getBroadcast(
            c, REQUEST, i, PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
    }

    fun schedule(c: Context, whenMs: Long) {
        if (whenMs <= System.currentTimeMillis()) {
            cancel(c)
            return
        }
        val am = c.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val pi = alarmIntent(c)
        val exact = Build.VERSION.SDK_INT < 31 || am.canScheduleExactAlarms()
        try {
            if (exact) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, whenMs, pi)
            } else {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, whenMs, pi)
            }
        } catch (e: SecurityException) {
            am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, whenMs, pi)
        }
    }

    /** 예약과 떠 있는 알림을 모두 지운다. */
    fun cancel(c: Context) {
        val am = c.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        am.cancel(alarmIntent(c))
        (c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(NOTIF_ID)
    }

    /** 위젯으로 출근했을 때: 앱이 저장해 둔 설정을 읽어 알림이 켜져 있고 소정 퇴근 시각이 있으면 예약한다. */
    fun scheduleFromSettings(c: Context) {
        val p = c.getSharedPreferences("FlutterSharedPreferences", Context.MODE_PRIVATE)
        val enabled = try {
            p.getBoolean("flutter.attendance_clockout_reminder", false)
        } catch (e: ClassCastException) {
            false
        }
        val end = try {
            p.getString("flutter.attendance_work_end", null)
        } catch (e: ClassCastException) {
            null
        }
        if (!enabled || end == null) return
        val parts = end.split(":")
        val h = parts.getOrNull(0)?.toIntOrNull() ?: return
        val m = parts.getOrNull(1)?.toIntOrNull() ?: return
        if (h !in 0..23 || m !in 0..59) return
        val at = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, h)
            set(Calendar.MINUTE, m)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            add(Calendar.MINUTE, DELAY_MIN)
        }.timeInMillis
        if (at > System.currentTimeMillis()) schedule(c, at)
    }

    /** 알림을 띄운다(알람 시각에 받는 쪽이 부른다). */
    fun show(c: Context) {
        val nm = c.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL_ID, "퇴근 시각 알림", NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "소정 퇴근 시각이 지났는데 퇴근을 안 찍었을 때 알림"
                }
            )
        }
        val open = FieldWidgetStore.openAppIntent(c, "attendance:open", 310)
        val punchOut = FieldWidgetStore.punchIntent(c, "out", 311)
        val b = if (Build.VERSION.SDK_INT >= 26) {
            Notification.Builder(c, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(c)
        }
        b.setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("퇴근 시각이 지났습니다")
            .setContentText("퇴근을 아직 안 찍었습니다. 눌러서 퇴근을 찍으십시오.")
            .setContentIntent(open)
            .setAutoCancel(true)
        val action = Notification.Action.Builder(
            Icon.createWithResource(c, R.drawable.ic_widget_logout), "퇴근 찍기", punchOut
        ).build()
        b.addAction(action)
        nm.notify(NOTIF_ID, b.build())
    }

    /** 위젯 상태가 "오늘 근무 중"인가(알림이 울릴 때 이미 퇴근했는지 확인). */
    fun stillWorking(c: Context): Boolean {
        val s: JSONObject = FieldWidgetStore.clock(c) ?: return false
        return s.optString("phase") == "working"
    }
}

class ClockOutAlarmReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (ClockReminder.stillWorking(context)) ClockReminder.show(context)
    }
}
