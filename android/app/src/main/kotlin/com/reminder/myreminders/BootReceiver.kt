package com.reminder.myreminders

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import android.app.AlarmManager
import android.app.PendingIntent
import android.os.Build
import java.util.Calendar

class BootReceiver : BroadcastReceiver() {
    
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == Intent.ACTION_LOCKED_BOOT_COMPLETED ||
            intent.action == "android.intent.action.QUICKBOOT_POWERON") {
            
            Log.d(TAG, "========================================")
            Log.d(TAG, "📱 DEVICE BOOTED - Action: ${intent.action}")
            Log.d(TAG, "========================================")
            
            rescheduleAll(context)
        }
    }
    
    private fun rescheduleAll(context: Context) {
        try {
            val prefs = context.getSharedPreferences("RemindMeAlarms", Context.MODE_PRIVATE)
            val activeIds = prefs.getStringSet("active_ids", emptySet()) ?: emptySet()
            
            Log.d(TAG, "Found ${activeIds.size} alarms to reschedule")
            
            var successCount = 0
            
            for (idStr in activeIds) {
                try {
                    val id = idStr.toInt()
                    val title = prefs.getString("alarm_${id}_title", null)
                    val body = prefs.getString("alarm_${id}_body", null)
                    val isRecurring = prefs.getBoolean("alarm_${id}_recurring", false)
                    val daysStr = prefs.getString("alarm_${id}_days", null)
                    val hour = prefs.getInt("alarm_${id}_hour", -1)
                    val minute = prefs.getInt("alarm_${id}_minute", -1)
                    val requiresCaptcha = prefs.getBoolean("alarm_${id}_captcha", false)
                    
                    if (title == null || body == null || hour < 0 || minute < 0) {
                        Log.w(TAG, "Incomplete data for alarm $id - skipping")
                        continue
                    }
                    
                    if (isRecurring && daysStr != null) {
                        val days = daysStr.split(",")
                            .mapNotNull { it.toIntOrNull() }
                            .toIntArray()
                        
                        if (days.isNotEmpty()) {
                            if (rescheduleAlarm(context, id, title, body, days, hour, minute, requiresCaptcha)) {
                                successCount++
                                Log.d(TAG, "✅ Rescheduled alarm $id: $body")
                            } else {
                                Log.e(TAG, "❌ Failed to reschedule alarm $id")
                            }
                        }
                    } else {
                        Log.d(TAG, "⏹️ Alarm $id is one-time - skipping")
                    }
                    
                } catch (e: Exception) {
                    Log.e(TAG, "Error rescheduling alarm $idStr", e)
                }
            }
            
            Log.d(TAG, "========================================")
            Log.d(TAG, "✅ Rescheduled $successCount/${activeIds.size} recurring alarms")
            Log.d(TAG, "========================================")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error in rescheduleAll", e)
        }
    }
    
    private fun rescheduleAlarm(
        context: Context,
        id: Int,
        title: String,
        body: String,
        days: IntArray,
        hour: Int,
        minute: Int,
        requiresCaptcha: Boolean
    ): Boolean {
        return try {
            val nextTime = findNext(days, hour, minute)
            
            if (nextTime == null) {
                Log.e(TAG, "Could not find next occurrence for alarm $id")
                return false
            }
            
            val minutesUntil = (nextTime.timeInMillis - System.currentTimeMillis()) / 60000
            Log.d(TAG, "Alarm $id will fire in $minutesUntil minutes")
            
            val alarmIntent = Intent(context, AlarmReceiver::class.java).apply {
                putExtra("id", id)
                putExtra("title", title)
                putExtra("body", body)
                putExtra("isRecurring", true)
                putExtra("selectedDays", days)
                putExtra("reminderHour", hour)
                putExtra("reminderMinute", minute)
                putExtra("requiresCaptcha", requiresCaptcha)
            }
            
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                id,
                alarmIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            
            when {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
                    val info = AlarmManager.AlarmClockInfo(nextTime.timeInMillis, pendingIntent)
                    alarmManager.setAlarmClock(info, pendingIntent)
                    Log.d(TAG, "Using setAlarmClock for alarm $id")
                }
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        nextTime.timeInMillis,
                        pendingIntent
                    )
                    Log.d(TAG, "Using setExactAndAllowWhileIdle for alarm $id")
                }
                else -> {
                    alarmManager.setExact(
                        AlarmManager.RTC_WAKEUP,
                        nextTime.timeInMillis,
                        pendingIntent
                    )
                    Log.d(TAG, "Using setExact for alarm $id")
                }
            }
            
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error scheduling alarm $id", e)
            false
        }
    }
    
    private fun findNext(days: IntArray, hour: Int, minute: Int): Calendar? {
        if (days.isEmpty()) return null
        
        val now = Calendar.getInstance()
        val currentDay = if (now.get(Calendar.DAY_OF_WEEK) == Calendar.SUNDAY) 6 else now.get(Calendar.DAY_OF_WEEK) - 2
        
        val todayAlarm = Calendar.getInstance().apply {
            set(Calendar.HOUR_OF_DAY, hour)
            set(Calendar.MINUTE, minute)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
        }
        
        if (days.contains(currentDay) && todayAlarm.timeInMillis > now.timeInMillis + 5000) {
            return todayAlarm
        }
        
        for (daysAhead in 1..7) {
            val checkDate = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_YEAR, daysAhead)
                set(Calendar.HOUR_OF_DAY, hour)
                set(Calendar.MINUTE, minute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            
            val checkDay = if (checkDate.get(Calendar.DAY_OF_WEEK) == Calendar.SUNDAY) {
                6
            } else {
                checkDate.get(Calendar.DAY_OF_WEEK) - 2
            }
            
            if (days.contains(checkDay)) {
                return checkDate
            }
        }
        
        return null
    }
    
    companion object {
        private const val TAG = "BootReceiver"
    }
}
