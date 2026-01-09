import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wordrop/ui/settings_screen.dart';
import 'package:wordrop/repositories/settings_repository.dart';
import 'package:wordrop/services/action_service.dart';
import 'package:wordrop/locator.dart';

class FakeSettingsRepository implements SettingsRepository {
  @override
  Future<double> getSensitivityValue() async => 50.0;

  @override
  Future<bool> isPerTriggerSensitivityEnabled() async => false;

  @override
  Future<bool> isHighSensitivity() async => true;

  @override
  Future<void> setHighSensitivity(bool value) async {}

  @override
  Future<void> setPerTriggerSensitivityEnabled(bool value) async {}

  @override
  Future<void> setSensitivityValue(double value) async {}

  @override
  Future<String> getThemeMode() async => 'system';

  @override
  Future<void> setThemeMode(String mode) async {}
}

class FakeActionService implements ActionService {
  @override
  Future<bool> isAccessibilityActive() async => false;

  @override
  Future<bool> isDeviceAdminActive() async => false;

  @override
  Future<bool> isAssistantActive() async => false;

  @override
  Future<void> requestAccessibility() async {}

  @override
  Future<bool> requestDeviceAdmin() async => false;

  @override
  Future<void> openAssistantSettings() async {}

  // Implementing other required members with stubs/errors
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUp(() {
    locator.reset();
    locator.registerSingleton<SettingsRepository>(FakeSettingsRepository());
    locator.registerSingleton<ActionService>(FakeActionService());
  });

  testWidgets('SettingsScreen loads correctly', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pumpAndSettle();

    expect(find.text('App Settings'), findsOneWidget);
    expect(find.text('Global Sensitivity'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Theme Mode'), findsOneWidget);
  });
}
