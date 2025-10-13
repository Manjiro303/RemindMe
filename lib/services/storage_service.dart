import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reminder_model.dart';

class StorageService {
  static const String _remindersKey = 'reminders';
  
  Future<List<ReminderModel>> loadReminders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? remindersJson = prefs.getString(_remindersKey);
      
      if (remindersJson == null) return [];
      
      final List<dynamic> decoded = json.decode(remindersJson);
      return decoded.map((item) => ReminderModel.fromJson(item)).toList();
    } catch (e) {
      print('Error loading reminders: $e');
      return [];
    }
  }
  
  Future<bool> saveReminders(List<ReminderModel> reminders) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final List<Map<String, dynamic>> remindersList = 
          reminders.map((r) => r.toJson()).toList();
      final String encoded = json.encode(remindersList);
      return await prefs.setString(_remindersKey, encoded);
    } catch (e) {
      print('Error saving reminders: $e');
      return false;
    }
  }
  
  Future<bool> clearAllReminders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return await prefs.remove(_remindersKey);
    } catch (e) {
      print('Error clearing reminders: $e');
      return false;
    }
  }
}
