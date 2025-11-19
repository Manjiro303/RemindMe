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
            Log.d(TAG, "📱 DEVICE BOOTED")
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
                    
                    if (title == null || body == null || hour < 0 || minute < 0) {
                        Log.w(TAG, "Incomplete data for alarm $id")
                        continue
                    }
                    
                    if (isRecurring && daysStr != null) {
                        val days = daysStr.split(",")
                            .mapNotNull { it.toIntOrNull() }
                            .toIntArray()
                        
                        if (rescheduleAlarm(context, id, title, body, days, hour, minute)) {
                            successCount++
                            Log.d(TAG, "✅ Rescheduled alarm $id: $body")
                        }
                    }
                    
                } catch (e: Exception) {
                    Log.e(TAG, "Error rescheduling alarm $idStr", e)
                }
            }
            
            Log.d(TAG, "========================================")
            Log.d(TAG, "✅ Rescheduled $successCount/${activeIds.size} alarms")
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
        minute: Int
    ): Boolean {
        return try {
            val nextTime = findNext(days, hour, minute) ?: return false
            
            val alarmIntent = Intent(context, AlarmReceiver::class.java).apply {
                putExtra("id", id)
                putExtra("title", title)
                putExtra("body", body)
                putExtra("isRecurring", true)
                putExtra("selectedDays", days)
                putExtra("reminderHour", hour)
                putExtra("reminderMinute", minute)
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
                }
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        nextTime.timeInMillis,
                        pendingIntent
                    )
                }
                else -> {
                    alarmManager.setExact(
                        AlarmManager.RTC_WAKEUP,
                        nextTime.timeInMillis,
                        pendingIntent
                    )
                }
            }
            
            true
        } catch (e: Exception) {
            Log.e(TAG, "Error scheduling alarm $id", e)
            false
        }
    }
    
    // CRITICAL FIX: Changed from 30000 to 10000
    private fun findNext(days: IntArray, hour: Int, minute: Int): Calendar? {
        if (days.isEmpty()) return null
        
        val now = Calendar.getInstance()
        
        for (daysAhead in 0..7) {
            val check = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_YEAR, daysAhead)
                set(Calendar.HOUR_OF_DAY, hour)
                set(Calendar.MINUTE, minute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            
            // CRITICAL FIX: Changed from 30000 to 10000
            if (check.timeInMillis <= now.timeInMillis + 10000) {
                continue
            }
            
            val dayOfWeek = when (check.get(Calendar.DAY_OF_WEEK)) {
                Calendar.MONDAY -> 0
                Calendar.TUESDAY -> 1
                Calendar.WEDNESDAY -> 2
                Calendar.THURSDAY -> 3
                Calendar.FRIDAY -> 4
                Calendar.SATURDAY -> 5
                Calendar.SUNDAY -> 6
                else -> -1
            }
            
            if (days.contains(dayOfWeek)) {
                return check
            }
        }
        
        return null
    }
    
    companion object {
        private const val TAG = "BootReceiver"
    }
}
