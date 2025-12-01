import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../models/reminder_model.dart';

class AlarmService {
  static const platform = MethodChannel('com.reminder.myreminders/alarm');

  /// Generate unique alarm ID from UUID to prevent collisions
  int _generateUniqueAlarmId(String uuid) {
    try {
      // Convert UUID to unique integer ID
      // Take first 8 hex chars and convert to int
      final hex = uuid.replaceAll('-', '').substring(0, 8);
      return int.parse(hex, radix: 16) % 2147483647;
    } catch (e) {
      print('❌ Error generating alarm ID: $e');
      // Fallback to hashCode if UUID parsing fails
      return uuid.hashCode.abs() % 2147483647;
    }
  }

  Future<bool> scheduleAlarm(ReminderModel reminder) async {
    try {
      print('\n========================================');
      print('📅 SCHEDULING ALARM');
      print('Text: ${reminder.text}');
      print('Category: ${reminder.category}');
      print('Recurring: ${reminder.isRecurring}');
      print('Requires Captcha: ${reminder.requiresCaptcha}');
      print('========================================\n');

      final DateTime alarmTime = _calculateAlarmTime(reminder);
      
      if (alarmTime.isBefore(DateTime.now())) {
        print('❌ Alarm time is in the past!');
        return false;
      }

      final minutesUntil = alarmTime.difference(DateTime.now()).inMinutes;
      print('⏰ Will fire in $minutesUntil minutes');
      print('⏰ At: $alarmTime');

      // Use improved ID generation
      final alarmId = _generateUniqueAlarmId(reminder.id);
      print('🆔 Alarm ID: $alarmId (from UUID: ${reminder.id})');

      final result = await platform.invokeMethod('scheduleAlarm', {
        'alarmId': alarmId,
        'scheduledTimeMillis': alarmTime.millisecondsSinceEpoch,
        'title': reminder.category,
        'body': reminder.text,
        'isRecurring': reminder.isRecurring,
        'selectedDays': reminder.isRecurring ? reminder.days : [],
        'reminderHour': reminder.time.hour,
        'reminderMinute': reminder.time.minute,
        'requiresCaptcha': reminder.requiresCaptcha,
      });

      print(result ? '✅ SUCCESS' : '❌ FAILED');
      print('========================================\n');
      
      return result == true;
      
    } catch (e, stackTrace) {
      print('❌ ERROR scheduling alarm: $e');
      print('Stack: $stackTrace');
      return false;
    }
  }

  DateTime _calculateAlarmTime(ReminderModel reminder) {
    final now = DateTime.now();
    
    // Handle one-time reminders with specific date
    if (!reminder.isRecurring && reminder.specificDate != null) {
      final alarmTime = DateTime(
        reminder.specificDate!.year,
        reminder.specificDate!.month,
        reminder.specificDate!.day,
        reminder.time.hour,
        reminder.time.minute,
        0,
        0,
      );
      // Ensure we use local time zone
      return alarmTime.toLocal();
    }
    
    // Handle recurring reminders
    final days = reminder.days.isEmpty ? [0, 1, 2, 3, 4, 5, 6] : reminder.days;
    
    final todayAlarm = DateTime(
      now.year,
      now.month,
      now.day,
      reminder.time.hour,
      reminder.time.minute,
      0,
      0,
    );
    
    // Convert current day to 0-6 format (Mon=0, Sun=6)
    final todayDay = now.weekday == 7 ? 6 : now.weekday - 1;
    
    // Check if alarm should fire today
    if (days.contains(todayDay) && 
        todayAlarm.isAfter(now.add(const Duration(seconds: 5)))) {
      print('✓ Next occurrence: TODAY at ${reminder.time.hour}:${reminder.time.minute}');
      return todayAlarm;
    }
    
    // Find next occurrence in the next 7 days
    for (int daysAhead = 1; daysAhead <= 7; daysAhead++) {
      final checkDate = now.add(Duration(days: daysAhead));
      final checkDay = checkDate.weekday == 7 ? 6 : checkDate.weekday - 1;
      
      if (days.contains(checkDay)) {
        final nextAlarm = DateTime(
          checkDate.year,
          checkDate.month,
          checkDate.day,
          reminder.time.hour,
          reminder.time.minute,
          0,
          0,
        );
        
        final dayName = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'][checkDay];
        print('✓ Next occurrence: $dayName ($daysAhead days)');
        return nextAlarm;
      }
    }
    
    // Fallback: schedule for tomorrow (shouldn't reach here normally)
    print('⚠️ Using fallback: tomorrow');
    return todayAlarm.add(const Duration(days: 1));
  }

  Future<void> cancelAlarm(String reminderId) async {
    try {
      final alarmId = _generateUniqueAlarmId(reminderId);
      print('🗑️ Cancelling alarm ID: $alarmId (UUID: $reminderId)');
      
      await platform.invokeMethod('cancelAlarm', {'alarmId': alarmId});
      print('✅ Alarm cancelled successfully');
      
    } catch (e) {
      print('❌ Error cancelling alarm: $e');
    }
  }

  Future<void> stopRingtone() async {
    try {
      await platform.invokeMethod('stopRingtone');
      print('✅ Ringtone stopped');
    } catch (e) {
      print('❌ Error stopping ringtone: $e');
    }
  }

  Future<bool> canScheduleExactAlarms() async {
    try {
      final result = await platform.invokeMethod('canScheduleExactAlarms');
      return result == true;
    } catch (e) {
      print('❌ Error checking exact alarm permission: $e');
      return false;
    }
  }

  Future<void> requestPermission() async {
    try {
      await platform.invokeMethod('requestPermission');
    } catch (e) {
      print('❌ Error requesting permission: $e');
    }
  }

  Future<void> rescheduleAllAlarms() async {
    print('ℹ️ Alarm rescheduling handled by native BootReceiver');
  }

  Future<bool> testAlarm(ReminderModel reminder) async {
    print('\n🧪 TESTING ALARM - Will fire in 1 minute\n');
    
    final now = DateTime.now();
    final testTime = now.add(const Duration(minutes: 1));
    
    final testReminder = reminder.copyWith(
      isRecurring: false,
      specificDate: testTime,
      time: TimeOfDay(
        hour: testTime.hour,
        minute: testTime.minute,
      ),
    );
    
    return await scheduleAlarm(testReminder);
  }
}
