package com.xhp.chronos

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class MonitorRecoveryReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action !in setOf(Intent.ACTION_BOOT_COMPLETED, Intent.ACTION_MY_PACKAGE_REPLACED,
                Intent.ACTION_TIME_CHANGED, Intent.ACTION_TIMEZONE_CHANGED)) return
        val pending = goAsync()
        Thread {
            try { GoalStore.schedule(context) } catch (_: Exception) {
                // Keep unreadable data intact; the UI reports the read failure.
            } finally { pending.finish() }
        }.start()
    }
}
