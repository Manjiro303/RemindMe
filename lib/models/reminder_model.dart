import 'package:flutter/material.dart';

class ReminderModel {
  final String id;
  String text;
  TimeOfDay time;
  String category;
  String priority;
  String note;
  List<int> days;
  bool enabled;
  String ringtone;
  String? customSoundPath;
  DateTime? specificDate;
  bool isRecurring;

  ReminderModel({
    required this.id,
    required this.text,
    required this.time,
    this.category = 'Personal',
    this.priority = 'Medium',
    this.note = '',
    List<int>? days,
    this.enabled = true,
    this.ringtone = 'Default Alarm',
    this.customSoundPath,
    this.specificDate,
    this.isRecurring = true,
  }) : days = days ?? List.generate(7, (index) => index);

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'text': text,
      'time': '${time.hour}:${time.minute}',
      'category': category,
      'priority': priority,
      'note': note,
      'days': days,
      'enabled': enabled,
      'ringtone': ringtone,
      'customSoundPath': customSoundPath,
      'specificDate': specificDate?.toIso8601String(),
      'isRecurring': isRecurring,
    };
  }

  factory ReminderModel.fromJson(Map<String, dynamic> json) {
    final timeParts = (json['time'] as String).split(':');
    return ReminderModel(
      id: json['id'],
      text: json['text'],
      time: TimeOfDay(
        hour: int.parse(timeParts[0]),
        minute: int.parse(timeParts[1]),
      ),
      category: json['category'] ?? 'Personal',
      priority: json['priority'] ?? 'Medium',
      note: json['note'] ?? '',
      days: List<int>.from(json['days'] ?? List.generate(7, (index) => index)),
      enabled: json['enabled'] ?? true,
      ringtone: json['ringtone'] ?? 'Default Alarm',
      customSoundPath: json['customSoundPath'],
      specificDate: json['specificDate'] != null 
          ? DateTime.parse(json['specificDate']) 
          : null,
      isRecurring: json['isRecurring'] ?? true,
    );
  }

  ReminderModel copyWith({
    String? id,
    String? text,
    TimeOfDay? time,
    String? category,
    String? priority,
    String? note,
    List<int>? days,
    bool? enabled,
    String? ringtone,
    String? customSoundPath,
    DateTime? specificDate,
    bool? isRecurring,
  }) {
    return ReminderModel(
      id: id ?? this.id,
      text: text ?? this.text,
      time: time ?? this.time,
      category: category ?? this.category,
      priority: priority ?? this.priority,
      note: note ?? this.note,
      days: days ?? this.days,
      enabled: enabled ?? this.enabled,
      ringtone: ringtone ?? this.ringtone,
      customSoundPath: customSoundPath ?? this.customSoundPath,
      specificDate: specificDate ?? this.specificDate,
      isRecurring: isRecurring ?? this.isRecurring,
    );
  }
}
