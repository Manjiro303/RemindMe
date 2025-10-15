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
