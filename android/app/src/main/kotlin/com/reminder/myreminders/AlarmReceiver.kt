package com.reminder.myreminders

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.RingtoneManager
import android.media.Ringtone
import android.media.AudioManager
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import android.app.PendingIntent
import android.os.PowerManager
import android.os.VibrationEffect
import android.os.Vibrator
import android.app.AlarmManager
import java.util.Calendar

class AlarmReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "AlarmReceiver"
        private var currentRingtone: Ringtone? = null
        private var currentVibrator: Vibrator? = null
        
        fun stopCurrentRingtone() {
            try {
                currentRingtone?.stop()
                currentRingtone = null
                currentVibrator?.cancel()
                currentVibrator = null
                Log.d(TAG, "🔇 Stopped ringtone and vibration")
            } catch (e: Exception) {
                Log.e(TAG, "Error stopping ringtone: ${e.message}")
            }
        }
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "🔔 ==========================================")
        Log.d(TAG, "🔔 ALARM TRIGGERED!")
        Log.d(TAG, "🔔 ==========================================")
        
        // Handle dismiss action
        if (intent.action == "DISMISS_ALARM") {
            val notificationId = intent.getIntExtra("notification_id", 0)
            val requiresCaptcha = intent.getBooleanExtra("requiresCaptcha", false)
            
            if (!requiresCaptcha) {
                stopCurrentRingtone()
                val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                notificationManager.cancel(notificationId)
                Log.d(TAG, "✅ Alarm dismissed: $notificationId")
            }
            return
        }
        
        // Acquire wake lock
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK or PowerManager.ACQUIRE_CAUSES_WAKEUP,
            "RemindMe::AlarmWakeLock"
        )
        wakeLock.acquire(5 * 60 * 1000L) // 5 minutes
        
        try {
            val id = intent.getIntExtra("id", 0)
            val title = intent.getStringExtra("title") ?: "Reminder"
            val body = intent.getStringExtra("body") ?: "Time's up!"
            val soundUri = intent.getStringExtra("sound")
            val priority = intent.getStringExtra("priority") ?: "Medium"
            val requiresCaptcha = intent.getBooleanExtra("requiresCaptcha", false)
            val isRecurring = intent.getBooleanExtra("isRecurring", false)
            val selectedDays = intent.getIntArrayExtra("selectedDays") ?: intArrayOf()
            val reminderHour = intent.getIntExtra("reminderHour", 0)
            val reminderMinute = intent.getIntExtra("reminderMinute", 0)
            
            Log.d(TAG, "Alarm Details:")
            Log.d(TAG, "  ID: $id")
            Log.d(TAG, "  Title: $title")
            Log.d(TAG, "  Body: $body")
            Log.d(TAG, "  Recurring: $isRecurring")
            Log.d(TAG, "  Days: ${selectedDays.joinToString()}")
            Log.d(TAG, "  CAPTCHA: $requiresCaptcha")
            
            // Play sound and vibrate
            playAlarmSound(context, soundUri, requiresCaptcha)
            vibrateDevice(context, requiresCaptcha)
            
            // Show notification
            showAlarmNotification(context, id, title, body, priority, requiresCaptcha)
            
            // Reschedule if recurring
            if (isRecurring && selectedDays.isNotEmpty()) {
                rescheduleRecurringAlarm(
                    context, id, title, body, soundUri, priority,
                    requiresCaptcha, selectedDays, reminderHour, reminderMinute
                )
            }
            
            Log.d(TAG, "✅ Alarm processed successfully")
            Log.d(TAG, "==========================================")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error processing alarm: ${e.message}", e)
        } finally {
            if (wakeLock.isHeld) {
                wakeLock.release()
            }
        }
    }
    
    private fun playAlarmSound(context: Context, soundUri: String?, requiresCaptcha: Boolean) {
        try {
            stopCurrentRingtone()
            
            // Get the alarm URI
            val uri: Uri = if (!soundUri.isNullOrEmpty() && soundUri != "null") {
                try {
                    Uri.parse(soundUri)
                } catch (e: Exception) {
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                }
            } else {
                RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
            }
            
            currentRingtone = RingtoneManager.getRingtone(context, uri)
            
            // Set to max volume
            val audioManager = context.getSystemService(Context.AUDIO_SERVICE) as AudioManager
            audioManager.setStreamVolume(
                AudioManager.STREAM_ALARM,
                audioManager.getStreamMaxVolume(AudioManager.STREAM_ALARM),
                0
            )
            
            if (requiresCaptcha) {
                currentRingtone?.isLooping = true
            }
            
            currentRingtone?.play()
            
            Log.d(TAG, "🎵 Playing alarm sound: $uri")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error playing sound: ${e.message}")
        }
    }
    
    private fun vibrateDevice(context: Context, requiresCaptcha: Boolean) {
        try {
            currentVibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            
            val pattern = longArrayOf(0, 1000, 500, 1000, 500, 1000)
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                currentVibrator?.vibrate(
                    VibrationEffect.createWaveform(pattern, if (requiresCaptcha) 0 else -1)
                )
            } else {
                @Suppress("DEPRECATION")
                currentVibrator?.vibrate(pattern, if (requiresCaptcha) 0 else -1)
            }
            
            Log.d(TAG, "📳 Vibrating device")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error vibrating: ${e.message}")
        }
    }
    
    private fun showAlarmNotification(
        context: Context,
        id: Int,
        title: String,
        body: String,
        priority: String,
        requiresCaptcha: Boolean
    ) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channelId = "alarm_channel"
        
        // Create notification channel
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "Alarm Notifications",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Notifications for alarm reminders"
                enableVibration(false) // We handle vibration ourselves
                setSound(null, null) // We handle sound ourselves
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            }
            notificationManager.createNotificationChannel(channel)
        }
        
        // Create intent to open app
        val appIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
            action = "ALARM_DETAIL"
            putExtra("notification_id", id)
            putExtra("alarm_title", title)
            putExtra("alarm_body", body)
            putExtra("alarm_priority", priority)
            putExtra("requiresCaptcha", requiresCaptcha)
        }
        
        val pendingIntent = PendingIntent.getActivity(
            context, id, appIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // Build notification
        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("⏰ $title")
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(!requiresCaptcha)
            .setOngoing(requiresCaptcha)
            .setContentIntent(pendingIntent)
            .setFullScreenIntent(pendingIntent, true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setSound(null)
            .setVibrate(null)
        
        // Add dismiss button if no CAPTCHA
        if (!requiresCaptcha) {
            val dismissIntent = Intent(context, AlarmReceiver::class.java).apply {
                action = "DISMISS_ALARM"
                putExtra("notification_id", id)
                putExtra("requiresCaptcha", false)
            }
            val dismissPendingIntent = PendingIntent.getBroadcast(
                context, id + 10000, dismissIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            notification.addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Dismiss",
                dismissPendingIntent
            )
        }
        
        val builtNotification = notification.build()
        builtNotification.flags = builtNotification.flags or android.app.Notification.FLAG_INSISTENT
        
        notificationManager.notify(id, builtNotification)
        
        Log.d(TAG, "✅ Notification shown: ID=$id")
    }
    
    private fun rescheduleRecurringAlarm(
        context: Context,
        alarmId: Int,
        title: String,
        body: String,
        soundUri: String?,
        priority: String,
        requiresCaptcha: Boolean,
        selectedDays: IntArray,
        hour: Int,
        minute: Int
    ) {
        try {
            Log.d(TAG, "🔄 Rescheduling recurring alarm...")
            
            val now = Calendar.getInstance()
            val nextAlarm = findNextAlarmTime(selectedDays, hour, minute)
            
            if (nextAlarm == null) {
                Log.e(TAG, "❌ Could not find next alarm time")
                return
            }
            
            Log.d(TAG, "   Next alarm: ${nextAlarm.time}")
            
            val alarmManager = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(context, AlarmReceiver::class.java).apply {
                putExtra("id", alarmId)
                putExtra("title", title)
                putExtra("body", body)
                putExtra("sound", soundUri)
                putExtra("priority", priority)
                putExtra("requiresCaptcha", requiresCaptcha)
                putExtra("isRecurring", true)
                putExtra("selectedDays", selectedDays)
                putExtra("reminderHour", hour)
                putExtra("reminderMinute", minute)
            }
            
            val pendingIntent = PendingIntent.getBroadcast(
                context,
                alarmId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            // Use setAlarmClock for reliability
            val alarmClockInfo = AlarmManager.AlarmClockInfo(nextAlarm.timeInMillis, pendingIntent)
            alarmManager.setAlarmClock(alarmClockInfo, pendingIntent)
            
            Log.d(TAG, "✅ Recurring alarm rescheduled")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error rescheduling: ${e.message}", e)
        }
    }
    
    private fun findNextAlarmTime(selectedDays: IntArray, hour: Int, minute: Int): Calendar? {
        val now = Calendar.getInstance()
        
        // Try next 7 days
        for (daysAhead in 1..7) {
            val checkTime = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_YEAR, daysAhead)
                set(Calendar.HOUR_OF_DAY, hour)
                set(Calendar.MINUTE, minute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            
            // Convert to our day format (0=Mon, 6=Sun)
            val dayIndex = when (checkTime.get(Calendar.DAY_OF_WEEK)) {
                Calendar.MONDAY -> 0
                Calendar.TUESDAY -> 1
                Calendar.WEDNESDAY -> 2
                Calendar.THURSDAY -> 3
                Calendar.FRIDAY -> 4
                Calendar.SATURDAY -> 5
                Calendar.SUNDAY -> 6
                else -> 0
            }
            
            if (selectedDays.contains(dayIndex)) {
                return checkTime
            }
        }
        
        return null
    }
}
