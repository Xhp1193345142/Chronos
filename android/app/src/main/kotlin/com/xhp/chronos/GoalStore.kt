package com.xhp.chronos

import android.app.NotificationManager
import android.app.job.JobInfo
import android.app.job.JobScheduler
import android.content.ComponentName
import android.content.Context
import org.json.JSONArray
import org.json.JSONObject
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Locale
import java.util.UUID

internal object GoalStore {
    private const val PREFS = "chronos_local"
    private const val GOAL = "goal"
    private const val GOALS = "goals"
    private const val JOB_ID = 4107

    @Synchronized
    fun current(context: Context): Map<String, Any?>? = all(context).firstOrNull()

    @Synchronized
    fun all(context: Context): List<Map<String, Any?>> {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        var raw = prefs.getString(GOALS, null)
        if (raw == null) {
            val legacy = prefs.getString(GOAL, null)
            if (legacy != null) {
                raw = JSONArray().put(JSONObject(legacy).put("id", "legacy-1")).toString()
                val editor = prefs.edit().putString(GOALS, raw).remove(GOAL)
                if (prefs.contains("lastNotifiedDate")) {
                    editor.putString("lastNotifiedDate_legacy-1", prefs.getString("lastNotifiedDate", ""))
                        .remove("lastNotifiedDate")
                }
                if (prefs.contains("lastCheckedAtMillis")) {
                    editor.putLong("lastCheckedAtMillis_legacy-1", prefs.getLong("lastCheckedAtMillis", 0L))
                        .remove("lastCheckedAtMillis")
                }
                check(editor.commit()) { "Goal migration could not be saved" }
            }
        }
        if (raw == null) return emptyList()
        return try {
            val values = JSONArray(raw)
            (0 until values.length()).mapNotNull { index ->
                val value = values.optJSONObject(index) ?: return@mapNotNull null
                val id = value.optString("id")
                if (id.isBlank()) return@mapNotNull null
                val apps = value.optJSONArray("packageIds") ?: JSONArray()
                mapOf(
                    "id" to id,
                    "name" to value.optString("name", "我的目标"),
                    "packageIds" to (0 until apps.length()).map { apps.getString(it) },
                    "limitMinutes" to value.optInt("limitMinutes", 120),
                    "weekendLimitMinutes" to if (value.has("weekendLimitMinutes"))
                        value.optInt("weekendLimitMinutes") else null,
                    "tone" to value.optString("tone", "直接"),
                    "enabled" to value.optBoolean("enabled", true),
                    "pausedDate" to value.optString("pausedDate", ""),
                    "lastCheckedAtMillis" to prefs.getLong("lastCheckedAtMillis_$id", 0L),
                    "lastCheckResult" to prefs.getString("lastCheckResult_$id", "never"),
                )
            }
        } catch (_: Exception) {
            throw IllegalStateException("Local goals could not be read; original data preserved")
        }
    }

    @Synchronized
    fun save(context: Context, input: Map<*, *>): Map<String, Any?> {
        val id = (input["id"] as? String)?.takeIf { it.isNotBlank() } ?: UUID.randomUUID().toString()
        val name = (input["name"] as? String)?.trim().orEmpty().take(32)
        val ids = (input["packageIds"] as? List<*>)
            ?.filterIsInstance<String>()?.filter { it.isNotBlank() }?.distinct().orEmpty()
        val limit = (input["limitMinutes"] as? Number)?.toInt() ?: 120
        val weekendLimit = (input["weekendLimitMinutes"] as? Number)?.toInt()
        val tone = (input["tone"] as? String).takeIf { it in setOf("温和", "直接", "严格") } ?: "直接"
        val enabled = input["enabled"] as? Boolean ?: true
        require(ids.isNotEmpty()) { "Choose at least one app" }
        require(limit in 15..720 && limit % 15 == 0) { "Goal must use 15-minute steps from 15 minutes to 12 hours" }
        require(weekendLimit == null || (weekendLimit in 15..720 && weekendLimit % 15 == 0)) {
            "Weekend limit must use 15-minute steps from 15 minutes to 12 hours"
        }
        val existing = raw(context).firstOrNull { it.optString("id") == id }
        val value = JSONObject()
            .put("id", id)
            .put("name", name.ifBlank { "我的目标" })
            .put("packageIds", JSONArray(ids))
            .put("limitMinutes", limit)
            .put("tone", tone)
            .put("enabled", enabled)
            .put("pausedDate", existing?.optString("pausedDate", "") ?: "")
        if (weekendLimit != null) value.put("weekendLimitMinutes", weekendLimit)
        val goals = raw(context).filterNot { it.optString("id") == id }.toMutableList()
        goals.add(value)
        write(context, goals)
        schedule(context)
        return all(context).first { it["id"] == id }
    }

    @Synchronized
    fun setEnabled(context: Context, id: String, enabled: Boolean): Map<String, Any?>? {
        val goals = raw(context)
        val value = goals.firstOrNull { it.optString("id") == id } ?: return null
        value.put("enabled", enabled)
        if (enabled) value.put("pausedDate", "")
        write(context, goals)
        schedule(context)
        return all(context).firstOrNull { it["id"] == id }
    }

