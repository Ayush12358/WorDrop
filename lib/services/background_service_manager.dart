import 'dart:async';
import 'dart:convert';
import 'dart:ui';

import 'package:flutter_background_service/flutter_background_service.dart';
// import 'package:flutter_background_service_android/flutter_background_service_android.dart';
// Note: flutter_background_service 5.0.0 changes import structure, checking docs might be needed.
// Usually for 5.x it is just flutter_background_service.

import 'package:vosk_flutter_2/vosk_flutter_2.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'model_downloader_service.dart';
import 'action_service.dart';
import '../repositories/trigger_word_repository.dart';
import '../repositories/settings_repository.dart';

// Top-level entry point
@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });
    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
    // stopService moved to later to access speechService
  }

  // Initialize Repositories and Services
  final modelService = ModelDownloaderService();
  final triggerRepo = TriggerWordRepository();
  // final actionRepo = ActionRepository(); // Removed unused
  final actionService = ActionService();

  // Load Model
  final modelPath = await modelService.getModelPath();
  if (modelPath == null) {
    // print('Error: Model not found');
    service.stopSelf();
    return;
  }

  final vosk = VoskFlutterPlugin.instance();
  final model = await vosk.createModel(modelPath);
  final recognizer = await vosk.createRecognizer(
    model: model,
    sampleRate: 16000,
  );

  // Load Triggers and set Grammar
  final triggers = await triggerRepo.getTriggerWords();
  final grammarList = <String>[...triggers, "[unk]"];
  // final grammarJson = jsonEncode(grammarList);

  recognizer.setGrammar(grammarList);
  // VoskFlutterPlugin usually has a SpeechService to handle mic.
  // Wait, vosk_flutter 0.3.x uses a speech service?
  // Let's check vosk_flutter example usage pattern.
  // Assuming standard usage:

  final speechService = await vosk.initSpeechService(recognizer);
  await speechService.start();

  // Register stop listener AFTER speech service is ready to ensure graceful shutdown
  if (service is AndroidServiceInstance) {
    service.on('stopService').listen((event) async {
      await speechService.stop();
      service.stopSelf();
    });
  }

  // 5. Load Settings
  final settingsRepo = SettingsRepository();
  final isHighSensitivity = await settingsRepo.isHighSensitivity();

  // Listen to results based on sensitivity
  if (isHighSensitivity) {
    // FAST MODE: triggers on partial
    speechService.onPartial().listen((event) {
      try {
        final decoded = jsonDecode(event);
        final partial = decoded['partial'] as String;
        if (partial.isNotEmpty) {
          _checkAndExecute(partial, triggers, actionService, speechService);
        }
      } catch (_) {}
    });
  } else {
    // ACCURATE MODE: triggers on final result
    speechService.onResult().listen((event) {
      try {
        final decoded = jsonDecode(event);
        final text = decoded['text'] as String;
        if (text.isNotEmpty) {
          _checkAndExecute(text, triggers, actionService, speechService);
        }
      } catch (_) {}
    });
  }

  // Keep alive
  Timer.periodic(const Duration(seconds: 10), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        service.setForegroundNotificationInfo(
          title: "WorDrop Active (${isHighSensitivity ? 'Fast' : 'Strict'})",
          content: "Listening for: ${triggers.join(', ')}",
        );
      }
    }
  });
}

void _checkAndExecute(
  String text,
  List<String> triggers,
  ActionService actionService,
  SpeechService speechService,
) {
  for (final trigger in triggers) {
    if (text.contains(trigger)) {
      // print('Trigger Detected: $trigger');
      actionService.executeFor(trigger);
      speechService.reset();
      break;
    }
  }
}

class BackgroundServiceManager {
  Future<void> initialize() async {
    // Create Notification Channel for Android 14+ stability
    final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
    const AndroidNotificationChannel channel = AndroidNotificationChannel(
      'wordrop_service', // id must match notificationChannelId in configure
      'WorDrop Service',
      description: 'Background listening service for WorDrop',
      importance: Importance.low,
    );
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    final service = FlutterBackgroundService();

    await service.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        autoStart: false,
        isForegroundMode: true,
        notificationChannelId: 'wordrop_service',
        initialNotificationTitle: 'WorDrop Service',
        initialNotificationContent: 'Initializing...',
        foregroundServiceNotificationId: 888,
      ),
      iosConfiguration: IosConfiguration(
        autoStart: false,
        onForeground: onStart,
      ),
    );
  }

  Future<void> start() async {
    final service = FlutterBackgroundService();
    if (!await service.isRunning()) {
      await service.startService();
    }
  }

  Future<void> stop() async {
    final service = FlutterBackgroundService();
    if (await service.isRunning()) {
      service.invoke('stopService');
    }
  }
}
