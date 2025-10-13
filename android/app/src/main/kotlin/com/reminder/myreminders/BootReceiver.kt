package com.reminder.myreminders

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.util.Log

class BootReceiver : BroadcastReceiver() {
    
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED ||
            intent.action == "android.intent.action.QUICKBOOT_POWERON") {
            
            Log.d(TAG, "Device booted - launching app to reschedule alarms")
            
            val launchIntent = context.packageManager.getLaunchIntentForPackage(context.packageName)
            launchIntent?.apply {
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
                putExtra("reschedule_alarms", true)
                context.startActivity(this)
            }
            
            Log.d(TAG, "App launched for alarm rescheduling")
        }
    }
    
    companion object {
        private const val TAG = "BootReceiver"
    }
}
