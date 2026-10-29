package com.xhp.chronos

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.job.JobParameters
import android.app.job.JobService
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build

class GoalCheckJobService : JobService() {
    override fun onStartJob(params: JobParameters): Boolean {
        Thread {
            try {
                val goal = GoalStore.current(this)
                val ids = (goal?.get("packageIds") as? List<*>)
                    ?.filterIsInstance<String>()?.toSet().orEmpty()
                if (ids.isNotEmpty()) {
                    val used = UsageReader.selectedMinutesToday(this, ids)
                    if (used != null && GoalStore.shouldNotify(this, used) && notificationsAllowed()) {
                        postNotification(goal!!)
                        GoalStore.markNotified(this)
                    }
                }
            } catch (_: Exception) {
                // A failed usage query must not crash the process or mark a reminder as sent.
            } finally {
                jobFinished(params, false)
            }
        }.start()
        return true
    }

    override fun onStopJob(params: JobParameters): Boolean = false

    private fun notificationsAllowed(): Boolean {
        if (Build.VERSION.SDK_INT >= 33 &&
            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) return false
        return (getSystemService(NOTIFICATION_SERVICE) as NotificationManager).areNotificationsEnabled()
    }

    private fun postNotification(goal: Map<String, Any?>) {
        val manager = getSystemService(NOTIFICATION_SERVICE) as NotificationManager
        val channel = "chronos_goals"
        manager.createNotificationChannel(
            NotificationChannel(channel, "目标提醒", NotificationManager.IMPORTANCE_DEFAULT),
        )
        val name = goal["name"] as String
        val limit = goal["limitMinutes"] as Int
        val duration = when {
            limit < 60 -> "$limit 分钟"
            limit % 60 == 0 -> "${limit / 60} 小时"
            else -> "${limit / 60} 小时 ${limit % 60} 分钟"
        }
        val body = when (goal["tone"]) {
            "温和" -> "你设置的$name 今天达到 $duration 了，休息一下吗？"
            "严格" -> "你已达到自己设置的 $duration 上限。现在暂停刷屏，回到原定安排。"
            else -> "$name 已达到今天的 $duration 上限。"
        }
        val intent = PendingIntent.getActivity(
            this,
            0,
            Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_SINGLE_TOP or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("openGoal", true)
            },
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val notification = Notification.Builder(this, channel)
            .setSmallIcon(R.mipmap.ic_launcher)
            .setContentTitle("Chronos · 目标提醒")
            .setContentText(body)
            .setStyle(Notification.BigTextStyle().bigText(body))
            .setContentIntent(intent)
            .setAutoCancel(true)
            .build()
        manager.notify(4107, notification)
    }
}
