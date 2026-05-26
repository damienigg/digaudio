# Acceptance test plan — digaudio (v0.30.0)

Real-device walk-through. Tag v1.0.0 only after every section is ticked. Each item is self-contained: it states where you start, what to tap, and what to see. If a step fails, file an issue or ping in chat with the exact section name + tap sequence + actual behaviour.

**Phone**: Samsung Galaxy `R5GL21FEWCR` (or any Android 10+ phone with USB debugging enabled). **Connectivity**: Tailscale must be on the phone for the Subsonic server to be reachable.

---

## 0 · Install

- [ ] **APK installed**. From the v0.30.0 GitHub release: `gh release download v0.30.0 -p '*.apk' -O /tmp/digaudio.apk && adb install -r /tmp/digaudio.apk && adb shell am start -n com.digaudio.digaudio/.MainActivity`. → App opens to Home.
- [ ] **At least one Subsonic server is configured + active**. Settings → Servers. If the build had `SUBSONIC_URL` baked in, it appears pre-filled. → A green check sits next to the active server.
- [ ] **At least one local audio file is on the device** (any MP3 / FLAC under `/sdcard/Music/`).
- [ ] **Library cache is synced once**. Settings → Playback → "Subsonic library cache" → tap "Sync now" if it shows 0 songs. → Count becomes non-zero (~thousands depending on library size).

---

## 1 · Playback basics

Start from Home.

- [ ] **Play a Subsonic track via Search**. Search tab → type a known title → tap a result. → Now Playing opens, audio starts within 1–2 s, artwork visible.
- [ ] **Play a local track**. Library → Tracks → tap any local-origin track (no "· server" suffix). → Same behaviour.
- [ ] **Background playback survives screen-off**. While playing, press the power button → wait 30 s → press power again. → Audio still playing; lockscreen shows artwork + transport controls.
- [ ] **Notification controls**. Pull down the notification shade during playback. → Compact + expanded notification controls are present and functional (play/pause, prev, next).
- [ ] **Notification rich actions** (v0.23.1). On the expanded notification: tap the 10-second-back arrow → audio rewinds 10 s. Tap the 10-second-forward arrow → audio jumps forward 10 s.

---

## 2 · Now Playing — Player tab

Open Now Playing (tap the mini-player) → Player tab.

- [ ] **Full-screen artwork** renders for Subsonic tracks (local tracks fall back to a soft placeholder when no embedded art).
- [ ] **Colour-tint background gradient**. → A soft gradient of the dominant artwork colour fades from top to bottom. (Disable check: Settings → Display → "Now Playing tint" off → gradient disappears next track switch.)
- [ ] **Audio routing info line** (v0.29.0). A small line under the artist reads e.g. `FLAC · 24-bit/96 kHz · 938 kbps  →  Speaker · 48 kHz ⚠`. Verify the matrix:
  - **Built-in speaker, mismatched rates** (e.g. 96 kHz source on 48 kHz mix) → line is amber + ⚠.
  - **Matched rates** (e.g. 48 kHz source on 48 kHz mix) → line is neutral grey, no ⚠.
  - **Plug a USB DAC** → after the next track switch, device segment reads `USB: <product name> · <output kHz>`.
  - **Connect Bluetooth A2DP** → after next track switch, `Bluetooth: <device> · 48 kHz`.
  - **Wired 3.5 mm headphones** → `Wired · …`.
  - **Local file** → source segment shows only the codec (no sample rate / bit depth); output still renders.
  - **Stock-Subsonic track** (no OpenSubsonic `samplingRate` field) → source shows codec + bit-rate only; resampling can't be detected → line stays neutral.
