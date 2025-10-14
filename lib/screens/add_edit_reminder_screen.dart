import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';
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
            _buildCategorySection(),
            const SizedBox(height: 20),
            _buildPrioritySection(),
            const SizedBox(height: 20),
            _buildTimeSection(),
            const SizedBox(height: 20),
            _buildDaysSection(),
            const SizedBox(height: 20),
            _buildSoundSection(),
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

    if (_selectedDays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⚠️ Please select at least one day')),
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
      days: _selectedDays,
      enabled: true,
      ringtone: _selectedRingtone,
      customSoundPath: _customSoundPath,
    );

    if (_isEditing) {
      provider.updateReminder(widget.reminderId!, reminder);
    } else {
      provider.addReminder(reminder);
    }

    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(_isEditing ? '✅ Reminder updated!' : '✅ Reminder created!'),
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
