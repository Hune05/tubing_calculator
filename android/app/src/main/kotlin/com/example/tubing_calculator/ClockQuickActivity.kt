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
import android.widget.Button
import android.widget.EditText
import android.widget.HorizontalScrollView
import android.widget.LinearLayout
import android.widget.RadioButton
import android.widget.RadioGroup
import android.widget.TextView
import android.widget.Toast

/**
 * 출퇴근 위젯의 [휴게]·[메모] 단추가 여는 작은 창. 위에서 내려오고, 앱을 열지 않는다.
 * - 메모: 자주 쓰는 태그를 누르면 글에 붙고, 직접 적어도 된다(최대 40자). 앱 근태 기록의 "현장 메모"로 저장된다.
 * - 휴게: 없음·30분·1시간·1시간 30분·2시간 중에서 고른다. 앱 근태 기록의 휴게시간으로 저장된다.
 * 저장은 ClockPunch가 서버에 칸만 합쳐 쓴다(출퇴근 시각 등 다른 칸은 그대로).
 */
class ClockQuickActivity : Activity() {
    companion object {
        const val EXTRA_MODE = "mode"
        const val MODE_MEMO = "memo"
        const val MODE_BREAK = "break"
        const val MEMO_MAX = 40
        val TAGS = listOf("현장 작업", "출장", "교육", "회의", "대기", "정비", "이동")
        val BREAK_VALUES = intArrayOf(0, 30, 60, 90, 120)
        val BREAK_LABELS = arrayOf("없음", "30분", "1시간", "1시간 30분", "2시간")
    }

    private fun dp(v: Int) = (v * resources.displayMetrics.density).toInt()

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val mode = intent?.getStringExtra(EXTRA_MODE) ?: MODE_MEMO
        window.setGravity(Gravity.TOP)
        window.setLayout(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT)
        window.setSoftInputMode(WindowManager.LayoutParams.SOFT_INPUT_ADJUST_NOTHING or WindowManager.LayoutParams.SOFT_INPUT_STATE_VISIBLE)
        window.setBackgroundDrawable(GradientDrawable().apply {
            setColor(Color.WHITE)
            cornerRadii = floatArrayOf(0f, 0f, 0f, 0f, dp(22).toFloat(), dp(22).toFloat(), dp(22).toFloat(), dp(22).toFloat())
        })
        val state = FieldWidgetStore.clock(this)
        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(dp(22), dp(24), dp(22), dp(18))
        }
        if (mode == MODE_BREAK) buildBreak(root, state?.optInt("brk", -1) ?: -1)
        else buildMemo(root, state?.optString("memo").orEmpty())
        setContentView(root)
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
            gravity = Gravity.END
            setPadding(0, dp(14), 0, 0)
        }
        row.addView(Button(this).apply {
            text = "취소"
            setOnClickListener { finish() }
        })
        row.addView(Button(this).apply {
            text = "저장"
            setOnClickListener { onSave() }
        })
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
                background = GradientDrawable().apply {
                    cornerRadius = dp(18).toFloat()
                    setColor(if (on) 0xFF007580.toInt() else 0xFFE0F1F2.toInt())
                }
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

    private fun buildBreak(root: LinearLayout, current: Int) {
        root.addView(title("휴게시간"))
        root.addView(TextView(this).apply {
            text = "오늘 쉰 시간을 고르면 근로시간에서 빠집니다."
            textSize = 13f
            setTextColor(0xFF6B7280.toInt())
        })
        val group = RadioGroup(this)
        for ((i, label) in BREAK_LABELS.withIndex()) {
            group.addView(RadioButton(this).apply {
                id = 500 + i
                text = label
                textSize = 16f
                isChecked = BREAK_VALUES[i] == current
            })
        }
        root.addView(group, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
            topMargin = dp(8)
        })
        root.addView(buttons {
            val i = (group.checkedRadioButtonId - 500)
            if (i !in BREAK_VALUES.indices) {
                Toast.makeText(this, "휴게시간을 골라 주세요.", Toast.LENGTH_SHORT).show()
            } else {
                save(memo = null, brk = BREAK_VALUES[i])
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
