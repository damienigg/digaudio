# Changelog

All notable changes to **digaudio** are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.3.0] — 2026-05-24

Equalizer (Android) + Settings restructured as a hub.

### Added
- **Android equalizer** wired through `just_audio`'s `AndroidEqualizer`
  (attached to the player's `AudioPipeline`). Engine exposes
  `setEqEnabled`, `applyEqGains`, `eqParameters`.
- **`PlaybackPrefs`** (in `lib/core/playback_prefs.dart`) persists the EQ
  enabled state and per-band gains (dB) via `shared_preferences`. Restored
  on app startup, written on every change.
- **`PlaybackPage`** (`/settings/playback`) — toggle the EQ, drag per-band
  gain sliders (band count and frequency range come from the device's
  reported parameters at runtime), and a "Flat" action to reset.
- **Settings hub** — `/settings` is now a two-tile navigator into
  `/settings/servers` (the existing list) and `/settings/playback`.

### Notes
- iOS equalizer support is **deferred** — would need `AVAudioUnitEQ` via a
  platform channel; tracked for a future commit.
- True crossfade (audio overlap between tracks) is **deferred** — would
  require running two players concurrently, which conflicts with
  `just_audio_background`'s single-player MediaSession integration. A
  follow-up commit will refactor onto `audio_service` directly when this
  becomes worth the architectural cost.

## [0.2.0] — 2026-05-24

Multi-server support and a baked-in default server URL.

### Added
- **Multi-server registry.** [`ServerConfig`] entries (id, label, url, user,
  password, builtin) live as a single JSON blob in secure storage. One server
  is "active" at a time; the audio engine streams from the active one.
- **`SettingsStore`** rewritten around `servers()` / `active()` / `upsert()` /
  `remove()` / `setActiveId()`.
- **Built-in default server URL** baked at build time via
  `--dart-define=SUBSONIC_URL=...` (+ optional `SUBSONIC_LABEL`). Seeded once
  on first launch. **No credentials are baked** — the user fills them in
  Settings on first use. See `tool/run.example.sh`.
- **Settings UI** is now a list of servers with active/configured indicators,
  built-in badge, add/edit/delete actions, and tap-to-activate.
- **`/settings/server/:id` route** for adding (`id == "new"`) and editing.
- **`tool/probe_subsonic.dart`** — standalone Dart probe that exercises the
  Subsonic client (ping + browse + random songs) without touching the UI.
  Useful for validating credentials end-to-end in the terminal.

### Changed
- `subsonicProvider` now derives from `activeServerProvider` (transparently —
  callers still get a nullable `SubsonicClient`).
- Bumped `pubspec.yaml` to `0.2.0+2`.

### Removed
- The single-server `serverConfigProvider` (replaced by
  `serversProvider` + `activeServerProvider`).

## [0.1.0] — 2026-05-24

First runnable build. Builds and launches on Android with full UI scaffolding
and core playback wiring in place. iOS code-compatible but not yet built (build
requires macOS).

### Added
- **Audio engine** on `just_audio` + `just_audio_background` — gapless
  playback, background, lockscreen / MediaSession / Android Auto / CarPlay
  controls.
- **Subsonic client** with salt+token auth (`ping`, `getAlbumList2`,
  `getRandomSongs`, `getArtists`, `getArtist`, `getAlbum`, `search3`,
  `getPlaylists`, `getPlaylist`, `getLyrics`, `getCoverArt`, `stream`).
- **Local library** via our own Kotlin `MethodChannel` (`digaudio/media_store`):
  `MediaStore` audio query + artwork via `ContentResolver.loadThumbnail` —
  zero third-party plugin dependency.
- **Source-agnostic domain model** (`Track` / `Album` / `Artist` / `Playlist`
  + `MediaOrigin`). The audio engine and UI never branch on origin.
- **Offline downloads** infrastructure (Subsonic → local cache, drift-backed
  index with sync in-memory lookup for the engine).
- **Drift (SQLite) database** for downloads, favorites, local playlists,
  recent plays.
- **Riverpod-based wiring** — one central `providers.dart` exposes the full
  graph (settings, server config, Subsonic client, engine, downloads,
  library, search, browse data).
- **Dark, content-first UI** inspired by Spotify / Symfonium with a single
  vivid accent (`#1ED760`).
- **App shell** with bottom navigation (Home / Search / Library) and a
  persistent mini player that opens the full Now Playing screen on tap.
- **Now Playing** screen with full-screen artwork, transport controls,
  shuffle / repeat, seek slider, queue tab, lyrics tab.
- **Album / Artist / Playlist** detail pages.
- **Unified search** across local + Subsonic.
- **Settings** screen with secure Subsonic credential storage
  (`flutter_secure_storage`), ping/test before save.
- GPL-3.0 licensed.

### Technical decisions
- **Replaced abandoned `on_audio_query` plugin** with our own MediaStore
  MethodChannel (~50 lines Kotlin + ~30 Dart). Eliminates the AGP 8 namespace
  build failure at the root and removes the dependency rot. See `CLAUDE.md`
  principle #3.
- **`minSdk = 29`** (Android 10+) — enables `ContentResolver.loadThumbnail`
  for artwork in one line, drops compatibility cruft.
- **`MainActivity extends AudioServiceActivity`** so the activity returns the
  cached `FlutterEngine` that `audio_service` expects (root cause of the
  startup `PlatformException` — fixed properly, not papered over).