- [ ] **Heart toggle**. Tap the heart icon next to the title → fills + turns accent green. Tap again → empties.
- [ ] **Position scrubber**. Drag the slider. → Audio seeks accordingly.
- [ ] **Transport**. Tap shuffle → goes accent green; queue is genuinely re-ordered (next track is no longer the album's track 2). Tap prev → previous track. Tap play/pause → toggles. Tap next → next track. Tap repeat → cycles off / one / all.
- [ ] **Up Next strip**. → Below the transport, the next 3 queued tracks appear. Tap one → jumps to that track.

## 3 · Now Playing — AppBar actions

Still on Now Playing.

- [ ] **Album mode**. Tap the album icon (AppBar). → Icon turns accent green; tooltip "Cancel album-end stop". Let the album finish. → Playback pauses when the last track ends; icon returns to outlined.
- [ ] **Speed**. Tap the "1.0x" pill → pick 1.5×. → Audibly faster. Close + re-open app. → Pill still shows "1.5x" (persisted).
- [ ] **Sleep timer (countdown)**. Tap bedtime icon → "5 minutes". → Bedtime icon active + "5:00" countdown next to it. Let it tick down.
- [ ] **Sleep timer fade-out** (v0.23.0). When the countdown reaches 0:10 → volume audibly ramps down across 10 s. At 0:00 → playback pauses. Volume is restored to its pre-fade value on the next play.
- [ ] **Sleep timer end-of-track**. Tap bedtime icon → "Stop at end of current track". → Bedtime icon active, no countdown. → Pauses at the end of the current track.
- [ ] **Cancel timer**. Tap bedtime icon → "Cancel timer". → Indicator disappears; current track keeps playing.
- [ ] **Share track**. Tap the share icon (AppBar). → System share sheet opens with `Listening to <title> — <artist>  ·  via digaudio`.

## 4 · Now Playing — Queue + Lyrics

- [ ] **Queue tab — drag to reorder**. Now Playing → Queue tab → long-press a row's trailing drag-handle → drag up or down → release. → Order persists; audio uninterrupted.
- [ ] **Queue tab — swipe to remove**. Swipe a non-current row left. → Red background flashes; row dismissed; queue length shrinks by 1.
- [ ] **Lyrics — synced**. Now Playing → Lyrics tab. For a track with synced lyrics on the Subsonic server (OpenSubsonic `getLyricsBySongId`). → Lines render; active line is accent + larger; view auto-scrolls.
- [ ] **Lyrics — plain fallback**. For a track without synced lyrics but with plain ones. → Plain text block, no highlighting.
- [ ] **Lyrics — none**. Track with no lyrics at all. → "No lyrics available."

---

## 5 · Library browsing

From the bottom-nav, tap **Library**.

- [ ] **6 sub-tabs visible**: Tracks / Albums / Artists / Genres / Decades / Playlists.
- [ ] **Tracks** — list populated; tap any → plays.
- [ ] **Albums** — grid populated; tap one → Album page (tracklist + Play / Shuffle header) → tap Play → queue = full tracklist in order.
- [ ] **Artists** — list populated. Scroll: a vertical alphabetical strip on the right lets you jump to any letter.
- [ ] **Tap an artist** → discography page → tap an album → tracklist.
- [ ] **Genres** — list of genres with counts. Tap one → page with Play all + Shuffle.
- [ ] **Decades** — 1970s / 1980s / etc. Tap one → same UX as Genres.
- [ ] **Playlists** — shows both local + Subsonic playlists, plus Favorites / Wishlist / Smart playlists / Stats entries.

---

## 6 · Search

From bottom-nav, tap **Search**.

- [ ] **Type a 2-3 letter query**. → Results appear within ~50-280 ms (FTS local hits are instant; remote merges in shortly after).
- [ ] **Accent-insensitive**. Type "cafe". → Finds tracks containing "Café" or "Cafe".
- [ ] **Prefix-AND**. Type `daf pun` (with space). → Finds "Daft Punk".
- [ ] **"Show more"** in any section with ≥ 20 results. → Section grows by 20.
- [ ] **Local + remote mix**. Type a term matching both. → Local tracks first, then remote.
- [ ] **Works offline**. Airplane mode + type a known term. → FTS-cached results still appear (remote silently skipped).
- [ ] **Voice search** (v0.26.0). Tap the mic icon in the Search AppBar. → Google "Listening…" dialog opens. Speak a track / artist / album. → Dialog closes; text drops into the field; results appear immediately (no debounce wait).
- [ ] **Voice search cancel**. Tap mic → tap outside the dialog. → Field unchanged; no error.

### 6a · Multi-server search (only with ≥ 2 servers)

Add a second Subsonic server first (Settings → Servers → "Add server").

- [ ] **Both servers' results appear**. Search a term known to exist on both. → Mixed result list; each row's subtitle ends with ` · <server label>`. Single-server users see no label (clean subtitle).
- [ ] **Cross-server playback**. Tap a track from the **non**-active server. → Streams from the originating server (no 404); cover art renders.
- [ ] **One server offline**. Disconnect one of two servers (URL unreachable). → Other server's results still appear; no error banner blocks the page.

---

## 7 · Smart playlists

Library → Playlists → "Smart playlists".

- [ ] **4 builtins seeded first run**: "All time random", "80s revival", "90s revival", "Recent (year−4 → year)".
- [ ] **All time random plays**. Tap → 50 random tracks; Play all / Shuffle header at top.
- [ ] **Decade filter works**. Tap "90s revival" → at least one displayed track has a 199x year.
- [ ] **Create a v1 custom rule**. "+ New" → name "Rock 2000s" → `genre eq Rock` AND `year between 2000 2009` → order random → limit 30 → Save. → Plays only Rock 2000-2009.
- [ ] **v2 join — favourite filter**. Create "Recurring favs": `favourite eq Yes AND playCount30d gte 3`. → Lists tracks you favourited AND played ≥ 3 times this month.
- [ ] **v2 join — throwback filter**. Create "Throwback 90s": `favourite eq Yes AND lastPlayedDaysAgo gte 180 AND year between 1990 1999`. → Lists 90s favs you haven't touched in 6+ months (or never).
- [ ] **v2 join — cached state filter**. Create "Offline-ready unplayed": `cached eq Yes AND playCount30d lte 1`. → Tracks on disk barely touched.

---

## 8 · Local + Subsonic playlists

Library → Playlists.

- [ ] **Create local playlist**. ⋮ on any track → "Add to playlist…" → "New playlist…" → name. → Created; visible in Library → Playlists.
- [ ] **Reorder + delete in local playlist**. Open it → long-drag rows; swipe-delete a row. → Persists across app restart.
- [ ] **Export local playlist as JSON**. Open it → menu → Export. → System share sheet opens with the `.json` file.
- [ ] **Import playlist**. Library → Playlists → "Import playlist…" → pick a `.m3u`, `.m3u8`, or `digaudio.json` file. → New local playlist; matched tracks visible, unmatched greyed.
- [ ] **Subsonic playlist plays**. Tap any Subsonic playlist → Play. → Full tracklist queues + starts.

---

## 9 · Track actions + bulk select

- [ ] **Long-press any track** anywhere. → Tile leading swaps to a 36 dp check-circle; **SelectionBar** appears above the mini-player.
- [ ] **Tap (not long-press) more tiles** in the same list. → Each toggles in / out; count updates.
- [ ] **Cross-screen selection**. Long-press a track in Library, navigate to Search, long-press another. → Count = sum.
- [ ] **Bulk Play**. Tap "Play" in the SelectionBar. → Queue replaced; selection clears.
- [ ] **Bulk Add to queue / Play next**. → Appends / inserts after current respectively.
- [ ] **Bulk Add to playlist + favourites**. → All selected tracks affected; selection clears.
- [ ] **Bulk Download** (Subsonic tracks only). → Routes through the background download queue; DownloadBanner appears above mini-player with live progress.
- [ ] **Bulk Cancel** = tap the X in the SelectionBar. → Bar disappears; tiles return to normal.
- [ ] **5-star rating** (Subsonic track via ⋮). Tap any star. → Stars 1-N fill; server receives the rating (re-open the sheet to confirm). Tap the current rating again → clears.
- [ ] **Rating row hidden for local tracks**. ⋮ on a local track → no star row.
- [ ] **Start radio** (Subsonic track via ⋮ → "Start radio"). → Queue = seed + 30 similar; plays.

---

## 10 · Subsonic radio + auto-queue

- [ ] **Radio auto-refills**. Start a radio (above), listen until you're within 3 tracks of the queue end. → 10 more tracks appended without you doing anything.
- [ ] **Radio disengages on user action**. While radio is active, Library → tap an album → Play. → Radio stops refilling silently (verify by listening to the end of the album — no auto-appended tracks).
- [ ] **Empty-radio fallback**. Try radio on a track the server has no similar data for. → Toast "no similar tracks…"; original queue untouched.
- [ ] **Auto-queue (Settings → Playback → Auto-queue ON)**. Start with a single Subsonic track. → Queue tab shows the original + ~3 similar follow-ups appended.

---

## 11 · Playback effects

Settings → Playback.

- [ ] **Crossfade — true overlap**. Set Crossfade → 5 s. Play an album. → Last ~5 s of current track audibly overlap the first 5 s of the next — you should briefly hear **both** simultaneously.
- [ ] **Crossfade off = still gapless**. Crossfade → Off. → Seamless transition with no perceived gap (preloaded secondary swaps in at the end of primary).
- [ ] **Pause during a crossfade**. Trigger one, pause mid-overlap. → Both players pause; resume plays both back.
- [ ] **Skip during a crossfade**. Trigger one, hit skip-next. → Transition cancelled; target track loaded; plays from start.
- [ ] **Replay Gain — Track mode**. Volume normalisation → Track. Play a known-loud track followed by a known-quiet one (Subsonic server must expose `replayGain` — Navidrome does, stock Subsonic ≤ 1.16 doesn't). → Perceived loudness similar.
- [ ] **Replay Gain — Album mode**. Same setup, mode = Album. → Within one album, quiet songs stay quiet relative to loud ones (album RG normalises across albums, not within them).
- [ ] **Replay Gain — Off**. → No volume change between tracks.
- [ ] **Equalizer preset**. Equalizer → enable → tap "Bass boost". → All bands set; bass audibly stronger.
- [ ] **Custom slider after preset**. Pull 60 Hz to +6 dB on top of Bass boost. → Saves as a custom curve (presets are not "modes", they just stamp values).
- [ ] **Per-Bluetooth-device EQ**. Connect a BT headphone → Equalizer → "Per-Bluetooth-device EQ" → "Save current EQ". → Saved. Disconnect + reconnect → profile auto-applies.

---

## 12 · Per-track resume + headphone auto-pause

- [ ] **Pause mid-track + return**. Play a ≥ 3 min track, let it run to ~1:30, pause, switch to a different track, play that. Now go back to the first track. → Playback resumes around 1:30 (not 0:00) once buffered.
- [ ] **Short tracks don't trigger**. Play from start to ~0:05, pause, switch away, return. → Plays from 0:00 (threshold protects against "resume at 0:05" UX).
- [ ] **Wired headphone yank**. Play music with wired headphones plugged → yank them mid-playback. → Playback pauses automatically.
- [ ] **Auto-play on BT connect** (opt-in, Settings → Playback). Pair + connect BT headphones while a paused queue is loaded. → Playback resumes automatically. (Default off — verify default is off if you flip it.)

---

## 13 · Storage + downloads

Settings → Playback → Storage.

- [ ] **Auto-cache toggles a fresh play**. Auto-cache ON. Play a Subsonic track never played before. Let it finish. → Track tile now shows a grey ✓ cached badge.
- [ ] **Cached track plays offline**. Airplane mode. Play the same cached track. → Plays from disk; offline banner appears above mini-player.
- [ ] **Pin a download**. ⋮ on a cached track → "Keep download". → Badge turns accent green ✓.
- [ ] **Remove a download**. ⋮ on a pinned track → "Remove download". → Badge disappears; file gone.
- [ ] **Cache budget enforced**. Storage → Max cache → 512 MB. Play music until close to limit. → Oldest non-pinned tracks evicted; total usage ≤ 512 MB.
- [ ] **"Clear auto-cache" preserves pinned**. With both kinds present, tap "Clear auto-cache". → Auto-cached gone, pinned remain.
- [ ] **Download queue banner**. Select 10+ Subsonic tracks → Bulk → Download. → DownloadBanner appears above mini-player: current track title + queued count + live progress + Cancel button. Tap Cancel → pending cleared; in-flight finishes.

---

## 14 · Scrobbling (3 parallel paths)

### 14a · Subsonic server scrobble

- [ ] **Track-start scrobble**. Start any Subsonic track. → Within ~1 s the Subsonic server logs it as a play (visible in Navidrome's "Now Playing" admin page).
- [ ] **Definitive scrobble at threshold**. Let the track play past 4 min OR past 50 % of duration (whichever is shorter). → Server increments its play count for that track.

### 14b · ListenBrainz direct (after pasting a user token)

- [ ] **Connect**. Settings → Playback → ListenBrainz card → paste a token from `listenbrainz.org/profile/` → green check appears next to "ListenBrainz".
- [ ] **`playing_now` at track start**. Play any track → within ~1 s, your ListenBrainz profile shows it as currently playing.
- [ ] **`single` listen at threshold**. Past the 4-min / 50 % threshold → listen appears in your LB history within ~1 min.

### 14c · Last.fm direct (after `LASTFM_API_KEY` + `LASTFM_SHARED_SECRET` secrets baked in)

Prerequisite check: open Settings → Playback → Last.fm card. If you see "This APK was built without LASTFM_API_KEY / LASTFM_SHARED_SECRET", add both secrets to GitHub repo settings (or pass them via `--dart-define=` on a local build), re-build, re-install, then retry this section.

- [ ] **Step 1 — request token + open browser**. Tap "Connect Last.fm". → The default browser opens at `last.fm/api/auth/?api_key=…&token=…`. In the app, the card switches to "Step 2 of 2: in the browser tab that just opened, click Yes, allow access" + Finish / Cancel buttons.
- [ ] **Step 2 — approve in browser**. In the browser, log in to Last.fm if needed, then click "Yes, allow access". → Browser confirms approval.
- [ ] **Step 3 — finish in app**. Return to digaudio → tap "I approved — finish". → Green check + your Last.fm username appear next to the "Last.fm" heading.
- [ ] **Now-Playing at track start**. Play any track. → Within ~1 s, `last.fm/user/<you>` shows it as "playing now".
- [ ] **Scrobble at threshold**. Past the 4-min / 50 % threshold. → `last.fm/user/<you>` shows the scrobble within ~1 min. Subsonic + LB scrobble counts stay in sync (same threshold).
- [ ] **Cancel mid-flow**. Tap "Connect Last.fm" → don't approve in the browser → return to app → tap "Cancel". → Card returns to "Connect" state; no session key persisted.
- [ ] **Disconnect**. From a connected state, tap "Disconnect Last.fm". → Card returns to "Connect" state. Play another track → no scrobble to Last.fm (Subsonic + LB still scrobble).

---

## 15 · External surfaces

### 15a · Quick Settings tile (v0.20.0)

- [ ] **Add the tile once**. Pull down the notification shade twice → tap the pencil (edit) → find "digaudio" in available tiles → drag into active set.
- [ ] **Tap the tile**. → Toggles play / pause without opening the app.

### 15b · Homescreen widget (v0.25.0 + artwork v0.28.0)

- [ ] **Add the widget once**. Long-press homescreen → Widgets → drag "digaudio" 4×1 cell onto the homescreen.
- [ ] **Cover appears on widget**. Play a Subsonic track. → Within ~1 s the launcher icon is replaced by the album cover (256 px JPEG prefetched + `setImageViewBitmap`).
- [ ] **Pause/resume preserves art**. → Art stays during pause; no re-download, no flicker on resume.
- [ ] **Local track fallback**. Play a track from local MediaStore. → Widget falls back to the launcher icon (local artwork prefetch is deferred; same behaviour as MediaItem `artUri`).
- [ ] **Cross-track flicker is brief**. Skip rapidly between Subsonic tracks. → Each fetch takes 200-500 ms; previous track's art may persist briefly until new one lands. Acceptable.

### 15c · Wear OS mirror (no companion APK)

Skip if you don't have a Wear OS 3+ watch (Pixel Watch / TicWatch / Galaxy Watch).

- [ ] **Pair the watch** with the phone via the Wear OS app.
- [ ] **Add the "Media Controls" tile** on the watch (long-press a watch face → Tiles → add "Media Controls" if absent).
- [ ] **Start playback on phone**, then raise wrist on watch. → Media Controls tile shows title / artist / play-pause / skip.
- [ ] **Tap play/pause on watch**. → Phone playback toggles.
- [ ] **Tap skip on watch**. → Phone advances to next track.

### 15d · Bluetooth controls

- [ ] **BT play/pause/next**. Connect BT headphones → tap the play/pause button on the headphones → tap next. → App responds; lockscreen reflects new state.

### 15e · Android Auto (requires hardware or AA Desktop Head Unit simulator)

- [ ] Connect phone to car head unit (or AA DHU).
- [ ] **digaudio appears in the AA app list**.
- [ ] **Browse tree shows "Favourites / Recently played / Most played"**.
- [ ] **Tapping a leaf starts playback**.
- [ ] **Voice command "Play <song>" works**.

---

## 16 · Server admin (Subsonic admin user only)

Settings → Servers → Edit (your admin server) → "Library scan (admin)" section.

- [ ] **Check status**. Tap "Check status". → "Idle — N songs in the library" or "Scanning…".
- [ ] **Trigger scan**. → "Scanning… N songs indexed so far" updates live; tap "Check status" again later → idle + final count.
- [ ] **Non-admin user**. As a non-admin Subsonic user on a different server, tap "Trigger scan". → "Admin role required on this server." inline (red text); no exception.

---

## 17 · Stats

Library → Playlists → Stats.

- [ ] **Time-window picker** at the top: 30 d / 90 d / all time → tapping each updates the page.
- [ ] **Totals**: plays / unique tracks / listening days.
- [ ] **Streak chips**: current + longest.
- [ ] **Year-grid heatmap** (365 days, GitHub style) renders below totals.
- [ ] **On this day** (same MM-DD in prior years). For installs ≥ 1 year old: tracks listed. For fresh installs: a hint string.
- [ ] **Year-by-year tops** (top 5 per year) at the bottom — each year a block of 5 tracks tappable to play.
- [ ] **Monthly tops** (last 12 months, top 3 each) further down.

---

## 18 · Theme + accessibility

Settings → Display.

- [ ] **Light theme**. Pick "Light". → Entire app switches to a light palette.
- [ ] **Follow system**. Pick "System" → toggle OS dark mode. → App follows.
- [ ] **Material You** (Android 12+). Enable "Use system colours". → Material 3 widgets (FilledButtons, chips, indicators) follow the wallpaper palette. The brand accent `#1ED760` stays green on hearts / EQ-active / transport play button (intentional).
- [ ] **Now Playing tint**. Toggle "Now Playing tint". → Background gradient appears / disappears on next track switch.
- [ ] **TalkBack** (enable in Android Settings → Accessibility → TalkBack). Open digaudio. → Tooltips read out on every IconButton; the alpha-scroll letter strip (Library → Artists) and the year heatmap (Stats) are announced semantically.

---

## 19 · Offline behaviour

- [ ] **Banner appears on server down**. Airplane mode → wait ~60 s. → Amber "Server offline" banner above mini-player.
- [ ] **Banner clears on recover**. Restore network → wait ~60 s. → Banner gone.
- [ ] **Cached track plays in offline mode**. With airplane mode on, play a cached track. → Plays fine. Uncached tracks fail visibly with an error toast.

---

## 20 · Build & release verifications

### 20a · Signed builds (after keystore secrets set in CI)

- [ ] **First install** with the release-signed APK (uninstall any prior debug-signed APK first). → No "unknown source" warning on install (or only once when whitelisting GitHub as a source).
- [ ] **Subsequent updates** install in place without uninstall.

### 20b · Last.fm ranker (after `LASTFM_API_KEY` set)

- [ ] **Subjective check** after a few weeks of use: auto-queue picks "feel" more musically related than just artist/genre matches.

### 20c · Last.fm direct scrobble (after `LASTFM_API_KEY` + `LASTFM_SHARED_SECRET` set)

Covered in §14c above.
