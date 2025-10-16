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

      print('📅 ============ SCHEDULING ALARM ============');
      print('📅 Alarm for: ${reminder.text}');
      print('⏰ Current time: $now');
      print('⏰ Scheduled time: $scheduledTime');
      print('⏰ Time until alarm: ${scheduledTime.difference(now).inMinutes} minutes');
      print('🆔 Alarm ID: $alarmId');
      print('🔄 Is recurring: ${reminder.isRecurring}');
      print('📆 Specific date: ${reminder.specificDate}');
      print('📆 Selected days: ${reminder.days}');

      // Check if time is in the past
      if (scheduledTime.isBefore(now)) {
        print('❌ ERROR: Scheduled time is in the past!');
        return false;
      }

      // Cancel existing alarm
      await cancelAlarm(reminder.id);
      await Future.delayed(const Duration(milliseconds: 500));

      // Schedule the alarm
      final success = await _platformService.scheduleNativeAlarm(
        alarmId: alarmId,
        scheduledTime: scheduledTime,
        title: reminder.category,
        body: reminder.text,
        soundUri: reminder.customSoundPath ?? '',
        priority: reminder.priority,
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
    // For one-time reminders with specific date
    if (!reminder.isRecurring && reminder.specificDate != null) {
      DateTime scheduledTime = DateTime(
        reminder.specificDate!.year,
        reminder.specificDate!.month,
        reminder.specificDate!.day,
        reminder.time.hour,
        reminder.time.minute,
        0,
        0,
      );
      
      print('📆 One-time reminder calculated: $scheduledTime');
      return scheduledTime;
    }

    // For recurring reminders
    DateTime scheduledTime = DateTime(
      now.year,
      now.month,
      now.day,
      reminder.time.hour,
      reminder.time.minute,
      0,
      0,
    );

    print('🔍 Initial time today: $scheduledTime');
    
    final secondsUntil = scheduledTime.difference(now).inSeconds;
    print('🔍 Seconds until alarm: $secondsUntil');

    // If time has passed OR less than 30 seconds away, move to next day
    if (scheduledTime.isBefore(now) || secondsUntil < 30) {
      print('⏭️ Moving to next day (time passed or too close)');
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    // Find next valid day for recurring reminders
    int attempts = 0;
    int currentWeekday = scheduledTime.weekday - 1; // 0 = Monday
    
    print('🔍 Selected days: ${reminder.days}');
    print('🔍 Current weekday: $currentWeekday (${_getDayName(currentWeekday)})');

    while (!reminder.days.contains(currentWeekday) && attempts < 7) {
      print('⏭️ Day $currentWeekday not selected, moving forward');
      scheduledTime = scheduledTime.add(const Duration(days: 1));
      currentWeekday = scheduledTime.weekday - 1;
      attempts++;
    }

    if (attempts >= 7) {
      print('❌ No valid day found!');
    } else {
      print('✅ Valid day found: $currentWeekday (${_getDayName(currentWeekday)})');
    }

    print('🎯 Final time: $scheduledTime');
    return scheduledTime;
  }

  String _getDayName(int weekday) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[weekday];
  }

  Future<void> cancelAlarm(String reminderId) async {
    try {
      final int alarmId = reminderId.hashCode.abs() % 2147483647;
      
      await _platformService.cancelNativeAlarm(alarmId);
      await _platformService.cancelNotification(alarmId);
      
      print('✅ Cancelled alarm ID: $reminderId (native ID: $alarmId)');
    } catch (e) {
      print('❌ Error cancelling: $e');
    }
  }

  Future<void> rescheduleAllAlarms() async {
    try {
      final reminders = await _storageService.loadReminders();
      
      print('📋 ========== RESCHEDULING ALL ALARMS ==========');
      print('📋 Total reminders: ${reminders.length}');

      // Cancel all first
      for (var reminder in reminders) {
        await cancelAlarm(reminder.id);
      }
      
      await Future.delayed(const Duration(seconds: 1));

      // Reschedule enabled ones
      int count = 0;
      for (var reminder in reminders) {
        if (reminder.enabled) {
          print('\n🔄 Scheduling: ${reminder.text}');
          final success = await scheduleAlarm(reminder);
          if (success) count++;
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }

      print('\n✅ ========== RESCHEDULE COMPLETE ==========');
      print('✅ Rescheduled $count alarms');
      print('============================================\n');
    } catch (e) {
      print('❌ Reschedule error: $e');
    }
  }
}
