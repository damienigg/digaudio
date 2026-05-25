# User test plan — digaudio (v0.21.2)

Phone-side acceptance checklist. Run through each section; tick the box when verified. Failures: file an issue or ping in chat with the exact steps + actual result.

## Prerequisites

- [ ] APK installed (v0.21.2 or later)
- [ ] At least one Subsonic server configured & active (Settings → Servers)
- [ ] At least one local audio file on device (`/sdcard/Music/*.flac|mp3|…`)
- [ ] (Required for many features) Library cache synced once: Settings → Playback → Storage shows "Subsonic library cache" with non-zero count

## Playback basics

- [ ] **Play a Subsonic track from search**. Type in Search, tap result. → Now Playing opens, audio starts within 1–2 s, artwork visible
- [ ] **Play a local track from Library → Tracks**. → Same UX as Subsonic
- [ ] **Background playback survives screen-off**. Play, lock screen, wait 30 s. → Still playing; lockscreen shows artwork + transport
- [ ] **Bluetooth play/pause/next**. Connect BT headphones, tap pause on headphones, tap next. → App responds, lockscreen reflects new state
- [ ] **Notification controls**. Pull down notification shade during playback. → Compact + expanded controls present, all functional

## Queue & navigation

- [ ] **Album play-all**. Open any album, tap play. → Queue = full tracklist in order, plays from track 1
- [ ] **Play next** via ⋮ button. → Track inserted right after current
- [ ] **Add to queue** via ⋮ button. → Track appended at end of Now Playing → Queue tab
- [ ] **Skip prev / next** from Now Playing transport. → Moves through queue cleanly
- [ ] **Scrubber**. Drag the position slider. → Audio seeks to that point
- [ ] **Shuffle on/off**. Toggle shuffle icon. → Becomes accent green when active; queue is genuinely re-ordered (engine-level shuffle now)
- [ ] **Repeat off/one/all** (cycle). Tap repeat icon. → Cycles through 3 states; LoopMode.one loops seamlessly via just_audio; LoopMode.all wraps the queue from end to 0
- [ ] **Up Next strip**. Play a Subsonic album with autoqueue. → Strip below transport shows next 3 tracks; tap one → jumps to it

## Queue editor (v0.16.0)

- [ ] **Drag-to-reorder**. Now Playing → Queue tab → drag a row's trailing handle up/down. → Order persists, audio uninterrupted
- [ ] **Swipe-to-remove**. Swipe a non-current row left. → Row dismissed with red background; track removed from queue

## Album mode (v0.16.0)

- [ ] **Stop at end of album**. Play any album. On Now Playing, tap the album icon (AppBar). → Icon turns accent green. When the last track of the album finishes, playback pauses; icon returns to outlined

## Per-track resume (v0.16.1)

- [ ] **Pause mid-track + return**. Play a long track (≥3 min), let it run to ~1:30, pause, switch to a different track, play. Now go back to the first track. → Playback resumes around 1:30 (not 0:00) once buffered
- [ ] **Short tracks don't trigger**. Play a track from start to ~0:05, pause, switch away, return. → Plays from 0:00 (threshold protects against "resume at 0:05" UX)

## True crossfade (v0.18.0) — **important regression check**

- [ ] **Overlap audible**. Settings → Playback → Crossfade → 5 s. Play an album. → Last ~5 s of current track audibly overlaps the first 5 s of the next — you should briefly hear **both** simultaneously
- [ ] **No overlap = still gapless**. Crossfade → Off. Same album. → Seamless transition with no perceived gap (preloaded secondary swaps in at the moment primary ends)
- [ ] **Pause during fade**. Trigger a crossfade, hit pause mid-overlap. → Both players pause; resume plays both back
- [ ] **Skip during fade**. Trigger a crossfade, hit skip-next. → Transition cancelled, secondary silenced, target track loaded on primary, plays from start

## Auto-cache + downloads

- [ ] **Auto-cache toggles a fresh play**. Auto-cache ON, play a Subsonic track never played before. Wait for it to finish. → Track tile now shows grey ✓ cached badge
- [ ] **Cached track plays offline**. Airplane mode. Play the same cached track. → Plays from disk; offline banner appears
- [ ] **Pin a download**. ⋮ on cached track → "Keep download". → Badge turns green ✓
- [ ] **Remove a download**. ⋮ on pinned track → "Remove download". → Badge disappears; file gone
- [ ] **Cache budget enforced**. Settings → Playback → Storage → Max cache to 512 MB. Play music until limit approaches. → Oldest non-pinned tracks evicted; usage ≤ 512 MB
- [ ] **"Clear auto-cache" preserves pinned**. With both kinds present, tap "Clear auto-cache". → Auto-cached gone, pinned remain

## Favourites & ratings

- [ ] **Heart on Now Playing**. Play any track, tap heart icon next to title. → Icon fills + turns green; tile badge appears everywhere
- [ ] **5-star rating** on Subsonic track via ⋮ → tap a star. → Stars 1–N fill, server receives the rating (re-open sheet to confirm)
- [ ] **Clear rating**. Tap the current rating star again. → Stars clear
- [ ] **Rating row hidden for local tracks**. ⋮ on a local track. → No star row

