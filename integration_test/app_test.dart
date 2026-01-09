import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:wordrop/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('end-to-end test', () {
    testWidgets('tap on settings verifies app launch', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // Verify Home Screen modern UI
      expect(find.text('START LISTENING'), findsOneWidget);

      // Find the Settings Gear icon
      final settingsButton = find.byIcon(Icons.settings);

      // Verify it exists
      expect(settingsButton, findsOneWidget);

      // Tap it
      await tester.tap(settingsButton);
      await tester.pumpAndSettle();

      // Verify we are on Settings Screen
      expect(find.text("App Settings"), findsOneWidget);
      expect(find.text("Global Sensitivity"), findsOneWidget);
      expect(find.text("Appearance"), findsOneWidget); // Verify Theme section

      // Go Back
      await tester.pageBack();
      await tester.pumpAndSettle();
    });
  });
}
