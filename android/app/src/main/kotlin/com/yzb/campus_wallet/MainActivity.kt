package com.yzb.campus_wallet

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "campus_wallet/widget")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "update" -> {
                        val data = call.argument<String>("data") ?: "{}"
                        saveWidgetData(data)
                        CampusWidgetProvider.updateAll(this)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun saveWidgetData(json: String) {
        val prefs = getSharedPreferences("campus_widget", Context.MODE_PRIVATE)
        prefs.edit().putString("data", json).apply()
    }
}