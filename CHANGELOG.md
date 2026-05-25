# Changelog

All notable changes to **digaudio** are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.20.1] — 2026-05-25

### Added (Material You + auto-play BT)
- **Material You dynamic palette** (Android 12+). Settings →
  Display → "Use system colours (Material You)". When on AND the
  OS exposes a palette, `MaterialApp.router` wraps with
  `DynamicColorBuilder` and the `ColorScheme` follows the
  wallpaper. Brand accent `#1ED760` remains the fallback when the
  OS doesn't expose a palette (pre-Android 12, or palette
  unavailable). Hardcoded accent splashes (heart icon, EQ-active,
  Now Playing transport) stay green by design — those are brand,
  not theme.
- **`AppTheme.fromDynamic(ColorScheme)`** builds the dynamic
  variant: dynamic palette for `colorScheme`, our background /
  card / appBar treatment overlaid on top.
- **Auto-play on Bluetooth connect** (Settings → Playback). When
  a BT output becomes active and the queue is loaded but paused,
  resume automatically. Default off — opt-in because some users
  explicitly pause before donning headphones.
- `BtEqService` extended with the auto-play hook (reuses the same
  `devicesChangedEventStream` subscription that already drives the
  per-device EQ override).

### Confirmed (no code change)
- **Headphone-removal auto-pause** has been on since v0.9.x via
  `AudioSessionConfiguration.music` — the OS sends
  `AUDIO_BECOMING_NOISY` on unplug, and the session config makes
  just_audio pause automatically. The new auto-play-on-connect
  toggle complements it: pause on remove + resume on connect.

### Dep
- Added `dynamic_color: ^1.7.0` for the Material You palette
  resolution (no other consumer in the app today).

## [0.20.0] — 2026-05-25

### Added (Quick Settings tile — combo 4 kickoff)
- **`PlaybackTileService`** (Kotlin) — Android Quick Settings tile
  that broadcasts a paired DOWN/UP `ACTION_MEDIA_BUTTON` intent
  with `KEYCODE_MEDIA_PLAY_PAUSE` on tap. The
  `MediaButtonReceiver` (declared by the `audio_service` plugin in
  the manifest) picks it up and routes to the AudioService →
  toggles `play()` / `pause()` on the engine. No direct service
  binding needed — relies entirely on Android's standard media-
  button plumbing.
- Manifest registration with `BIND_QUICK_SETTINGS_TILE` permission
  + `QS_TILE` intent filter.

### User onboarding
- Android API doesn't let an app auto-add its tile to Quick
  Settings. **First-time setup**:
  1. Pull down the notification shade twice to expose the full
     Quick Settings panel.
  2. Tap the pencil/edit icon.
  3. Find "digaudio" in the available tiles and drag it into the
     active set.
  4. From then on: pull down → tap "digaudio" → play/pause.

### v1 scope
- Tile shows a static "digaudio" label with INACTIVE state — no
  two-way sync with the live PlaybackState. Live state would
  require either a NotificationListenerService (intrusive runtime
  permission) or a bound service connection, neither of which adds
  enough value over the existing notification + lockscreen
  controls to justify the complexity. User can confirm play state
  via the notification.

## [0.19.0] — 2026-05-25

### Added (Library FTS — combo 1 complete)
- **FTS5 virtual table** `cached_subsonic_songs_fts` shadowing the
  drift-managed `CachedSubsonicSongs`. Searchable cols: title /
  artist / album / genre, tokenised with
  `unicode61 remove_diacritics 2` so "café" matches "cafe" and
  vice versa.
- **Triggers** keep FTS in sync with the main table on every
  insert / delete / update — no manual reindex needed when the
  Subsonic cache rebuilds.
- **`SubsonicLibraryCache.searchFts(serverId, query, limit)`** —
  parametrised, sanitises raw user input to a safe FTS5 query
  (strips non-`[\p{L}\p{N}\s]`, drops 1-char terms, appends `*`
  for prefix-AND matching → "daf pun" finds "Daft Punk").
- **Search page now FTS-first.** `searchResultsProvider` fans out
  to FTS + Subsonic `search3` in parallel via `Future.wait`,
  dedupes by `uniqueKey`, surfaces FTS hits first (instant), then
  remote-only additions. Local-MediaStore matches still come from
  the existing in-memory filter (MediaStore has no FTS).
- **Offline-resilient**: remote `search3` is wrapped with
  `catchError` returning empty results, so FTS still surfaces
  matches from the cache when the server is unreachable.

