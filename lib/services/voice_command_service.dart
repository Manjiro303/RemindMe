import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

class VoiceCommandService {
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isInitialized = false;
  
  Future<bool> initialize() async {
    if (_isInitialized) return true;
    
    try {
      _isInitialized = await _speech.initialize(
        onError: (error) => print('❌ Speech error: $error'),
        onStatus: (status) => print('📢 Speech status: $status'),
      );
      
      if (_isInitialized) {
        print('✅ Voice recognition initialized');
      }
      
      return _isInitialized;
    } catch (e) {
      print('❌ Failed to initialize voice recognition: $e');
      return false;
    }
  }
  
  Future<String?> listen() async {
    if (!_isInitialized) {
      final success = await initialize();
      if (!success) return null;
    }
    
    if (!_speech.isAvailable) {
      print('❌ Speech recognition not available');
      return null;
    }
    
    String? recognizedText;
    
    await _speech.listen(
      onResult: (result) {
        recognizedText = result.recognizedWords;
        print('🎤 Recognized: $recognizedText');
      },
      listenFor: const Duration(seconds: 10),
      pauseFor: const Duration(seconds: 3),
      listenOptions: stt.SpeechListenOptions(
        partialResults: false,
        cancelOnError: true,
        listenMode: stt.ListenMode.confirmation,
      ),
    );
    
    // Wait for recognition to complete
    await Future.delayed(const Duration(seconds: 10));
    
    return recognizedText;
  }
  
  void stopListening() {
    _speech.stop();
  }
  
  bool get isListening => _speech.isListening;
  
  /// Parse voice command into reminder details
  ReminderCommand? parseCommand(String text) {
    text = text.toLowerCase().trim();
    print('🔍 Parsing command: "$text"');
    
    // Extract reminder text (what to remind)
    String? reminderText = _extractReminderText(text);
    
    // Extract time
    TimeOfDay? time = _extractTime(text);
    
    // Extract date for one-time reminders
    DateTime? specificDate = _extractDate(text);
    
    // Determine if recurring
    bool isRecurring = _isRecurring(text);
    
    // Extract days for recurring reminders
    List<int> days = _extractDays(text);
    
    // Extract category
    String category = _extractCategory(text);
    
    // Extract priority
    String priority = _extractPriority(text);
    
    // Determine if CAPTCHA required
    bool requiresCaptcha = _requiresCaptcha(text);
    
    if (reminderText == null || reminderText.isEmpty) {
      print('⚠️ Could not extract reminder text');
      return null;
    }
    
    // Default time if not specified
    time ??= const TimeOfDay(hour: 9, minute: 0);
    
    // For recurring, default to weekdays if no days specified
    if (isRecurring && days.isEmpty) {
      days = [0, 1, 2, 3, 4]; // Mon-Fri
    }
    
    return ReminderCommand(
      text: reminderText,
      time: time,
      category: category,
      priority: priority,
      isRecurring: isRecurring,
      days: days,
      specificDate: specificDate,
      requiresCaptcha: requiresCaptcha,
    );
  }
  
  String? _extractReminderText(String text) {
    // Patterns to extract the actual reminder text
    final patterns = [
      RegExp(r'remind me to (.+?)(?:\s+at|\s+on|\s+every|\s+tomorrow|\s+today|$)', caseSensitive: false),
      RegExp(r'set (?:a |an )?(?:alarm|reminder) (?:to |for )?(.+?)(?:\s+at|\s+on|\s+every|\s+tomorrow|\s+today|$)', caseSensitive: false),
      RegExp(r'create (?:a |an )?(?:alarm|reminder) (?:to |for )?(.+?)(?:\s+at|\s+on|\s+every|\s+tomorrow|\s+today|$)', caseSensitive: false),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null && match.group(1) != null) {
        return match.group(1)!.trim();
      }
    }
    
    // Fallback: remove common command words and take what's left
    String cleaned = text
        .replaceAll(RegExp(r'\b(remind me|set alarm|create alarm|reminder)\b', caseSensitive: false), '')
        .replaceAll(RegExp(r'\b(at|on|every|tomorrow|today)\b.*', caseSensitive: false), '')
        .trim();
    
