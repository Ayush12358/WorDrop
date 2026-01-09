import 'package:flutter/services.dart'; // For Clipboard
import 'dart:io'; // For File
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:device_apps/device_apps.dart';
import 'package:telephony/telephony.dart';
import 'package:geolocator/geolocator.dart';

import 'package:http/http.dart' as http;
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';

import 'package:audio_session/audio_session.dart';
import 'package:vibration/vibration.dart';
import 'package:torch_light/torch_light.dart';
import '../models/trigger_config.dart';
import '../models/action_data.dart';
import '../models/activity_log.dart';
import '../repositories/trigger_word_repository.dart';
import '../repositories/log_repository.dart';

class ActionService {
  final TriggerWordRepository _triggerRepository = TriggerWordRepository();
  final Telephony _telephony = Telephony.instance;

  static final ActionService _instance = ActionService._internal();

  factory ActionService() {
    return _instance;
  }

  ActionService._internal();

  // Callbacks to control Background Service (Vosk)
  Future<void> Function()? onPauseRecognition;
  Future<void> Function()? onResumeRecognition;

  Future<void> executeFor(String triggerWord) async {
    // 1. Get specific config
    TriggerConfig? config = await _triggerRepository.getConfigFor(triggerWord);

    // Fallback if null (shouldn't happen)
    final actionsToRun =
        config?.actions ??
        [
          ActionInstance.create(ActionType.pauseMedia),
          ActionInstance.create(ActionType.vibrate),
        ];

    // Execute actions in parallel
    List<Future<void>> futures = [];

    for (final action in actionsToRun) {
      switch (action.type) {
        case ActionType.pauseMedia:
          futures.add(triggerPause());
          break;
        case ActionType.vibrate:
          futures.add(triggerVibrate());
          break;
        case ActionType.flash:
          futures.add(triggerFlash());
          break;
        case ActionType.muteAll:
          futures.add(triggerMuteAll());
          break;
        case ActionType.clearClipboard:
          futures.add(triggerClearClipboard());
          break;
        case ActionType.loudSiren:
          futures.add(triggerLoudSiren());
          break;
        case ActionType.launchApp:
          if (action.params.containsKey('package')) {
            futures.add(triggerLaunchApp(action.params['package']));
          }
          break;
        case ActionType.emergencySms:
          if (action.params.containsKey('phone')) {
            futures.add(
              triggerEmergencySms(
                action.params['phone'],
                action.params['message'] ??
                    "Help! I triggered my emergency SOS.",
              ),
            );
          }
          break;
        case ActionType.fakeCall:
          FlutterBackgroundService().invoke("fakeCall", {
            "name": "Potential Harm",
          });
          break;
        case ActionType.lockDevice:
          const channel = MethodChannel('com.ayush.wordrop/device_admin');
          try {
            // 1. Try Accessibility Service (Preferred)
            final bool? isAccessActive = await channel.invokeMethod<bool>(
              'isAccessibilityActive',
            );
            if (isAccessActive == true) {
              await channel.invokeMethod('lockDeviceAccessibility');
              break;
            }

            // 2. Fallback to Device Admin
            await channel.invokeMethod('lockDevice');
          } catch (_) {
            // Consider logging error
          }
          break;
        case ActionType.webhook:
          if (action.params.containsKey('url')) {
            futures.add(
              triggerWebhook(
                action.params['url'],
                method: action.params['method'] ?? 'GET',
                body: action.params['body'],
              ),
            );
          }
          break;
        case ActionType.audioRecord:
          futures.add(
            triggerAudioRecord(
              duration: Duration(seconds: action.params['duration'] ?? 10),
            ),
          );
          break;
        case ActionType.privacyWipe:
          // Execute immediately (don't wait for others if this is destructive)
          futures.add(triggerPrivacyWipe());
          break;
      }
    }

    await Future.wait(futures);

    // 3. Log the event
    await _logUsage(
      triggerWord,
      config?.label ?? "Unknown",
      actionsToRun.first.type.name,
    );
  }

