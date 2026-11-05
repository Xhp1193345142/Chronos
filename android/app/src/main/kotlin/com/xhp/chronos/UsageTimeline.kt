package com.xhp.chronos

/** Framework-independent accounting of observed foreground intervals. */
internal data class ActivityEvent(val at: Long, val kind: Int, val app: String = "", val activity: String = "")
internal data class ForegroundSlice(val app: String, val start: Long, val end: Long)
internal data class UsageBucket(val app: String, val start: Long, val end: Long, val duration: Long)

internal data class TimelineResult(val slices: List<ForegroundSlice>, val knownSince: Long?, val conflicts: List<LongRange>) {
    fun conflictsWith(start: Long, end: Long): Boolean =
        conflicts.any { !it.isEmpty() && it.first < end && it.last >= start }
    fun covers(start: Long, end: Long): Boolean = knownSince != null &&
        knownSince <= start && !conflictsWith(start, end)

    fun usage(start: Long, end: Long): Map<String, Long> {
        val totals = mutableMapOf<String, Long>()
        for (slice in slices) {
            val elapsed = minOf(end, slice.end) - maxOf(start, slice.start)
            if (elapsed > 0) totals[slice.app] = (totals[slice.app] ?: 0L) + elapsed
        }
        return totals
    }
}

internal object UsageTimeline {
    fun calendarAggregate(start: Long, end: Long, buckets: List<UsageBucket>): Map<String, Long>? {
        if (buckets.isEmpty() || buckets.any {
                it.start != start || it.end < it.start || it.end > end || it.duration !in 0..(end - start)
            }) return null
        val totals = buckets.groupBy { it.app }.mapValues { (_, values) -> values.sumOf { it.duration } }
            .filterValues { it > 0 }
        return totals.takeIf { it.isNotEmpty() && it.values.sum() <= end - start }
    }

    // Also valid on API 24–28, before the activity constants were renamed.
    const val RESUMED = 1
    const val PAUSED = 2
    const val SCREEN_ON = 15
    const val SCREEN_OFF = 16
    const val LOCKED = 17
    const val UNLOCKED = 18
    const val STOPPED = 23
    const val SHUTDOWN = 26
    const val STARTUP = 27

    fun build(events: List<ActivityEvent>, end: Long): TimelineResult {
        val slices = mutableListOf<ForegroundSlice>()
        val conflicts = mutableListOf<LongRange>()
        var uncertainFrom: Long? = null
        var knownSince: Long? = null
        var screenOn: Boolean? = null
        var locked = false
        var resumedApp: String? = null
        val activities = mutableSetOf<String>()
        var countFrom: Long? = null
        var prior = Long.MIN_VALUE

        fun stopCount(at: Long) {
            val from = countFrom
            val app = resumedApp
            if (app != null && from != null && at > from) slices.add(ForegroundSlice(app, from, at))
            countFrom = null
        }
        fun startCount(at: Long) {
            if (countFrom == null && resumedApp != null && screenOn != false && !locked) countFrom = at
        }
        fun reset(at: Long) {
            stopCount(at)
            resumedApp = null
            activities.clear()
        }
        fun resolveConflict(at: Long) {
            uncertainFrom?.let { conflicts.add(it until at) }
            uncertainFrom = null
        }

        for (event in events) {
            if (event.at >= end) continue
            if (event.at < prior) {
                conflicts.add(event.at..prior)
                reset(maxOf(countFrom ?: event.at, event.at))
                knownSince = prior
                continue
            }
            prior = event.at
            val token = event.activity.ifBlank { event.app }
            when (event.kind) {
                RESUMED -> {
                    if (event.app.isBlank()) continue
                    if (resumedApp != null && resumedApp != event.app) {
                        if (countFrom != null && uncertainFrom == null) uncertainFrom = event.at
                        reset(event.at)
                    }
                    resumedApp = event.app
                    activities.add(token)
                    startCount(event.at)
                    if (knownSince == null) knownSince = event.at
                }
                PAUSED, STOPPED -> {
                    if (event.app == resumedApp) {
                        activities.remove(token)
                        if (activities.isEmpty()) reset(event.at)
                    }
                }
                SCREEN_OFF -> {
                    resolveConflict(event.at)
                    stopCount(event.at); screenOn = false
                    if (knownSince == null) knownSince = event.at
                }
                LOCKED -> {
                    resolveConflict(event.at)
                    stopCount(event.at); locked = true
                    if (knownSince == null) knownSince = event.at
                }
                SHUTDOWN, STARTUP -> {
                    resolveConflict(event.at)
                    reset(event.at)
                    screenOn = if (event.kind == SHUTDOWN) false else null
                    locked = false
                    if (knownSince == null) knownSince = event.at
                }
                SCREEN_ON -> { screenOn = true; startCount(event.at) }
                UNLOCKED -> {
                    locked = false; screenOn = true
                    // Some devices resume the activity immediately BEFORE the
                    // unlock event. Retain it while locked and count from unlock.
                    startCount(event.at)
                }
            }
        }
        stopCount(end)
        resolveConflict(end)
        return TimelineResult(slices, knownSince, conflicts)
    }
}
