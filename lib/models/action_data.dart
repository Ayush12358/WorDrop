import 'package:uuid/uuid.dart';

enum ActionType {
  // Legacy / Core
  pauseMedia,
  vibrate,
  flash,

  // Privacy
  muteAll,
  clearClipboard,
  lockDevice, // Requires Accessibility
  // Safety
  loudSiren,
  emergencySms, // Future
  fakeCall, // Future
  // Automation
  launchApp,
  webhook,
  audioRecord,
  privacyWipe,
}

class ActionInstance {
  final String id;
  final ActionType type;
  final Map<String, dynamic> params;

  ActionInstance({
    required this.id,
    required this.type,
    this.params = const {},
  });

  factory ActionInstance.create(
    ActionType type, [
    Map<String, dynamic> params = const {},
  ]) {
    return ActionInstance(id: const Uuid().v4(), type: type, params: params);
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.name, // Store enum as string
      'params': params,
    };
  }

  factory ActionInstance.fromJson(Map<String, dynamic> json) {
    return ActionInstance(
      id: json['id'] as String,
      type: ActionType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => ActionType.vibrate, // Fallback
      ),
      params: json['params'] as Map<String, dynamic>? ?? {},
    );
  }
}