  Future<void> _logUsage(
    String trigger,
    String label,
    String actionType,
  ) async {
    try {
      final log = ActivityLog(
        timestamp: DateTime.now(),
        triggerLabel: "$label ($trigger)",
        actionType: actionType, // Simplification: Log first action type
        success: true,
      );
      await LogRepository().addLog(log);
    } catch (_) {}
  }

  Future<bool> requestDeviceAdmin() async {
    const channel = MethodChannel('com.ayush.wordrop/device_admin');
    try {
      final bool? success = await channel.invokeMethod<bool>(
        'requestDeviceAdmin',
      );
      return success ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isDeviceAdminActive() async {
    const channel = MethodChannel('com.ayush.wordrop/device_admin');
    try {
      final bool? isActive = await channel.invokeMethod<bool>('isAdminActive');
      return isActive ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<bool> isAccessibilityActive() async {
    const channel = MethodChannel('com.ayush.wordrop/device_admin');
    try {
      final bool? isActive = await channel.invokeMethod<bool>(
        'isAccessibilityActive',
      );
      return isActive ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> requestAccessibility() async {
    const channel = MethodChannel('com.ayush.wordrop/device_admin');
    try {
      await channel.invokeMethod('requestAccessibility');
    } catch (_) {}
  }

  Future<bool> isAssistantActive() async {
    const channel = MethodChannel('com.ayush.wordrop/device_admin');
    try {
      final bool? isActive = await channel.invokeMethod<bool>(
        'isAssistantActive',
      );
      return isActive ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> openAssistantSettings() async {
    const channel = MethodChannel('com.ayush.wordrop/device_admin');
    try {
      await channel.invokeMethod('openAssistantSettings');
    } catch (_) {}
  }

  Future<void> triggerPause() async {
    final session = await AudioSession.instance;
    await session.configure(
      const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.playback,
        avAudioSessionCategoryOptions:
            AVAudioSessionCategoryOptions.mixWithOthers,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.speech,
          usage: AndroidAudioUsage.assistant,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransient,
        androidWillPauseWhenDucked: true,
      ),
    );

    if (await session.setActive(true)) {
      await Future.delayed(const Duration(seconds: 3));
      await session.setActive(false);
    }
  }

  Future<void> triggerVibrate() async {
    if (await Vibration.hasVibrator()) {
      Vibration.vibrate(pattern: [0, 200, 100, 200]);
    }
  }

  bool _isCancelled = false;

  Future<void> triggerFlash() async {
    _isCancelled = false; // Reset flag
    try {
      final isTorchAvailable = await TorchLight.isTorchAvailable();
      if (isTorchAvailable) {
        // Flash 5 times (increased from 3 for visibility)
        for (int i = 0; i < 5; i++) {
          if (_isCancelled) break;
          await TorchLight.enableTorch();

          if (_isCancelled) {
            await TorchLight.disableTorch();
            break;
          }
          await Future.delayed(const Duration(milliseconds: 200));

          await TorchLight.disableTorch();

          if (_isCancelled) break;
          await Future.delayed(const Duration(milliseconds: 200));
        }
      }
    } catch (e) {
      // Ignore torch errors
    }
  }

  // --- New Actions ---

  Future<void> triggerMuteAll() async {
    try {
      // Set all volumes to 0
      await FlutterVolumeController.setVolume(0);
    } catch (_) {}
  }

  Future<void> triggerClearClipboard() async {
    await Clipboard.setData(const ClipboardData(text: ''));
  }

  Future<void> triggerLoudSiren() async {
    try {
      // Max volume first?
      await FlutterVolumeController.setVolume(1.0);

      // Play system alarm sound (looping)
      FlutterRingtonePlayer().playAlarm();

      // Stop after 10 seconds automatically
      await Future.delayed(const Duration(seconds: 10));
      FlutterRingtonePlayer().stop();
    } catch (_) {
      // Ensure stop is called on error if possible
      FlutterRingtonePlayer().stop();
    }
  }

  Future<void> triggerLaunchApp(String packageName) async {
    try {
      await DeviceApps.openApp(packageName);
    } catch (_) {}
  }

  Future<void> triggerEmergencySms(String phone, String message) async {
    try {
      // 1. Get Location (if permission granted)
      String locationSuffix = "";
      // Check/Request permission is tricky in background context.
      // We assume permissions are granted by user in App UI beforehand.
      // But we can check status.
      LocationPermission permission = await Geolocator.checkPermission();

      if (permission == LocationPermission.whileInUse ||
          permission == LocationPermission.always) {
        try {
          Position position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
            ),
          );
          locationSuffix =
              "\n\nLocation: https://maps.google.com/?q=${position.latitude},${position.longitude}";
        } catch (_) {}
      }

      final fullMessage = "$message$locationSuffix";

      // 2. Send SMS (Background)
      await _telephony.sendSms(
        to: phone,
        message: fullMessage,
        isMultipart: true,
      );
    } catch (_) {
      // print("SMS Failed");
    }
  }

  Future<void> stopAll() async {
    _isCancelled = true; // Signal loops to stop
    try {
      // Stop Ringtone/Alarm
      await FlutterRingtonePlayer().stop();
      // Stop Vibration
      Vibration.cancel();
      // Disable Torch
      try {
        await TorchLight.disableTorch();
      } catch (_) {}

      // Deactivate Audio Session to release focus
      final session = await AudioSession.instance;
      await session.setActive(false);
    } catch (_) {}
  }

  Future<void> triggerWebhook(
    String url, {
    String method = 'GET',
    String? body,
  }) async {
    try {
      final uri = Uri.parse(url);
      if (method.toUpperCase() == 'POST') {
        await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: body,
        );
      } else {
        await http.get(uri);
      }
    } catch (_) {
      // print("Webhook failed");
    }
  }

  Future<void> triggerAudioRecord({
    Duration duration = const Duration(seconds: 10),
  }) async {
    try {
      // 1. Pause Recognition to free mic
      if (onPauseRecognition != null) {
        await onPauseRecognition!();
        // Give a brief moment for Vosk to release
        await Future.delayed(const Duration(milliseconds: 500));
      }

      final record = AudioRecorder();

      // Check permissions (Should be granted by app, but good to check)
      if (await record.hasPermission()) {
        final dir = await getApplicationDocumentsDirectory();

        // Stealth: Ensure .nomedia exists
        final nomedia = File('${dir.path}/.nomedia');
        if (!await nomedia.exists()) {
          await nomedia.create();
        }

        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final path = '${dir.path}/recording_$timestamp.m4a';

        // Start recording
        // Note: This MIGHT conflict with Vosk if it's running.
        await record.start(const RecordConfig(), path: path);

        // Wait for duration
        await Future.delayed(duration);

        // Stop
        await record.stop();
        record.dispose();
      }
    } catch (e) {
      // Log error
      // print("Recording Error: $e");
    } finally {
      // 4. Resume Recognition
      if (onResumeRecognition != null) {
        await onResumeRecognition!();
      }
    }
  }

  Future<void> triggerPrivacyWipe() async {
    try {
      // 1. Clear Clipboard
      await triggerClearClipboard();

      // 2. Clear Internal Logs
      await LogRepository().clearLogs();

      // 3. Open Privacy Settings (Best effort to prompt user to clear browser data)
      const channel = MethodChannel('com.ayush.wordrop/device_admin');
      try {
        await channel.invokeMethod('openPrivacySettings');
      } catch (_) {
        // Fallback to general settings logic if needed, or ignore
      }

      // 4. Kill App & Service
      final service = FlutterBackgroundService();
      if (await service.isRunning()) {
        service.invoke("stopService");
      }

      // 5. Exit Process (Brutal kill)
      // await SystemNavigator.pop(); // Graceful
      // exit(0); // importation needed
    } catch (_) {}
  }
}
