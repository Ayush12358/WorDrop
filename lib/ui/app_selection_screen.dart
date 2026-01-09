import 'package:flutter/material.dart';
import 'package:device_apps/device_apps.dart';

class AppSelectionScreen extends StatefulWidget {
  const AppSelectionScreen({super.key});

  @override
  State<AppSelectionScreen> createState() => _AppSelectionScreenState();
}

class _AppSelectionScreenState extends State<AppSelectionScreen> {
  List<Application> _apps = [];
  List<Application> _filteredApps = [];
  bool _loading = true;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadApps();
  }

  Future<void> _loadApps() async {
    // Get apps with launch intent (openable) and icons
    final apps = await DeviceApps.getInstalledApplications(
      includeAppIcons: true,
      includeSystemApps: true,
      onlyAppsWithLaunchIntent: true,
    );

    // Sort alphabetically
    apps.sort(
      (a, b) => a.appName.toLowerCase().compareTo(b.appName.toLowerCase()),
    );

    if (mounted) {
      setState(() {
        _apps = apps;
        _filteredApps = apps;
        _loading = false;
      });
    }
  }

  void _filterApps(String query) {
    if (query.isEmpty) {
      setState(() => _filteredApps = _apps);
    } else {
      final lower = query.toLowerCase();
      setState(() {
        _filteredApps = _apps.where((app) {
          return app.appName.toLowerCase().contains(lower) ||
              app.packageName.toLowerCase().contains(lower);
        }).toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Select App"),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search apps...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 0),
              ),
              onChanged: _filterApps,
            ),
          ),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _filteredApps.isEmpty
              ? const Center(child: Text("No apps found"))
              : ListView.builder(
                  itemCount: _filteredApps.length,
                  itemBuilder: (context, index) {
                    final app = _filteredApps[index];
                    return ListTile(
                      leading: app is ApplicationWithIcon
                          ? Image.memory(app.icon, width: 40, height: 40)
                          : const Icon(Icons.android),
                      title: Text(app.appName),
                      subtitle: Text(app.packageName),
                      onTap: () {
                        // Return the package name
                        Navigator.pop(context, app.packageName);
                      },
                    );
                  },
                ),
    );
  }
}
