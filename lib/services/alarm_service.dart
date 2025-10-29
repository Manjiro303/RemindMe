import 'package:shared_preferences/shared_preferences.dart';
import '../models/reminder_model.dart';
import 'platform_channel_service.dart';
import 'storage_service.dart';

class AlarmService {
  final PlatformChannelService _platformService = PlatformChannelService();
  final StorageService _storageService = StorageService();

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

  DateTime _getNextAlarmTime(ReminderModel reminder, DateTime now) {
    // Handle one-time reminders
    if (!reminder.isRecurring && reminder.specificDate != null) {
      final scheduledTime = DateTime(
        reminder.specificDate!.year,
        reminder.specificDate!.month,
        reminder.specificDate!.day,
        reminder.time.hour,
        reminder.time.minute,
        0,
        0,
      );
      
      return scheduledTime;
    }

    // Handle recurring reminders
    DateTime scheduledTime = DateTime(
      now.year,
      now.month,
      now.day,
      reminder.time.hour,
      reminder.time.minute,
      0,
      0,
    );

    // If no days are selected, treat as all days selected
    List<int> selectedDays = reminder.days.isEmpty 
        ? List.generate(7, (index) => index) 
        : reminder.days;

    // If the time has passed today or is now, start from tomorrow
    if (scheduledTime.isBefore(now) || scheduledTime.isAtSameMomentAs(now)) {
      scheduledTime = DateTime(
        now.year,
        now.month,
        now.day + 1,
        reminder.time.hour,
        reminder.time.minute,
        0,
        0,
      );
    }

    // Find the next valid day (check up to 7 days)
    for (int i = 0; i < 7; i++) {
      final dayOfWeek = (scheduledTime.weekday - 1) % 7; // Convert to 0-6 (Monday = 0)
      
      if (selectedDays.contains(dayOfWeek)) {
        return scheduledTime;
      }
      
      // Move to next day
      scheduledTime = DateTime(
        scheduledTime.year,
        scheduledTime.month,
        scheduledTime.day + 1,
        reminder.time.hour,
        reminder.time.minute,
        0,
        0,
      );
    }

    // Fallback: return the calculated time
    return scheduledTime;
  }

  Future<void> cancelAlarm(String reminderId) async {
    try {
      final int alarmId = reminderId.hashCode.abs() % 2147483647;
      await _platformService.cancelNativeAlarm(alarmId);
      await _platformService.cancelNotification(alarmId);
      print('✅ Alarm and notification cancelled for ID: $reminderId');
    } catch (e) {
      print('❌ Error cancelling alarm: $e');
    }
  }

  Future<void> rescheduleAllAlarms() async {
    try {
      print('🔄 Checking if alarms need rescheduling...');
      
      final prefs = await SharedPreferences.getInstance();
      final needsReschedule = prefs.getBool('needs_reschedule') ?? false;
      
      if (!needsReschedule) {
        print('✅ No rescheduling needed');
        return;
      }

      print('📅 Rescheduling all alarms after boot...');
      
      final reminders = await _storageService.loadReminders();
      
      for (var reminder in reminders) {
        if (reminder.enabled) {
          await scheduleAlarm(reminder);
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }
      
      await prefs.setBool('needs_reschedule', false);
      print('✅ All alarms rescheduled successfully');
    } catch (e) {
      print('❌ Error rescheduling alarms: $e');
    }
  }

  Future<void> cancelAllAlarms() async {
    try {
      final reminders = await _storageService.loadReminders();
      
      for (var reminder in reminders) {
        await cancelAlarm(reminder.id);
      }
      
      print('✅ All alarms cancelled');
    } catch (e) {
      print('❌ Error cancelling all alarms: $e');
    }
  }
}
