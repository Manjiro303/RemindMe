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
import '../services/platform_channel_service.dart';

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
  }

  void _setupNativeListener() {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onAlarmDetail') {
        final Map<dynamic, dynamic> args = call.arguments;
        final int alarmId = args['notification_id'] ?? 0;
        final String alarmTitle = args['alarm_title'] ?? '';
        final String alarmBody = args['alarm_body'] ?? '';
        final bool requiresCaptcha = args['requiresCaptcha'] ?? false;
        
        print('📱 Received alarm detail from native: ID=$alarmId, CAPTCHA=$requiresCaptcha');
        
        final reminders = context.read<ReminderProvider>().reminders;
        ReminderModel? reminder;
        
        try {
          reminder = reminders.firstWhere(
            (r) => r.id.hashCode.abs() % 2147483647 == alarmId
          );
          print('✅ Found reminder by hash: ${reminder.text}, CAPTCHA=${reminder.requiresCaptcha}');
        } catch (e) {
          print('⚠️ Could not find reminder with hash ID: $alarmId, trying text match');
          try {
            reminder = reminders.firstWhere(
              (r) => r.text == alarmBody || r.category == alarmTitle
            );
            print('✅ Found reminder by text: ${reminder.text}');
          } catch (e2) {
            print('❌ Could not find reminder at all');
          }
        }
        
        if (reminder != null && mounted) {
          print('🔔 Opening alarm detail screen - CAPTCHA required: ${reminder.requiresCaptcha}');
          _showAlarmDetailScreen(reminder);
        }
      }
    });
  }

  Future<void> _checkAndRescheduleAlarms() async {
    final provider = context.read<ReminderProvider>();
    await provider.rescheduleAllAlarms();
  }

  void _showAlarmDetailScreen(ReminderModel reminder) async {
    final alarmId = reminder.id.hashCode.abs() % 2147483647;
    
    // Open the alarm detail screen
    await Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => AlarmDetailScreen(
          reminder: reminder,
          onDismiss: () async {
            print('✅ CAPTCHA solved or dismissed - Stopping alarm');
            // Stop the ringtone and vibration, then dismiss notification
            await PlatformChannelService().cancelNotification(alarmId);
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🔔 My Reminders'),
        actions: [
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

          return Column(
            children: [
              const SizedBox(height: 16),
              StatsCard(provider: provider),
              const SizedBox(height: 16),
              
              if (provider.currentFilter != 'All')
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Chip(
                    label: Text('Filter: ${provider.currentFilter}'),
                    onDeleted: () => provider.setFilter('All'),
                    deleteIcon: const Icon(Icons.close, size: 18),
                  ),
                ),

              Expanded(
                child: reminders.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: reminders.length,
                        itemBuilder: (context, index) {
                          final reminder = reminders[index];
                          return ReminderCard(
                            reminder: reminder,
                            onTap: () => _editReminder(reminder.id),
                            onToggle: () => provider.toggleReminder(reminder.id),
                            onDelete: () => _deleteReminder(reminder.id),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addReminder,
        icon: const Icon(Icons.add),
        label: const Text('Add Reminder'),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.notifications_none,
            size: 100,
            color: Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            'No reminders yet',
            style: TextStyle(
              fontSize: 20,
              color: Colors.grey[600],
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tap the + button to add your first reminder',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[500],
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
        title: const Text('Delete Reminder'),
        content: const Text('Are you sure you want to delete this reminder?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              context.read<ReminderProvider>().deleteReminder(id);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Reminder deleted')),
              );
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
