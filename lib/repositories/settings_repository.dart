import 'package:shared_preferences/shared_preferences.dart';
import '../util/constants.dart';

class SettingsRepository {
  // --- Legacy / Binary Sensitivity ---

  Future<bool> isHighSensitivity() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.keySensitivityHigh) ??
        true; // Default to Fast
  }

  Future<void> setHighSensitivity(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keySensitivityHigh, value);
  }

  // --- Per-Trigger Toggle ---

  Future<bool> isPerTriggerSensitivityEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(AppConstants.keyPerTriggerSensitivity) ?? false;
  }

  Future<void> setPerTriggerSensitivityEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.keyPerTriggerSensitivity, value);
  }

  // --- Slider / Double Sensitivity ---

  Future<double> getSensitivityValue() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getDouble(AppConstants.keySensitivityValue) ??
        0.0; // Default 0 (Fast)
  }

  Future<void> setSensitivityValue(double value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(AppConstants.keySensitivityValue, value);
    // Sync binary setting for backward compatibility/service logic
    await setHighSensitivity(value < 50.0);
  }

  Future<String> getThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.keyThemeMode) ?? 'system';
  }

  Future<void> setThemeMode(String mode) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.keyThemeMode, mode);
  }
}
