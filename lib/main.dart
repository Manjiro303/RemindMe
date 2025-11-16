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

class _MyRemindersAppState extends State<MyRemindersApp> with WidgetsBindingObserver {
  static const platform = MethodChannel('com.reminder.myreminders/alarm');
  static const permissionChannel = MethodChannel('com.reminder.myreminders/permissions');
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupMethodChannelListener();
    _checkPermissions();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermissions();
    }
  }

  Future<void> _checkPermissions() async {
    try {
      final canSchedule = await permissionChannel.invokeMethod('canScheduleExactAlarms');
      if (canSchedule == false) {
        print('⚠️ Exact alarm permission not granted');
        // Show dialog to user
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showPermissionDialog();
        });
      } else {
        print('✅ Exact alarm permission granted');
      }
    } catch (e) {
      print('Error checking permissions: $e');
    }
  }

  void _showPermissionDialog() {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.alarm, color: Colors.orange),
            SizedBox(width: 12),
            Expanded(child: Text('Permission Required')),
          ],
        ),
        content: const Text(
          'This app needs permission to schedule exact alarms. '
          'Please enable "Alarms & reminders" in the next screen.',
          style: TextStyle(fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Later'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await permissionChannel.invokeMethod('requestExactAlarmPermission');
              } catch (e) {
                print('Error requesting permission: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
            ),
            child: const Text('Grant Permission'),
          ),
        ],
      ),
    );
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
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = navigatorKey.currentContext;
      if (context != null) {
        final provider = Provider.of<ReminderProvider>(context, listen: false);
        ReminderModel? reminder;
        
        try {
          reminder = provider.reminders.firstWhere(
            (r) => r.id.hashCode.abs() % 2147483647 == alarmId
          );
          print('✅ Found reminder: ${reminder.text}');
        } catch (e) {
          try {
            reminder = provider.reminders.firstWhere(
              (r) => r.text == alarmBody
            );
            print('✅ Found reminder by text');
          } catch (e2) {
            print('❌ Could not find reminder');
          }
        }
        
        if (reminder != null) {
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
