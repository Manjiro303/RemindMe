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
            val isRecurring = intent.getBooleanExtra("recurring", false)
            val days = intent.getIntArrayExtra("days") ?: intArrayOf()
            val hour = intent.getIntExtra("hour", 0)
            val minute = intent.getIntExtra("minute", 0)
            
            Log.d(TAG, "ID: $id, Body: $body, Recurring: $isRecurring")
            
            // PLAY SOUND - THIS IS THE KEY PART
            playSound(context)
            
            // SHOW NOTIFICATION
            showNotification(context, id, title, body)
            
            // RESCHEDULE IF RECURRING
            if (isRecurring && days.isNotEmpty()) {
                reschedule(context, id, title, body, days, hour, minute)
            }
            
        } finally {
            wakeLock.release()
        }
    }
    
    private fun playSound(context: Context) {
        try {
            stopRingtone()
            val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM) 
                ?: RingtoneManager.getDefaultUri(RingtoneManager.TYPE_RINGTONE)
            ringtone = RingtoneManager.getRingtone(context, uri)
            ringtone?.play()
            Log.d(TAG, "🎵 PLAYING SOUND: $uri")
        } catch (e: Exception) {
            Log.e(TAG, "Sound error: ${e.message}")
        }
    }
    
    private fun showNotification(context: Context, id: Int, title: String, body: String) {
        val nm = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            nm.createNotificationChannel(
                NotificationChannel("alarm", "Alarms", NotificationManager.IMPORTANCE_HIGH)
            )
        }
        
        val openIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        
        val openPi = PendingIntent.getActivity(
            context, id, openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val dismissIntent = Intent(context, AlarmReceiver::class.java).apply {
            action = "DISMISS"
        }
        
        val dismissPi = PendingIntent.getBroadcast(
            context, id + 1000, dismissIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
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
            .build()
        
        nm.notify(id, notification)
        Log.d(TAG, "✅ Notification shown")
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
            val next = findNext(days, hour, minute) ?: return
            
            Log.d(TAG, "🔄 Rescheduling to: ${next.time}")
            
            val intent = Intent(context, AlarmReceiver::class.java).apply {
                putExtra("id", id)
                putExtra("title", title)
                putExtra("body", body)
                putExtra("recurring", true)
                putExtra("days", days)
                putExtra("hour", hour)
                putExtra("minute", minute)
            }
            
            val pi = PendingIntent.getBroadcast(
                context, id, intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            am.setAlarmClock(AlarmManager.AlarmClockInfo(next.timeInMillis, pi), pi)
            
            Log.d(TAG, "✅ Rescheduled")
        } catch (e: Exception) {
            Log.e(TAG, "Reschedule error: ${e.message}")
        }
    }
    
    private fun findNext(days: IntArray, hour: Int, minute: Int): Calendar? {
        for (i in 1..7) {
            val cal = Calendar.getInstance().apply {
                add(Calendar.DAY_OF_YEAR, i)
                set(Calendar.HOUR_OF_DAY, hour)
                set(Calendar.MINUTE, minute)
                set(Calendar.SECOND, 0)
                set(Calendar.MILLISECOND, 0)
            }
            
            val dayIdx = when (cal.get(Calendar.DAY_OF_WEEK)) {
                Calendar.MONDAY -> 0
                Calendar.TUESDAY -> 1
                Calendar.WEDNESDAY -> 2
                Calendar.THURSDAY -> 3
                Calendar.FRIDAY -> 4
                Calendar.SATURDAY -> 5
                Calendar.SUNDAY -> 6
                else -> 0
            }
            
            if (days.contains(dayIdx)) return cal
        }
        return null
    }
}
