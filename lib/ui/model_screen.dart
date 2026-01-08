import 'package:flutter/material.dart';
import '../services/model_downloader_service.dart';

class ModelScreen extends StatefulWidget {
  const ModelScreen({super.key});

  @override
  State<ModelScreen> createState() => _ModelScreenState();
}

class _ModelScreenState extends State<ModelScreen> {
  final _modelService = ModelDownloaderService();
  String? _modelPath;
  bool _isDownloading = false;
  double _progress = 0.0;
  String _status = "Checking...";

  @override
  void initState() {
    super.initState();
    _checkModel();
  }

  void _checkModel() async {
    final path = await _modelService.getModelPath();
    setState(() {
      _modelPath = path;
      _status = path != null ? "Model Ready" : "Model Not Found";
    });
  }

  void _downloadModel() async {
    setState(() {
      _isDownloading = true;
      _status = "Downloading...";
      _progress = 0;
    });

    try {
      final path = await _modelService.downloadModel(
        onProgress: (p) {
          setState(() => _progress = p);
        },
      );

      setState(() {
        _modelPath = path;
        _status = "Download Complete";
        _isDownloading = false;
      });
    } catch (e) {
      setState(() {
        _status = "Error: $e";
        _isDownloading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Model')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: ListTile(
                title: const Text('English (Indian) Model'),
                subtitle: Text('vosk-model-small-en-in-0.4'),
                trailing: _modelPath != null
                    ? const Icon(Icons.check_circle, color: Colors.green)
                    : const Icon(Icons.error, color: Colors.red),
              ),
            ),
            const SizedBox(height: 20),
            Text(_status),
            const SizedBox(height: 20),
            if (_isDownloading) LinearProgressIndicator(value: _progress),

            const SizedBox(height: 20),
            if (_modelPath == null && !_isDownloading)
              ElevatedButton.icon(
                onPressed: _downloadModel,
                icon: const Icon(Icons.download),
                label: const Text('Download Model (36MB)'),
              ),

            if (_modelPath != null)
              OutlinedButton.icon(
                onPressed: _downloadModel, // Allow re-download if corrupted
                icon: const Icon(Icons.refresh),
                label: const Text('Re-download Model'),
              ),
          ],
        ),
      ),
    );
  }
}
