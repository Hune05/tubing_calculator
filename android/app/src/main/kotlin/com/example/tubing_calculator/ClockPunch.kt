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
import com.google.firebase.firestore.Source
import org.json.JSONObject
import java.util.Calendar
import java.util.Locale
import java.util.concurrent.ExecutionException
import java.util.concurrent.TimeUnit
import java.util.concurrent.TimeoutException

/**
 * 출퇴근 위젯의 [출근]·[퇴근] 단추: 앱을 열지 않고 지금 시각으로 근태 기록을 바로 적는다.
 *
 * 앱(Dart)이 하는 일과 같은 규칙을 따른다(attendance_clock.dart, 근태 화면의 _punchIn·_punchOut):
 * - 서버 모음 attendance_records, 문서 이름 "{uid}__{yyyy-MM-dd}", 칸 date·type·checkIn·checkOut·uid.
 * - 이미 찍었으면 덮지 않고 알리기만 한다. 연차·월차·결근인 날은 찍지 않는다.
 * - 밤샘: 어제 15시 이후에 출근했고 16시간이 안 지났으면 [퇴근]은 어제 기록에 찍는다.
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
    private const val COLLECTION = "attendance_records"
    private val OFF_TYPES = setOf("연차", "월차", "결근")
    private const val OVERNIGHT_START_MIN = 15 * 60
    private const val OVERNIGHT_MAX_MIN = 16 * 60

    private class Rec(val type: String, val checkIn: String?, val checkOut: String?)

    private fun dateKey(c: Calendar) = String.format(
        Locale.US, "%04d-%02d-%02d", c.get(Calendar.YEAR), c.get(Calendar.MONTH) + 1, c.get(Calendar.DAY_OF_MONTH)
    )

    private fun hhmm(c: Calendar) = String.format(
        Locale.US, "%02d:%02d", c.get(Calendar.HOUR_OF_DAY), c.get(Calendar.MINUTE)
    )

    /** "HH:mm" → 그 날 0시부터 분. 모양이 틀리면 null. */
    private fun minutesOf(v: String?): Int? {
        if (v == null) return null
        val p = v.split(":")
        if (p.size != 2) return null
        val h = p[0].toIntOrNull() ?: return null
        val m = p[1].toIntOrNull() ?: return null
        if (h !in 0..23 || m !in 0..59) return null
        return h * 60 + m
    }

    /** 출근~퇴근 사이 분(자정 넘김 처리). 같은 시각이면 null. */
    private fun stayMinutes(inT: String?, outT: String?): Int? {
        val a = minutesOf(inT) ?: return null
        val b = minutesOf(outT) ?: return null
        var d = b - a
        if (d == 0) return null
        if (d < 0) d += 24 * 60
        return d
    }

    private fun minutesText(m: Int): String {
        val h = m / 60
        val r = m % 60
        return if (r == 0) "${h}시간" else if (h == 0) "${r}분" else "${h}시간 ${r}분"
    }

    private fun isOpen(r: Rec?): Boolean =
        r != null && r.type !in OFF_TYPES && minutesOf(r.checkIn) != null && r.checkOut == null

    /** 어제 이후 두 날의 기록을 읽는다(서버 → 안 되면 폰 사본). 둘 다 안 되면 null. */
    private fun load(uid: String, from: String, to: String): Map<String, Rec>? {
        val q = FirebaseFirestore.getInstance().collection(COLLECTION)
            .whereEqualTo("uid", uid)
            .whereGreaterThanOrEqualTo("date", from)
            .whereLessThanOrEqualTo("date", to)
        val snap = try {
            Tasks.await(q.get(Source.SERVER), 5, TimeUnit.SECONDS)
        } catch (e: Exception) {
            try {
                Tasks.await(q.get(Source.CACHE), 3, TimeUnit.SECONDS)
            } catch (e2: Exception) {
                return null
            }
        }
        val out = HashMap<String, Rec>()
        for (d in snap.documents) {
            val date = d.getString("date") ?: continue
            out[date] = Rec(d.getString("type") ?: "정상근무", d.getString("checkIn"), d.getString("checkOut"))
        }
        return out
    }

    /** 칸을 합쳐 쓴다. 서버가 거절하면 예외, 통신이 없어 늦으면 폰에 먼저 적힌 것으로 본다. */
    private fun write(uid: String, key: String, data: Map<String, Any?>): String? {
        val ref = FirebaseFirestore.getInstance().collection(COLLECTION).document("${uid}__$key")
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

    private fun saveClock(c: Context, todayKey: String, phase: String, text: String, sinceMs: Long) {
        val o = JSONObject()
            .put("date", todayKey)
            .put("phase", phase)
            .put("text", text)
            .put("since", sinceMs)
        FieldWidgetStore.save(c, null, null, o.toString())
        FieldWidgetStore.refreshAll(c)
    }

    fun run(c: Context, kind: String): String {
        val user = FirebaseAuth.getInstance().currentUser
            ?: return "로그인이 안 되어 있습니다. 앱을 열어 로그인하세요."
        val uid = user.uid
        val now = Calendar.getInstance()
        val yest = (now.clone() as Calendar).apply { add(Calendar.DAY_OF_MONTH, -1) }
        val todayKey = dateKey(now)
        val yestKey = dateKey(yest)
        val recs = load(uid, yestKey, todayKey)
            ?: return "기록을 읽지 못해 찍지 않았습니다. 앱에서 확인하세요."
        val y = recs[yestKey]
        val t = recs[todayKey]

        // 밤샘 근무 중인가: 어제 15시 이후에 출근했고 퇴근을 안 찍었으며 16시간이 안 지났다.
        var overnight = false
        if (isOpen(y)) {
            val m = minutesOf(y!!.checkIn)!!
            val start = (yest.clone() as Calendar).apply {
                set(Calendar.HOUR_OF_DAY, m / 60)
                set(Calendar.MINUTE, m % 60)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            val elapsed = (now.timeInMillis - start.timeInMillis) / 60000
            overnight = m >= OVERNIGHT_START_MIN && elapsed in 0..OVERNIGHT_MAX_MIN.toLong()
        }

        val nowText = hhmm(now)
        if (kind == "in") {
            if (overnight) return "이미 어제 ${y!!.checkIn}에 출근해 근무 중입니다."
            if (t != null && t.type in OFF_TYPES) return "오늘은 ${t.type}이라 출근을 찍지 않았습니다."
            if (t != null && minutesOf(t.checkIn) != null) return "이미 ${t.checkIn}에 출근을 찍었습니다."
            val note = write(
                uid, todayKey,
                mapOf("date" to todayKey, "uid" to uid, "type" to (t?.type ?: "정상근무"), "checkIn" to nowText)
            )
            val since = (now.clone() as Calendar).apply {
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }.timeInMillis
            saveClock(c, todayKey, "working", "$nowText 출근 · 근무 중", since)
            return note ?: "출근 $nowText 저장했습니다."
        }

        // 퇴근
        val targetKey: String
        val target: Rec
        if (overnight) {
            targetKey = yestKey
            target = y!!
        } else if (isOpen(t)) {
            targetKey = todayKey
            target = t!!
        } else {
            return if (t != null && minutesOf(t.checkIn) != null && t.checkOut != null) {
                "이미 ${t.checkOut}에 퇴근을 찍었습니다."
            } else {
                "출근 기록이 없어 퇴근을 찍지 못했습니다. 앱에서 출근 시각을 먼저 적어 주세요."
            }
        }
        val stay = stayMinutes(target.checkIn, nowText)
            ?: return "방금 출근하셨습니다. 1분 뒤에 퇴근을 눌러 주세요."
        val note = write(uid, targetKey, mapOf("date" to targetKey, "uid" to uid, "checkOut" to nowText))
        if (targetKey == yestKey) {
            // 밤샘 퇴근: 오늘 기록은 아직 없으니 출근 전으로 돌아간다.
            saveClock(c, todayKey, "ready", "오늘 출근 전", 0L)
        } else {
            saveClock(c, todayKey, "done", "${target.checkIn} ~ $nowText", 0L)
        }
        return note ?: "퇴근 $nowText 저장했습니다 · 출근~퇴근 ${minutesText(stay)}"
    }
}
