Future<bool> scheduleAlarm(ReminderModel reminder) async {
    try {
      final DateTime now = DateTime.now();
      DateTime scheduledTime = _getNextAlarmTime(reminder, now);

      final int alarmId = reminder.id.hashCode.abs() % 2147483647;

      print('📅 ============ SCHEDULING ALARM ============');
      print('📅 Alarm for: ${reminder.text}');
      print('⏰ Current time: $now');
      print('⏰ Scheduled time: $scheduledTime');
      print('⏰ Time until alarm: ${scheduledTime.difference(now).inMinutes} minutes');
      print('🆔 Alarm ID: $alarmId');
      print('🔄 Is recurring: ${reminder.isRecurring}');
      print('📆 Specific date: ${reminder.specificDate}');
      print('📆 Selected days: ${reminder.days}');
      print('🔐 Requires CAPTCHA: ${reminder.requiresCaptcha}');

      if (scheduledTime.isBefore(now)) {
        print('❌ ERROR: Scheduled time is in the past!');
        return false;
      }

      await cancelAlarm(reminder.id);
      await Future.delayed(const Duration(milliseconds: 500));

      final success = await _platformService.scheduleNativeAlarm(
        alarmId: alarmId,
        scheduledTime: scheduledTime,
        title: reminder.category,
        body: reminder.text,
        soundUri: reminder.customSoundPath ?? '',
        priority: reminder.priority,
        requiresCaptcha: reminder.requiresCaptcha,
      );

      if (success) {
        print('✅ Alarm scheduled successfully!');
        print('✅ Will ring in ${scheduledTime.difference(now).inMinutes} minutes');
        print('============================================');
        return true;
      } else {
        print('❌ Failed to schedule alarm');
        return false;
      }
    } catch (e) {
      print('❌ Error scheduling alarm: $e');
      return false;
    }
  }
