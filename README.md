# digaudio

A lightweight, modern, high-quality music player for Android and iOS — for
people who care about sound and own their library.

Streams from any [Subsonic](http://www.subsonic.org/)-compatible server
(Navidrome / Airsonic / Gonic / …) and plays the music already on the device.
No proprietary services. No telemetry. Free as in freedom.

## Status

Version **0.1.0** — first runnable build. The app launches on Android and the
core UI is in place. The Subsonic client, audio engine, local library and
download infrastructure are wired up; end-to-end testing against a real
Subsonic server is the next step. iOS code is compatible but not yet built
(building iOS requires macOS).

See [`CHANGELOG.md`](CHANGELOG.md) for what shipped.

## Features

- **Subsonic streaming** — browse, search, queue and stream from any Subsonic
  / OpenSubsonic-compatible server.
- **Local library** — your own MediaStore queried natively, no third-party
  dependency.
- **High-quality formats** — FLAC, MP3, AAC, OGG/Vorbis, Opus, WAV, ALAC
  (decoded natively via ExoPlayer on Android, AVPlayer on iOS).
- **Background playback** with lockscreen / MediaSession controls, Android
  Auto and CarPlay compatible.
- **Offline downloads** — cache any Subsonic track for offline listening; the
  player transparently prefers the local copy.
- **Unified search** across local + remote sources.
- **Lyrics** (unsynced via Subsonic `getLyrics`; synced support planned).
- **Dark, content-first UI** inspired by Spotify and Symfonium — artwork-led,
  one vivid accent, minimal chrome.
- **Free** — GPL-3.0, no tracking, no ads.

## Requirements

- **Flutter** 3.24+ (Dart 3.5+)
- **Android** — `minSdk 29` (Android 10+), `compileSdk 35`. Tested.
- **iOS** — deployment target 12+. Code is iOS-compatible; building requires
  macOS + Xcode (CI or local Mac).

## Build & run

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs    # drift codegen
flutter build apk --debug                                   # Android APK
flutter install                                             # → connected device / emulator
```

To run against a live device or emulator:

```bash
flutter run
```

## Project layout

```
lib/
├── main.dart              # bootstrap + just_audio_background.init
├── app.dart               # MaterialApp + theme + router
├── theme.dart             # dark Spotify-inspired theme
├── router.dart            # go_router (bottom-nav shell + detail routes)
├── domain.dart            # source-agnostic Track/Album/Artist/Playlist
├── core/
│   ├── db.dart            # drift database (Downloads, Favorites, …)
│   └── settings.dart      # secure Subsonic credential storage
├── subsonic/client.dart   # Subsonic API client (salt+token auth)
├── library/
│   ├── local.dart         # local library via our own MediaStore channel
│   └── downloads.dart     # offline cache manager
├── audio/
│   ├── player.dart        # AudioEngine (just_audio + just_audio_background)
│   └── providers.dart     # central Riverpod wiring
└── ui/                    # screens + widgets
android/app/src/main/kotlin/com/digaudio/digaudio/
├── MainActivity.kt        # extends AudioServiceActivity (cached engine)
└── MediaStoreChannel.kt   # native MediaStore queries (getAllSongs, getArtwork)
```

## Founding principles

Documented in [`CLAUDE.md`](CLAUDE.md) — non-negotiable for any change:

1. **Lightweight, never redundant.** Any logic appearing ≥2 times becomes a
   function.
2. **Minimum lines for a valid result.** Shortest correct solution wins.
3. **Fix the root cause, never the symptoms.** No `try/except` that masks, no
   build-system workarounds for broken plugins — fix the actual cause.

## License

[GPL-3.0](LICENSE).
