package com.example.tubing_calculator

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Handler
import android.os.Looper
import android.widget.Toast
import com.google.android.gms.tasks.Tasks
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore
import com.google.firebase.firestore.SetOptions
import java.util.Calendar
import java.util.concurrent.ExecutionException
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException

/**
 * 출퇴근 위젯의 [출근]·[퇴근] 단추: 앱을 열지 않고 지금 시각으로 근태 기록을 바로 적는다.
 *
 * 앱(Dart)이 하는 일과 같은 규칙을 따른다(attendance_clock.dart, 근태 화면의 _punchIn·_punchOut):
 * - 서버 모음 attendance_records, 문서 이름 "{uid}__{yyyy-MM-dd}", 칸 date·type·checkIn·checkOut·uid.
 * - 이미 찍었으면 덮지 않고 알리기만 한다. 연차·월차·결근인 날은 찍지 않는다.
 * - 밤샘: 오늘 출근을 아직 안 찍었고, 어제 15시 이후에 출근해 12시간이 안 지났으면 [퇴근]은 어제 기록에 찍는다
 *   (10-09 8차: 앱은 10-08에 16 → 12시간·오늘 먼저로 바꿨는데 위젯은 그대로라, 어제 18시 출근하고 퇴근을
 *   잊은 다음 날 08시 위젯 [출근]이 "이미 어제 출근"으로 막히고, 오늘 출근을 앱에서 찍은 뒤 위젯 [퇴근]이
 *   어제 기록에 찍혔다).
 * - 기록을 읽지 못하면(통신 없음 + 폰에 사본 없음) 찍지 않는다. 모르는 채 찍으면 있던 기록을 덮을 수 있다.
 * 저장은 칸 하나씩 합쳐 쓴다(merge): 메모·휴게 같은 다른 칸은 그대로 둔다.
 * 통신이 없으면 Firestore가 폰에 먼저 적고 통신될 때 올린다. 앱의 퇴근 알림 예약은 앱을 다시 열 때 맞춘다.
 */
class ClockPunchReceiver : BroadcastReceiver() {
    companion object {
        const val EXTRA_KIND = "kind"
    }

    override fun onReceive(context: Context, intent: Intent) {
        val kind = intent.getStringExtra(EXTRA_KIND) ?: return
        val app = context.applicationContext
        val pending = goAsync()
        Thread {
            val msg = try {
                ClockPunch.run(app, kind)
            } catch (e: Exception) {
                "출퇴근을 찍지 못했습니다. 위젯을 눌러 앱에서 확인하세요."
            }
            Handler(Looper.getMainLooper()).post {
                Toast.makeText(app, msg, Toast.LENGTH_LONG).show()
            }
            pending.finish()
        }.start()
    }
}

object ClockPunch {
    // 기록 읽기·상태 규칙은 ClockState·ClockSync(ClockState.kt)와 같이 쓴다(10-13: 위젯 퇴근 근무 시간이
    // 기본 휴게를 안 빼 앱과 달랐다 — 이제 찍은 뒤 상태를 앱과 같은 규칙으로 다시 만든다).
    private const val OVERNIGHT_START_MIN = 15 * 60
    private const val OVERNIGHT_MAX_MIN = 12 * 60 // 앱 attendance_clock.dart kMaxOvernightMinutes와 같게

    private fun minutesOf(v: String?) = ClockState.minutesOf(v)

