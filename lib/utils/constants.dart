import 'package:flutter/material.dart';

class AppConstants {
  static const String appName = 'My Reminders';
  
  static const List<String> categories = [
    'Work',
    'Personal',
    'Health',
    'Shopping',
    'Other',
  ];
  
  static const List<String> priorities = [
    'High',
    'Medium',
    'Low',
  ];
  
  static const List<String> dayNames = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
  static const List<String> fullDayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  
  static Map<String, Color> getCategoryColors() {
    return {
      'Work': const Color(0xFFF28B50),
      'Personal': const Color(0xFF4DA6F2),
      'Health': const Color(0xFF33CC8C),
      'Shopping': const Color(0xFFD957BF),
      'Other': const Color(0xFF999999),
    };
  }
  
  static Map<String, Color> getPriorityColors() {
    return {
      'High': const Color(0xFFF24C4C),
      'Medium': const Color(0xFFF2B233),
      'Low': const Color(0xFF4DB8F2),
    };
  }
}
