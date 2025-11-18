import 'package:file_picker/file_picker.dart';
import 'dart:io';

class SoundPickerService {
  static final SoundPickerService _instance = SoundPickerService._internal();
  factory SoundPickerService() => _instance;
  SoundPickerService._internal();

  static const List<String> soundOptions = [
    'Default Alarm',
    'Default Notification',
    'Pick Audio File',
  ];

  Future<String?> pickSound(String option) async {
    switch (option) {
      case 'Default Alarm':
        return 'default_alarm';
      
      case 'Default Notification':
        return 'default_notification';
      
      case 'Pick Audio File':
        return await _pickAudioFile();
      
      default:
        return null;
    }
  }

  Future<String?> _pickAudioFile() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null) {
        final String filePath = result.files.single.path!;
        final file = File(filePath);
        
        if (await file.exists()) {
          print('🎵 Audio file selected: $filePath');
          return 'file://$filePath';
        }
      }
      
      return null;
    } catch (e) {
      print('❌ Error picking audio file: $e');
      return null;
    }
  }

  String getDisplayName(String? path) {
    if (path == null || path.isEmpty) return 'Default Alarm';
    
    if (path == 'default_alarm' || path.contains('alarm')) return 'Default Alarm';
    if (path == 'default_notification' || path.contains('notification')) return 'Default Notification';
    if (path.startsWith('content://')) return 'Phone Ringtone';
    if (path.startsWith('file://')) {
      return path.split('/').last.replaceAll('.mp3', '').replaceAll('.m4a', '');
    }
    
    return 'Custom Sound';
  }
}
