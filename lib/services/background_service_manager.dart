import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/services.dart';

import 'package:flutter_background_service/flutter_background_service.dart';
// import 'package:flutter_background_service_android/flutter_background_service_android.dart';
// Note: flutter_background_service 5.0.0 changes import structure, checking docs might be needed.
// Usually for 5.x it is just flutter_background_service.

import 'package:vosk_flutter_2/vosk_flutter_2.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/trigger_config.dart';
import 'model_downloader_service.dart';
import 'action_service.dart';
import '../repositories/trigger_word_repository.dart';
import '../repositories/settings_repository.dart';

// Top-level entry point
@pragma('vm:entry-point')
// State variables
List<TriggerConfig> _allConfigs = [];
List<String> _fastTriggers = [];
List<String> _strictTriggers = [];
bool _isHighSensitivity = true;
bool _perTriggerEnabled = false;
StreamSubscription? _partialSubscription;
StreamSubscription? _resultSubscription;

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
    service.on('stopActions').listen((event) async {
      ActionService().stopAll();
    });
  }

  // Initialize Repositories and Services
  final modelService = ModelDownloaderService();
  final triggerRepo = TriggerWordRepository();
  final actionService = ActionService();
  final settingsRepo = SettingsRepository();

  // Load Model
  final modelPath = await modelService.getModelPath();
  if (modelPath == null) {
    service.stopSelf();
    return;
  }

  final vosk = VoskFlutterPlugin.instance();
  final model = await vosk.createModel(modelPath);
  final recognizer = await vosk.createRecognizer(
    model: model,
    sampleRate: 16000,
  );

  final speechService = await vosk.initSpeechService(recognizer);

  // Helper function to reload config
  Future<void> loadConfig() async {
    _allConfigs = await triggerRepo.getConfigs();
    _isHighSensitivity = await settingsRepo.isHighSensitivity();
    _perTriggerEnabled = await settingsRepo.isPerTriggerSensitivityEnabled();

    _fastTriggers.clear();
    _strictTriggers.clear();
    List<String> allTriggerWords = [];

    for (var config in _allConfigs) {
      allTriggerWords.addAll(config.triggers);

      bool useFast = _isHighSensitivity; // Default global

      if (_perTriggerEnabled) {
        if (config.sensitivity == 'fast') useFast = true;
        if (config.sensitivity == 'strict') useFast = false;
      }

      if (useFast) {
        _fastTriggers.addAll(config.triggers);
      } else {
        _strictTriggers.addAll(config.triggers);
      }
    }

    // Update Grammar
    final grammarList = <String>[...allTriggerWords, "[unk]"];
    recognizer.setGrammar(grammarList);

    // Refresh Notification
    if (service is AndroidServiceInstance &&
        await service.isForegroundService()) {
      service.setForegroundNotificationInfo(
        title: "WorDrop Active",
        content:
            "Fast: ${_fastTriggers.length}, Strict: ${_strictTriggers.length}",
      );
    }

    _setupListeners(speechService, actionService);

    // Inject concurrency handlers for Audio Recording
    actionService.onPauseRecognition = () async {
      await speechService.cancel();
      // print("Vosk Paused for Recording");
    };

    actionService.onResumeRecognition = () async {
      await speechService.start();
      // print("Vosk Resumed after Recording");
    };
  }

  // Initial Load
  await loadConfig();
  await speechService.start();

  // Listen for Reload
  service.on('reloadSettings').listen((event) async {
    // print("Reloading Settings...");
    await loadConfig();
  });

  if (service is AndroidServiceInstance) {
    service.on('stopService').listen((event) async {
      await speechService.stop();
      service.stopSelf();
    });
  }

  // Keep alive / Periodic Update
  Timer.periodic(const Duration(seconds: 10), (timer) async {
    if (service is AndroidServiceInstance) {
      if (await service.isForegroundService()) {
        service.setForegroundNotificationInfo(
          title: "WorDrop Active",
          content:
              "Fast: ${_fastTriggers.length}, Strict: ${_strictTriggers.length}",
        );
      }
    }
  });
}

void _setupListeners(SpeechService speechService, ActionService actionService) {
  _partialSubscription?.cancel();
  _resultSubscription?.cancel();

  // Always listen to Partial if there are Fast triggers
  if (_fastTriggers.isNotEmpty) {
    _partialSubscription = speechService.onPartial().listen((event) {
      try {
        final decoded = jsonDecode(event);
        final partial = decoded['partial'] as String;
        if (partial.isNotEmpty) {
          _checkAndExecute(
            partial,
            _fastTriggers,
            actionService,
            speechService,
          );
        }
      } catch (_) {}
    });
  }

  // Always listen to Result if there are Strict triggers (or just generally to handle flow)
  // Even if no strict triggers, we might want to reset? But reset logic handles that.
  if (_strictTriggers.isNotEmpty) {
    _resultSubscription = speechService.onResult().listen((event) {
      try {
        final decoded = jsonDecode(event);
        final text = decoded['text'] as String;
        if (text.isNotEmpty) {
          _checkAndExecute(text, _strictTriggers, actionService, speechService);
        }
      } catch (_) {}
    });
  }
}

DateTime _lastTriggerTime = DateTime.fromMillisecondsSinceEpoch(0);

void _checkAndExecute(
  String text,
  List<String> triggersToCheck,
  ActionService actionService,
  SpeechService speechService,
) async {
  // Cooldown check (2 seconds)
  if (DateTime.now().difference(_lastTriggerTime).inSeconds < 2) {
    return;
  }

  for (final trigger in triggersToCheck) {
    if (text.contains(trigger)) {
      _lastTriggerTime = DateTime.now(); // Update timestamp

      // Check Smart Lock Logic
      final repo = TriggerWordRepository();
      final config = await repo.getConfigFor(trigger);

      if (config != null && !config.allowWhenLocked) {
        // Check if locked
        const channel = MethodChannel('com.ayush.wordrop/device_admin');
        try {
          final bool isLocked = await channel.invokeMethod('isDeviceLocked');
          if (isLocked) {
            // print("Trigger '$trigger' ignored because device is locked.");
            speechService.reset();
            return;
          }
        } catch (_) {}
      }

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
            AndroidFlutterLocalNotificationsPlugin>()
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
