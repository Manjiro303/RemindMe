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
import android.content.ComponentName
import android.content.pm.PackageManager

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.reminder.myreminders/permissions"
    private val RINGTONE_CHANNEL = "com.reminder.myreminders/ringtone"
    private val ALARM_CHANNEL = "com.reminder.myreminders/alarm"
    private val RINGTONE_PICKER_REQUEST = 999

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        Log.d(TAG, "🚀 Configuring Flutter Engine")
        
        // Enable boot receiver
        enableBootReceiver()
        
        // Check permissions
        checkAndRequestPermissions()
        
        setupPermissionChannel(flutterEngine)
        setupRingtoneChannel(flutterEngine)
        setupAlarmChannel(flutterEngine)
    }
    
    private fun enableBootReceiver() {
        try {
            val receiver = ComponentName(this, BootReceiver::class.java)
            packageManager.setComponentEnabledSetting(
                receiver,
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED,
                PackageManager.DONT_KILL_APP
            )
            Log.d(TAG, "✅ Boot receiver enabled")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error enabling boot receiver", e)
        }
    }
    
    private fun checkAndRequestPermissions() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            if (!alarmManager.canScheduleExactAlarms()) {
                Log.w(TAG, "⚠️ Exact alarm permission not granted")
                try {
                    startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM))
                } catch (e: Exception) {
                    Log.e(TAG, "Error requesting permission", e)
                }
            } else {
                Log.d(TAG, "✅ Exact alarm permission granted")
            }
        }
    }
    
    private fun setupPermissionChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "openSettings" -> {
                        openAppSettings()
                        result.success(null)
                    }
                    "canScheduleExactAlarms" -> {
                        result.success(canScheduleExactAlarms())
                    }
                    "requestExactAlarmPermission" -> {
                        requestExactAlarmPermission()
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
    
    private fun setupRingtoneChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RINGTONE_CHANNEL)
            .setMethodCallHandler { call, result ->
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
    }
    
    private fun setupAlarmChannel(flutterEngine: FlutterEngine) {
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, ALARM_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "scheduleAlarm" -> handleScheduleAlarm(call, result)
                    "cancelAlarm" -> handleCancelAlarm(call, result)
                    "cancelNotification" -> handleCancelNotification(call, result)
                    "stopRingtone" -> {
                        AlarmReceiver.stopRingtone()
                        result.success(true)
                    }
                    "getInitialIntent" -> {
                        result.success(getIntentData(intent))
                    }
                    else -> result.notImplemented()
                }
            }
    }
    
    private fun handleScheduleAlarm(call: io.flutter.plugin.common.MethodCall, result: io.flutter.plugin.common.MethodChannel.Result) {
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
            
            Log.d(TAG, "📱 Schedule alarm request:")
            Log.d(TAG, "   ID: $alarmId")
            Log.d(TAG, "   Time: $timeMillis")
            Log.d(TAG, "   Recurring: $isRecurring")
            Log.d(TAG, "   Days: ${selectedDays.joinToString()}")
            
            val success = scheduleAlarm(
                alarmId, timeMillis, title, body, soundUri, priority,
                requiresCaptcha, isRecurring, selectedDays, reminderHour, reminderMinute
            )
            
            result.success(success)
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error scheduling alarm", e)
            result.error("ALARM_ERROR", e.message, null)
        }
    }
    
    private fun handleCancelAlarm(call: io.flutter.plugin.common.MethodCall, result: io.flutter.plugin.common.MethodChannel.Result) {
        try {
            val alarmId = call.argument<Int>("alarmId") ?: 0
            cancelAlarm(alarmId)
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error cancelling alarm", e)
            result.error("CANCEL_ERROR", e.message, null)
        }
    }
    
    private fun handleCancelNotification(call: io.flutter.plugin.common.MethodCall, result: io.flutter.plugin.common.MethodChannel.Result) {
        try {
            val notificationId = call.argument<Int>("notificationId") ?: 0
            AlarmReceiver.stopRingtone()
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.cancel(notificationId)
            Log.d(TAG, "✅ Notification cancelled: $notificationId")
            result.success(true)
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error cancelling notification", e)
            result.error("CANCEL_NOTIF_ERROR", e.message, null)
        }
    }
    
    private fun scheduleAlarm(
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
        
        Log.d(TAG, "==========================================")
        Log.d(TAG, "📅 SCHEDULING ALARM")
        Log.d(TAG, "==========================================")
        
        val now = System.currentTimeMillis()
        val scheduledDate = java.util.Date(timeMillis)
        
        Log.d(TAG, "Alarm ID: $alarmId")
        Log.d(TAG, "Title: $title")
        Log.d(TAG, "Body: $body")
        Log.d(TAG, "Current time: ${java.util.Date(now)}")
        Log.d(TAG, "Scheduled time: $scheduledDate")
        Log.d(TAG, "Minutes until alarm: ${(timeMillis - now) / 60000}")
        Log.d(TAG, "Recurring: $isRecurring")
        if (isRecurring) {
            Log.d(TAG, "Days: ${selectedDays.joinToString()}")
            Log.d(TAG, "Time: $reminderHour:$reminderMinute")
        }
        Log.d(TAG, "==========================================")
        
        // Validation
        if (timeMillis <= now) {
            Log.e(TAG, "❌ Scheduled time is in the past!")
            Toast.makeText(this, "❌ Alarm time is in the past", Toast.LENGTH_LONG).show()
            return false
        }
        
        // Permission check
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            if (!am.canScheduleExactAlarms()) {
                Log.e(TAG, "❌ No exact alarm permission!")
                Toast.makeText(this, "⚠️ Grant 'Alarms & reminders' permission", Toast.LENGTH_LONG).show()
                requestExactAlarmPermission()
                return false
            }
        }
        
        // Cancel existing alarm
        cancelAlarm(alarmId)
        Thread.sleep(100)
        
        // Create alarm intent
        val alarmIntent = Intent(this, AlarmReceiver::class.java).apply {
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
            alarmIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        try {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            
            // Use setAlarmClock for reliability
            val alarmClockInfo = AlarmManager.AlarmClockInfo(timeMillis, pendingIntent)
            alarmManager.setAlarmClock(alarmClockInfo, pendingIntent)
            
            Log.d(TAG, "✅ Alarm scheduled successfully!")
            Log.d(TAG, "==========================================")
            
            val typeStr = if (isRecurring) {
                val dayNames = arrayOf("Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun")
                val daysStr = selectedDays.map { dayNames.getOrNull(it) ?: "?" }.joinToString(", ")
                "Recurring ($daysStr)"
            } else {
                "One-time"
            }
            
            Toast.makeText(
                this,
                "✅ $typeStr alarm set",
                Toast.LENGTH_SHORT
            ).show()
            
            return true
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error scheduling alarm", e)
            Toast.makeText(this, "❌ Error: ${e.message}", Toast.LENGTH_LONG).show()
            return false
        }
    }
    
    private fun cancelAlarm(alarmId: Int) {
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
            Log.d(TAG, "✅ Cancelled alarm: $alarmId")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error cancelling alarm", e)
        }
    }
    
    private fun canScheduleExactAlarms(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            am.canScheduleExactAlarms()
        } else {
            true
        }
    }
    
    private fun requestExactAlarmPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            try {
                startActivity(Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM))
            } catch (e: Exception) {
                Log.e(TAG, "Error requesting permission", e)
            }
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
            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_DEFAULT, true)
            putExtra(RingtoneManager.EXTRA_RINGTONE_SHOW_SILENT, false)
        }
        startActivityForResult(intent, RINGTONE_PICKER_REQUEST)
    }
    
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode == RINGTONE_PICKER_REQUEST && resultCode == RESULT_OK) {
            val uri: Uri? = data?.getParcelableExtra(RingtoneManager.EXTRA_RINGTONE_PICKED_URI)
            uri?.let {
                flutterEngine?.dartExecutor?.binaryMessenger?.let { messenger ->
                    MethodChannel(messenger, RINGTONE_CHANNEL).invokeMethod(
                        "onRingtonePicked",
                        it.toString()
                    )
                }
            }
        }
    }
    
    private fun getIntentData(intent: Intent?): Map<String, Any>? {
        if (intent?.action == "OPEN_ALARM") {
            return mapOf(
                "notification_id" to (intent.getIntExtra("alarm_id", 0)),
                "alarm_body" to (intent.getStringExtra("alarm_body") ?: "")
            )
        }
        return null
    }
    
    companion object {
        private const val TAG = "MainActivity"
    }
}
