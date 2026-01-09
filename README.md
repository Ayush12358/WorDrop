# WorDrop - Offline Personal Safety & Automation

![Build Status](https://img.shields.io/github/actions/workflow/status/Ayush12358/wordrop/build.yml?branch=main)
![License](https://img.shields.io/badge/license-Apache%202.0-blue.svg)

WorDrop is an offline, privacy-first Android application designed for personal safety, privacy, and automation. It continuously listens for custom "trigger words" (hotwords) and executes a configurable set of actions when detected.

## Key Features

*   **Offline Speech Recognition**: Powered by [Vosk](https://alphacephei.com/vosk/), identifying trigger words without internet access.
*   **Privacy First**: All audio processing happens locally on the device. No audio is ever sent to the cloud.
*   **Custom Trigger Categories**: Group multiple aliases (e.g., "Hey Assistant", "Computer") under a single category.
*   **Configurable Actions**:
    *   **Media Control**: Pause music/audio.
    *   **Haptic Feedback**: Custom vibration patterns.
    *   **Visual Alert**: Flash the torch/flashlight.
    *   **Privacy**: Mute all audio, clear clipboard.
    *   **Safety**: Loud siren (panic mode).
    *   **Automation**: Launch apps.
*   **Sensitivity Control**: Choose between "Fast" (instant response) and "Strict" (high accuracy) modes.
*   **Modern UI**: Beautiful Material 3 design with full **Dark Mode** support and a clean Grid Dashboard.

## Installation

1.  Clone the repository:
    ```bash
    git clone https://github.com/Ayush12358/wordrop.git
    ```
2.  Install dependencies:
    ```bash
    flutter pub get
    ```
3.  Run on an Android device:
    ```bash
    flutter run
    ```

## Usage

1.  **Download Model**: On first launch, download the offline language model (approx. 50MB).
2.  **Add Triggers**: Go to the "Trigger Categories" screen and add a new category (e.g., "Panic").
3.  **Configure Actions**:
        *   **App Launch**: Search for installed apps (e.g., "Spotify") to launch specific apps.
        *   **Safety**: Select "Play Siren" or "Fake Call" for emergency scenarios.
4.  **Sensitivity Control**:
        *   **Global**: Set default sensitivity in *Settings*.
        *   **Per-Trigger**: In *Settings*, enable "Per-Trigger Sensitivity", then customize each trigger (Fast/Strict) in the Edit dialog.
5.  **Start Service**: Tap the central microphone button on the Home screen to start the background listening service.

## Permissions

WorDrop requires the following permissions to function:
*   `Microphone`: To listen for trigger words.
*   `Notification`: To show the persistent background service notification.
*   `Flashlight`: For visual alerts.
*   `Vibration`: For haptic feedback.
*   `Overlay` (System Alert Window): For certain background interactions.


## Roadmap & Development Phases

### ✅ Phase 1: V1 Release (Current)
- [x] **Core**: Offline Speech Recognition (Vosk), Background Service.
- [x] **Smart Features**:
        - [x] **Hot Reload**: Settings apply instantly.
        - [x] **Smart App Launcher**: List/Search installed apps.
        - [x] **Advanced Sensitivity**: Per-Trigger (Fast/Strict) configuration.
- [x] **Actions**:
    - [x] Media Control (Pause).
    - [x] Haptics & Visual (Vibrate, Flash).
    - [x] Safety (Loud Siren, Fake Call, Emergency SMS).
    - [x] Automation (Launch App).
- [x] **Infrastructure**: CI/CD Workflows, Unit Tests.

### ✅ Phase 2: V2.1 Release (Current)
- [x] **Audio Record**: Stealthily record audio on trigger.
- [x] **Lock Device**: Lock screen immediately (via Accessibility or Device Admin).
- [x] **Data Privacy Mode**: "Incognito" trigger that clears `ActivityLogs`, clipboard, and stops service.
- [x] **Robustness**: Comprehensive Unit Tests & CI Verification.

### 🔮 Phase 3: Future Ideas
- [ ] **Two-Factor Trigger**: Require physical button combo + voice trigger.
- [ ] **Smart Home Integration**: Local webhook calls (e.g., Home Assistant).
- [ ] **Wear OS Companion**: Trigger from watch.

## Credits

*   **Developer**: [Ayush Maurya](https://github.com/Ayush12358) (Independent Developer)

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.
