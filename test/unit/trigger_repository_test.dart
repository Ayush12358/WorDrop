import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wordrop/repositories/trigger_word_repository.dart';
import 'package:wordrop/models/trigger_config.dart';

void main() {
  group('TriggerWordRepository', () {
    late TriggerWordRepository repository;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      repository = TriggerWordRepository();
    });

    test('addTriggerWord creates default config', () async {
      await repository.addTriggerWord('TestTrigger');
      final configs = await repository.getConfigs();

      // Expect 2 because repository adds a "Default" item if empty
      expect(configs.length, 2);
      expect(configs.any((c) => c.label == 'TestTrigger'), true);
    });

    test('addConfig saves full config', () async {
      final config = TriggerConfig(
        label: 'MyLabel',
        triggers: ['alias1', 'alias2'],
        actions: [],
      );

      await repository.addConfig(config);
      final configs = await repository.getConfigs();

      expect(configs.length, 2);
      expect(
        configs.firstWhere((c) => c.label == 'MyLabel').triggers.length,
        2,
      );
    });

    test('removeConfig deletes by label', () async {
      await repository.addTriggerWord('ToDelete');
      await repository.addTriggerWord('KeepMe');
      // State: [Default, ToDelete, KeepMe]

      await repository.removeConfig('ToDelete');
      final configs = await repository.getConfigs();

      expect(configs.length, 2); // Default + KeepMe
      expect(configs.any((c) => c.label == 'KeepMe'), true);
      expect(configs.any((c) => c.label == 'ToDelete'), false);
    });

    test('update existing config', () async {
      await repository.addTriggerWord('UpdateMe');

      final newConfig = TriggerConfig(
        label: 'UpdateMe',
        triggers: ['NewAlias'],
        actions: [],
      );

      await repository.addConfig(newConfig);
      final configs = await repository.getConfigs();

      // Should still be 2 (Default + UpdateMe)
      expect(configs.length, 2);
      expect(
        configs.firstWhere((c) => c.label == 'UpdateMe').triggers.first,
        'NewAlias',
      );
    });
  });
}
