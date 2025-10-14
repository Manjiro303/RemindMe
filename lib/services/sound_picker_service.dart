import 'package:file_picker/file_picker.dart';
import 'dart:io';
import 'platform_channel_service.dart';

class SoundPickerService {
  static final SoundPickerService _instance = SoundPickerService._internal();
  factory SoundPickerService() => _instance;
  SoundPickerService._internal();

  final PlatformChannelService _platformService = PlatformChannelService();

  static const List<String> soundOptions = [
    'Default Alarm',
    'Default Notification',
    'Pick from Phone',
    'Pick Audio File',
  ];

  Future<String?> pickSound(String option) async {
    switch (option) {
      case 'Default Alarm':
        return await _platformService.getDefaultAlarmUri();
      
      case 'Default Notification':
        return await _platformService.getDefaultNotificationUri();
      
      case 'Pick from Phone':
        await _platformService.pickRingtone();
        // Wait a bit for the ringtone picker to complete
        await Future.delayed(const Duration(seconds: 1));
        return _platformService.selectedRingtoneUri;
      
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
    
    if (path.contains('alarm')) return 'Default Alarm';
    if (path.contains('notification')) return 'Default Notification';
    if (path.startsWith('content://')) return 'Phone Ringtone';
    if (path.startsWith('file://')) {
      return path.split('/').last.replaceAll('.mp3', '').replaceAll('.m4a', '');
    }
    
    return 'Custom Sound';
  }
}
