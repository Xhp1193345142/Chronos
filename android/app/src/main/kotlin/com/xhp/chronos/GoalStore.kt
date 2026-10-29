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

    fun current(context: Context): Map<String, Any?>? = all(context).firstOrNull()

    fun all(context: Context): List<Map<String, Any?>> {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        var raw = prefs.getString(GOALS, null)
        if (raw == null) {
            val legacy = prefs.getString(GOAL, null)
            if (legacy != null) {
                raw = try {
                    JSONArray().put(JSONObject(legacy).put("id", "legacy-1")).toString()
                } catch (_: Exception) { "[]" }
                val editor = prefs.edit().putString(GOALS, raw).remove(GOAL)
                if (prefs.contains("lastNotifiedDate")) {
                    editor.putString("lastNotifiedDate_legacy-1", prefs.getString("lastNotifiedDate", ""))
                        .remove("lastNotifiedDate")
                }
                if (prefs.contains("lastCheckedAtMillis")) {
                    editor.putLong("lastCheckedAtMillis_legacy-1", prefs.getLong("lastCheckedAtMillis", 0L))
                        .remove("lastCheckedAtMillis")
                }
                editor.apply()
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
                )
            }
        } catch (_: Exception) {
            prefs.edit().remove(GOALS).apply()
            emptyList()
        }
    }

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

    fun setEnabled(context: Context, id: String, enabled: Boolean): Map<String, Any?>? {
        val goals = raw(context)
        val value = goals.firstOrNull { it.optString("id") == id } ?: return null
        value.put("enabled", enabled)
        if (enabled) value.put("pausedDate", "")
        write(context, goals)
        schedule(context)
        return all(context).firstOrNull { it["id"] == id }
    }

    fun pauseToday(context: Context, id: String): Map<String, Any?>? {
        val goals = raw(context)
        val value = goals.firstOrNull { it.optString("id") == id } ?: return null
        value.put("pausedDate", todayKey())
        write(context, goals)
        return all(context).firstOrNull { it["id"] == id }
    }

    fun deleteGoal(context: Context, id: String) {
        write(context, raw(context).filterNot { it.optString("id") == id })
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
            .remove("lastNotifiedDate_$id").remove("lastCheckedAtMillis_$id").apply()
        (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancel(id.hashCode())
        schedule(context)
    }

    fun clear(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().clear().apply()
        (context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler).cancel(JOB_ID)
        (context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager).cancelAll()
    }

    fun insightPreferences(context: Context): Map<String, Any> {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        return mapOf(
            "enabled" to prefs.getBoolean("insightsEnabled", true),
            "weekRangeSuppressedUntil" to prefs.getLong("weekRangeSuppressedUntil", 0L),
        )
    }

    fun setInsightsEnabled(context: Context, enabled: Boolean): Map<String, Any> {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putBoolean("insightsEnabled", enabled).apply()
        return insightPreferences(context)
    }

    fun suppressWeekRange(context: Context): Map<String, Any> {
        val until = System.currentTimeMillis() + 30L * 24L * 60L * 60L * 1000L
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putLong("weekRangeSuppressedUntil", until).apply()
        return insightPreferences(context)
    }

    fun restoreInsights(context: Context): Map<String, Any> {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().remove("weekRangeSuppressedUntil").apply()
        return insightPreferences(context)
    }

    fun schedule(context: Context) {
        val scheduler = context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler
        if (all(context).none { it["enabled"] == true }) {
            scheduler.cancel(JOB_ID)
            return
        }
        val job = JobInfo.Builder(JOB_ID, ComponentName(context, GoalCheckJobService::class.java))
            .setPeriodic(15 * 60 * 1000L)
            .setPersisted(true)
            .build()
        scheduler.schedule(job)
    }

    fun shouldNotify(context: Context, id: String, usedMinutes: Int): Boolean {
        val goal = all(context).firstOrNull { it["id"] == id } ?: return false
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val today = todayKey()
        prefs.edit().putLong("lastCheckedAtMillis_$id", System.currentTimeMillis()).apply()
        return goal["enabled"] == true && goal["pausedDate"] != today &&
            usedMinutes >= effectiveLimit(goal) &&
            prefs.getString("lastNotifiedDate_$id", "") != today
    }

    fun markNotified(context: Context, id: String) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString("lastNotifiedDate_$id", todayKey()).apply()
    }

    fun effectiveLimit(goal: Map<String, Any?>): Int {
        val day = Calendar.getInstance().get(Calendar.DAY_OF_WEEK)
        val weekend = day == Calendar.SATURDAY || day == Calendar.SUNDAY
        val weekdayLimit = goal["limitMinutes"] as Int
        return if (weekend) goal["weekendLimitMinutes"] as? Int ?: weekdayLimit else weekdayLimit
    }

    private fun raw(context: Context): List<JSONObject> = try {
        all(context)
        val text = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(GOALS, "[]") ?: "[]"
        val values = JSONArray(text)
        (0 until values.length()).mapNotNull { values.optJSONObject(it) }
    } catch (_: Exception) {
        emptyList()
    }

    private fun write(context: Context, values: List<JSONObject>) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString(GOALS, JSONArray(values).toString()).apply()
    }

    private fun todayKey(): String = SimpleDateFormat("yyyy-MM-dd", Locale.US)
        .format(Calendar.getInstance().time)
}
