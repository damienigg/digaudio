# Resume — next session

## Where we left off (end of session 2026-05-26)

**Shipped tonight**: v0.27.0 (multi-server search) → v0.27.1 (Kotlin
compile fix — v0.26 + v0.27 CI were both red because `flutter analyze`
doesn't compile Kotlin) → v0.28.0 (widget artwork v2 + Subsonic admin
scan). v0.27.1 is the first APK past the Kotlin regression.

**Roadmap state**: A/B/C/D/F/H categories are now **complete** (D
closed by widget art v2 tonight; F was closed by v0.27.0 multi-server
search). Combo 1 + Combo 4 both **5/5 ✓**. Combo 2 is 4/6 with the
remaining items being verify-only (no code — needs real FLAC + USB
DAC). Two real polish items deliberately deferred: **Last.fm direct
scrobble** and **i18n**. The app is feature-complete vs Substreamer /
Symfonium; what's left is genuinely optional.

## Tomorrow's first 5 minutes — install + smoke test v0.28.0

```bash
# Grab the latest signed APK from the v0.28.0 release
gh release download v0.28.0 -p '*.apk' -O /tmp/digaudio-v0.28.0.apk
adb install -r /tmp/digaudio-v0.28.0.apk
adb shell am start -n com.digaudio.digaudio/.MainActivity
```

Smoke checks specific to what shipped tonight:

1. **Widget artwork** — long-press homescreen → Widgets → drag
   "digaudio". Play a Subsonic track. → Cover art appears on the
   widget within ~1 s of track change (Dart prefetch → tmp JPEG →
   Kotlin `setImageViewBitmap`). Pause/resume preserves the art
   (no re-download).
2. **Voice search** — Search tab → mic icon → speak. → Google
   "Listening…" dialog → text drops into the field → results
   appear immediately (v0.27.1 verified the regression fix).
3. **Multi-server search** — Settings → Servers → add a second
   server with credentials → activate either one → Search a term
   known to exist on both. → Results from both appear, subtitle ends
   with " · <server label>". Tap a track from the **non**-active
   server. → Streams from the originating server (not 404). Cover
   art renders.
4. **Admin scan** — Settings → Servers → Edit (your admin server) →
   "Library scan (admin)" section → tap "Check status" → shows
   "Idle — N songs". Tap "Trigger scan" → shows "Scanning… N songs
   indexed so far" while it runs.
5. **Wear OS mirror** (if you have one) — pair Pixel Watch /
   TicWatch → play on phone → Media Controls tile on the watch
   shows transport. No app code on the watch — system handles it.

## Open follow-ups (deferred, ordered by impact)

### Genuinely useful next sessions (own-session items)

1. **Last.fm direct scrobble** (M, deferred from v0.28 bundle)
   - Why deferred: needs `LASTFM_SHARED_SECRET` added to GH repo
     secrets + `url_launcher` dep + browser-roundtrip auth flow
     (request token → open `last.fm/api/auth/?api_key=X&token=Y` in
     browser → user approves → app calls `auth.getSession` → stores
     session key). Not big code-wise but UX flow wants careful walk.
   - Today: Subsonic-side scrobble already forwards to Last.fm when
     the server is configured, so this is only useful if your
     Subsonic doesn't have LFM integration.
   - First step tomorrow: decide whether you want it at all (the
     existing Subsonic→LFM path may already cover you).

2. **i18n (FR translation)** (hours of focused work)
   - Bootstrap is mechanical (~15 min): add `flutter_localizations`
     + `intl` deps, `l10n.yaml` config, ARB scaffold.
   - Then: every `'...'` literal across ~30-40 UI files becomes
     `AppLocalizations.of(context)!.someString`. Probably ~2-3 h of
     mechanical work + a translation pass.
   - Triggers: if you actually want the app in French. Otherwise
     skip — the codebase already works in English for any English
     speaker.

### Optional ambitious chunks (no commitment)

3. **Album-art waveform scrubber** (L) — precomputed PCM peaks from
   FLAC/MP3 headers, cached alongside the audio file. Visual upgrade
   + faster scrubbing reference. Niche but slick.
4. **BPM-matched crossfade** (L) — detect BPM (Subsonic metadata or
   in-app FFT estimate), skip the crossfade if next track has a
   wildly different tempo. Niche but unique.
5. **Listening parties / shared queue** (L) — real-time playback-state
   sync across multiple devices (WebSocket relay or Tailscale-local
   mesh). Deferred indefinitely — no real use case yet.

### Verify-only (no code — needs hardware)

6. **FLAC end-to-end** — play a FLAC on real device, confirm
   bit-perfect through Android's audio routing.
7. **Wired USB DAC** — plug one in, confirm Android routes to it.

## Path to v1.0.0

What gates v1.0.0 = a real-device pass on every section of
`TEST_PLAN.md`. The TEST_PLAN already covers everything that shipped
in v0.22.x → v0.28.0 (widget, voice search, multi-server search,
Wear OS mirror, admin scan). No code change required for v1.0.0 —
just walking through `TEST_PLAN.md` on the phone and fixing whatever
shows real-world quirks.

After v1.0.0, the deferred items (Last.fm direct, i18n, waveform,
BPM-match, parties) become "post-1.0 nice-to-haves" without a
roadmap commitment.

## Environment reminders

- **Phone**: Samsung `R5GL21FEWCR`, USB debugging enabled.
- **Subsonic server**: only reachable via **Tailscale** — Tailscale
  must run on the phone (or laptop, for the standalone probe).
- **Local creds for build-time URL injection**: `tool/run.sh` (gitignored).
- **GitHub Actions secrets**: `SUBSONIC_URL`, `SUBSONIC_LABEL`,
  `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`,
  `LASTFM_API_KEY` (read-only ranker; **not** the same as the
  `LASTFM_SHARED_SECRET` that direct-scrobble would need).

## Debug commands if something feels off

```bash
adb logcat -d 2>&1 | grep -iE "flutter|digaudio" | grep -iE "error|exception|fatal" | tail -20
adb shell dumpsys activity activities | grep ResumedActivity
dart run tool/probe_subsonic.dart 'https://damienigg-nas.tail401ff3.ts.net:30028' 'damien' 'abcdef1011'
```

`CHANGELOG.md` lists each version's deltas if a regression is suspected.
`TODO.md` is the live source of truth for what remains; `FEATURES.md`
is the shipped-features index; this NEXT.md is the bedtime brief.
