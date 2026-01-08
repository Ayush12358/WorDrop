import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/trigger_config.dart';
import '../models/action_data.dart';

class TriggerWordRepository {
  static const String _kTriggerConfigsKey = 'trigger_configs_v2';
  static const String _kLegacyTriggerWordsKey = 'trigger_words';

  Future<List<TriggerConfig>> getConfigs() async {
    final prefs = await SharedPreferences.getInstance();

    // Check for legacy migration
    if (!prefs.containsKey(_kTriggerConfigsKey) &&
        prefs.containsKey(_kLegacyTriggerWordsKey)) {
      await _migrateLegacy(prefs);
    }

    final String? jsonString = prefs.getString(_kTriggerConfigsKey);
    if (jsonString == null) {
      return [
        TriggerConfig(
          label: "Default",
          triggers: ["wordrop"],
          actions: [
            ActionInstance.create(ActionType.pauseMedia),
            ActionInstance.create(ActionType.vibrate),
          ],
        ),
      ];
    }

    try {
      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded.map((e) => TriggerConfig.fromJson(e)).toList();
    } catch (e) {
      return [
        TriggerConfig(
          label: "Default",
          triggers: ["wordrop"],
          actions: [
            ActionInstance.create(ActionType.pauseMedia),
            ActionInstance.create(ActionType.vibrate),
          ],
        ),
      ];
    }
  }

  // Helper for backward compatibility
  Future<List<String>> getTriggerWords() async {
    final configs = await getConfigs();
    return configs.expand((e) => e.triggers).toList();
  }

  Future<void> addConfig(TriggerConfig config) async {
    final configs = await getConfigs();
    // Remove if exists to update
    configs.removeWhere(
      (c) => c.label.toLowerCase() == config.label.toLowerCase(),
    );
    configs.add(config);
    await _saveConfigs(configs);
  }

  Future<void> removeConfig(String label) async {
    final configs = await getConfigs();
    configs.removeWhere((c) => c.label.toLowerCase() == label.toLowerCase());
    await _saveConfigs(configs);
  }

  Future<void> addTriggerWord(String word) async {
    await addConfig(
      TriggerConfig(
        label: word,
        triggers: [word],
        actions: [ActionInstance.create(ActionType.vibrate)],
      ),
    ); // Adds with defaults
  }

  Future<void> removeTriggerWord(String label) async {
    await removeConfig(label);
  }

  Future<void> _saveConfigs(List<TriggerConfig> configs) async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(configs.map((e) => e.toJson()).toList());
    await prefs.setString(_kTriggerConfigsKey, encoded);
  }

  Future<void> _migrateLegacy(SharedPreferences prefs) async {
    final oldList = prefs.getStringList(_kLegacyTriggerWordsKey) ?? [];
    final newConfigs = oldList
        .map(
          (w) => TriggerConfig(
            label: w,
            triggers: [w],
            actions: [
              ActionInstance.create(ActionType.vibrate),
            ], // Default migration action
          ),
        )
        .toList();
    final encoded = jsonEncode(newConfigs.map((e) => e.toJson()).toList());
    await prefs.setString(_kTriggerConfigsKey, encoded);
  }

  // Retrieve config for specific word
  Future<TriggerConfig?> getConfigFor(String word) async {
    final configs = await getConfigs();
    try {
      // Flexible matching
      return configs.firstWhere(
        (c) =>
            c.triggers.any((t) => word.toLowerCase().contains(t.toLowerCase())),
      );
    } catch (e) {
      return null;
    }
  }
}
