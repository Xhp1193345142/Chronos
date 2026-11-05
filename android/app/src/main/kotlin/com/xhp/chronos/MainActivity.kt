package com.xhp.chronos

import android.Manifest
import android.app.NotificationManager
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import android.provider.Settings
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private var notificationResult: MethodChannel.Result? = null
    private var pendingOpenGoal = false
    private var nativeChannel: MethodChannel? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        pendingOpenGoal = intent?.getBooleanExtra("openGoal", false) == true
        super.onCreate(savedInstanceState)
        runCatching { GoalStore.schedule(this) }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        pendingOpenGoal = intent.getBooleanExtra("openGoal", false)
        setIntent(intent)
        if (pendingOpenGoal) nativeChannel?.invokeMethod("openGoal", null)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        nativeChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "chronos/native")
        nativeChannel!!.setMethodCallHandler { call, result ->
            try {
                when (call.method) {
                    "status" -> {
                        val openGoal = pendingOpenGoal
                        pendingOpenGoal = false
                        result.success(mapOf(
                            "usageGranted" to UsageReader.hasAccess(this),
                            "notificationsGranted" to GoalChecker.notificationsAllowed(this),
                            "monitorScheduled" to GoalStore.isScheduled(this),
                            "openGoal" to openGoal,
                            "platform" to "android",
                        ))
                    }
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
                            val settings = if (Build.VERSION.SDK_INT >= 26) {
                                Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS)
                                    .putExtra(Settings.EXTRA_APP_PACKAGE, packageName)
                            } else Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                                android.net.Uri.parse("package:$packageName"))
                            startActivity(settings)
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
                    "checkGoalsNow" -> Thread {
                        try {
                            GoalStore.schedule(applicationContext)
                            val checks = GoalChecker.check(applicationContext)
                            runOnUiThread { result.success(checks) }
                        } catch (error: Exception) {
                            runOnUiThread { result.error("goal_check_failed", error.message, null) }
                        }
                    }.start()
                    "getGoal" -> result.success(GoalStore.current(this))
                    "getGoals" -> result.success(GoalStore.all(this))
                    "saveGoal" -> try {
                        val input = call.arguments as? Map<*, *> ?: emptyMap<Any, Any>()
                        result.success(GoalStore.save(this, input))
                    } catch (error: Exception) {
                        result.error("invalid_goal", error.message, null)
                    }
                    "setGoalEnabled" -> result.success(
                        GoalStore.setEnabled(this, call.argument<String>("id").orEmpty(),
                            call.argument<Boolean>("enabled") == true),
                    )
                    "pauseGoalToday" -> result.success(
                        GoalStore.pauseToday(this, call.argument<String>("id").orEmpty()),
                    )
                    "deleteGoal" -> {
                        GoalStore.deleteGoal(this, call.argument<String>("id").orEmpty())
                        result.success(true)
                    }
                    "insightPreferences" -> result.success(GoalStore.insightPreferences(this))
                    "setInsightsEnabled" -> result.success(GoalStore.setInsightsEnabled(
                        this, call.argument<Boolean>("enabled") == true,
                    ))
                    "suppressWeekRange" -> result.success(GoalStore.suppressWeekRange(this))
                    "restoreInsights" -> result.success(GoalStore.restoreInsights(this))
                    "selectedGoalMinutes" -> {
                        val goalId = call.argument<String>("id").orEmpty()
                        val ids = (GoalStore.all(this).firstOrNull { it["id"] == goalId }
                            ?.get("packageIds") as? List<*>)
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
            } catch (error: Exception) {
                result.error("local_operation_failed", error.message, null)
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
