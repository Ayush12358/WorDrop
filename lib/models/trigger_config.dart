import 'action_data.dart';

class TriggerConfig {
  final String label;
  final List<String> triggers;
  final List<ActionInstance> actions;
  final String? sensitivity; // 'fast', 'strict', 'default' or null
  final bool allowWhenLocked;

  TriggerConfig({
    required this.label,
    required this.triggers,
    required this.actions,
    this.sensitivity = 'default',
    this.allowWhenLocked = true,
  });

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'triggers': triggers,
      'actions': actions.map((e) => e.toJson()).toList(),
      'sensitivity': sensitivity,
      'allowWhenLocked': allowWhenLocked,
    };
  }

  factory TriggerConfig.fromJson(Map<String, dynamic> json) {
    // Basic fields
    String label =
        json['label'] as String? ?? json['word'] as String? ?? "Unknown";
    List<String> triggers = [];

    if (json['triggers'] != null) {
      triggers = (json['triggers'] as List).map((e) => e.toString()).toList();
    } else if (json['word'] != null) {
      triggers = [json['word'] as String];
    }

    String? sensitivity = json['sensitivity'] as String? ?? 'default';

    // Actions Migration
    List<ActionInstance> actions = [];
    if (json['actions'] != null) {
      actions = (json['actions'] as List)
          .map((e) => ActionInstance.fromJson(e))
          .toList();
    } else {
      // Legacy Migration: Convert old booleans to ActionInstances
      if (json['pause'] == true || json['pause'] == null) {
        actions.add(ActionInstance.create(ActionType.pauseMedia));
      }
      if (json['vibrate'] == true || json['vibrate'] == null) {
        actions.add(ActionInstance.create(ActionType.vibrate));
      }
      if (json['flash'] == true) {
        actions.add(ActionInstance.create(ActionType.flash));
      }
    }

    return TriggerConfig(
      label: label,
      triggers: triggers,
      actions: actions,
      sensitivity: sensitivity,
      allowWhenLocked: json['allowWhenLocked'] ?? true, // Default to true
    );
  }

  TriggerConfig copyWith({
    String? label,
    List<String>? triggers,
    List<ActionInstance>? actions,
    String? sensitivity,
    bool? allowWhenLocked,
  }) {
    return TriggerConfig(
      label: label ?? this.label,
      triggers: triggers ?? this.triggers,
      actions: actions ?? this.actions,
      sensitivity: sensitivity ?? this.sensitivity,
      allowWhenLocked: allowWhenLocked ?? this.allowWhenLocked,
    );
  }
}
