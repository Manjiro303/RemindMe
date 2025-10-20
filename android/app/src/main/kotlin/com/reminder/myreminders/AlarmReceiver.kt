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

class AlarmReceiver : BroadcastReceiver() {
    
    companion object {
        private const val TAG = "AlarmReceiver"
        private var currentRingtone: Ringtone? = null
        private var currentVibrator: Vibrator? = null
        
        // Public method to stop ringtone from outside (called from Flutter)
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
                
                Log.d(TAG, "🔇 Ringtone and vibration stopped from external call")
            } catch (e: Exception) {
                Log.e(TAG, "❌ Error stopping ringtone externally: ${e.message}")
            }
        }
    }
    
    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "🔔 ========== ALARM RECEIVED ==========")
        
        // Don't handle dismiss actions for CAPTCHA-protected alarms
        if (intent.action == "DISMISS_ALARM") {
            val notificationId = intent.getIntExtra("notification_id", 0)
            val requiresCaptcha = intent.getBooleanExtra("requiresCaptcha", false)
            
            // Only allow dismissal if CAPTCHA is not required
            if (!requiresCaptcha) {
                stopRingtone()
                stopVibration()
                
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
        wakeLock.acquire(300000) // 5 minutes
        
        try {
            val title = intent.getStringExtra("title") ?: "Reminder"
            val body = intent.getStringExtra("body") ?: "Your reminder is here!"
            val id = intent.getIntExtra("id", 0)
            val soundUri = intent.getStringExtra("sound")
            val priority = intent.getStringExtra("priority") ?: "Medium"
            val requiresCaptcha = intent.getBooleanExtra("requiresCaptcha", false)
            
            Log.d(TAG, "Title: $title")
            Log.d(TAG, "Body: $body")
            Log.d(TAG, "ID: $id")
            Log.d(TAG, "Sound URI: $soundUri")
            Log.d(TAG, "Priority: $priority")
            Log.d(TAG, "Requires CAPTCHA: $requiresCaptcha")
            
            playRingtone(context, soundUri, requiresCaptcha)
            vibrateDevice(context, requiresCaptcha)
            showNotification(context, id, title, body, soundUri, priority, requiresCaptcha)
            
            Log.d(TAG, "✅ Alarm processing complete")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error processing alarm: ${e.message}", e)
        } finally {
            if (wakeLock.isHeld) {
                wakeLock.release()
            }
        }
    }
    
    private fun playRingtone(context: Context, soundUri: String?, requiresCaptcha: Boolean) {
        try {
            // Always stop any existing ringtone first
            stopRingtone()
            
            val uri: Uri = when {
                !soundUri.isNullOrEmpty() && soundUri != "null" -> {
                    try {
                        Uri.parse(soundUri)
                    } catch (e: Exception) {
                        Log.e(TAG, "Invalid sound URI, using default: ${e.message}")
                        RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                            ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                    }
                }
                else -> {
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                        ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                }
            }
            
            Log.d(TAG, "🎵 Playing ringtone: $uri (CAPTCHA: $requiresCaptcha)")
            currentRingtone = RingtoneManager.getRingtone(context, uri)
            
            // For CAPTCHA alarms, loop the ringtone
            if (requiresCaptcha) {
                currentRingtone?.isLooping = true
            }
            
            currentRingtone?.play()
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error playing ringtone: ${e.message}")
        }
    }
    
    private fun stopRingtone() {
        try {
            currentRingtone?.let {
                if (it.isPlaying) {
                    it.stop()
                }
            }
            currentRingtone = null
            Log.d(TAG, "🔇 Ringtone stopped")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error stopping ringtone: ${e.message}")
        }
    }
    
    private fun vibrateDevice(context: Context, requiresCaptcha: Boolean) {
        try {
            currentVibrator = context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                currentVibrator?.vibrate(
                    VibrationEffect.createWaveform(
                        longArrayOf(0, 500, 200, 500, 200, 500, 200, 500),
                        if (requiresCaptcha) 0 else -1 // Loop if CAPTCHA required
                    )
                )
            } else {
                @Suppress("DEPRECATION")
                currentVibrator?.vibrate(
                    longArrayOf(0, 500, 200, 500, 200, 500, 200, 500), 
                    if (requiresCaptcha) 0 else -1
                )
            }
            Log.d(TAG, "📳 Device vibrating (CAPTCHA: $requiresCaptcha)")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error vibrating: ${e.message}")
        }
    }
    
    private fun stopVibration() {
        try {
            currentVibrator?.cancel()
            currentVibrator = null
            Log.d(TAG, "📳 Vibration stopped")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error stopping vibration: ${e.message}")
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
        
        Log.d(TAG, "📱 Creating notification channel...")
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(channelId, "Alarm Notifications", importance).apply {
                description = "High priority notifications for alarms"
                enableVibration(false)
                setSound(null, null)
                enableLights(true)
                lightColor = android.graphics.Color.BLUE
                setShowBadge(true)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
            }
            
            notificationManager.createNotificationChannel(channel)
            Log.d(TAG, "✅ Notification channel created (silent)")
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
            context, 
            id, 
            appIntent, 
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
            .setOngoing(requiresCaptcha) // Make it persistent if CAPTCHA required
            .setContentIntent(pendingIntent)
            .setFullScreenIntent(pendingIntent, true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setSound(null)
            .setVibrate(null)
        
        // Only add dismiss action if no CAPTCHA required
        if (!requiresCaptcha) {
            val dismissIntent = Intent(context, AlarmReceiver::class.java).apply {
                action = "DISMISS_ALARM"
                putExtra("notification_id", id)
                putExtra("requiresCaptcha", requiresCaptcha)
            }
            val dismissPendingIntent = PendingIntent.getBroadcast(
                context,
                id + 1000,
                dismissIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            notification.addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Dismiss",
                dismissPendingIntent
            )
            notification.setDeleteIntent(dismissPendingIntent)
        }
        
        val builtNotification = notification.build()
        builtNotification.flags = builtNotification.flags or android.app.Notification.FLAG_INSISTENT
        notificationManager.notify(id, builtNotification)
        
        Log.d(TAG, "✅ Notification shown with ID: $id (CAPTCHA: $requiresCaptcha)")
    }
}
