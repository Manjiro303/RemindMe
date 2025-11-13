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
      print('📅 Alarm: ${reminder.text}');
      print('⏰ Current: $now');
      print('⏰ Scheduled: $scheduledTime');
      print('⏰ Minutes until alarm: ${scheduledTime.difference(now).inMinutes}');
      print('🆔 ID: $alarmId');
      print('🔄 Recurring: ${reminder.isRecurring}');
      print('📆 Days: ${reminder.days}');
      print('🔐 CAPTCHA: ${reminder.requiresCaptcha}');

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
        isRecurring: reminder.isRecurring,
        selectedDays: reminder.isRecurring ? reminder.days : [],
        reminderHour: reminder.time.hour,
        reminderMinute: reminder.time.minute,
      );

      if (success) {
        print('✅ Alarm scheduled successfully!');
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
    List<int> selectedDays = reminder.days.isEmpty 
        ? List.generate(7, (index) => index) 
        : List.from(reminder.days);

    selectedDays.sort();

    // Today's alarm time
    DateTime todayAlarm = DateTime(
      now.year,
      now.month,
      now.day,
      reminder.time.hour,
      reminder.time.minute,
      0,
      0,
    );

    // Get current day index (0 = Monday, 6 = Sunday)
    int currentDayIndex = now.weekday == 7 ? 6 : now.weekday - 1;

    print('🔍 Finding next alarm...');
    print('📅 Current day: $currentDayIndex (${_getDayName(currentDayIndex)})');
    print('📅 Selected days: ${selectedDays.map((d) => _getDayName(d)).join(', ')}');

    // Check if we can schedule for today
    if (selectedDays.contains(currentDayIndex) && now.isBefore(todayAlarm)) {
      print('✅ Scheduling for TODAY');
      return todayAlarm;
    }

    // Find next valid day
    for (int daysAhead = 1; daysAhead <= 7; daysAhead++) {
      DateTime checkDate = DateTime(
        now.year,
        now.month,
        now.day + daysAhead,
        reminder.time.hour,
        reminder.time.minute,
        0,
        0,
      );
      
      int checkDayIndex = checkDate.weekday == 7 ? 6 : checkDate.weekday - 1;
      
      if (selectedDays.contains(checkDayIndex)) {
        print('✅ Next alarm: ${_getDayName(checkDayIndex)} at $checkDate');
        return checkDate;
      }
    }

    // Fallback
    print('⚠️ Using fallback - tomorrow');
    return DateTime(
      now.year,
      now.month,
      now.day + 1,
      reminder.time.hour,
      reminder.time.minute,
      0,
      0,
    );
  }

  String _getDayName(int index) {
    const days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return days[index];
  }

  Future<void> cancelAlarm(String reminderId) async {
    try {
      final int alarmId = reminderId.hashCode.abs() % 2147483647;
      await _platformService.cancelNativeAlarm(alarmId);
      await _platformService.cancelNotification(alarmId);
      print('✅ Alarm cancelled: $reminderId');
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
      print('✅ All alarms rescheduled');
    } catch (e) {
      print('❌ Error rescheduling: $e');
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
      print('❌ Error cancelling all: $e');
    }
  }
}