### Database
- **Schema v7 → v8** — adds the FTS virtual table + 3 triggers
  (`cs_fts_ai` / `cs_fts_ad` / `cs_fts_au`). On-upgrade backfills
  the FTS index from existing `cached_subsonic_songs` rows so
  installs with a synced cache get instant search without
  re-syncing. `onCreate` runs the same setup for fresh installs.

### Internal
- DB schema helpers `_createSubsonicFtsTable` /
  `_createSubsonicFtsTriggers` extracted so `onCreate` and the v8
  migration share them.
- Combo 1 (recommendation engine = Last.fm × library FTS × smart
  playlists × Subsonic radio) is now **4/4 done**.

### Known limitation
- The Search page's "Show more" pagination counts FTS results
  against the remote offset, so it may skip some remote results
  that are also present in FTS. Real-world impact: low (FTS covers
  everything in the cache; "Show more" is mainly useful for tracks
  newer than the last sync, which by definition aren't in FTS).
  Fix would require tracking provenance per result.

## [0.18.0] — 2026-05-25

### Added (TRUE crossfade — engine refactor)
- **`AudioEngine` rewritten with two `AudioPlayer` instances.**
  `_primary` is the audibly-playing one; `_secondary` either idles
  or preloads the next track. The queue (`_tracks`) is managed
  manually — no more `ConcatenatingAudioSource` — so we can
  suppress auto-advance and replace it with our own transitions:
  - **Overlap fade** when `crossfadeMs > 0`: secondary starts at
    volume 0 + ramps up to the next track's RG-adjusted target
    while primary ramps down to 0 over the fade window. After
    completion, `_primary` and `_secondary` swap roles.
  - **Instant swap** when `crossfadeMs == 0`: secondary already
    has the next track preloaded, primary stops at the same moment
    secondary starts at full volume → **gapless even without
    overlap** (a real improvement vs. the old single-player flow
    where setAudioSource on track end would briefly underrun).

### Internal — stream multiplexing
- All UI-facing streams (`playerStateStream`, `positionStream`,
  `durationStream`, `bufferedPositionStream`, `currentIndexStream`,
  `currentTrackStream`, `loopModeStream`, `shuffleModeStream`) are
  now **engine-owned broadcast controllers**, fed by inner subs on
  whichever player is currently primary. `_wirePrimary()` cancels
  and re-attaches those inner subs on every swap so external
  subscribers (Now Playing, mini-player, etc.) stay valid across
  transitions without any code on their side.

### Engine — manual loop + shuffle
- **`LoopMode.one`** delegates to just_audio's per-source loop
  (seamless single-track repeat).
- **`LoopMode.all`** is handled by `_peekNextIndex()` — wraps to
  index 0 when we'd advance past the last track.
- **Shuffle** is engine-level now (`_applyShuffle` pins the current
  track at index 0 then shuffles the rest). Toggle off restores the
  insertion order via `_originalOrder`. The old just_audio
  per-source `shuffle()` was a no-op in single-source mode.

### Engine — secondary safety
- `_silenceSecondary()` is called by `skipToPrevious`,
  `skipToQueueItem`, and the `_instantAdvance` fallback path —
  guarantees a mid-fade secondary doesn't keep playing in the
  background when the user jumps elsewhere.

### Equalizer
- Two `AndroidEqualizer` instances (one per player) kept in sync
  via `applyEqGains` / `setEqEnabled` so a fade across an EQ change
  doesn't sound like a sudden tone shift.

### Compatibility
- Every public method preserved: `setQueue`, `playSingle`,
  `appendToQueue`, `playNext`, `moveInQueue`, `removeFromQueue`,
  all `BaseAudioHandler` overrides, plus convenience aliases
  (`next`, `previous`, `setShuffle`, `setRepeat`, `seekToIndex`,
  `setVolume`). `raw` getter still works (now returns `_primary`),
  `equalizer` (returns `_eqA`).

### Known limitations / follow-ups
- Position UI during the crossfade window reflects whichever player
  is primary — once the swap happens, the slider snaps to the new
  track's position. Acceptable for the ~5 s fade window; if it
  feels jarring we could pause UI updates during the overlap.
- Repeat-one + crossfade > 0 explicitly suppresses the transition
  (LoopMode.one delegates to the source's own loop) — the user
  almost certainly wants the seamless repeat, not a self-crossfade.

## [0.17.3] — 2026-05-25

### Added (Per-Bluetooth-device EQ override)
- **`BtEqService`** subscribes to `audio_session.devicesChangedEventStream`,
  detects the active BT output device (A2DP / LE / SCO), and applies
  a saved per-device EQ profile via `AudioEngine.applyEqGains`. When
  no override exists for the active BT device (or no BT is active),
  falls back to the user's default `eqGainsDb`.
- Storage key per device = `"<name>|<type.name>"` so a wired
  "speaker" and a BT "speaker" with the same name don't collide.
  Profiles persist in `SharedPreferences` under `pb.eq.bt.profiles`.
- **Settings → Playback → Equalizer → Per-Bluetooth-device EQ** card:
  - Shows the currently-connected BT device (if any)
  - "Save current EQ" button captures the current sliders as that
    device's profile
  - List of every remembered device below, each with a delete button

### Internal
- The default EQ (sliders + presets) is unchanged — it always writes
  to `eqGainsDb`. The BT override is a separate layer that kicks in
  only when the active output matches a saved profile.

## [0.17.2] — 2026-05-25

### Added (Replay Gain — volume normalisation)
- **`PlaybackPrefs.rgMode`** = `off` / `track` / `album`. Engine
  reads the matching gain from the current Track and applies a
  per-track volume attenuation via setVolume. Crossfade ramps were
  refactored to tween toward the RG-adjusted ceiling (`_targetVolume`)
  instead of 1.0, so RG and crossfade compose cleanly.
- **No boost** — RG positive gain would require pre-amp boost that
  risks clipping. Loud tracks get pulled down; quiet tracks stay at 1.0.
- **Track model** gains `replayGainTrackDb` + `replayGainAlbumDb`
  (nullable doubles). Parsed from OpenSubsonic's `replayGain.{track,album}Gain`
  on song JSON. Stock Subsonic ≤ 1.16 doesn't expose them → both
  fields null → engine leaves volume at 1.0 (no-op).
- **Settings → Playback → Volume normalisation** picker (Off / Track /
  Album) with subtitle explaining the OpenSubsonic dependency.

### Internal
- `AudioEngine._rgVolumeFor(t)` — `10^(gainDb/20)`, clamped `[0, 1]`,
  with track / album field preference based on mode.
- `_startFadeIn` / `_applyFadeOut` updated: their ramps tween toward
  `_targetVolume` so an RG-quiet track + crossfade still works.

## [0.17.1] — 2026-05-25

### Confirmed
- **Gapless playback** has been on since v0.9.x — `just_audio`'s
  `ConcatenatingAudioSource` handles same-album track transitions
  without inserting a silent gap. No code change needed; added a
  sentence to the Crossfade settings card so the user knows.

## [0.17.0] — 2026-05-25

### Added (EQ presets — category C kickoff)
- **6 EQ presets** above the band sliders in Settings → Playback →
  Equalizer: Flat, Rock, Jazz, Vocal, Bass boost, Treble boost.
  Tap any chip → applies preset gains across all bands + saves to
  PlaybackPrefs.eqGainsDb + auto-enables the EQ if it was off.
- Presets target the standard 5-band layout Android Equalizer
  returns (60 / 230 / 910 / 3.6k / 14k Hz). On devices with more
  bands the extra ones get 0; on devices with fewer the tail is
  truncated. Values clamped to `[minDecibels, maxDecibels]` so a
  device with ±9 dB range doesn't crash on a preset peaking at +8.

## [0.16.3] — 2026-05-25

### Added (Bulk select — finishes category A)
- **Long-press any track tile to enter multi-select mode.** Standard
  mobile pattern (Gmail / Google Photos / Spotify). When selection
  is non-empty, tap also toggles instead of playing.
- **SelectionBar** above the mini-player when ≥1 track is selected.
  Five bulk actions:
  - **Play** — replaces the current queue with the selection
  - **Add to queue** — appends to the end
  - **Play next** — inserts right after current (reverse-iterates
    so the first-selected lands next)
  - **Add to playlist** — opens a multi-add variant of the local
    playlist picker
  - **Add to favourites** — bulk-fav every selected key
  - X button cancels selection
- Selection state is **global** on purpose — start in Library,
  navigate to Search, add more, act on the union.

### Changed (breaking-ish for v0.16.2 users)
- **Long-press always enters selection mode now.** This supersedes
  the `longPressPlays` toggle introduced in v0.16.2. The toggle is
  removed from Settings → Display → Behaviour; the underlying
  `DisplayPrefs.longPressPlays` field is kept (silently unread) so
  prefs don't fail to load on existing installs.
- Rationale: dual long-press meaning ("play OR enter selection")
  isn't discoverable; the selection-mode pattern is the dominant
  mobile idiom, and the standalone toggle was a stop-gap before
  this batch landed.

### Internal
- `SelectionNotifier` keeps `Map<String, Track>` (key + full Track
  for actions that need more than the key — playNext, queue, etc.).
- Selection bar lives in `AppShell` between the offline banner and
  the mini-player; renders only when `selectionProvider` is
  non-empty.
- TrackTile shows a leading check-circle when in selection mode and
  tints itself accent-translucent when selected.

## [0.16.2] — 2026-05-25

### Added (UX polish — last items of category A)
- **Now Playing colour tint.** Soft top-down gradient using the
  dominant colour of the current artwork (via palette_generator,
  already in the dep tree). Computed once per track, cached in
  widget state, animated 400 ms between tracks. Toggle in
  Settings → Display.
- **Long-press plays the track** toggle (Settings → Display →
  Behaviour). Power-user mode: tap = browse, hold = play; the track
  sheet then moves to the ⋮ button on the right. Off by default.

### Deferred (originally bundled into v0.16.2)
- **Bulk select in lists** — long-press toggles a multi-select mode
  with batch actions (favourite / add-to-playlist / queue /
  download). Touches many UI files (Library, Search, Album, Playlist
  views) + needs its own per-list state + an alternative AppBar.
  Lifted to its own future release so this one ships clean.

### Internal
- `DisplayPrefs` gains `longPressPlays` + `nowPlayingTint` (both
  persisted alongside `themeMode`).
- `_TintBackground` is the only consumer of palette_generator
  today; it caches by trackKey so the same track's palette is
  computed at most once per session.

## [0.16.1] — 2026-05-25

### Added (Per-track resume + Up Next strip)
- **Per-track resume position.** The engine debounces position writes
  to a new `TrackPositions` table (~5 s cadence) for the currently
  playing track. On re-play of the same track, if the saved
  position is meaningfully mid-track (≥ 10 s in, ≥ 10 s before end)
  the engine seeks there automatically once duration is known. Use
  case: long DJ mixes / audiobooks / podcasts — pause, switch to
  something else, come back later, resume where you left off.
- **"Up Next" inline strip** on Now Playing → Player tab. Shows the
  3 upcoming tracks below the transport row (small artwork + title +
  artist). Tap a row → skip directly to that track. Hides itself
  if there's nothing queued after the current.

### Database
- **Schema v6 → v7** — new `TrackPositions` table (trackKey PK /
  positionMs / updatedAt).

### Internal
- `TrackPositionsManager` — `save` (insertOnConflictUpdate),
  `get`, `clear`. Not a hot table thanks to the 5 s debounce in
  the engine.
- `AudioEngine._maybeResume` — one-shot `durationStream` listen
  that seeks once duration is non-null, then cancels. Avoids a
  permanent subscription per track switch.

## [0.16.0] — 2026-05-25

### Added (Queue editor + Album mode — category A)
- **Drag-to-reorder** in the Now Playing → Queue tab via
  ReorderableListView. Each row carries an explicit drag handle on
  the right (avoids tap-vs-drag ambiguity on TrackTile).
- **Swipe-to-remove** queue entries (left swipe). Background reveals
  red delete affordance, similar to the local-playlist editor.
- **Album mode** ("Stop after this album") — new AppBar action on
  Now Playing. When armed, the engine pauses as soon as the next
  track switch leaves the current `albumId`. One-tap toggle; chip
  turns accent green when armed; auto-disarms after firing.

### Engine
- `AudioEngine.moveInQueue(from, to)` — wraps just_audio's
  `ConcatenatingAudioSource.move`. Adapts the "newIndex" convention
  ReorderableListView uses (post-removal index) to the
  ConcatenatingAudioSource expectation.
- `AudioEngine.removeFromQueue(index)` — wraps `.removeAt`. Both
  methods rebroadcast `queue` so the MediaSession surface stays
  truthful.
- `AlbumModeService` — lazy `currentIndexStream` subscription, only
  attaches when the user first arms the toggle; reactive
  `armedStream`.

## [0.15.4] — 2026-05-25

### Added (Smart mixes builtins seeded at first launch)
- 4 builtin smart playlists materialise on first launch into a
  freshly-installed app, so the user has something to play with
  before writing their own rules:
  - **All time random** — no filters, random order, 50 tracks
  - **80s revival** — year 1980–1989, random
  - **90s revival** — year 1990–1999, random
  - **Recent** — year ≥ current_year − 4, random
- `smart.builtins.seeded` flag persists in SharedPreferences after
  the first seed pass, so users who delete the builtins won't see
  them respawn.

### Internal
- `SmartPlaylistsManager.seedBuiltins()` — single call, idempotent
  via the caller's flag. v1 builtins all fit inside the v1 rule set
  (year-only filters); richer builtins can be added once v2 lands
  with play-count / favourite / rating joins.

## [0.15.3] — 2026-05-25

### Added (Smart playlists — combo 1 centerpiece)
- **Rules-based smart playlists**. Library → Playlists → "Smart
  playlists" section + "New" button → editor with:
  - name
  - match all / any
  - N rule rows: field (Genre / Artist / Album / Title / Year /
    Duration) × operator (= ≠ > ≥ < ≤ between contains) × value
  - order (Random / Year / Title / Artist / Duration) ± direction
  - limit (1–1000)
- Opening a smart playlist materialises it on the fly: runs the rules
  against `CachedSubsonicSongs`, shows the matching tracks with Play
  all + Shuffle buttons. Refresh + Edit + Delete in AppBar.
- Rules persisted as JSON in a new drift table (schema v6) so the
  rule shape can evolve without further migrations.

### Database
- **Schema v5 → v6** — new `SmartPlaylists` table (id / name /
  rulesJson / createdAt).

### Internal
- `SmartPlaylistsManager.executeRules()` builds dynamic SQL with
  parametrised variables (no string interpolation of user input);
  bad rules are silently dropped so one malformed entry doesn't tank
  the whole query.
- v1 filters Subsonic library cache columns only; joins against
  favourites / play counts / pinned downloads deferred to v2 to keep
  the engine small and easy to reason about.

### Notes
- Requires the Subsonic library cache to be synced (Settings →
  Playback → Sync library). With an empty cache, all smart playlists
  return zero tracks.

## [0.15.2] — 2026-05-25

### Added (Subsonic radio mode)
- **"Start radio"** action in the per-track sheet (Subsonic tracks
  only). Seeds the playback queue with the chosen track + up to 30
  similar tracks pulled from the server's own similarity engine
  (`getSimilarSongs2`). Different engine than digaudio's metadata
  similarity / Last.fm ranker — taps into whatever Subsonic /
  Navidrome / Gonic computes server-side.
- `SubsonicClient.getSimilarSongs(songId, count)` — empty list on
  any failure so the caller can fall back gracefully.

### Note
- The radio queue isn't auto-refilled today (when the 30 tracks
  end, the regular auto-queue lookahead takes over). A future
  patch could keep refilling via `getSimilarSongs` on the last
  played track for a truly endless radio stream.

## [0.15.1] — 2026-05-25

### Added (Library — Genre + Decade browsers)
- **Library → Genres** sub-tab. Lists every distinct genre present in
  the Subsonic library cache (sorted by track count). Tap → tracks of
  that genre with Play all + Shuffle buttons.
- **Library → Decades** sub-tab. Lists every decade (1970s, 1980s, …)
  present in the cache, newest first. Tap → tracks of that decade,
  same Play all / Shuffle header.
- Both require a one-time library sync (Settings → Playback → Sync
  library); empty hint points the user there.

### Internal
- `SubsonicLibraryCache.genres(serverId)` / `decades(serverId)` —
  single-pass aggregation queries.
- `SubsonicLibraryCache.tracksOfGenre()` / `tracksOfDecade()` —
  ordered fetch, returns full `Track` list.
- New routes `/genre/:name` + `/decade/:year`; shared `_BrowsePage`
  scaffold so the two pages share UI.

## [0.15.0] — 2026-05-25

### Added (Stats — combo 1 / category B starter)
- **"On this day" section** — distinct tracks you played on the same
  calendar day in prior years, newest first. One-tap to play a track,
  or "Play all" to queue the whole nostalgic batch as a retrospective
  mix. Empty for installs < 1 year old (with a hint explaining why).
- **"Year by year" section** — one block per year present in history
  (newest first), top 5 tracks each, tap a row to play. Reuses the
  monthly-tops renderer with a label-format tweak.

### Internal
- `PlayHistoryManager.onThisDay(limit)` — `strftime('%m-%d', ...)`
  match excluding today.
- `PlayHistoryManager.topPerYear(perYear)` — single SQL pass grouped
  by `(track_key, year)`, then limited per-year in Dart for clarity.
- `_MonthBlock` label parser now accepts year-only strings so the
  yearly section reuses the same widget.

## [0.14.2] — 2026-05-25

### Added
- **Search pagination ("Show more" per category).** The first batch
  still comes from the existing `searchResultsProvider` (20 each).
  After that, each section gets a "Show more" button that fetches
  the next 20 of that type via the Subsonic offset params and
  appends to the displayed list. Button hides itself when a fetch
  returns fewer than the requested page size (server has no more).
  Local-track matches stay up front; remote tracks paginate.
- `SubsonicClient.search` gained `songOffset` / `albumOffset` /
  `artistOffset` parameters (omitted when 0 to keep the first-call
  request small).

### Internal
- Per-category extras + exhausted flags + loading flags live in
  `_SearchPageState`; reset whenever the debounced query changes
  so we never mix results across searches.

## [0.14.1] — 2026-05-25

### Changed
- **Auto-queue now maintains a 3-track lookahead** instead of
  appending a single track at queue-end. Each newly-appended pick is
  computed off the **last** track in the queue (not the original
  seed), so the chain stays coherent with the trajectory the user is
  actually moving through — and the LockCachingAudioSource has time
  to prefetch + warm the cache before each transition, which matters
  more now that crossfade exists.

## [0.14.0] — 2026-05-25

### Added
- **Crossfade between tracks.** Settings → Playback → Crossfade chip
  row (Off / 2 s / 5 s / 10 s). The engine ramps volume from 1 → 0
  over the last `crossfadeMs` of each track and from 0 → 1 over the
  first `crossfadeMs` of the next, so the transition feels continuous.
  Pseudo-crossfade — no second player / no actual overlap, but the
  perceived effect is identical for typical music.
- `PlaybackPrefs.crossfadeMs` persisted in shared_preferences;
  restored at startup; engine reads it live on every position tick +
  every track switch so picker changes take effect at the next
  transition.

### Internal
- `AudioEngine._applyFadeOut` (position-stream-driven, idempotent)
  and `_startFadeIn` (40 ms-tick Timer.periodic, auto-cancelled on
  next track switch) — both no-ops when `crossfadeMs == 0`.

## [0.13.1] — 2026-05-25

### Added
- **Home hero strip.** The Home page gains a brand strip at the top:
  the launcher icon (72 dp, rounded) + "digaudio" + "Dig your audio."
  tagline. Adds a bit of life on the main screen instead of jumping
  straight into "Newest releases".
- `assets/icon/digaudio_icon.png` registered as a runtime asset
  (separate from the build-time launcher icon generator, which
  consumes the same PNG but doesn't bundle it for `Image.asset`).
  `cacheWidth: 192` so the 1024 source is decoded near display size,
  not at full resolution.

## [0.13.0] — 2026-05-25

### Added (release signing — opt-in)
- `android/app/build.gradle` now picks up a release-signing config from
  env vars (`KEYSTORE_FILE`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`,
  optional `KEY_PASSWORD`). When the keystore file is missing, falls
  back to debug signing — so clean clones / forks still build without
  any keystore.
- CI workflow has a new "Decode release keystore (opt-in)" step that
  base64-decodes a `KEYSTORE_BASE64` secret into `/tmp/digaudio-release.jks`
  and exports `KEYSTORE_FILE` for the gradle step.

### Activation recipe (do once)
On your dev machine:
```bash
keytool -genkey -v \
  -keystore digaudio-release.jks \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias digaudio
base64 -w 0 digaudio-release.jks       # copy the one-line output
```
On GitHub → Settings → Secrets and variables → Actions, add:
- `KEYSTORE_BASE64` — paste the base64 output
- `KEYSTORE_PASSWORD` — what you typed at the `keytool` prompt
- `KEY_ALIAS` — `digaudio` (or whatever you used)
- `KEY_PASSWORD` — only if you set a different key password than the
  store password; otherwise omit.

**Keep `digaudio-release.jks` somewhere safe** — losing it means you
can never ship an in-place update again (users would have to
uninstall + reinstall).

### Migration note
The first build with these secrets in place produces an APK signed
with a **different identity** than the previous debug-signed builds.
That means the very first install will need to **uninstall** the old
one first (`adb uninstall com.digaudio.digaudio`) — Android refuses
to overwrite an APK with a different signing certificate. Every
update after that is seamless.

## [0.12.3] — 2026-05-25

### Changed
- **New launcher icon (v2).** Golden shovel with embossed "DIG", music
  notes, and a small dirt mound — replaces the previous shovel-only
  rendition. Adaptive foreground regenerated via `make_adaptive_fg.py`
  (~68% inset preserved so launcher masks don't clip).

## [0.12.2] — 2026-05-25

### Fixed (UX)
- **Direct heart toggle on Now Playing.** Until now favourites were
  only reachable through the per-track actions sheet (long-press or
  ⋮), which was non-obvious from the big artwork view. The Player
  tab now shows a Spotify-style heart icon next to the title — one
  tap to favourite the currently playing track. Stays in sync with
  every other surface (track tile badge, actions sheet) via the
  existing `favoriteKeysProvider`.

## [0.12.1] — 2026-05-25

### Added (Stats polish)
- **Year-grid heatmap** (GitHub-contributions style) replaces the
  30-day strip. 7 rows × ~53 cols, oldest left / today right. Cell
  intensity normalises against the year's max so a quiet listener
  still sees relative shape.
- **Monthly tops** — one block per month for the last 12 months,
  newest first; each block shows the 3 most-played tracks of the
  month with play counts. Tap a track → engine plays it.

### Internal
- `PlayHistoryManager.topPerMonth(months)` — single SQL pass via
  `strftime('%Y-%m', played_at, 'unixepoch')` for grouping; UI
  resolves only the top 3 per month (≤ 36 lookups for a year).
- `_load()` now fetches the year-long heatmap + monthly tops alongside
  the existing payload — still one async pass, no extra rebuilds.

## [0.12.0] — 2026-05-25

### Changed (theme-awareness sweep)
- **All 18 UI files** migrated from hardcoded `Colors.white*` literals to
  a `BuildContext` extension (`textPrimary` / `textSecondary` /
  `textTertiary` / `textMuted` / `textDisabled` / `outlineStrong` /
  `dividerSoft`). The same UI now re-skins automatically when the user
  picks light mode — no widget-by-widget overrides needed. The light
  theme upgraded from "experimental" to actually usable.
- **`lib/ui/widgets/theme_ext.dart`** — single source of truth for the
  opacity-step rubric. Each alias is defined relative to
  `colorScheme.onSurface` so dark + light both honour it.
- **`AppTheme.light()` definitions** (in `lib/theme.dart`) keep their
  hardcoded `Colors.black*` paint values — those define the theme,
  not consume it.

### Notable carve-outs
- The amber **offline banner** in `shell.dart` keeps explicit
  `Colors.white` for text + icon (fixed amber background, white reads
  in both light and dark UI).
- The `_accent` constant (`Color(0xFF1ED760)`) is unchanged — that's
  the brand colour, intentionally fixed.

### Internal
- 87 `Colors.white*` literals replaced across 18 files; `flutter analyze`
  clean.
- `lib/ui/widgets/artwork.dart` placeholder helper gained a
  `BuildContext` parameter (was static-callable; needed context for
  the theme-aware fill). Three call sites in itemBuilder lambdas
  updated.

## [0.11.3] — 2026-05-25

### Added
- **Synced lyrics** via OpenSubsonic `getLyricsBySongId`. The Lyrics
  tab now highlights the active line in accent and auto-scrolls it to
  ~1/3 from the top as playback advances. Gracefully falls back to
  the classic `getLyrics` plain-text endpoint when the server doesn't
  implement the OpenSubsonic extension or has no synced version.
- `SyncedLyrics` + `LyricsLine` models in `lib/subsonic/client.dart`.

### Internal
- `_SyncedLyricsView` subscribes once to `positionStream` and only
  `setState`s when the active line index actually changes (per line,
  every few seconds) — the position-tick rate (10–30 Hz) doesn't
  trigger a full ListView rebuild.

## [0.11.2] — 2026-05-25

### Added
- **Last.fm `track.getSimilar` ranker** for AutoQueue. When a key is
  baked into the build, the picker fetches Last.fm's similar tracks
  for the current seed and adds a per-candidate boost (Last.fm
  match × 12, so a perfect 1.0 outranks an artist-only metadata
  hit of +10). Without a key, behaviour is identical to before —
  pure metadata, no network call.

### Internal
- `lib/library/lastfm.dart` — `LastfmClient` with aggressive timeouts
  (5 s connect / 10 s receive) and swallow-on-error semantics. The
  next-track pick must always succeed even if last.fm is down.
- CI workflow forwards `LASTFM_API_KEY` (optional secret) as a
  `--dart-define`. Add it under repo Settings → Secrets → Actions
  to enable; sign up at https://www.last.fm/api/account/create.

## [0.11.1] — 2026-05-25

### Added (Batch 3 — polish)
- **Online/offline fallback.** A `ServerHealthService` pings the active
  Subsonic server every 60 s. A thin amber banner appears above the
  mini-player when the server is unreachable so the user knows they're
  seeing cached state. Auto-recovers on the next successful ping —
  no manual retry needed.
- **Theme toggle** (Settings → Display). Dark / Light / Follow system.
  The light theme is **experimental** — many widgets still hardcode
  `Colors.white*` (artefact of the dark-only roots) and render with
  low contrast in light mode. They'll be migrated to
  `Theme.of(context).colorScheme.*` incrementally; the toggle ships
  now so the picker + persistence are in place.
- **`DisplayPrefs`** in `lib/core/display_prefs.dart` (themeMode today;
  accent / font scale tomorrow). Loaded in `main()` alongside the
  playback prefs; mirrored into `themeModeProvider` so MaterialApp
  redraws on every change.

### Internal
- `_accent` constant now scoped per-file (settings.dart, now_playing.dart)
  instead of inlined as `Color(0xFF1ED760)` literals (principle 1).

## [0.11.0] — 2026-05-25

### Added (Phase 3 — Android Auto)
- **Android Auto** support. A custom `AudioHandler` exposes a browsable
  tree with three top-level nodes: **Favorites**, **Recently played**
  (last 20 distinct), **Most played** (top 50). Tapping a leaf in AA
  routes through `playFromMediaId` → `TrackResolver` → single-track
  queue. The MediaSession surface (notification, lockscreen, Bluetooth,
  Android Auto) is now driven by the same `playbackState` /
  `mediaItem` / `queue` streams the in-app UI uses — no parallel paths.
- **`PlayHistoryManager.recentUnique(n)`** — most-recent N distinct
  trackKeys, most-recent first. Powers the AA "Recently played" node.

### Changed (significant)
- **Dropped `just_audio_background`** in favor of `audio_service` direct.
  JAB's internal `AudioHandler` is private, so customising the
  browsable tree (mandatory for AA) wasn't possible without forking.
  audio_service is the underlying engine JAB itself uses, written by
  the same author (Ryan Heise) and considerably more mature than the
  beta JAB. No regression risk: `MainActivity` already inherits from
  `AudioServiceActivity` and the manifest already had the
  `MediaBrowserService` intent-filter.
- **`AudioEngine` now extends `BaseAudioHandler`** and broadcasts
  `playbackState` + `mediaItem` + `queue` so MediaSession reflects the
  player without a separate bridge. The class file (`lib/audio/player.dart`)
  is the single source of truth — no duplicated state.
- **Boot order rewired.** `main()` now hydrates downloads + prefs and
  builds the handler **before** `runApp`. The handler is registered
  into Riverpod via `registerAudioEngine()`; `audioEngineProvider`
  reads the singleton. `app.dart`'s post-frame callback shrunk to its
  three remaining concerns: speed-mirror StateProvider, AutoQueue
  start, and (unchanged) router build.

### Android
- New `res/xml/automotive_app_desc.xml` declaring `<uses name="media"/>`.
- `AndroidManifest.xml` gains the
  `com.google.android.gms.car.application` meta-data pointing at it.
  Without these two files, AA won't surface the app even with a working
  `MediaBrowserService`.

### Testing notes
- **AA requires a real-device validation pass.** The CI build will
  produce an APK, but Android Auto behaviour can only be confirmed
  on-device (phone connected to a car head unit or AA Desktop Head
  Unit simulator). Same goes for the new MediaSession bridge — the
  notification / lockscreen / BT controls should behave identically
  to before; please flag any regression.

## [0.10.1] — 2026-05-25

### Added (Phase 2.1 — streaks + heatmap)
- **Listening streaks** — current and longest consecutive-day runs.
  "Current" tolerates a missed *today* (walks back from yesterday) so
  the streak doesn't visually reset at midnight before the morning's
  listen. Rendered as two flame-chip metrics on the Stats page.
- **30-day heatmap** — one square per day, intensity normalised
  against the window's max. Days with zero plays render in white12
  (visible but inert). Oldest left, today right.

### Internal
- `PlayHistoryManager.streaks()` + `dailyCounts(days:)` — both go
  through SQLite's `date(played_at, 'unixepoch')` since drift's typed
  expressions don't expose day truncation.

## [0.10.0] — 2026-05-25

### Added (Phase 2 — listening stats + smart mixes)
- **Listening stats page** at `/stats` (Library → Playlists → "Stats").
  Three time windows (30 d / 90 d / All-time); for each: total plays,
  unique tracks, listening days; top 10 tracks; top 10 artists derived
  from the same 50-track aggregation.
- **"Most played" smart mix.** One-tap queue of the top 50 tracks in
  the current window — same payload the page already had loaded, no
  second round-trip.
- **`PlayHistoryManager`** in `lib/library/play_history.dart`. Append-only
  log with totals / top-tracks / listening-days queries (typed-drift
  expressions for the windowed counts, raw SQL only for the date
  truncation that drift can't express).
- **Engine now records every play** in its existing track-change
  listener (same listener that already does LRU touch + scrobble), so
  no extra subscription overhead.

### Database
- **Schema v4 → v5.** `RecentPlays` migrated from `(trackKey)` PK to
  autoincrement `id`. The old shape silently overwrote replays — now
  every playback is preserved (true play counts). Old table was empty
  in practice, so the migration drops + recreates.

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
