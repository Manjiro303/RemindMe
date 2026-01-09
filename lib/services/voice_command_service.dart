// FILE: lib/services/voice_command_service.dart
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
    
    // Extract reminder text
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
    
    // Default time handling
    if (time == null) {
      if (specificDate != null) {
        // If specific date mentioned but no time, use 9 AM
        time = const TimeOfDay(hour: 9, minute: 0);
        print('⏰ No time specified for specific date, using 9:00 AM');
      } else {
        // For immediate reminders
        final now = DateTime.now().add(const Duration(minutes: 1));
        time = TimeOfDay(hour: now.hour, minute: now.minute);
        print('⏰ No time specified, using current time + 1 minute');
      }
    }
    
    // For recurring, default to weekdays if no days specified
    if (isRecurring && days.isEmpty) {
      days = [0, 1, 2, 3, 4]; // Mon-Fri
      print('📅 No days specified for recurring, defaulting to weekdays');
    }
    
    print('✅ Parsed: text="$reminderText", time=${time.hour}:${time.minute}, recurring=$isRecurring, captcha=$requiresCaptcha');
    
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
    // Remove command keywords and time/date info to get clean reminder text
    final patterns = [
      RegExp(r'(?:remind me to|set (?:a |an )?(?:alarm|reminder) (?:to |for )?|create (?:a |an )?(?:alarm|reminder) (?:to |for )?)(.+?)(?:\s+(?:at|on|every|tomorrow|today|with captcha|with security|secure|captcha)\b|$)', caseSensitive: false),
    ];
    
    for (final pattern in patterns) {
      final match = pattern.firstMatch(text);
      if (match != null && match.group(1) != null) {
        String extracted = match.group(1)!.trim();
        
        // Remove trailing time/date mentions
        extracted = extracted
          .replaceAll(RegExp(r'\s+(?:at|on|every|tomorrow|today|with captcha|with security|secure|captcha).*$', caseSensitive: false), '')
          .trim();
        
        if (extracted.isNotEmpty) {
          print('📝 Extracted reminder text: "$extracted"');
          return extracted;
        }
      }
    }
    
    // Fallback: more aggressive extraction
    String cleaned = text
      .replaceAll(RegExp(r'^(?:remind me|set alarm|create alarm|reminder|to)\s+', caseSensitive: false), '')
      .replaceAll(RegExp(r'\s+(?:at|on|every|tomorrow|today|with captcha|with security|secure|captcha)\b.*$', caseSensitive: false), '')
      .trim();
    
    return cleaned.isNotEmpty ? cleaned : null;
  }
  
  TimeOfDay? _extractTime(String text) {
    // Format: "at 3:30 PM" or "at 15:30"
    final timePattern = RegExp(r'(?:at\s+)?(\d{1,2}):(\d{2})\s*(am|pm)?', caseSensitive: false);
    final match = timePattern.firstMatch(text);
    
    if (match != null) {
      int hour = int.parse(match.group(1)!);
      final minute = int.parse(match.group(2)!);
      final period = match.group(3)?.toLowerCase();
      
      if (period == 'pm' && hour < 12) hour += 12;
      if (period == 'am' && hour == 12) hour = 0;
      
      // Validate hour
      if (hour >= 24) hour = hour % 24;
      
      print('⏰ Extracted time: $hour:$minute from "${match.group(0)}"');
      return TimeOfDay(hour: hour, minute: minute);
    }
    
    // Format: "at 3 PM" or "at 3am"
    final simpleTimePattern = RegExp(r'(?:at\s+)?(\d{1,2})\s*(am|pm)', caseSensitive: false);
    final simpleMatch = simpleTimePattern.firstMatch(text);
    
    if (simpleMatch != null) {
      int hour = int.parse(simpleMatch.group(1)!);
      final period = simpleMatch.group(2)?.toLowerCase();
      
      if (period == 'pm' && hour < 12) hour += 12;
      if (period == 'am' && hour == 12) hour = 0;
      
      print('⏰ Extracted time: $hour:00 from "${simpleMatch.group(0)}"');
      return TimeOfDay(hour: hour, minute: 0);
    }
    
    // Format: "at 15" (24-hour)
    final hourOnlyPattern = RegExp(r'at\s+(\d{1,2})(?:\s|$)', caseSensitive: false);
    final hourMatch = hourOnlyPattern.firstMatch(text);
    
    if (hourMatch != null) {
      int hour = int.parse(hourMatch.group(1)!);
      if (hour >= 24) hour = hour % 24;
      print('⏰ Extracted hour: $hour:00');
      return TimeOfDay(hour: hour, minute: 0);
    }
    
    // Named times
    if (text.contains(RegExp(r'\bmorning\b', caseSensitive: false))) {
      print('⏰ Detected "morning" - using 9:00 AM');
      return const TimeOfDay(hour: 9, minute: 0);
    }
    if (text.contains(RegExp(r'\b(noon|lunch)\b', caseSensitive: false))) {
      print('⏰ Detected "noon/lunch" - using 12:00 PM');
      return const TimeOfDay(hour: 12, minute: 0);
    }
    if (text.contains(RegExp(r'\bafternoon\b', caseSensitive: false))) {
      print('⏰ Detected "afternoon" - using 3:00 PM');
      return const TimeOfDay(hour: 15, minute: 0);
    }
    if (text.contains(RegExp(r'\bevening\b', caseSensitive: false))) {
      print('⏰ Detected "evening" - using 6:00 PM');
      return const TimeOfDay(hour: 18, minute: 0);
    }
    if (text.contains(RegExp(r'\bnight\b', caseSensitive: false))) {
      print('⏰ Detected "night" - using 9:00 PM');
      return const TimeOfDay(hour: 21, minute: 0);
    }
    
    print('⏰ No time found in text');
    return null;
  }
  
  DateTime? _extractDate(String text) {
    final now = DateTime.now();
    
    if (text.contains(RegExp(r'\btoday\b', caseSensitive: false))) {
      print('📅 Detected "today"');
      return now;
    }
    
    if (text.contains(RegExp(r'\btomorrow\b', caseSensitive: false))) {
      print('📅 Detected "tomorrow"');
      return now.add(const Duration(days: 1));
    }
    
    // Check for specific day names
    final dayPatterns = {
      'monday': 1,
      'tuesday': 2,
      'wednesday': 3,
      'thursday': 4,
      'friday': 5,
      'saturday': 6,
      'sunday': 7,
    };
    
    for (final entry in dayPatterns.entries) {
      if (text.contains(RegExp(r'\b' + entry.key + r'\b', caseSensitive: false))) {
        final targetDay = entry.value;
        int daysToAdd = targetDay - now.weekday;
        if (daysToAdd <= 0) daysToAdd += 7;
        
        final targetDate = now.add(Duration(days: daysToAdd));
        print('📅 Detected "${entry.key}" - date: $targetDate');
        return targetDate;
      }
    }
    
    return null;
  }
  
  bool _isRecurring(String text) {
    final recurringKeywords = [
      r'\bevery\b',
      r'\bdaily\b',
      r'\bweekday',
      r'\bweekend',
      r'\brecurring\b',
      r'\beach\b',
      r'\ball\b.*\bdays?\b',
    ];
    
    for (final keyword in recurringKeywords) {
      if (text.contains(RegExp(keyword, caseSensitive: false))) {
        print('🔄 Recurring keyword detected: $keyword');
        return true;
      }
    }
    
    return false;
  }
  
  List<int> _extractDays(String text) {
    final days = <int>[];
    
    // Every day
    if (text.contains(RegExp(r'\bevery\s+day', caseSensitive: false)) || 
        text.contains(RegExp(r'\bdaily\b', caseSensitive: false))) {
      print('📅 Every day detected');
      return [0, 1, 2, 3, 4, 5, 6];
    }
    
    // Weekdays
    if (text.contains(RegExp(r'\bweekday', caseSensitive: false))) {
      print('📅 Weekdays detected');
      return [0, 1, 2, 3, 4]; // Mon-Fri
    }
    
    // Weekend
    if (text.contains(RegExp(r'\bweekend', caseSensitive: false))) {
      print('📅 Weekend detected');
      return [5, 6]; // Sat-Sun
    }
    
    // Individual days
    final dayMap = {
      'monday': 0, 'mon': 0,
      'tuesday': 1, 'tue': 1, 'tues': 1,
      'wednesday': 2, 'wed': 2,
      'thursday': 3, 'thu': 3, 'thur': 3, 'thurs': 3,
      'friday': 4, 'fri': 4,
      'saturday': 5, 'sat': 5,
      'sunday': 6, 'sun': 6,
    };
    
    for (final entry in dayMap.entries) {
      if (text.contains(RegExp(r'\b' + entry.key + r'\b', caseSensitive: false))) {
        if (!days.contains(entry.value)) {
          days.add(entry.value);
          print('📅 Day detected: ${entry.key} (${entry.value})');
        }
      }
    }
    
    days.sort();
    return days;
  }
  
  String _extractCategory(String text) {
    final categoryKeywords = {
      'Work': ['work', 'office', 'meeting', 'job', 'business', 'project'],
      'Health': ['health', 'medicine', 'doctor', 'workout', 'exercise', 'gym', 'pills', 'appointment'],
      'Shopping': ['shop', 'buy', 'grocery', 'groceries', 'purchase', 'store'],
      'Personal': ['personal', 'family', 'home', 'call', 'birthday'],
    };
    
    for (final entry in categoryKeywords.entries) {
      for (final keyword in entry.value) {
        if (text.contains(RegExp(r'\b' + keyword + r'\b', caseSensitive: false))) {
          print('📂 Category detected: ${entry.key} (keyword: $keyword)');
          return entry.key;
        }
      }
    }
    
    return 'Personal'; // Default
  }
  
  String _extractPriority(String text) {
    if (text.contains(RegExp(r'\b(high priority|important|urgent|critical)\b', caseSensitive: false))) {
      print('⚠️ High priority detected');
      return 'High';
    }
    if (text.contains(RegExp(r'\b(low priority|not urgent|later)\b', caseSensitive: false))) {
      print('⚠️ Low priority detected');
      return 'Low';
    }
    return 'Medium'; // Default
  }
  
  bool _requiresCaptcha(String text) {
    final captchaKeywords = [
      r'\bcaptcha\b',
      r'\bwith captcha\b',
      r'\bsecurity\b',
      r'\bsecure\b',
      r'\bmust solve\b',
      r'\brequire captcha\b',
      r'\bneeds captcha\b',
      r'\badd captcha\b',
      r'\benable captcha\b',
      r'\blocked\b',
      r'\bprotected\b',
      r'\bwith security\b',
      r'\bverify\b',
      r'\bconfirm\b',
      r'\bmath problem\b',
    ];
    
    for (final keyword in captchaKeywords) {
      if (text.contains(RegExp(keyword, caseSensitive: false))) {
        print('🔒 CAPTCHA keyword detected: $keyword');
        return true;
      }
    }
    
    print('ℹ️ No CAPTCHA requirement detected - will be a normal alarm');
    return false;
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