## Bulk select (v0.16.3, polished v0.21.2)

- [ ] **Enter select mode**. Long-press any track tile. → Tile leading swaps to a 36 dp check-circle; SelectionBar appears above mini-player
- [ ] **Toggle more in same list**. Tap (not long-press) other tiles. → Each toggles in/out; count updates
- [ ] **Cross-screen selection**. Select in Library, navigate to Search, long-press a track there. → Count = sum of both
- [ ] **Bulk Play**. Tap "Play" in the bar. → Queue replaced; selection clears
- [ ] **Bulk Add to queue / Play next**. → Appends / inserts after current respectively
- [ ] **Bulk favourite / add to playlist**. → All selected tracks treated; selection clears
- [ ] **Cancel**. Tap X. → Bar disappears, tiles return to normal

## Playlists

- [ ] **Create local playlist**. ⋮ → "Add to playlist…" → "New playlist…" → name. → Created in Library → Playlists → Local
- [ ] **Reorder + delete in local playlist**. Open it, long-drag rows, swipe delete. → Persists across app restart
- [ ] **Export local playlist as JSON**. Open → menu → Export. → Share sheet opens with `.json`
- [ ] **Import playlist**. Library → Playlists → "Import playlist…" → pick `.m3u` or `.json`. → New local playlist; matched tracks visible, unmatched greyed
- [ ] **Subsonic playlist plays**. Library → Playlists → tap any Subsonic playlist → Play. → Full tracklist queues + starts

## Smart playlists (v0.15.3 + v0.21.0 v2 joins)

### v1 builtins (seeded first run)
- [ ] **4 builtins present**. Library → Playlists → "Smart playlists". → Lists "All time random", "80s revival", "90s revival", "Recent (year−4 → year)"
- [ ] **All time random plays**. Tap → 50 random tracks; Play all / Shuffle header
- [ ] **Decade filter works**. Tap "90s revival" → at least one displayed track has a 199x year

### v1 custom rule
- [ ] **Create a custom column-based playlist**. "+ New" → name "Rock 2000s" → add `genre eq Rock` + `year between 2000 2009` → order random → limit 30 → Save. → Plays only Rock 2000–2009

### v2 joins (the powerful ones)
- [ ] **Favourite filter**. Create "Recurring favs": `favourite eq Yes AND playCount30d gte 3`. → Lists tracks you favourited AND played ≥3 times this month
- [ ] **Throwback filter**. Create "Throwback 90s": `favourite eq Yes AND lastPlayedDaysAgo gte 180 AND year between 1990 1999`. → Lists 90s favs you haven't touched in 6+ months (or never)
- [ ] **Cached state filter**. Create "Offline-ready unplayed": `cached eq Yes AND playCount30d lte 1`. → Tracks on disk that you've barely touched

## Genre + Decade browsers (v0.15.1)

- [ ] **Genres tab populated**. Library → Genres. → List of genres with counts
- [ ] **Decades tab populated**. Library → Decades. → 1970s / 1980s / etc.
- [ ] **Tap a genre → page loads + plays**. → All tracks of that genre; Play all queues + starts
- [ ] **Tap a decade → same**. → Tracks of that decade

## Subsonic radio (v0.15.2 + v0.21.1 auto-refill)

- [ ] **Start radio**. ⋮ on a Subsonic track → "Start radio". → Queue = seed + 30 similar; plays
- [ ] **Auto-refill**. Listen until you're within 3 tracks of the end. → 10 more tracks appended without you doing anything; refill seeded by the queue's tail
- [ ] **Self-disengages**. While radio is active, navigate to Library → tap an album → Play. → Radio stops refilling silently (verify by listening to the end of the album — no more auto-appended tracks)
- [ ] **Empty fallback**. Try radio on a track the server has no similar data for. → Toast "no similar tracks…"; original queue untouched

## Stats — On-this-day + Year-by-year (v0.15.0)

- [ ] **On this day**. → For installs ≥1 year old: tracks played same MM-DD in prior years. Fresh installs: hint text
- [ ] **Year-by-year**. → For each year present in history, one block with top 5 tracks (tap to play)

## Search (FTS-first, v0.19.0)

- [ ] **Type query → results appear instantly**. Type 2-3 letters. → Results within ~50–280 ms (FTS hits are instant; remote search adds new tracks ~280 ms later)
- [ ] **Accent-insensitive**. Type "cafe". → Finds tracks containing "Café" or "Cafe"
- [ ] **Prefix-AND**. Type "daf pun" (with space). → Finds "Daft Punk"
- [ ] **"Show more"** in any section with ≥20 results. → Section grows by 20
- [ ] **Local + remote mix**. Type a term matching both local and Subsonic. → Local tracks first, then remote
- [ ] **Works offline**. Airplane mode + type a known term. → FTS-cached results still appear (remote is silently skipped)
- [ ] **Voice search** (v0.26.0). Tap the mic icon in the Search AppBar. → Google "Listening…" dialog → speak a track / album / artist name → dialog closes → text appears in the field → results appear immediately (no debounce wait)
- [ ] **Voice search cancel**. Tap mic → tap outside the dialog. → Field unchanged
- [ ] **Voice search — no recogniser**. On a device with no Google speech app (rare). → Mic tap is silently no-op (graceful fallback)

