import 'package:flutter/services.dart'; // For Clipboard
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_volume_controller/flutter_volume_controller.dart';
import 'package:device_apps/device_apps.dart';

import 'package:audio_session/audio_session.dart';
import 'package:vibration/vibration.dart';
import 'package:torch_light/torch_light.dart';
import '../models/trigger_config.dart';
import '../models/action_data.dart';
import '../repositories/trigger_word_repository.dart';

class ActionService {
  final TriggerWordRepository _triggerRepository = TriggerWordRepository();
  final AudioPlayer _audioPlayer = AudioPlayer(); // For Siren

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
        case ActionType.lockDevice:
          // Requires Accessibility Service (Later)
          break;
        default:
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

      // Play siren asset
      await _audioPlayer.play(AssetSource('sounds/siren.mp3'));

      // Stop after 10 seconds automatically?
      await Future.delayed(const Duration(seconds: 10));
      await _audioPlayer.stop();
    } catch (_) {}
  }

  Future<void> triggerLaunchApp(String packageName) async {
    try {
      await DeviceApps.openApp(packageName);
    } catch (_) {}
  }
}
