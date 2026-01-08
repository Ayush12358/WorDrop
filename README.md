# WorDrop - Offline Personal Safety & Automation

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

## Installation

1.  Clone the repository:
    ```bash
    git clone https://github.com/your-username/wordrop.git
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
3.  **Configure Actions**: Select the actions you want to happen when the trigger is heard (e.g., "Play Siren", "Flash Light").
4.  **Add Aliases**: Add variations of the trigger word (e.g., "Help", "Emergency").
5.  **Start Service**: Tap the central microphone button on the Home screen to start the background listening service.

## Permissions

WorDrop requires the following permissions to function:
*   `Microphone`: To listen for trigger words.
*   `Notification`: To show the persistent background service notification.
*   `Flashlight`: For visual alerts.
*   `Vibration`: For haptic feedback.
*   `Overlay` (System Alert Window): For certain background interactions.

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.
