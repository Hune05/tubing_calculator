package com.example.tubing_calculator

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import java.util.Calendar

/**
 * 폰을 다시 켰을 때·앱을 새로 깔았을 때·시계를 바꿨을 때, 그리고 날짜가 바뀔 때(자정) 할 일.
 *
 * 10-09: 앱이 직접 잡는 휴게 알람·퇴근 알림은 폰을 다시 켜면 사라지는데 다시 잡는 곳이 없어서,
 * 위젯 칩에는 "휴게 10:00~10:15"가 보이는데 알람은 울리지 않았다. 홈 위젯(출퇴근·오늘 요약)도
 * 저절로 다시 그려지지 않아, 어제 퇴근을 찍으면 오늘 아침 [시작] 단추가 없고 요약은 어제 개수였다.
 */
object FieldDaily {
    private const val REQ_DAY = 930001

    /** 다음 자정 조금 뒤에 위젯을 다시 그리게 한다(같은 예약은 덮어쓴다). */
    fun scheduleNextDay(c: Context) {
        val am = c.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val next = Calendar.getInstance().apply {
            add(Calendar.DAY_OF_YEAR, 1)
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 5)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
        val pi = PendingIntent.getBroadcast(
            c,
            REQ_DAY,
            Intent(c, FieldDayChangeReceiver::class.java).setAction("com.example.tubing_calculator.DAY_CHANGED"),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        // 정확할 필요는 없다(화면을 켤 때 받아도 된다). 잠든 폰을 깨우지 않는다.
        am.set(AlarmManager.RTC, next, pi)
    }

    /** 다시 켠 뒤 등: 남은 휴게 알람·퇴근 알림을 다시 걸고 위젯을 다시 그린다. */
    fun restore(c: Context) {
        try {
            ClockBreak.rescheduleAll(c)
        } catch (e: Exception) {
        }
        try {
            if (ClockReminder.stillWorking(c)) ClockReminder.scheduleFromSettings(c)
        } catch (e: Exception) {
        }
        FieldWidgetStore.refreshAll(c)
        scheduleNextDay(c)
    }
}

/** 날짜가 바뀌면 위젯을 다시 그리고 다음 날을 다시 예약한다. */
class FieldDayChangeReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        FieldWidgetStore.refreshAll(context)
        FieldDaily.scheduleNextDay(context)
    }
}

/** 폰을 다시 켰을 때·앱을 새로 깔았을 때·시계·시간대를 바꿨을 때. */
class FieldBootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        FieldDaily.restore(context)
    }
}
