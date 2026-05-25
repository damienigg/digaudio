# Features — digaudio (v0.21.2)

What's shipped, where to find it. Each row gives the entry point + a one-line description. **TEST_PLAN.md** covers acceptance tests, **TODO.md** covers what's left.

---

## Audio engine

- **just_audio** + custom `BaseAudioHandler` (audio_service) — single source of truth for playback state.
- **Two-player crossfade engine** (v0.18.0): `_primary` audible + `_secondary` preloaded; true overlap fades between tracks when `crossfadeMs > 0`, instant gapless swap when `crossfadeMs == 0`.
- Origin-agnostic queue: local + Subsonic mix freely.
- MediaSession surface: lockscreen, notification, Bluetooth, Android Auto — all driven by the same handler.
- **Per-track resume position** (v0.16.1) — saves every ~5 s; re-play seeks to saved position once duration is known.
- **Replay Gain** (v0.17.2) — applies per-track attenuation from OpenSubsonic's `replayGain.{track,album}Gain`. No boost (caps at 1.0).
- **Equalizer**: 5-band Android EQ + 6 presets (Flat / Rock / Jazz / Vocal / Bass boost / Treble boost, v0.17.0) + **per-Bluetooth-device override** (v0.17.3).

## Audio sources

- **Local MediaStore** via own Kotlin channel (`digaudio/media_store`).
- **Subsonic** (Navidrome, Gonic, Airsonic, Ampache, Nextcloud Music — all compatible).
- **Multi-server** — N Subsonic servers registered, one active (Settings → Servers).

## Playback features

| Feature | Where |
|---|---|
| Shuffle | Now Playing transport |
| Repeat off / one / all | Now Playing transport |
| Playback speed 0.5× → 2× | Now Playing AppBar |
| Sleep timer (5/15/30/45/60 min OR end-of-track) | Now Playing AppBar (bedtime) |
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

## Library browsing

| Feature | Where |
|---|---|
| Home (newest releases + random + brand hero) | Home tab |
| **Search** — FTS-first (instant, accent-insensitive, prefix-AND) + remote merge | Search tab |
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

## Track-level actions (long-press = select mode; ⋮ = sheet)

| Action | Where |
|---|---|
| Add / remove favourite | ⋮ on tile, **OR** heart icon on Now Playing |
| 5-star rating (Subsonic, server-synced) | ⋮ → 5-star row |
| Add to playlist | ⋮ → "Add to playlist…", or bulk via select bar |
| Play next | ⋮ → "Play next", or bulk |
| Add to queue | ⋮ → "Add to queue", or bulk |
| Download / pin / remove | ⋮ → contextual label |
| **Start radio** (Subsonic, endless auto-refilling) | ⋮ → "Start radio" |

## Bulk select (v0.16.3)

- Long-press any tile → enters multi-select mode (tile leading swaps to a 36 dp check-circle in v0.21.2).
- Tap (in mode) = toggle. Tap (out of mode) = play.
- SelectionBar above the mini-player: **Play** (replace queue) · Add to queue · Play next · Add to playlist · Add to favourites · X cancel.
- Selection is **global** — long-press in Library, navigate to Search, add more, act on the union.

## Recommendation engine (combo 1 complete)

1. **Metadata score** (artist +10, album +5, genre +6, year ±5 +3, duration ±60 s +1)
2. **Last.fm `track.getSimilar` ranker** (+12 max if `LASTFM_API_KEY` secret set)
3. **Subsonic radio** (server-side `getSimilarSongs2`, **endless auto-refill** in v0.21.1)
4. **Smart playlists v2** (rules-based materialisation with joins on plays / favourites / downloads)
5. **Library FTS** (v0.19.0) — drift FTS5 virtual table, accent-insensitive, prefix-AND; Search page is FTS-first + Subsonic search3 in parallel, merged & deduped
6. Auto-queue lookahead 3 tracks ahead, chains off the last track in queue
7. "Suggested next" hint after favoriting

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

## Now Playing

| Feature | Where |
|---|---|
| Full-screen artwork | Player tab |
| **Colour tint background** (dominant artwork colour gradient) | Player tab — Settings toggle to disable |
| Title + artist + heart toggle | Below artwork |
| Position scrubber + duration | Below title |
| Transport (shuffle / prev / play/pause / next / repeat) | Below scrubber |
| **Up Next inline strip** (next 3 tracks, tap to jump) | Below transport |
| Album mode + Speed + Sleep timer actions | AppBar |
| Active queue (editable: drag + swipe) | Queue tab |
| Lyrics — synced via OpenSubsonic, plain fallback, active-line highlight + auto-scroll | Lyrics tab |

## MediaSession surfaces

| Where | Status |
|---|---|
| Lockscreen artwork + transport | ✓ via audio_service |
| Notification + transport | ✓ via audio_service |
| Bluetooth controls | ✓ |
| **Quick Settings tile** (Android system shade) | ✓ v0.20.0 — user drags it in once |
| Android Auto browsable tree (Favourites / Recently played / Most played) | ✓ (untested on real head unit) |
| Headphone-removal auto-pause | ✓ free via `audio_session.music` |
| Auto-play on BT connect | ✓ v0.20.1 (opt-in toggle) |

## Server features

- Subsonic salt+token auth (no plain-text passwords on wire).
- Server reachability ping (every 60 s) → offline banner above mini-player.
- Subsonic library cache (drift): full song-level metadata for autoqueue scoring + Genre/Decade browsers + smart playlists + FTS.
- Subsonic scrobble at track-start + at Last.fm-style played-threshold.

## Theme & UI

- Dark theme (default, Spotify-inspired).
- Light theme (system / dark / light picker in Settings → Display); 87 `Colors.white*` literals migrated to theme-aware aliases (v0.12.0).
- **Material You** (v0.20.1) — Settings → Display → "Use system colours"; Android 12+ pulls the wallpaper palette.
- Brand accent `#1ED760` everywhere.
- Custom launcher icon (golden shovel + "DIG" + music notes, v0.12.3).
- Bottom-nav shell (Home / Search / Library) + persistent mini-player.
- Offline banner + Selection bar appear conditionally above the mini-player.

## Build & release

- GitHub Actions CI on push to `main` + `v*` tags.
- APK artifact (90-day retention) on every push.
- Auto-published GitHub Release on tag.
- Concurrency dedup by SHA.
- **Optional release-signed APKs** via 3 secrets (`KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`); falls back to debug signing if absent.
- **Optional Last.fm ranker** via `LASTFM_API_KEY` secret.
- Optional Subsonic URL pre-bake via `SUBSONIC_URL` + `SUBSONIC_LABEL`.

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
