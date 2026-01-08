import 'package:flutter/material.dart';
import 'ui/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Background service initialization moved to HomeScreen to ensure permissions first
  // final backgroundServiceManager = BackgroundServiceManager();
  // await backgroundServiceManager.initialize();

  runApp(const WorDropApp());
}

class WorDropApp extends StatelessWidget {
  const WorDropApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'WorDrop',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
