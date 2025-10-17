import 'package:flutter/material.dart';
import '../models/reminder_model.dart';
import '../services/storage_service.dart';
import '../services/alarm_service.dart';

class ReminderProvider with ChangeNotifier {
  List<ReminderModel> _reminders = [];
  final StorageService _storageService = StorageService();
  final AlarmService _alarmService = AlarmService();
  
  String _currentFilter = 'All';
  String _currentSort = 'Time';

  List<ReminderModel> get reminders => _reminders;
  String get currentFilter => _currentFilter;
  String get currentSort => _currentSort;

  List<ReminderModel> get filteredReminders {
    if (_currentFilter == 'All') return _reminders;
    return _reminders.where((r) => r.category == _currentFilter).toList();
  }

  int get totalReminders => _reminders.length;
  int get activeReminders => _reminders.where((r) => r.enabled).length;
  int get todayReminders {
    final today = DateTime.now().weekday - 1;
    return _reminders.where((r) => r.enabled && r.days.contains(today)).length;
  }

  ReminderProvider() {
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    _reminders = await _storageService.loadReminders();
    _sortReminders();
    notifyListeners();
  }

  Future<void> addReminder(ReminderModel reminder) async {
    _reminders.add(reminder);
    await _saveAndSchedule();
    notifyListeners();
  }

  Future<void> updateReminder(String id, ReminderModel updatedReminder) async {
    final index = _reminders.indexWhere((r) => r.id == id);
    if (index != -1) {
      await _alarmService.cancelAlarm(id);
      await Future.delayed(const Duration(milliseconds: 500));
      
      _reminders[index] = updatedReminder;
      
      await _storageService.saveReminders(_reminders);
      _sortReminders();
      
      if (updatedReminder.enabled) {
        await _alarmService.scheduleAlarm(updatedReminder);
      }
      
      notifyListeners();
    }
  }

  Future<void> deleteReminder(String id) async {
    await _alarmService.cancelAlarm(id);
    _reminders.removeWhere((r) => r.id == id);
    await _storageService.saveReminders(_reminders);
    notifyListeners();
  }

  Future<void> toggleReminder(String id) async {
    final index = _reminders.indexWhere((r) => r.id == id);
    if (index != -1) {
      _reminders[index].enabled = !_reminders[index].enabled;
      
      if (_reminders[index].enabled) {
        await _alarmService.scheduleAlarm(_reminders[index]);
      } else {
        await _alarmService.cancelAlarm(id);
      }
      
      await _storageService.saveReminders(_reminders);
      notifyListeners();
    }
  }

  void setFilter(String filter) {
    _currentFilter = filter;
    notifyListeners();
  }

  void setSort(String sort) {
    _currentSort = sort;
    _sortReminders();
    notifyListeners();
  }

  void _sortReminders() {
    switch (_currentSort) {
      case 'Time':
        _reminders.sort((a, b) {
          final aMinutes = a.time.hour * 60 + a.time.minute;
          final bMinutes = b.time.hour * 60 + b.time.minute;
          return aMinutes.compareTo(bMinutes);
        });
        break;
      case 'Category':
        _reminders.sort((a, b) => a.category.compareTo(b.category));
        break;
      case 'Priority':
        final priorityOrder = {'High': 0, 'Medium': 1, 'Low': 2};
        _reminders.sort((a, b) =>
            (priorityOrder[a.priority] ?? 1).compareTo(priorityOrder[b.priority] ?? 1));
        break;
    }
  }

  Future<void> _saveAndSchedule() async {
    await _storageService.saveReminders(_reminders);
    _sortReminders();
    
    for (var reminder in _reminders) {
      if (reminder.enabled) {
        await _alarmService.scheduleAlarm(reminder);
      }
    }
  }

  Future<void> rescheduleAllAlarms() async {
    await _alarmService.rescheduleAllAlarms();
  }

  // Get reminder by ID
  ReminderModel? getReminderById(String id) {
    try {
      return _reminders.firstWhere((r) => r.id == id);
    } catch (e) {
      return null;
    }
  }

  // Get reminder by alarm hash ID
  ReminderModel? getReminderByHashId(int hashId) {
    try {
      return _reminders.firstWhere((r) => r.id.hashCode.abs() % 2147483647 == hashId);
    } catch (e) {
      return null;
    }
  }
}
