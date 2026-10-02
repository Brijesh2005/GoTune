# GoTune 🎵

A personal, modern dark music streaming application built with **Flutter**, featuring a high-performance, lightweight **YouTube-centered architecture** powered by the official embedded **YouTube IFrame Player**.

---

## ✨ Features

- **YouTube Music & Video Catalog:**
  - YouTube search with instant results and automatic deduplication.
  - Built-in curated playlists and category discovery.
  - Video title and artist normalization with smart recommendations.
- **Embedded YouTube IFrame Playback:**
  - Official YouTube IFrame Player integration via `webview_flutter`.
  - Full player controls: Play, Pause, Seek, Duration, and Buffering indicators.
  - Smart queue management (Next up, reorder, auto-advance).
  - Repeat modes (Off / One / All) & Shuffle.
  - Sleep timer with countdown notifications.
- **Personal Library & Offline Persistence:**
  - Favorites and recently played track history persisted via `shared_preferences`.
  - Custom playlists creation and management.
- **Aesthetic Dark UI:**
  - Glassmorphic accents, animated equalizers, high-resolution album/video thumbnails.
  - Mini player and immersive full-screen Now Playing view.

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
   Or build architecture-split APKs:
   ```bash
   flutter build apk --split-per-abi
   ```

---

## 🛠️ Tech Stack & Architecture

- **Framework:** Flutter / Dart
- **Playback Engine:** Official YouTube IFrame Player API (`webview_flutter`)
- **Networking & API:** `http`
- **State Management:** `provider`
- **Local Persistence:** `shared_preferences`
- **Image Caching:** `cached_network_image`

---

## 🧪 Testing

Run the test suite:
```bash
flutter test
```

Run static analysis:
```bash
flutter analyze
```

---

## ⚠️ Policy & Disclaimer

GoTune operates strictly through the official embedded YouTube IFrame Player. It does not extract direct audio streams, bypass DRM, download copyrighted content, or circumvent YouTube playback and advertising policies.
