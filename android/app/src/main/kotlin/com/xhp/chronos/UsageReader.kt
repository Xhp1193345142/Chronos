package com.xhp.chronos

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.pm.ApplicationInfo
import android.os.Process
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import kotlin.math.abs
import kotlin.math.max
import kotlin.math.min

internal object UsageReader {
    fun hasAccess(context: Context): Boolean {
        val appOps = context.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        return appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS,
            Process.myUid(),
            context.packageName,
        ) == AppOpsManager.MODE_ALLOWED
    }

    fun snapshot(context: Context): Map<String, Any?> {
        if (!hasAccess(context)) return mapOf("state" to "permissionDenied")
        val manager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val now = System.currentTimeMillis()
        val today = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        val monthDays = (29 downTo 0).map { offset ->
            val day = (today.clone() as Calendar).apply { add(Calendar.DAY_OF_YEAR, -offset) }
            val start = day.timeInMillis
            val next = (day.clone() as Calendar).apply { add(Calendar.DAY_OF_YEAR, 1) }.timeInMillis
            val end = min(now, next)
            val rawStats = manager.queryUsageStats(UsageStatsManager.INTERVAL_DAILY, start, end)
                .orEmpty()
                .filter { it.firstTimeStamp >= start && it.firstTimeStamp < next }
            val usage = rawStats
                .groupBy { it.packageName }
                .mapValues { (_, values) -> values.sumOf { max(0, it.totalTimeInForeground) } }
                .filterValues { it >= 60_000L }
            val totalMillis = usage.values.sum()
            val interactiveMillis = manager.queryEventStats(
                UsageStatsManager.INTERVAL_DAILY, start, end,
            ).orEmpty().filter { it.eventType == UsageEvents.Event.SCREEN_INTERACTIVE }
                .sumOf { max(0, it.totalTime) }
            val plausible = if (interactiveMillis > 0) {
                totalMillis <= (interactiveMillis * 1.2).toLong() + 300_000L
            } else totalMillis <= 18L * 60L * 60L * 1000L
            val available = rawStats.any { it.totalTimeInForeground > 0 } && plausible
            val apps = usage.entries.sortedByDescending { it.value }.map { (id, millis) ->
                mapOf(
                    "id" to id,
                    "label" to appLabel(context, id),
                    "minutes" to (millis / 60_000L).toInt(),
                    "category" to appCategory(context, id),
                )
            }
            val hourly = if (available && offset <= 6 && next - start == 86_400_000L) {
                hourlyFromEvents(manager, start, end, totalMillis)
            } else null
            mapOf(
                "date" to SimpleDateFormat("yyyy-MM-dd", Locale.US).format(day.time),
                "totalMinutes" to (totalMillis / 60_000L).toInt(),
                "apps" to apps,
                "hourly" to hourly,
                "available" to available,
                "reason" to if (!plausible) "unreliable" else if (!available) "missing" else "",
                "complete" to (offset != 0 && available),
            )
        }
        val days = monthDays.takeLast(7)
        return mapOf(
            "state" to when {
                days.none { it["available"] == true } -> "empty"
                days.any { it["available"] != true } -> "partial"
                else -> "ready"
            },
            "readAtMillis" to now,
            "days" to days,
            "monthDays" to monthDays.map { day ->
                mapOf(
                    "date" to day["date"],
                    "totalMinutes" to day["totalMinutes"],
                    "available" to day["available"],
                    "reason" to day["reason"],
                    "complete" to day["complete"],
                )
            },
            "source" to "android_usage_stats",
        )
    }

    fun selectedMinutesToday(context: Context, packageIds: Set<String>): Int? {
        if (!hasAccess(context)) return null
        val manager = context.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val start = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, 0)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }.timeInMillis
        val usage = manager.queryUsageStats(
            UsageStatsManager.INTERVAL_DAILY,
            start,
            System.currentTimeMillis(),
        ).orEmpty()
        val selectedMillis = usage.filter { it.firstTimeStamp >= start && it.packageName in packageIds }
            .sumOf { max(0, it.totalTimeInForeground) }
        val interactiveMillis = manager.queryEventStats(
            UsageStatsManager.INTERVAL_DAILY, start, System.currentTimeMillis(),
        ).orEmpty().filter { it.eventType == UsageEvents.Event.SCREEN_INTERACTIVE }
            .sumOf { max(0, it.totalTime) }
        if (interactiveMillis > 0 &&
            selectedMillis > (interactiveMillis * 1.2).toLong() + 300_000L
        ) return null
        return (selectedMillis / 60_000L).toInt()
    }

    private fun hourlyFromEvents(
        manager: UsageStatsManager,
        start: Long,
        end: Long,
        aggregateMillis: Long,
    ): List<Int>? {
        if (aggregateMillis < 60_000L) return null
        val buckets = LongArray(24)
        val events = manager.queryEvents(start, end) ?: return null
        val event = UsageEvents.Event()
        var currentPackage: String? = null
        var currentStart = start

        fun close(at: Long) {
            if (currentPackage == null || at <= currentStart) return
            var cursor = currentStart
            val stop = min(at, end)
            while (cursor < stop) {
                val hour = Calendar.getInstance().apply { timeInMillis = cursor }
                    .get(Calendar.HOUR_OF_DAY)
                val nextHour = Calendar.getInstance().apply {
                    timeInMillis = cursor
                    set(Calendar.MINUTE, 0)
                    set(Calendar.SECOND, 0)
                    set(Calendar.MILLISECOND, 0)
                    add(Calendar.HOUR_OF_DAY, 1)
                }.timeInMillis
                val segmentEnd = min(stop, nextHour)
                buckets[hour] += segmentEnd - cursor
                cursor = segmentEnd
            }
            currentPackage = null
        }

        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            when (event.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED -> {
                    if (currentPackage != event.packageName) close(event.timeStamp)
                    if (currentPackage == null) {
                        currentPackage = event.packageName
                        currentStart = max(start, event.timeStamp)
                    }
                }
                UsageEvents.Event.ACTIVITY_PAUSED -> {
                    if (currentPackage == event.packageName) close(event.timeStamp)
                }
                UsageEvents.Event.SCREEN_NON_INTERACTIVE -> close(event.timeStamp)
            }
        }
        close(end)
        val eventMillis = buckets.sum()
        if (abs(eventMillis - aggregateMillis) > max(300_000L, aggregateMillis / 5)) return null
        return buckets.map { (it / 60_000L).toInt().coerceIn(0, 60) }
    }

    private fun appLabel(context: Context, id: String): String = try {
        val info = context.packageManager.getApplicationInfo(id, 0)
        context.packageManager.getApplicationLabel(info).toString()
    } catch (_: Exception) {
        id
    }

    private fun appCategory(context: Context, id: String): String = try {
        val info = context.packageManager.getApplicationInfo(id, 0)
        when (info.category) {
            ApplicationInfo.CATEGORY_GAME -> "游戏"
            ApplicationInfo.CATEGORY_AUDIO, ApplicationInfo.CATEGORY_VIDEO,
            ApplicationInfo.CATEGORY_IMAGE -> "影音娱乐"
            ApplicationInfo.CATEGORY_SOCIAL -> "社交"
            ApplicationInfo.CATEGORY_PRODUCTIVITY -> "效率"
            ApplicationInfo.CATEGORY_NEWS -> "资讯"
            else -> "其他"
        }
    } catch (_: Exception) {
        "其他"
    }
}
