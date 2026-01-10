import 'dart:io';
import 'package:dio/dio.dart';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/services.dart' show rootBundle;
import '../repositories/log_repository.dart';
import '../models/activity_log.dart';

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

    // Atomic Install Strategy:
    // 1. Download to temp zip
    // 2. Extract to temp folder
    // 3. Rename temp folder to final folder

    final zipPath = '${modelsDir.path}/temp_${model.fileName}.zip';
    final tempExtractPath = '${modelsDir.path}/temp_${model.fileName}_extract';

    // Cleanup residues from previous failed attempts
    try {
      if (await File(zipPath).exists()) await File(zipPath).delete();
      if (await Directory(tempExtractPath).exists()) {
        await Directory(tempExtractPath).delete(recursive: true);
      }
    } catch (_) {}

    try {
      // 1. Download
      await _dio.download(
        model.url,
        zipPath,
        onReceiveProgress: (received, total) {
          if (total != -1 && onProgress != null) {
            onProgress(received / total);
          }
        },
      );

      // 2. Extract
      final bytes = File(zipPath).readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);

      for (final file in archive) {
        final filename = file.name;
        if (file.isFile) {
          final data = file.content as List<int>;
          File('$tempExtractPath/$filename')
            ..createSync(recursive: true)
            ..writeAsBytesSync(data);
        } else {
          Directory('$tempExtractPath/$filename').createSync(recursive: true);
        }
      }

      // 3. Move/Rename to Final
      // Note: The zip usually contains a root folder (e.g. 'vosk-model-small-en-us-0.15').
      // We need to find that root folder and move IT to the final destination.
      final extractedRoot = Directory(tempExtractPath).listSync().firstWhere(
            (e) => e is Directory,
            orElse: () => Directory(tempExtractPath),
          ) as Directory;

      final finalModelDir = Directory('${modelsDir.path}/${model.fileName}');
      if (await finalModelDir.exists()) {
        await finalModelDir.delete(recursive: true);
      }

      // Try extraction root move first, else move the temp container content
      if (extractedRoot.path != tempExtractPath) {
        await extractedRoot.rename(finalModelDir.path);
      } else {
        // Flat zip? unlikely for vosk, but handle rename of container
        await Directory(tempExtractPath).rename(finalModelDir.path);
      }

      // Success! Update prefs
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_model', model.name);

      return finalModelDir.path;
    } catch (e) {
      // Cleanup on failure
      try {
        if (await File(zipPath).exists()) await File(zipPath).delete();
        if (await Directory(tempExtractPath).exists()) {
          await Directory(tempExtractPath).delete(recursive: true);
        }
      } catch (_) {}
      rethrow;
    } finally {
      // Cleanup zip always
      try {
        if (await File(zipPath).exists()) await File(zipPath).delete();
        // Temp dir should be moved or deleted by now, but just in case
        if (await Directory(tempExtractPath).exists()) {
          await Directory(tempExtractPath).delete(recursive: true);
        }
      } catch (_) {}
    }
  }

  Future<void> installBundledModel() async {
    print("DEBUG: installBundledModel called");
    final appDocDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${appDocDir.path}/models');

    // Check if ANY model is installed. If so, skip.
    if (await modelsDir.exists() && modelsDir.listSync().isNotEmpty) {
      print("DEBUG: installBundledModel - models exist, skipping");
      return;
    }

    // Target Model: English India Small
    const bundledZipAsset = "assets/models/vosk-model-small-en-in-0.4.zip";

    try {
      // Create models dir
      if (!await modelsDir.exists()) {
        await modelsDir.create(recursive: true);
      }

      // Check if asset exists (by trying to load it)
      print("DEBUG: Loading asset: $bundledZipAsset");
      final byteData = await rootBundle.load(bundledZipAsset);
      print("DEBUG: Asset loaded, size: ${byteData.lengthInBytes}");

      // Write to temp file
      final tempZipPath = '${modelsDir.path}/bundled_install.zip';
      final file = File(tempZipPath);
      await file.writeAsBytes(byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      ));
      print("DEBUG: Zip written to $tempZipPath");

      // Extract
      final bytes = file.readAsBytesSync();
      final archive = ZipDecoder().decodeBytes(bytes);
      print("DEBUG: Zip decoded, files: ${archive.length}");

      for (final archiveFile in archive) {
        final filename = archiveFile.name;
        if (archiveFile.isFile) {
          final data = archiveFile.content as List<int>;
          File('${modelsDir.path}/$filename')
            ..createSync(recursive: true)
            ..writeAsBytesSync(data);
        } else {
          Directory('${modelsDir.path}/$filename').createSync(recursive: true);
        }
      }

      await file.delete();

      // Update Prefs
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('selected_model', "English (India) Small");
      print("DEBUG: installBundledModel Configured and Done");
    } catch (e) {
      // Asset might not exist or other error, just ignore
      print("DEBUG: installBundledModel FAILED: $e");
    }
  }
}
