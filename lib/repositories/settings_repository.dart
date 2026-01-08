import 'package:shared_preferences/shared_preferences.dart';

class SettingsRepository {
  static const String _kSensitivityKey = 'setting_sensitivity_high';

  // True = High Sensitivity (Fast/Partial)
  // False = High Accuracy (Slow/Result)
  Future<bool> isHighSensitivity() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_kSensitivityKey) ?? true; // Default to Fast
  }

  Future<void> setHighSensitivity(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSensitivityKey, value);
  }
}
