package com.reminder.myreminders

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.RingtoneManager
import android.media.Ringtone
import android.net.Uri
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
            ringtone?.stop()
            ringtone = null
        }
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "========================================")
        Log.d(TAG, "🔔 ALARM FIRED!!!")
        Log.d(TAG, "========================================")
        
        if (intent.action == "DISMISS") {
            stopRingtone()
            return
        }
        
        val wakeLock = (context.getSystemService(Context.POWER_SERVICE) as PowerManager)
            .newWakeLock(PowerManager.PARTIAL_WAKE_LOCK, "RemindMe::WakeLock")
        wakeLock.acquire(60000)
        
        try {
            val id = intent.getIntExtra("id", 0)
            val title = intent.getStringExtra("title") ?: "Reminder"
            val body = intent.getStringExtra("body") ?: "Alarm"
            
            // ✅ FIX: Use correct key names that match MainActivity
            val isRecurring = intent.getBooleanExtra("isRecurring", false)
            val days = intent.getIntArrayExtra("selectedDays") ?: intArrayOf()
            val hour = intent.getIntExtra("reminderHour", 0)
            val minute = intent.getIntExtra("reminderMinute", 0)
            
            Log.d(TAG, "ID: $id")
            Log.d(TAG, "Title: $title")
            Log.d(TAG, "Body: $body")
            Log.d(TAG, "Recurring: $isRecurring")
            Log.d(TAG, "Days: ${days.joinToString()}")
            Log.d(TAG, "Time: $hour:$minute")
            
            // PLAY SOUND
            playSound(context)
            
            // SHOW NOTIFICATION
            showNotification(context, id, title, body)
            
            // RESCHEDULE IF RECURRING
            if (isRecurring && days.isNotEmpty()) {
                Log.d(TAG, "🔄 Rescheduling recurring alarm...")
                reschedule(context, id, title, body, days, hour, minute)
            } else {
                Log.d(TAG, "⏹️ One-time alarm - not rescheduling")
            }
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error in onReceive: ${e.message}", e)
        } finally {
            wakeLock.release()
        }
    }
    
    private fun playSound(context: Context) {
        try {
            stopRingtone()
            
            // Try to get alarm sound, fallback to notification, then ringtone
            var uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            if (uri == null) {
                uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
            }
            if (uri == null) {
                uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            }
            
            if (uri != null) {
                ringtone = RingtoneManager.getRingtone(context, uri)
                ringtone?.play()
                Log.d(TAG, "🎵 PLAYING SOUND: $uri")
            } else {
                Log.e(TAG, "❌ No sound URI available")
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Sound error: ${e.message}", e)
        }
    }
    
    private fun showNotification(context: Context, id: Int, title: String, body: String) {
        try {
            val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            
            // Create notification channel for Android O+
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                val channel = NotificationChannel(
                    "alarm",
                    "Alarms",
                    NotificationManager.IMPORTANCE_HIGH
                ).apply {
                    description = "Alarm notifications"
                    enableVibration(true)
                    setSound(
                        RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM),
                        null
                    )
                }
                nm.createNotificationChannel(channel)
            }
            
            // Open app intent
            val openIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                putExtra("notification_id", id)
                putExtra("alarm_title", title)
                putExtra("alarm_body", body)
            }
            
            val openPi = PendingIntent.getActivity(
                context, id, openIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            // Dismiss intent
            val dismissIntent = Intent(context, AlarmReceiver::class.java).apply {
                action = "DISMISS"
            }
            
            val dismissPi = PendingIntent.getBroadcast(
                context, id + 1000, dismissIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            // Build notification
            val notification = NotificationCompat.Builder(context, "alarm")
                .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
                .setContentTitle("⏰ $title")
                .setContentText(body)
                .setPriority(NotificationCompat.PRIORITY_MAX)
                .setCategory(NotificationCompat.CATEGORY_ALARM)
                .setContentIntent(openPi)
                .setFullScreenIntent(openPi, true)
                .addAction(0, "Dismiss", dismissPi)
                .setAutoCancel(true)
                .setVibrate(longArrayOf(0, 1000, 1000, 1000))
                .setSound(RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM))
                .build()
            
            nm.notify(id, notification)
            Log.d(TAG, "✅ Notification shown with ID: $id")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Notification error: ${e.message}", e)
        }
    }
    
    private fun reschedule(
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
            
            Log.d(TAG, "🔄 Next alarm will be at: ${nextTime.time}")
            Log.d(TAG, "   That's ${(nextTime.timeInMillis - System.currentTimeMillis()) / 1000 / 60} minutes from now")
            
            // Create the intent with ALL the data needed for next trigger
            val intent = Intent(context, AlarmReceiver::class.java).apply {
                putExtra("id", id)
                putExtra("title", title)
                putExtra("body", body)
                putExtra("isRecurring", true)  // ✅ Correct key
                putExtra("selectedDays", days) // ✅ Correct key
                putExtra("reminderHour", hour) // ✅ Correct key
                putExtra("reminderMinute", minute) // ✅ Correct key
            }
            
            val pi = PendingIntent.getBroadcast(
                context, id, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            
            // Use setAlarmClock for reliability
            val alarmClockInfo = AlarmManager.AlarmClockInfo(nextTime.timeInMillis, pi)
            am.setAlarmClock(alarmClockInfo, pi)
            
            Log.d(TAG, "✅ Recurring alarm rescheduled successfully")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Reschedule error: ${e.message}", e)
        }
    }
    
    private fun findNextAlarmTime(days: IntArray, hour: Int, minute: Int): Calendar? {
        val now = Calendar.getInstance()
        
        // Try next 7 days
        for (daysAhead in 1..7) {
            val candidate = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_YEAR, daysAhead)
                set(Calendar.HOUR_OF_DAY, hour)
                set(Calendar.MINUTE, minute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            
            // Convert Calendar.DAY_OF_WEEK to our 0-6 format (Mon=0, Sun=6)
            val dayOfWeek = when (candidate.get(Calendar.DAY_OF_WEEK)) {
                Calendar.MONDAY -> 0
                Calendar.TUESDAY -> 1
                Calendar.WEDNESDAY -> 2
                Calendar.THURSDAY -> 3
                Calendar.FRIDAY -> 4
                Calendar.SATURDAY -> 5
                Calendar.SUNDAY -> 6
                else -> 0
            }
            
            Log.d(TAG, "   Checking day $daysAhead ahead: ${candidate.time}, dayOfWeek=$dayOfWeek")
            
            if (days.contains(dayOfWeek)) {
                Log.d(TAG, "   ✅ Found match!")
                return candidate
            }
        }
        
        Log.e(TAG, "   ❌ No matching day found in next 7 days")
        return null
    }
}
