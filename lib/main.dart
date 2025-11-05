import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'services/notification_service.dart';
import 'providers/reminder_provider.dart';
import 'screens/home_screen.dart';
import 'screens/alarm_detail_screen.dart';
import 'utils/theme.dart';
import 'models/reminder_model.dart';

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
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    _setupMethodChannelListener();
  }

  void _setupMethodChannelListener() {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onAlarmDetail') {
        print('📱 Received alarm detail from native: ${call.arguments}');
        _handleAlarmFromNative(call.arguments);
      }
    });
  }

  void _handleAlarmFromNative(Map<dynamic, dynamic> args) {
    final int alarmId = args['notification_id'] ?? 0;
    final String alarmBody = args['alarm_body'] ?? '';
    final bool requiresCaptcha = args['requiresCaptcha'] ?? false;
    
    print('🔔 Handling alarm: ID=$alarmId, CAPTCHA=$requiresCaptcha');
    
    // CRITICAL: Use addPostFrameCallback to ensure we have a valid context
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = navigatorKey.currentContext;
      if (context != null) {
        final provider = Provider.of<ReminderProvider>(context, listen: false);
        ReminderModel? reminder;
        
        try {
          reminder = provider.reminders.firstWhere(
            (r) => r.id.hashCode.abs() % 2147483647 == alarmId
          );
          print('✅ Found reminder: ${reminder.text}, CAPTCHA: ${reminder.requiresCaptcha}');
        } catch (e) {
          try {
            reminder = provider.reminders.firstWhere(
              (r) => r.text == alarmBody
            );
            print('✅ Found reminder by text: ${reminder.text}');
          } catch (e2) {
            print('❌ Could not find reminder');
          }
        }
        
        if (reminder != null) {
          // Navigate to alarm detail screen immediately
          // This will show CAPTCHA if required
          Navigator.of(context).push(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (context) => AlarmDetailScreen(
                reminder: reminder!,
                notificationId: alarmId,
              ),
            ),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ReminderProvider(),
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'My Reminders',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const HomeScreen(),
      ),
    );
  }
}
