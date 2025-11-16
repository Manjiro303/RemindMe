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

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.reminder.myreminders/permissions"
    private val RINGTONE_CHANNEL = "com.reminder.myreminders/ringtone"
    private val ALARM_CHANNEL = "com.reminder.myreminders/alarm"
    private val RINGTONE_PICKER_REQUEST = 999

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
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
                        
                        scheduleNativeAlarm(
                            alarmId, timeMillis, title, body, soundUri, priority, 
                            requiresCaptcha, isRecurring, selectedDays, reminderHour, reminderMinute
                        )
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error in scheduleAlarm: ${e.message}")
                        result.error("ALARM_ERROR", e.message, null)
                    }
                }
                "cancelAlarm" -> {
                    try {
                        val alarmId = call.argument<Int>("alarmId") ?: 0
                        cancelNativeAlarm(alarmId)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error in cancelAlarm: ${e.message}")
                        result.error("CANCEL_ERROR", e.message, null)
                    }
                }
                "cancelNotification" -> {
                    try {
                        val notificationId = call.argument<Int>("notificationId") ?: 0
                        stopRingtoneAndNotification(notificationId)
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error in cancelNotification: ${e.message}")
                        result.error("CANCEL_NOTIF_ERROR", e.message, null)
                    }
                }
                "stopRingtone" -> {
                    try {
                        AlarmReceiver.stopCurrentRingtone()
                        result.success(true)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error in stopRingtone: ${e.message}")
                        result.error("STOP_RINGTONE_ERROR", e.message, null)
                    }
                }
                "getInitialIntent" -> {
                    try {
                        val intentData = getIntentData(intent)
                        result.success(intentData)
                    } catch (e: Exception) {
                        Log.e(TAG, "Error getting initial intent: ${e.message}")
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
        Log.d(TAG, "🔔 onNewIntent called with action: ${intent.action}")
        
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
        
        Log.d(TAG, "Opening alarm detail: $alarmTitle, CAPTCHA: $requiresCaptcha")
        
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

    override fun onResume() {
        super.onResume()
        Log.d(TAG, "onResume called")
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
                Log.d(TAG, "Selected ringtone: $uri")
                
                flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                    MethodChannel(messenger, RINGTONE_CHANNEL).invokeMethod(
                        "onRingtonePicked",
                        uri.toString()
                    )
                }
            } else {
                Log.d(TAG, "No ringtone selected")
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
    ) {
        val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
        
        val scheduledDate = java.util.Date(timeMillis)
        val now = java.util.Date()
        
        Log.d(TAG, "📅 ========== SCHEDULING NATIVE ALARM ==========")
        Log.d(TAG, "  - ID: $alarmId")
        Log.d(TAG, "  - Current Time: $now")
        Log.d(TAG, "  - Scheduled Time: $scheduledDate")
        Log.d(TAG, "  - Time Millis: $timeMillis")
        Log.d(TAG, "  - Title: $title")
        Log.d(TAG, "  - Body: $body")
        Log.d(TAG, "  - Sound: $soundUri")
        Log.d(TAG, "  - Priority: $priority")
        Log.d(TAG, "  - Requires CAPTCHA: $requiresCaptcha")
        Log.d(TAG, "  - Recurring: $isRecurring")
        Log.d(TAG, "  - Days: ${selectedDays.joinToString()}")
        Log.d(TAG, "  - Hour: $reminderHour, Minute: $reminderMinute")
        
        cancelNativeAlarm(alarmId)
        cancelNotification(alarmId)
        
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
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                if (!alarmManager.canScheduleExactAlarms()) {
                    Log.w(TAG, "⚠️ Cannot schedule exact alarms. Requesting permission...")
                    val permIntent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                    startActivity(permIntent)
                    return
                }
            }
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                alarmManager.setExactAndAllowWhileIdle(
                    AlarmManager.RTC_WAKEUP,
                    timeMillis,
                    pendingIntent
                )
            } else {
                alarmManager.setExact(
                    AlarmManager.RTC_WAKEUP,
                    timeMillis,
                    pendingIntent
                )
            }
            
            Log.d(TAG, "✅ Native alarm scheduled successfully for ID: $alarmId")
            
        } catch (e: SecurityException) {
            Log.e(TAG, "❌ SecurityException: ${e.message}")
            Log.e(TAG, "   Please grant exact alarm permission in settings")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error scheduling alarm: ${e.message}")
            e.printStackTrace()
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
            
            Log.d(TAG, "✅ Native alarm cancelled for ID: $alarmId")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error cancelling alarm: ${e.message}")
        }
    }
    
    private fun stopRingtoneAndNotification(notificationId: Int) {
        try {
            // Stop the ringtone first
            AlarmReceiver.stopCurrentRingtone()
            
            // Then cancel the notification
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.cancel(notificationId)
            
            Log.d(TAG, "✅ Ringtone stopped and notification cancelled for ID: $notificationId")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error stopping ringtone and notification: ${e.message}")
        }
    }
    
    private fun cancelNotification(notificationId: Int) {
        try {
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.cancel(notificationId)
            Log.d(TAG, "✅ Notification cancelled for ID: $notificationId")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error cancelling notification: ${e.message}")
        }
    }
    
    companion object {
        private const val TAG = "MainActivity"
    }
}
