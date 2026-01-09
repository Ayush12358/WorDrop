import 'package:flutter/material.dart';
import 'ui/home_screen.dart';
import 'util/app_theme.dart';

import 'dart:async';

import 'locator.dart';
import 'repositories/settings_repository.dart';

void main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      setupLocator();

      runApp(const WorDropApp());
    },
    (error, stack) {
      // Error Reporting: Log to console for now.
      // In future versions, this will connect to Firebase Crashlytics.
      debugPrint('Global Error Caught: $error');
      debugPrint("Global Error: $error\n$stack");
    },
  );
}

class WorDropApp extends StatefulWidget {
  const WorDropApp({super.key});

  @override
  State<WorDropApp> createState() => _WorDropAppState();
}

class _WorDropAppState extends State<WorDropApp> {
  @override
  void initState() {
    super.initState();
    _loadTheme();
  }

  void _loadTheme() async {
    final repo = locator<SettingsRepository>();
    final modeStr = await repo.getThemeMode();
    _updateTheme(modeStr);
  }

  void _updateTheme(String mode) {
    switch (mode) {
      case 'light':
        themeNotifier.value = ThemeMode.light;
        break;
      case 'dark':
        themeNotifier.value = ThemeMode.dark;
        break;
      default:
        themeNotifier.value = ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, _) {
        return MaterialApp(
          title: 'WorDrop',
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: currentMode,
          home: const HomeScreen(),
        );
      },
    );
  }
}
