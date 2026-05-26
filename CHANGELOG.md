# Changelog

All notable changes to **digaudio** are documented here.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/);
versioning follows [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.30.26] — 2026-05-27

### Changed (App name: DIGaudio)
- "digaudio" → **DIGaudio** in user-visible places: Home hero,
  MaterialApp title, AndroidManifest `android:label`. The "DIG"
  emphasises the brand; "audio" stays lowercase. The Subsonic
  client identifier on the wire stays lowercase (server doesn't
  care; consistency with prior installs).

### Fixed (Up Next ↔ Queue drift)
- The Up Next 6-tile strip and the Now Playing Queue tab could
  drift apart when the queue mutated between track changes (auto-
  queue append, addToQueue, etc.) — both widgets only rebuilt on
  track change, missing in-between mutations.
- New `engine.currentQueueStream` (broadcast) fires on every mutation
  via a single `_publishQueue()` helper that all 7 mutation sites
  now route through. `currentQueueProvider` mirrors it via
  StateNotifier; both Up Next + Queue tab watch this — always in
  sync.

### Changed (Tint extraction shares the artwork cache)
- `coverAccentProvider` used `NetworkImage` for PaletteGenerator —
  triggered a fresh network fetch every time the tint provider ran,
  so the play FAB stayed brand-green for several hundred ms after
  each track change. Switched to `CachedNetworkImageProvider` with
  the same cacheKey as `_BgArtwork` → palette extraction reads the
  cover off disk (already cached for the bg) → near-instant tint
  on repeat plays.

### Fixed (Library tabs were local-only)
- Library → Tracks / Albums / Artists tabs surfaced ONLY the local
  MediaStore content. Subsonic tracks (cached or otherwise) were
  invisible — a real Library should show "everything you can play".
- New `librarySourceProvider` (StateProvider) with 3 modes:
  - **Both** (default) — local + Subsonic union, sorted by title /
    name.
  - **Local only** — old behaviour.
  - **Subsonic only** — pulled from the drift cache; offline-safe.
- AppBar action: source-picker popup with icon hint
  (`all_inclusive` / `phone_android` / `cloud_outlined`).
- New `SubsonicLibraryCache.allAlbums()` + `allArtists()` derive
  the album / artist lists from the cached per-track rows.
- Empty state copy now mentions running the library sync when
  nothing shows up (sync via Settings → Playback).

## [0.30.25] — 2026-05-27

### Changed (Album mode moved into the sleep-timer sheet)
- The standalone round album icon in the Now Playing AppBar was
  ambiguous — users didn't read it as a "stop after this album"
  affordance ("a quoi sert l'icone ronde a cote du share ?").
  Removed the icon entirely. Added a "Stop at end of album" entry
  inside the sleep-timer sheet alongside "Stop at end of current
  track" + duration options. The bedtime icon now shows `EOA` when
  album mode is armed (alongside the existing `EOT` and countdown
  labels).
- All three sleep modes are mutually exclusive in the sheet —
  picking one cancels the others. Single "Cancel timer" entry
  clears whichever is active.

### Fixed (Crossfade + sleep EOT conflict)
- With both crossfade enabled and "Stop at end of current track"
  armed, the crossfade trigger (`_onPosition` swap to secondary
  when within the fade window) ended the current track via
  `_primary.stop()` instead of letting it complete naturally — so
  `_onProcessingState(completed)` never fired for the gated track
  and the sleep timer didn't pause. Fix: also guard the crossfade
  trigger behind `pauseAtEndOfTrack`. When the gate is armed, the
  track ends naturally (no crossfade), the completed event fires,
  the gate is honoured.

## [0.30.24] — 2026-05-27

### Changed (Real music sharing instead of a text card)
- The Share icon on Now Playing used to send a dumb text card
  ("Listening to X — Y · via digaudio"). Now actually shares the
  music:
  - **Subsonic track**: calls `createShare(songId)` on the
    originating server, which returns a public URL anyone can use
    to stream the song without auth or the digaudio app. URL goes
    through the system share sheet (Messages, Telegram, email,
    etc.). Server-side share permissions apply — Navidrome
    restricts to admin users by default and the error is surfaced
    inline as a snack.
  - **Local track**: shares the file via Android's content URI
    through `share_plus`'s `shareXFiles`. The recipient app gets a
    real attachable file (Telegram → audio file, email →
    attachment, Drive → upload, etc.).

### Fixed (Sleep timer "Stop at end of current track")
- The "Stop at end" feature was racing the engine's auto-advance:
  both listened to `processingState == completed` on the same
  stream, and the auto-advance (subscribed first) consistently
  fired before the sleep timer could pause — so the next track
  started playing anyway.
- Fix: added a one-shot `pauseAtEndOfTrack` gate on the engine.
  When `SleepTimerService.startAtEndOfTrack()` arms it, the engine's
  `_onProcessingState` honours the gate and skips the advance.
  The sleep timer's own listener still fires to tidy its UI state.

## [0.30.23] — 2026-05-27

### Added (Mini-player on Now Playing too)
- Now Playing's Queue + Lyrics tabs had no transport visible — once
  inside, the only way to pause/skip was to swipe back to the Player
  tab. Added `bottomNavigationBar: const MiniPlayer()` to the
  Now Playing Scaffold so transport is always one tap away,
  regardless of which tab you're on. Slightly redundant on the
  Player tab (the FAB is right above) but harmless.

### Bundled
- All v0.30.22 contents (shuffle setQueue fix, prev/next transport
  accents, album AppBar → clickable link, TrackTile.onTap debug
  print). v0.30.22's tag CI was cancelled by concurrency dedup
  with the simultaneous main-push run, so the release APK never
  shipped — folded those changes into this release.

## [0.30.22] — 2026-05-27

### Fixed (Shuffle-on + tap song = plays a random different song)
- `setQueue` called `_applyShuffle(initialIndex)` (which pins
  `tracks[initialIndex]` at position 0 + sets `_currentIndex = 0`)
  but then *overwrote* `_currentIndex = initialIndex.clamp(...)` on
  the next line — pointing at some random shuffled track instead of
  the user's pick. Now only the non-shuffle branch reassigns
  `_currentIndex`; the shuffle branch trusts `_applyShuffle`'s own
  bookkeeping. Tap-to-play now respects the user's selection
  regardless of shuffle state.

### Added (Prev / next icons follow the same artwork tint)
- The transport row on Now Playing had a tinted play FAB but
  prev / next stayed un-coloured. Now both inherit the same accent
  from the cover palette (with brand-green fallback), so the trio
  reads as a cohesive group.

### Added (Now Playing AppBar album title → tappable)
- The truncated album name top-left of Now Playing now navigates to
  the album page when tapped (when an albumId is available — typical
  Subsonic case). Local tracks without an albumId stay as plain text.

### Debug
- Added `[digaudio.dbg] TrackTile.onTap: index=X, title=Y` print on
  every track-tile tap so the user's off-by-one report
  ("playing the song just before the one I tapped") can be confirmed
  in logcat. If `setQueue` follows up with `idx=X` and
  `setAudioSource (title=Y)`, the chain matches. If not, the gap is
  visible.

## [0.30.21] — 2026-05-27

