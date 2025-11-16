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
      DateTime scheduledTime;

      // Handle one-time reminders
      if (!reminder.isRecurring && reminder.specificDate != null) {
        scheduledTime = DateTime(
          reminder.specificDate!.year,
          reminder.specificDate!.month,
          reminder.specificDate!.day,
          reminder.time.hour,
          reminder.time.minute,
          0,
          0,
        );
        
        // If the scheduled time is in the past, don't schedule
        if (scheduledTime.isBefore(now)) {
          print('❌ One-time alarm is in the past, not scheduling');
          return false;
        }
      } else {
        // Handle recurring reminders
        scheduledTime = _getNextRecurringAlarmTime(reminder, now);
      }

      final int alarmId = reminder.id.hashCode.abs() % 2147483647;

      print('📅 ============ SCHEDULING ALARM ============');
      print('📅 Reminder: ${reminder.text}');
      print('⏰ Now: $now');
      print('⏰ Scheduled: $scheduledTime');
      print('⏰ Minutes until: ${scheduledTime.difference(now).inMinutes}');
      print('🆔 Alarm ID: $alarmId');
      print('🔄 Recurring: ${reminder.isRecurring}');
      if (reminder.isRecurring) {
        print('📆 Days: ${reminder.days.map((d) => _getDayName(d)).join(', ')}');
      }
      print('============================================');

      // Cancel existing alarm
      await cancelAlarm(reminder.id);
      await Future.delayed(const Duration(milliseconds: 100));

      // Schedule new alarm
      final success = await _platformService.scheduleNativeAlarm(
        alarmId: alarmId,
        scheduledTime: scheduledTime,
        title: reminder.category,
        body: reminder.text,
        soundUri: reminder.customSoundPath ?? '',
        priority: reminder.priority,
        requiresCaptcha: reminder.requiresCaptcha,
        isRecurring: reminder.isRecurring,
        selectedDays: reminder.isRecurring ? reminder.days : [],
        reminderHour: reminder.time.hour,
        reminderMinute: reminder.time.minute,
      );

      if (success) {
        print('✅ Alarm scheduled successfully!');
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

  DateTime _getNextRecurringAlarmTime(ReminderModel reminder, DateTime from) {
    List<int> selectedDays = reminder.days.isEmpty 
        ? List.generate(7, (index) => index) 
        : List.from(reminder.days)..sort();

    // Get current day (0=Monday, 6=Sunday)
    int currentDay = from.weekday == 7 ? 6 : from.weekday - 1;

    // Check today first
    DateTime todayAlarm = DateTime(
      from.year,
      from.month,
      from.day,
      reminder.time.hour,
      reminder.time.minute,
      0,
      0,
    );

    if (selectedDays.contains(currentDay) && todayAlarm.isAfter(from)) {
      return todayAlarm;
    }

    // Find next occurrence
    for (int i = 1; i <= 7; i++) {
      DateTime checkDate = from.add(Duration(days: i));
      int checkDay = checkDate.weekday == 7 ? 6 : checkDate.weekday - 1;

      if (selectedDays.contains(checkDay)) {
        return DateTime(
          checkDate.year,
          checkDate.month,
          checkDate.day,
          reminder.time.hour,
          reminder.time.minute,
          0,
          0,
        );
      }
    }

    // Fallback
    return todayAlarm.add(const Duration(days: 1));
  }

  String _getDayName(int index) {
    const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days[index];
  }

  Future<void> cancelAlarm(String reminderId) async {
    try {
      final int alarmId = reminderId.hashCode.abs() % 2147483647;
      await _platformService.cancelNativeAlarm(alarmId);
      await _platformService.cancelNotification(alarmId);
      print('✅ Cancelled alarm: $reminderId');
    } catch (e) {
      print('❌ Error cancelling alarm: $e');
    }
  }

  Future<void> rescheduleAllAlarms() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final needsReschedule = prefs.getBool('needs_reschedule') ?? false;
      
      if (!needsReschedule) {
        return;
      }

      print('🔄 Rescheduling all alarms...');
      
      final reminders = await _storageService.loadReminders();
      
      for (var reminder in reminders) {
        if (reminder.enabled) {
          await scheduleAlarm(reminder);
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }
      
      await prefs.setBool('needs_reschedule', false);
      print('✅ All alarms rescheduled');
    } catch (e) {
      print('❌ Error rescheduling: $e');
    }
  }
}
