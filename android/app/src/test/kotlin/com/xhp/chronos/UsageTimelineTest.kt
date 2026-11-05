package com.xhp.chronos

import org.junit.Assert.*
import org.junit.Test

class UsageTimelineTest {
    @Test fun middaySystemBucketIsNotATodayTotal() {
        assertNull(UsageTimeline.calendarAggregate(0, 1000, listOf(UsageBucket("a", 500, 900, 400))))
        assertNull(UsageTimeline.calendarAggregate(0, 1000, listOf(UsageBucket("a", 0, 1100, 400))))
    }

    @Test fun alignedTotalsCannotExceedTheElapsedDay() {
        assertEquals(mapOf("a" to 200L), UsageTimeline.calendarAggregate(0, 1000,
            listOf(UsageBucket("a", 0, 900, 200))))
        assertNull(UsageTimeline.calendarAggregate(0, 1000,
            listOf(UsageBucket("a", 0, 900, 600), UsageBucket("b", 0, 900, 600))))
    }

    private fun event(at: Long, kind: Int, app: String = "a", activity: String = app) =
        ActivityEvent(at, kind, app, activity)

    @Test fun clipsAnOngoingActivityAcrossMidnight() {
        val result = UsageTimeline.build(listOf(event(50, 1)), 250)
        assertTrue(result.covers(100, 200))
        assertEquals(100L, result.usage(100, 200)["a"])
    }

    @Test fun lockAndScreenOffStopCountingWithoutAPause() {
        val result = UsageTimeline.build(listOf(event(0, 1), event(50, 17),
            event(60, 1), event(100, 18), event(110, 1), event(150, 16)), 300)
        assertEquals(100L, result.usage(0, 300)["a"])
    }

    @Test fun anOldActivityPauseDoesNotCloseItsReplacement() {
        val result = UsageTimeline.build(listOf(event(0, 1, activity = "old"),
            event(50, 1, activity = "new"), event(60, 2, activity = "old"),
            event(70, 23, activity = "old"), event(100, 2, activity = "new")), 200)
        assertEquals(100L, result.usage(0, 200)["a"])
    }

    @Test fun resumeBeforeUnlockIsCountedOnlyAfterUnlock() {
        val result = UsageTimeline.build(listOf(event(0, 17), event(50, 1),
            event(60, 18), event(100, 2)), 200)
        assertEquals(40L, result.usage(0, 200)["a"])
    }

    @Test fun duplicateResumeEventsDoNotDoubleCount() {
        val result = UsageTimeline.build(listOf(event(0, 1), event(10, 1), event(100, 2)), 200)
        assertEquals(100L, result.usage(0, 200)["a"])
    }

    @Test fun stoppedAndShutdownEventsCloseIntervals() {
        val result = UsageTimeline.build(listOf(event(0, 1), event(50, 23),
            event(100, 1), event(150, 26), event(200, 27)), 300)
        assertEquals(100L, result.usage(0, 300)["a"])
    }

    @Test fun missingHistoryIsNotAZeroDay() {
        val result = UsageTimeline.build(listOf(event(100, 1), event(150, 2)), 200)
        assertFalse(result.covers(0, 200))
        assertFalse(UsageTimeline.build(emptyList(), 200).covers(0, 200))
    }

    @Test fun missingCloseOrMultiWindowDoesNotProduceAnExactDay() {
        val result = UsageTimeline.build(listOf(event(0, 1), event(100, 1, "b")), 200)
        assertFalse(result.covers(0, 200))
        assertFalse(result.covers(101, 200))
    }

    @Test fun unresolvedConflictCrossingMidnightRemainsUnavailable() {
        val result = UsageTimeline.build(listOf(event(0, 1), event(50, 1, "b"), event(150, 16)), 300)
        assertFalse(result.covers(100, 200))
        assertTrue(result.covers(151, 300))
    }

    @Test fun backwardClockInvalidatesTheAffectedRange() {
        val result = UsageTimeline.build(listOf(event(0, 1), event(100, 2), event(50, 1)), 200)
        assertFalse(result.covers(0, 200))
    }
}
