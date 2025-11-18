import 'package:flutter/services.dart';

class PlatformChannelService {
  static final PlatformChannelService _instance = PlatformChannelService._internal();
  factory PlatformChannelService() => _instance;
  PlatformChannelService._internal();

  static const platform = MethodChannel('com.reminder.myreminders/alarm');

  /// Schedule a native alarm
  Future<bool> scheduleNativeAlarm({
    required int alarmId,
    required DateTime scheduledTime,
    required String title,
    required String body,
    required String soundUri,
    required String priority,
    required bool requiresCaptcha,
    required bool isRecurring,
    required List<int> selectedDays,
    required int reminderHour,
    required int reminderMinute,
  }) async {
    try {
      final result = await platform.invokeMethod('scheduleAlarm', {
        'alarmId': alarmId,
        'scheduledTimeMillis': scheduledTime.millisecondsSinceEpoch,
        'title': title,
        'body': body,
        'soundUri': soundUri,
        'priority': priority,
        'requiresCaptcha': requiresCaptcha,
        'isRecurring': isRecurring,
        'selectedDays': selectedDays,
        'reminderHour': reminderHour,
        'reminderMinute': reminderMinute,
      });
      return result == true;
    } catch (e) {
      print('❌ Error scheduling native alarm: $e');
      return false;
    }
  }

  /// Cancel a native alarm
  Future<void> cancelNativeAlarm(int alarmId) async {
    try {
      await platform.invokeMethod('cancelAlarm', {'alarmId': alarmId});
      print('✅ Native alarm cancelled for ID: $alarmId');
    } catch (e) {
      print('❌ Error cancelling native alarm: $e');
    }
  }

  /// Cancel notification
  Future<void> cancelNotification(int notificationId) async {
    try {
      await platform.invokeMethod('stopRingtone');
      print('✅ Notification cancelled for ID: $notificationId');
    } catch (e) {
      print('❌ Error cancelling notification: $e');
    }
  }

  /// Stop ringtone
  Future<void> stopRingtone() async {
    try {
      await platform.invokeMethod('stopRingtone');
    } catch (e) {
      print('❌ Error stopping ringtone: $e');
    }
  }

  /// Check if can schedule exact alarms
  Future<bool> canScheduleExactAlarms() async {
    try {
      final result = await platform.invokeMethod('canScheduleExactAlarms');
      return result == true;
    } catch (e) {
      print('❌ Error checking exact alarm permission: $e');
      return false;
    }
  }

  /// Request exact alarm permission
  Future<void> requestExactAlarmPermission() async {
    try {
      await platform.invokeMethod('requestPermission');
    } catch (e) {
      print('❌ Error requesting permission: $e');
    }
  }

  /// Get default alarm URI (placeholder for compatibility)
  Future<String> getDefaultAlarmUri() async {
    return '';
  }

  /// Get default notification URI (placeholder for compatibility)
  Future<String> getDefaultNotificationUri() async {
    return '';
  }
}
