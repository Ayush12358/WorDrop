import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/action_service.dart';
import '../repositories/settings_repository.dart';
import '../locator.dart';
import '../util/app_theme.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _repository = locator<SettingsRepository>();
  double _sensitivityValue = 0.0;
  bool _perTriggerEnabled = false;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    final sliderVal = await _repository.getSensitivityValue();
    final perTrigger = await _repository.isPerTriggerSensitivityEnabled();
    setState(() {
      _sensitivityValue = sliderVal;
      _perTriggerEnabled = perTrigger;
      _loading = false;
    });
  }

  String _currentThemeMode() {
    final mode = themeNotifier.value;
    if (mode == ThemeMode.light) return 'light';
    if (mode == ThemeMode.dark) return 'dark';
    return 'system';
  }

  void _updateGlobalTheme(String mode) {
    if (mode == 'light') {
      themeNotifier.value = ThemeMode.light;
    } else if (mode == 'dark') {
      themeNotifier.value = ThemeMode.dark;
    } else {
      themeNotifier.value = ThemeMode.system;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('App Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            title: const Text("Enable Per-Trigger Sensitivity"),
            subtitle: const Text(
              "Customize sensitivity for each trigger word.",
            ),
            value: _perTriggerEnabled,
            onChanged: (val) async {
              setState(() => _perTriggerEnabled = val);
              await _repository.setPerTriggerSensitivityEnabled(val);
              FlutterBackgroundService().invoke("reloadSettings");
            },
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              "Appearance",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: DropdownButtonFormField<String>(
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.brightness_6),
                labelText: "Theme Mode",
              ),
              // ignore: deprecated_member_use
              value: _currentThemeMode(),
              items: const [
                DropdownMenuItem(
                  value: 'system',
                  child: Text("System Default"),
                ),
                DropdownMenuItem(value: 'light', child: Text("Light Mode")),
                DropdownMenuItem(value: 'dark', child: Text("Dark Mode")),
              ],
              onChanged: (val) async {
                if (val != null) {
                  await _repository.setThemeMode(val);
                  _updateGlobalTheme(val);
                  setState(() {}); // Rebuild to show new value
                }
              },
            ),
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _perTriggerEnabled
                  ? "Global Default Sensitivity"
                  : "Global Sensitivity",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text("Fast (High Sensitivity)"),
                    const Text("Strict (High Accuracy)"),
                  ],
                ),
                Slider(
                  key: const Key('sensitivity_slider'),
                  value: _sensitivityValue,
                  min: 0,
                  max: 100,
                  divisions: 10,
                  label: _sensitivityValue < 50 ? "Fast Mode" : "Strict Mode",
                  onChanged: (val) async {
                    setState(() => _sensitivityValue = val);
                    await _repository.setSensitivityValue(val);
                    FlutterBackgroundService().invoke("reloadSettings");
                  },
                ),
                Text(
                  _sensitivityValue < 50
                      ? "Triggers instantly as you speak. Best for responsiveness."
                      : "Waits for phrase completion. Slower, but fewer false alarms.",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),

          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "Permissions Checklist",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          FutureBuilder<Map<String, bool>>(
            future: _checkPermissions(),
            builder: (context, snapshot) {
              final data = snapshot.data ?? {};
              return Column(
                children: [
                  _buildPermissionTile(
                    "Microphone",
                    data['mic'] ?? false,
                    () => openAppSettings(),
                  ),
                  _buildPermissionTile(
                    "Notification",
                    data['noti'] ?? false,
                    () => openAppSettings(),
                  ),
                  _buildPermissionTile(
                    "Accessibility (Preferred)",
                    data['access'] ?? false,
                    () async {
                      await locator<ActionService>().requestAccessibility();
                      // Wait for user to return?
                      // We can't really await the settings result here easily without LifecycleObserver.
                      // Just setState to refresh when they come back (if hot reload/reassemble triggers, or next frame).
                      // Actually, let's just wait a bit or rely on user re-opening (future builder refreshes on build).
                    },
                    subtitle: "Recommended for 'Lock Device'.",
                  ),
                  _buildPermissionTile(
                    "Device Admin (Fallback)",
                    data['admin'] ?? false,
                    () async {
                      await locator<ActionService>().requestDeviceAdmin();
                      setState(() {});
                    },
                    subtitle: "Alternative for 'Lock Device'.",
                  ),
                  _buildPermissionTile(
                    "System Overlay (Background)",
                    data['overlay'] ?? false,
                    () => openAppSettings(), // No direct overlay request easily
                    subtitle: "Required for background reliability.",
                  ),
                  _buildPermissionTile(
                    "Video/Battery Optimization",
                    data['battery'] ?? false,
                    () => Permission.ignoreBatteryOptimizations.request(),
                    subtitle: "Prevent app from being killed in background.",
                  ),
                  _buildPermissionTile(
                    "Digital Assistant (Optional)",
                    data['assistant'] ?? false,
                    () => locator<ActionService>().openAssistantSettings(),
                    subtitle: "Allows replacing Google Assistant.",
                  ),
                ],
              );
            },
          ),

          const Divider(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              "About",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text("Developer"),
            subtitle: const Text("Ayush Maurya"),
            trailing: const Text("Independent"),
          ),
          ListTile(
            leading: const Icon(Icons.policy),
            title: const Text("License"),
            subtitle: const Text("Apache 2.0"),
          ),
          FutureBuilder<String>(
            future: _getAppVersion(),
            builder: (context, snapshot) {
              return ListTile(
                leading: const Icon(Icons.info_outline),
                title: const Text("Version"),
                subtitle: Text(snapshot.data ?? "Loading..."),
              );
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Future<String> _getAppVersion() async {
    // Ideally use package_info_plus, but for now hardcode or use a simple string since we don't have that dep fully set up in this context snippet
    // Actually, let's just return a static string for V2.0 to avoid adding deps mid-task unless needed.
    return "v0.0.1";
  }

  Future<Map<String, bool>> _checkPermissions() async {
    return {
      'mic': await Permission.microphone.isGranted,
      'noti': await Permission.notification.isGranted,
      'access': await locator<ActionService>().isAccessibilityActive(),
      'admin': await locator<ActionService>().isDeviceAdminActive(),
      'overlay': await Permission.systemAlertWindow.isGranted,
      'battery': await Permission.ignoreBatteryOptimizations.isGranted,
      'assistant': await locator<ActionService>().isAssistantActive(),
    };
  }

  Widget _buildPermissionTile(
    String title,
    bool isGranted,
    VoidCallback onTap, {
    String? subtitle,
  }) {
    return ListTile(
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: isGranted
          ? const Icon(Icons.check_circle, color: Colors.green)
          : ElevatedButton(onPressed: onTap, child: const Text("Grant")),
    );
  }
}
