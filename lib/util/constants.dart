class AppConstants {
  // Shared Preferences Keys
  static const String keySensitivityValue = 'setting_sensitivity_value';
  static const String keySensitivityHigh = 'setting_sensitivity_high';
  static const String keyPerTriggerSensitivity =
      'setting_per_trigger_sensitivity';
  static const String keyThemeMode =
      'setting_theme_mode'; // system, light, dark
  static const String keyTriggers = 'trigger_configs';
  static const String keyLogs = 'activity_logs';
  static const String keyModelPath = 'model_path';

  // Method Channels
  static const String channelDeviceAdmin = 'com.ayush.wordrop/device_admin';
  static const String channelBackgroundService =
      'com.ayush.wordrop/background_service';

  // Notification IDs
  static const int notificationIdService = 888;
  static const int notificationIdSiren = 999;
}
