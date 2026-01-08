import 'package:flutter/services.dart'; // For Clipboard
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:device_apps/device_apps.dart';
import 'package:telephony/telephony.dart';
import 'package:geolocator/geolocator.dart';

import 'package:audio_session/audio_session.dart';
import 'package:vibration/vibration.dart';
import 'package:torch_light/torch_light.dart';
import '../models/trigger_config.dart';
import '../models/action_data.dart';
import '../repositories/trigger_word_repository.dart';

class ActionService {
  final TriggerWordRepository _triggerRepository = TriggerWordRepository();
  final Telephony _telephony = Telephony.instance;

  ActionService();

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
          break;
      }
    }

    await Future.wait(futures);
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

  Future<void> triggerFlash() async {
    try {
      final isTorchAvailable = await TorchLight.isTorchAvailable();
      if (isTorchAvailable) {
        for (int i = 0; i < 3; i++) {
          await TorchLight.enableTorch();
          await Future.delayed(const Duration(milliseconds: 150));
          await TorchLight.disableTorch();
          await Future.delayed(const Duration(milliseconds: 150));
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
}
