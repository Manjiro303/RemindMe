package com.reminder.myreminders

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log
import android.app.AlarmManager
import android.app.PendingIntent
import android.os.Build

class BootReceiver : BroadcastReceiver() {
    
    override fun onReceive(context: Context, intent: Intent) {
        val action = intent.action
        if (action == Intent.ACTION_BOOT_COMPLETED ||
            action == Intent.ACTION_LOCKED_BOOT_COMPLETED ||
            action == "android.intent.action.QUICKBOOT_POWERON") {
            
            Log.d(TAG, "📱 Device booted - Will reschedule alarms when app opens")
            
            // Set a flag in SharedPreferences to reschedule on next app open
            val prefs = context.getSharedPreferences("alarm_prefs", Context.MODE_PRIVATE)
            prefs.edit().putBoolean("needs_reschedule", true).apply()
            
            Log.d(TAG, "✅ Reschedule flag set")
        }
    }
    
    companion object {
        private const val TAG = "BootReceiver"
    }
}
