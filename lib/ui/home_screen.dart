import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/background_service_manager.dart';
import 'model_screen.dart';
import 'trigger_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
    checkServiceStatus();
  }

  Future<void> _requestPermissions() async {
    Map<Permission, PermissionStatus> statuses = await [
      Permission.microphone,
      Permission.notification,
    ].request();

    if (statuses[Permission.microphone]?.isGranted == true &&
        statuses[Permission.notification]?.isGranted == true) {
      // Initialize service ONLY after permissions are granted
      final serviceManager = BackgroundServiceManager();
      await serviceManager.initialize();
    }
  }

  void checkServiceStatus() async {
    final isRunning = await FlutterBackgroundService().isRunning();
    setState(() {
      _isRunning = isRunning;
    });
  }

  void _toggleService() async {
    final service = BackgroundServiceManager();
    if (_isRunning) {
      await service.stop();
    } else {
      await service.start();
    }
    // Give it a moment to update state
    await Future.delayed(const Duration(milliseconds: 500));
    checkServiceStatus();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('WorDrop'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              _isRunning ? 'Listening...' : 'Inactive',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _toggleService,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 20,
                ),
                backgroundColor: _isRunning ? Colors.red : Colors.green,
                foregroundColor: Colors.white,
              ),
              child: Text(
                _isRunning ? 'STOP' : 'START',
                style: const TextStyle(fontSize: 20),
              ),
            ),
            const SizedBox(height: 40),
            _buildNavButton(
              context,
              'Manage Models',
              Icons.download,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ModelScreen()),
              ),
            ),
            _buildNavButton(
              context,
              'Trigger Words',
              Icons.record_voice_over,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TriggerScreen()),
              ),
            ),
            _buildNavButton(
              context,
              'Settings',
              Icons.settings,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNavButton(
    BuildContext context,
    String label,
    IconData icon,
    VoidCallback onPressed,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 40.0),
      child: SizedBox(
        width: double.infinity,
        child: OutlinedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon),
          label: Text(label),
        ),
      ),
    );
  }
}
