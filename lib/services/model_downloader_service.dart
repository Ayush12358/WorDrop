import 'dart:io';
import 'package:dio/dio.dart';
import 'package:archive/archive.dart';
import 'package:archive/archive_io.dart';
import 'package:path_provider/path_provider.dart';

class ModelDownloaderService {
  static const String _kModelUrl =
      'https://alphacephei.com/vosk/models/vosk-model-small-en-in-0.4.zip';
  static const String _kModelName = 'vosk-model-small-en-in-0.4';

  final Dio _dio = Dio();

  Future<String?> getModelPath() async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final modelDir = Directory('${appDocDir.path}/models/$_kModelName');

    if (await modelDir.exists()) {
      return modelDir.path;
    }
    return null;
  }

  Future<String> downloadModel({Function(double)? onProgress}) async {
    final appDocDir = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${appDocDir.path}/models');

    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }

    final zipPath = '${modelsDir.path}/model.zip';

    // Download
    await _dio.download(
      _kModelUrl,
      zipPath,
      onReceiveProgress: (received, total) {
        if (total != -1 && onProgress != null) {
          onProgress(received / total);
        }
      },
    );

    // Extract
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

    // Cleanup
    await File(zipPath).delete();

    return '${modelsDir.path}/$_kModelName';
  }
}
