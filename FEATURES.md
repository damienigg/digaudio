# Features — digaudio (v1.0.0)

What's shipped, where to find it. Each row gives the entry point + a one-line description. `TEST_PLAN.md` covers acceptance tests.

**Release status (2026-06-01)**: **v1.0.0 released**. The 0.30.x line closed out with the dynamic accent tint (every UI surface follows the cover), 5-star ratings (TrackTile star + Library Rated tab + smart-playlist filter), Stats v2 (Top Genres / Top Albums + sub-100 ms load via batch resolve), a Library Genres tab served by the live Subsonic `getGenres` endpoint (Navidrome's `getAlbum` returns `genres: []` per child), the back-arrow keyboard fix and the smart-playlist router bug. Post-1.0, **i18n FR** is the only open optional polish — pursued only if explicitly requested.

---

## Audio engine

- **just_audio** + custom `BaseAudioHandler` (audio_service) — single source of truth for playback state.
- **Two-player crossfade engine** (v0.18.0): `_primary` audible + `_secondary` preloaded; true overlap fades between tracks when `crossfadeMs > 0`, instant gapless swap when `crossfadeMs == 0`.
- Origin-agnostic queue: local + Subsonic mix freely (per-track `serverId` since v0.27.0).
- MediaSession surface: lockscreen, notification, Bluetooth, Android Auto — all driven by the same handler.
- **Per-track resume position** (v0.16.1) — saves every ~5 s; re-play seeks to saved position once duration is known.
- **Replay Gain** (v0.17.2) — applies per-track attenuation from OpenSubsonic's `replayGain.{track,album}Gain`. No boost (caps at 1.0).
- **Equalizer**: 5-band Android EQ + 6 presets (Flat / Rock / Jazz / Vocal / Bass boost / Treble boost, v0.17.0) + **per-Bluetooth-device override** (v0.17.3).
- **Audio routing info line** (v0.29.0) — under the artist on Now Playing: `FLAC · 24-bit/96 kHz · 938 kbps  →  USB: FiiO Q3 · 96 kHz`. Visual bit-transparency check: line goes amber + ⚠ when source sample rate ≠ system output mix rate (silent resampling detected). Source from OpenSubsonic `samplingRate`/`bitDepth`/`bitRate`/`contentType`; routing from `AudioInfoChannel` (hardware priority: USB > BT A2DP > wired > built-in).

## Audio sources

- **Local MediaStore** via own Kotlin channel (`digaudio/media_store`).
- **Subsonic** (Navidrome, Gonic, Airsonic, Ampache, Nextcloud Music — all compatible).
- **Multi-server** — N Subsonic servers registered, one active (Settings → Servers).
- **Multi-server unified search** (v0.27.0) — Search fans out across all configured servers + local in parallel, results tagged "· <server>" when ≥2 servers configured; engine streams from the originating server (per-track `serverId` routing).

## Playback controls

| Feature | Where |
|---|---|
| Shuffle | Now Playing transport |
| Repeat off / one / all | Now Playing transport |
| Playback speed 0.5× → 2× | Now Playing AppBar |
| Sleep timer (5/15/30/45/60 min OR end-of-track) **+ 10 s fade-out** | Now Playing AppBar (bedtime) |
| Crossfade off / 2 / 5 / 10 s (true overlap) | Settings → Playback → Crossfade |
| Volume normalisation (Replay Gain) | Settings → Playback → Volume normalisation |
| Auto-play on BT connect | Settings → Playback (opt-in) |
| Album mode (stop after current album) | Now Playing AppBar (album) |
| Queue editor (drag-reorder + swipe-remove) | Now Playing → Queue tab |
| Auto-queue (similar-track append, lookahead 3, Last.fm boost) | Settings → Playback → Auto-queue toggle |

## Storage & cache (unified pool, LRU evict)

| Feature | Where |
|---|---|
| Auto-cache on play | Settings → Playback → Storage |
| Cache budget 512 MB → 20 GB | Same |
| Current usage + clear button | Same |
| Pinned downloads (never evicted) | Track sheet → "Download for offline" |
| Promote auto-cached → pinned | Track sheet → "Keep download" |
| Remove a download | Track sheet → "Remove download" |
| Cache state badge (✓ green = pinned, ✓ grey = cached) | Track tile next to title |

### Background download queue (v0.22.2)

- `DownloadQueueService` wraps `DownloadsManager`. `enqueue(t)` / `enqueueAll(tracks)` — concurrency 1 (one server's bandwidth saturates anyway).
- **DownloadBanner** above mini-player when active — current track + queued count + live progress bar + Cancel (clears pending; in-flight finishes).
- Per-track "Download for offline" routes through the queue (`Queued "X"` toast).
- **Bulk Download** via the SelectionBar — filters non-Subsonic tracks silently. Pair with long-press → select-album → Download for one-tap album pin.

## Library browsing

| Feature | Where |
|---|---|
| Home (newest releases + **recently played** + random + brand hero) | Home tab |
| **Search** — FTS-first (instant, accent-insensitive, prefix-AND) + remote merge | Search tab |
| **Voice search** — mic icon in Search AppBar → system speech recogniser → injects text + searches | Search tab — v0.26.0 |
| **Multi-server results** — fan-out across all configured servers + local; per-row " · <server>" label when ≥2 servers | Search tab — v0.27.0 |
| Tracks / Albums / Artists / Genres / Decades / Playlists | Library tab — 6 sub-tabs |
| Alphabetical quick-scroll | Library → Artists |
| Genre / Decade pages with Play all + Shuffle | Library → Genres / Decades → tap |
| Artist page (discography) | Tap any artist |
| Album page (tracklist + play) | Tap any album |
| Subsonic playlists | Library → Playlists |
| Local playlists (editable, reorderable, exportable JSON) | Library → Playlists |
| Import playlist (M3U / M3U8 / digaudio JSON) | Library → Playlists → "Import playlist…" |
| Favourites | Library → Playlists → Favorites |
| Wishlist (local-only) | Library → Playlists → Wishlist |
| Stats page | Library → Playlists → Stats |
| **Smart playlists v2** (rules: genre / year / artist / album / title / duration / favourite / pinned / cached / playCount30d / playCountAll / lastPlayedDaysAgo) | Library → Playlists → "Smart playlists" |
| 4 builtin smart mixes seeded first run | All time random / 80s / 90s / Recent |

## Track-level actions

Long-press any tile = enter multi-select mode. Tap ⋮ on a tile = open the action sheet.

| Action | Where |
|---|---|
| Add / remove favourite | ⋮ on tile, **OR** heart icon on Now Playing |
| 5-star rating (Subsonic, server-synced) | ⋮ → 5-star row |
| Add to playlist | ⋮ → "Add to playlist…", or bulk via select bar |
| Play next | ⋮ → "Play next", or bulk |
| Add to queue | ⋮ → "Add to queue", or bulk |
| Download / pin / remove | ⋮ → contextual label |
| **Start radio** (Subsonic, endless auto-refilling) | ⋮ → "Start radio" |

## Bulk select (v0.16.3, polished v0.21.2)

- Long-press any tile → enters multi-select mode (tile leading swaps to a 36 dp check-circle in v0.21.2).
- Tap (in mode) = toggle. Tap (out of mode) = play.
- SelectionBar above the mini-player: **Play** (replace queue) · Add to queue · Play next · Add to playlist · Add to favourites · X cancel.
- Selection is **global** — long-press in Library, navigate to Search, add more, act on the union.

## Recommendation engine

1. **Metadata score** (artist +10, album +5, genre +6, year ±5 +3, duration ±60 s +1)
2. **Last.fm `track.getSimilar` ranker** (+12 max if `LASTFM_API_KEY` secret set; gracefully omitted otherwise)
3. **Subsonic radio** (server-side `getSimilarSongs2`, **endless auto-refill** in v0.21.1)
4. **Smart playlists v2** (rules-based materialisation with joins on plays / favourites / downloads)
5. **Library FTS** (v0.19.0) — drift FTS5 virtual table, accent-insensitive, prefix-AND; Search page is FTS-first + Subsonic search3 in parallel, merged & deduped
6. Auto-queue lookahead 3 tracks ahead, chains off the last track in queue
7. "Suggested next" hint after favoriting

## Now Playing

| Feature | Where |
|---|---|
| Full-screen artwork | Player tab |
| **Colour tint background** (dominant artwork colour gradient) | Player tab — Settings toggle to disable |
| Title + artist + heart toggle | Below artwork |
| **Audio routing info line** (codec / bit-depth / sample-rate / bitrate → device / output rate) | Under the artist — v0.29.0 |
| Position scrubber + duration | Below title |
| Transport (shuffle / prev / play/pause / next / repeat) | Below scrubber |
| **Up Next inline strip** (next 3 tracks, tap to jump) | Below transport |
| Album mode + Speed + Sleep timer actions | AppBar |
| Active queue (editable: drag + swipe) | Queue tab |
| Lyrics — synced via OpenSubsonic, plain fallback, active-line highlight + auto-scroll | Lyrics tab |
| **Share track** (system share sheet, text card) | Now Playing AppBar — v0.24.0 |

## Stats

| Feature | Where |
|---|---|
| Time-window picker (30 d / 90 d / all time) | Stats page top |
| Totals (plays / unique tracks / listening days) | Stats header |
| Current + longest streak | Two flame chips |
| Year-grid heatmap (365 days, GitHub style) | Below totals |
| **On this day** (same MM-DD in prior years) | With "Play all" button |
| "Most played" smart mix | Plays top 50 in window |
| Top 10 tracks + Top 10 artists (window) | Lists |
| **Year-by-year tops** (top 5 per year) | Bottom of stats |
| Monthly tops (last 12 months, top 3 each) | Bottom of stats |

## MediaSession surfaces

| Where | Status |
|---|---|
| Lockscreen artwork + transport | ✓ via audio_service |
| Notification + transport | ✓ via audio_service |
| **Notification rich actions** (skip 10 s back / forward) | ✓ v0.23.1 |
| Bluetooth controls | ✓ |
| **Quick Settings tile** (Android system shade) | ✓ v0.20.0 — user drags it in once |
| **Homescreen widget** (mini-player, 4×1 cell **with artwork**) | ✓ v0.25.0 + artwork v0.28.0 — long-press homescreen → Widgets → drag "digaudio" |
| **Wear OS** (transport on the wrist) | ✓ free — Wear OS 3+ mirrors the active phone MediaSession to the watch's Media Controls tile. No companion APK needed; just enable "Media Controls" tile on the watch |
| Android Auto browsable tree (Favourites / Recently played / Most played) | ✓ (untested on real head unit) |
| Headphone-removal auto-pause | ✓ free via `audio_session.music` |
| Auto-play on BT connect | ✓ v0.20.1 (opt-in toggle) |

## Scrobbling & external services

Three independent scrobble paths fire in parallel — counts stay aligned because all three use the same Last.fm-style threshold (≥ 4 min OR ≥ 50 % of duration, whichever is shorter).

| Path | Trigger | Where to enable |
|---|---|---|
| **Subsonic server scrobble** | track start (`submission=false`) + threshold (`submission=true`) | Automatic when the active server has a configured scrobble integration |
| **ListenBrainz direct** (v0.24.1) | `playing_now` at start + `single` at threshold | Settings → Playback → ListenBrainz card — paste user token from `listenbrainz.org/profile/` → "User token" |
| **Last.fm direct** (v0.30.0) | `track.updateNowPlaying` at start + `track.scrobble` at threshold | Settings → Playback → Last.fm card — tap "Connect Last.fm" → approve in browser → tap Finish. Required because Navidrome's Last.fm integration is metadata-only (it does NOT forward listens). Build needs `LASTFM_API_KEY` + `LASTFM_SHARED_SECRET` dart-defines; without them the card greys out with an inline explanation. |

## Server features

- Subsonic salt+token auth (no plain-text passwords on wire).
- Server reachability ping (every 60 s) → offline banner above mini-player.
- Subsonic library cache (drift): full song-level metadata for autoqueue scoring + Genre/Decade browsers + smart playlists + FTS.
- **Cache auto-refresh** (v0.22.0) — Settings → Playback → Subsonic library cache → Auto-refresh dropdown (Off / Daily / 3 d / Weekly / 2 wk / Monthly). On boot if older than threshold + already-synced, background rebuild kicks off.
- **Admin library scan** (v0.28.0) — Settings → Servers → Edit → "Trigger scan" / "Check status". Admin-only endpoint; non-admin users see "Admin role required" inline. Shows live `scanning…` count then idle `N songs`.

## Theme & UI

- Dark theme (default, Spotify-inspired).
- Light theme (system / dark / light picker in Settings → Display); 87 `Colors.white*` literals migrated to theme-aware aliases (v0.12.0).
- **Material You** (v0.20.1) — Settings → Display → "Use system colours"; Android 12+ pulls the wallpaper palette.
- Brand accent `#1ED760` everywhere.
- Custom launcher icon (golden shovel + "DIG" + music notes, v0.12.3).
- Bottom-nav shell (Home / Search / Library) + persistent mini-player.
- Offline banner + **Download banner** + Selection bar appear conditionally above the mini-player.
- **Accessibility** (v0.23.2): tooltips on every IconButton; alpha-scroll letter strip + year heatmap wrapped with `Semantics` for TalkBack.

## Build & release

- GitHub Actions CI on push to `main` + `v*` tags.
- APK artifact (90-day retention) on every push.
- Auto-published GitHub Release on tag.
- Concurrency dedup by SHA.

### Optional GitHub repo secrets

| Secret | Effect when set |
|---|---|
| `SUBSONIC_URL` + `SUBSONIC_LABEL` | Bakes the active-server URL + label into the build (first-run onboarding can skip server entry) |
| `KEYSTORE_BASE64` + `KEYSTORE_PASSWORD` + `KEY_PASSWORD` + `KEY_ALIAS` | Release-signed APKs (no "unknown source" install warning) |
| `LASTFM_API_KEY` | Activates the autoqueue Last.fm ranker (`track.getSimilar`) |
| `LASTFM_SHARED_SECRET` (v0.30.0) | Together with `LASTFM_API_KEY`, unlocks the direct scrobble path (Settings → Playback → Last.fm card) |

Without any of these, CI still builds a working debug-signed APK with no functional regression — every feature gated by a missing secret degrades gracefully.

## Database schema (drift v8)

| Table | Version | Purpose |
|---|---|---|
| Downloads | v4 — adds `pinned`, `lastAccessedAt` | Unified storage pool |
| Favorites | v1 | Binary favourites mirror |
| LocalPlaylists / LocalPlaylistTracks | v1 | User playlists |
| RecentPlays | v5 — autoincrement id | Append-only play log |
| MissingTracks / Wishlist | v2 | Import placeholders + wishlist |
| CachedSubsonicSongs | v3 | Full Subsonic library cache |
| **SmartPlaylists** | v6 | Rules-based playlist JSON |
| **TrackPositions** | v7 | Per-track resume |
| **cached_subsonic_songs_fts** | v8 (virtual) | FTS5 index over the library cache |
