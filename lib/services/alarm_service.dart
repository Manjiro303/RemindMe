import 'package:shared_preferences/shared_preferences.dart';
import '../models/reminder_model.dart';
import 'platform_channel_service.dart';
import 'storage_service.dart';

class AlarmService {
  final PlatformChannelService _platformService = PlatformChannelService();
  final StorageService _storageService = StorageService();

  Future<bool> scheduleAlarm(ReminderModel reminder) async {
    try {
      print('========================================');
      print('📅 SCHEDULING: ${reminder.text}');
      
      final now = DateTime.now();
      DateTime alarmTime;

      // ONE-TIME ALARM
      if (!reminder.isRecurring && reminder.specificDate != null) {
        alarmTime = DateTime(
          reminder.specificDate!.year,
          reminder.specificDate!.month,
          reminder.specificDate!.day,
          reminder.time.hour,
          reminder.time.minute,
          0,
        );
      } 
      // RECURRING ALARM
      else {
        alarmTime = _findNext(reminder, now);
      }

      print('⏰ Scheduled for: $alarmTime');
      print('⏰ In ${alarmTime.difference(now).inMinutes} minutes');
      print('========================================');

      if (alarmTime.isBefore(now)) {
        print('❌ Time is in past!');
        return false;
      }

      final id = reminder.id.hashCode.abs() % 2147483647;

      await cancelAlarm(reminder.id);
      await Future.delayed(const Duration(milliseconds: 100));

      final success = await _platformService.scheduleNativeAlarm(
        alarmId: id,
        scheduledTime: alarmTime,
        title: reminder.category,
        body: reminder.text,
        soundUri: '',
        priority: reminder.priority,
        requiresCaptcha: reminder.requiresCaptcha,
        isRecurring: reminder.isRecurring,
        selectedDays: reminder.isRecurring ? reminder.days : [],
        reminderHour: reminder.time.hour,
        reminderMinute: reminder.time.minute,
      );

      print(success ? '✅ SCHEDULED' : '❌ FAILED');
      return success;
    } catch (e) {
      print('❌ Error: $e');
      return false;
    }
  }

  DateTime _findNext(ReminderModel reminder, DateTime from) {
    final days = reminder.days.isEmpty ? [0,1,2,3,4,5,6] : reminder.days;
    final today = from.weekday == 7 ? 6 : from.weekday - 1;
    
    // Try today first
    final todayTime = DateTime(
      from.year, from.month, from.day,
      reminder.time.hour, reminder.time.minute, 0,
    );
    
    if (days.contains(today) && todayTime.isAfter(from)) {
      return todayTime;
    }
    
    // Try next 7 days
    for (int i = 1; i <= 7; i++) {
      final check = from.add(Duration(days: i));
      final checkDay = check.weekday == 7 ? 6 : check.weekday - 1;
      
      if (days.contains(checkDay)) {
        return DateTime(
          check.year, check.month, check.day,
          reminder.time.hour, reminder.time.minute, 0,
        );
      }
    }
    
    // Fallback
    return todayTime.add(const Duration(days: 1));
  }

  Future<void> cancelAlarm(String reminderId) async {
    final id = reminderId.hashCode.abs() % 2147483647;
    await _platformService.cancelNativeAlarm(id);
    await _platformService.cancelNotification(id);
  }

  Future<void> rescheduleAllAlarms() async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('needs_reschedule') != true) return;
    
    final reminders = await _storageService.loadReminders();
    for (var r in reminders) {
      if (r.enabled) await scheduleAlarm(r);
    }
    
    await prefs.setBool('needs_reschedule', false);
  }
}
