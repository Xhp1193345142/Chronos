package com.xhp.chronos

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStats
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.pm.ApplicationInfo
import android.os.Build
import android.os.Process
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale

internal data class DailyUsage(
    val usage: Map<String, Long>, val available: Boolean, val reason: String,
    val source: String, val hourly: List<Int>?,
)

internal object UsageReader {
    fun hasAccess(context: Context): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        return appOps.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(), context.packageName) == AppOpsManager.MODE_ALLOWED
    }

    private fun midnight(): Calendar = Calendar.getInstance().apply {
        set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0)
        set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
    }

    private fun timeline(manager: UsageStatsManager, today: Calendar, now: Long): TimelineResult {
        val since = (today.clone() as Calendar).apply { add(Calendar.DAY_OF_YEAR, -8) }.timeInMillis
        val stream = manager.queryEvents(since, now) ?: return TimelineResult(emptyList(), null, emptyList())
        val event = UsageEvents.Event()
        val events = mutableListOf<ActivityEvent>()
        val kinds = setOf(1, 2, 15, 16, 17, 18, 23, 26, 27)
        while (stream.hasNextEvent()) {
            stream.getNextEvent(event)
            if (event.eventType !in kinds) continue
            if (events.size >= 200_000) return TimelineResult(emptyList(), null, emptyList())
            val activity = event.className.orEmpty()
            events.add(ActivityEvent(event.timeStamp, event.eventType, event.packageName.orEmpty(), activity))
        }
        return UsageTimeline.build(events, now)
    }

    internal fun dayUsage(
        start: Long, next: Long, now: Long, timeline: TimelineResult, stats: List<UsageStats>,
    ): DailyUsage {
        val end = minOf(next, now)
        if (timeline.covers(start, end)) {
            val totals = timeline.usage(start, end)
            val hourly = if (next - start == 86_400_000L) {
                (0 until 24).map { hour ->
                    (timeline.usage(start + hour * 3_600_000L,
                        minOf(end, start + (hour + 1) * 3_600_000L)).values.sum() / 60_000L).toInt()
                }
            } else null
            return DailyUsage(totals, true, "", "android_activity_events", hourly)
        }
        // OS queries expand to whole buckets; an 11:52 bucket is not a calendar day.
        val buckets = stats.filter { it.firstTimeStamp in start until next }
        val aligned = buckets.isNotEmpty() && buckets.all {
            it.firstTimeStamp == start && it.lastTimeStamp <= end &&
                it.totalTimeInForeground in 0..(end - start)
        }
        val totals = buckets.groupBy { it.packageName }.mapValues { (_, values) ->
            values.sumOf { it.totalTimeInForeground.coerceAtLeast(0) }
        }.filterValues { it > 0 }
        val plausible = totals.values.sum() <= end - start
        val aggregate = UsageTimeline.calendarAggregate(start, end, buckets.map {
            UsageBucket(it.packageName, it.firstTimeStamp, it.lastTimeStamp, it.totalTimeInForeground)
        })
        if (aggregate != null) {
            return DailyUsage(aggregate, true, "", "android_daily_stats", null)
        }
        val reason = when {
            timeline.conflictsWith(start, end) -> "event_conflict"
            buckets.isNotEmpty() && !aligned -> "calendar_mismatch"
            !plausible -> "unreliable"
            else -> "missing"
        }
        return DailyUsage(emptyMap(), false, reason, "", null)
    }

    fun snapshot(context: Context): Map<String, Any?> {
        if (!hasAccess(context)) return mapOf("state" to "permissionDenied")
        val manager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val now = System.currentTimeMillis()
        val today = midnight()
        val timeline = timeline(manager, today, now)
        val monthStart = (today.clone() as Calendar).apply { add(Calendar.DAY_OF_YEAR, -29) }.timeInMillis
        val stats = manager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, monthStart, now).orEmpty()
        val labels = mutableMapOf<String, String>()
        val categories = mutableMapOf<String, String>()
        val monthDays = (29 downTo 0).map { offset ->
            val day = (today.clone() as Calendar).apply { add(Calendar.DAY_OF_YEAR, -offset) }
            val start = day.timeInMillis
            val next = (day.clone() as Calendar).apply { add(Calendar.DAY_OF_YEAR, 1) }.timeInMillis
            val result = dayUsage(start, next, now, timeline, stats)
            mapOf(
                "date" to SimpleDateFormat("yyyy-MM-dd", Locale.US).format(day.time),
                "totalMinutes" to (result.usage.values.sum() / 60_000L).toInt(),
                "apps" to result.usage.entries.filter { it.value >= 60_000L }.sortedByDescending { it.value }.map { (id, millis) ->
                    mapOf("id" to id, "minutes" to (millis / 60_000L).toInt(),
                        "label" to labels.getOrPut(id) { appLabel(context, id) },
                        "category" to categories.getOrPut(id) { appCategory(context, id) })
                },
                "hourly" to if (offset <= 6) result.hourly else null,
                "available" to result.available, "reason" to result.reason, "source" to result.source,
                "complete" to (offset != 0 && result.available),
            )
        }
        val days = monthDays.takeLast(7)
        return mapOf(
            "state" to when {
                days.none { it["available"] == true } -> "empty"
                days.any { it["available"] != true } -> "partial"
                else -> "ready"
            },
            "readAtMillis" to now, "days" to days,
            "monthDays" to monthDays.map { it.filterKeys { key -> key !in setOf("apps", "hourly") } },
            "source" to "android_usage_stats",
        )
    }

    fun selectedMinutesToday(context: Context, packageIds: Set<String>): Int? {
        if (!hasAccess(context)) return null
        val manager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val now = System.currentTimeMillis()
        val day = midnight()
        val next = (day.clone() as Calendar).apply { add(Calendar.DAY_OF_YEAR, 1) }.timeInMillis
        val result = dayUsage(day.timeInMillis, next, now, timeline(manager, day, now),
            manager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, day.timeInMillis, now).orEmpty())
        if (!result.available) return null
        return (result.usage.filterKeys { it in packageIds }.values.sum() / 60_000L).toInt()
    }

    private fun appLabel(context: Context, id: String): String = try {
        val info = context.packageManager.getApplicationInfo(id, 0)
        context.packageManager.getApplicationLabel(info).toString()
    } catch (_: Exception) { id }

    private fun appCategory(context: Context, id: String): String = try {
        if (Build.VERSION.SDK_INT < 26) "其他" else when (context.packageManager.getApplicationInfo(id, 0).category) {
            ApplicationInfo.CATEGORY_GAME -> "游戏"
            ApplicationInfo.CATEGORY_AUDIO, ApplicationInfo.CATEGORY_VIDEO,
            ApplicationInfo.CATEGORY_IMAGE -> "影音娱乐"
            ApplicationInfo.CATEGORY_SOCIAL -> "社交"
            ApplicationInfo.CATEGORY_PRODUCTIVITY -> "效率"
            ApplicationInfo.CATEGORY_NEWS -> "资讯"
            else -> "其他"
        }
    } catch (_: Exception) { "其他" }
}
