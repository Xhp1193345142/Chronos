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

internal object GoalStore {
    private const val PREFS = "chronos_local"
    private const val GOAL = "goal"
    private const val JOB_ID = 4107

    fun current(context: Context): Map<String, Any?>? {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val raw = prefs.getString(GOAL, null) ?: return null
        return try {
            val value = JSONObject(raw)
            val apps = value.optJSONArray("packageIds") ?: JSONArray()
            mapOf(
                "name" to value.optString("name", "我的目标"),
                "packageIds" to (0 until apps.length()).map { apps.getString(it) },
                "limitMinutes" to value.optInt("limitMinutes", 120),
                "tone" to value.optString("tone", "直接"),
                "enabled" to value.optBoolean("enabled", true),
                "pausedDate" to value.optString("pausedDate", ""),
                "lastCheckedAtMillis" to prefs.getLong("lastCheckedAtMillis", 0L),
            )
        } catch (_: Exception) {
            prefs.edit().remove(GOAL).apply()
            null
        }
    }

    fun save(context: Context, input: Map<*, *>): Map<String, Any?> {
        val name = (input["name"] as? String)?.trim().orEmpty().take(32)
        val ids = (input["packageIds"] as? List<*>)
            ?.filterIsInstance<String>()?.filter { it.isNotBlank() }?.distinct().orEmpty()
        val limit = (input["limitMinutes"] as? Number)?.toInt() ?: 120
        val tone = (input["tone"] as? String).takeIf { it in setOf("温和", "直接", "严格") } ?: "直接"
        val enabled = input["enabled"] as? Boolean ?: true
        require(ids.isNotEmpty()) { "Choose at least one app" }
        require(limit in 15..720 && limit % 15 == 0) { "Goal must use 15-minute steps from 15 minutes to 12 hours" }
        val value = JSONObject()
            .put("name", name.ifBlank { "我的目标" })
            .put("packageIds", JSONArray(ids))
            .put("limitMinutes", limit)
            .put("tone", tone)
            .put("enabled", enabled)
            .put("pausedDate", "")
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString(GOAL, value.toString()).apply()
        schedule(context)
        return current(context)!!
    }

    fun setEnabled(context: Context, enabled: Boolean): Map<String, Any?>? {
        val value = raw(context) ?: return null
        value.put("enabled", enabled)
        if (enabled) value.put("pausedDate", "")
        write(context, value)
        schedule(context)
        return current(context)
    }

    fun pauseToday(context: Context): Map<String, Any?>? {
        val value = raw(context) ?: return null
        value.put("pausedDate", todayKey())
        write(context, value)
        return current(context)
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
        val goal = current(context)
        val scheduler = context.getSystemService(Context.JOB_SCHEDULER_SERVICE) as JobScheduler
        if (goal == null || goal["enabled"] != true) {
            scheduler.cancel(JOB_ID)
            return
        }
        val job = JobInfo.Builder(JOB_ID, ComponentName(context, GoalCheckJobService::class.java))
            .setPeriodic(15 * 60 * 1000L)
            .setPersisted(true)
            .build()
        scheduler.schedule(job)
    }

    fun shouldNotify(context: Context, usedMinutes: Int): Boolean {
        val goal = current(context) ?: return false
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val today = todayKey()
        prefs.edit().putLong("lastCheckedAtMillis", System.currentTimeMillis()).apply()
        return goal["enabled"] == true && goal["pausedDate"] != today &&
            goal["limitMinutes"] is Int && usedMinutes >= goal["limitMinutes"] as Int &&
            prefs.getString("lastNotifiedDate", "") != today
    }

    fun markNotified(context: Context) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString("lastNotifiedDate", todayKey()).apply()
    }

    private fun raw(context: Context): JSONObject? = try {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(GOAL, null)
            ?.let(::JSONObject)
    } catch (_: Exception) {
        null
    }

    private fun write(context: Context, value: JSONObject) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit().putString(GOAL, value.toString()).apply()
    }

    private fun todayKey(): String = SimpleDateFormat("yyyy-MM-dd", Locale.US)
        .format(Calendar.getInstance().time)
}
