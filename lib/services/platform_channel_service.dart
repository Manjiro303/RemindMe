import 'package:flutter/services.dart';

class PlatformChannelService {
  static final PlatformChannelService _instance = PlatformChannelService._internal();
  factory PlatformChannelService() => _instance;
  PlatformChannelService._internal() {
    _setupRingtoneListener();
  }

  static const platform = MethodChannel('com.reminder.myreminders/alarm');
  static const ringtoneChannel = MethodChannel('com.reminder.myreminders/ringtone');

  String? _selectedRingtoneUri;

  void _setupRingtoneListener() {
    ringtoneChannel.setMethodCallHandler((call) async {
      if (call.method == 'onRingtonePicked') {
        _selectedRingtoneUri = call.arguments as String?;
        print('🎵 Ringtone selected: $_selectedRingtoneUri');
      }
    });
  }

  Future<bool> scheduleNativeAlarm({
    required int alarmId,
    required DateTime scheduledTime,
    required String title,
    required String body,
    required String soundUri,
    required String priority,
  }) async {
    try {
      final result = await platform.invokeMethod('scheduleAlarm', {
        'alarmId': alarmId,
        'scheduledTimeMillis': scheduledTime.millisecondsSinceEpoch,
        'title': title,
        'body': body,
        'soundUri': soundUri.isNotEmpty ? soundUri : await getDefaultAlarmUri(),
        'priority': priority,
      });
      return result == true;
    } catch (e) {
      print('❌ Error scheduling native alarm: $e');
      return false;
    }
  }

  Future<void> cancelNativeAlarm(int alarmId) async {
    try {
      await platform.invokeMethod('cancelAlarm', {'alarmId': alarmId});
    } catch (e) {
      print('❌ Error cancelling native alarm: $e');
    }
  }

  Future<void> pickRingtone() async {
    try {
      await ringtoneChannel.invokeMethod('pickRingtone');
    } catch (e) {
      print('❌ Error picking ringtone: $e');
    }
  }

  Future<String> getDefaultAlarmUri() async {
    try {
      final uri = await ringtoneChannel.invokeMethod('getDefaultAlarmUri');
      return uri as String? ?? '';
    } catch (e) {
      print('❌ Error getting default alarm URI: $e');
      return '';
    }
  }

  Future<String> getDefaultNotificationUri() async {
    try {
      final uri = await ringtoneChannel.invokeMethod('getDefaultNotificationUri');
      return uri as String? ?? '';
    } catch (e) {
      print('❌ Error getting default notification URI: $e');
      return '';
    }
  }

  String? get selectedRingtoneUri => _selectedRingtoneUri;
  
  void clearSelectedRingtone() {
    _selectedRingtoneUri = null;
  }
}
