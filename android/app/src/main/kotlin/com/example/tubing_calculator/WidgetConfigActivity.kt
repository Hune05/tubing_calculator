package com.example.tubing_calculator

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.graphics.Typeface
import android.os.Bundle
import android.view.Gravity
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.RadioButton
import android.widget.RadioGroup
import android.widget.TextView

/**
 * 위젯별 설정: 위젯을 홈 화면에 올릴 때 한 번 뜨고, 이미 올린 위젯은 길게 눌러 "설정"으로 다시 연다.
 * 설정은 위젯 하나마다 따로 저장한다(WidgetCfg). 바꿀 수 있는 것:
 * - 배경 투명도(100·80·60·40%): 배경화면이 비치게
 * - 모양: 자동(크기에 맞춤) / 항상 한 줄 / 항상 카드
 */
object WidgetCfg {
    private const val PREFS = "field_widget_cfg"
    const val MODE_AUTO = 0
    const val MODE_SMALL = 1
    const val MODE_LARGE = 2

    private fun p(c: Context) = c.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun alpha(c: Context, id: Int): Int = p(c).getInt("a_$id", 100)
    fun mode(c: Context, id: Int): Int = p(c).getInt("m_$id", MODE_AUTO)

    fun save(c: Context, id: Int, alpha: Int, mode: Int) {
        p(c).edit().putInt("a_$id", alpha).putInt("m_$id", mode).apply()
    }

    fun clear(c: Context, ids: IntArray) {
        val e = p(c).edit()
        for (id in ids) e.remove("a_$id").remove("m_$id")
        e.apply()
    }

    /** 투명도에 맞는 배경 모양. */
    fun bgRes(alpha: Int): Int = when {
        alpha >= 100 -> R.drawable.widget_bg
        alpha >= 80 -> R.drawable.widget_bg_80
        alpha >= 60 -> R.drawable.widget_bg_60
        else -> R.drawable.widget_bg_40
    }
}

class WidgetConfigActivity : Activity() {
    private var widgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // 설정을 안 하고 닫으면 위젯이 올라가지 않도록 먼저 "취소"로 둔다.
        setResult(RESULT_CANCELED)
        widgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID, AppWidgetManager.INVALID_APPWIDGET_ID
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID
        if (widgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }
        val dp = resources.displayMetrics.density
        fun px(v: Int) = (v * dp).toInt()

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(px(22), px(20), px(22), px(16))
        }
        fun title(t: String) = TextView(this).apply {
            text = t
            textSize = 16f
            setTypeface(typeface, Typeface.BOLD)
            setPadding(0, px(14), 0, px(4))
        }
        root.addView(TextView(this).apply {
            text = "위젯 설정"
            textSize = 20f
            setTypeface(typeface, Typeface.BOLD)
        })

        val alphaValues = intArrayOf(100, 80, 60, 40)
        val alphaLabels = arrayOf("불투명 (100%)", "80%", "60%", "40% (배경화면이 많이 비침)")
        val curAlpha = WidgetCfg.alpha(this, widgetId)
        val alphaGroup = RadioGroup(this)
        for ((i, label) in alphaLabels.withIndex()) {
            alphaGroup.addView(RadioButton(this).apply {
                id = 100 + i
                text = label
                isChecked = alphaValues[i] == curAlpha
            })
        }
        root.addView(title("배경 투명도"))
        root.addView(alphaGroup)

        val modeLabels = arrayOf("자동 (크기에 맞춤)", "항상 한 줄로", "항상 카드로")
        val curMode = WidgetCfg.mode(this, widgetId)
        val modeGroup = RadioGroup(this)
        for ((i, label) in modeLabels.withIndex()) {
            modeGroup.addView(RadioButton(this).apply {
                id = 200 + i
                text = label
                isChecked = i == curMode
            })
        }
        root.addView(title("모양"))
        root.addView(modeGroup)
        root.addView(TextView(this).apply {
            text = "자동이면 위젯을 줄이고 늘리는 대로 한 줄과 카드가 바뀝니다."
            textSize = 12f
            setPadding(0, px(4), 0, 0)
        })

        val btn = Button(this).apply {
            text = "완료"
            textSize = 16f
            setOnClickListener {
                val a = alphaValues[(alphaGroup.checkedRadioButtonId - 100).coerceIn(0, 3)]
                val m = (modeGroup.checkedRadioButtonId - 200).coerceIn(0, 2)
                WidgetCfg.save(this@WidgetConfigActivity, widgetId, a, m)
                FieldWidgetStore.refreshAll(applicationContext)
                setResult(RESULT_OK, Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId))
                finish()
            }
        }
        root.addView(btn, LinearLayout.LayoutParams(ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT).apply {
            topMargin = px(18)
            gravity = Gravity.END
        })
        setContentView(root)
    }
}
