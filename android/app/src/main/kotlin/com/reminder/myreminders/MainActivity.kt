package com.reminder.myreminders

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.provider.Settings
import android.os.Build
import android.app.AlarmManager
import android.content.Context
import android.media.RingtoneManager
import android.net.Uri
import android.util.Log
import android.app.PendingIntent
import android.app.NotificationManager
import android.widget.Toast

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.reminder.myreminders/permissions"
    private val RINGTONE_CHANNEL = "com.reminder.myreminders/ringtone"
    private val ALARM_CHANNEL = "com.reminder.myreminders/alarm"
    private val RINGTONE_PICKER_REQUEST = 999

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Request exact alarm permission on startup for Android 12+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            if (!alarmManager.canScheduleExactAlarms()) {
                Log.w(TAG, "⚠️ Exact alarm permission not granted - requesting")
                try {
                    val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                    startActivity(intent)
                } catch (e: Exception) {
                    Log.e(TAG, "Error requesting exact alarm permission: ${e.message}")
                }
            }
        }
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openSettings" -> {
                    openAppSettings()
                    result.success(null)
                }
                "canScheduleExactAlarms" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                        result.success(alarmManager.canScheduleExactAlarms())
                    } else {
                        result.success(true)
                    }
                }
                "requestExactAlarmPermission" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                        val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                        startActivity(intent)
                    }
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RINGTONE_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "pickRingtone" -> {
                    pickRingtone()
                    result.success(null)
                }
                "getDefaultAlarmUri" -> {
                    val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM)
                    result.success(uri?.toString() ?: "")
                }
                "getDefaultNotificationUri" -> {
                    val uri = RingtoneManager.getDefaultUri(RingtoneManager.TYPE_NOTIFICATION)
                    result.success(uri?.toString() ?: "")
                }
                else -> result.notImplemented()
            }
        }
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ALARM_CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleAlarm" -> {
                    try {
                        val alarmId = call.argument<Int>("alarmId") ?: 0
                        val timeMillis = call.argument<Long>("scheduledTimeMillis") ?: 0L
                        val title = call.argument<String>("title") ?: "Reminder"
                        val body = call.argument<String>("body") ?: ""
                        val soundUri = call.argument<String>("soundUri") ?: ""
                        val priority = call.argument<String>("priority") ?: "Medium"
                        val requiresCaptcha = call.argument<Boolean>("requiresCaptcha") ?: false
                        val isRecurring = call.argument<Boolean>("isRecurring") ?: false
                        val selectedDays = call.argument<IntArray>("selectedDays") ?: intArrayOf()
                        val reminderHour = call.argument<Int>("reminderHour") ?: 0
                        val reminderMinute = call.argument<Int>("reminderMinute") ?: 0
                        
                        val success = scheduleNativeAlarm(
                            alarmId, timeMillis, title, body, soundUri, priority, 
                            requiresCaptcha, isRecurring, selectedDays, reminderHour, reminderMinute
                        )
                        result.success(success)
                    } catch (e: Exception) {
                        Log.e(TAG, "❌ Error in scheduleAlarm: ${e.message}")
                        result.error("ALARM_ERROR", e.message, null)
                    }
                }
                "cancelAlarm" -> {
                    try {
                        val alarmId = call.argument<Int>("alarmId") ?: 0
                        cancelNativeAlarm(alarmId)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "❌ Error in cancelAlarm: ${e.message}")
                        result.error("CANCEL_ERROR", e.message, null)
                    }
                }
                "cancelNotification" -> {
                    try {
                        val notificationId = call.argument<Int>("notificationId") ?: 0
                        stopRingtoneAndNotification(notificationId)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "❌ Error in cancelNotification: ${e.message}")
                        result.error("CANCEL_NOTIF_ERROR", e.message, null)
                    }
                }
                "stopRingtone" -> {
                    try {
                        AlarmReceiver.stopRingtone()
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "❌ Error in stopRingtone: ${e.message}")
                        result.error("STOP_RINGTONE_ERROR", e.message, null)
                    }
                }
                "getInitialIntent" -> {
                    try {
                        val intentData = getIntentData(intent)
                        result.success(intentData)
                    } catch (e: Exception) {
                        Log.e(TAG, "❌ Error getting initial intent: ${e.message}")
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun getIntentData(intent: Intent?): Map<String, Any>? {
        if (intent?.action == "ALARM_DETAIL") {
            return mapOf(
                "notification_id" to (intent.getIntExtra("notification_id", 0)),
                "alarm_title" to (intent.getStringExtra("alarm_title") ?: ""),
                "alarm_body" to (intent.getStringExtra("alarm_body") ?: ""),
                "alarm_priority" to (intent.getStringExtra("alarm_priority") ?: "Medium"),
                "requiresCaptcha" to (intent.getBooleanExtra("requiresCaptcha", false))
            )
        }
        return null
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        if (intent.action == "ALARM_DETAIL") {
            handleAlarmDetail(intent)
        }
    }

    private fun handleAlarmDetail(intent: Intent) {
        val notificationId = intent.getIntExtra("notification_id", 0)
        val alarmTitle = intent.getStringExtra("alarm_title") ?: ""
        val alarmBody = intent.getStringExtra("alarm_body") ?: ""
        val alarmPriority = intent.getStringExtra("alarm_priority") ?: "Medium"
        val requiresCaptcha = intent.getBooleanExtra("requiresCaptcha", false)
        
        flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
            MethodChannel(messenger, ALARM_CHANNEL).invokeMethod(
                "onAlarmDetail",
                mapOf(
                    "notification_id" to notificationId,
                    "alarm_title" to alarmTitle,
                    "alarm_body" to alarmBody,
                    "alarm_priority" to alarmPriority,
                    "requiresCaptcha" to requiresCaptcha
                )
            )
        }
    }

    private fun openAppSettings() {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.parse("package:$packageName")
        }
        startActivity(intent)
    }
    
    private fun pickRingtone() {
        val intent = Intent(RingtoneManager.ACTION_RINGTONE_PICKER).apply {
            putExtra(RingtoneManager.EXTRA_RINGTONE_TYPE, RingtoneManager.TYPE_ALARM)
            putExtra(RingtoneManager.EXTRA_RINGTONE_TITLE, "Select Alarm Sound")
            putExtra(RingtoneManager.EXTRA_RINGTONE_EXISTING_URI, null as Uri?)
            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, true)
            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
        }
        startActivityForResult(intent, RINGTONE_PICKER_REQUEST)
    }
    
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        
        if (requestCode == RINGTONE_PICKER_REQUEST && resultCode == RESULT_OK) {
            val uri: Uri? = data?.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
            
            if (uri != null) {
                flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                    MethodChannel(messenger, RINGTONE_CHANNEL).invokeMethod(
                        "onRingtonePicked",
                        uri.toString()
                    )
                }
            }
        }
    }
    
    private fun scheduleNativeAlarm(
        alarmId: Int,
        timeMillis: Long,
        title: String,
        body: String,
        soundUri: String,
        priority: String,
        requiresCaptcha: Boolean,
        isRecurring: Boolean,
        selectedDays: IntArray,
        reminderHour: Int,
        reminderMinute: Int
    ): Boolean {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        
        val now = System.currentTimeMillis()
        val scheduledDate = java.util.Date(timeMillis)
        val currentDate = java.util.Date(now)
        
        Log.d(TAG, "==========================================")
        Log.d(TAG, "📅 SCHEDULING ALARM")
        Log.d(TAG, "==========================================")
        Log.d(TAG, "Alarm ID: $alarmId")
        Log.d(TAG, "Title: $title")
        Log.d(TAG, "Body: $body")
        Log.d(TAG, "Current time: $currentDate ($now)")
        Log.d(TAG, "Scheduled time: $scheduledDate ($timeMillis)")
        Log.d(TAG, "Time difference: ${(timeMillis - now) / 1000} seconds")
        Log.d(TAG, "Recurring: $isRecurring")
        Log.d(TAG, "Days: ${selectedDays.joinToString()}")
        Log.d(TAG, "==========================================")
        
        // Check if time is in past
        if (timeMillis <= now) {
            Log.e(TAG, "❌ ERROR: Scheduled time is in the PAST!")
            Log.e(TAG, "   Current: $now")
            Log.e(TAG, "   Scheduled: $timeMillis")
            Log.e(TAG, "   Difference: ${now - timeMillis} ms")
            Toast.makeText(this, "Error: Alarm time is in the past", Toast.LENGTH_LONG).show()
            return false
        }
        
        // Check exact alarm permission on Android 12+
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            if (!alarmManager.canScheduleExactAlarms()) {
                Log.e(TAG, "❌ ERROR: No permission to schedule exact alarms!")
                Toast.makeText(this, "Please grant 'Alarms & reminders' permission", Toast.LENGTH_LONG).show()
                val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                startActivity(intent)
                return false
            }
        }
        
        // Cancel any existing alarm with this ID first
        cancelNativeAlarm(alarmId)
        
        // Create the intent
        val intent = Intent(this, AlarmReceiver::class.java).apply {
            putExtra("id", alarmId)
            putExtra("title", title)
            putExtra("body", body)
            putExtra("sound", soundUri)
            putExtra("priority", priority)
            putExtra("requiresCaptcha", requiresCaptcha)
            putExtra("isRecurring", isRecurring)
            putExtra("selectedDays", selectedDays)
            putExtra("reminderHour", reminderHour)
            putExtra("reminderMinute", reminderMinute)
        }
        
        val pendingIntent = PendingIntent.getBroadcast(
            this,
            alarmId,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        try {
            // Use setAlarmClock for most reliable delivery
            val alarmClockInfo = AlarmManager.AlarmClockInfo(timeMillis, pendingIntent)
            alarmManager.setAlarmClock(alarmClockInfo, pendingIntent)
            
            Log.d(TAG, "✅ Alarm scheduled using setAlarmClock()")
            Log.d(TAG, "   Will ring at: $scheduledDate")
            Log.d(TAG, "==========================================")
            
            Toast.makeText(
                this, 
                "✅ Alarm set for ${scheduledDate.hours}:${scheduledDate.minutes.toString().padStart(2, '0')}", 
                Toast.LENGTH_SHORT
            ).show()
            
            return true
            
        } catch (e: SecurityException) {
            Log.e(TAG, "❌ SecurityException: ${e.message}")
            Toast.makeText(this, "Permission error: ${e.message}", Toast.LENGTH_LONG).show()
            return false
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error scheduling alarm: ${e.message}")
            e.printStackTrace()
            Toast.makeText(this, "Error: ${e.message}", Toast.LENGTH_LONG).show()
            return false
        }
    }
    
    private fun cancelNativeAlarm(alarmId: Int) {
        try {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val intent = Intent(this, AlarmReceiver::class.java)
            val pendingIntent = PendingIntent.getBroadcast(
                this,
                alarmId,
                intent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
            )
            
            alarmManager.cancel(pendingIntent)
            pendingIntent.cancel()
            Log.d(TAG, "✅ Cancelled alarm ID: $alarmId")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error cancelling alarm: ${e.message}")
        }
    }
    
    private fun stopRingtoneAndNotification(notificationId: Int) {
        try {
            AlarmReceiver.stopCurrentRingtone()
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.cancel(notificationId)
            Log.d(TAG, "✅ Stopped ringtone and cancelled notification ID: $notificationId")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error stopping ringtone: ${e.message}")
        }
    }
    
    companion object {
        private const val TAG = "MainActivity"
    }
}
