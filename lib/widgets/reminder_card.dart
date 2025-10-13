import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/reminder_model.dart';
import '../utils/constants.dart';

class ReminderCard extends StatelessWidget {
  final ReminderModel reminder;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const ReminderCard({
    super.key,
    required this.reminder,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final categoryColor = AppConstants.getCategoryColors()[reminder.category]!;
    final priorityColor = AppConstants.getPriorityColors()[reminder.priority]!;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Slidable(
        endActionPane: ActionPane(
          motion: const DrawerMotion(),
          children: [
            SlidableAction(
              onPressed: (_) => onDelete(),
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
              icon: Icons.delete,
              label: 'Delete',
              borderRadius: BorderRadius.circular(16),
            ),
          ],
        ),
        child: Card(
          elevation: reminder.enabled ? 2 : 0,
          color: reminder.enabled ? Colors.white : Colors.grey[100],
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border(
                  left: BorderSide(
                    color: reminder.enabled ? categoryColor : Colors.grey,
                    width: 5,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        _buildCategoryChip(categoryColor),
                        const Spacer(),
                        Text(
                          _formatTime(reminder.time),
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: reminder.enabled
                                ? categoryColor
                                : Colors.grey,
                          ),
                        ),
                        if (reminder.priority == 'High')
                          const Padding(
                            padding: EdgeInsets.only(left: 8),
                            child: Text(
                              '!!!',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      reminder.text,
                      style: TextStyle(
                        fontSize: 16,
                        color: reminder.enabled ? Colors.black87 : Colors.grey,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(Icons.repeat, size: 16, color: Colors.grey),
                        const SizedBox(width: 6),
                        Text(
                          _formatDays(reminder.days),
                          style: const TextStyle(
                            fontSize: 13,
                            color: Colors.grey,
                          ),
                        ),
                        if (reminder.note.isNotEmpty) ...[
                          const SizedBox(width: 12),
                          const Icon(Icons.note, size: 16, color: Colors.grey),
                        ],
                        const Spacer(),
                        Switch(
                          value: reminder.enabled,
                          onChanged: (_) => onToggle(),
                          activeColor: const Color(0xFF33CC8C),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChip(Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        reminder.category,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  String _formatDays(List<int> days) {
    if (days.length == 7) return 'Every day';
    if (days.length == 5 && days.every((d) => d < 5)) return 'Weekdays';
    if (days.length == 2 && days[0] == 5 && days[1] == 6) return 'Weekend';
    return days.map((d) => AppConstants.dayNames[d]).join(' ');
  }
}
