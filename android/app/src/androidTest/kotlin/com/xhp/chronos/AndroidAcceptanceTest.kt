package com.xhp.chronos

import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.os.Bundle
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import org.junit.Assert.*
import org.junit.Assume.assumeTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.util.UUID

/** Opt-in device checks. Never clear user data or print app history. */
@RunWith(AndroidJUnit4::class)
class AndroidAcceptanceTest {
    @Test fun realUsageThresholdBackgroundJobAndDedupe() {
        val instrumentation = InstrumentationRegistry.getInstrumentation()
        val context = instrumentation.targetContext
        assumeTrue("Usage permission required", UsageReader.hasAccess(context))
        assumeTrue("Notification permission/channel required", GoalChecker.notificationsAllowed(context))
        val snapshot = UsageReader.snapshot(context)
        val today = (snapshot["days"] as List<*>).last() as Map<*, *>
        instrumentation.sendStatus(0, Bundle().apply {
            putString("chronos_quality", "available=${today["available"]}; source=${today["source"]}; reason=${today["reason"]}")
        })
        assertEquals("Today's real usage must be verifiable", true, today["available"])
        val used = UsageReader.selectedMinutesToday(context, setOf(context.packageName))
        assumeTrue("At least 15 minutes of actual Chronos usage is required", used != null && used >= 15)
        val id = "acceptance-${UUID.randomUUID()}"
        val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        try {
            GoalStore.save(context, mapOf("id" to id, "name" to "提醒验收（临时）",
                "packageIds" to listOf(context.packageName), "limitMinutes" to 15,
                "tone" to "温和", "enabled" to true))
            assertTrue(GoalStore.isScheduled(context))
            context.startActivity(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            instrumentation.uiAutomation.executeShellCommand("cmd jobscheduler run -f ${context.packageName} 4107").use { }
            val deadline = System.currentTimeMillis() + 15_000L
            while (System.currentTimeMillis() < deadline &&
                GoalStore.all(context).first { it["id"] == id }["lastCheckResult"] != "sent") {
                Thread.sleep(100)
            }
            assertEquals("sent", GoalStore.all(context).first { it["id"] == id }["lastCheckResult"])
            val first = manager.activeNotifications.single { it.tag == id }
            assertEquals("already_notified", GoalChecker.check(context, setOf(id))[id])
            assertEquals(first.postTime, manager.activeNotifications.single { it.tag == id }.postTime)
            // Exercise the actual PendingIntent rather than fabricating a Flutter route.
            first.notification.contentIntent.send()
            instrumentation.sendStatus(0, Bundle().apply {
                putString("chronos_reminder", "background_job=sent; second_check=deduplicated; pending_intent=opened")
            })
        } finally {
            GoalStore.deleteGoal(context, id)
        }
    }
}
