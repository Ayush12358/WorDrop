import 'action_data.dart';

class TriggerConfig {
  final String label;
  final List<String> triggers;
  final List<ActionInstance> actions;

  TriggerConfig({
    required this.label,
    required this.triggers,
    required this.actions,
  });

  Map<String, dynamic> toJson() {
    return {
      'label': label,
      'triggers': triggers,
      'actions': actions.map((e) => e.toJson()).toList(),
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

    return TriggerConfig(label: label, triggers: triggers, actions: actions);
  }

  TriggerConfig copyWith({
    String? label,
    List<String>? triggers,
    List<ActionInstance>? actions,
  }) {
    return TriggerConfig(
      label: label ?? this.label,
      triggers: triggers ?? this.triggers,
      actions: actions ?? this.actions,
    );
  }
}
