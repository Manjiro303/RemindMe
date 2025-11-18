Future<String?> pickSound(String option) async {
    switch (option) {
      case 'Default Alarm':
        return await _platformService.getDefaultAlarmUri();
      
      case 'Default Notification':
        return await _platformService.getDefaultNotificationUri();
      
      case 'Pick from Phone':
        // For now, just return default alarm sound
        // TODO: Implement native ringtone picker if needed
        return await _platformService.getDefaultAlarmUri();
      
      case 'Pick Audio File':
        return await _pickAudioFile();
      
      default:
        return null;
    }
  }
