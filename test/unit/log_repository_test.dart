import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wordrop/repositories/log_repository.dart';
import 'package:wordrop/models/activity_log.dart';
import 'package:wordrop/models/action_data.dart';

void main() {
  group('LogRepository', () {
    late LogRepository repository;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      repository = LogRepository();
    });

    test('addLog saves log entry', () async {
      final log = ActivityLog(
        timestamp: DateTime.now(),
        triggerLabel: 'Test',
        actionType: ActionType.flash.name,
        success: true,
      );

      await repository.addLog(log);
      final logs = await repository.getLogs();

      expect(logs.length, 1);
      expect(logs.first.triggerLabel, 'Test');
    });

    test('clearLogs wipes all data', () async {
      await repository.addLog(
        ActivityLog(
          timestamp: DateTime.now(),
          triggerLabel: 'Test',
          actionType: ActionType.flash.name,
          success: true,
        ),
      );

      await repository.clearLogs();
      final logs = await repository.getLogs();

      expect(logs, isEmpty);
    });

    test('Log limit is respected', () async {
      // Add 105 logs
      for (int i = 0; i < 105; i++) {
        await repository.addLog(
          ActivityLog(
            timestamp: DateTime.now().add(Duration(seconds: i)),
            triggerLabel: 'Log $i',
            actionType: ActionType.flash.name,
            success: true,
          ),
        );
      }

      final logs = await repository.getLogs();
      expect(logs.length, 100);
      // Should have the latest logs (Log 104 should be present)
      expect(logs.first.triggerLabel, 'Log 104');
    });
  });
}
