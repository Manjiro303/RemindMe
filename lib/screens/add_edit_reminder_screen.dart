// FILE: lib/screens/add_edit_reminder_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
import 'package:intl/intl.dart';
import '../models/reminder_model.dart';
import '../providers/reminder_provider.dart';
import '../utils/constants.dart';
import '../services/sound_picker_service.dart';

class AddEditReminderScreen extends StatefulWidget {
  final String? reminderId;

  const AddEditReminderScreen({super.key, this.reminderId});

  @override
  State<AddEditReminderScreen> createState() => _AddEditReminderScreenState();
}

class _AddEditReminderScreenState extends State<AddEditReminderScreen> {
  final _formKey = GlobalKey<FormState>();
  final _textController = TextEditingController();
  final _noteController = TextEditingController();
  final SoundPickerService _soundPicker = SoundPickerService();

  TimeOfDay _selectedTime = const TimeOfDay(hour: 9, minute: 0);
  String _selectedCategory = 'Personal';
  String _selectedPriority = 'Medium';
  List<int> _selectedDays = List.generate(7, (index) => index);
  String _selectedRingtone = 'Default Alarm';
  String? _customSoundPath;
  bool _isRecurring = true;
  DateTime? _specificDate;
  bool _requiresCaptcha = false;

  bool get _isEditing => widget.reminderId != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      _loadReminderData();
    }
  }

  void _loadReminderData() {
    final provider = context.read<ReminderProvider>();
    final reminder = provider.reminders.firstWhere(
      (r) => r.id == widget.reminderId,
    );

    _textController.text = reminder.text;
    _noteController.text = reminder.note;
    _selectedTime = reminder.time;
    _selectedCategory = reminder.category;
    _selectedPriority = reminder.priority;
    _selectedDays = List.from(reminder.days);
    _selectedRingtone = reminder.ringtone;
    _customSoundPath = reminder.customSoundPath;
    _isRecurring = reminder.isRecurring;
    _specificDate = reminder.specificDate;
    _requiresCaptcha = reminder.requiresCaptcha;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? '✏️ Edit Reminder' : '➕ New Reminder'),
        elevation: 0,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _buildTextField(),
            const SizedBox(height: 20),
            _buildReminderTypeSection(),
            const SizedBox(height: 20),
            _buildCategorySection(),
            const SizedBox(height: 20),
            _buildPrioritySection(),
            const SizedBox(height: 20),
            _buildTimeSection(),
            const SizedBox(height: 20),
            if (_isRecurring) _buildDaysSection() else _buildDateSection(),
            const SizedBox(height: 20),
            _buildSoundSection(),
            const SizedBox(height: 20),
            _buildCaptchaSection(),
            const SizedBox(height: 20),
            _buildNoteField(),
            const SizedBox(height: 30),
            _buildSaveButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField() {
    return TextFormField(
      controller: _textController,
      decoration: const InputDecoration(
        labelText: 'What should I remind you?',
        hintText: 'e.g., Take medicine, Call mom...',
        prefixIcon: Icon(Icons.edit),
      ),
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter reminder text';
        }
        return null;
      },
      maxLength: 100,
    );
  }

  Widget _buildReminderTypeSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🔄 Reminder Type',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isRecurring = true;
                    _specificDate = null;
                  });
                },
                icon: const Icon(Icons.repeat),
                label: const Text('Recurring'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isRecurring 
                      ? Theme.of(context).primaryColor 
                      : Colors.grey[200],
                  foregroundColor: _isRecurring ? Colors.white : Colors.black87,
                  elevation: _isRecurring ? 4 : 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _isRecurring = false;
                    _specificDate = DateTime.now();
                  });
                },
                icon: const Icon(Icons.event),
                label: const Text('One-Time'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: !_isRecurring 
                      ? Theme.of(context).primaryColor 
                      : Colors.grey[200],
                  foregroundColor: !_isRecurring ? Colors.white : Colors.black87,
                  elevation: !_isRecurring ? 4 : 0,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDateSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '📅 Select Date',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.calendar_today),
            title: const Text('Reminder Date'),
            subtitle: Text(
              _specificDate != null 
                  ? DateFormat('EEEE, MMMM dd, yyyy').format(_specificDate!)
                  : 'Select a date'
            ),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _selectDate,
          ),
        ),
      ],
    );
  }

  Widget _buildCategorySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '📂 Category',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: AppConstants.categories.map((category) {
            final isSelected = _selectedCategory == category;
            final color = AppConstants.getCategoryColors()[category]!;

            return ChoiceChip(
              label: Text(category),
              selected: isSelected,
              onSelected: (_) {
                setState(() => _selectedCategory = category);
              },
              selectedColor: color.withOpacity(0.3),
              backgroundColor: Colors.grey[200],
              labelStyle: TextStyle(
                color: isSelected ? color : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildPrioritySection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '⚠️ Priority',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          children: AppConstants.priorities.map((priority) {
            final isSelected = _selectedPriority == priority;
            final color = AppConstants.getPriorityColors()[priority]!;

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ElevatedButton(
                  onPressed: () {
                    setState(() => _selectedPriority = priority);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isSelected ? color : Colors.grey[200],
                    foregroundColor: isSelected ? Colors.white : Colors.black87,
                    elevation: isSelected ? 4 : 0,
                  ),
                  child: Text(priority),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildTimeSection() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.access_time),
        title: const Text('Reminder Time'),
        subtitle: Text(_selectedTime.format(context)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: _selectTime,
      ),
    );
  }

  Widget _buildDaysSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '📅 Repeat On',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(7, (index) {
            final isSelected = _selectedDays.contains(index);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSelected) {
                    _selectedDays.remove(index);
                  } else {
                    _selectedDays.add(index);
                  }
                  _selectedDays.sort();
                });
              },
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : Colors.grey[200],
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    AppConstants.dayNames[index],
                    style: TextStyle(
                      color: isSelected ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _selectedDays = [0, 1, 2, 3, 4];
                  });
                },
                child: const Text('Weekdays'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _selectedDays = [5, 6];
                  });
                },
                child: const Text('Weekend'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: () {
                  setState(() {
                    _selectedDays = List.generate(7, (index) => index);
                  });
                },
                child: const Text('Every Day'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSoundSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🎵 Alarm Sound',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.music_note),
            title: const Text('Select Alarm Sound'),
            subtitle: Text(_soundPicker.getDisplayName(_customSoundPath)),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _selectSound,
          ),
        ),
      ],
    );
  }

  Widget _buildCaptchaSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🔐 Alarm Security',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Card(
          color: _requiresCaptcha ? Colors.red.shade50 : Colors.grey[50],
          child: Column(
            children: [
              SwitchListTile(
                title: Row(
                  children: [
                    Icon(
                      _requiresCaptcha ? Icons.lock : Icons.lock_open,
                      color: _requiresCaptcha ? Colors.red.shade700 : Colors.grey[600],
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _requiresCaptcha ? 'CAPTCHA Protection Enabled' : 'Normal Alarm',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: _requiresCaptcha ? Colors.red.shade700 : Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
                subtitle: Padding(
                  padding: const EdgeInsets.only(top: 4, left: 30),
                  child: Text(
                    _requiresCaptcha 
                        ? 'Must solve math problem to dismiss alarm'
                        : 'Can be dismissed normally',
                    style: TextStyle(
                      fontSize: 13,
                      color: _requiresCaptcha ? Colors.red.shade600 : Colors.grey[700],
                    ),
                  ),
                ),
                value: _requiresCaptcha,
                onChanged: (value) {
                  setState(() => _requiresCaptcha = value);
                },
                activeColor: Colors.red.shade700,
              ),
              if (_requiresCaptcha) ...[
                Divider(color: Colors.red.shade200, height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.red.shade300, width: 2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.red.shade700, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'CAPTCHA Alarm Features:',
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
                        _buildCaptchaFeature('🔒 Cannot be dismissed without solving'),
                        _buildCaptchaFeature('🔊 Forces maximum volume'),
                        _buildCaptchaFeature('♾️ Rings continuously until solved'),
                        _buildCaptchaFeature('📵 Cannot minimize app'),
                        _buildCaptchaFeature('🧮 Requires correct math answer'),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                Divider(color: Colors.grey[300], height: 1),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.check_circle_outline, color: Colors.green.shade700, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Normal Alarm Features:',
                                style: TextStyle(
                                  color: Colors.green.shade700,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildNormalFeature('✅ Easy one-tap dismiss'),
                        _buildNormalFeature('⏱️ Auto-stops after 5 minutes'),
                        _buildNormalFeature('📱 Can minimize app'),
                        _buildNormalFeature('🎵 Respects volume settings'),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCaptchaFeature(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.red.shade600,
          fontSize: 12,
          height: 1.3,
        ),
      ),
    );
  }

  Widget _buildNormalFeature(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        text,
        style: TextStyle(
          color: Colors.green.shade600,
          fontSize: 12,
          height: 1.3,
        ),
      ),
    );
  }

  Widget _buildNoteField() {
    return TextFormField(
      controller: _noteController,
      decoration: const InputDecoration(
        labelText: '📝 Note (Optional)',
        hintText: 'Add any additional details...',
        prefixIcon: Icon(Icons.note),
      ),
      maxLines: 3,
      maxLength: 200,
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _saveReminder,
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 16),
        backgroundColor: const Color(0xFF33CC8C),
        foregroundColor: Colors.white,
      ),
      child: Text(
        _isEditing ? '💾 Update Reminder' : '💾 Save Reminder',
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  Future<void> _selectTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            timePickerTheme: TimePickerThemeData(
              backgroundColor: Colors.white,
              hourMinuteShape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _specificDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: Theme.of(context).primaryColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() => _specificDate = picked);
    }
  }

  Future<void> _selectSound() async {
    final String? selectedOption = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🎵 Select Alarm Sound'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: SoundPickerService.soundOptions.map((option) {
            return ListTile(
              title: Text(option),
              leading: Radio<String>(
                value: option,
                groupValue: _selectedRingtone,
                onChanged: (value) {
                  Navigator.pop(context, value);
                },
              ),
              onTap: () => Navigator.pop(context, option),
            );
          }).toList(),
        ),
      ),
    );

    if (selectedOption != null) {
      final soundPath = await _soundPicker.pickSound(selectedOption);
      if (soundPath != null) {
        setState(() {
          _selectedRingtone = selectedOption;
          _customSoundPath = soundPath;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('🎵 Sound selected: ${_soundPicker.getDisplayName(soundPath)}')),
          );
        }
      }
    }
  }

  void _saveReminder() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_isRecurring && _selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Please select at least one day for recurring reminders')),
      );
      return;
    }

    if (!_isRecurring && _specificDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Please select a date for one-time reminders')),
      );
      return;
    }

    final provider = context.read<ReminderProvider>();

    final reminder = ReminderModel(
      id: _isEditing ? widget.reminderId! : const Uuid().v4(),
      text: _textController.text.trim(),
      time: _selectedTime,
      category: _selectedCategory,
      priority: _selectedPriority,
      note: _noteController.text.trim(),
      days: _isRecurring ? _selectedDays : [],
      enabled: true,
      ringtone: _selectedRingtone,
      customSoundPath: _customSoundPath,
      specificDate: _specificDate,
      isRecurring: _isRecurring,
      requiresCaptcha: _requiresCaptcha,
    );

    print('💾 Saving reminder with CAPTCHA = $_requiresCaptcha');

    if (_isEditing) {
      provider.updateReminder(widget.reminderId!, reminder);
    } else {
      provider.addReminder(reminder);
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          _isEditing 
              ? '✅ Reminder updated!${_requiresCaptcha ? ' (CAPTCHA enabled)' : ''}' 
              : '✅ Reminder created!${_requiresCaptcha ? ' (CAPTCHA enabled)' : ''}'
        ),
      ),
    );
  }

  @override
  void dispose() {
    _textController.dispose();
    _noteController.dispose();
    super.dispose();
  }
}
