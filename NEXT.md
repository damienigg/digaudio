# Resume — next session

## Where we left off (morning of 2026-05-27, second pass)

**Shipped this morning** (back-to-back): v0.29.0 (audio routing info
line on Now Playing) → v0.30.0 (Last.fm direct scrobble — closes the
Navidrome → Last.fm gap with a 2-step browser-handshake auth flow).

**Roadmap state**: A/B/C/D/E/F/H **complete**. Only G has one entry
left (i18n FR — explicitly post-v1.0). All four combos
(Recommendation engine / Pro-listener / Friend-share / Daily driver)
are **complete**. The app is feature-complete vs Substreamer /
Symfonium; what's left is pure real-device validation +
optional FR translation.

## First 5 minutes — install + smoke test v0.30.0

```bash
# Grab the latest signed APK from the v0.30.0 release
gh release download v0.30.0 -p '*.apk' -O /tmp/digaudio-v0.30.0.apk
adb install -r /tmp/digaudio-v0.30.0.apk
adb shell am start -n com.digaudio.digaudio/.MainActivity
```

**Prerequisite for the Last.fm card to be usable**: add a new GH repo
secret `LASTFM_SHARED_SECRET` (alongside the existing `LASTFM_API_KEY`).
Grab the secret from your existing Last.fm API account at
`last.fm/api/account/your` → Application details → Shared secret. Once
added, push any commit (or re-run CI manually) to bake a new APK that
includes the secret in the dart-defines.

Smoke checks (v0.30.0 + carryover):

-1. **Last.fm direct scrobble** (after `LASTFM_SHARED_SECRET` set) —
   Settings → Playback → "Last.fm" card → tap "Connect Last.fm" →
   browser tab opens at `last.fm/api/auth/?...` → tap "Yes, allow
   access" → return to app → tap "I approved — finish" → green
   check + your username appears. Play any track → check
   `last.fm/user/<you>` shows it within ~1 s (Now-Playing) and ~1 min
   after the 4-min threshold (definitive scrobble).

0. **Audio routing line** — open Now Playing on any track. → A small
   line under the artist reads e.g. `FLAC · 24-bit/96 kHz · 938 kbps
   → Speaker · 48 kHz ⚠` (amber when source ≠ output mix rate),
   or `FLAC · 24-bit/96 kHz · 938 kbps → USB: FiiO Q3 · 96 kHz`
   (neutral grey when matched). Plug a USB DAC mid-track → line
   updates on next track change (it polls on track switch, not
   live). For local files / stock-Subsonic tracks, sample-rate
   fields drop out — line still shows codec + device.

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

## Open follow-ups (post 2026-05-27 audit + v0.30.0 ship)

Zero required code items remain before v1.0.0. The two open
threads:

### User-side prerequisite — add `LASTFM_SHARED_SECRET` to repo secrets

The v0.30.0 build threads `LASTFM_SHARED_SECRET` (new GH repo
secret) into the dart-defines. Without it, the Settings card greys
out and the user can't connect to Last.fm. Add the secret once
from `last.fm/api/account/your` → Application details → Shared
secret. After that's added, any subsequent release build picks
it up automatically.

### Post-v1.0 (optional) — i18n FR

Bootstrap is mechanical (~15 min): `flutter_localizations` + `intl`
deps, `l10n.yaml`, ARB scaffold. Then every `'...'` UI literal
becomes `AppLocalizations.of(context)!.someString` (~2-3 h
mechanical work). Trigger: if you actually want the app in FR.
Otherwise skip — English works fine for a French speaker today.

### Verify-only (no code — covered visually by v0.29.0 line)

FLAC end-to-end and wired-DAC routing are now both checkable at
a glance via the Now Playing audio info line (codec · bit-depth/sr
+ device · output sr, amber + ⚠ on resampling). Plugging in a DAC
or playing a 96 kHz FLAC is enough; no loop-back hardware needed.

## Path to v1.0.0

What gates v1.0.0 = a real-device pass on every section of
`TEST_PLAN.md`. The TEST_PLAN now covers everything through
v0.30.0 (widget, voice search, multi-server search, Wear OS mirror,
admin scan, audio routing info line, Last.fm direct scrobble).
**No code remaining**. Post-v1.0: i18n FR is the only remaining
open item, untaken until you actually want the app in French.

## Environment reminders

- **Phone**: Samsung `R5GL21FEWCR`, USB debugging enabled.
- **Subsonic server**: only reachable via **Tailscale** — Tailscale
  must run on the phone (or laptop, for the standalone probe).
- **Local creds for build-time URL injection**: `tool/run.sh` (gitignored).
- **GitHub Actions secrets**: `SUBSONIC_URL`, `SUBSONIC_LABEL`,
  `KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`,
  `LASTFM_API_KEY` (read-only ranker), `LASTFM_SHARED_SECRET`
  (v0.30.0 — unlocks direct scrobble; until you add this secret
  the Settings → Last.fm card stays greyed out).

## Debug commands if something feels off

```bash
adb logcat -d 2>&1 | grep -iE "flutter|digaudio" | grep -iE "error|exception|fatal" | tail -20
adb shell dumpsys activity activities | grep ResumedActivity
dart run tool/probe_subsonic.dart 'https://damienigg-nas.tail401ff3.ts.net:30028' 'damien' 'abcdef1011'
```

`CHANGELOG.md` lists each version's deltas if a regression is suspected.
`TODO.md` is the live source of truth for what remains; `FEATURES.md`
is the shipped-features index; this NEXT.md is the bedtime brief.
