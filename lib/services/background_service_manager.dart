import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui';
// ignore_for_file: avoid_print
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter_background_service/flutter_background_service.dart';
// import 'package:flutter_background_service_android/flutter_background_service_android.dart';

import 'package:vosk_flutter_2/vosk_flutter_2.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../models/trigger_config.dart';
import 'model_downloader_service.dart';
import 'action_service.dart';
import '../repositories/trigger_word_repository.dart';
import '../repositories/settings_repository.dart';
import '../repositories/log_repository.dart';

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
void onStart(ServiceInstance service) {
  runZonedGuarded(() async {
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

    // 1. Ensure Model
    await modelService.installBundledModel();
    final modelPath = await modelService.getModelPath();
    if (modelPath == null) {
      service.stopSelf();
      return;
    }

    final vosk = VoskFlutterPlugin.instance();
    final model = await vosk.createModel(modelPath);

    // State: Nullable to allow full recreation
    Recognizer? recognizer;
    SpeechService? speechService;
    bool isStopping = false;

    // Helper: Safely tear down active session
    Future<void> stopSession() async {
      try {
        await speechService?.cancel();
        await speechService?.dispose();
      } catch (_) {}

      try {
        recognizer?.dispose();
      } catch (_) {}

      speechService = null;
      recognizer = null;
    }

    // Register Stop Listener IMMEDIATELY
    if (service is AndroidServiceInstance) {
      service.on('stopService').listen((event) async {
        isStopping = true;
        print("Stopping service requested...");
        await stopSession();
        service.stopSelf();

        // Ensure clean process exit to prevent orphans
        if (Platform.isAndroid) {
          Future.delayed(const Duration(milliseconds: 500), () {
            exit(0);
          });
        }
      });
    }

    // Helper: Build fresh session from config
    Future<void> startSession() async {
      if (isStopping) return;

      // 1. Reload Config Data
      _allConfigs = await triggerRepo.getConfigs();
      _isHighSensitivity = await settingsRepo.isHighSensitivity();
      _perTriggerEnabled = await settingsRepo.isPerTriggerSensitivityEnabled();

      _fastTriggers.clear();
      _strictTriggers.clear();
      List<String> allTriggerWords = [];

      for (var config in _allConfigs) {
        allTriggerWords.addAll(config.triggers);
        bool useFast = _isHighSensitivity;
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

      // 2. Create Grammar List
      final grammarList = <String>[...allTriggerWords, "[unk]"];

      if (isStopping) return;

      // 3. Create Fresh Recognizer with Grammar
      recognizer = await vosk.createRecognizer(
        model: model,
        sampleRate: 16000,
        grammar: grammarList,
      );

      if (isStopping) {
        recognizer?.dispose();
        recognizer = null;
        return;
      }

      // 4. Init SpeechService with Retry & Orphan Logic
      int retryCount = 0;
      while (retryCount < 3) {
        if (isStopping) {
          try {
            recognizer?.dispose();
          } catch (_) {}
          print("Stopping during init. Forcing clean exit.");
          exit(0);
        }
        try {
          speechService = await vosk.initSpeechService(recognizer!);
          break; // Success
        } catch (e) {
          if (e.toString().contains("already exist") ||
              (e is PlatformException && e.code == 'INITIALIZE_FAIL')) {
            retryCount++;
            print(
                "SpeechService already exists. Retrying in 1s... (Attempt $retryCount/3)");

            if (isStopping) {
              print("Stop requested during orphan state. Killing process.");
              exit(0);
            }

            if (retryCount >= 3) {
              print(
                  "Critical: Orphan SpeechService persists. Killing process to cleanup.");
              service.stopSelf();
              exit(0);
            }
            await Future.delayed(const Duration(seconds: 1));
          } else {
            rethrow;
          }
        }
      }

      if (isStopping) {
        await speechService?.dispose();
        speechService = null;
        recognizer?.dispose();
        recognizer = null;
        return;
      }

      // 5. Setup Listeners
      _setupListeners(speechService!, actionService);

      // 6. Config ActionService bridge
      actionService.onPauseRecognition = () async {
        await speechService?.cancel();
      };
      actionService.onResumeRecognition = () async {
        await speechService?.start();
      };

      // 7. Update Notification (Android)
      if (service is AndroidServiceInstance &&
          await service.isForegroundService()) {
        service.setForegroundNotificationInfo(
          title: "WorDrop Active",
          content:
              "Fast: ${_fastTriggers.length}, Strict: ${_strictTriggers.length}",
        );
      }

      // 8. START
      if (!isStopping) {
        await speechService!.start();
      }
    }

    // --- Lifecycle ---

    // Initial Start
    if (!isStopping) {
      await startSession();
    }

    // Clear restart flag on start
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('restart_required', false);
    } catch (_) {}

    // Keep Alive / Notification Update
    Timer.periodic(const Duration(seconds: 10), (timer) async {
      if (service is AndroidServiceInstance &&
          await service.isForegroundService()) {
        service.setForegroundNotificationInfo(
          title: "WorDrop Active",
          content:
              "Fast: ${_fastTriggers.length}, Strict: ${_strictTriggers.length}",
        );
      }
    });
  }, (error, stack) {
    try {
      LogRepository().logError("Background Service Error: $error", stack);
    } catch (_) {}
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

  // Always listen to Result if there are Strict triggers
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
