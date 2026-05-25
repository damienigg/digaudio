# TODO — digaudio (post-v0.22.2)

What's left, organised by category + combo. Effort tags: **S** ≈ 30 min, **M** ≈ 1 h, **L** ≈ several hours (own session).

**TL;DR**: the app is feature-complete vs the Substreamer / Symfonium baseline. What follows is incremental polish + larger standalone chunks (widget, Wear OS, voice search). No remaining killer feature.

---

## Done (just for context)

- **Category A** — UX gold: 7/7
- **Category B** — Discovery & smart mixes: 7/7
- **Category C** — Audio fidelity: 5/5
- **Category H** — Session-discovered TODOs: 3/3 (smart playlists v2 / radio auto-refill / checkbox UX)
- **Combo 1** (Recommendation engine): 4/4 ✓
- **Combo 4** (Daily driver): 3/5 (widget + Wear OS remain, both L)

## Categories with items remaining

### D · Platform integration — 3/7 remaining

- **Homescreen widget (mini-player)** — *(L)*  
  Same controls + artwork on the user's homescreen. Glance value. Significant Android `AppWidget` work — Kotlin + remote views + update broadcasts. Own session.
- **Voice search inside the app** — *(M)*  
  Today Android Auto does it via the system; in-app would use Android's `SpeechRecognizer`. Adds a mic icon to the Search AppBar → speech-to-text → debounced query injection.
- **Wear OS companion** — *(L)*  
  Independent watch app, syncs playback state with the phone via the standard Wear Data Layer. Own session.

### E · Social & external — 0/4

- **ListenBrainz scrobble direct** — *(S)*  
  Open alternative to Last.fm. Same shape as the existing Subsonic scrobble — different endpoint + user token in Settings.
- **Last.fm scrobble direct** — *(S)*  
  Today scrobbling routes through the Subsonic server (which forwards to Last.fm when configured). Direct mode bypasses the server — useful if the Subsonic server lacks Last.fm integration.
- **Now-Playing share** — *(S)*  
  Share button on Now Playing — rich card (artwork + title + artist + Subsonic deep-link if any) via `share_plus`.
- **Listening parties / shared queue** — *(L)*  
  Real-time playback-state sync across multiple devices (WebSocket relay or Tailscale-local mesh). Defer until there's a real use case.

### F · Library management — 1/5 remaining

- ~~**Subsonic library cache auto-refresh**~~ — **DONE v0.22.0**
- ~~**"Recently played" on Home**~~ — **DONE v0.22.1** (the original "Recently added" wording was wrong — `type=recent` is play-history; "Newest releases" already covers recently-added)
- ~~**Background download queue**~~ — **DONE v0.22.2** with in-app progress banner (system notification omitted for v1 — would conflict with audio_service's notification + need POST_NOTIFICATIONS permission flow)
- **Multi-server unified search** — *(L, was M)*  
  Cross-cutting refactor: needs `Track.serverId` field added across
  the model + every parser + the source builder (engine currently
  streams via active-server URI, which would 404 for a track from
  a different server). Plus a UI affordance to show which server
  each result came from. Bumped to L; own milestone.

### G · Long-tail polish — 0/7

- **Accessibility audit** — *(S)*  
  Verify TalkBack labels on all interactive elements. Bigger tap targets on small UI (alpha-scroll letters, heatmap cells, year-grid cells). Audit semantic ordering of the Now Playing transport.
- **Internationalisation** — *(M)*  
  Everything is English today. Externalise strings via Flutter's `intl` package; ship a French translation first.
- **Sleep-timer fade-out** — *(S)*  
  Instead of pausing at 0, ramp the engine's volume from `_targetVolume` to 0 over the last 10 s of the timer. Smoother fall-asleep.
- **Notification rich actions** — *(S)*  
  Add "Skip 10 s back" + "Skip 10 s forward" buttons to the system notification — useful for podcasts.
- **Album-art waveform scrubber** — *(L)*  
  Replace the linear slider with a precomputed waveform (decode FLAC/MP3 header → PCM peaks → cached image alongside the cached audio file). Visual + faster scrubbing reference.
- **BPM-matched crossfade** — *(L)*  
  Detect BPM (either via Subsonic metadata or in-app FFT estimate), skip the crossfade if next track has a wildly different tempo. Niche but unique.
- **Subsonic admin actions** — *(M)*  
  If the user's role is admin: trigger server library scan from the app, see scan status, manage users.

### Combo 2 — Pro-listener — 4/6 remaining (verify-only)

- **FLAC end-to-end verify** — *(S, no code)*  
  Play a FLAC track, confirm bit-perfect through to the output (no resampling / dithering by Android). Optionally: display codec + sample rate on Now Playing.
- **Wired-DAC fidelity verify** — *(S, no code)*  
  Plug a wired USB DAC, confirm Android routes audio to it (probably free via system audio routing).

---

## Strategic combos — progress

| Combo | Status |
|---|---|
| 1 · Recommendation engine (Last.fm × FTS × smart playlists × Subsonic radio) | **4/4 ✓** |
| 2 · Pro-listener (RG × crossfade × EQ presets × per-BT EQ × FLAC × wired-DAC) | 4/6 (verify-only remaining) |
| 3 · Friend-share (ListenBrainz × Now-Playing share × listening parties × webhook) | 0/4 |
| 4 · Daily driver (Quick Settings tile × widget × Wear OS × Auto-play BT × Per-track resume) | 3/5 |

---

## Suggested versioning sequence

- ~~**v0.22.x** — F batch~~ DONE (cache auto-refresh / Recently played / DL queue; multi-server search deferred as L)
- **v0.23.x** — G batch: i18n (M) + accessibility (S) + sleep-timer fade (S) + notif rich actions (S)
- **v0.24.x** — E batch: ListenBrainz (S) + direct Last.fm (S) + Now-Playing share (S)
- **v0.25.x** — Homescreen widget (L, own session)
- **v0.26.x** — Voice search in-app (M)
- **v0.27.x** — Wear OS companion (L, own session)
- **v0.28.x** — Multi-server unified search (L, cross-cutting Track.serverId refactor)
- **v1.0.0** — first "release" milestone after a real-device validation pass on every section of `TEST_PLAN.md`

## Items deliberately not on the roadmap

- **Chromecast** — user explicitly dropped during planning ("c'est inutile")
- **iOS support** — Android-only target since v0.8.3 (scaffold removed)
- **Lidarr direct push** — user opted for "just a dashboard, I'll handle Lidarr manually" instead (see chat history; wishlist already covers it)
- **Listening parties / wishlist webhook gateway** — design discussed but no real use case yet; kept on the back burner

## User actions (non-code) outstanding

- **Activate release keystore** — drops "unknown source" install warning. Recipe in `CHANGELOG.md` v0.13.0
- **(Optional) Last.fm API key** — `LASTFM_API_KEY` in repo secrets, activates the auto-queue Last.fm ranker
- **Add the Quick Settings tile** — Android API can't auto-add it; user drags it in once (recipe in `CHANGELOG.md` v0.20.0)
- **Real-device validation pass** — work through `TEST_PLAN.md` on a phone before tagging v1.0.0
