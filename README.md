# GoTune 🎵

A personal, modern dark music streaming application built with **Flutter**, featuring a high-performance **dual-engine architecture** powered by **JioSaavn** and **Audius**.

---

## ✨ Features

- **Dual-Engine Streaming Catalog:**
  - **JioSaavn Engine:** Full access to mainstream Bollywood, Punjabi hits, regional Indian songs, and new film soundtracks (including *Hangover*, *Dhurandhar*, Arijit Singh, Sidhu Moose Wala) streamed in **crystal-clear 320kbps audio**.
  - **Audius Engine:** Decentralized catalog for trending electronic beats, independent artists, Phonk, Brazilian Funk, and lo-fi tracks.
- **Unified & Provider-Specific Search:**
  - Search across all sources simultaneously or filter specifically by **All Sources**, **JioSaavn**, or **Audius**.
  - Quick trending search tags (*Hangover*, *Dhurandhar*, *Phonk*, *Top Hindi Hits*).
- **Background Playback & Audio Controls:**
  - Powered by `just_audio` and `audio_service`.
  - Notification bar playback controls, lock-screen media controls, and headset button integration.
  - Audio focus & phone call ducking/interruption management with `audio_session`.
- **Playback Capabilities:**
  - Smart queue management (play next, drag-and-drop reorder, clear queue).
  - Sleep timer with countdown notifications.
  - Repeat modes (Off / One / All) & Shuffle.
- **Personal Library & Offline Persistence:**
  - Favorites and recently played track history persisted via `shared_preferences`.
  - Custom playlists creation and management.
- **Aesthetic Dark UI:**
  - Glassmorphic accents, animated equalizers, high-resolution 500x500 album art, and provider badges (`Saavn 320k` & `Audius`).

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://flutter.dev/docs/get-started/install) (3.10.0 or higher)
- Android SDK / Android Studio (for Android builds)

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/Brijesh2005/GoTune.git
   cd GoTune
   ```

2. **Install dependencies:**
   ```bash
   flutter pub get
   ```

3. **Run the application:**
   ```bash
   flutter run
   ```

4. **Build release APK:**
   ```bash
   flutter build apk --release
   ```
   The APK will be generated at `build/app/outputs/flutter-apk/app-release.apk`.

----

## 🛠️ Tech Stack & Architecture

- **Framework:** Flutter / Dart
- **Audio Engine:** `just_audio`, `audio_service`, `audio_session`
- **Catalog & APIs:** `saavn_play`, `dart_des`, `http`
- **State Management:** `provider`
- **Local Persistence:** `shared_preferences`
- **Image Caching:** `cached_network_image`

---

## 🧪 Testing

Run the test suite:
```bash
flutter test
```

---

## 📄 License

This project is licensed for personal and educational use.
