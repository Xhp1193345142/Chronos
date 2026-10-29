package com.xhp.chronos

import android.Manifest
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var notificationResult: MethodChannel.Result? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "chronos/native")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "status" -> result.success(mapOf(
                        "usageGranted" to UsageReader.hasAccess(this),
                        "notificationsGranted" to notificationsGranted(),
                        "platform" to "android",
                    ))
                    "openUsageSettings" -> {
                        try {
                            startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                            result.success(true)
                        } catch (error: Exception) {
                            result.error("settings_unavailable", error.message, null)
                        }
                    }
                    "openNotificationSettings" -> {
                        try {
                            startActivity(Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                .putExtra(Settings.EXTRA_APP_PACKAGE, packageName))
                            result.success(true)
                        } catch (error: Exception) {
                            result.error("settings_unavailable", error.message, null)
                        }
                    }
                    "requestNotificationPermission" -> {
                        if (notificationsGranted() || Build.VERSION.SDK_INT < 33) {
                            result.success(true)
                        } else if (notificationResult != null) {
                            result.error("request_active", "Notification request already active", null)
                        } else {
                            notificationResult = result
                            requestPermissions(arrayOf(Manifest.permission.POST_NOTIFICATIONS), 4107)
                        }
                    }
                    "snapshot" -> Thread {
                        try {
                            val data = UsageReader.snapshot(applicationContext)
                            runOnUiThread { result.success(data) }
                        } catch (error: Exception) {
                            runOnUiThread { result.error("usage_read_failed", error.message, null) }
                        }
                    }.start()
                    "getGoal" -> result.success(GoalStore.current(this))
                    "saveGoal" -> try {
                        val input = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                        result.success(GoalStore.save(this, input))
                    } catch (error: Exception) {
                        result.error("invalid_goal", error.message, null)
                    }
                    "setGoalEnabled" -> result.success(
                        GoalStore.setEnabled(this, call.argument<Boolean>("enabled") == true),
                    )
                    "pauseGoalToday" -> result.success(GoalStore.pauseToday(this))
                    "insightPreferences" -> result.success(GoalStore.insightPreferences(this))
                    "setInsightsEnabled" -> result.success(GoalStore.setInsightsEnabled(
                        this, call.argument<Boolean>("enabled") == true,
                    ))
                    "suppressWeekRange" -> result.success(GoalStore.suppressWeekRange(this))
                    "restoreInsights" -> result.success(GoalStore.restoreInsights(this))
                    "selectedGoalMinutes" -> {
                        val ids = (GoalStore.current(this)?.get("packageIds") as? List<*>)
                            ?.filterIsInstance<String>()?.toSet().orEmpty()
                        Thread {
                            try {
                                val minutes = UsageReader.selectedMinutesToday(applicationContext, ids)
                                runOnUiThread { result.success(minutes) }
                            } catch (error: Exception) {
                                runOnUiThread { result.error("usage_read_failed", error.message, null) }
                            }
                        }.start()
                    }
                    "deleteLocalData" -> {
                        GoalStore.clear(this)
                        result.success(true)
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onRequestPermissionsResult(
        requestCode: Int,
        permissions: Array<out String>,
        grantResults: IntArray,
    ) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 4107) {
            notificationResult?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
            notificationResult = null
        }
    }

    private fun notificationsGranted(): Boolean {
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) return false
        return (getSystemService(NOTIFICATION_SERVICE) as NotificationManager).areNotificationsEnabled()
    }
}
