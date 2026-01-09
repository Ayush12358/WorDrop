import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../services/model_downloader_service.dart';

class ModelScreen extends StatefulWidget {
  const ModelScreen({super.key});

  @override
  State<ModelScreen> createState() => _ModelScreenState();
}

class _ModelScreenState extends State<ModelScreen> {
  final _modelService = ModelDownloaderService();
  String _activeModelName = ""; // Name of currently selected model
  Map<String, bool> _downloadedStatus = {};
  String? _downloadingModelName; // Which model is currently downloading
  double _progress = 0.0;
  String _status = "Checking models...";

  @override
  void initState() {
    super.initState();
    _checkModels();
  }

  void _checkModels() async {
    final path = await _modelService.getModelPath();
    final prefs = await SharedPreferences.getInstance();
    final savedName = prefs.getString('selected_model');

    final statusMap = <String, bool>{};
    for (var m in ModelDownloaderService.availableModels) {
      statusMap[m.name] = await _modelService.isModelDownloaded(m);
    }

    setState(() {
      _activeModelName =
          savedName ?? ModelDownloaderService.availableModels[1].name;
      _downloadedStatus = statusMap;
      _status = path != null ? "Ready" : "Select a model";
    });
  }

  void _downloadModel(ModelInfo model) async {
    if (_downloadingModelName != null) return; // Busy

    setState(() {
      _downloadingModelName = model.name;
      _status = "Downloading ${model.name}...";
      _progress = 0;
    });

    try {
      await _modelService.downloadModel(
        model,
        onProgress: (p) => setState(() => _progress = p),
      );

      // Refresh state
      _checkModels();

      setState(() {
        _downloadingModelName = null;
        _status = "Download Complete";
      });
    } catch (e) {
      setState(() {
        _status = "Error: $e";
        _downloadingModelName = null;
      });
    }
  }

  void _setActive(ModelInfo model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_model', model.name);
    _checkModels(); // Refresh path

    // Notify Background Service?
    // In V1, getting model path happens on Service Start.
    // So we might need to restart service or notify reload.
    FlutterBackgroundService().invoke("stopService");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Model switched. Restarting service...")),
      );
    }
    await Future.delayed(const Duration(seconds: 1));
    FlutterBackgroundService().startService();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Models')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _status,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          if (_downloadingModelName != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: LinearProgressIndicator(value: _progress),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: ModelDownloaderService.availableModels.length,
              itemBuilder: (context, index) {
                final model = ModelDownloaderService.availableModels[index];
                final isDownloaded = _downloadedStatus[model.name] ?? false;
                final isActive = model.name == _activeModelName;
                final isDownloading = _downloadingModelName == model.name;

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: ListTile(
                    title: Text(model.name),
                    subtitle: Text(model.fileName),
                    leading: isActive
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : const Icon(Icons.circle_outlined),
                    trailing: isDownloading
                        ? const CircularProgressIndicator()
                        : isDownloaded
                        ? (isActive
                              ? const Text(
                                  "Active",
                                  style: TextStyle(color: Colors.green),
                                )
                              : OutlinedButton(
                                  onPressed: () => _setActive(model),
                                  child: const Text("Select"),
                                ))
                        : IconButton(
                            icon: const Icon(Icons.download),
                            onPressed: () => _downloadModel(model),
                          ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
