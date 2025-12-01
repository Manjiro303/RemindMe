# RemindMe - Smart Reminder App

🔔 A powerful Flutter reminder app with background alarms that work even when closed or phone is off. Features categories, priorities, custom scheduling, CAPTCHA security & Material Design 3 UI.

## ✨ Features

- ⏰ **Reliable Alarms** - Works even when app is closed or phone is off
- 🔄 **Recurring Reminders** - Set daily, weekday, weekend, or custom schedules
- 📅 **One-Time Reminders** - Schedule for specific dates
- 🔐 **CAPTCHA Security** - Solve math problems to dismiss important alarms
- 📂 **Categories** - Work, Personal, Health, Shopping, Other
- ⚠️ **Priority Levels** - High, Medium, Low
- 🎵 **Custom Sounds** - Choose from default alarms or custom audio files
- 📱 **Material Design 3** - Modern, beautiful UI
- 🌙 **Full-Screen Alarms** - Launches even from lockscreen
- 🔋 **Battery Optimized** - Efficient background processing

## 🔧 Technical Highlights

- Native Android alarm scheduling using AlarmManager
- Boot receiver for alarm rescheduling after device restart
- Wake lock implementation for reliable alarm triggering
- Kotlin + Dart integration
- SharedPreferences for persistent storage
- UUID-based unique alarm IDs to prevent collisions

## 🚀 Installation

### Prerequisites
- Flutter 3.24.0 or higher
- Android SDK 21+ (Android 5.0 Lollipop)
- Java 17

### Steps

1. **Clone the repository**
```bash
git clone https://github.com/yourusername/remindme.git
cd remindme
```

2. **Install dependencies**
```bash
flutter pub get
```

3. **Run the app**
```bash
flutter run
```

4. **Build APK**
```bash
flutter build apk --release
```

## 📋 Permissions

The app requires the following permissions:

- ✅ `SCHEDULE_EXACT_ALARM` - Schedule precise alarms
- ✅ `USE_EXACT_ALARM` - Android 12+ exact alarm permission
- ✅ `POST_NOTIFICATIONS` - Show notifications (Android 13+)
- ✅ `RECEIVE_BOOT_COMPLETED` - Reschedule alarms after reboot
- ✅ `WAKE_LOCK` - Wake device when alarm fires
- ✅ `VIBRATE` - Vibrate on alarm
- ✅ `USE_FULL_SCREEN_INTENT` - Show full-screen alarm UI

## 🛠️ Recent Fixes (v2.8.0)

### Critical Bug Fixes
- ✅ Fixed alarm ID collision issues using improved UUID-to-int conversion
- ✅ Added auto-stop for ringtone after 5 minutes
- ✅ Fixed CAPTCHA bypass by removing dismiss action when CAPTCHA required
- ✅ Added Android 13+ notification permission handling
- ✅ Improved time zone handling for alarm scheduling
- ✅ Enhanced error handling throughout codebase
- ✅ Better null safety in BootReceiver
- ✅ Added `USE_EXACT_ALARM` permission for Android 12+
- ✅ Improved vibration patterns for better user attention
- ✅ Added global error handling with FlutterError.onError

### Performance Improvements
- ⚡ Better wake lock management
- ⚡ Optimized alarm rescheduling on boot
- ⚡ Reduced memory footprint
- ⚡ Improved battery efficiency

## 📱 Testing Checklist

Before releasing, test these scenarios:

- [ ] Create recurring reminder (weekdays only)
- [ ] Create one-time reminder for tomorrow
- [ ] Test CAPTCHA requirement - verify dismiss button is hidden
- [ ] Restart device - verify alarms reschedule correctly
- [ ] Test alarm when app is completely closed
- [ ] Test alarm when phone screen is off
- [ ] Verify ringtone stops after 5 minutes
- [ ] Test multiple alarms don't have ID collisions
- [ ] Check Android 13+ notification permissions
- [ ] Verify alarm detail screen shows correctly from notification

## 🏗️ Architecture
```
lib/
├── models/           # Data models
├── providers/        # State management
├── screens/          # UI screens
├── services/         # Business logic
├── utils/            # Constants & themes
└── widgets/          # Reusable widgets

android/
└── app/src/main/kotlin/
    └── com/reminder/myreminders/
        ├── MainActivity.kt       # Main Flutter activity
        ├── AlarmReceiver.kt      # Handles alarm triggers
        └── BootReceiver.kt       # Reschedules after reboot
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📞 Support

For issues and questions, please open an issue on GitHub.

## 🎉 Acknowledgments

- Flutter team for the amazing framework
- Material Design for the beautiful UI components
- Contributors and testers

---

**Made with ❤️ using Flutter**
