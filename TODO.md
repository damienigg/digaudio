# TODO — digaudio (post-v0.29.0 audio routing info line)

What's left, organised by category + combo. Effort tags: **S** ≈ 30 min, **M** ≈ 1 h, **L** ≈ several hours (own session).

**TL;DR**: the app is feature-complete vs the Substreamer / Symfonium baseline. Every "killer" feature (incl. homescreen widget, voice search, Wear OS mirror) is shipped or proven free. What follows is polish + ambitious standalone L items.

---

## Done (just for context)

- **Category A** — UX gold: 7/7
- **Category B** — Discovery & smart mixes: 7/7
- **Category C** — Audio fidelity: 5/5 (FLAC + USB-DAC verify closed visually via v0.29.0 routing info line)
- **Category H** — Session-discovered TODOs: 3/3 (smart playlists v2 / radio auto-refill / checkbox UX)
- **Combo 1** (Recommendation engine): 4/4 ✓
- **Combo 4** (Daily driver): 5/5 ✓ (Wear OS validated via Wear OS 3+ system MediaSession mirror — no companion APK needed)

## Categories with items remaining

### D · Platform integration — 0/7 remaining ✓

- ~~**Homescreen widget (mini-player)**~~ — **DONE v0.25.0** (4×1 RemoteViews + WidgetChannel push from Dart)
- ~~**Voice search inside the app**~~ — **DONE v0.26.0** (mic icon → `RecognizerIntent.ACTION_RECOGNIZE_SPEECH`)
- ~~**Wear OS companion**~~ — **COVERED (no code)** — Wear OS 3+ system mirror handles transport
- ~~**Widget artwork (v2)**~~ — **DONE v0.28.0** (Dart `WidgetArtFetcher` writes 256 px JPEG to tmp; Kotlin `BitmapFactory.decodeFile` + `setImageViewBitmap`; falls back to launcher icon on null). Local-origin tracks still have no artwork (same hidden cost as MediaItem.artUri; deferred to a v3 only if a use case appears).

### E · Social & external — 2/4 remaining

- ~~**ListenBrainz scrobble direct**~~ — **DONE v0.24.1** (token-based, parallel to Subsonic scrobble)
- ~~**Now-Playing share**~~ — **DONE v0.24.0** (text card via share_plus)
- **Last.fm scrobble direct** — *(M, deferred from v0.28 bundle)*  
  Needs: (1) `LASTFM_SHARED_SECRET` secret added to GH repo + CI; (2) `url_launcher` dep added; (3) OAuth-style flow — get request token → open browser to `last.fm/api/auth/?api_key=X&token=Y` → user approves → app calls `auth.getSession` → stores session key. All future scrobbles use that key. Not a huge piece of code but the UX flow (browser handoff + "I've approved" confirmation) wants careful walk-through. Realistic session item, not a bundle drop-in.
- **Listening parties / shared queue** — *(L)*  
  Real-time playback-state sync across multiple devices (WebSocket relay or Tailscale-local mesh). Still deferred until there's a real use case.

### F · Library management — 0/5 remaining ✓

- ~~**Subsonic library cache auto-refresh**~~ — **DONE v0.22.0**
- ~~**"Recently played" on Home**~~ — **DONE v0.22.1** (the original "Recently added" wording was wrong — `type=recent` is play-history; "Newest releases" already covers recently-added)
- ~~**Background download queue**~~ — **DONE v0.22.2** with in-app progress banner
- ~~**Multi-server unified search**~~ — **DONE v0.27.0** (`Track.serverId` + `SubsonicResolver` per-track routing; fan-out FTS+search3 per server; `· <label>` chip when ≥2 servers). v1 limitations documented in CHANGELOG: "Show more" still active-server only; ratings/scrobble/cache routing still active-server (degrades silently for non-active-server tracks)

### G · Long-tail polish — 3/7 remaining

