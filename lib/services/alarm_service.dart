import '../models/reminder_model.dart';
import 'storage_service.dart';
import 'platform_channel_service.dart';

class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal();

  final StorageService _storageService = StorageService();
  final PlatformChannelService _platformService = PlatformChannelService();

  Future<bool> scheduleAlarm(ReminderModel reminder) async {
    try {
      final DateTime now = DateTime.now();
      DateTime scheduledTime = _getNextAlarmTime(reminder, now);

      final int alarmId = reminder.id.hashCode.abs() % 2147483647;

      print('📅 Scheduling alarm for: ${reminder.text}');
      print('⏰ Current time: $now');
      print('⏰ Scheduled time: $scheduledTime');
      print('🆔 Alarm ID: $alarmId');
      print('🔄 Is recurring: ${reminder.isRecurring}');
      print('📆 Specific date: ${reminder.specificDate}');

      if (scheduledTime.isBefore(now)) {
        print('⚠️ Scheduled time is in the past! Skipping...');
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
      );

      if (success) {
        print('✅ Alarm scheduled successfully');
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
    if (!reminder.isRecurring && reminder.specificDate != null) {
      DateTime scheduledTime = DateTime(
        reminder.specificDate!.year,
        reminder.specificDate!.month,
        reminder.specificDate!.day,
        reminder.time.hour,
        reminder.time.minute,
      );
      
      print('📆 One-time reminder for: $scheduledTime');
      return scheduledTime;
    }

    DateTime scheduledTime = DateTime(
      now.year,
      now.month,
      now.day,
      reminder.time.hour,
      reminder.time.minute,
    );

    print('🔍 Initial scheduled time: $scheduledTime');
    print('🔍 Current time: $now');
    print('🔍 Time difference: ${scheduledTime.difference(now).inSeconds} seconds');

    if (scheduledTime.isBefore(now) || 
        scheduledTime.difference(now).inSeconds < 120) {
      print('⏭️ Time has passed or too close, moving to next occurrence');
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    int attempts = 0;
    int currentWeekday = scheduledTime.weekday - 1;
    
    print('🔍 Looking for next valid day...');
    print('🔍 Selected days: ${reminder.days}');
    print('🔍 Starting from weekday: $currentWeekday');

    while (!reminder.days.contains(currentWeekday) && attempts < 7) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
      currentWeekday = scheduledTime.weekday - 1;
      attempts++;
      print('🔍 Checking day $currentWeekday (attempt $attempts)');
    }

    if (attempts >= 7) {
      print('⚠️ No valid day found in next 7 days!');
    } else {
      print('✅ Found valid day: $currentWeekday');
    }

    print('🎯 Final scheduled time: $scheduledTime');
    return scheduledTime;
  }

  Future<void> cancelAlarm(String reminderId) async {
    try {
      final int alarmId = reminderId.hashCode.abs() % 2147483647;
      
      await _platformService.cancelNativeAlarm(alarmId);
      await _platformService.cancelNotification(alarmId);
      
      print('✅ Alarm and notification cancelled for ID: $reminderId (alarm ID: $alarmId)');
    } catch (e) {
      print('❌ Error cancelling alarm: $e');
    }
  }

  Future<void> rescheduleAllAlarms() async {
    try {
      final reminders = await _storageService.loadReminders();
      int count = 0;

      print('📋 Found ${reminders.length} total reminders');

      for (var reminder in reminders) {
        await cancelAlarm(reminder.id);
      }
      
      await Future.delayed(const Duration(seconds: 1));

      for (var reminder in reminders) {
        if (reminder.enabled) {
          final success = await scheduleAlarm(reminder);
          if (success) count++;
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }

      print('✅ Rescheduled $count alarms successfully');
    } catch (e) {
      print('❌ Error rescheduling alarms: $e');
    }
  }
}
