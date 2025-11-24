package com.reminder.myreminders

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import android.content.Intent
import android.provider.Settings
import android.os.Build
import android.app.AlarmManager
import android.content.Context
import android.util.Log
import android.app.PendingIntent
import android.widget.Toast
import android.app.NotificationManager

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.reminder.myreminders/alarm"
    private val TAG = "MainActivity"
    private var methodChannel: MethodChannel? = null
    private var pendingAlarmIntent: Intent? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        Log.d(TAG, "🚀 Configuring Flutter Engine")
        checkAndRequestPermissions()
        
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "scheduleAlarm" -> {
                    val success = scheduleAlarm(call.arguments as Map<String, Any>)
                    result.success(success)
                }
                "cancelAlarm" -> {
                    val alarmId = call.argument<Int>("alarmId") ?: 0
                    cancelAlarm(alarmId)
                    result.success(true)
                }
                "stopRingtone" -> {
                    AlarmReceiver.stopRingtone()
                    val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                    notificationManager.cancelAll()
                    result.success(true)
                }
                "canScheduleExactAlarms" -> {
                    result.success(canScheduleExactAlarms())
                }
                "requestPermission" -> {
                    requestExactAlarmPermission()
                    result.success(null)
                }
                "getPendingAlarmIntent" -> {
                    if (pendingAlarmIntent != null) {
                        val notificationId = pendingAlarmIntent!!.getIntExtra("notification_id", 0)
                        val alarmBody = pendingAlarmIntent!!.getStringExtra("alarm_body") ?: ""
                        result.success(mapOf(
                            "notification_id" to notificationId,
                            "alarm_body" to alarmBody
                        ))
                        pendingAlarmIntent = null
                    } else {
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
        
        android.os.Handler(android.os.Looper.getMainLooper()).postDelayed({
            handleIntent(intent)
        }, 500)
    }
    
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        Log.d(TAG, "📱 onNewIntent called")
        handleIntent(intent)
    }
    
    override fun onResume() {
        super.onResume()
        Log.d(TAG, "📱 onResume called")
        handleIntent(intent)
    }
    
    private fun handleIntent(intent: Intent?) {
        Log.d(TAG, "🔍 Checking intent...")
        Log.d(TAG, "Action: ${intent?.action}")
        Log.d(TAG, "Extras: ${intent?.extras}")
        
        if (intent?.action == "OPEN_ALARM") {
            val notificationId = intent.getIntExtra("notification_id", 0)
            val alarmBody = intent.getStringExtra("alarm_body") ?: ""
            
            Log.d(TAG, "📱 ALARM NOTIFICATION CLICKED!")
            Log.d(TAG, "Notification ID: $notificationId")
            Log.d(TAG, "Alarm Body: $alarmBody")
            
            if (methodChannel != null) {
                Log.d(TAG, "✅ Sending to Flutter immediately")
                methodChannel?.invokeMethod("onAlarmDetail", mapOf(
                    "notification_id" to notificationId,
                    "alarm_body" to alarmBody
                ))
            } else {
                Log.d(TAG, "⏳ Flutter not ready, storing intent")
                pendingAlarmIntent = intent
            }
            
            intent.action = null
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.cancel(notificationId)
            
            AlarmReceiver.stopRingtone()
        }
    }
    
    private fun checkAndRequestPermissions() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            if (!alarmManager.canScheduleExactAlarms()) {
                Log.w(TAG, "⚠️ Exact alarm permission not granted")
            } else {
                Log.d(TAG, "✅ Exact alarm permission granted")
            }
        }
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 101)
        }
    }
    
    private fun scheduleAlarm(args: Map<String, Any>): Boolean {
        try {
            val alarmId = args["alarmId"] as Int
            val timeMillis = args["scheduledTimeMillis"] as Long
            val title = args["title"] as String
            val body = args["body"] as String
            val isRecurring = args["isRecurring"] as Boolean
            val selectedDays = (args["selectedDays"] as? List<Int>)?.toIntArray() ?: intArrayOf()
            val reminderHour = args["reminderHour"] as Int
            val reminderMinute = args["reminderMinute"] as Int
            
            Log.d(TAG, "========================================")
            Log.d(TAG, "📅 SCHEDULING ALARM")
            Log.d(TAG, "ID: $alarmId")
            Log.d(TAG, "Title: $title")
            Log.d(TAG, "Body: $body")
            Log.d(TAG, "Time: ${java.util.Date(timeMillis)}")
            Log.d(TAG, "Recurring: $isRecurring")
            Log.d(TAG, "Days: ${selectedDays.joinToString()}")
            Log.d(TAG, "========================================")
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.S) {
                val am = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                if (!am.canScheduleExactAlarms()) {
                    Log.e(TAG, "❌ No permission!")
                    Toast.makeText(this, "Please grant Alarms & reminders permission", Toast.LENGTH_LONG).show()
                    requestExactAlarmPermission()
                    return false
                }
            }
            
            val now = System.currentTimeMillis()
            if (timeMillis <= now) {
                Log.e(TAG, "❌ Time is in the past!")
                Toast.makeText(this, "Cannot schedule alarm in the past", Toast.LENGTH_SHORT).show()
                return false
            }
            
            cancelAlarm(alarmId)
            Thread.sleep(100)
            
            val intent = Intent(this, AlarmReceiver::class.java).apply {
                putExtra("id", alarmId)
                putExtra("title", title)
                putExtra("body", body)
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
            
            val alarmManager = getSystemService(Context.ALARM_SERVICE) as AlarmManager
            
            when {
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.S -> {
                    val info = AlarmManager.AlarmClockInfo(timeMillis, pendingIntent)
                    alarmManager.setAlarmClock(info, pendingIntent)
                    Log.d(TAG, "✅ Using setAlarmClock (Android 12+)")
                }
                Build.VERSION.SDK_INT >= Build.VERSION_CODES.M -> {
                    alarmManager.setExactAndAllowWhileIdle(
                        AlarmManager.RTC_WAKEUP,
                        timeMillis,
                        pendingIntent
                    )
                    Log.d(TAG, "✅ Using setExactAndAllowWhileIdle (Android 6-11)")
                }
                else -> {
                    alarmManager.setExact(
                        AlarmManager.RTC_WAKEUP,
                        timeMillis,
                        pendingIntent
                    )
                    Log.d(TAG, "✅ Using setExact (Android 5-)")
                }
            }
            
            saveAlarmData(alarmId, title, body, isRecurring, selectedDays, reminderHour, reminderMinute)
            
            val minutesUntil = (timeMillis - now) / 60000
            Toast.makeText(this, "⏰ Alarm set for $minutesUntil minutes from now", Toast.LENGTH_SHORT).show()
            Log.d(TAG, "✅ Alarm scheduled successfully!")
            Log.d(TAG, "========================================")
            
            return true
            
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error scheduling alarm", e)
            Toast.makeText(this, "Failed to schedule alarm: ${e.message}", Toast.LENGTH_SHORT).show()
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
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.cancel(alarmId)
            
            removeAlarmData(alarmId)
            
            Log.d(TAG, "✅ Cancelled alarm: $alarmId")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Error cancelling alarm", e)
        }
    }
    
    private fun saveAlarmData(
        id: Int,
        title: String,
        body: String,
        isRecurring: Boolean,
        days: IntArray,
        hour: Int,
        minute: Int
    ) {
        val prefs = getSharedPreferences("RemindMeAlarms", Context.MODE_PRIVATE)
        val editor = prefs.edit()
        
        editor.putString("alarm_${id}_title", title)
        editor.putString("alarm_${id}_body", body)
        editor.putBoolean("alarm_${id}_recurring", isRecurring)
        editor.putString("alarm_${id}_days", days.joinToString(","))
        editor.putInt("alarm_${id}_hour", hour)
        editor.putInt("alarm_${id}_minute", minute)
        
        val ids = prefs.getStringSet("active_ids", mutableSetOf()) ?: mutableSetOf()
        val newIds = ids.toMutableSet()
        newIds.add(id.toString())
        editor.putStringSet("active_ids", newIds)
        
        editor.apply()
        Log.d(TAG, "💾 Saved alarm data to preferences")
    }
    
    private fun removeAlarmData(id: Int) {
        val prefs = getSharedPreferences("RemindMeAlarms", Context.MODE_PRIVATE)
        val editor = prefs.edit()
        
        editor.remove("alarm_${id}_title")
        editor.remove("alarm_${id}_body")
        editor.remove("alarm_${id}_recurring")
        editor.remove("alarm_${id}_days")
        editor.remove("alarm_${id}_hour")
        editor.remove("alarm_${id}_minute")
        
        val ids = prefs.getStringSet("active_ids", mutableSetOf()) ?: mutableSetOf()
        val newIds = ids.toMutableSet()
        newIds.remove(id.toString())
        editor.putStringSet("active_ids", newIds)
        
        editor.apply()
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
                val intent = Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM)
                startActivity(intent)
            } catch (e: Exception) {
                Log.e(TAG, "Error requesting permission", e)
            }
        }
    }
}
