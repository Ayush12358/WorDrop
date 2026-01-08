// ignore_for_file: deprecated_member_use
import 'package:flutter/material.dart';
import '../repositories/settings_repository.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _repository = SettingsRepository();
  bool _highSensitivity = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  void _loadSettings() async {
    final val = await _repository.isHighSensitivity();
    setState(() {
      _highSensitivity = val;
      _loading = false;
    });
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
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              "Trigger Sensitivity",
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ListTile(
            title: const Text("High Sensitivity (Fast)"),
            subtitle: const Text(
              "Triggers instantly as you speak. Best for responsiveness, but may have false positives.",
            ),
            leading: Radio<bool>(
              value: true,
              groupValue: _highSensitivity,
              onChanged: (val) async {
                if (val != null) {
                  setState(() => _highSensitivity = val);
                  await _repository.setHighSensitivity(val);
                }
              },
            ),
            onTap: () async {
              if (_highSensitivity != true) {
                setState(() => _highSensitivity = true);
                await _repository.setHighSensitivity(true);
              }
            },
          ),
          ListTile(
            title: const Text("High Accuracy (Strict)"),
            subtitle: const Text(
              "Waits for phrase completion. Slower, but significantly fewer false alarms.",
            ),
            leading: Radio<bool>(
              value: false,
              groupValue: _highSensitivity,
              onChanged: (val) async {
                if (val != null) {
                  setState(() => _highSensitivity = val);
                  await _repository.setHighSensitivity(val);
                }
              },
            ),
            onTap: () async {
              if (_highSensitivity != false) {
                setState(() => _highSensitivity = false);
                await _repository.setHighSensitivity(false);
              }
            },
          ),
        ],
      ),
    );
  }
}
