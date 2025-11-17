package com.reminder.myreminders

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.RingtoneManager
import android.media.Ringtone
import android.os.Build
import androidx.core.app.NotificationCompat
import android.app.PendingIntent
import android.os.PowerManager
import android.app.AlarmManager
import java.util.Calendar

class AlarmReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "AlarmReceiver"
        private var ringtone: Ringtone? = null
        
        fun stopRingtone() {
            try {
                ringtone?.stop()
                ringtone = null
                Log.d(TAG, "Ringtone stopped")
            } catch (e: Exception) {
                Log.e(TAG, "Error stopping ringtone: ${e.message}")
            }
        }
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "========================================")
        Log.d(TAG, "🔔 ALARM BROADCAST RECEIVED!!!")
        Log.d(TAG, "Action: ${intent.action}")
        Log.d(TAG, "========================================")
        
        // Handle dismiss action
        if (intent.action == "DISMISS_ALARM") {
            stopRingtone()
            return
        }
        
        // Acquire wake lock to ensure processing completes
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK,
            "RemindMe::AlarmWakeLock"
        )
        wakeLock.acquire(60000) // 60 seconds max
        
        try {
            // Extract alarm data
            val id = intent.getIntExtra("id", 0)
            val title = intent.getStringExtra("title") ?: "Reminder"
            val body = intent.getStringExtra("body") ?: "Alarm"
            val isRecurring = intent.getBooleanExtra("isRecurring", false)
            val days = intent.getIntArrayExtra("selectedDays") ?: intArrayOf()
            val hour = intent.getIntExtra("reminderHour", 0)
            val minute = intent.getIntExtra("reminderMinute", 0)
            
            Log.d(TAG, "Alarm Details:")
            Log.d(TAG, "  ID: $id")
            Log.d(TAG, "  Title: $title")
            Log.d(TAG, "  Body: $body")
            Log.d(TAG, "  Recurring: $isRecurring")
            Log.d(TAG, "  Days: ${days.joinToString()}")
            Log.d(TAG, "  Time: $hour:$minute")
            
            // 1. Play sound immediately
            playSound(context)
            
            // 2. Show notification
            showNotification(context, id, title, body)
            
            // 3. Handle recurring alarms
            if (isRecurring && days.isNotEmpty()) {
                Log.d(TAG, "🔄 Scheduling next occurrence...")
                scheduleNextAlarm(context, id, title, body, days, hour, minute)
            } else {
                Log.d(TAG, "⏹️ One-time alarm - not rescheduling")
            }
            
            Log.d(TAG, "✅ Alarm processing complete")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error in onReceive", e)
        } finally {
            if (wakeLock.isHeld) {
                wakeLock.release()
            }
        }
    }
    
    private fun playSound(context: Context) {
        try {
            stopRingtone() // Stop any existing ringtone
            
            // Get alarm sound URI
            var uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            if (uri == null) {
                uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            }
            if (uri == null) {
                uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            }
            
            if (uri != null) {
                ringtone = RingtoneManager.getRingtone(context, uri)
                if (ringtone != null) {
                    ringtone?.play()
                    Log.d(TAG, "🎵 Playing alarm sound: $uri")
                } else {
                    Log.e(TAG, "❌ Failed to get Ringtone object")
                }
            } else {
                Log.e(TAG, "❌ No sound URI available")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error playing sound", e)
        }
    }
    
    private fun showNotification(context: Context, id: Int, title: String, body: String) {
        try {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            
            // Create notification channel (Android O+)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    "alarm_channel",
                    "Alarms",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Alarm notifications"
                    enableVibration(true)
                    vibrationPattern = longArrayOf(0, 500, 200, 500)
                    setSound(
                        RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM),
                        null
                    )
                }
                notificationManager.createNotificationChannel(channel)
            }
            
            // Intent to open app
            val openIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                action = "OPEN_ALARM"
                putExtra("alarm_id", id)
                putExtra("alarm_body", body)
            }
            
            val openPendingIntent = PendingIntent.getActivity(
                context,
                id,
                openIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            // Intent to dismiss alarm
            val dismissIntent = Intent(context, AlarmReceiver::class.java).apply {
                action = "DISMISS_ALARM"
            }
            
            val dismissPendingIntent = PendingIntent.getBroadcast(
                context,
                id + 10000,
                dismissIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            // Build notification
            val notification = NotificationCompat.Builder(context, "alarm_channel")
                .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                .setContentTitle("⏰ $title")
                .setContentText(body)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_ALARM)
                .setAutoCancel(true)
                .setOngoing(true)
                .setVibrate(longArrayOf(0, 500, 200, 500))
                .setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM))
                .setContentIntent(openPendingIntent)
                .setFullScreenIntent(openPendingIntent, true)
                .addAction(0, "Dismiss", dismissPendingIntent)
                .build()
            
            notificationManager.notify(id, notification)
            Log.d(TAG, "✅ Notification displayed (ID: $id)")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error showing notification", e)
        }
    }
    
    private fun scheduleNextAlarm(
        context: Context,
        id: Int,
        title: String,
        body: String,
        days: IntArray,
        hour: Int,
        minute: Int
    ) {
        try {
            val nextTime = findNextAlarmTime(days, hour, minute)
            
            if (nextTime == null) {
                Log.e(TAG, "❌ Could not find next alarm time")
                return
            }
            
            val minutesUntilNext = (nextTime.timeInMillis - System.currentTimeMillis()) / 60000
            Log.d(TAG, "📅 Next alarm: ${nextTime.time}")
            Log.d(TAG, "⏱️  In $minutesUntilNext minutes")
            
            // Create intent for next alarm
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
            
            // Use setAlarmClock for maximum reliability
            val alarmClockInfo = AlarmManager.AlarmClockInfo(
                nextTime.timeInMillis,
                pendingIntent
            )
            alarmManager.setAlarmClock(alarmClockInfo, pendingIntent)
            
            Log.d(TAG, "✅ Next alarm scheduled successfully")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error scheduling next alarm", e)
        }
    }
    
    private fun findNextAlarmTime(days: IntArray, hour: Int, minute: Int): Calendar? {
        if (days.isEmpty()) {
            Log.e(TAG, "No days selected for recurring alarm")
            return null
        }
        
        val now = Calendar.getInstance()
        
        // Check next 8 days (including today if time hasn't passed yet)
        for (daysToAdd in 0..7) {
            val candidate = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_YEAR, daysToAdd)
                set(Calendar.HOUR_OF_DAY, hour)
                set(Calendar.MINUTE, minute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            
            // Skip if time is in the past
            if (candidate.timeInMillis <= now.timeInMillis) {
                continue
            }
            
            // Convert day of week to our format (Mon=0, Sun=6)
            val dayOfWeek = when (candidate.get(Calendar.DAY_OF_WEEK)) {
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
                Log.d(TAG, "   ✓ Found next occurrence: ${candidate.time} (day $dayOfWeek)")
                return candidate
            }
        }
        
        Log.e(TAG, "Could not find next occurrence in next 8 days")
        return null
    }
}
