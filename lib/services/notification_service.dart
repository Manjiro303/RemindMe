import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    print('🔔 Initializing Notification Service...');
    
    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings settings =
        InitializationSettings(android: androidSettings);

    await _notifications.initialize(settings);
    await requestPermissions();
    
    print('✅ Notification Service initialized');
  }

  Future<void> requestPermissions() async {
    print('📱 Requesting permissions...');
    
    await Permission.notification.request();
    
    if (Platform.isAndroid) {
      await Permission.scheduleExactAlarm.request();
      await Permission.ignoreBatteryOptimizations.request();
    }
  }

  Future<void> showConfirmationNotification({
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'reminder_confirmations',
      'Confirmation Notifications',
      channelDescription: 'Low priority notifications for confirmations',
      importance: Importance.low,
      priority: Priority.low,
    );

    const NotificationDetails details = NotificationDetails(android: androidDetails);

    await _notifications.show(
      DateTime.now().millisecondsSinceEpoch % 100000,
      title,
      body,
      details,
    );
  }
}
