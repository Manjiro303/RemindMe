import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/reminder_model.dart';
import '../providers/reminder_provider.dart';
import '../widgets/reminder_card.dart';
import '../widgets/stats_card.dart';
import '../utils/constants.dart';
import 'add_edit_reminder_screen.dart';
import 'alarm_detail_screen.dart';
import 'captcha_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const platform = MethodChannel('com.reminder.myreminders/alarm');

  @override
  void initState() {
    super.initState();
    _setupNativeListener();
    _checkAndRescheduleAlarms();
    _checkForPendingAlarm();
  }

  Future<void> _checkForPendingAlarm() async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    final intent = await platform.invokeMethod('getInitialIntent');
    if (intent != null && mounted) {
      _handleAlarmIntent(intent);
    }
  }

  void _handleAlarmIntent(Map<dynamic, dynamic> args) {
    final int alarmId = args['notification_id'] ?? 0;
    final String alarmBody = args['alarm_body'] ?? '';
    
    print('📱 Handling alarm intent: ID=$alarmId');
    
    final reminders = context.read<ReminderProvider>().reminders;
    ReminderModel? reminder;
    
    try {
      reminder = reminders.firstWhere(
        (r) => r.id.hashCode.abs() % 2147483647 == alarmId
      );
    } catch (e) {
      try {
        reminder = reminders.firstWhere(
          (r) => r.text == alarmBody
        );
      } catch (e2) {
        print('❌ Could not find reminder');
      }
    }
    
    if (reminder != null && mounted) {
      _showAlarmDetailScreen(reminder, alarmId);
    }
  }

  void _setupNativeListener() {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onAlarmDetail') {
        final Map<dynamic, dynamic> args = call.arguments;
        _handleAlarmIntent(args);
      }
    });
  }

  Future<void> _checkAndRescheduleAlarms() async {
    final provider = context.read<ReminderProvider>();
    await provider.rescheduleAllAlarms();
  }

  void _showAlarmDetailScreen(ReminderModel reminder, int notificationId) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => AlarmDetailScreen(
          reminder: reminder,
          notificationId: notificationId,
        ),
      ),
    );
  }

  // Handle toggle with CAPTCHA protection
  Future<void> _handleReminderToggle(ReminderModel reminder) async {
    final provider = context.read<ReminderProvider>();
    
    // If alarm is being turned OFF and requires CAPTCHA, show CAPTCHA screen
    if (reminder.enabled && reminder.requiresCaptcha) {
      final result = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          fullscreenDialog: true,
          builder: (context) => CaptchaScreen(
            onSuccess: () {
              Navigator.pop(context, true);
            },
            reminderText: reminder.text,
          ),
        ),
      );
      
      // Only toggle if CAPTCHA was solved
      if (result == true) {
        await provider.toggleReminder(reminder.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('✅ Alarm disabled successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } else {
      // Normal toggle (no CAPTCHA required)
      await provider.toggleReminder(reminder.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔔 My Reminders'),
        actions: [
          // TEST BUTTON - Add this for debugging
          IconButton(
            icon: const Icon(Icons.science),
            tooltip: 'Test Alarms',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TestAlarmScreen()),
              );
            },
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.filter_list),
            onSelected: (value) {
              context.read<ReminderProvider>().setFilter(value);
            },
            itemBuilder: (context) => [
              const PopupMenuItem(value: 'All', child: Text('All')),
              ...AppConstants.categories.map(
                (cat) => PopupMenuItem(value: cat, child: Text(cat)),
              ),
            ],
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.sort),
            onSelected: (value) {
              context.read<ReminderProvider>().setSort(value);
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'Time', child: Text('Sort by Time')),
              PopupMenuItem(value: 'Category', child: Text('Sort by Category')),
              PopupMenuItem(value: 'Priority', child: Text('Sort by Priority')),
            ],
          ),
        ],
      ),
      body: Consumer<ReminderProvider>(
        builder: (context, provider, child) {
          final reminders = provider.filteredReminders;
          final hasReminders = provider.totalReminders > 0;

          return Column(
            children: [
              const SizedBox(height: 16),
              
              // Always show stats
              StatsCard(provider: provider),
              
              const SizedBox(height: 8),
              
              if (provider.currentFilter != 'All')
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Theme.of(context).primaryColor.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.filter_alt,
                          size: 18,
                          color: Theme.of(context).primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Filter: ${provider.currentFilter}',
                          style: TextStyle(
                            color: Theme.of(context).primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () => provider.setFilter('All'),
                          child: Icon(
                            Icons.close,
                            size: 18,
                            color: Theme.of(context).primaryColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              Expanded(
                child: reminders.isEmpty
                    ? _buildEmptyState(hasReminders)
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: reminders.length,
                        itemBuilder: (context, index) {
                          final reminder = reminders[index];
                          return ReminderCard(
                            reminder: reminder,
                            onTap: () => _editReminder(reminder.id),
                            onToggle: () => _handleReminderToggle(reminder),
                            onDelete: () => _deleteReminder(reminder.id),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: Consumer<ReminderProvider>(
        builder: (context, provider, child) {
          final hasReminders = provider.totalReminders > 0;
          
          if (!hasReminders) {
            return const SizedBox.shrink();
          }
          
          return FloatingActionButton.extended(
            onPressed: _addReminder,
            icon: const Icon(Icons.add),
            label: const Text('Add Reminder'),
            elevation: 6,
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(bool hasReminders) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[100],
            ),
            child: Icon(
              Icons.notifications_off_outlined,
              size: 80,
              color: Colors.grey[400],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            hasReminders ? 'No reminders in this category' : 'No reminders yet',
            style: TextStyle(
              fontSize: 24,
              color: Colors.grey[700],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Text(
              hasReminders 
                  ? 'Try selecting a different category or create a new reminder'
                  : 'Create your first reminder to never forget important tasks again!',
              style: TextStyle(
                fontSize: 15,
                color: Colors.grey[500],
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          if (!hasReminders)
            ElevatedButton.icon(
              onPressed: _addReminder,
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Create Reminder'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                backgroundColor: const Color(0xFF33CC8C),
                foregroundColor: Colors.white,
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _addReminder() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const AddEditReminderScreen(),
      ),
    );
  }

  void _editReminder(String id) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddEditReminderScreen(reminderId: id),
      ),
    );
  }

  void _deleteReminder(String id) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.orange),
            SizedBox(width: 12),
            Text('Delete Reminder'),
          ],
        ),
        content: const Text('Are you sure you want to delete this reminder? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              context.read<ReminderProvider>().deleteReminder(id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Row(
                    children: [
                      Icon(Icons.check_circle, color: Colors.white),
                      SizedBox(width: 12),
                      Text('Reminder deleted'),
                    ],
                  ),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
