import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'services/notification_service.dart';
import 'providers/reminder_provider.dart';
import 'screens/home_screen.dart';
import 'utils/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize alarm manager
  try {
    await AndroidAlarmManager.initialize();
    print('✅ Alarm manager initialized');
  } catch (e) {
    print('❌ Error initializing alarm manager: $e');
  }
  
  // Initialize notifications
  try {
    await NotificationService().initialize();
    print('✅ Notification service initialized');
  } catch (e) {
    print('❌ Error initializing notifications: $e');
  }
  
  // Lock orientation to portrait
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);
  
  runApp(const MyRemindersApp());
}

class MyRemindersApp extends StatefulWidget {
  const MyRemindersApp({super.key});

  @override
  State<MyRemindersApp> createState() => _MyRemindersAppState();
}

class _MyRemindersAppState extends State<MyRemindersApp> {
  static const platform = MethodChannel('com.reminder.myreminders/alarm');

  @override
  void initState() {
    super.initState();
    _setupMethodChannelListener();
  }

  void _setupMethodChannelListener() {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onAlarmDetail') {
        print('📱 Received alarm detail from native: ${call.arguments}');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ReminderProvider(),
      child: MaterialApp(
        title: 'My Reminders',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const HomeScreen(),
      ),
    );
  }
}
