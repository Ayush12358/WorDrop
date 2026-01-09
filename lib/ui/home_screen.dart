import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import '../services/background_service_manager.dart';
import 'model_screen.dart';
import 'trigger_screen.dart';
import 'settings_screen.dart';
import 'fake_call_screen.dart';
import 'history_screen.dart';

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

    // Listen for background events
    FlutterBackgroundService().on('fakeCall').listen((event) {
      if (mounted) {
        final name = event?['name'] as String? ?? "Unknown";
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => FakeCallScreen(callerName: name)),
        );
      }
    });
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
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text(
          'WorDrop',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurface,
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // --- Status Section ---
            Container(
              margin: const EdgeInsets.all(24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _isRunning
                    ? colorScheme.primaryContainer
                    : (isDark ? Colors.grey[800] : Colors.white),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(26),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Icon(
                    _isRunning ? Icons.mic : Icons.mic_off,
                    size: 48,
                    color: _isRunning
                        ? colorScheme.onPrimaryContainer
                        : Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _isRunning ? 'Active & Listening' : 'Service Inactive',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: _isRunning
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _isRunning
                        ? 'Say your trigger word to execute actions.'
                        : 'Tap the button below to start protection.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: _isRunning
                          ? colorScheme.onPrimaryContainer.withAlpha(204)
                          : colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),

            // --- Central Control ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: _toggleService,
                  style: FilledButton.styleFrom(
                    backgroundColor: _isRunning
                        ? colorScheme.error
                        : colorScheme.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: Icon(_isRunning ? Icons.stop : Icons.play_arrow),
                  label: Text(
                    _isRunning ? 'STOP LISTENING' : 'START LISTENING',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),

            if (_isRunning) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: OutlinedButton.icon(
                    onPressed: () {
                      FlutterBackgroundService().invoke("stopActions");
                      FlutterRingtonePlayer().stop();
                      Vibration.cancel();
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: colorScheme.error,
                      side: BorderSide(color: colorScheme.error),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(Icons.emergency_share),
                    label: const Text("EMERGENCY STOP ACTIONS"),
                  ),
                ),
              ),
            ],

            const SizedBox(height: 24),

            // --- Grid Dashboard ---
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                padding: const EdgeInsets.symmetric(horizontal: 24),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.3,
                children: [
                  _buildDashboardCard(
                    context,
                    'Triggers',
                    Icons.record_voice_over,
                    colorScheme.secondary,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const TriggerScreen()),
                    ),
                  ),
                  _buildDashboardCard(
                    context,
                    'Models',
                    Icons.language,
                    Colors.blueAccent,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ModelScreen()),
                    ),
                  ),
                  _buildDashboardCard(
                    context,
                    'History',
                    Icons.history,
                    Colors.orangeAccent,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const HistoryScreen()),
                    ),
                  ),
                  _buildDashboardCard(
                    context,
                    'Settings',
                    Icons.settings,
                    Colors.grey,
                    () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsScreen()),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardCard(
    BuildContext context,
    String title,
    IconData icon,
    Color accentColor,
    VoidCallback onTap,
  ) {
    return Card(
      elevation: 0, // Flat card with border or color
      color: Theme.of(
        context,
      ).colorScheme.surfaceContainerHighest.withAlpha(77),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: Theme.of(context).dividerColor.withAlpha(26)),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: accentColor.withAlpha(26),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: accentColor, size: 28),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