### Changed (Background visible through the blur)
- Blur sigma 40 was too smeared — couldn't make out the artwork at
  all. Dropped to 12 and bumped overlay opacity 0.22 → 0.35 so the
  cover reads through cleanly without overwhelming the foreground
  content.

### Changed (Home page: no more top bandeau)
- Home's AppBar was an opaque strip with the "digaudio" title +
  settings gear. Now transparent (no title) + `extendBodyBehindAppBar`,
  so the global `AppBackground` flows all the way to the status bar.
  The settings gear stays accessible top-right, floating over the
  background. The "digaudio" branding is already in the Home hero
  card below — no need for a redundant title.

### Added (Album Play button tinted by cover palette)
- Generalised `nowPlayingTintProvider` into a family `coverAccentProvider`
  keyed by `(serverId, coverArt)`. Reuses the same palette-extraction
  + same vibrant/light-vibrant/muted/dominant fallback chain.
- `AlbumPage`'s Play button pulls its background colour from the
  album cover's palette (falls back to brand green for local
  albums / palette failure). Visually matches Now Playing's
  tinted FAB.

## [0.30.20] — 2026-05-27

### Changed (Artwork is snappier + sleeker)
- **In-memory image cache bumped** from Flutter's defaults
  (~100 entries / ~100 MB) to 500 entries / 256 MB at app boot.
  For a music app that scrolls through hundreds of album covers
  in a single session, the previous limits caused thrashing —
  evictions forced re-decodes (sometimes re-fetches) when the
  user scrolled back. New limits keep most covers warm across
  navigation.
- **Fade-in transition** on every `CachedNetworkImage` placeholder
  → loaded swap. Was the abrupt default; now 180 ms fade for
  tile-sized art, 220 ms for the full-bleed Now Playing
  background. Reads polished without feeling sluggish.

### Note (Background should now be screen-fixed)
- v0.30.19's restructure puts the `AppBackground` at
  `MaterialApp.builder` — outside the Navigator + outside any
  Scaffold. It sits on its own layer behind the active route, so
  page scrolling never moves it. (Earlier builds had bg inside
  AppShell's body Stack, which still wasn't scrollable but the
  user reported scroll-coupling; confirm post-install.)

## [0.30.19] — 2026-05-27

### Fixed (Display settings toggles silently destroying other prefs)
- Latent severe bug: every Display toggle called
  `ref.invalidate(displayPrefsProvider)` after `prefs.save()`. With
  `Provider<DisplayPrefs>`, invalidate re-runs the create lambda —
  which constructs a **fresh** `DisplayPrefs()` with default values.
  Net effect: toggling any Display setting reset *every other*
  in-memory display pref (theme mode, Material You, audio-geek
  toggle, debug mode, recent searches, etc.) until the next cold
  start when `load()` ran again. Toggle UI also visually stuck on
  the default value rather than the user's choice.
- Fix: `DisplayPrefs extends ChangeNotifier`; `save()` calls
  `notifyListeners()` at the end. `displayPrefsProvider` switched to
  `ChangeNotifierProvider`. Removed all five
  `ref.invalidate(displayPrefsProvider)` calls in settings.dart. Now
  the singleton stays alive, mutation persists in-memory, and
  `ref.watch` consumers rebuild correctly.

### Fixed (Subsonic artwork loading late + flickering on rebuild)
- `Artwork` widget's `CachedNetworkImage` had no `cacheKey`. Subsonic's
  salt+token auth regenerates the URL on every call, so a parent
  rebuild made CachedNetworkImage see a "new" image → cancel-and-
  refetch loop → artwork appeared late and disappeared on refresh.
- Fix: pin `cacheKey: 'subsonic:$serverId:$coverArt:$pxSize'` so the
  cache identifies the image by its stable shape regardless of the
  ephemeral salt in the URL.

### Fixed (App background invisible despite toggle on)
- v0.30.17's `_AppBackground` lived inside `AppShell.body` behind the
  StatefulNavigationShell. Inner shell branches (Home / Search /
  Library) each have their own Scaffold with an opaque
  `scaffoldBackgroundColor` that covered the background. Result:
  bg was rendered but never visible.
- Fix architecture: moved `AppBackground` to its own widget at
  `lib/ui/widgets/app_background.dart` and applied it globally via
  `MaterialApp.builder` — every route gets the same backdrop. Theme
  override sets `scaffoldBackgroundColor: Colors.transparent` so all
  Scaffolds (shell, secondary pages, settings, etc.) bleed through
  to the global bg. Now Playing's own opaque `_BgArtwork` continues
  to override locally on that route.

### Changed (Now-Playing tint colour source)
- Tint extraction order was `lightVibrantColor → vibrantColor →
  dominantColor`. `lightVibrantColor` is luminance-biased toward
  bright shades and often picked near-white for artworks containing
  bright whites — the play FAB ended up looking un-tinted. Reordered
  to `vibrantColor → lightVibrantColor → mutedColor → dominantColor`
  so the play / slider / heart accents pop more often.

### Changed (Up Next strip is denser — 2 columns × 3 rows)
- Previously showed 3 tracks vertically. Bumped to 6 (2-column ×
  3-row layout) per user request. Last row gracefully shows one tile
  + empty space when the upcoming queue is odd-length. Each tile is
  still tap-to-jump.

## [0.30.18] — 2026-05-27

### Added (Mini-player on secondary pages)
- Album / Artist / Playlist / Smart-playlist / Favorites / Wishlist
  / Genre / Decade / Stats pages now show the mini-player at the
  bottom — was missing because these routes live OUTSIDE the
  `StatefulShellRoute` so they didn't inherit the AppShell's
  bottomNavigationBar. Each Scaffold gets
  `bottomNavigationBar: const MiniPlayer()`. When no queue is
  loaded, MiniPlayer collapses to zero height (SizedBox.shrink)
  — no padding visible.

### Added (Skip-previous button on mini-player)
- Mini-player used to expose only play/pause + skip-next. Adding
  skip-previous to round out the standard transport, matching the
  expanded notification + Now Playing transport layouts.

### Changed (Single-instance lock)
- `MainActivity` launchMode bumped from `singleTop` to
  `singleTask`. Only one instance system-wide — subsequent app
  launches surface the existing process instead of starting a
  parallel one. Matches the media-app standard (Spotify,
  YouTube Music, etc.). Prevents the "two icons in recents with
  one playing audio" failure mode.

## [0.30.17] — 2026-05-27

### Added (Fancy app background on Home / Search / Library)
- The bottom-nav tabs used to render on a flat dark (or white)
  scaffold which read as bland for a music app. New `_AppBackground`
  widget sits behind the shell body and renders:
  - **Nothing playing** — app launcher icon (`assets/icon/digaudio_icon.png`)
    centred at 6 % opacity. Subtle brand presence on either theme.
  - **Track playing with artwork** — current cover blurred via
    `ImageFiltered(ImageFilter.blur(40, 40))` at 22 % opacity,
    `BoxFit.cover` over the full viewport. Cross-fades on track
    change via `AnimatedSwitcher` (350 ms).
- Works for Subsonic AND local tracks (uses the same Artwork
  fetch paths — `CachedNetworkImageProvider` for Subsonic,
  `LocalLibrary.getArtwork` for local with the v0.30.16 APIC
  fallback).
- Toggle: **Settings → Display → "App background"**, default ON.
  Off → flat scaffold (previous behaviour).
