void _setupNativeListener() {
    platform.setMethodCallHandler((call) async {
      if (call.method == 'onAlarmDetail') {
        final Map<dynamic, dynamic> args = call.arguments;
        final int alarmId = args['notification_id'] ?? 0;
        final String alarmTitle = args['alarm_title'] ?? '';
        final String alarmBody = args['alarm_body'] ?? '';
        final String alarmPriority = args['alarm_priority'] ?? 'Medium';
        final bool requiresCaptcha = args['requiresCaptcha'] ?? false;
        
        final reminders = context.read<ReminderProvider>().reminders;
        final reminder = reminders.firstWhereOrNull(
          (r) => r.id.hashCode.abs() % 2147483647 == alarmId
        );
        
        if (reminder != null && mounted) {
          _showAlarmDetailScreen(reminder);
        }
      }
    });
  }
