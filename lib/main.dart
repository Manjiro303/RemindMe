import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'providers/reminder_provider.dart';
import 'screens/home_screen.dart';
import 'utils/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Global error handling for production
  FlutterError.onError = (FlutterErrorDetails details) {
    print('❌ Flutter Error: ${details.exception}');
    print('Stack Trace: ${details.stack}');
  };
  
  print('✅ App initialized');
  
  // Lock orientation to portrait
  await SystemChrome.setPreferredOrientations([
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
  final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
  bool _permissionChecked = false;
  bool _permissionGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
      // Check exact alarm permission
      final canSchedule = await platform.invokeMethod('canScheduleExactAlarms');
      
      // Check notification permission for Android 13+
      if (Platform.isAndroid) {
        final notificationStatus = await Permission.notification.status;
        if (notificationStatus.isDenied) {
          print('📱 Requesting notification permission for Android 13+');
          final result = await Permission.notification.request();
          print('Notification permission result: $result');
        }
      }
      
      setState(() {
        _permissionChecked = true;
        _permissionGranted = canSchedule == true;
      });
      
      if (canSchedule == false) {
        print('⚠️ Exact alarm permission not granted');
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!_permissionGranted && mounted) {
            _showPermissionDialog();
          }
        });
      } else {
        print('✅ Exact alarm permission granted');
      }
    } catch (e) {
      print('❌ Error checking permissions: $e');
      setState(() {
        _permissionChecked = true;
        _permissionGranted = false;
      });
    }
  }

  void _showPermissionDialog() {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.alarm, color: Colors.orange, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Permission Required',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: const Text(
          'This app needs permission to schedule exact alarms. '
          'Please enable "Alarms & reminders" in the next screen to ensure '
          'your reminders work correctly.',
          style: TextStyle(fontSize: 15, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _permissionGranted = false;
              });
            },
            child: const Text('Later', style: TextStyle(fontSize: 15)),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await platform.invokeMethod('requestPermission');
                // Check permission again after a delay
                await Future.delayed(const Duration(seconds: 1));
                await _checkPermissions();
              } catch (e) {
                print('❌ Error requesting permission: $e');
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Grant Permission',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ReminderProvider(),
      child: MaterialApp(
        navigatorKey: navigatorKey,
        title: 'RemindMe',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        home: const HomeScreen(),
      ),
    );
  }
}
