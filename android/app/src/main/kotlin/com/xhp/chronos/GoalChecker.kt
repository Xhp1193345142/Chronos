package com.xhp.chronos

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.os.Build

internal object GoalChecker {
    const val CHANNEL = "chronos_goals"
    private val lock = Any()

    fun notificationsAllowed(context: Context): Boolean {
        if (Build.VERSION.SDK_INT >= 33 && context.checkSelfPermission(
                Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return false
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        return manager.areNotificationsEnabled() &&
            (Build.VERSION.SDK_INT < 26 ||
                manager.getNotificationChannel(CHANNEL)?.importance != NotificationManager.IMPORTANCE_NONE)
    }

    fun check(context: Context, goalIds: Set<String>? = null, cancelled: () -> Boolean = { false }): Map<String, String> = synchronized(lock) {
        val results = mutableMapOf<String, String>()
        val day = GoalStore.todayKey()
        for (goal in GoalStore.all(context)) {
            if (cancelled()) break
            val id = goal["id"] as? String ?: continue
            if (goalIds != null && id !in goalIds) continue
            try {
                val result = when {
                    goal["enabled"] != true -> "disabled"
                    goal["pausedDate"] == day -> "paused"
                    !UsageReader.hasAccess(context) -> "permission_denied"
                    !notificationsAllowed(context) -> "notifications_denied"
                    else -> {
                        val ids = (goal["packageIds"] as? List<*>)?.filterIsInstance<String>()?.toSet().orEmpty()
                        val used = UsageReader.selectedMinutesToday(context, ids)
                        if (cancelled()) break
                        if (used == null) "data_unavailable" else GoalStore.notifyIfEligible(context, goal, used, day) {
                            if (cancelled() || !notificationsAllowed(context)) false
                            else { post(context, it, GoalStore.effectiveLimit(it)); true }
                        }
                    }
                }
                if (!cancelled()) {
                    GoalStore.recordCheck(context, id, result)
                    results[id] = result
                }
            } catch (_: Exception) {
                // Preserve the goal and allow other goals to be checked.
                runCatching { GoalStore.recordCheck(context, id, "error") }
                results[id] = "error"
            }
        }
        results
    }

    private fun post(context: Context, goal: Map<String, Any?>, limit: Int) {
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(NotificationChannel(CHANNEL, "目标提醒", NotificationManager.IMPORTANCE_DEFAULT))
        }
        val id = goal["id"] as String
        val name = goal["name"] as String
        val duration = when {
            limit < 60 -> "$limit 分钟"
            limit % 60 == 0 -> "${limit / 60} 小时"
            else -> "${limit / 60} 小时 ${limit % 60} 分钟"
        }
        val body = when (goal["tone"]) {
            "温和" -> "你设置的$name 今天达到 $duration 了，休息一下吗？"
            "严格" -> "$name 已达到今天的 $duration 上限。现在暂停刷屏，回到原定安排。"
            else -> "$name 已达到今天的 $duration 上限。"
        }
        val intent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
            data = Uri.parse("chronos://goal/${Uri.encode(id)}")
            putExtra("openGoal", true)
        }
        val pending = PendingIntent.getActivity(context, 0, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
        val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL)
            else Notification.Builder(context)
        val notification = builder.setSmallIcon(R.drawable.ic_notification_chronos)
            .setContentTitle("Chronos · 目标提醒")
            .setContentText(body).setStyle(Notification.BigTextStyle().bigText(body))
            .setCategory(Notification.CATEGORY_REMINDER).setVisibility(Notification.VISIBILITY_PRIVATE)
            .setContentIntent(pending).setAutoCancel(true).setOnlyAlertOnce(true).build()
        manager.notify(id, 1, notification)
    }
}
