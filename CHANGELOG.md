# Changelog

All notable changes to **digaudio** are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.9.2] — 2026-05-25

### Added (Substreamer parity — batch 2)
- **5-star ratings.** Track action sheet gains a row of 5 stars for
  Subsonic-origin tracks. Tap a star to set, tap the current rating to
  clear. Optimistic UI — the manager rolls the override back on network
  failure. Ratings sync to the server (`/rest/setRating.view`); local
  tracks don't show the row (Subsonic-only feature).
- **Quick-scroll alphabetical sidebar** on the Artists list (Library).
  Tap or drag the A→Z strip on the right to jump; empty letters
  gracefully degrade to the next populated one. Items use a fixed
  `itemExtent: 65` so the jump is O(1).

### Changed
- `Track` gains a nullable `userRating` (1–5) field; populated by the
  Subsonic parser. Local tracks always null.

### Internal
- `lib/library/ratings.dart` — `RatingsManager` with in-memory overrides
  + change stream (no SQLite mirror; the server response is
  authoritative on next fetch).
- `lib/ui/widgets/alpha_scroll.dart` — reusable `AlphaScrollList<T>`.
  Apply to any list that's long enough to need scanning.

## [0.9.1] — 2026-05-25

### Added (Substreamer parity — batch 1)
- **Subsonic scrobble.** Every track playback fires a "now playing" hint
  at start (`submission=false`) and a definitive scrobble once the played
  duration crosses the Last.fm threshold (≥4 min OR ≥50 % of length,
  whichever is shorter). Origin-gated to Subsonic tracks; failures are
  swallowed so a flaky network never interrupts playback. Subsonic
  forwards to Last.fm / ListenBrainz server-side when configured.
- **Sleep timer.** Now Playing AppBar gains a bedtime button. Pick a
  fixed duration (5 / 15 / 30 / 45 / 60 min) — the icon shows a live
  countdown — or "Stop at end of current track" which arms on the
  player's own `completed` state. Cancellable from the same sheet.
- **Playback speed control.** AppBar action shows the current rate
  (`1.0x` ⇒ idle, anything else ⇒ green). Picker offers 0.5× → 2.0× in
  6 stops. Persisted in `PlaybackPrefs`, restored at startup.

### Internal
- `lib/audio/sleep_timer.dart` — `SleepTimerService` with two modes
  (duration / end-of-track) and two reactive streams
  (`remainingStream`, `endOfTrackActiveStream`).
- `playbackSpeedProvider` — `StateProvider<double>` mirror of the
  persisted speed, so the AppBar label rebuilds instantly on change.

## [0.9.0] — 2026-05-25

