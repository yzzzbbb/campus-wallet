package com.yzb.campus_wallet

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import org.json.JSONObject

class CampusWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, buildViews(context))
        }
    }

    companion object {
        fun updateAll(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(
                ComponentName(context, CampusWidgetProvider::class.java),
            )
            for (id in ids) {
                manager.updateAppWidget(id, buildViews(context))
            }
        }

        private fun buildViews(context: Context): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_campus)
            val prefs = context.getSharedPreferences("campus_widget", Context.MODE_PRIVATE)
            val raw = prefs.getString("data", null)

            var days = "--"
            var remaining = "剩余可用 --"
            var daily = "日均可用 --"
            var spent = "本月支出 --"
            if (raw != null) {
                try {
                    val o = JSONObject(raw)
                    days = o.optInt("days", -1).let { if (it < 0) "--" else it.toString() }
                    val remainingCents = o.optLong("remaining_cents", Long.MIN_VALUE)
                    if (remainingCents != Long.MIN_VALUE) {
                        remaining = "剩余可用 " + formatCents(remainingCents)
                    }
                    val dailyCents = o.optLong("daily_cents", Long.MIN_VALUE)
                    if (dailyCents != Long.MIN_VALUE) {
                        daily = "日均可用 " + formatCents(dailyCents)
                    }
                    val spentCents = o.optLong("month_expense_cents", Long.MIN_VALUE)
                    if (spentCents != Long.MIN_VALUE) {
                        spent = "本月支出 " + formatCents(spentCents)
                    }
                } catch (_: Exception) {
                }
            }

            views.setTextViewText(R.id.widget_days_label, "距发生活费还有")
            views.setTextViewText(R.id.widget_days, "$days 天")
            views.setTextViewText(R.id.widget_remaining, remaining)
            views.setTextViewText(R.id.widget_daily, daily)
            views.setTextViewText(R.id.widget_spent, spent)

            val launch = context.packageManager.getLaunchIntentForPackage(context.packageName)
            if (launch != null) {
                val pi = PendingIntent.getActivity(
                    context,
                    0,
                    launch,
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                )
                views.setOnClickPendingIntent(R.id.widget_root, pi)
            }
            return views
        }

        private fun formatCents(cents: Long): String {
            val sign = if (cents < 0) "-" else ""
            val abs = if (cents < 0) -cents else cents
            val yuan = abs / 100
            val fen = abs % 100
            val fenStr = if (fen == 0L) "" else ".${fen.toString().padStart(2, '0')}"
            return "$sign¥$yuan$fenStr"
        }
    }
}