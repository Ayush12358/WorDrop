import 'package:flutter/material.dart';
import 'ui/home_screen.dart';
import 'util/app_theme.dart';

import 'dart:async';

import 'locator.dart';
import 'repositories/settings_repository.dart';
import 'repositories/log_repository.dart';

void main() async {
  runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();
      setupLocator();

      // Handle Flutter errors (layout, etc.)
      FlutterError.onError = (FlutterErrorDetails details) {
        FlutterError.presentError(details); // Dump to console
        debugPrint(details.toString());
        // Log to repository
        try {
          // Simple locator access might fail if not set up, but we are inside runZonedGuarded
          if (locator.isRegistered<LogRepository>()) {
            // Not strictly needed if we use LogRepository() directly or a simple singleton
          }
          // We can use the repository directly since it doesn't depend on complex initialization
          LogRepository().logError(
            "Flutter Error: ${details.exception}",
            details.stack,
          );
        } catch (_) {}
      };

      runApp(const WorDropApp());
    },
    (error, stack) {
      debugPrint('Global Error Caught: $error');
      try {
        LogRepository().logError("Uncaught Exception: $error", stack);
      } catch (_) {}
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
