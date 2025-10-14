package com.reminder.myreminders

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import android.app.NotificationChannel
import android.app.NotificationManager
import android.media.AudioAttributes
import android.media.RingtoneManager
import android.net.Uri
import android.os.Build
import androidx.core.app.NotificationCompat
import android.app.PendingIntent
import android.os.PowerManager

class AlarmReceiver : BroadcastReceiver() {
    
    override fun onReceive(context: Context, intent: Intent) {
        Log.d(TAG, "🔔 ========== ALARM RECEIVED ==========")
        
        // Handle dismiss action
        if (intent.action == "DISMISS_ALARM") {
            val notificationId = intent.getIntExtra("notification_id", 0)
            val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.cancel(notificationId)
            Log.d(TAG, "✅ Notification dismissed: $notificationId")
            return
        }
        
        // Wake up the device
        val powerManager = context.getSystemService(Context.POWER_SERVICE) as PowerManager
        val wakeLock = powerManager.newWakeLock(
            PowerManager.PARTIAL_WAKE_LOCK or 
            PowerManager.ACQUIRE_CAUSES_WAKEUP or 
            PowerManager.ON_AFTER_RELEASE,
            "RemindMe::AlarmWakeLock"
        )
        wakeLock.acquire(60000) // 60 seconds
        
        try {
            val title = intent.getStringExtra("title") ?: "Reminder"
            val body = intent.getStringExtra("body") ?: "Your reminder is here!"
            val id = intent.getIntExtra("id", 0)
            val soundUri = intent.getStringExtra("sound")
            val priority = intent.getStringExtra("priority") ?: "Medium"
            
            Log.d(TAG, "Title: $title")
            Log.d(TAG, "Body: $body")
            Log.d(TAG, "ID: $id")
            Log.d(TAG, "Priority: $priority")
            
            // Show notification
            showNotification(context, id, title, body, soundUri, priority)
            
            Log.d(TAG, "✅ Alarm processing complete")
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error processing alarm: ${e.message}", e)
        } finally {
            if (wakeLock.isHeld) {
                wakeLock.release()
            }
        }
    }
    
    private fun showNotification(
        context: Context,
        id: Int,
        title: String,
        body: String,
        soundUri: String?,
        priority: String
    ) {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        val channelId = "reminder_alarm_channel"
        
        Log.d(TAG, "📱 Creating notification channel...")
        
        // Create notification channel
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(channelId, "Alarm Notifications", importance).apply {
                description = "High priority notifications for alarms"
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 500, 200, 500, 200, 500, 200, 500)
                enableLights(true)
                lightColor = android.graphics.Color.BLUE
                setShowBadge(true)
                lockscreenVisibility = android.app.Notification.VISIBILITY_PUBLIC
                
                // Set sound
                val sound: Uri = when {
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
                
                setSound(sound, AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_ALARM)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build())
            }
            
            notificationManager.createNotificationChannel(channel)
            Log.d(TAG, "✅ Notification channel created")
        }
        
        // Create intent to open app
        val appIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TASK
            putExtra("notification_id", id)
        }
        val pendingIntent = PendingIntent.getActivity(
            context, 
            id, 
            appIntent, 
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // Create dismiss action
        val dismissIntent = Intent(context, AlarmReceiver::class.java).apply {
            action = "DISMISS_ALARM"
            putExtra("notification_id", id)
        }
        val dismissPendingIntent = PendingIntent.getBroadcast(
            context,
            id + 1000,
            dismissIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        // Build notification
        val notification = NotificationCompat.Builder(context, channelId)
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("⏰ $title")
            .setContentText(body)
            .setStyle(NotificationCompat.BigTextStyle().bigText(body))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(false)
            .setOngoing(true)
            .setContentIntent(pendingIntent)
            .setFullScreenIntent(pendingIntent, true)
            .setVisibility(NotificationCompat.VISIBILITY_PUBLIC)
            .setVibrate(longArrayOf(0, 500, 200, 500, 200, 500, 200, 500))
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Dismiss",
                dismissPendingIntent
            )
            .build()
        
        // Show notification
        notification.flags = notification.flags or android.app.Notification.FLAG_INSISTENT
        notificationManager.notify(id, notification)
        
        Log.d(TAG, "✅ Notification shown with ID: $id")
    }
    
    companion object {
        private const val TAG = "AlarmReceiver"
    }
}
