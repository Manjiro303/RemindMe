import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import '../models/reminder_model.dart';
import '../providers/reminder_provider.dart';
import '../services/voice_command_service.dart';
import '../services/alarm_service.dart';

class VoiceCommandScreen extends StatefulWidget {
  const VoiceCommandScreen({super.key});

  @override
  State<VoiceCommandScreen> createState() => _VoiceCommandScreenState();
}

class _VoiceCommandScreenState extends State<VoiceCommandScreen>
    with SingleTickerProviderStateMixin {
  final VoiceCommandService _voiceService = VoiceCommandService();
  final AlarmService _alarmService = AlarmService();
  
  bool _isListening = false;
  bool _isProcessing = false;
  bool _isCreating = false;
  String _recognizedText = '';
  String _status = 'Tap the microphone to start';
  ReminderCommand? _parsedCommand;
  
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _initializeVoice();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  Future<void> _initializeVoice() async {
    final success = await _voiceService.initialize();
    if (!success && mounted) {
      _showError('Voice recognition not available on this device');
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _voiceService.stopListening();
    super.dispose();
  }

  Future<void> _startListening() async {
    setState(() {
      _isListening = true;
      _status = '🎤 Listening... Speak now!';
      _recognizedText = '';
      _parsedCommand = null;
    });

    final text = await _voiceService.listen();

    setState(() {
      _isListening = false;
      _isProcessing = true;
    });

    if (text != null && text.isNotEmpty) {
      setState(() {
        _recognizedText = text;
        _status = '🤔 Processing your command...';
      });

      await Future.delayed(const Duration(milliseconds: 500));

      final command = _voiceService.parseCommand(text);

      setState(() {
        _parsedCommand = command;
        _isProcessing = false;
        
        if (command != null) {
          _status = '✅ Command understood!';
        } else {
          _status = '❌ Could not understand the command';
        }
      });

      // Automatically create reminder if command was understood
      if (command != null && mounted) {
        await Future.delayed(const Duration(milliseconds: 800));
        await _createReminderAndNavigate();
      }
    } else {
      setState(() {
        _isProcessing = false;
        _status = '❌ No speech detected. Please try again.';
      });
    }
  }

  Future<void> _createReminderAndNavigate() async {
    if (_parsedCommand == null) return;

    setState(() {
      _isCreating = true;
      _status = '⏰ Creating your reminder...';
    });

    final provider = context.read<ReminderProvider>();
    
    final reminder = ReminderModel(
      id: const Uuid().v4(),
      text: _parsedCommand!.text,
      time: _parsedCommand!.time,
      category: _parsedCommand!.category,
      priority: _parsedCommand!.priority,
      isRecurring: _parsedCommand!.isRecurring,
      days: _parsedCommand!.days,
      specificDate: _parsedCommand!.specificDate,
      requiresCaptcha: _parsedCommand!.requiresCaptcha,
      enabled: true,
    );

    // Add reminder to provider (this saves to storage)
    await provider.addReminder(reminder);

    // Explicitly schedule the alarm for this reminder
    print('🎤 Voice Command: Scheduling alarm for new reminder');
    final scheduled = await _alarmService.scheduleAlarm(reminder);
    
    if (mounted) {
      if (scheduled) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '✅ Reminder created and alarm scheduled!',
                    style: const TextStyle(fontSize: 15),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
        
        // Wait a moment for user to see the success message
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Navigate back to home
        if (mounted) {
          Navigator.pop(context);
        }
      } else {
        setState(() {
          _isCreating = false;
          _status = '⚠️ Alarm scheduling failed. Check permissions.';
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('⚠️ Reminder created but alarm scheduling failed. Please check permissions.'),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('🎤 Voice Command'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Instructions Card
              _buildInstructionsCard(),
              
              const SizedBox(height: 32),
              
              // Status
              Text(
                _status,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF2C3E50),
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 32),
              
              // Microphone Button
              _buildMicrophoneButton(),
              
              const SizedBox(height: 32),
              
              // Recognized Text
              if (_recognizedText.isNotEmpty) ...[
                _buildRecognizedTextCard(),
                const SizedBox(height: 16),
              ],
              
              // Parsed Command Preview
              if (_parsedCommand != null && !_isCreating) ...[
                _buildParsedCommandCard(),
              ],
              
              // Creating indicator
              if (_isCreating) ...[
                const SizedBox(height: 24),
                Card(
                  elevation: 4,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  color: Colors.green.shade50,
                  child: Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      children: [
                        const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Setting up your alarm...',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.green.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInstructionsCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.blue.shade700, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Voice Command Examples',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildExampleItem('Remind me to take medicine at 9 AM every day'),
            _buildExampleItem('Set alarm for meeting at 3:30 PM tomorrow'),
            _buildExampleItem('Create reminder to buy groceries on Saturday'),
            _buildExampleItem('Remind me to workout every weekday at 6 PM'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.tips_and_updates, color: Colors.amber.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Alarm will be set automatically after recognition',
                      style: TextStyle(
                        color: Colors.amber.shade900,
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
      ),
    );
  }

  Widget _buildExampleItem(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💬 ', style: TextStyle(fontSize: 16)),
          Expanded(
            child: Text(
              '"$text"',
              style: const TextStyle(
                fontSize: 14,
                fontStyle: FontStyle.italic,
                color: Color(0xFF2C3E50),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMicrophoneButton() {
    return GestureDetector(
      onTap: (_isListening || _isCreating) ? null : _startListening,
      child: AnimatedBuilder(
        animation: _pulseAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _isListening ? _pulseAnimation.value : 1.0,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _isListening
                      ? [Colors.red.shade400, Colors.red.shade600]
                      : _isCreating
                          ? [Colors.green.shade400, Colors.green.shade600]
                          : [Colors.blue.shade400, Colors.blue.shade600],
                ),
                boxShadow: [
                  BoxShadow(
                    color: (_isListening ? Colors.red : _isCreating ? Colors.green : Colors.blue).withOpacity(0.4),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: _isProcessing || _isCreating
                  ? const Center(
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        strokeWidth: 3,
                      ),
                    )
                  : Icon(
                      _isListening ? Icons.mic : Icons.mic_none,
                      size: 60,
                      color: Colors.white,
                    ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecognizedTextCard() {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.hearing, color: Colors.blue.shade700, size: 24),
                const SizedBox(width: 12),
                const Text(
                  'You said:',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '"$_recognizedText"',
                style: const TextStyle(
                  fontSize: 15,
                  fontStyle: FontStyle.italic,
                  color: Color(0xFF2C3E50),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParsedCommandCard() {
    if (_parsedCommand == null) return const SizedBox.shrink();
    
    final cmd = _parsedCommand!;
    
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      color: Colors.green.shade50,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.task_alt, color: Colors.green.shade700, size: 28),
                const SizedBox(width: 12),
                Text(
                  'Reminder Details',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            _buildDetailRow('📝', 'Task', cmd.text),
            _buildDetailRow('⏰', 'Time', _formatTime(cmd.time)),
            _buildDetailRow('📂', 'Category', cmd.category),
            _buildDetailRow('⚠️', 'Priority', cmd.priority),
            
            if (cmd.isRecurring) ...[
              _buildDetailRow('🔄', 'Repeat', _formatDays(cmd.days)),
            ] else if (cmd.specificDate != null) ...[
              _buildDetailRow('📅', 'Date', _formatDate(cmd.specificDate!)),
            ],
            
            if (cmd.requiresCaptcha)
              Container(
                margin: const EdgeInsets.only(top: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.security, color: Colors.orange.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'CAPTCHA security enabled',
                        style: TextStyle(
                          color: Colors.orange.shade700,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String emoji, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Color(0xFF2C3E50),
              ),
              textAlign: TextAlign.right,
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

  String _formatDays(List<int> days) {
    if (days.length == 7) return 'Every day';
    if (days.length == 5 && days.every((d) => d < 5)) return 'Weekdays';
    if (days.length == 2 && days[0] == 5 && days[1] == 6) return 'Weekend';
    
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    return days.map((d) => dayNames[d]).join(', ');
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) return 'Today';
    if (dateOnly == tomorrow) return 'Tomorrow';
    
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    
    return '${dayNames[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}';
  }
}
