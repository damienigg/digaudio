# Changelog

All notable changes to **digaudio** are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.7.0] — 2026-05-24

User-facing controls for the two features that previously had no UI:
auto-queue continuation and per-track offline downloads.

### Added
- **Auto-queue toggle** (`Settings → Playback`) — switch to disable the
  similarity-based auto-append at the end of the playback queue.
  `PlaybackPrefs.autoQueueEnabled` persists across launches (default ON).
  Restored at app startup and pushed straight into `AutoQueueService`.
- **Download for offline / Remove download** action in the track actions
  sheet (only shown for Subsonic-origin tracks). Streams the track to the
  app docs dir, records it in the `Downloads` drift table, and the audio
  engine transparently prefers the cached file over re-streaming.

### Notes
- Download progress is surfaced as a sticky snackbar that switches to a
  completion / failure snackbar at the end. Per-track progress percentage
  isn't shown live; that can wire to `DownloadsManager.progressStream` in
  a future commit when it's worth the noise.
- A "downloaded" badge on the track tile isn't shown yet — the sheet
  reflects the current cache state when opened, which is enough for now.

## [0.6.0] — 2026-05-24

CI: GitHub Actions builds and releases the Android APK automatically.

### Added
- **`.github/workflows/build-android.yml`** — runs on every push to `main`
  and on every `v*.*.*` tag, plus a manual `workflow_dispatch` trigger:
  - Set up JDK 17, Flutter 3.24.5, cached pub + gradle.
  - `flutter pub get`, drift codegen, `flutter analyze`.
  - `flutter build apk --release` with the default server URL injected
    from repo secrets (`SUBSONIC_URL`, optional `SUBSONIC_LABEL`) via
    `--dart-define` — same mechanism as the local `tool/run.sh`.
  - Uploads the APK as a workflow artifact (90 d retention).
  - On tag pushes (`v*.*.*`), publishes a **GitHub Release** with the APK
    attached and auto-generated release notes — public download URL.

### Notes
- Repository secrets `SUBSONIC_URL` and `SUBSONIC_LABEL` configure the
  baked-in default server; when unset, the build still succeeds but ships
  with no pre-registered server (user adds one manually).
- Release APKs are signed with the debug keystore for now (Flutter's
  scaffolded default in `android/app/build.gradle`). Android will warn
  "unknown source" on first install — fine for personal sideloading.
  Switching to a proper release keystore is a one-line `build.gradle`
  change + a base64-encoded keystore in a secret when needed.

## [0.5.1] — 2026-05-24

Custom launcher icon — visual pun on "DIG" audio.

### Added
- **Brand icon**: tilted green music-note head with **DIG** overlaid in
  bold white, an eighth-note flag for clarity, and a metal handle ending
  in a spade-shaped blade. One centered vertical figure so the silhouette
  reads even at 48 px.
- **`tool/make_icon.py`** — PIL-based generator (no rsvg / ImageMagick
  required) that emits both the full icon and a transparent-background
  foreground for Android adaptive icons. Re-run on any design change.
- **`flutter_launcher_icons`** dev dep + pubspec config block; generates
  all `mipmap-*` and iOS `AppIcon` assets from a single 1024 px source.

## [0.5.0] — 2026-05-24

Playlist import (from external apps) + wishlist for tracks you don't have yet.

### Added
- **Playlist import** (`Library → Import playlist…`) reads M3U / M3U8 and
  digaudio JSON, matches each entry against the local library first and
  then the active Subsonic server's `search3`. Each match is normalized
  (lowercase, diacritic fold, punctuation stripped) so "Café del Mar" and
  "cafe del mar" collide. Unmatched rows are recorded as **missing
  entries** with a sentinel key (`missing:<uuid>`) — they appear in the
  playlist as **greyed-out tiles** with a `cloud_off` icon and a
  bookmark-add action to push them straight onto the wishlist.
- **Wishlist** (`/wishlist`): drift-backed list of tracks/albums you want
  on a server. Add manually via FAB, add from any missing playlist entry
  in one tap, swipe to remove. Lidarr integration is **deferred** with a
  documented hook point in `lib/library/wishlist.dart` (POST
  `/api/v1/album/lookup` then `/api/v1/album` on `add(...)`).
- **`PlaylistEntry` sealed type** (`TrackEntry` | `MissingEntry`) so
  playlist UI handles mixed contents without branching everywhere.
- **`MissingTracks` table** (sentinel-key approach — no costly recreation
  of `LocalPlaylistTracks` to add nullable columns).
- **`Wishlist` table** with `requestedAt` for ordering and an optional
  `notes` field reserved for the Lidarr album id once that ships.
- **drift schema v2** with a clean `onUpgrade` migration (creates the two
  new tables; existing data untouched).
- **`file_picker` dep** to open M3U / JSON files from device storage.

### Changed
- `TrackResolver` gains `resolveEntries(keys)` returning mixed
  `PlaylistEntry` (used by the playlist detail view); the existing
  `resolveAll(keys)` still returns `Track` only for play-all flows.
- Library page Playlists tab gains: `Wishlist` tile, `Import playlist…`
  entry, the existing Favorites / Local / Subsonic sections unchanged.

### Notes
- Spotify CSV and Apple Music exports aren't auto-detected yet — the M3U
  path covers most exports out of common third-party tools; native
  formats can be added with a single parser each.

## [0.4.0] — 2026-05-24

Favorites, editable local playlists, metadata-based similarity engine, and
auto-queue continuation.

### Added
- **Favorites** — heart icon in the track actions sheet; reactive across
  the UI (drift `watchKeys`). Dedicated `/favorites` view, accessible from
  the Library tab.
- **Local playlists** — create / rename / delete; add tracks via the track
  actions sheet (long-press or "…" → "Add to playlist"). Detail view at
  `/playlist/local/:id` with drag-to-reorder, swipe-to-remove, and
  play-all.
- **Playlist export** — JSON (`digaudio.playlist.v1`) shared via the OS
  share sheet (`share_plus`). Track origin is preserved; no credentials or
  Subsonic stream URLs are written.
- **`Similarity` service** — single metadata-based scoring algorithm
  (artist +10, album +5, genre +6, year ±5 +3, duration ±60 s +1) used for:
  - the "Suggested next" hint shown after adding a track to favorites or a
    playlist,
  - the auto-queue (see below).
- **`AutoQueueService`** — when the playback queue is about to run out,
  appends a similar track from the library (local songs + a cached
  Subsonic random sample of 200). Same scoring as the suggestion hint, so
  both surfaces behave consistently.
- **`genre` field** on `Track` (parsed from Subsonic responses) — feeds
  into the similarity score.
- **Subsonic `getSong(id)`** and **`LocalLibrary.getSongById(id)`** —
  resolve stored track keys (`origin:id`) back to full `Track` objects on
  playlist / favorites load.

### Changed
- Track tile shows a small heart marker next to favorites; the trailing
  "…" button and long-press both open the actions sheet.
- Library / Playlists tab gains sections: **Favorites** (with live count),
  **Local playlists**, **Subsonic playlists**.

### Notes
- Subsonic candidate pool for the similarity algorithm is capped at 200
  random songs to keep the per-launch fetch cheap. The server's
  `getSimilarSongs2` endpoint is a planned enhancement to deepen the pool
  for Subsonic-origin seeds.
- Local tracks have no `genre` for now (Android MediaStore exposes it via
  a separate `audio_genres` join that's costly per-song; deferred).

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