## Sleep timer + speed + crossfade

- [ ] **Sleep timer 5 min** from Now Playing AppBar (bedtime icon). → Countdown badge appears; ticks down; pauses at 0
- [ ] **Sleep timer "end of track"**. → Bedtime icon active, no countdown; pauses at next track end
- [ ] **Cancel timer**. → Badge disappears
- [ ] **Speed 1.5×**. Tap "1.0x" → 1.5×. → Audibly faster
- [ ] **Speed persists** across app restart. → AppBar still shows the previously-set speed

## Equalizer (v0.17.0 presets + v0.17.3 per-BT)

- [ ] **Preset chip**. Settings → Playback → Equalizer → enable → tap "Bass boost". → All bands set to preset values; bass audibly stronger
- [ ] **Custom slider after preset**. Pull 60 Hz to +6 dB on top of Bass boost. → Saves as custom (presets are not "modes" — they just write values)
- [ ] **Per-BT EQ**. Connect a BT headphone → Settings → Playback → Equalizer → "Per-Bluetooth-device EQ" → "Save current EQ". → Saved. Disconnect + reconnect → profile auto-applies

## Replay Gain (v0.17.2)

- [ ] **Track mode evens out loud / quiet**. Settings → Playback → Volume normalisation → Track. Play a known loud track followed by a known quiet one (Subsonic server must expose `replayGain` — Navidrome does, stock Subsonic ≤ 1.16 doesn't). → Perceived loudness similar between the two
- [ ] **Album mode preserves intra-album dynamics**. Same setup, mode = Album. → Within one album, quiet songs stay quiet relative to loud ones (album RG normalises across albums, not within)
- [ ] **Off behaves as before**. Mode = Off. → No volume change between tracks

## Auto-queue

- [ ] **Lookahead fills the queue**. Auto-queue ON. Start with a single track. → Queue tab shows the original + ~3 similar follow-ups

## Sleep auto-pause via headphone unplug

- [ ] **Yank wired headphones during playback**. → Playback pauses automatically (`audio_session.music` config handles this)
- [ ] **Auto-play on BT connect** (opt-in, Settings → Playback). Pair + connect BT headphones while a paused queue is loaded. → Playback resumes automatically

## Quick Settings tile (v0.20.0)

- [ ] **Add the tile once**. Pull down notif shade twice → tap edit (pencil) → find "digaudio" in available tiles → drag into active set
- [ ] **Tap the tile**. → Toggles play/pause without opening the app

## Material You (v0.20.1, Android 12+)

- [ ] **Toggle on**. Settings → Display → "Use system colours". → Material 3 widgets (FilledButtons, chips, indicators) follow the wallpaper palette
- [ ] **Brand accent splashes still green**. → Heart icons, EQ-active, transport play button stay `#1ED760` regardless (intentional, brand)

## Settings — servers

- [ ] **Add a 2nd server**. Settings → Servers → "Add server" → URL + creds → "Test & save". → "Connected"; appears in list
- [ ] **Switch active server**. Tap any inactive server. → Active checkmark moves; Home reloads
- [ ] **Delete a non-builtin server**. Edit → trash → confirm. → Disappears

## Settings — display

- [ ] **Light theme**. Settings → Display → Light. → Entire app switches (some widgets retain dark-ish tones — the Colors.white* migration in v0.12.0 covered most but not all)
- [ ] **Follow system**. Toggle OS dark mode. → App follows
- [ ] **Now Playing tint toggle**. → Toggle controls whether the background gradient appears

## Offline behaviour

- [ ] **Banner appears on server down**. Airplane mode → within 60 s. → Amber banner above mini-player
- [ ] **Banner clears on recover**. Restore network → within 60 s. → Banner gone
- [ ] **Cached track plays in offline mode**. → Plays fine. Uncached tracks fail visibly

## Android Auto (requires hardware)

- [ ] Connect phone to car head unit (or AA Desktop Head Unit simulator)
- [ ] **digaudio appears in the AA app list**
- [ ] **Browse tree shows "Favourites / Recently played / Most played"**
- [ ] **Tapping a leaf starts playback**
- [ ] **Voice command "Play <song>" works**

## Last.fm ranker (only after `LASTFM_API_KEY` secret set)

- [ ] **Subjective check** after a few weeks: auto-queue picks "feel" more musically related than just artist/genre matches

## Signed builds (only after keystore secrets set)

- [ ] **First install**: uninstall the previous debug-signed APK + install the new release-signed one. → No more "unknown source" warning (or just once when whitelisting GitHub as a source)
- [ ] **Subsequent updates** install in place without uninstall