- ~~**Accessibility audit**~~ — **DONE v0.23.2** (12 tooltips + alpha-scroll Semantics + heatmap Semantics wrapper)
- ~~**Sleep-timer fade-out**~~ — **DONE v0.23.0** (10 s 1-second-stepped ramp; snapshot+restore on cancel)
- ~~**Notification rich actions**~~ — **DONE v0.23.1** (skip 10 s back / forward via MediaAction.fastForward / .rewind)
- ~~**Subsonic admin actions**~~ — **DONE v0.28.0** (`startScan` + `getScanStatus` + "Library scan (admin)" section on the server edit page; non-admin users see "Admin role required" inline). User mgmt deferred — admin scan covers the realistic "I just added music server-side" workflow; user CRUD is admin-console territory.
- **Internationalisation** — *(M scaffold, hours of FR translation pass)*  
  Everything is English today. Externalise strings via Flutter's `intl` package; ship a French translation first. Bootstrap is mechanical (l10n.yaml + ARB scaffold), translation pass itself is several hours of focus — own session.
- **Album-art waveform scrubber** — *(L)*  
  Replace the linear slider with a precomputed waveform (decode FLAC/MP3 header → PCM peaks → cached image alongside the cached audio file). Visual + faster scrubbing reference.
- **BPM-matched crossfade** — *(L)*  
  Detect BPM (either via Subsonic metadata or in-app FFT estimate), skip the crossfade if next track has a wildly different tempo. Niche but unique.

### Combo 2 — Pro-listener — 6/6 ✓

- ~~**FLAC end-to-end verify**~~ — **DONE v0.29.0** via routing info line: Now Playing reads `FLAC · 24-bit/96 kHz · 938 kbps  →  <device> · <output kHz>`. Resampling shown amber + ⚠ when source ≠ output mix rate. No ear required.
- ~~**Wired-DAC fidelity verify**~~ — **DONE v0.29.0** via same line: the device segment (`USB: FiiO Q3 · 96 kHz`) reads what Android routes to. Plug a DAC, glance at the line.

---

## Strategic combos — progress

| Combo | Status |
|---|---|
| 1 · Recommendation engine (Last.fm × FTS × smart playlists × Subsonic radio) | **4/4 ✓** |
| 2 · Pro-listener (RG × crossfade × EQ presets × per-BT EQ × FLAC × wired-DAC) | **6/6 ✓** (FLAC + wired-DAC closed visually via v0.29.0 routing info line) |
| 3 · Friend-share (ListenBrainz × Now-Playing share × listening parties × webhook) | **2/4** (ListenBrainz v0.24.1 + Now-Playing share v0.24.0; listening parties + webhook gateway deferred indefinitely — no use case) |
| 4 · Daily driver (Quick Settings tile × widget × Wear OS × Auto-play BT × Per-track resume) | **5/5 ✓** (Wear OS covered via system MediaSession mirror) |

---

## Suggested versioning sequence

- ~~**v0.22.x** — F batch~~ DONE (cache auto-refresh / Recently played / DL queue)
- ~~**v0.23.x** — G batch (partial)~~ DONE (sleep fade / notif rich actions / accessibility); i18n + waveform + BPM-match + admin remain
- ~~**v0.24.x** — E batch (partial)~~ DONE (Now-Playing share / ListenBrainz); Last.fm direct (M) + listening parties (L) remain
- ~~**v0.25.x** — Homescreen widget~~ DONE (v1 without artwork)
- ~~**v0.26.x** — Voice search in-app~~ DONE (ACTION_RECOGNIZE_SPEECH intent)
- ~~**Wear OS**~~ COVERED — no code release, Wear OS 3+ system mirror is sufficient
- ~~**v0.27.x** — Multi-server unified search~~ DONE (`Track.serverId` + `SubsonicResolver` fan-out)
- ~~**v0.27.1** — Kotlin compile fix~~ DONE (voice search regression — v0.26/v0.27 CI both failed; v0.27.1 is first APK past it)
- ~~**v0.28.0** — Widget artwork v2 + Subsonic admin scan~~ DONE
- ~~**v0.29.0** — Audio routing info line on Now Playing~~ DONE (closes Combo 2 visually — no loop-back hardware required)
- **v0.30.x** (optional) — Last.fm direct scrobble OR i18n; pick whichever you actually need next
- **v1.0.0** — first "release" milestone after a real-device validation pass on every section of `TEST_PLAN.md`. All required-for-1.0 features ship; what's left is genuinely optional

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
