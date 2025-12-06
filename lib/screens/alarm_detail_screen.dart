import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/reminder_model.dart';
import '../utils/constants.dart';
import '../services/platform_channel_service.dart';
import 'captcha_screen.dart';

class AlarmDetailScreen extends StatefulWidget {
  final ReminderModel reminder;
  final int notificationId;

  const AlarmDetailScreen({
    super.key,
    required this.reminder,
    required this.notificationId,
  });

  @override
  State<AlarmDetailScreen> createState() => _AlarmDetailScreenState();
}

class _AlarmDetailScreenState extends State<AlarmDetailScreen> with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  bool _showCaptcha = false;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    
    // Add lifecycle observer to prevent backgrounding
    WidgetsBinding.instance.addObserver(this);
    
    // Prevent back button and hide system UI
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    
    // If CAPTCHA is required, show it immediately
    if (widget.reminder.requiresCaptcha) {
      // Prevent app from being minimized or closed
      _preventAppMinimization();
      
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          setState(() => _showCaptcha = true);
        }
      });
    }
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _pulseAnimation = Tween<double>(begin: 0.0, end: 10.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  void _preventAppMinimization() {
    // Keep screen on and prevent going to background
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.immersiveSticky,
      overlays: [],
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // If CAPTCHA is required and app goes to background, bring it back
    if (widget.reminder.requiresCaptcha && _showCaptcha) {
      if (state == AppLifecycleState.paused || 
          state == AppLifecycleState.inactive ||
          state == AppLifecycleState.hidden) {
        print('⚠️ User tried to minimize app with CAPTCHA active - preventing!');
        
        // Try to bring app back to foreground
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) {
            SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
          }
        });
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _animationController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  void _showCannotDismissDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: Colors.red.shade50,
          title: Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 32),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'CAPTCHA Required',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You must solve the CAPTCHA to dismiss this alarm.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.red.shade900,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade100,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.red.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.block, color: Colors.red.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Closing the app, silencing, or going back is disabled until CAPTCHA is solved.',
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'OK, I understand',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Show CAPTCHA screen if required
    if (_showCaptcha && widget.reminder.requiresCaptcha) {
      return PopScope(
        canPop: false,
        onPopInvokedWithResult: (bool didPop, dynamic result) async {
          if (!didPop && widget.reminder.requiresCaptcha) {
            _showCannotDismissDialog();
          }
        },
        child: CaptchaScreen(
          onSuccess: _handleDismissAfterCaptcha,
          reminderText: widget.reminder.text,
        ),
      );
    }

    final categoryColor = AppConstants.getCategoryColors()[widget.reminder.category]!;
    final priorityColor = AppConstants.getPriorityColors()[widget.reminder.priority]!;

    return PopScope(
      canPop: !widget.reminder.requiresCaptcha,
      onPopInvokedWithResult: (bool didPop, dynamic result) async {
        if (!didPop) {
          if (widget.reminder.requiresCaptcha) {
            _showCannotDismissDialog();
          } else {
            await _handleDismissWithoutCaptcha();
          }
        }
      },
      child: Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                categoryColor.withOpacity(0.9),
                categoryColor.withOpacity(0.5),
                categoryColor.withOpacity(0.2),
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
                      // Animated alarm icon with pulse effect
                      AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              // Pulse rings
                              Container(
                                width: 120 + _pulseAnimation.value * 2,
                                height: 120 + _pulseAnimation.value * 2,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.1 - _pulseAnimation.value / 100),
                                ),
                              ),
                              Container(
                                width: 110 + _pulseAnimation.value,
                                height: 110 + _pulseAnimation.value,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.white.withOpacity(0.15 - _pulseAnimation.value / 100),
                                ),
                              ),
                              // Main icon
                              Transform.scale(
                                scale: _scaleAnimation.value,
                                child: Container(
                                  width: 100,
                                  height: 100,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.white.withOpacity(0.25),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 20,
                                        spreadRadius: 5,
                                      ),
                                    ],
                                  ),
                                  child: const Icon(
                                    Icons.notifications_active,
                                    size: 50,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 32),

                      // Reminder title with shadow
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '🔔 Reminder Alert',
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.3),
                                offset: const Offset(0, 2),
                                blurRadius: 4,
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Reminder text card with improved design
                      Card(
                        elevation: 8,
                        color: Colors.white.withOpacity(0.98),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            children: [
                              // Main reminder text
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: categoryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: categoryColor.withOpacity(0.3),
                                    width: 2,
                                  ),
                                ),
                                child: Text(
                                  widget.reminder.text,
                                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                    color: Colors.black87,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(height: 20),
                              Divider(color: Colors.grey[300], thickness: 1),
                              const SizedBox(height: 20),

                              // Details with improved layout
                              _buildDetailRow(
                                icon: Icons.access_time,
                                label: 'Time',
                                value: _formatTime(widget.reminder.time),
                                valueColor: categoryColor,
                              ),
                              const SizedBox(height: 16),
                              _buildDetailRow(
                                icon: Icons.category,
                                label: 'Category',
                                value: widget.reminder.category,
                                valueColor: categoryColor,
                              ),
                              const SizedBox(height: 16),
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
                                  valueColor: Colors.grey[700]!,
                                  multiLine: true,
                                ),
                              ],
                              if (widget.reminder.requiresCaptcha) ...[
                                const SizedBox(height: 16),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.red.shade200, width: 2),
                                  ),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.security, color: Colors.red.shade700, size: 20),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              'CAPTCHA Required',
                                              style: TextStyle(
                                                color: Colors.red.shade700,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'You must solve a math problem to dismiss this alarm. Going back, closing the app, or silencing your phone is disabled.',
                                        style: TextStyle(
                                          color: Colors.red.shade700,
                                          fontSize: 12,
                                          height: 1.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Dismiss button (only shown if no CAPTCHA required)
                      if (!widget.reminder.requiresCaptcha)
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: _handleDismissWithoutCaptcha,
                            icon: const Icon(Icons.check_circle_outline, size: 28),
                            label: const Text(
                              'Dismiss Alarm',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 0.5,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 18,
                              ),
                              backgroundColor: Colors.white,
                              foregroundColor: categoryColor,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(24),
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
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: multiLine ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: valueColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: valueColor, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: valueColor,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
              maxLines: multiLine ? 3 : 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  Future<void> _handleDismissWithoutCaptcha() async {
    print('✅ Dismissing alarm without CAPTCHA');
    await PlatformChannelService().cancelNotification(widget.notificationId);
    if (mounted) {
      Navigator.pop(context);
    }
  }

  Future<void> _handleDismissAfterCaptcha() async {
    print('✅ CAPTCHA solved - Stopping alarm and dismissing');
    await PlatformChannelService().cancelNotification(widget.notificationId);
    if (mounted) {
      Navigator.pop(context);
    }
  }
}
