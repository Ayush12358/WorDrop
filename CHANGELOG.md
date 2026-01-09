# Changelog

## [0.0.1] - 2026-01-09

### Added
- **Core Functionality**: Offline speech recognition using Vosk.
- **Trigger Management**: Custom trigger words and categories.
- **Actions**:
    - Media Control (Pause/Play).
    - Haptic Feedback (Vibration).
    - Visual Alert (Flashlight).
    - Safety (Loud Siren, Fake Call, Emergency SMS).
    - Privacy (Clear Clipboard, Privacy Wipe).
    - Automation (Launch App).
- **Settings**:
    - Global vs Per-Trigger Sensitivity control.
    - Permissions Checklist.
- **Privacy**:
    - `.nomedia` file creation for stealth recordings.
    - Local-only processing.
- **Robustness**:
    - Dependency Injection with `get_it`.
    - Comprehensive Test Suite (`test/unit`, `test/widget`, `integration_test`).
    - Cloud CI/CD via GitHub Actions.
    - **UI/UX**:
        - Complete Material 3 Modernization.
        - Dark/Light Theme Engine with System Sync.
        - Grid Dashboard for intuitive navigation.

### Technical
- Implemented `ActionService` for centralized action execution.
- Implemented `SettingsRepository` and `TriggerWordRepository`.
- Added `flutter_background_service` for continuous listening.
