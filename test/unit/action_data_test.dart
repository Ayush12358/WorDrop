import 'package:flutter_test/flutter_test.dart';
import 'package:wordrop/models/action_data.dart';

void main() {
  group('ActionInstance', () {
    test('toJson and fromJson should be symmetric', () {
      final instance = ActionInstance.create(ActionType.launchApp, {
        'package': 'com.example.app',
      });

      final json = instance.toJson();
      final recreated = ActionInstance.fromJson(json);

      expect(recreated.id, instance.id);
      expect(recreated.type, instance.type);
      expect(recreated.params, instance.params);
    });

    test('fromJson handles missing params gracefully', () {
      final json = {'id': 'test-id', 'type': 'loudSiren'};

      final instance = ActionInstance.fromJson(json);
      expect(instance.type, ActionType.loudSiren);
      expect(instance.params, isEmpty);
    });

    test('fromJson falls back to vibrate on invalid type', () {
      final json = {'id': 'test-id', 'type': 'nonExistentType'};

      final instance = ActionInstance.fromJson(json);
      expect(instance.type, ActionType.vibrate);
    });
  });
}
