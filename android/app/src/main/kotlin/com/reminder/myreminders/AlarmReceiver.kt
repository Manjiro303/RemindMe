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
import android.os.VibrationEffect
import android.os.Vibrator
import java.util.Calendar

class AlarmReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "AlarmReceiver"
        private var ringtone: Ringtone? = null
        
        fun stopRingtone() {
            try {
                ringtone?.stop()
                ringtone = null
                Log.d(TAG, "🔇 Ringtone stopped")
            } catch (e: Exception) {
                Log.e(TAG, "Error stopping ringtone: ${e.message}")
            }
        }
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "========================================")
        Log.d(TAG, "🔔 ALARM RECEIVED!")
        Log.d(TAG, "========================================")
        
        if (intent.action == "DISMISS_ALARM") {
            stopRingtone()
            return
        }
        
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val wakeLock = powerManager.newWakeLock(
            PowerManager.FULL_WAKE_LOCK or 
            PowerManager.ACQUIRE_CAUSES_WAKEUP or 
            PowerManager.ON_AFTER_RELEASE,
            "RemindMe::FullWakeLock"
        )
        wakeLock.acquire(60000)
        
        try {
            val id = intent.getIntExtra("id", 0)
            val title = intent.getStringExtra("title") ?: "Reminder"
            val body = intent.getStringExtra("body") ?: "Time's up!"
            val isRecurring = intent.getBooleanExtra("isRecurring", false)
            val days = intent.getIntArrayExtra("selectedDays") ?: intArrayOf()
            val hour = intent.getIntExtra("reminderHour", 0)
            val minute = intent.getIntExtra("reminderMinute", 0)
            
            Log.d(TAG, "ID: $id")
            Log.d(TAG, "Title: $title")
            Log.d(TAG, "Body: $body")
            Log.d(TAG, "Recurring: $isRecurring")
            
            if (isRecurring && days.isNotEmpty()) {
                Log.d(TAG, "🔄 Scheduling next occurrence...")
                val scheduled = scheduleNextAlarm(context, id, title, body, days, hour, minute)
                if (scheduled) {
                    Log.d(TAG, "✅ Next alarm scheduled")
                } else {
                    Log.e(TAG, "❌ Failed to schedule next alarm")
                }
            } else {
                Log.d(TAG, "⏹️ One-time alarm - removing from storage")
                removeFromStorage(context, id)
            }
            
            showFullScreenNotification(context, id, title, body)
            playAlarmSound(context)
            vibrateDevice(context)
            
            Log.d(TAG, "✅ Alarm processing complete")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ ERROR in onReceive", e)
            e.printStackTrace()
        } finally {
            if (wakeLock.isHeld) {
                wakeLock.release()
            }
        }
        
        Log.d(TAG, "========================================")
    }
    
    private fun scheduleNextAlarm(
        context: Context,
        id: Int,
        title: String,
        body: String,
        days: IntArray,
        hour: Int,
        minute: Int
    ): Boolean {
        return try {
            val nextTime = findNextOccurrence(days, hour, minute)
            
            if (nextTime == null) {
                Log.e(TAG, "Could not find next occurrence")
                return false
            }
            
            val minutesUntil = (nextTime.timeInMillis - System.currentTimeMillis()) / 60000
            Log.d(TAG, "Next alarm in $minutesUntil minutes: ${nextTime.time}")
            
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
            Log.e(TAG, "Error scheduling next alarm", e)
            false
        }
    }
    
    // CRITICAL FIX: Changed from 30000 to 10000
    private fun findNextOccurrence(days: IntArray, hour: Int, minute: Int): Calendar? {
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
    
    // CRITICAL FIX: Updated intent extras
    private fun showFullScreenNotification(context: Context, id: Int, title: String, body: String) {
        try {
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    "alarm_channel",
                    "Alarms",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Alarm notifications"
                    enableVibration(true)
                    setBypassDnd(true)
                    lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
                    setSound(
                        RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM),
                        null
                    )
                }
                notificationManager.createNotificationChannel(channel)
            }
            
            // CRITICAL FIX: Updated intent with proper extras
            val openIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                       Intent.FLAG_ACTIVITY_CLEAR_TOP or
                       Intent.FLAG_ACTIVITY_SINGLE_TOP
                action = "OPEN_ALARM"
                putExtra("notification_id", id)
                putExtra("alarm_body", body)
            }
            
            val openPendingIntent = PendingIntent.getActivity(
                context,
                id,
                openIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            val dismissIntent = Intent(context, AlarmReceiver::class.java).apply {
                action = "DISMISS_ALARM"
            }
            
            val dismissPendingIntent = PendingIntent.getBroadcast(
                context,
                id + 10000,
                dismissIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            val notification = NotificationCompat.Builder(context, "alarm_channel")
                .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                .setContentTitle("⏰ $title")
                .setContentText(body)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_ALARM)
                .setAutoCancel(false)
                .setOngoing(true)
                .setVibrate(longArrayOf(0, 1000, 500, 1000, 500, 1000))
                .setContentIntent(openPendingIntent)
                .setFullScreenIntent(openPendingIntent, true)
                .addAction(0, "Dismiss", dismissPendingIntent)
                .build()
            
            notificationManager.notify(id, notification)
            Log.d(TAG, "📱 Notification shown with ID: $id")
            
        } catch (e: Exception) {
            Log.e(TAG, "Error showing notification", e)
        }
    }
    
    private fun playAlarmSound(context: Context) {
        try {
            stopRingtone()
            
            val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            
            if (uri != null) {
                ringtone = RingtoneManager.getRingtone(context, uri)
                ringtone?.play()
                Log.d(TAG, "🎵 Sound playing")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error playing sound", e)
        }
    }
    
    private fun vibrateDevice(context: Context) {
        try {
            val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(
                    VibrationEffect.createWaveform(
                        longArrayOf(0, 500, 200, 500, 200, 500),
                        -1
                    )
                )
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(longArrayOf(0, 500, 200, 500, 200, 500), -1)
            }
            Log.d(TAG, "📳 Vibrating")
        } catch (e: Exception) {
            Log.e(TAG, "Error vibrating", e)
        }
    }
    
    private fun removeFromStorage(context: Context, id: Int) {
        val prefs = context.getSharedPreferences("RemindMeAlarms", Context.MODE_PRIVATE)
        val editor = prefs.edit()
        
        editor.remove("alarm_${id}_title")
        editor.remove("alarm_${id}_body")
        editor.remove("alarm_${id}_recurring")
        editor.remove("alarm_${id}_days")
        editor.remove("alarm_${id}_hour")
        editor.remove("alarm_${id}_minute")
        
        val ids = prefs.getStringSet("active_ids", mutableSetOf()) ?: mutableSetOf()
        val newIds = ids.toMutableSet()
        newIds.remove(id.toString())
        editor.putStringSet("active_ids", newIds)
        
        editor.apply()
    }
}
