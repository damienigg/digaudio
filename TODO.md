# TODO — digaudio (post-v0.25.0)

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

### D · Platform integration — 2/7 remaining

- ~~**Homescreen widget (mini-player)**~~ — **DONE v0.25.0** (4×1 RemoteViews + WidgetChannel push from Dart; v1 has no artwork — RemoteViews need a Bitmap, deferred to v2)
- **Voice search inside the app** — *(M)*  
  Today Android Auto does it via the system; in-app would use Android's `SpeechRecognizer`. Adds a mic icon to the Search AppBar → speech-to-text → debounced query injection.
- **Wear OS companion** — *(L)*  
  Independent watch app, syncs playback state with the phone via the standard Wear Data Layer. Own session.
- **Widget artwork (v2)** — *(M, follow-up to v0.25.0)*  
  Pre-fetch the current track's artwork on the Dart side, write to a tmp file, pass the path through the MethodChannel; Kotlin reads + `setImageViewBitmap` on the widget. Battery + storage cost minor (one Bitmap per track switch, evicted on next change).

### E · Social & external — 2/4 remaining

- ~~**ListenBrainz scrobble direct**~~ — **DONE v0.24.1** (token-based, parallel to Subsonic scrobble)
- ~~**Now-Playing share**~~ — **DONE v0.24.0** (text card via share_plus)
- **Last.fm scrobble direct** — *(M, was S)*  
  Bumped to M: needs the Last.fm OAuth-style auth flow (different from the read-only API key we use for the ranker — `track.scrobble` requires per-user session). Today's Subsonic-mediated scrobble already forwards to Last.fm when the server is configured, so this is only useful when the Subsonic server itself lacks LFM integration.
- **Listening parties / shared queue** — *(L)*  
  Real-time playback-state sync across multiple devices (WebSocket relay or Tailscale-local mesh). Still deferred until there's a real use case.

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

### G · Long-tail polish — 3/7 remaining

- ~~**Accessibility audit**~~ — **DONE v0.23.2** (12 tooltips + alpha-scroll Semantics + heatmap Semantics wrapper)
- ~~**Sleep-timer fade-out**~~ — **DONE v0.23.0** (10 s 1-second-stepped ramp; snapshot+restore on cancel)
- ~~**Notification rich actions**~~ — **DONE v0.23.1** (skip 10 s back / forward via MediaAction.fastForward / .rewind)
- **Internationalisation** — *(M)*  
  Everything is English today. Externalise strings via Flutter's `intl` package; ship a French translation first. Bootstrap is mechanical (l10n.yaml + ARB scaffold), translation pass itself is several hours of focus — own session.
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
| 4 · Daily driver (Quick Settings tile × widget × Wear OS × Auto-play BT × Per-track resume) | 4/5 (only Wear OS remains) |

---

## Suggested versioning sequence

- ~~**v0.22.x** — F batch~~ DONE (cache auto-refresh / Recently played / DL queue)
- ~~**v0.23.x** — G batch (partial)~~ DONE (sleep fade / notif rich actions / accessibility); i18n + waveform + BPM-match + admin remain
- ~~**v0.24.x** — E batch (partial)~~ DONE (Now-Playing share / ListenBrainz); Last.fm direct (M) + listening parties (L) remain
- ~~**v0.25.x** — Homescreen widget~~ DONE (v1 without artwork)
- **v0.26.x** — Voice search in-app (M)
- **v0.27.x** — Wear OS companion (L, own session)
- **v0.28.x** — Multi-server unified search (L, cross-cutting Track.serverId refactor)
- **v0.29.x** — i18n / Last.fm direct / Subsonic admin / widget-artwork-v2 (mid-effort polish)
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
