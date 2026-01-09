import 'package:flutter/material.dart';

final themeNotifier = ValueNotifier<ThemeMode>(ThemeMode.system);

class AppTheme {
  static const _primaryLight = Color(0xFF6200EE);
  static const _primaryDark = Color(0xFFBB86FC);

  static const _secondaryLight = Color(0xFF03DAC6);
  static const _secondaryDark = Color(0xFF03DAC6);

  static final ThemeData light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: _primaryLight,
      secondary: _secondaryLight,
      surface: Color(0xFFF5F5F5), // Light grey background
      onPrimary: Colors.white,
    ),
    scaffoldBackgroundColor: const Color(0xFFF5F5F5),

    appBarTheme: const AppBarTheme(
      backgroundColor: _primaryLight,
      foregroundColor: Colors.white,
      centerTitle: true,
      elevation: 0,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: _secondaryLight,
      foregroundColor: Colors.black,
    ),
  );

  static final ThemeData dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: _primaryDark,
      secondary: _secondaryDark,
      surface: Color(0xFF1E1E1E), // Dark grey surface
      onPrimary: Colors.black,
    ),
    scaffoldBackgroundColor: const Color(0xFF121212),

    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF1F1F1F),
      foregroundColor: Colors.white,
      centerTitle: true,
      elevation: 0,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: _secondaryDark,
      foregroundColor: Colors.black,
    ),
  );
}
