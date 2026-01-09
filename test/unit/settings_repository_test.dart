import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wordrop/repositories/settings_repository.dart';

void main() {
  group('SettingsRepository', () {
    late SettingsRepository repository;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      repository = SettingsRepository();
    });

    test('Default sensitivity is mid-range', () async {
      final val = await repository.getSensitivityValue();
      expect(val, 0.0);
    });

    test('Set sensitivity saves value', () async {
      await repository.setSensitivityValue(75.5);
      final val = await repository.getSensitivityValue();
      expect(val, 75.5);
    });

    test('PerTrigger Toggle works', () async {
      expect(await repository.isPerTriggerSensitivityEnabled(), false);

      await repository.setPerTriggerSensitivityEnabled(true);
      expect(await repository.isPerTriggerSensitivityEnabled(), true);
    });
  });
}
