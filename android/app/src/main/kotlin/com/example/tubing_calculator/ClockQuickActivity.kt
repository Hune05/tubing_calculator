package com.example.tubing_calculator

import android.app.Activity
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.text.InputFilter
import android.view.Gravity
import android.view.ViewGroup
import android.view.WindowManager
import android.widget.EditText
import android.widget.HorizontalScrollView
import android.widget.LinearLayout
import android.widget.NumberPicker
import java.util.Calendar
import android.widget.RadioButton
import android.widget.RadioGroup
import android.widget.TextView
import android.widget.Toast

/**
 * 출퇴근 위젯의 [휴게]·[메모] 단추가 여는 작은 창. 위에서 내려오고, 앱을 열지 않는다.
 * - 메모: 자주 쓰는 태그를 누르면 글에 붙고, 직접 적어도 된다(최대 40자). 앱 근태 기록의 "현장 메모"로 저장된다.
 * - 휴게: "10:00 ~ 10:15"처럼 쉬는 시간대를 정하면 시작할 때와 끝날 때 폰이 알려 준다(ClockBreak). 근태 기록은 바꾸지 않는다.
 * 저장은 ClockPunch가 서버에 칸만 합쳐 쓴다(출퇴근 시각 등 다른 칸은 그대로).
 */
class ClockQuickActivity : Activity() {
    companion object {
        const val EXTRA_MODE = "mode"
        const val MODE_MEMO = "memo"
        const val MODE_BREAK = "break"
        const val MEMO_MAX = 40
        val TAGS = listOf("현장 작업", "출장", "교육", "회의", "대기", "정비", "이동")
        val BREAK_LENGTHS = intArrayOf(10, 15, 20, 30, 60)
    }