### Added
- **Auto-cache on play.** Every Subsonic stream is teed straight into the
  on-disk pool as it plays (via just_audio's `LockCachingAudioSource`), so
  the next listen is offline-instant — no separate download step, no
  doubled bandwidth (one network roundtrip serves both playback and the
  cache write). The pool is LRU-evicted under a user-configurable
  budget; pinned downloads are immune.
- **Unified storage model.** Explicit downloads and auto-cache live in the
  same on-disk pool: `pinned` distinguishes the two. Pinned rows are
  never evicted; everything else competes for space by `lastAccessedAt`.
- **Storage settings** (Settings → Playback → Storage). Toggle auto-cache,
  pick the budget (512 MB → 20 GB), watch current usage, clear the
  auto-cache without losing pinned downloads.
- **Cache badge on track tiles.** Green check = pinned. Grey check =
  auto-cached. None = not on disk yet.
- **Three-state download action** in the track sheet:
  uncached → "Download for offline" (fetch + pin);
  auto-cached → "Keep download" (pin existing file, no network);
  pinned → "Remove download".

### Changed
- **AudioEngine** constructor now takes `DownloadsManager` + `PlaybackPrefs`
  directly (was: two narrow callbacks). The wider surface is justified
  by source-build needing both the cache target path and the live
  auto-cache toggle; the narrower call sites went away with the cleanup.
- **App init order.** `DownloadsManager.hydrate()` and `PlaybackPrefs.load()`
  now complete *before* `AudioEngine.init()` — the engine reads cache
  paths and `autoCacheEnabled` at source-build time, so the earlier
  ordering was racy under fast first-play.

### Database
- **Schema v3 → v4.** `Downloads` gets `pinned BOOL` (default false) and
  `lastAccessedAt DATETIME`. Existing rows are migrated as
  `pinned = TRUE` to preserve user intent (every pre-v4 row came from an
  explicit user download).

## [0.8.3] — 2026-05-24

### Removed
- **`ios/` directory deleted.** Android is the supported target;
  carrying around the iOS scaffold (912 KB of Xcode project, plist,
  Swift bridging header, …) only added noise. The Dart code stays
  cross-platform-correct — an Apple-toolchain build would still work
  after `flutter create --platforms=ios .` to regenerate the scaffold —
  but it's not on the roadmap.
- iOS gates from `pubspec.yaml` (`flutter_launcher_icons.ios`,
  `remove_alpha_ios`), the iOS-block from `.gitignore`, and stale
  "iOS support is planned" UI notes in `Settings → Playback` and code
  comments.

## [0.8.2] — 2026-05-24

### Changed
- **New launcher icon** — golden shovel with embossed "DIG" on the blade
  (replaces the previous in-house PIL drawing). Source PNG in
  `assets/icon/digaudio_icon.png`; the script that built the prior icon
  (`tool/make_icon.py`) is removed.
- **`tool/make_adaptive_fg.py`** — small PIL script that scales the main
  icon to ~68% on a transparent canvas to produce the Android adaptive
  foreground (so launcher masks don't clip the shovel handle).

Workflow when updating the icon: drop a new
`assets/icon/digaudio_icon.png`, run `python3 tool/make_adaptive_fg.py`,
then `dart run flutter_launcher_icons` to regenerate every platform
asset.

## [0.8.1] — 2026-05-24

Documentation pass.

### Changed
- **README rewritten** to reflect the full feature surface as of v0.8.0
  (was last accurate at v0.1.0): multi-server, multi-format streaming,
  offline downloads, equalizer, favorites, playlists (editable + export +
  import + missing-entries), wishlist, similarity-based auto-queue +
  suggestions, full-library Subsonic cache, CI pipeline, where data lives
  on the device. Added build / release badges and the launcher icon.
- **iOS support removed** from advertised features. Pure-Dart code remains
  iOS-compatible, but Apple's toolchain lock-in means we're not investing
  in shipping an iOS build. Android-only is the supported target.

## [0.8.0] — 2026-05-24

Full Subsonic library cache (no more random sample), plus a CI fix for
the duplicate-build issue.

### Added
- **`CachedSubsonicSongs` table** (drift schema v3) — per-server slim
  metadata index of every song on the server, sized by what the
  similarity scorer needs (id, title, artist, album, year, duration,
  genre, coverArt). Multi-server scoped via `serverId`.
- **`SubsonicLibraryCache`** — `rebuild(client, serverId)` paginates
  `getAlbumList2` to enumerate every album, then `getAlbum(id)` per album
  to harvest songs, writing batches inside a single transaction.
  Reports progress per album so the UI can show a live bar; supports
  cancellation mid-sync.
- **Settings → Playback → "Subsonic library cache"** section: shows
  cached song count + last sync time for the active server, a
  Sync / Re-sync button, and a cancellable progress bar during sync.
- **`AutoQueueService` now scores against the FULL cached library** for
  the active server. Falls back to a 200-song random sample only when
  the cache is empty (graceful degradation before first sync). Pool
  invalidates automatically when the active server changes; manual
  `invalidatePool()` is called after every successful sync.

### Fixed
- **CI: duplicate-build on each release.** Pushing `main` then a `v*` tag
  fired the workflow twice for the same SHA. Added a `concurrency:` block
  keyed by `github.sha` with `cancel-in-progress: true` — the
  tag-triggered run cancels the just-started main run and a single build
  proceeds. main-only pushes (no tag) still build normally.

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