    @Synchronized
    fun pauseToday(context: Context, id: String): Map<String, Any?>? {
        val goals = raw(context)
        val value = goals.firstOrNull { it.optString("id") == id } ?: return null
        value.put("pausedDate", todayKey())
        write(context, goals)
        return all(context).firstOrNull { it["id"] == id }
    }

    @Synchronized
    fun deleteGoal(context: Context, id: String) {
        write(context, raw(context).filterNot { it.optString("id") == id })
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .remove("lastNotifiedDate_$id").remove("lastCheckedAtMillis_$id")
            .remove("lastCheckResult_$id").commit()
        (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(id.hashCode())
        (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(id, 1)
        schedule(context)
    }

    @Synchronized
    fun clear(context: Context) {
        check(context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().commit()) {
            "Local data could not be deleted"
        }
        (context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler).cancel(JOB_ID)
        (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancelAll()
    }

    @Synchronized
    fun insightPreferences(context: Context): Map<String, Any> {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        return mapOf(
            "enabled" to prefs.getBoolean("insightsEnabled", true),
            "weekRangeSuppressedUntil" to prefs.getLong("weekRangeSuppressedUntil", 0L),
        )
    }

    @Synchronized
    fun setInsightsEnabled(context: Context, enabled: Boolean): Map<String, Any> {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putBoolean("insightsEnabled", enabled).apply()
        return insightPreferences(context)
    }

    @Synchronized
    fun suppressWeekRange(context: Context): Map<String, Any> {
        val until = System.currentTimeMillis() + 30L * 24L * 60L * 60L * 1000L
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putLong("weekRangeSuppressedUntil", until).apply()
        return insightPreferences(context)
    }

    @Synchronized
    fun restoreInsights(context: Context): Map<String, Any> {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().remove("weekRangeSuppressedUntil").apply()
        return insightPreferences(context)
    }

    @Synchronized
    fun schedule(context: Context) {
        val scheduler = context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler
        if (all(context).none { it["enabled"] == true }) {
            scheduler.cancel(JOB_ID)
            return
        }
        if (scheduler.getPendingJob(JOB_ID) != null) return
        val job = JobInfo.Builder(JOB_ID, ComponentName(context, GoalCheckJobService::class.java))
            .setPeriodic(15 * 60 * 1000L)
            .setPersisted(true)
            .build()
        check(scheduler.schedule(job) == JobScheduler.RESULT_SUCCESS) { "Background check could not be scheduled" }
    }

    fun isScheduled(context: Context): Boolean =
        (context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler).getPendingJob(JOB_ID) != null

    @Synchronized
    fun recordCheck(context: Context, id: String, result: String) {
        check(context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .putLong("lastCheckedAtMillis_$id", System.currentTimeMillis())
            .putString("lastCheckResult_$id", result).commit()) { "Check status could not be saved" }
    }

    @Synchronized
    fun shouldNotify(context: Context, id: String, usedMinutes: Int): Boolean {
        val goal = all(context).firstOrNull { it["id"] == id } ?: return false
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val today = todayKey()
        return goal["enabled"] == true && goal["pausedDate"] != today &&
            usedMinutes >= effectiveLimit(goal) &&
            prefs.getString("lastNotifiedDate_$id", "") != today
    }

    @Synchronized
    fun markNotified(context: Context, id: String, day: String = todayKey()) {
        check(context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString("lastNotifiedDate_$id", day).commit()) { "Reminder status could not be saved" }
    }

    @Synchronized
    fun notifyIfEligible(context: Context, expected: Map<String, Any?>, used: Int, day: String,
        post: (Map<String, Any?>) -> Boolean): String {
        if (todayKey() != day) return "day_changed"
        val id = expected["id"] as String
        val current = all(context).firstOrNull { it["id"] == id } ?: return "changed"
        val keys = setOf("packageIds", "limitMinutes", "weekendLimitMinutes", "tone", "enabled", "pausedDate")
        if (keys.any { expected[it] != current[it] }) return "changed"
        if (!shouldNotify(context, id, used)) return when {
            current["enabled"] != true -> "disabled"
            current["pausedDate"] == day -> "paused"
            used < effectiveLimit(current) -> "below_limit"
            else -> "already_notified"
        }
        if (todayKey() != day) return "day_changed"
        if (!post(current)) return "notifications_denied"
        markNotified(context, id, day)
        return "sent"
    }

    @Synchronized
    fun effectiveLimit(goal: Map<String, Any?>): Int {
        val day = Calendar.getInstance().get(Calendar.DAY_OF_WEEK)
        val weekend = day == Calendar.SATURDAY || day == Calendar.SUNDAY
        val weekdayLimit = goal["limitMinutes"] as Int
        return if (weekend) goal["weekendLimitMinutes"] as? Int ?: weekdayLimit else weekdayLimit
    }

    private fun raw(context: Context): List<JSONObject> {
        all(context) // Validate/migrate before any read-modify-write; never replace corrupt data.
        val text = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(GOALS, "[]") ?: "[]"
        val values = JSONArray(text)
        return (0 until values.length()).map { values.getJSONObject(it) }
    }

    private fun write(context: Context, values: List<JSONObject>) {
        check(context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString(GOALS, JSONArray(values).toString()).commit()) { "Goals could not be saved" }
    }

    fun todayKey(): String = SimpleDateFormat("yyyy-MM-dd", Locale.US)
        .format(Calendar.getInstance().time)
}
