import 'dart:io';
import 'package:dio/dio.dart';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ModelInfo {
  final String name;
  final String url;
  final String fileName; // e.g. "vosk-model-small-cn-0.22"

  const ModelInfo(this.name, this.url, this.fileName);
}

class ModelDownloaderService {
  static const List<ModelInfo> availableModels = [
    ModelInfo(
      'English (US) Small',
      'https://alphacephei.com/vosk/models/vosk-model-small-en-us-0.15.zip',
      'vosk-model-small-en-us-0.15',
    ),
    ModelInfo(
      'English (India) Small',
      'https://alphacephei.com/vosk/models/vosk-model-small-en-in-0.4.zip',
      'vosk-model-small-en-in-0.4',
    ),
    ModelInfo(
      'English (US) Large',
      'https://alphacephei.com/vosk/models/vosk-model-en-us-0.22.zip',
      'vosk-model-en-us-0.22',
    ),
    ModelInfo(
      'Hindi Small',
      'https://alphacephei.com/vosk/models/vosk-model-small-hi-0.22.zip',
      'vosk-model-small-hi-0.22',
    ),
    ModelInfo(
      'French Small',
      'https://alphacephei.com/vosk/models/vosk-model-small-fr-0.22.zip',
      'vosk-model-small-fr-0.22',
    ),
    ModelInfo(
      'Spanish Small',
      'https://alphacephei.com/vosk/models/vosk-model-small-es-0.42.zip',
      'vosk-model-small-es-0.42',
    ),
  ];

  final Dio _dio = Dio();

  // Returns the path of the *currently selected* model, or null if none selected/downloaded.
  // We'll store the selected model name in SharedPreferences separately,
  // but for now, let's look for ANY downloaded model or a specific preference.
  Future<String?> getModelPath() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final prefs = await SharedPreferences.getInstance();
    final selectedName = prefs.getString('selected_model');

    if (selectedName != null) {
      final info = availableModels.firstWhere(
        (m) => m.name == selectedName,
        orElse: () => availableModels[1], // Default to Indian English
      );
      final modelDir = Directory('${appDocDir.path}/models/${info.fileName}');
      if (await modelDir.exists()) return modelDir.path;
    }

    // Fallback: Check if default Indian English exists
    final defaultModel = availableModels[1];
    final defaultDir = Directory(
      '${appDocDir.path}/models/${defaultModel.fileName}',
    );
    if (await defaultDir.exists()) return defaultDir.path;

    return null;
  }

  Future<bool> isModelDownloaded(ModelInfo model) async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${appDocDir.path}/models/${model.fileName}');
    return await modelDir.exists();
  }

  Future<String> downloadModel(
    ModelInfo model, {
    Function(double)? onProgress,
  }) async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${appDocDir.path}/models');

    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }

    final zipPath = '${modelsDir.path}/temp_model.zip';

    await _dio.download(
      model.url,
      zipPath,
      onReceiveProgress: (received, total) {
        if (total != -1 && onProgress != null) {
          onProgress(received / total);
        }
      },
    );

    final bytes = File(zipPath).readAsBytesSync();
    final archive = ZipDecoder().decodeBytes(bytes);

    for (final file in archive) {
      final filename = file.name;
      if (file.isFile) {
        final data = file.content as List<int>;
        File('${modelsDir.path}/$filename')
          ..createSync(recursive: true)
          ..writeAsBytesSync(data);
      } else {
        Directory('${modelsDir.path}/$filename').createSync(recursive: true);
      }
    }

    await File(zipPath).delete();

    // Set as selected automatically
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('selected_model', model.name);

    return '${modelsDir.path}/${model.fileName}';
  }
}
