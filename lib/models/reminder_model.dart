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

  ReminderModel({
    required this.id,
    required this.text,
    required this.time,
    this.category = 'Personal',
    this.priority = 'Medium',
    this.note = '',
    List<int>? days,
    this.enabled = true,
    this.ringtone = 'System Alarm',
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
      ringtone: json['ringtone'] ?? 'System Alarm',
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
    );
  }
}
