# Resume — next session

## Where we left off

- **v0.8.3** released ([latest](https://github.com/damienigg/digaudio/releases/latest))
  and installed on the Samsung (`R5GL21FEWCR`) via `adb install`. App
  launches, MediaSession registers, **zero Flutter crash**.
- End-to-end Subsonic test on the real phone **was not done** — credentials
  entry + playback verification is the first thing to do.
- Library cache sync also **not run** yet → AutoQueue is on the 200-song
  random fallback until then.

## Tomorrow's first 10 minutes

```bash
adb devices                                    # phone still plugged?
# If still installed, just reopen from the launcher; otherwise:
adb install -r /tmp/digaudio-v0.8.3.apk
adb shell am start -n com.digaudio.digaudio/.MainActivity
```

On the phone:
1. **Settings → Servers** → tap `damienigg-nas` → enter `damien` /
   `abcdef1011` → **Test & save** → "Connected."
2. **Home** populates (Newest releases + Random picks).
3. **Settings → Playback → Sync library** (~1-2 min over Tailscale, ~1000
   albums). After: AutoQueue scores against the whole library.
4. Tap a track, verify lockscreen / notification / Bluetooth controls.

## Open follow-ups (deferred, in priority order)

1. **Last.fm augmentation** — `track.getSimilar` as a ranker on top of the
   metadata score; API key baked via `--dart-define` from a
   `LASTFM_API_KEY` repo secret. Fallback to pure-metadata scoring if the
   call fails. Decide **after** real-use feel of the current scoring.
2. **Release keystore** — drop the "unknown source" install warning.
   One-line `android/app/build.gradle` change + base64-encoded keystore in
   a `KEYSTORE_BASE64` repo secret + `KEYSTORE_PASSWORD` secret.
3. **"Downloaded" badge** on the track tile — currently the cache state
   only surfaces in the actions sheet on long-press.
4. **Synced lyrics** via OpenSubsonic `getLyricsBySongId` (we only read
   unsynced via `getLyrics` today).
5. **Lidarr wishlist push** — `POST /api/v1/album/lookup → /api/v1/album`
   on wishlist add. Hook is documented at the top of
   `lib/library/wishlist.dart`. Needs a Lidarr settings page (URL + key).

## Environment reminders

- **Phone**: Samsung `R5GL21FEWCR`, USB debugging enabled.
- **Subsonic server**: only reachable via **Tailscale** — Tailscale must
  run on the phone (or laptop, for the standalone probe).
- **Local creds for build-time URL injection**: `tool/run.sh` (gitignored).
- **GitHub Actions secrets**: `SUBSONIC_URL`, `SUBSONIC_LABEL`.

## Debug commands if something feels off

```bash
adb logcat -d 2>&1 | grep -iE "flutter|digaudio" | grep -iE "error|exception|fatal" | tail -20
adb shell dumpsys activity activities | grep ResumedActivity
dart run tool/probe_subsonic.dart 'https://damienigg-nas.tail401ff3.ts.net:30028' 'damien' 'abcdef1011'
```

`CHANGELOG.md` lists each version's deltas if a regression is suspected.
