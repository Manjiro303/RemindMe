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
                currentRingtone?.let {
                    if (it.isPlaying) {
                        it.stop()
                    }
                }
                currentRingtone = null
                
                currentVibrator?.cancel()
                currentVibrator = null
                
                Log.d(TAG, "🔇 Ringtone and vibration stopped")
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error stopping ringtone: ${e.message}")
            }
        }
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "🔔 ========== ALARM RECEIVED ==========")
        
        if (intent.action == "DISMISS_ALARM") {
            val notificationId = intent.getIntExtra("notification_id", 0)
            val requiresCaptcha = intent.getBooleanExtra("requiresCaptcha", false)
            
            if (!requiresCaptcha) {
                stopRingtone()
                val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                notificationManager.cancel(notificationId)
                Log.d(TAG, "✅ Notification dismissed: $notificationId")
            } else {
                Log.d(TAG, "⚠️ Cannot dismiss - CAPTCHA required")
            }
            return
        }
        
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK or 
            PowerManager.ACQUIRE_CAUSES_WAKEUP or 
            PowerManager.ON_AFTER_RELEASE,
            "RemindMe::AlarmWakeLock"
        )
        wakeLock.acquire(300000)
        
        try {
            val id = intent.getIntExtra("id", 0)
            val title = intent.getStringExtra("title") ?: "Reminder"
            val body = intent.getStringExtra("body") ?: "Your reminder is here!"
            val soundUri = intent.getStringExtra("sound")
            val priority = intent.getStringExtra("priority") ?: "Medium"
            val requiresCaptcha = intent.getBooleanExtra("requiresCaptcha", false)
            val isRecurring = intent.getBooleanExtra("isRecurring", false)
            val selectedDays = intent.getIntArrayExtra("selectedDays") ?: intArrayOf()
            val reminderHour = intent.getIntExtra("reminderHour", 0)
            val reminderMinute = intent.getIntExtra("reminderMinute", 0)
            
            Log.d(TAG, "📋 ID: $id, Recurring: $isRecurring, Days: ${selectedDays.joinToString()}")
            
            playRingtone(context, soundUri, requiresCaptcha)
            vibrateDevice(context, requiresCaptcha)
            showNotification(context, id, title, body, soundUri, priority, requiresCaptcha)
            
            // CRITICAL FIX: Reschedule recurring alarm
            if (isRecurring && selectedDays.isNotEmpty()) {
                rescheduleRecurringAlarm(
                    context, id, title, body, soundUri, priority, 
                    requiresCaptcha, selectedDays, reminderHour, reminderMinute
                )
            }
            
            Log.d(TAG, "✅ Alarm processing complete")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error: ${e.message}", e)
        } finally {
            if (wakeLock.isHeld) {
                wakeLock.release()
            }
        }
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
            var nextAlarm: Calendar? = null
            
            // Try next 7 days
            for (offset in 1..7) {
                val checkTime = Calendar.getInstance().apply {
                    add(Calendar.DAY_OF_YEAR, offset)
                    set(Calendar.HOUR_OF_DAY, hour)
                    set(Calendar.MINUTE, minute)
                    set(Calendar.SECOND, 0)
                    set(Calendar.MILLISECOND, 0)
                }
                
                // Convert to our day index (0=Mon, 6=Sun)
                val dayOfWeek = when (checkTime.get(Calendar.DAY_OF_WEEK)) {
                    Calendar.MONDAY -> 0
                    Calendar.TUESDAY -> 1
                    Calendar.WEDNESDAY -> 2
                    Calendar.THURSDAY -> 3
                    Calendar.FRIDAY -> 4
                    Calendar.SATURDAY -> 5
                    Calendar.SUNDAY -> 6
                    else -> 0
                }
                
                if (selectedDays.contains(dayOfWeek)) {
                    nextAlarm = checkTime
                    Log.d(TAG, "✅ Next alarm in $offset days (${getDayName(dayOfWeek)})")
                    break
                }
            }
            
            if (nextAlarm == null) {
                Log.e(TAG, "❌ Could not find next alarm day")
                return
            }
            
            // Schedule next alarm
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
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    nextAlarm.timeInMillis,
                    pendingIntent
                )
            } else {
                alarmManager.setExact(
                    AlarmManager.RTC_WAKEUP,
                    nextAlarm.timeInMillis,
                    pendingIntent
                )
            }
            
            Log.d(TAG, "✅ Rescheduled for: ${nextAlarm.time}")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error rescheduling: ${e.message}", e)
        }
    }
    
    private fun getDayName(index: Int): String {
        return arrayOf("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")[index]
    }
    
    private fun playRingtone(context: Context, soundUri: String?, requiresCaptcha: Boolean) {
        try {
            stopRingtone()
            
            val uri: Uri = when {
                !soundUri.isNullOrEmpty() && soundUri != "null" -> {
                    try {
                        Uri.parse(soundUri)
                    } catch (e: Exception) {
                        RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                    }
                }
                else -> {
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                        ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                }
            }
            
            currentRingtone = RingtoneManager.getRingtone(context, uri)
            if (requiresCaptcha) {
                currentRingtone?.isLooping = true
            }
            currentRingtone?.play()
            
            Log.d(TAG, "🎵 Ringtone playing")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error playing ringtone: ${e.message}")
        }
    }
    
    private fun vibrateDevice(context: Context, requiresCaptcha: Boolean) {
        try {
            currentVibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                currentVibrator?.vibrate(
                    VibrationEffect.createWaveform(
                        longArrayOf(0, 500, 200, 500, 200, 500),
                        if (requiresCaptcha) 0 else -1
                    )
                )
            } else {
                @Suppress("DEPRECATION")
                currentVibrator?.vibrate(
                    longArrayOf(0, 500, 200, 500, 200, 500), 
                    if (requiresCaptcha) 0 else -1
                )
            }
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error vibrating: ${e.message}")
        }
    }
    
    private fun showNotification(
        context: Context,
        id: Int,
        title: String,
        body: String,
        soundUri: String?,
        priority: String,
        requiresCaptcha: Boolean
    ) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channelId = "reminder_alarm_channel"
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(channelId, "Alarm Notifications", NotificationManager.IMPORTANCE_HIGH).apply {
                enableVibration(false)
                setSound(null, null)
                enableLights(true)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            }
            notificationManager.createNotificationChannel(channel)
        }
        
        val appIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP
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
        
        val notificationText = if (requiresCaptcha) {
            "🔐 Solve CAPTCHA to dismiss - $body"
        } else {
            body
        }
        
        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("⏰ $title")
            .setContentText(notificationText)
            .setStyle(NotificationCompat.BigTextStyle().bigText(notificationText))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(false)
            .setOngoing(requiresCaptcha)
            .setContentIntent(pendingIntent)
            .setFullScreenIntent(pendingIntent, true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setSound(null)
            .setVibrate(null)
        
        if (!requiresCaptcha) {
            val dismissIntent = Intent(context, AlarmReceiver::class.java).apply {
                action = "DISMISS_ALARM"
                putExtra("notification_id", id)
                putExtra("requiresCaptcha", false)
            }
            val dismissPendingIntent = PendingIntent.getBroadcast(
                context, id + 1000, dismissIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            notification.addAction(android.R.drawable.ic_menu_close_clear_cancel, "Dismiss", dismissPendingIntent)
            notification.setDeleteIntent(dismissPendingIntent)
        }
        
        val builtNotification = notification.build()
        builtNotification.flags = builtNotification.flags or android.app.Notification.FLAG_INSISTENT
        notificationManager.notify(id, builtNotification)
        
        Log.d(TAG, "✅ Notification shown")
    }
}
