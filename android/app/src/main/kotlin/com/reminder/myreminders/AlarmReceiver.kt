private fun showFullScreenNotification(
    context: Context, 
    id: Int, 
    title: String, 
    body: String,
    requiresCaptcha: Boolean
) {
    try {
        val notificationManager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "alarm_channel",
                "Alarms",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Alarm notifications"
                enableVibration(true)
                setBypassDnd(true)
                lockscreenVisibility = NotificationCompat.VISIBILITY_PUBLIC
                setSound(
                    RingtoneManager.getDefaultUri(RingtoneManager.TYPE_ALARM),
                    null
                )
            }
            notificationManager.createNotificationChannel(channel)
        }
        
        val openIntent = Intent(context, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                   Intent.FLAG_ACTIVITY_CLEAR_TOP or
                   Intent.FLAG_ACTIVITY_SINGLE_TOP
            action = "OPEN_ALARM"
            putExtra("notification_id", id)
            putExtra("alarm_body", body)
            putExtra("alarm_title", title)
            putExtra("requires_captcha", requiresCaptcha)
        }
        
        val openPendingIntent = PendingIntent.getActivity(
            context,
            id,
            openIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val dismissIntent = Intent(context, AlarmReceiver::class.java).apply {
            action = "DISMISS_ALARM"
        }
        
        val dismissPendingIntent = PendingIntent.getBroadcast(
            context,
            id + 10000,
            dismissIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val notificationBuilder = NotificationCompat.Builder(context, "alarm_channel")
            .setSmallIcon(android.R.drawable.ic_lock_idle_alarm)
            .setContentTitle("⏰ $title")
            .setContentText(body)
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setAutoCancel(false)
            .setOngoing(true)
            .setVibrate(longArrayOf(0, 1000, 500, 1000, 500, 1000))
            .setContentIntent(openPendingIntent)
            .setFullScreenIntent(openPendingIntent, true)
        
        // Only add dismiss action if CAPTCHA is NOT required
        if (!requiresCaptcha) {
            notificationBuilder.addAction(0, "Dismiss", dismissPendingIntent)
        }
        
        notificationManager.notify(id, notificationBuilder.build())
        Log.d(TAG, "📱 Full-screen notification shown with ID: $id")
        
    } catch (e: Exception) {
        Log.e(TAG, "Error showing notification", e)
    }
}