    return cleaned.isNotEmpty ? cleaned : null;
  }
  
  TimeOfDay? _extractTime(String text) {
    // Try to extract time in various formats
    
    // Format: "at 3:30 PM" or "at 15:30"
    final timePattern = RegExp(r'at\s+(\d{1,2}):(\d{2})\s*(am|pm)?', caseSensitive: false);
    final match = timePattern.firstMatch(text);
    
    if (match != null) {
      int hour = int.parse(match.group(1)!);
      final minute = int.parse(match.group(2)!);
      final period = match.group(3)?.toLowerCase();
      
      if (period == 'pm' && hour < 12) hour += 12;
      if (period == 'am' && hour == 12) hour = 0;
      
      return TimeOfDay(hour: hour, minute: minute);
    }
    
    // Format: "at 3 PM" or "at 15"
    final simpleTimePattern = RegExp(r'at\s+(\d{1,2})\s*(am|pm)?', caseSensitive: false);
    final simpleMatch = simpleTimePattern.firstMatch(text);
    
    if (simpleMatch != null) {
      int hour = int.parse(simpleMatch.group(1)!);
      final period = simpleMatch.group(2)?.toLowerCase();
      
      if (period == 'pm' && hour < 12) hour += 12;
      if (period == 'am' && hour == 12) hour = 0;
      
      return TimeOfDay(hour: hour, minute: 0);
    }
    
    // Named times
    if (text.contains('morning')) return const TimeOfDay(hour: 9, minute: 0);
    if (text.contains('noon') || text.contains('lunch')) return const TimeOfDay(hour: 12, minute: 0);
    if (text.contains('afternoon')) return const TimeOfDay(hour: 15, minute: 0);
    if (text.contains('evening')) return const TimeOfDay(hour: 18, minute: 0);
    if (text.contains('night')) return const TimeOfDay(hour: 21, minute: 0);
    
    return null;
  }
  
  DateTime? _extractDate(String text) {
    final now = DateTime.now();
    
    if (text.contains('today')) {
      return now;
    }
    
    if (text.contains('tomorrow')) {
      return now.add(const Duration(days: 1));
    }
    
    // Format: "on Monday", "on Tuesday"
    final days = ['monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'];
    for (int i = 0; i < days.length; i++) {
      if (text.contains('on ${days[i]}')) {
        // Calculate next occurrence of this day
        final targetDay = i + 1; // DateTime uses 1=Monday
        int daysToAdd = targetDay - now.weekday;
        if (daysToAdd <= 0) daysToAdd += 7;
        return now.add(Duration(days: daysToAdd));
      }
    }
    
    return null;
  }
  
  bool _isRecurring(String text) {
    return text.contains('every') || 
           text.contains('daily') || 
           text.contains('weekday') ||
           text.contains('weekend') ||
           text.contains('recurring');
  }
  
  List<int> _extractDays(String text) {
    final days = <int>[];
    
    if (text.contains('every day') || text.contains('daily')) {
      return [0, 1, 2, 3, 4, 5, 6];
    }
    
    if (text.contains('weekday') || text.contains('week days')) {
      return [0, 1, 2, 3, 4]; // Mon-Fri
    }
    
    if (text.contains('weekend') || text.contains('week end')) {
      return [5, 6]; // Sat-Sun
    }
    
    // Individual days
    final dayMap = {
      'monday': 0, 'mon': 0,
      'tuesday': 1, 'tue': 1,
      'wednesday': 2, 'wed': 2,
      'thursday': 3, 'thu': 3,
      'friday': 4, 'fri': 4,
      'saturday': 5, 'sat': 5,
      'sunday': 6, 'sun': 6,
    };
    
    dayMap.forEach((key, value) {
      if (text.contains(key)) {
        if (!days.contains(value)) {
          days.add(value);
        }
      }
    });
    
    days.sort();
    return days;
  }
  
  String _extractCategory(String text) {
    if (text.contains('work') || text.contains('office') || text.contains('meeting')) {
      return 'Work';
    }
    if (text.contains('health') || text.contains('medicine') || text.contains('doctor') || text.contains('workout')) {
      return 'Health';
    }
    if (text.contains('shop') || text.contains('buy') || text.contains('grocery')) {
      return 'Shopping';
    }
    if (text.contains('personal') || text.contains('family')) {
      return 'Personal';
    }
    return 'Personal'; // Default
  }
  
  String _extractPriority(String text) {
    if (text.contains('high priority') || text.contains('important') || text.contains('urgent')) {
      return 'High';
    }
    if (text.contains('low priority') || text.contains('not urgent')) {
      return 'Low';
    }
    return 'Medium'; // Default
  }
  
  bool _requiresCaptcha(String text) {
    return text.contains('captcha') || 
           text.contains('security') || 
           text.contains('must solve') ||
           text.contains('important');
  }
}

class ReminderCommand {
  final String text;
  final TimeOfDay time;
  final String category;
  final String priority;
  final bool isRecurring;
  final List<int> days;
  final DateTime? specificDate;
  final bool requiresCaptcha;
  
  ReminderCommand({
    required this.text,
    required this.time,
    required this.category,
    required this.priority,
    required this.isRecurring,
    required this.days,
    this.specificDate,
    this.requiresCaptcha = false,
  });
  
  @override
  String toString() {
    return 'ReminderCommand(text: $text, time: ${time.hour}:${time.minute}, '
           'category: $category, priority: $priority, recurring: $isRecurring, '
           'days: $days, date: $specificDate, captcha: $requiresCaptcha)';
  }
}
