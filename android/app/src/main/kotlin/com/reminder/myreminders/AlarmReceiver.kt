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
import android.os.Handler
import android.os.Looper
import java.util.Calendar

class AlarmReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "AlarmReceiver"
        private var ringtone: Ringtone? = null
        private var wakeLock: PowerManager.WakeLock? = null
        private var stopHandler: Handler? = null
        
        fun stopRingtone() {
            try {
                // Cancel auto-stop timer
                stopHandler?.removeCallbacksAndMessages(null)
                
                ringtone?.stop()
                ringtone = null
                wakeLock?.let {
                    if (it.isHeld) {
                        it.release()
                    }
                }
                wakeLock = null
                Log.d(TAG, "🔇 Ringtone stopped and wake lock released")
            } catch (e: Exception) {
                Log.e(TAG, "Error stopping ringtone: ${e.message}")
            }
        }
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "========================================")
        Log.d(TAG, "🔔 ALARM RECEIVED!")
        Log.d(TAG, "Action: ${intent.action}")
        Log.d(TAG, "========================================")
        
        if (intent.action == "DISMISS_ALARM") {
            val notificationId = intent.getIntExtra("notification_id", 0)
            Log.d(TAG, "🔕 Dismiss action received for notification $notificationId")
            stopRingtone()
            
            // Clear notification
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (notificationId != 0) {
                notificationManager.cancel(notificationId)
            }
            return
        }
        
        // Acquire FULL wake lock with screen and keyboard wake up
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        wakeLock = powerManager.newWakeLock(
            PowerManager.FULL_WAKE_LOCK or 
            PowerManager.ACQUIRE_CAUSES_WAKEUP or 
            PowerManager.ON_AFTER_RELEASE,
            "RemindMe::FullWakeLock"
        )
        
        try {
            wakeLock?.acquire(5 * 60 * 1000L) // 5 minutes max
            Log.d(TAG, "✅ Wake lock acquired")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to acquire wake lock: ${e.message}")
        }
        
        try {
            val id = intent.getIntExtra("id", 0)
            val title = intent.getStringExtra("title") ?: "Reminder"
            val body = intent.getStringExtra("body") ?: "Time's up!"
            val isRecurring = intent.getBooleanExtra("isRecurring", false)
            val days = intent.getIntArrayExtra("selectedDays") ?: intArrayOf()
            val hour = intent.getIntExtra("reminderHour", 0)
            val minute = intent.getIntExtra("reminderMinute", 0)
            val requiresCaptcha = intent.getBooleanExtra("requiresCaptcha", false)
            
            Log.d(TAG, "ID: $id")
            Log.d(TAG, "Title: $title")
            Log.d(TAG, "Body: $body")
            Log.d(TAG, "Recurring: $isRecurring")
            Log.d(TAG, "Requires Captcha: $requiresCaptcha")
            
            if (isRecurring && days.isNotEmpty()) {
                Log.d(TAG, "🔄 Scheduling next occurrence...")
                val scheduled = scheduleNextAlarm(context, id, title, body, days, hour, minute, requiresCaptcha)
                if (scheduled) {
                    Log.d(TAG, "✅ Next alarm scheduled")
                } else {
                    Log.e(TAG, "❌ Failed to schedule next alarm")
                }
            } else {
                Log.d(TAG, "⏹️ One-time alarm - removing from storage")
                removeFromStorage(context, id)
            }
            
            // Start the full screen activity
            launchFullScreenActivity(context, id, title, body, requiresCaptcha)
            
            // Also show notification as backup
            showFullScreenNotification(context, id, title, body, requiresCaptcha)
            
            // Play sound and vibrate
            playAlarmSound(context)
            vibrateDevice(context)
            
            Log.d(TAG, "✅ Alarm processing complete")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ ERROR in onReceive", e)
            e.printStackTrace()
        }
        
        Log.d(TAG, "========================================")
    }
    
    private fun launchFullScreenActivity(
        context: Context,
        id: Int,
        title: String,
        body: String,
        requiresCaptcha: Boolean
    ) {
        try {
            val activityIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                       Intent.FLAG_ACTIVITY_CLEAR_TOP or
                       Intent.FLAG_ACTIVITY_SINGLE_TOP or
                       Intent.FLAG_ACTIVITY_NO_USER_ACTION
                action = "OPEN_ALARM"
                putExtra("notification_id", id)
                putExtra("alarm_body", body)
                putExtra("alarm_title", title)
                putExtra("requires_captcha", requiresCaptcha)
            }
            
            context.startActivity(activityIntent)
            Log.d(TAG, "🚀 Full screen activity launched")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error launching activity", e)
        }
    }
    
    private fun scheduleNextAlarm(
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
    
    private fun findNextOccurrence(days: IntArray, hour: Int, minute: Int): Calendar? {
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
            Log.d(TAG, "✓ Next occurrence: TODAY at $hour:$minute")
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
                val dayName = arrayOf("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")[checkDay]
                Log.d(TAG, "✓ Next occurrence: $dayName ($daysAhead days) at $hour:$minute")
                return checkDate
            }
        }
        
        return null
    }
    
    private fun showFullScreenNotification(
        context: Context, 
        id: Int, 
        title: String, 
        body: String,
        requiresCaptcha: Boolean
    ) {
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
            
            val openIntent = Intent(context, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                       Intent.FLAG_ACTIVITY_CLEAR_TOP or
                       Intent.FLAG_ACTIVITY_SINGLE_TOP
                action = "OPEN_ALARM"
                putExtra("notification_id", id)
                putExtra("alarm_body", body)
                putExtra("alarm_title", title)
                putExtra("requires_captcha", requiresCaptcha)
            }
            
            val openPendingIntent = PendingIntent.getActivity(
                context,
                id,
                openIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            val dismissIntent = Intent(context, AlarmReceiver::class.java).apply {
                action = "DISMISS_ALARM"
                putExtra("notification_id", id)
            }
            
            val dismissPendingIntent = PendingIntent.getBroadcast(
                context,
                id + 10000,
                dismissIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            val notificationBuilder = NotificationCompat.Builder(context, "alarm_channel")
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
            
            // Only add dismiss action if CAPTCHA is NOT required
            if (!requiresCaptcha) {
                notificationBuilder.addAction(0, "Dismiss", dismissPendingIntent)
                Log.d(TAG, "Added dismiss action (no CAPTCHA required)")
            } else {
                Log.d(TAG, "CAPTCHA required - dismiss action NOT added")
            }
            
            notificationManager.notify(id, notificationBuilder.build())
            Log.d(TAG, "📱 Full-screen notification shown with ID: $id")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error showing notification", e)
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
                
                // Auto-stop after 5 minutes
                stopHandler = Handler(Looper.getMainLooper())
                stopHandler?.postDelayed({
                    Log.d(TAG, "⏱️ Auto-stopping ringtone after 5 minutes")
                    stopRingtone()
                }, 5 * 60 * 1000L)
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error playing sound", e)
        }
    }
    
    private fun vibrateDevice(context: Context) {
        try {
            val vibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            
            // Improved vibration pattern: longer and more noticeable
            val pattern = longArrayOf(
                0,    // Start immediately
                1000, // Vibrate 1 second
                500,  // Pause 0.5 seconds
                1000, // Vibrate 1 second
                500,  // Pause 0.5 seconds
                1000  // Vibrate 1 second
            )
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                vibrator.vibrate(
                    VibrationEffect.createWaveform(pattern, -1)
                )
            } else {
                @Suppress("DEPRECATION")
                vibrator.vibrate(pattern, -1)
            }
            Log.d(TAG, "📳 Vibrating")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error vibrating", e)
        }
    }
    
    private fun removeFromStorage(context: Context, id: Int) {
        try {
            val prefs = context.getSharedPreferences("RemindMeAlarms", Context.MODE_PRIVATE)
            val editor = prefs.edit()
            
            editor.remove("alarm_${id}_title")
            editor.remove("alarm_${id}_body")
            editor.remove("alarm_${id}_recurring")
            editor.remove("alarm_${id}_days")
            editor.remove("alarm_${id}_hour")
            editor.remove("alarm_${id}_minute")
            editor.remove("alarm_${id}_captcha")
            
            val ids = prefs.getStringSet("active_ids", mutableSetOf()) ?: mutableSetOf()
            val newIds = ids.toMutableSet()
            newIds.remove(id.toString())
            editor.putStringSet("active_ids", newIds)
            
            editor.apply()
            Log.d(TAG, "🗑️ Removed alarm $id from storage")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error removing from storage", e)
        }
    }
}
