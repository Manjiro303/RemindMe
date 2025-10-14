import 'package:flutter/material.dart';
import '../models/reminder_model.dart';
import 'storage_service.dart';
import 'platform_channel_service.dart';

class AlarmService {
  static final AlarmService _instance = AlarmService._internal();
  factory AlarmService() => _instance;
  AlarmService._internal();

  final StorageService _storageService = StorageService();
  final PlatformChannelService _platformService = PlatformChannelService();

  // Schedule alarm for a reminder
  Future<bool> scheduleAlarm(ReminderModel reminder) async {
    try {
      final DateTime now = DateTime.now();
      DateTime scheduledTime = _getNextAlarmTime(reminder, now);

      // Use unique ID for each reminder
      final int alarmId = reminder.id.hashCode.abs() % 2147483647;

      print('📅 Scheduling alarm for: ${reminder.text}');
      print('⏰ Scheduled time: $scheduledTime');
      print('🆔 Alarm ID: $alarmId');

      // CRITICAL FIX: Cancel existing alarm first and wait
      await cancelAlarm(reminder.id);
      await Future.delayed(const Duration(milliseconds: 500));

      // Schedule alarm using native AlarmManager
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
    if (scheduledTime.isBefore(now) || scheduledTime.difference(now).inSeconds < 60) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
    }

    // Find next valid day
    int attempts = 0;
    while (!reminder.days.contains(scheduledTime.weekday - 1) && attempts < 7) {
      scheduledTime = scheduledTime.add(const Duration(days: 1));
      attempts++;
    }

    return scheduledTime;
  }

  // Cancel alarm - ENHANCED VERSION
  Future<void> cancelAlarm(String reminderId) async {
    try {
      final int alarmId = reminderId.hashCode.abs() % 2147483647;
      
      // Cancel the native alarm
      await _platformService.cancelNativeAlarm(alarmId);
      
      // Also cancel any pending notifications
      await _platformService.cancelNotification(alarmId);
      
      print('✅ Alarm and notification cancelled for ID: $reminderId (alarm ID: $alarmId)');
    } catch (e) {
      print('❌ Error cancelling alarm: $e');
    }
  }

  // Reschedule all enabled alarms
  Future<void> rescheduleAllAlarms() async {
    try {
      final reminders = await _storageService.loadReminders();
      int count = 0;

      print('📋 Found ${reminders.length} total reminders');

      // First, cancel all existing alarms
      for (var reminder in reminders) {
        await cancelAlarm(reminder.id);
      }
      
      // Wait a bit to ensure cancellations are processed
      await Future.delayed(const Duration(seconds: 1));

      // Then reschedule enabled ones
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
