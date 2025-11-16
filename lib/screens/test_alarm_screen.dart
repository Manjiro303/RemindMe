import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/reminder_provider.dart';
import '../models/reminder_model.dart';

class TestAlarmScreen extends StatefulWidget {
  const TestAlarmScreen({super.key});

  @override
  State<TestAlarmScreen> createState() => _TestAlarmScreenState();
}

class _TestAlarmScreenState extends State<TestAlarmScreen> {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ReminderProvider>();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('🧪 Test Alarms'),
        backgroundColor: Colors.orange,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '⏰ Quick Test Alarm',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text('Creates an alarm that rings in 30 seconds'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _createTestAlarm30Seconds(context, provider),
                    icon: const Icon(Icons.alarm_add),
                    label: const Text('Create 30s Test Alarm'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '⏰ One Minute Test',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  const Text('Creates an alarm that rings in 1 minute'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _createTestAlarm1Minute(context, provider),
                    icon: const Icon(Icons.alarm_add),
                    label: const Text('Create 1min Test Alarm'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card(
            color: Colors.red.shade50,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.red.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Delete All Test Alarms',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red.shade700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text('Remove all test alarms from the list'),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () => _deleteTestAlarms(context, provider),
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Delete Test Alarms'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.all(16),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Divider(),
          const SizedBox(height: 16),
          Text(
            '📊 Current Alarms: ${provider.totalReminders}',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            '✅ Active: ${provider.activeReminders}',
            style: const TextStyle(fontSize: 14),
          ),
        ],
      ),
    );
  }

  void _createTestAlarm30Seconds(BuildContext context, ReminderProvider provider) async {
    final now = DateTime.now();
    final testTime = now.add(const Duration(seconds: 30));
    
    final reminder = ReminderModel(
      id: 'test_30s_${DateTime.now().millisecondsSinceEpoch}',
      text: '🧪 TEST: 30 second alarm',
      time: TimeOfDay(hour: testTime.hour, minute: testTime.minute),
      category: 'Personal',
      priority: 'High',
      note: 'This is a test alarm',
      days: [],
      enabled: true,
      isRecurring: false,
      specificDate: testTime,
      requiresCaptcha: false,
    );

    await provider.addReminder(reminder);
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Test alarm created! Will ring at ${testTime.hour}:${testTime.minute.toString().padLeft(2, '0')}:${testTime.second}'),
          duration: const Duration(seconds: 5),
          backgroundColor: Colors.green,
        ),
      );
      
      Navigator.pop(context);
    }
  }

  void _createTestAlarm1Minute(BuildContext context, ReminderProvider provider) async {
    final now = DateTime.now();
    final testTime = now.add(const Duration(minutes: 1));
    
    final reminder = ReminderModel(
      id: 'test_1min_${DateTime.now().millisecondsSinceEpoch}',
      text: '🧪 TEST: 1 minute alarm',
      time: TimeOfDay(hour: testTime.hour, minute: testTime.minute),
      category: 'Work',
      priority: 'High',
      note: 'This is a test alarm',
      days: [],
      enabled: true,
      isRecurring: false,
      specificDate: testTime,
      requiresCaptcha: false,
    );

    await provider.addReminder(reminder);
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Test alarm created! Will ring at ${testTime.hour}:${testTime.minute.toString().padLeft(2, '0')}'),
          duration: const Duration(seconds: 5),
          backgroundColor: Colors.blue,
        ),
      );
      
      Navigator.pop(context);
    }
  }

  void _deleteTestAlarms(BuildContext context, ReminderProvider provider) async {
    final testReminders = provider.reminders.where((r) => r.text.startsWith('🧪 TEST:')).toList();
    
    if (testReminders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No test alarms found'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    for (var reminder in testReminders) {
      await provider.deleteReminder(reminder.id);
    }
    
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('✅ Deleted ${testReminders.length} test alarm(s)'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}
