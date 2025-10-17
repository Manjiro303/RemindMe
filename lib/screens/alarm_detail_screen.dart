import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/reminder_model.dart';
import '../utils/constants.dart';
import 'captcha_screen.dart';

class AlarmDetailScreen extends StatefulWidget {
  final ReminderModel reminder;
  final VoidCallback onDismiss;

  const AlarmDetailScreen({
    super.key,
    required this.reminder,
    required this.onDismiss,
  });

  @override
  State<AlarmDetailScreen> createState() => _AlarmDetailScreenState();
}

class _AlarmDetailScreenState extends State<AlarmDetailScreen> {
  bool _showCaptcha = false;

  @override
  Widget build(BuildContext context) {
    if (_showCaptcha && widget.reminder.requiresCaptcha) {
      return CaptchaScreen(
        onSuccess: _handleDismiss,
        reminderText: widget.reminder.text,
      );
    }

    final categoryColor = AppConstants.getCategoryColors()[widget.reminder.category]!;
    final priorityColor = AppConstants.getPriorityColors()[widget.reminder.priority]!;

    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                categoryColor.withOpacity(0.8),
                categoryColor.withOpacity(0.3),
              ],
            ),
          ),
          child: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Animated alarm icon
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withOpacity(0.2),
                        ),
                        child: const Icon(
                          Icons.notifications_active,
                          size: 60,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Reminder title
                      Text(
                        'Reminder Alert',
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Reminder text
                      Card(
                        color: Colors.white.withOpacity(0.95),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            children: [
                              Text(
                                widget.reminder.text,
                                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Colors.black87,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 20),
                              Divider(color: Colors.grey[300]),
                              const SizedBox(height: 20),

                              // Time
                              _buildDetailRow(
                                icon: Icons.access_time,
                                label: 'Time',
                                value: _formatTime(widget.reminder.time),
                                valueColor: categoryColor,
                              ),
                              const SizedBox(height: 16),

                              // Category
                              _buildDetailRow(
                                icon: Icons.category,
                                label: 'Category',
                                value: widget.reminder.category,
                                valueColor: categoryColor,
                              ),
                              const SizedBox(height: 16),

                              // Priority
                              _buildDetailRow(
                                icon: Icons.flag,
                                label: 'Priority',
                                value: widget.reminder.priority,
                                valueColor: priorityColor,
                              ),
                              if (widget.reminder.note.isNotEmpty) ...[
                                const SizedBox(height: 16),
                                _buildDetailRow(
                                  icon: Icons.note,
                                  label: 'Note',
                                  value: widget.reminder.note,
                                  valueColor: Colors.grey,
                                  multiLine: true,
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Dismiss button
                      Container(
                        decoration: BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: ElevatedButton.icon(
                          onPressed: widget.reminder.requiresCaptcha
                              ? () => setState(() => _showCaptcha = true)
                              : _handleDismiss,
                          icon: const Icon(Icons.check_circle, size: 28),
                          label: Text(
                            widget.reminder.requiresCaptcha ? 'Solve CAPTCHA to Dismiss' : 'Dismiss',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 40,
                              vertical: 16,
                            ),
                            backgroundColor: Colors.white,
                            foregroundColor: categoryColor,
                            elevation: 8,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color valueColor,
    bool multiLine = false,
  }) {
    return Row(
      crossAxisAlignment: multiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Icon(icon, color: Colors.grey[600], size: 20),
        const SizedBox(width: 12),
        Text(
          label,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
        const Spacer(),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: valueColor,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
            maxLines: multiLine ? 3 : 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  void _handleDismiss() {
    widget.onDismiss();
    Navigator.pop(context);
  }
}