    private fun dp(v: Int) = (v * resources.displayMetrics.density).toInt()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val mode = intent?.getStringExtra(EXTRA_MODE) ?: MODE_MEMO
        window.setGravity(Gravity.TOP)
        window.setLayout(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
        // 메모만 글자를 치니 자판을 띄운다. 휴게의 시간 휠(NumberPicker)은 안에 입력 칸이 있어서 자판이 떠 저장·지우기 단추를 덮었다.
        window.setSoftInputMode(
            WindowManager.LayoutParams.SOFT_INPUT_ADJUST_NOTHING or
                if (mode == MODE_BREAK) WindowManager.LayoutParams.SOFT_INPUT_STATE_ALWAYS_HIDDEN
                else WindowManager.LayoutParams.SOFT_INPUT_STATE_VISIBLE
        )
        window.setBackgroundDrawable(GradientDrawable().apply {
            setColor(Color.WHITE)
            cornerRadii = floatArrayOf(0f, 0f, 0f, 0f, dp(22).toFloat(), dp(22).toFloat(), dp(22).toFloat(), dp(22).toFloat())
        })
        val state = FieldWidgetStore.clock(this)
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(22), dp(24), dp(22), dp(18))
        }
        if (mode == MODE_BREAK) buildBreak(root)
        else buildMemo(root, state?.optString("memo").orEmpty())
        setContentView(root)
    }

    /** 칩 바탕: 고르면 청록, 아니면 연한 청록. */
    private fun chipBg(on: Boolean) = GradientDrawable().apply {
        cornerRadius = dp(18).toFloat()
        setColor(if (on) 0xFF007580.toInt() else 0xFFE0F1F2.toInt())
    }

    private fun title(t: String) = TextView(this).apply {
        text = t
        textSize = 18f
        setTypeface(typeface, Typeface.BOLD)
        setTextColor(0xFF1F2933.toInt())
    }

    private fun buttons(onSave: () -> Unit): LinearLayout {
        val row = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.END or Gravity.CENTER_VERTICAL
            setPadding(0, dp(18), 0, 0)
        }
        row.addView(TextView(this).apply {
            text = "취소"
            textSize = 16f
            setTextColor(0xFF6B7280.toInt())
            setPadding(dp(18), dp(10), dp(18), dp(10))
            setOnClickListener { finish() }
        })
        row.addView(TextView(this).apply {
            text = "저장"
            textSize = 16f
            setTypeface(typeface, Typeface.BOLD)
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            setPadding(dp(26), dp(10), dp(26), dp(10))
            background = GradientDrawable().apply {
                cornerRadius = dp(22).toFloat()
                setColor(0xFF007580.toInt())
            }
            setOnClickListener { onSave() }
        }, LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply { marginStart = dp(6) })
        return row
    }

    private fun buildMemo(root: LinearLayout, current: String) {
        root.addView(title("메모"))
        val edit = EditText(this).apply {
            setText(current)
            setSelection(current.length)
            hint = "오늘 일에 대한 메모"
            isSingleLine = true
            filters = arrayOf(InputFilter.LengthFilter(MEMO_MAX))
            textSize = 17f
        }
        root.addView(edit, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
            topMargin = dp(8)
        })

        // 태그: 눌러서 글에 넣고 빼고
        val chipRow = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        val chips = HashMap<String, TextView>()
        fun paint(tag: String) {
            val on = edit.text.toString().contains(tag)
            chips[tag]?.apply {
                setTextColor(if (on) Color.WHITE else 0xFF007580.toInt())
                background = chipBg(on)
            }
        }
        for (tag in TAGS) {
            val chip = TextView(this).apply {
                text = tag
                textSize = 14f
                setTypeface(typeface, Typeface.BOLD)
                setPadding(dp(14), dp(8), dp(14), dp(8))
                setOnClickListener {
                    val cur = edit.text.toString()
                    val next = if (cur.contains(tag)) {
                        cur.replace(tag, "").replace("  ", " ").trim()
                    } else {
                        (if (cur.isBlank()) tag else "$tag $cur").take(MEMO_MAX)
                    }
                    edit.setText(next)
                    edit.setSelection(next.length)
                    for (t in TAGS) paint(t)
                }
            }
            chips[tag] = chip
            chipRow.addView(chip, LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                marginEnd = dp(8)
            })
        }
        for (t in TAGS) paint(t)
        root.addView(HorizontalScrollView(this).apply {
            isHorizontalScrollBarEnabled = false
            addView(chipRow)
        }, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
            topMargin = dp(10)
        })
        root.addView(buttons {
            save(memo = edit.text.toString().trim(), brk = null)
        })
    }

    private fun buildBreak(root: LinearLayout) {
        root.addView(title("휴게 알람"))
        root.addView(TextView(this).apply {
            text = "쉬는 시간대를 정하면 시작할 때와 끝날 때 알려 줍니다."
            textSize = 13f
            setTextColor(0xFF6B7280.toInt())
        })

        // 시작 시각: 지금 이후 가까운 5분 단위로 맞춰 둔다
        val cal = Calendar.getInstance().apply { add(Calendar.MINUTE, 5) }
        val hour = NumberPicker(this).apply {
            minValue = 0
            maxValue = 23
            displayedValues = Array(24) { h -> if (h < 12) "오전 ${if (h == 0) 12 else h}시" else "오후 ${if (h == 12) 12 else h - 12}시" }
            value = cal.get(Calendar.HOUR_OF_DAY)
            wrapSelectorWheel = true
        }
        val minute = NumberPicker(this).apply {
            minValue = 0
            maxValue = 11
            displayedValues = Array(12) { m -> String.format("%02d분", m * 5) }
            value = (cal.get(Calendar.MINUTE) / 5) % 12
            wrapSelectorWheel = true
        }
        hour.descendantFocusability = ViewGroup.FOCUS_BLOCK_DESCENDANTS
        minute.descendantFocusability = ViewGroup.FOCUS_BLOCK_DESCENDANTS
        val pickers = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
        }
        pickers.addView(hour, LinearLayout.LayoutParams(dp(120), ViewGroup.LayoutParams.WRAP_CONTENT))
        pickers.addView(minute, LinearLayout.LayoutParams(dp(90), ViewGroup.LayoutParams.WRAP_CONTENT).apply { marginStart = dp(8) })
        root.addView(pickers, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
            topMargin = dp(8)
        })

        // 쉬는 길이
        val preview = TextView(this).apply {
            textSize = 16f
            setTypeface(typeface, Typeface.BOLD)
            setTextColor(0xFF007580.toInt())
            gravity = Gravity.CENTER
        }
        var lengthMin = 15
        val chips = HashMap<Int, TextView>()
        fun startMs(): Long = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour.value)
            set(Calendar.MINUTE, minute.value * 5)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
        fun refresh() {
            val st = startMs()
            preview.text = "${ClockBreak.fmt(st)} ~ ${ClockBreak.fmt(st + lengthMin * 60000L)}"
            for ((m, chip) in chips) {
                val on = m == lengthMin
                chip.setTextColor(if (on) Color.WHITE else 0xFF007580.toInt())
                chip.background = chipBg(on)
            }
        }
        val lenRow = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER }
        for (m in BREAK_LENGTHS) {
            val chip = TextView(this).apply {
                text = if (m == 60) "1시간" else "${m}분"
                textSize = 14f
                setTypeface(typeface, Typeface.BOLD)
                setPadding(dp(14), dp(8), dp(14), dp(8))
                setOnClickListener { lengthMin = m; refresh() }
            }
            chips[m] = chip
            lenRow.addView(chip, LinearLayout.LayoutParams(ViewGroup.LayoutParams.WRAP_CONTENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
                marginStart = dp(4); marginEnd = dp(4)
            })
        }
        hour.setOnValueChangedListener { _, _, _ -> refresh() }
        minute.setOnValueChangedListener { _, _, _ -> refresh() }
        root.addView(lenRow, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
            topMargin = dp(6)
        })
        root.addView(preview, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
            topMargin = dp(10)
        })
        refresh()

        // 이미 정한 휴게 알람(지울 수 있다)
        val existing = ClockBreak.list(this)
        if (existing.isNotEmpty()) {
            root.addView(TextView(this).apply {
                text = "정해 둔 휴게"
                textSize = 13f
                setTextColor(0xFF6B7280.toInt())
                setPadding(0, dp(12), 0, dp(2))
            })
            for (item in existing) {
                val row = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL; gravity = Gravity.CENTER_VERTICAL }
                row.addView(TextView(this).apply {
                    text = ClockBreak.label(item)
                    textSize = 16f
                    setTextColor(0xFF1F2933.toInt())
                }, LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f))
                row.addView(TextView(this).apply {
                    text = "지우기"
                    textSize = 15f
                    setTextColor(0xFFE5195E.toInt())
                    setPadding(dp(14), dp(8), dp(14), dp(8))
                    setOnClickListener {
                        ClockBreak.remove(this@ClockQuickActivity, item.id)
                        Toast.makeText(this@ClockQuickActivity, "휴게 알람을 지웠습니다.", Toast.LENGTH_SHORT).show()
                        finish()
                    }
                })
                root.addView(row)
            }
        }

        root.addView(buttons {
            val st = startMs()
            val err = ClockBreak.add(this, st, st + lengthMin * 60000L)
            if (err != null) {
                Toast.makeText(this, err, Toast.LENGTH_LONG).show()
            } else {
                Toast.makeText(this, "휴게 알람을 정했습니다: ${preview.text}", Toast.LENGTH_LONG).show()
                finish()
            }
        })
    }

    private fun save(memo: String?, brk: Int?) {
        val app = applicationContext
        Thread {
            val msg = try {
                ClockPunch.setField(app, memo, brk)
            } catch (e: Exception) {
                "저장하지 못했습니다. 앱에서 확인하세요."
            }
            Handler(Looper.getMainLooper()).post {
                Toast.makeText(app, msg, Toast.LENGTH_LONG).show()
            }
        }.start()
        finish()
    }
}