    /** 밤샘 근무 중인가: 오늘 출근 전이고, 어제 15시 이후 출근해 퇴근을 안 찍었으며 12시간이 안 지났다. */
    private fun isOvernight(y: ClockState.Rec?, t: ClockState.Rec?, yest: Calendar, now: Calendar): Boolean {
        if (!ClockState.isOpen(y) || minutesOf(t?.checkIn) != null) return false
        val m = minutesOf(y!!.checkIn)!!
        val start = (yest.clone() as Calendar).apply {
            set(Calendar.HOUR_OF_DAY, m / 60)
            set(Calendar.MINUTE, m % 60)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val elapsed = (now.timeInMillis - start.timeInMillis) / 60000
        return m >= OVERNIGHT_START_MIN && elapsed in 0..OVERNIGHT_MAX_MIN.toLong()
    }

    /** 칸을 합쳐 쓴다. 서버가 거절하면 예외, 통신이 없어 늦으면 폰에 먼저 적힌 것으로 본다. */
    private fun write(uid: String, key: String, data: Map<String, Any?>): String? {
        val ref = FirebaseFirestore.getInstance().collection(ClockState.COLLECTION).document("${uid}__$key")
        val task = ref.set(data, SetOptions.merge())
        return try {
            Tasks.await(task, 3, TimeUnit.SECONDS)
            null
        } catch (e: TimeoutException) {
            "통신이 안 돼 폰에 먼저 저장했습니다. 연결되면 올라갑니다."
        } catch (e: ExecutionException) {
            throw e
        }
    }

    /** 찍은 뒤의 기록으로 위젯 상태를 다시 만들어 그린다(앱과 같은 규칙). */
    private fun redraw(c: Context, recs: Map<String, ClockState.Rec>, now: Calendar) {
        ClockSync.save(c, ClockState.build(recs, now, ClockState.opts(c)))
    }

    fun run(c: Context, kind: String): String {
        val user = FirebaseAuth.getInstance().currentUser
            ?: return "로그인이 안 되어 있습니다. 앱을 열어 로그인하세요."
        val uid = user.uid
        val now = Calendar.getInstance()
        val yest = (now.clone() as Calendar).apply { add(Calendar.DAY_OF_MONTH, -1) }
        val todayKey = ClockState.dateKey(now)
        val yestKey = ClockState.dateKey(yest)
        val recs = ClockSync.load(uid, now)
            ?: return "기록을 읽지 못해 찍지 않았습니다. 앱에서 확인하세요."
        val y = recs[yestKey]
        val t = recs[todayKey]

        val overnight = isOvernight(y, t, yest, now)

        val nowText = ClockState.hhmm(now)
        if (kind == "in") {
            if (overnight) return "이미 어제 ${y!!.checkIn}에 출근해 근무 중입니다."
            if (t != null && t.type in ClockState.OFF_TYPES) return "오늘은 ${t.type}이라 출근을 찍지 않았습니다."
            if (t != null && minutesOf(t.checkIn) != null) return "이미 ${t.checkIn}에 출근을 찍었습니다."
            val type = t?.type ?: "정상근무"
            val note = write(uid, todayKey, mapOf("date" to todayKey, "uid" to uid, "type" to type, "checkIn" to nowText))
            recs[todayKey] = ClockState.Rec(type, nowText, t?.checkOut, t?.breakMin, t?.memo)
            redraw(c, recs, now)
            // 앱이 꺼져 있어도 퇴근 깜빡 알림이 잡히게 한다(설정에서 켜 둔 경우만).
            ClockReminder.scheduleFromSettings(c)
            return note ?: "출근 $nowText 저장했습니다."
        }

        // 퇴근
        val targetKey: String
        val target: ClockState.Rec
        if (overnight) {
            targetKey = yestKey
            target = y!!
        } else if (ClockState.isOpen(t)) {
            targetKey = todayKey
            target = t!!
        } else {
            return if (t != null && minutesOf(t.checkIn) != null && t.checkOut != null) {
                "이미 ${t.checkOut}에 퇴근을 찍었습니다."
            } else {
                "출근 기록이 없어 퇴근을 찍지 못했습니다. 앱에서 출근 시각을 먼저 적어 주세요."
            }
        }
        val stay = ClockState.stayMinutes(target.checkIn, nowText)
            ?: return "방금 출근하셨습니다. 1분 뒤에 퇴근을 눌러 주세요."
        val note = write(uid, targetKey, mapOf("date" to targetKey, "uid" to uid, "checkOut" to nowText))
        ClockReminder.cancel(c)
        val done = ClockState.Rec(target.type, target.checkIn, nowText, target.breakMin, target.memo)
        recs[targetKey] = done
        redraw(c, recs, now)
        // 근무 시간은 앱처럼 휴게(비워 두면 기본 휴게)를 뺀 것
        val work = stay - ClockState.breakFor(done, stay, ClockState.opts(c))
        return note ?: "퇴근 $nowText 저장했습니다 · 근무 ${ClockState.minutesText(work)}"
    }

    /**
     * [메모]·[휴게] 창이 저장할 때 부른다. 지금 근무 중인 기록(밤샘이면 어제 것, 아니면 오늘 것)에 칸 하나만 합쳐 쓴다.
     * 출퇴근 시각은 건드리지 않는다. 쓸 기록이 없으면(출근 전) 안내만 한다.
     */
    fun setField(c: Context, memo: String?, brk: Int?): String {
        val user = FirebaseAuth.getInstance().currentUser
            ?: return "로그인이 안 되어 있습니다. 앱을 열어 로그인하세요."
        val uid = user.uid
        val now = Calendar.getInstance()
        val yest = (now.clone() as Calendar).apply { add(Calendar.DAY_OF_MONTH, -1) }
        val todayKey = ClockState.dateKey(now)
        val yestKey = ClockState.dateKey(yest)
        val recs = ClockSync.load(uid, now)
            ?: return "기록을 읽지 못해 저장하지 않았습니다. 앱에서 확인하세요."
        val y = recs[yestKey]
        val t = recs[todayKey]
        val overnight = isOvernight(y, t, yest, now)
        val targetKey = if (overnight) yestKey else todayKey
        val target = if (overnight) y else t
        if (target == null || minutesOf(target.checkIn) == null) {
            return "출근한 뒤에 쓸 수 있습니다. 먼저 출근을 찍어 주세요."
        }
        val data = HashMap<String, Any?>()
        data["date"] = targetKey
        data["uid"] = uid
        if (memo != null) data["memo"] = memo
        if (brk != null) data["breakMin"] = brk
        val note = write(uid, targetKey, data)

        // 위젯 상태에도 바로 반영
        recs[targetKey] = ClockState.Rec(
            target.type, target.checkIn, target.checkOut, brk ?: target.breakMin,
            if (memo != null) memo.takeIf { it.isNotBlank() } else target.memo
        )
        redraw(c, recs, now)
        return note ?: if (memo != null) "메모를 저장했습니다." else "휴게시간을 ${if (brk == 0) "없음" else ClockState.minutesText(brk ?: 0)}으로 저장했습니다."
    }
}
