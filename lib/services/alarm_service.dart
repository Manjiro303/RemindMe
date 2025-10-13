import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/material.dart';
import '../models/reminder_model.dart';
import 'notification_service.dart';
import 'storage_service.dart';

class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal();

  final NotificationService _notificationService = NotificationService();
  final StorageService _storageService = StorageService();

  // Schedule alarm for a reminder
  Future<bool> scheduleAlarm(ReminderModel reminder) async {
    try {
      final DateTime now = DateTime.now();
      DateTime scheduledTime = _getNextAlarmTime(reminder, now);

      final int alarmId = reminder.id.hashCode;

      await AndroidAlarmManager.oneShotAt(
        scheduledTime,
        alarmId,
        _alarmCallback,
        exact: true,
        wakeup: true,
        rescheduleOnReboot: true,
        params: {
          'id': reminder.id,
          'text': reminder.text,
          'category': reminder.category,
          'priority': reminder.priority,
          'note': reminder.note,
          'days': reminder.days,
          'hour': reminder.time.hour,
          'minute': reminder.time.minute,
        },
      );

      print('✅ Alarm scheduled for ${reminder.text} at $scheduledTime');
      return true;
    } catch (e) {
      print('❌ Error scheduling alarm: $e');
      return false;
    }
  }

  // Calculate next alarm time
  DateTime _getNextAlarmTime(ReminderModel reminder, DateTime now) {
    DateTime scheduledTime = DateTime(
      now.year,
      now.month,
      now.day,
      reminder.time.hour,
      reminder.time.minute,
    );

    // If time has passed today, start from tomorrow
    if (scheduledTime.isBefore(now)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    // Find next valid day
    while (!reminder.days.contains(scheduledTime.weekday - 1)) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    return scheduledTime;
  }

  // Cancel alarm
  Future<void> cancelAlarm(String reminderId) async {
    try {
      final int alarmId = reminderId.hashCode;
      await AndroidAlarmManager.cancel(alarmId);
      print('✅ Alarm cancelled for ID: $reminderId');
    } catch (e) {
      print('❌ Error cancelling alarm: $e');
    }
  }

  // Reschedule all enabled alarms
  Future<void> rescheduleAllAlarms() async {
    try {
      final reminders = await _storageService.loadReminders();
      int count = 0;

      for (var reminder in reminders) {
        if (reminder.enabled) {
          final success = await scheduleAlarm(reminder);
          if (success) count++;
        }
      }

      print('✅ Rescheduled $count alarms');
    } catch (e) {
      print('❌ Error rescheduling alarms: $e');
    }
  }

  // Alarm callback - must be top-level or static
  @pragma('vm:entry-point')
  static Future<void> _alarmCallback(int alarmId, Map<String, dynamic> params) async {
    print('🔔 Alarm triggered: ${params['text']}');

    final notificationService = NotificationService();
    await notificationService.initialize();

    await notificationService.showNotification(
      id: alarmId,
      title: params['category'] ?? 'Reminder',
      body: params['text'] ?? 'Reminder',
      category: params['category'] ?? 'Personal',
      priority: params['priority'] ?? 'Medium',
      payload: params['id'],
    );

    // Reschedule if recurring
    if (params['days'] != null && (params['days'] as List).isNotEmpty) {
      await _rescheduleRecurringAlarm(params);
    }
  }

  @pragma('vm:entry-point')
  static Future<void> _rescheduleRecurringAlarm(Map<String, dynamic> params) async {
    try {
      final storageService = StorageService();
      final reminders = await storageService.loadReminders();
      
      final reminder = reminders.firstWhere(
        (r) => r.id == params['id'],
        orElse: () => throw Exception('Reminder not found'),
      );

      if (reminder.enabled) {
        final alarmService = AlarmService();
        await alarmService.scheduleAlarm(reminder);
        print('✅ Recurring alarm rescheduled');
      }
    } catch (e) {
      print('❌ Error rescheduling recurring alarm: $e');
    }
  }
}