- Now Playing keeps its own `_BgArtwork` (full-bleed at higher
  opacity); this background only shows behind the navigation
  branches.

## [0.30.16] — 2026-05-27

### Fixed (Local MP3 artwork on Now Playing full-bleed background)
- `_BgArtwork` (the full-bleed cover that replaces the old rounded
  square in v0.30.5) bailed unconditionally on
  `track.origin != MediaOrigin.subsonic`, falling back to a dark
  empty container. So local MP3s with embedded artwork — visible
  in Up Next thumbnails, Library lists, the homescreen widget —
  showed up as a black void on Now Playing.
- Fix: when the track is local and has a coverArt id, fetch via
  `LocalLibrary.getArtwork` (the same path used everywhere else
  for local artwork) and render with `Image.memory` +
  `BoxFit.cover`, matching the Subsonic path's full-bleed shape.

### Changed (Per-track resume is session-bounded)
- Resume-from-saved-position used to fire on every track switch —
  if you replayed a song mid-session that you had paused 5 min
  earlier, it picked up at the old offset instead of starting from
  zero. Confusing UX (user: "ce comportement ne devrait s'appliquer
  que quand on revient apres avoir fermé l'app").
- Fix: the engine remembers when it has applied an auto-resume in
  the current session via a `_sessionResumeApplied` flag. The
  first track played in a session can still resume from a saved
  position; every subsequent track (auto-advance, skip, replay,
  fresh setQueue) starts at 0. The flag resets implicitly on app
  process restart so the next cold-start replay behaves as expected.
- Position-saving every ~5 s is untouched — the position is still
  persisted for use on the *next* cold start.

### Fixed (Embedded MP3 artwork extraction is more robust)
- `MediaStoreChannel.getArtwork` (Kotlin) only tried
  `ContentResolver.loadThumbnail`, which on many devices returns
  null / throws for MP3s whose embedded APIC frame isn't
  pre-indexed by Android's MediaStore. Symptom in logcat:
  `getEmbeddedPicture: extractAlbumArt was failed or the media
  file has no albumart image`.
- Fix: when `loadThumbnail` fails, fall through to a second path
  that opens the file via `MediaMetadataRetriever`, reads
  `embeddedPicture` directly (which actually parses the APIC ID3
  frame), decodes + downscales to the requested size, and returns
  PNG bytes. So MP3s that previously thumbnail-failed now surface
  their embedded art everywhere — Up Next, list rows, mini-player,
  AND the new full-bleed Now Playing background.

## [0.30.15] — 2026-05-27

### Changed (Now Playing accents follow the artwork palette)
- Slider track + thumb, play/pause FAB, and heart toggle now use a
  colour pulled from the current artwork's palette
  (`lightVibrantColor` preferred, falling back to `vibrantColor`
  then `dominantColor`). When the palette is unavailable (local
  track, network glitch, palette extraction failed, or the user
  turned off "Now Playing colour tint" in Settings → Display),
  these controls fall back to brand-accent green `#1ED760`.
- Single source of truth: new `nowPlayingTintProvider`
  (`FutureProvider.autoDispose<Color?>`) computes the tint once
  per track and feeds both the top-down gradient
  (`_TintBackground`) and the control accents. Palette extraction
  no longer happens twice.
- Brand green still applies to: shuffle / repeat icons (when
  active), Speed and Sleep labels (when active), synced lyrics
  active line, EQ enable accents. Those weren't part of the
  request.

## [0.30.14] — 2026-05-27

### Fixed (Notification rich actions never rendered)
- v0.23.1 declared `MediaAction.fastForward` + `MediaAction.rewind`
  in `systemActions` (so external surfaces like Bluetooth media
  buttons and Android Auto could call into the handlers), but
  forgot to put them in the `controls` list — which is what
  actually renders icons on the notification. The 10-second skip
  arrows were never visible to users since v0.23.1.
- Fix: 5-control podcast layout — `rewind / prev / play-pause /
  next / fastForward`. `MediaControl.stop` dropped (max 5 controls
  on Android; swipe-to-dismiss already handles "close"). Compact
  view indices `[1, 2, 3]` = prev / play-pause / next, so the
  rewind / fastForward arrows show only when the user expands the
  notification (standard placement).

### Added (Debug mode toggle)
- Settings → Display → "Debug mode" — toggles whether the
  `[digaudio.dbg]` engine + provider + mini-player prints fire in
  logcat. Default OFF; prints currently still fire unconditionally
  in the engine (legacy from the bug hunt). A follow-up release
  will gate the prints on this flag — for now the toggle is the
  user-visible affordance, the wiring lands later.

## [0.30.13] — 2026-05-27

### Fixed (THE mini-player race — for real this time, with proof)
- v0.30.12's per-step logs in `setQueue` pinpointed the freeze:
  ```
  setQueue: setVolume returned, awaiting play…
  [silence — never reaches "play returned"]
  ```
- Root cause: `await _primary.play()` in `setQueue` (and 5 other
  call sites). just_audio's `play()` returns a `Future<void>` that
  resolves only when playback STOPS (pauses / completes / stops),
  NOT when playback starts. Awaiting it blocks every line that
  follows — including `_onTrackChanged(t)` which is the one that
  emits the new track to `_trackController` and updates the
  StateNotifier feeding the mini-player.
- Symptom that finally cracked the case: "auto-advance ca marche
  après la première chanson". Auto-advance uses a different code
  path (`_finalizeAdvance` fires `_onTrackChanged` synchronously
  inside the swap completion, NOT after the play() future).
  Latent bug since v0.18.0 (two-player crossfade engine). The
  v0.30.7 StateNotifier refactor didn't introduce it — just made
  the symptom more obvious by removing the AsyncValue.loading
  noise.
- Fix: replaced `await _primary.play()` / `await _secondary.play()`
  with `unawaited(_primary.play())` / `unawaited(_secondary.play())`
  across all 6 call sites in setQueue, _startTransition (×2),
  _instantAdvance (×2), skipToPrevious, skipToQueueItem. `play()`
  is fire-and-forget; the rest of the chain continues immediately;
  `_onTrackChanged` fires; the engine state propagates to the UI.

### Added (Version info in Settings)
- Bottom of Settings main page: tiny low-contrast line
  `digaudio v0.30.13 · build 79`. Reads from `PackageManager` via
  `package_info_plus`. Useful when triaging bugs: the user can read
  back the running build at a glance.
- New dep: `package_info_plus: ^8.0.2`.

### Added (Recent searches)
- When the Search field is empty and the user has searched before,
  the empty state now shows a "RECENT SEARCHES" section with
  tappable chips for the last 10 queries (LRU, dedup'd). Tap a
  chip → fills the field + fires the search. X on a chip → deletes
  that entry. "Clear all" button in the section header wipes the
  list.
- Storage: `DisplayPrefs.recentSearches` (JSON-encoded `List<String>`),
  capped at 10. Recording: any debounced `_applyQuery` with a
  trimmed query of ≥ 2 chars. Dedup moves the existing entry to
  the head.

### Kept (Debug instrumentation)
- All `[digaudio.dbg]` prints across engine + providers + mini-player
  stay in place per user preference. Future bugs benefit from the
  ready-to-tail chain. A Settings toggle to silence them is
  planned but not in this build.

## [0.30.12] — 2026-05-27

### Debug
- v0.30.11 logcat smoking gun: `setQueue` entry log fires with
  `hasListener=true`, but `_onTrackChanged` log NEVER appears (no
  `_trackController.add fired`, no `MiniPlayer.build` with
  non-null track). So the function freezes between its entry and
  the line that updates the broadcast stream — strongly suggesting
  one of the `await` calls in the middle (`setAudioSource`,
  `setVolume`, `play`) hangs and never resolves.
- This build adds per-step prints between every `await` in
  `setQueue` (entry, secondary.stop, setAudioSource entry +
  return + catch, setVolume return, play return, _onTrackChanged).
  The next logcat capture will pinpoint the exact frozen call.

## [0.30.11] — 2026-05-27

### Debug
- Adds two more `[digaudio.dbg]` prints to nail down the mini-player
  race: `AudioEngine` constructor (confirms a single instance +
  ties controller hash to engine hash) and `MiniPlayer.build`
  (track value visible from inside the widget on every build).
- Combined with v0.30.9's existing setQueue / _onTrackChanged /
  _trackController.add / _StreamMirror lifecycle prints, the full
  chain is now traceable in logcat.

## [0.30.10] — 2026-05-27

### Changed (Audio info line is now opt-in)
- The codec / bit-depth / sample-rate / device line under the artist
  on Now Playing was visually noisy (multi-line wrap + a permanent
  ⚠ glyph for the 44.1 → 48 kHz upsampling that Android does on
  every built-in speaker — so it fired on 99 % of tracks for nothing
  useful). Hidden by default.
- New toggle: **Settings → Display → "Display infos for audio
  geeks"**. Off by default. When on, the line renders as before
  (still on 2 lines on narrow screens; the wrap is a separate
  cosmetic issue tracked for a future pass).
- The v0.29.0 design intent — visual bit-transparency proof for
  audiophiles — is preserved for users who explicitly opt in via
  the new toggle.

### Carried over
- All v0.30.9 debug instrumentation still active. Will be ripped
  out in v0.30.11 once the mini-player race is pinned.

## [0.30.9] — 2026-05-27

### Fixed
- Compile error in the v0.30.8 debug build: `super.initial` syntax
  forwards the param to the superclass but doesn't make it
  accessible in the constructor body, where we wanted to reference
  it for logging. Switched back to a regular `initial` param +
  explicit `: super(initial)` forwarding. Same debug instrumentation
  ships intact in this build.

## [0.30.8] — 2026-05-27

### Debug
- Temporary `print('[digaudio.dbg] ...')` instrumentation across
  `AudioEngine.setQueue`, `_onTrackChanged`, `_trackController.add`
  and `_StreamMirror` lifecycle (ctor / onData / onError / onDone /
  dispose). The smoking gun we need is whether
  `_trackController.hasListener` is true at the moment of the first
  `_trackController.add(t)` — if false, the StateNotifier
  subscription was created AFTER the event fired (race we missed).
  This is a one-version diagnostic build; the prints come out in
  v0.30.9 once the cause is identified.

## [0.30.7] — 2026-05-27

### Fixed — Mini-player STILL invisible after v0.30.5 (race in `async*` seeding)
- v0.30.5's seed-then-listen pattern using `async*`/`yield`+`yield*`
  still had a microtask race: the `yield engine.currentTrack` returned
  control to the event loop before the `yield*` subscribed to the
  underlying broadcast stream. Any broadcast event arriving in that
  window was lost. Symptom: tap a Search result → audio plays → mini-
  player + Now Playing remain empty (`currentTrackProvider` stuck
  on the initial seeded null).
- **Definitive fix**: scrap `StreamProvider` + `async*` for these
  six engine projections. Replace with `StateNotifierProvider`
  backed by a `_StreamMirror<T>` notifier that:
  1. Reads the engine's current synchronous state as `initial`
     (no race possible — fully sync).
  2. Subscribes to the broadcast stream (sync) and writes every
     emission into `state`.
  3. Cancels the subscription on dispose.
- Widgets switch from `ref.watch(p).valueOrNull ?? default` to
  `ref.watch(p)` since the value is now exposed directly (no
  `AsyncValue` wrapper). Applied across mini-player + Now Playing.

## [0.30.6] — 2026-05-27

### Added (Custom EQ presets)
- Settings → Playback → Equalizer now exposes a "**Save…**" chip
  alongside the 7 built-in presets. Tap it → naming dialog → the
  current band curve is persisted under that name. Custom presets
  render as InputChips next to the built-ins (visually peers, not a
  separate section) and carry a trailing X to delete.
- Storage: new `customEqPresets` field on `PlaybackPrefs`, encoded
  as a JSON array `[{name, gains[]}]`. Survives app restarts. No
  cap on count — the Wrap layout handles it naturally.
- Apply semantics match the built-ins: `_applyPreset` pads or
  truncates the gains list to fit the current device's band count
  (so a 5-band preset works on a 10-band device and vice-versa).

## [0.30.5] — 2026-05-27

### Fixed (Mini-player invisible on first play)
- **Root cause** (smoking-gun symptom from the user: *"ca chante mais
  pas de mini-player… une fois que la première chanson se termine,
  tout marche comme prévu"*): the engine's stream controllers are
  `StreamController.broadcast()` so multiple widgets can listen,
  but broadcast streams do NOT replay past events to new subscribers.
  The first `_onTrackChanged` event fires synchronously inside
  `setQueue()` — i.e. before any UI consumer has had a chance to
  attach. Listeners that subscribe afterwards (mini-player,
  Now Playing page, transport icons) never see that event → they
  render as if the queue were empty. Subsequent track changes work
  because by then the listeners are attached.
- **Fix**: every `Stream*Provider` in `lib/audio/providers.dart`
  now seeds with the engine's current synchronous state via an
  `async*` generator, then yields the broadcast stream. Applied to
  `currentTrack`, `playerState`, `position`, `duration`, `shuffle`,
  `loop`. Listeners now see the right initial state on first attach,
  regardless of when the prior broadcast event fired.

### Fixed (Notification artwork missing on Subsonic tracks)
- `audio_service` downloads `MediaItem.artUri` for the lockscreen +
  notification, but on our Tailscale-hosted Subsonic that fetch was
  flaky (the MediaSession service runs in a process boundary
  separate from the app, network reachability isn't identical).
- **Fix**: when `WidgetArtFetcher` lands a tmp JPEG (we already
  fetch this for the homescreen widget — single-slot, overwritten
  per track), we now re-publish the MediaItem with `Uri.file(path)`
  pointing at that local file. The notification + lockscreen pick
  up the local artwork immediately and reliably. Guard prevents
  race conditions on rapid skip (if `currentTrack` has moved past
  the original fetch's track when the file lands, we don't stamp
  it).

### Added (Now Playing nav icon)
- 4th destination in the bottom nav (`Icons.play_circle_outline`)
  that **pushes** `/now-playing` instead of switching branches —
  so back arrow returns to whichever tab the user was on. Always
  reachable regardless of mini-player state. The mini-player still
  appears above the nav when a track is loaded (now that the
  provider seeding fix above is in place) and still offers one-tap
  transport; the new icon is the *guaranteed* entry point.

### Changed (Now Playing — full-bleed artwork background)
- Replaced the centred rounded-square artwork with a full-bleed
  background. The cover fills the entire Player tab (`BoxFit.cover`
  at 1024 px source) with a dark vertical gradient overlay for
  legibility. Title / artist / audio info line / scrubber /
  transport / Up Next stack over the lower portion of the gradient.
  The `_TintBackground` palette gradient still wraps Queue + Lyrics
  tabs (where there's no full-bleed artwork to anchor the visual).

### Fixed (Up Next strip didn't advance after auto-advance)
- `_UpNextStrip` was reading `engine.raw.currentIndex` — that's
  just_audio's per-source index, which is always 0 in our
  two-player engine (each AudioPlayer owns one source at a time).
  After auto-advance the index didn't change → Up Next was frozen
  at queue positions 1/2/3 even though the queue had moved.
  Exposed `AudioEngine.currentIndex` (the engine-managed queue
  index) and routed `_UpNextStrip` through it.

## [0.30.4] — 2026-05-27

### Fixed (Subsonic artwork never loaded on Now Playing)
- **Root cause**: `_PlayerTab` watched `positionProvider` at the tab
  level. That stream emits ~10 Hz; the entire tab — including the
  `Artwork` widget — rebuilt every 100 ms. Each rebuild called
  `SubsonicClient.coverUri(coverArt)`, which mints a fresh
  salt+token per call, so the signed URL changed every frame.
  `CachedNetworkImage` saw a "new" URL every 100 ms, cancelled the
  in-flight fetch, and restarted — the cover never had time to
  land. Up Next thumbnails were unaffected because they're inside a
  separate widget below; the main artwork was the visible casualty.
- **Fix**: extracted scrubber + time labels into a `_ScrubberAndTimes`
  ConsumerWidget that owns the position watch. The parent tab no
  longer rebuilds on tick — Artwork, title, transport, audio-info
  line all stay stable across the entire track. Cover loads once
  per `_onTrackChanged` and stays put.

### Fixed (Audio routing line truncated past the device name)
- v0.29.0 set `maxLines: 1` on the routing line; phones with normal
  411 dp width clipped everything past the device name, hiding the
  output sample rate + the resampling ⚠ glyph (the whole point of
  the line). Bumped to `maxLines: 2`.

### Changed (EQ presets — softer, industry-grounded curves)
- Old presets were arbitrary internet-rule-of-thumb values capping
  at +8 dB (muddy bass, harsh treble — user-reported as "tres
  extremes"). Replaced with a curated 7-preset set derived from
  iTunes (Apple's audio team has been refining these since 2001;
  AIMP / VLC / foobar2000 inherit from this lineage). Max gain
  capped at ±5 dB.
  - Kept: **Flat**, **Rock** (softened), **Jazz** (softened),
    **Bass boost** (softened), **Vocal** (softened).
  - Added: **Pop** (vocal-forward V-flip), **Loudness**
    (Fletcher-Munson curve — AES/ITU reference for low-volume
    listening, boosts bass + a touch of treble).
  - Dropped: Treble boost (rarely used; the lighter Loudness curve
    covers the "add some sparkle" use case).
- Existing custom user gains are untouched — only the labelled
  presets changed.

## [0.30.3] — 2026-05-27

### Fixed
- **App stuck on splash forever for users with saved EQ gains.** Same
  root cause as the Playback-page hang fixed in v0.30.1: `main()`
  did `await handler.applyEqGains(prefs.eqGainsDb)`, which iterates
  bands and awaits `AndroidEqualizer.parameters` per band. On
  Android that future only resolves once the engine has materialised
  an `AudioTrack` — i.e. after the first play. At cold boot, no
  track has played → the future never resolves → `runApp()` is
  never reached → splash forever. Any user who has saved an EQ
  curve in a prior session hit this on the next launch.
  Fix: fire-and-forget the `applyEqGains` call at boot
  (`unawaited(...)`). The gains land as part of the audio pipeline
  initialisation, ahead of the first audible frame in practice.
  `setEqEnabled` stays awaited (it's a fast platform flag, no
  parameters dependency).

## [0.30.2] — 2026-05-27

### Fixed
- **Last.fm "Connect" handshake silently reset to "Connect Last.fm"
  after the user tapped "I approved — finish".** `LastfmScrobbleClient`
  captured the session key as a `final String?` at construction time;
  the provider read it from `PlaybackPrefs` via `ref.watch(...).lastfmSessionKey`.
  Problem: `PlaybackPrefs` is a mutable singleton — Riverpod can't
  tell when a field mutates inside it, so the provider never
  rebuilt, the client kept its empty cached session key, and
  `client.enabled` stayed false even though prefs had the key. The
  card's setState rebuilt local widget state but read the stale
  client and fell through to the "Connect Last.fm" branch.
  Root-cause fix: `LastfmScrobbleClient.sessionKey` is now
  `String? Function()` (a live closure). The provider passes
  `() => prefs.lastfmSessionKey`, so every `enabled` / `scrobble` /
  `updateNowPlaying` reads the current value. No provider rebuild
  needed, no version-counter plumbing, no extra `ref.invalidate`.
  Same model applies to disconnect (next read sees empty).

## [0.30.1] — 2026-05-27

### Fixed
- **Settings → Playback no longer hangs on a fresh launch.** Latent
  bug since v0.17.0 (when the EQ section first shipped). The page's
  `_hydrate()` awaited `AndroidEqualizer.parameters`, which on
  Android only resolves once the engine has materialised an
  `AudioTrack` — i.e. after the user has played at least one
  track in the current process. On a freshly-launched app (or right
  after `adb install -r`), opening Settings → Playback before any
  playback spun a `CircularProgressIndicator` indefinitely.
  Root-cause fix: extracted the EQ block into a self-managing
  `_EqualizerSection` widget that owns its own readiness. The rest
  of Playback (cache, storage, crossfade, RG, ListenBrainz,
  Last.fm, auto-play, auto-queue) now renders immediately. The
  EQ section shows an inline placeholder ("becomes available once
  a track has played") and swaps in the band sliders the instant
  the future lands — without the user having to leave + re-enter
  the page. The previously-`AppBar`-level "Flat" button moves
  inside the section header where it belongs.

## [0.30.0] — 2026-05-27

### Added (Last.fm scrobble direct)
- **Why it's not redundant**: user is on Navidrome, whose Last.fm
  integration is metadata-only (artist images / similar artists) —
  it does NOT forward user listens to Last.fm. So scrobbles never
  reach `last.fm/user/<you>` without this path. Confirmed during
  the 2026-05-27 audit.
- **`LastfmScrobbleClient`** (Dart, parallel to `ListenBrainzClient`)
  implements the classic 2-step desktop OAuth handshake:
  `auth.getToken` (signed: api_key + shared_secret → api_sig) →
  user approves in browser → `auth.getSession(token)` returns a
  long-lived session key + username. Session key is then signed
  into every `track.updateNowPlaying` (at track start) and
  `track.scrobble` (at the ≥ 4 min OR ≥ 50 % threshold, same as
  Subsonic + LB).
- **Settings → Playback → Last.fm card** with a 3-state UI:
  Disconnected (Connect button) → Pending approval (Finish +
  Cancel + copy-URL) → Connected (green check + username +
  Disconnect). Gracefully greys out on builds without the
  `LASTFM_API_KEY` / `LASTFM_SHARED_SECRET` dart-defines.
- **`url_launcher` dep** added (pubspec, `^6.3.1`) — opens the
  Last.fm approval page in the system browser.
- **`PlaybackPrefs`**: persists `lastfmSessionKey` + `lastfmUsername`.
- **CI**: `build-android.yml` threads `LASTFM_SHARED_SECRET` (new
  optional GH repo secret) into the build's dart-defines.
- **No regression risk** for users not on Navidrome / not wanting
  Last.fm: every call short-circuits to no-op when the session
  key isn't set; Subsonic + LB scrobble paths untouched.

### User action required to unlock
- Add `LASTFM_SHARED_SECRET` to GitHub repo secrets (alongside the
  existing `LASTFM_API_KEY`). Generate or retrieve it from
  https://www.last.fm/api/account/your → "Application details".
  Without it, the Settings card stays greyed out.

## [0.29.0] — 2026-05-27

### Added (Audio routing info line on Now Playing)
- **Visual bit-transparency check** on the Player tab: a small line
  under the artist reads `FLAC · 24-bit/96 kHz · 938 kbps  →  USB: FiiO Q3 · 96 kHz`.
  When source sample rate is known and differs from the system output
  mix rate, the line turns amber and a `⚠` glyph appears — silent
  resampling detected without trusting the ear. Closes Combo 2's
  FLAC + wired-DAC verify items (no loop-back hardware required).
- **`AudioInfoChannel`** (Kotlin, channel `digaudio/audio_info`)
  exposes `getRouting()` → `{deviceName, deviceType, outputSampleRate}`.
  Picks the active sink by Android's hardware priority chain
  (USB > BT A2DP > wired > built-in) — same answer as
  `AudioTrack.getRoutedDevice()` without holding the ExoPlayer-internal
  AudioTrack reference. `PROPERTY_OUTPUT_SAMPLE_RATE` for the mix rate.
- **`AudioInfoBridge` + `audioRoutingProvider`** (Dart) re-queries
  routing on every track change (the moment the user cares); polling
  outside that window is wasted.
- **`Track.samplingRate` + `Track.bitDepth`** parsed from OpenSubsonic
  `samplingRate` / `bitDepth` fields. Null on stock Subsonic ≤ 1.16
  and on local files (line falls back to codec + bit-rate only —
  detection of resampling needs both source and output sample rate).

## [0.28.0] — 2026-05-26

### Added (Widget artwork v2)
- **`WidgetArtFetcher`** (Dart) downloads the current Subsonic
  track's 256 px cover into `${tempDir}/widget_art.jpg` (single-slot,
  overwritten each track change — RemoteViews only shows one image
  at a time, no eviction needed). Engine kicks the fetch on
  `_onTrackChanged` then re-pushes the widget with the new path
  once it lands; pause/resume ticks re-use `_widgetArtPath` without
  re-downloading.
- **`WidgetBridge.update`** gains `artworkPath`; the Kotlin
  `WidgetChannel` forwards it to `DigaudioWidgetProvider.refresh`,
  which `BitmapFactory.decodeFile`s + `setImageViewBitmap`s the
  result (silently falls back to the launcher icon on null / decode
  failure / corrupt file). Layout's `widget_icon` → `widget_art`
  (semantic rename — only one ImageView slot).
- **`_pushWidget()` helper** in the engine — single source of truth
  for widget updates (was duplicated between `_onTrackChanged` and
  the playbackEventStream listener).
- **Local-only tracks**: still no widget artwork (same hidden cost
  as MediaItem `artUri` skipping local origin — deferred).

### Added (Subsonic admin — library scan)
- **`SubsonicClient.startScan` / `getScanStatus`** + a small
  `ScanStatus(scanning, count)` record. `startScan` is admin-only
  on Navidrome / Gonic; non-admin users get Subsonic error 50.
- **Server edit page section** "Library scan (admin)" with "Check
  status" + "Trigger scan" buttons. Surfaces "Admin role required"
  inline for non-admin users; surfaces live `scanning…` /
  `idle — N songs` for admins.

## [0.27.1] — 2026-05-26

### Fixed
- **Kotlin compile error introduced in v0.26.0** — VoiceChannel used
  `registerForActivityResult`, which needs `ComponentActivity` in the
  compile-time superclass chain. `AudioServiceActivity → FlutterActivity
  → FragmentActivity` doesn't surface that in our module's classpath
  (Flutter 3.24.5 pulls a fragment version where the inheritance isn't
  visible at compile time), so `MainActivity` failed to type-check.
  Result: v0.26.0 and v0.27.0 CI builds both red — no APKs were
  uploaded for either release. Switched to the pre-Jetpack
  `startActivityForResult` / `onActivityResult` pair, which works on
  any `Activity` regardless of the fragment version. `flutter analyze`
  was a false positive (Dart-only); needed the actual Android toolchain
  to surface this. v0.27.1 is the first build past the regression.

## [0.27.0] — 2026-05-26

### Added (Multi-server unified search)
- **`Track.serverId`** (+ `Album` / `Artist` / `Playlist`). Stamped by
  every `SubsonicClient` on parse so the originating server stays
  bound to each item even when the user switches the active server.
- **`SubsonicResolver`** — `forTrack(t)` / `forId(sid)` returns the
  right client per item, falling back to active when the id is null
  (legacy data) or stale (server since removed). Engine streaming,
  cover-art URI, scrobble routing, and the Artwork widget all go
  through it; the old "active client only" callback is gone.
- **Search fans out across every configured server** in parallel —
  per-server FTS5 cache hit + live `search3` call, fail-soft so one
  unreachable server can't block the others. Dedup is server-aware
  (`origin:serverId:id`) to avoid mis-merging two distinct songs that
  happen to share an id across unrelated Subsonic servers.
- **Server label on results** — when ≥2 servers are configured, each
  Track / Album / Artist row's subtitle gets a "· <label>" suffix so
  the user can tell which server a result came from. Single-server
  setup unchanged (no visual noise).

### v1 scope (deliberately deferred)
- **"Show more" pagination** still targets the active server only.
  Other servers contribute their initial 20 per category and plateau.
  Per-server pagination buttons would clutter the UI for marginal gain.
- **Ratings / scrobble / cache** still resolve via the active server
  for non-engine code paths (the engine itself routes per-track via
  the resolver, so playback always streams from the right host).
  A track played from server B scrobbles to A → A silently no-ops on
  the unknown id. Acceptable degradation; full per-server rating UI
  is a v2 if needed.
- **`Track.uniqueKey`** intentionally unchanged (`origin:id`, no
  serverId). Migrating it would invalidate every drift table that
  keys on it (favourites / cache / smart playlists / playlists /
  positions / history). The collision risk across two unrelated
  Subsonic servers is vanishingly low (Navidrome uses MBID-or-hash,
  Gonic uses sha256 — different namespaces); accepted as a known
  limitation, will revisit only if a real collision is reported.

### Roadmap — Combo 4 (daily driver) closed without code
- **Wear OS** companion was the last item; investigation showed
  Wear OS 3+ (Pixel Watch / TicWatch / Galaxy Watch with GMS)
  auto-mirrors the active phone MediaSession to the Media Controls
  tile on the watch. Our `audio_service` already publishes that
  session — so transport (title / artist / play / pause / skip)
  on the wrist is **free, no APK needed**. A custom Compose-for-Wear
  companion was scoped (Wearable Data/MessageClient handshake +
  separate Gradle module) but would only add favourite toggle /
  queue browse / lyrics — deferred unless a real need emerges
  (principle: minimum lines for a valid result).
- No code change — docs only (FEATURES.md / TODO.md / TEST_PLAN.md).
  Combo 4 → **5/5 ✓**.

## [0.26.0] — 2026-05-25

### Added (Voice search in-app)
- **Mic icon in the Search AppBar** — tap to dictate a query.
  Routes through `RecognizerIntent.ACTION_RECOGNIZE_SPEECH`, so
  the system's Google speech UI handles the listening overlay;
  the recognised text drops straight into the search field and
  triggers an immediate search (no 280 ms debounce — the user
  finished speaking, they want results now).
- **`VoiceChannel.kt`** — activity-scoped (must register the
  `ActivityResultLauncher` before `STARTED`). One `recognize`
  method that returns the top hypothesis or null on
  cancel / no recogniser / no speech captured.
- **`VoiceBridge.recognize()`** Dart wrapper.
- Manifest `<queries>` block extended with
  `android.speech.RecognitionService` so Android 11+ package
  visibility doesn't hide the system recogniser.

### v1 scope
- One-shot only — fires the system dialog, returns one string.
  No partial-results streaming or in-app waveform overlay
  (those need the lower-level `SpeechRecognizer` API; defer to a
  v2 if useful).
- Permission-free: the system recogniser captures audio in
  Google's own process, no `RECORD_AUDIO` needed in our app.

### Build & CI
- Bumped GH Actions past the Node 20 deprecation:
  `actions/checkout` v4→v6, `actions/cache` v4→v5,
  `actions/setup-java` v4→v5, `actions/upload-artifact` v4→v7.
  Forced Node 24 migration is 2026-06-02; v4s would have gone
  red. No workflow-script changes needed (no API differences
  affecting our usage).

## [0.25.0] — 2026-05-25

### Added (Homescreen widget — mini-player)
- **`DigaudioWidgetProvider`** (Kotlin AppWidgetProvider) — a
  4×1-cell homescreen widget showing the launcher icon · the
  current track's title + artist · play/pause + skip-next
  buttons. Tap the icon/text area → opens the app.
- **MethodChannel push updates**. `WidgetChannel.kt` listens on
  `digaudio/widget` for `update(title, artist, isPlaying)` calls
  from Dart and pokes every active widget instance via
  `AppWidgetManager.updateAppWidget`. No periodic AlarmManager
  wake — widget updates only when state changes (zero battery
  cost when paused).
- **`WidgetClickReceiver`** turns each button tap into a paired
  DOWN/UP `ACTION_MEDIA_BUTTON` broadcast (the audio_service
  plugin's `MediaButtonReceiver` consumes both). Same pattern as
  v0.20.0 Quick Settings tile.
- **`WidgetBridge`** (Dart) wraps the MethodChannel. Engine fires
  the bridge from two hooks already in place:
  - `_onTrackChanged` → title + artist + playing state
  - `playbackEventStream` listener (used for `_broadcastState`)
    → playing state alone, keeps the play/pause icon truthful
    across pause / resume / seek

### User onboarding
- Long-press the homescreen → Widgets → scroll to "digaudio" →
  drag the 4×1 tile onto a homescreen page. Resizes horizontally
  to fill larger cells.

### v1 limitations (deliberate)
- **No artwork**. RemoteViews can't display a network image — it
  needs an actual `Bitmap`. v2 would pre-fetch the artwork on
  Dart side, write to a tmp file, then pass the path so Kotlin
  reads + sets it. Acceptable tradeoff for v1; the launcher
  icon stands in.
- **No skip-prev button**. Save horizontal space for title + artist
  on the standard 4-cell width. Resize the widget wider on a
  big homescreen if you want one more control.
- **Single colour scheme**. Background hardcoded `#FF18181B`
  (matches dark theme) — RemoteViews can't follow Material You
  / light mode without per-version layout variants.

## [0.24.1] — 2026-05-25

### Added (ListenBrainz scrobble — token-based)
- **`ListenBrainzClient`** posts to `api.listenbrainz.org/1/submit-listens`
  with a user token (Bearer-style `Authorization: Token <uuid>`).
  Two listen types fire from the same hooks Subsonic scrobbling
  uses:
  - **`playing_now`** at track start (any origin — works for
    local + Subsonic tracks since LB doesn't need a server URL).
  - **`single`** when the played-duration threshold crosses
    (≥ 4 min OR ≥ 50 % of track) — same trigger as the Subsonic
    `submission=true` scrobble so the two scrobble counters stay
    aligned.
- **`PlaybackPrefs.listenbrainzToken`** persisted in SharedPreferences
  (same sensitivity as the Last.fm API key — revocable, per-user,
  non-destructive on leak).
- **Settings → Playback → ListenBrainz** card with a hidden token
  field (visibility toggle) + active check mark when set + a
  one-paragraph explanation linking to the LB profile token page.

### Compatibility
- Subsonic server-side scrobbling continues to fire in parallel —
  the two routes are independent; LB lets users scrobble even when
  their Subsonic server doesn't forward to anything.

## [0.24.0] — 2026-05-25

### Added (Now-Playing share)
- **Share button** on the Now Playing AppBar (between Album-mode
  and Speed). Tap → system share sheet with
  `'Listening to {title} — {artist}  ·  via digaudio'`.
  Disabled when no track is current.
- Reuses the `share_plus` dep already in the tree (originally
  added for playlist JSON export).
- **Not yet**: Subsonic `createShare` server-side URLs (need
  share permissions on the server) — would let recipients
  actually click and play, not just read the text. Future.

## [0.23.2] — 2026-05-25

### Changed (Accessibility sweep)
- **12 tooltips added** to previously-unlabelled `IconButton`s
  across 7 UI files (Home Settings, Now Playing transport +
  close, smart-playlist viewer, server edit / delete / forget,
  mini-player play+next, track-tile ⋮, ratings stars). TalkBack
  now announces a meaningful action for each.
- **Alpha-scroll letter strip** (`AlphaScrollList`) wraps each
  letter in `Semantics(label: 'Jump to letter X', button: true)`
  — visual size unchanged, but TalkBack now reads each row as a
  jump-target instead of just "B, button".
- **Year heatmap** (`_YearHeatmap` in Stats) wrapped with one
  summary `Semantics(label: 'Listening heatmap, last 365 days',
  excludeSemantics: true)` — silences the 365 inner cells (would
  otherwise read as "image, image, image..." noise) while keeping
  the visualisation intact for sighted users.

## [0.23.1] — 2026-05-25

### Added (Notification rich actions — skip 10 s)
- **Skip 10 s back / forward** buttons in the expanded
  notification, lockscreen, and Android Auto. `AudioEngine`
  overrides `fastForward()` / `rewind()` with explicit `±10 s`
  arithmetic + bound-clamping (negative → 0, past-end →
  duration). `_broadcastState` adds `MediaAction.fastForward` +
  `MediaAction.rewind` to the systemActions set.
- Useful for podcasts / mixes; doesn't replace the prev / next
  controls in the compact notification (those stay primary).

## [0.23.0] — 2026-05-25

### Added (Sleep-timer fade-out)
- During the last 10 s of a sleep-timer countdown, the engine's
  master volume ramps from its current value down to 0 (stepped
  at 1 s — audible but acceptable for a fall-asleep ramp).
  Snapshot taken when the fade window first opens; restored on
  pause + on manual cancel so the next play isn't muted.

## [0.22.2] — 2026-05-25

### Added (Background download queue + in-app progress)
- **`DownloadQueueService`** wraps `DownloadsManager.download`.
  `enqueue(Track)` / `enqueueAll(Iterable<Track>)` add to a
  pending list; an internal loop pops one at a time and runs the
  underlying download. Concurrency = 1 (concurrent downloads to
  one server contend for the same connection — serial is closer
  to wall-clock optimum).
- **Queue persistence is in-memory** — the loop survives app
  backgrounding (process stays alive via audio_service), but a
  full app kill loses the queue. Acceptable for v1.
- **`DownloadBanner`** (above the mini-player, same slot family
  as the offline banner / selection bar): shows the current
  track + queued count + a live progress bar (driven by
  `DownloadsManager.progressStream`) + Cancel button.
- **Cancel** clears the pending list; the in-flight job
  continues (Dio's stream-write semantics don't expose mid-stream
  cancel without restructuring). User-facing effect = "stops
  queuing more" which is what people usually mean.
- **Bulk-select gets a Download action** — pin every selected
  Subsonic track via the new queue (local tracks silently
  skipped). Pair with long-press → select-album → Download for
  one-tap album pin.

### Changed
- Per-track `Download for offline` action in the track sheet
  now enqueues (`Queued "X"` toast) instead of awaiting a
  blocking foreground download. Backing out of the sheet no
  longer interrupts anything.

### Not done in this batch (deferred)
- **Multi-server unified search** (originally planned as v0.22.3)
  needs `Track.serverId` added across the model + parsers +
  source builders (the engine streams via the active server's
  URI, which would 404 for a track from a different server).
  Cross-cutting refactor — split into its own milestone.

## [0.22.1] — 2026-05-25

### Added
- **Home gets a "Recently played" section**, between "Newest
  releases" and "Random picks". Uses Subsonic's
  `getAlbumList2(type='recent', size=20)` — comes from the
  server's own play history, not the local stats, so it stays
  useful across devices that share the same Subsonic account.
- Section hides itself when the server returns nothing (fresh
  install / fresh server / new account) — avoids an empty row.
- Pull-to-refresh now also invalidates the new provider.

## [0.22.0] — 2026-05-25

### Added (Subsonic library cache auto-refresh)
- `PlaybackPrefs.cacheRefreshDays` (default 7). On app boot, if
  the active server's library cache is older than this many days,
  the engine kicks a background `rebuild()` — no UI block, no
  user action required. Skipped on never-synced caches (initial
  sync should be deliberate so the user knows what they're
  getting) and when `cacheRefreshDays == 0` (off).
- **Settings → Playback → Subsonic library cache → Auto-refresh**
  dropdown: Off / Daily / Every 3 days / Weekly / Every 2 weeks /
  Monthly. The existing `_SubsonicCacheCard` shows progress + a
  Cancel button if the user opens that page while the background
  rebuild is running.

## [0.21.2] — 2026-05-25

### Changed (select-mode polish)
- **TrackTile in select mode: artwork becomes a 36 dp check-circle**
  in the same 48 dp leading slot. Same row footprint (no height
  jump) but the tap target reads as a checkbox first, artwork
  second. Out of select mode → artwork stays as-is, no change.

## [0.21.1] — 2026-05-25

### Added (Subsonic radio: auto-refill, truly endless)
- `RadioModeService` replaces the v0.15.2 one-shot 30-track flow.
  On every track-index change, if the buffer is under 3 tracks
  ahead, fetches 30 more similar tracks from the Subsonic server
  via `getSimilarSongs2(last_tail_track)` and appends up to 10
  unseen ones. Repeats indefinitely.
- **Self-disengaging**: the service tracks every key it added to
  the queue. On a track change, if the now-playing track isn't in
  that set, the user must have switched queues (album / playlist /
  smart mix) — refilling stops silently. Re-engaging is one tap on
  "Start radio".
- Refill seed is the **tail** of the queue (most recently added),
  not the original seed — so the radio's trajectory drifts the
  way the user is moving, not where they started.

### Changed
- "Start radio" action in the track sheet now routes through
  `radioModeProvider.startRadio(track)` instead of calling
  `engine.setQueue` directly. Same UX, plus the auto-refill.

## [0.21.0] — 2026-05-25

### Added (Smart playlists v2 — joins for the rules engine)
- **6 new rule fields** beyond v1's plain `CachedSubsonicSongs`
  columns:
  - **Boolean joins**: `favourite` / `pinned` / `cached` — `eq`
    only; renders as `EXISTS (…)` / `NOT EXISTS (…)` against the
    matching table.
  - **Computed ints**: `playCount30d` / `playCountAll` — subquery
    `COUNT(*) FROM recent_plays WHERE track_key = 'subsonic:' ||
    s.song_id` (with a date cutoff for the 30 d variant). Full
    comparator set applies.
  - **`lastPlayedDaysAgo`** — `(strftime('%s', 'now') -
    COALESCE(MAX(played_at), 0)) / 86400`. Never-played tracks
    return ∞ days ago so "≥ 90" matches dormant + never-played
    alike (treats never-played as "infinitely dormant" — usually
    the desired Throwback semantics).
- **Now expressible**: `favourite eq Yes AND playCount30d gte 3`
  → recurring favourites this month. `favourite eq Yes AND
  lastPlayedDaysAgo gte 180 AND year between 1990 1999` →
  90s favourites you haven't touched in 6 months — a real
  Throwback mix the v1 rule set couldn't write.

### Editor UI
- Field dropdown gains the 6 new fields, grouped visually
  (columns / boolean joins / computed ints).
- Op set adapts: bool fields lock to `eq`, ints get the full
  comparator set (no `contains`), text columns unchanged.
- Value editor swaps to a `Yes` / `No` `SegmentedButton` for
  bool fields; numeric keyboard for int fields; text for the rest.

### Internal
- `SmartPlaylistsManager._ruleToSql` refactored into three
  dispatchers: `_intExpr` (builds the LHS subquery for v2
  computed ints), `_intOp` (standard int comparator generator),
  `_columnOp` (preserves v1 column behaviour). Family routing
  happens up front in `_ruleToSql`.
- Main query gains alias `s` so subqueries can reference the
  outer row unambiguously (`s.song_id`). `_fieldToColumn` +
  `_orderClause` updated to prefix.
- `readsFrom` widened to include Favorites, Downloads,
  RecentPlays so drift's invalidation tracks the right
  surface area.

## [0.20.2] — 2026-05-25

### Fixed
- **CI build failure on v0.20.1.** `dynamic_color 1.8.1` (resolved
  by the `^1.7.0` constraint) calls `Color.toARGB32()`, which only
  exists in Flutter ≥ 3.27. The project is pinned to Flutter
  3.24.5 via the GH workflow, so the kernel snapshot failed with
  `Error: The method 'toARGB32' isn't defined for the class 'Color'`.
  Constraint tightened to `>=1.7.0 <1.8.0`. Locked at 1.7.0.

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
