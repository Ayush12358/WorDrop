import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wordrop/ui/settings_screen.dart';

void main() {
  testWidgets('SettingsScreen loads and toggles sensitivity', (
    WidgetTester tester,
  ) async {
    // 1. Mock SharedPreferences
    SharedPreferences.setMockInitialValues({
      'setting_sensitivity_high': true, // Initial value
    });

    // 2. Pump Widget
    await tester.pumpWidget(const MaterialApp(home: SettingsScreen()));
    await tester.pump(); // Allow FutureBuilder/InitState to complete

    // 3. Verify Initial State (High Sensitivity selected)
    // We look for the RadioListTile with value: true having groupValue: true
    // Logic: The "High Sensitivity" tile has value: true. If selected, groupValue is also true.
    // However, finding RadioListTile directly via predicate is tricky.
    // Easier to check for visual cues or specific widget states if possible.
    // Let's rely on finding text and tapping.

    expect(find.text('High Sensitivity (Fast)'), findsOneWidget);
    expect(find.text('High Accuracy (Strict)'), findsOneWidget);

    // 4. Tap "High Accuracy" (which corresponds to value: false)
    await tester.tap(find.text('High Accuracy (Strict)'));
    await tester.pumpAndSettle(); // Rebuild and save

    // 5. Verify persistence (indirectly, via checking if UI updated state)
    // Ideally we would verify verify(mockRepo.setVal) but we don't have a mock repo injected.
    // We can check SharedPreferences again.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('setting_sensitivity_high'), false);
  });
}
