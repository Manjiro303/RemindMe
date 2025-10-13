import 'package:flutter/material.dart';
import '../providers/reminder_provider.dart';

class StatsCard extends StatelessWidget {
  final ReminderProvider provider;

  const StatsCard({super.key, required this.provider});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Card(
        color: const Color(0xFFF7F9FC),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                icon: '📋',
                value: provider.totalReminders.toString(),
                label: 'Total',
              ),
              _buildDivider(),
              _buildStatItem(
                icon: '✅',
                value: provider.activeReminders.toString(),
                label: 'Active',
              ),
              _buildDivider(),
              _buildStatItem(
                icon: '📅',
                value: provider.todayReminders.toString(),
                label: 'Today',
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem({
    required String icon,
    required String value,
    required String label,
  }) {
    return Column(
      children: [
        Text(icon, style: const TextStyle(fontSize: 24)),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Color(0xFF2C3E50),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.grey,
          ),
        ),
      ],
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 40,
      width: 1,
      color: Colors.grey[300],
    );
  }
}
