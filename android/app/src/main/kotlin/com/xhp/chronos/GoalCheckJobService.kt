package com.xhp.chronos

import android.app.job.JobParameters
import android.app.job.JobService
import java.util.concurrent.atomic.AtomicBoolean

class GoalCheckJobService : JobService() {
    private var cancellation: AtomicBoolean? = null

    override fun onStartJob(params: JobParameters): Boolean {
        cancellation?.set(true)
        val cancelled = AtomicBoolean(false)
        cancellation = cancelled
        Thread {
            try {
                GoalChecker.check(this) { cancelled.get() }
            } catch (_: Exception) {
                // Unreadable goals stay intact and are reported by the app.
            } finally {
                if (!cancelled.get()) jobFinished(params, false)
            }
        }.start()
        return true
    }

    override fun onStopJob(params: JobParameters): Boolean {
        cancellation?.set(true)
        return true
    }
}
