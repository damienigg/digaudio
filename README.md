# digaudio

<p align="center">
  <img src="assets/icon/digaudio_icon.png" alt="digaudio" width="160"/>
</p>

A lightweight, fast, free music player for Android — built for people who
own their library and care about how it sounds.

Streams from any [Subsonic](http://www.subsonic.org/)-compatible server
(Navidrome / Airsonic / Gonic / OpenSubsonic / …), plays the music already on
the device, and stays out of your way. No proprietary services. No telemetry.
No ads. GPL-3.0.

[![Latest release](https://img.shields.io/github/v/release/damienigg/digaudio?logo=github&style=flat-square)](https://github.com/damienigg/digaudio/releases/latest)
[![Build](https://img.shields.io/github/actions/workflow/status/damienigg/digaudio/build-android.yml?branch=main&style=flat-square&label=APK%20build)](https://github.com/damienigg/digaudio/actions/workflows/build-android.yml)
[![License](https://img.shields.io/badge/license-GPL--3.0-blue?style=flat-square)](LICENSE)

## What it does

- **Subsonic streaming** — browse, search, queue and stream from any
  Subsonic / OpenSubsonic server. Multi-server support: register as many as
  you want, one active at a time. A default server URL can be baked into the
  build (see `tool/run.example.sh`); only the URL — credentials always come
  from the user.
- **Local library** — your device's `MediaStore` queried via a native Kotlin
  channel we own outright (no dead third-party plugin in the dependency tree).
- **High-quality formats** — FLAC, MP3, AAC, OGG/Vorbis, Opus, WAV, ALAC,
  decoded natively by ExoPlayer. Subsonic streams are requested **without
  transcoding**, so 3 Mbps FLAC arrives lossless on the wire.
- **Background playback** with lockscreen / MediaSession / Bluetooth /
  headphone controls. Android Auto compatible.
- **Offline downloads** — cache any Subsonic track to local storage; the
  audio engine transparently prefers the cached file over re-streaming.
- **Unified search** across local and remote, normalized so accented titles
  and casing differences still match.
- **Editable local playlists** — create, reorder (drag), remove (swipe),
  rename, delete, export to a portable JSON format (`digaudio.playlist.v1`)
  via the OS share sheet.
- **Playlist import** from `.m3u` / `.m3u8` / digaudio JSON. Each entry is
  matched against the local library first and then your active Subsonic
  server (`search3`) with diacritic/punctuation folding. Unmatched rows are
  preserved as **greyed-out "missing" placeholders** with a one-tap **Add to
  wishlist** action.
- **Favorites** — heart toggle on every track tile, drift-watched reactive
  count, dedicated `/favorites` view.
- **Wishlist** — local list of tracks/albums you'd like to add to a server.
  (Lidarr `POST /api/v1/album/lookup → /api/v1/album` integration is wired
  in `lib/library/wishlist.dart` but not exposed in the UI yet.)
- **Equalizer** (Android) — native `AndroidEqualizer` attached to the
  `just_audio` pipeline. Toggle + per-band sliders, "Flat" reset, settings
  persist across launches. Bands are read from the OS at runtime — no
  assumptions on band count or center frequencies.
- **Similarity-based suggestions** — one metadata-only algorithm (artist +10,
  album +5, genre +6, year ±5 +3, duration ±60 s +1) powers both:
  - the "Suggested next" snackbar after adding a track to favorites / a
    playlist,
  - the **auto-queue continuation** that appends a similar track when the
    playback queue is about to run out.
- **Full library candidate pool** — a per-server SQLite cache of every song
  on the active Subsonic server is built once via paginated `getAlbumList2`
  + `getAlbum`. AutoQueue scores against the whole library, not a random
  sample. Re-sync on demand from Settings → Playback.
- **Dark, content-first UI** inspired by Spotify / Symfonium — artwork-led,
  one vivid accent (`#1ED760`), minimal chrome, persistent mini-player
  above the bottom nav.

## How it picks the next song

When the playback queue is about to end and AutoQueue is on (default), the
engine seeds the last-played track into a single metadata scorer:

```
score(seed, candidate) =
    +10 if same artist
    +5  if same album
    +6  if same genre
    +3  if |year_seed - year_cand| <= 5
    +1  if |duration_seed - duration_cand| <= 60 s
```

The candidate pool is **all your local songs + the entire cached Subsonic
library for the active server** (built once via `Settings → Playback → Sync
library`, then memoized in-process). Highest-scoring track that isn't already
in the queue is appended. The exact same call powers the "Suggested next"
hint after favorite / playlist adds — consistent behavior across surfaces by
design.

## Install (Android)

The easy path: grab the latest APK from the
[**Releases page**](https://github.com/damienigg/digaudio/releases/latest).
Every `v*.*.*` tag triggers a CI build (`.github/workflows/build-android.yml`)
that publishes the APK as a release asset. Sideload it on your phone — Android
will warn "unknown source" because the APK is signed with the debug keystore
(fine for personal use; a proper release keystore is a one-line build.gradle
change + a secret).

To build locally instead:

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs    # drift codegen
./tool/run.sh build                                         # APK with the
                                                            # baked-in default
                                                            # server URL
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

`tool/run.example.sh` shows the `--dart-define` pattern; copy to
`tool/run.sh` (gitignored) and put your own URL there.

## Build & run from source

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
flutter run    # → connected device
```

Requirements: Flutter 3.24+ (Dart 3.5+), Android SDK 35, JDK 17.
`minSdk = 29` (Android 10+).

## CI

```
.github/workflows/build-android.yml
```

Triggers on push to `main`, on `v*.*.*` tag pushes, and on manual
`workflow_dispatch`. Builds a release APK with `SUBSONIC_URL` /
`SUBSONIC_LABEL` injected from repo secrets via `--dart-define`. Uploads the
APK as a 90-day workflow artifact, and on tag pushes also publishes a GitHub
Release with the APK attached. A `concurrency` block keyed by commit SHA
deduplicates the simultaneous `main` + tag triggers so you only ever pay for
one build per release.

## Project layout

```
lib/
├── main.dart                  # bootstrap + just_audio_background.init
├── app.dart                   # MaterialApp + theme + router + warm-up
├── theme.dart                 # dark Spotify-inspired theme
├── router.dart                # go_router (bottom-nav shell + detail routes)
├── domain.dart                # Track / Album / Artist / Playlist /
│                              # PlaylistEntry sealed type
├── core/
│   ├── db.dart                # drift database (schema v3)
│   ├── settings.dart          # multi-server config + Keystore-backed creds
│   └── playback_prefs.dart    # EQ + auto-queue persisted prefs
├── subsonic/client.dart       # Subsonic API client (salt+token auth)
├── library/
│   ├── local.dart             # local library via our own MediaStore channel
│   ├── downloads.dart         # offline cache manager
│   ├── collections.dart       # Favorites + LocalPlaylists + TrackResolver
│   ├── similarity.dart        # metadata-based scoring
│   ├── auto_queue.dart        # appends a similar track at queue end
│   ├── subsonic_cache.dart    # per-server full library index (drift)
│   ├── importer.dart          # M3U / digaudio JSON → playlist + missing
│   └── wishlist.dart          # wishlist CRUD + Lidarr hook (stub)
├── audio/
│   ├── player.dart            # AudioEngine (just_audio + AndroidEqualizer)
│   └── providers.dart         # central Riverpod wiring
└── ui/                        # screens + widgets
android/app/src/main/kotlin/com/digaudio/digaudio/
├── MainActivity.kt            # extends AudioServiceActivity (cached engine)
└── MediaStoreChannel.kt       # native MediaStore queries
tool/
├── make_icon.py               # launcher icon source (PIL)
├── probe_subsonic.dart        # standalone Subsonic ping / browse test
└── run.example.sh             # local build wrapper template (--dart-define)
```

## Where things live on the device

- **Server credentials** — Android Keystore via `flutter_secure_storage`.
- **EQ settings, AutoQueue toggle** — `SharedPreferences`.
- **Favorites, playlists, missing-track placeholders, wishlist, offline
  downloads index, Subsonic library cache** — SQLite via drift, in
  `<app docs>/digaudio.sqlite`.
- **Downloaded audio files** — `<app docs>/downloads/`.

Uninstalling the app wipes all of this (standard Android behavior); no
data lives outside the app sandbox.

## Founding principles

[`CLAUDE.md`](CLAUDE.md), non-negotiable for any change:

1. **Lightweight, never redundant.** Any logic appearing ≥2 times becomes a
   function.
2. **Minimum lines for a valid result.** Shortest correct solution wins.
3. **Fix the root cause, never the symptoms.** No `try/except` that masks,
   no build-system workarounds for broken plugins — fix the actual cause.

## License

[GPL-3.0](LICENSE).
