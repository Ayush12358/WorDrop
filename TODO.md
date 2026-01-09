# WorDrop Project Tracker

This file serves as the master list of completed work, active tasks, future roadmap, and technical improvements for WorDrop.

---

## ✅ Completed Milestones

### Phase 2.1: Robustness & Privacy (Current Release)
**Focus:** Professionalism, Reliability, and Data Safety.
- [x] **Privacy Wipe**: "Panic Mode" trigger that clears all App Logs, System Clipboard, and kills the app process.
- [x] **Lock Device**: Smart locking using Accessibility Service (Primary) with Device Admin (Fallback).
- [x] **Audio Recording**: Stealthily record audio when triggered, with robust concurrency handling (pausing Vosk).
- [x] **Credits & Ident**: Added "About" section crediting **Ayush Maurya** and licensing info.
- [x] **CI/CD Pipeline**: GitHub Actions now run `flutter test` and `flutter analyze` before building Release APKs.
- [x] **Developer Tools**: `verify.bat` script for one-click local health checks.
 
### Phase 2.0: Connectivity & Safety
**Focus:** Connecting the offline assistant to the outside world.
- [x] **App Launcher**: Voice command to launch any installed app ("Launch Spotify").
- [x] **Emergency Actions**:
    - [x] **Fake Call**: Simulates an incoming call.
    - [x] **Emergency SMS**: Sends GPS location to trusted contacts.
    - [x] **Loud Siren**: Maximum volume alarm.
- [x] **Webhooks**: Execute HTTP requests (GET/POST) to control Smart Home devices (Home Assistant, ESP32, etc.).
- [x] **Activity History**: Persistent log of all triggers and actions executed.

### Phase 1.x: Core Foundation (MVP)
- [x] **Offline Speech Recognition**: Integrated Vosk-Android for highly accurate, offline wakeword detection.
- [x] **Background Service**: Persistent notification and service that runs even when the app is closed.
- [x] **Smart Sensitivity**: Dual-mode sensitivity (Fast vs Strict) with a user-configurable slider (0-100).
- [x] **Basic Actions**: Flashlight Toggle, Vibration Patterns, Media Pause/Play.
- [x] **Trigger Management**: UI to add/edit/delete categories and aliases.

---

## 🔮 Future Roadmap (Phase 3 & Beyond)

### Context & Hardware Integration
*   [ ] **Two-Factor Trigger (2FA)**: Require a physical button combination (e.g., Volume Up x2) + Voice Trigger to prevent accidental activation.
*   [ ] **Wear OS Companion**: Trigger actions directly from a smartwatch.
*   [ ] **Bluetooth Triggers**: Automatically start/stop listening when connected to specific Bluetooth devices (Car, Headphones).
*   [ ] **Geofencing**: Enable specific profiles based on location (Home vs Work).

### Advanced Actions
*   [ ] **Screenshot**: Take a screenshot silently using Accessibility Service.
*   [ ] **Self-Destruct**: Advanced data wipe (requires Root or MDM access - research needed).

---


## 🏗️ Technical Improvements (Engineering Health)

### ✅ Completed
*   **Dependency Injection**: Implemented `get_it` and refactored `SettingsScreen`/`ActionService`.
*   **Tests**: Full unification (Unit, Widget, E2E) with `test_suite.bat`.
*   **CI/CD**: `test_suite.yml` for manual E2E in cloud.
*   **Privacy**: Stealth recordings, Logs, Wipe logic.

### 🔮 Future Roadmap
*   **Performance**: Migrate audio recording to separate Isolate.
*   **Security**: Implement Android KeyStore for encrypting triggers.
*   **Context**: WiFi/Location-based triggers.

### 📊 Current Test Coverage Strategy
*   **Data Models & Repositories**: ✅ **100% Covered**. We verified `TriggerWordRepository`, `LogRepository`, and `SettingsRepository` logic.
*   **Services (Business Logic)**: ❌ **0% Covered**. `ActionService` logic (e.g., "Did Siren play?") is untested because of hard dependency on native plugins (`flutter_ringtone_player`, etc.).
    *   *Fix*: Requires **Dependency Injection** refactor (Priority #1).
*   **UI (Widgets)**: ⚠️ **Stubbed**. Screen tests exist but are skipped/commented out because we can't mock the Services they depend on.

### Architecture & Code Quality
*   [ ] **Remove Unused Dependencies**: `dio` is listed in `pubspec.yaml` but `http` is used in `ActionService`. Standardize on one (likely `dio` for better interceptors/retries).
*   [x] **Error Boundary**: Wrapped the app in `runZonedGuarded` to catch unhandled async errors and log them.
*   [ ] **Localization (l10n)**: Move hardcoded strings to `.arb` files to support multiple languages.
*   [x] **Constants**: Extracted keys (e.g., `'setting_sensitivity_value'`) into a shared `AppConstants` class.
*   [ ] **Linting**: Upgrade to `very_good_analysis` for stricter rules (e.g., awaiting futures, const constructors).

### Security & Privacy
*   [ ] **Secure Storage**: Switch to `flutter_secure_storage` for keeping Webhook URLs and Phone Numbers encrypted.
*   [ ] **Obfuscation**: Enable R8/ProGuard obfuscation for release builds.
*   [ ] **Stealth Recording**: Ensure audio recordings are excluded from Gallery updates (add `.nomedia` file to recording dir).

---

## 🚀 Integration & DevOps
*   [ ] **Play Store Publishing**:
    *   Setup Fastlane for automated upload to "Internal" or "Alpha" tracks.
    *   Generate signed AABs automatically on Git Tag.
*   [ ] **Crash Reporting**: Integrate Firebase Crashlytics to capture the swallowed errors in `ActionService`.
*   [ ] **Analytics (Opt-in)**: Privacy-preserving usage stats to understand which actions are most used.

---

## 🎨 UX Polish & Notifications (User Experience)
To improve transparency, we need to add local notifications for specific background actions:

*   [ ] **Siren/Alarm**: Show "Siren Playing - Tap to Stop" notification with a "Stop" action button.
*   [ ] **Emergency SOS**: Show "SOS Sent to [Contact]" once successfully delivered.
*   [ ] **Audio Recording**:
    *   *Default*: Show "Recording in Progress" (Android requirement for foreground service mic usage).
    *   *Stealth Option*: Explore "Service Type" toggles to minimize visibility if legally permissible.
*   [ ] **Privacy Wipe**: Show "Device Sanitized" toast before killing the app.
*   [ ] **Webhook**: Show "Webhook [Name] Failed" if the HTTP request errors out.
*   [ ] **App Launch**: No notification needed (Result is visible).

## 💡 Suggestions for "WorDrop VNext"
*   **Theming Engine**: Support "Material You" (Dynamic Color) to match the user's wallpaper.
*   **Onboarding Flow**: A dedicated "Welcome" slider to explain permissions (Mic, Overlay, Battery) to new users.
*   **Backup & Restore**: Export configuration (Triggers/Webhooks) to a JSON file to share between devices.
*   **Dictation Mode**: A special mode that types what you speak into the currently focused text field (Voice Typing replacement).
*   **Accessibility**: Add "TalkBack" labels to all icon-only buttons for visually impaired users.
