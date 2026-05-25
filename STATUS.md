# digaudio — STATUS (v0.18.0, 2026-05-25)

Three things in one document:

1. **Inventory** — what's actually shipped, by area, with the path to invoke it.
2. **User test plan** — a checklist a human can run through on a real phone to verify each shipped feature.
3. **Next horizons** — what we could still add to make this the ultimate Android music player. Prioritised by impact × effort.

> Refresh history: v0.14.2 → v0.18.0 (14 releases). Combo-1
> recommendation engine, smart playlists, smart mixes, Subsonic radio,
> Genre/Decade browsers, On-this-day, Year-by-year, queue editor, album
> mode, per-track resume, Up Next strip, Now Playing colour tint, bulk
> select, EQ presets, gapless confirmation, Replay Gain, per-BT EQ,
> **true crossfade with two-player engine refactor**. Reflected throughout.

---

## 1 · Inventory (what's shipped)

### Audio engine
- **just_audio** + custom `BaseAudioHandler` (audio_service) — single source of truth for playback state.
- Single AudioPlayer; pseudo-crossfade via volume ramps (no second player).
- Origin-agnostic queue: local + Subsonic mix freely.
- MediaSession surface: lockscreen, notification, Bluetooth, Android Auto — all driven by the same handler.
- **Per-track resume position** (v0.16.1) — engine debounce-saves position
  every ~5 s; on re-play, seeks to saved position once duration is known.

### Audio sources
- **Local MediaStore** (Android files on the device) via own Kotlin channel (`digaudio/media_store`).
- **Subsonic** (and any Subsonic-compatible server: Navidrome, Gonic, Airsonic, Ampache, Nextcloud Music).
- **Multi-server**: register N Subsonic servers, switch the active one (Settings → Servers).

### Playback features
| Feature | Where |
|---|---|
| Shuffle | Now Playing (transport row) |
| Repeat off / one / all | Now Playing (transport row) |
| Playback speed 0.5× → 2× | Now Playing AppBar (`1.0x` button) |
| Sleep timer (5/15/30/45/60 min OR end-of-track) | Now Playing AppBar (bedtime icon) |
| Crossfade off / 2 / 5 / 10 s (pseudo) | Settings → Playback → Crossfade chips |
| Equalizer (5 bands, ±15 dB on most devices) | Settings → Playback → Equalizer |
| Auto-queue (similar-track append, lookahead 3, Last.fm boost when key set) | Settings → Playback → Auto-queue toggle |
| **Album mode** (stop-after-this-album) | Now Playing AppBar (album icon) |
| **Queue editor**: drag-to-reorder + swipe-to-remove | Now Playing → Queue tab |

### Storage & cache (unified pool, LRU evict)
| Feature | Where |
|---|---|
| Auto-cache on play (every Subsonic stream → disk) | Settings → Playback → Storage → "Auto-cache" toggle |
| Cache budget 512 MB → 20 GB | Same place, dropdown |
| Current cache usage + clear button | Same place |
| Pinned downloads (never evicted) | Per-track sheet → "Download for offline" |
| Promote auto-cached → pinned | Per-track sheet → "Keep download" |
| Remove a download | Per-track sheet → "Remove download" |
| Cache state badge on tile (✓ green = pinned, ✓ grey = cached, none) | Track tile next to title |

### Library browsing
| Feature | Where |
|---|---|
| Home — newest releases + random picks | Home tab |
| Brand hero (icon + tagline) | Top of Home |
| Search w/ pagination ("Show more" per category) | Search tab |
| Library tracks / albums / artists / **genres / decades** / playlists | Library tab → 6 sub-tabs |
| Alphabetical quick-scroll | Library → Artists (right edge) |
| **Genre / Decade pages** with Play all + Shuffle header | Library → Genres / Decades → tap an entry |
| Artist page (discography) | Tap any artist |
| Album page (tracklist + play) | Tap any album |
| Subsonic playlists | Library → Playlists |
| Local playlists (editable, reorderable, exportable JSON) | Library → Playlists |
| Import playlist (M3U / M3U8 / digaudio JSON) | Library → Playlists → "Import playlist…" |
| Favourites | Library → Playlists → Favorites |
| Wishlist (local-only) | Library → Playlists → Wishlist |
| Stats page | Library → Playlists → Stats |
| **Smart playlists** (rules-based, materialise on open) | Library → Playlists → "Smart playlists" → tap |
| **Smart playlists — 4 builtins seeded on first launch** | All time random / 80s / 90s / Recent |

### Track-level actions
| Action | Where |
|---|---|
| Add / remove favourite | Long-press tile → enters select mode (use bulk fav), **OR** ⋮ on tile → sheet → fav, **OR** heart icon on Now Playing |
| 5-star rating (Subsonic, server-synced) | ⋮ on tile → 5-star row in sheet |
| Add to playlist | ⋮ on tile → "Add to playlist…", or bulk via select bar |
| Play next | ⋮ on tile → "Play next", or bulk via select bar |
| Add to queue | ⋮ on tile → "Add to queue", or bulk via select bar |
| Download / pin / remove | ⋮ on tile → contextual label |
| **Start radio** (Subsonic getSimilarSongs2 → 30 similar) | ⋮ on tile → "Start radio" (Subsonic tracks) |

### **Bulk select** (v0.16.3)
- **Long-press any tile** → enters multi-select mode, adds the tile.
- Tap (in select mode) = toggle; tap (out of mode) = play as usual.
- **SelectionBar** appears above the mini-player. Actions:
  - **Play** (replaces queue with selection)
  - Add to queue (appends)
  - Play next (reverse-inserts so first-selected lands next)
  - Add to playlist (multi-add picker)
  - Add to favourites (bulk-fav all keys)
  - X cancels
- Selection is **global** — long-press in Library, navigate to Search, add more, act on the union.

### Recommendation engine — **combo 1 complete**
- **Metadata score** (artist +10, album +5, genre +6, year ±5 +3, duration ±60 s +1).
- **Last.fm `track.getSimilar` ranker** (+12 max if key baked at build time).
- **Subsonic radio mode** — server-side `getSimilarSongs2`; "Start radio" action in track sheet seeds the queue with 30 similar.
- **Smart playlists** — rules-based materialisation (filters on cached Subsonic library: genre / year / artist / album / title / duration; ops eq / neq / gt / gte / lt / lte / between / contains; match all/any; order random / year / title / artist / duration; limit 1–1000).
- Auto-queue lookahead 3 tracks ahead of current, chains off the **last** track in the queue.
- "Suggested next" hint after favoriting.

### Stats
| Feature | Where |
|---|---|
| Time-window picker (30 d / 90 d / all time) | Stats page top |
| Totals — plays / unique tracks / listening days | Stats page header |
| Current + longest streak | Two flame chips |
| Year-grid heatmap (365 days, GitHub style) | Below totals |
| **On this day** — same MM-DD in prior years | Section with Play all button |
| "Most played" smart mix button | Plays top 50 in window |
| Top 10 tracks (window) | List |
| Top 10 artists (window, aggregated from top 50 tracks) | List |
| **Year-by-year tops** (top 5 per year) | Bottom of stats page |
| Monthly tops (last 12 months, top 3 each, newest first) | Bottom of stats page |

### Now Playing
| Feature | Where |
|---|---|
| Full-screen artwork | Player tab |
| **Colour tint background** (dominant artwork colour gradient) | Player tab, behind artwork — Settings → Display toggle |
| Title + artist + heart toggle | Below artwork |
| Position scrubber + duration | Below title |
| Transport (shuffle / prev / play/pause / next / repeat) | Below scrubber |
| **Up Next inline strip** (next 3 tracks, tap to jump) | Below transport |
| Album mode + Speed + Sleep timer actions | AppBar |
| Active queue (editable: drag handle + swipe) | Queue tab |
| Lyrics (synced via OpenSubsonic, plain fallback) | Lyrics tab |
| Active-line highlight + auto-scroll on synced lyrics | Lyrics tab |

### MediaSession surfaces
| Where | Status |
|---|---|
| Lockscreen artwork + transport | ✓ via audio_service |
| Notification + transport | ✓ via audio_service |
| Bluetooth controls | ✓ |
| Android Auto browsable tree (Favourites / Recently played / Most played) | ✓ (untested on real head unit) |

### Server features
- Subsonic salt+token auth (no plain-text passwords on wire).
- Server reachability ping (every 60 s) → offline banner above mini-player.
- Subsonic library cache (drift): full song-level metadata for autoqueue scoring + Genre/Decade browsers + smart playlists.
- Subsonic scrobble at track-start + at Last.fm-style played-threshold.

### Theme & UI
- Dark theme (default, Spotify-inspired).
- Light theme (system / dark / light picker in Settings → Display); 87 `Colors.white*` literals migrated to theme-aware aliases (v0.12.0).
- Brand accent `#1ED760` everywhere.
- Custom launcher icon (golden shovel + "DIG" + music notes, v2 in v0.12.3).
- Bottom-nav shell (Home / Search / Library) + persistent mini-player.
- Offline banner + Selection bar appear conditionally above the mini-player.

### Build & release
- GitHub Actions CI on push to `main` + `v*` tags.
- APK artifact (90-day retention) on every push.
- Auto-published GitHub Release on tag.
- Concurrency dedup by SHA.
- Optional release-signed APKs via 3 secrets (`KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`). Falls back to debug signing if absent.
- Optional Last.fm ranker via `LASTFM_API_KEY` secret.
- Optional Subsonic URL pre-bake via `SUBSONIC_URL` + `SUBSONIC_LABEL` secrets.

---

## 2 · User test plan

Run through these on a phone with the latest APK installed. Each item is a one-paragraph recipe; "Expected" is the pass criterion.

### Prerequisites
- [ ] APK installed (v0.16.3 or later).
- [ ] At least one Subsonic server configured & active (Settings → Servers).
- [ ] At least one local audio file on the device (`/sdcard/Music/*.flac|mp3|…`).
- [ ] (Required for many features) Library cache synced once: Settings → Playback → Storage shows "Subsonic library cache" with non-zero count.

### Playback basics
- [ ] **Play a Subsonic track from search**. Search a known song, tap result. → Now Playing opens, audio starts within 1–2 s, artwork visible.
- [ ] **Play a local track from Library → Tracks**. → Same UX as Subsonic.
- [ ] **Background playback survives screen-off**. Play, lock screen, wait 30 s. → Still playing; lockscreen shows artwork + transport.
- [ ] **Bluetooth play/pause/next**. Connect BT headphones, play, tap pause on headphones, tap next. → App responds, lockscreen reflects new state.
- [ ] **Notification controls**. Pull down notification shade during playback. → Compact + expanded controls present, all functional.

### Queue & navigation
- [ ] **Album play-all**. Open any album, tap play. → Queue = full tracklist in order, plays from track 1.
- [ ] **Play next** via ⋮ button. → Track inserted right after current.
- [ ] **Add to queue** via ⋮ button. → Track appended at end of Now Playing → Queue tab.
- [ ] **Skip prev / next** from Now Playing transport. → Moves through queue cleanly, no audio glitch.
- [ ] **Scrubber**. Drag the position slider. → Audio seeks to that point.
- [ ] **Shuffle on/off**. Toggle shuffle icon in transport row. → Becomes accent green when active.
- [ ] **Repeat off/one/all** (cycle). Tap repeat icon. → Cycles through the 3 states, icon reflects mode.
- [ ] **Up Next strip**. Open Now Playing on a Subsonic album with autoqueue. → Strip below transport shows next 3 tracks; tap one → jumps to it.

### Queue editor (v0.16.0)
- [ ] **Drag-to-reorder a queue entry**. Now Playing → Queue tab → drag the trailing handle on any row up/down. → Order persists, audio keeps playing without interruption.
- [ ] **Swipe-to-remove**. Swipe a non-current row left. → Row dismissed with red background; track removed from queue.

### Album mode (v0.16.0)
- [ ] **Stop at end of album**. Play any album. On Now Playing, tap the album icon (AppBar). → Icon turns accent green. When the last track of the album finishes, playback pauses; icon returns to outlined.

### Per-track resume (v0.16.1)
- [ ] **Pause mid-track + return**. Play a long track (≥3 min), let it run to ~1:30, pause, switch to a different track, play. Now go back to the first track. → Playback resumes around 1:30 (not 0:00) once buffered.
- [ ] **Short tracks don't trigger**. Play a track from start to ~0:05, pause, switch away, return. → Plays from 0:00 (threshold protects against "resume at 0:05" UX).

### Auto-cache + downloads
- [ ] **Auto-cache toggles a fresh play**. Make sure auto-cache is ON. Play a Subsonic track you've never played before. Wait for it to finish. Reopen Now Playing for the same track. → Track tile now shows the grey ✓ cached badge.
- [ ] **Cached track plays offline**. Toggle airplane mode. Play the same cached track. → It plays from disk; offline banner appears at the bottom.
- [ ] **Pin a download**. ⋮ on a cached track → "Keep download". → Badge turns green ✓ (pinned).
- [ ] **Remove a download**. ⋮ on a pinned track → "Remove download". → Badge disappears; file gone from device.
- [ ] **Cache budget enforced**. Set Settings → Playback → Storage → Max cache to 512 MB. Play music until usage approaches limit. → Oldest non-pinned tracks get evicted; usage stays ≤ 512 MB.
- [ ] **"Clear auto-cache" preserves pinned**. With both pinned + auto-cached tracks present, tap "Clear auto-cache" in Settings. → Auto-cached gone, pinned remain.

### Favourites & ratings
- [ ] **Heart on Now Playing**. Play any track, tap heart icon next to title. → Icon fills + turns green; tile badge appears everywhere else.
- [ ] **5-star rating** on a Subsonic track via ⋮ → tap a star (e.g. 4th). → Stars 1–4 fill, server receives the rating (re-open sheet to confirm).
- [ ] **Clear rating**. Tap the current rating star again. → Stars clear.
- [ ] **Rating row hidden for local tracks**. ⋮ on a local-MediaStore track. → No star row (Subsonic-only feature).

### Bulk select (v0.16.3)
- [ ] **Enter select mode**. Long-press any track tile in any list. → Tile turns accent-translucent with check-circle on the left; SelectionBar appears above the mini-player.
- [ ] **Toggle more in same list**. Tap (not long-press) other tiles. → Each toggles in/out of selection; count in the bar updates.
- [ ] **Cross-screen selection**. With selection active in Library, navigate to Search via bottom nav, long-press a track from search results. → Same global selection; count = sum of both.
- [ ] **Bulk Play**. Tap "Play" in the bar. → Queue replaced with selection; first track plays; selection clears.
- [ ] **Bulk Add to queue / Play next**. Same approach, "Add to queue" appends, "Play next" inserts after current.
- [ ] **Bulk favourite**. Tap heart icon in the bar. → All selected tracks gain the favourite badge; selection clears.
- [ ] **Bulk add to playlist**. Tap playlist icon in the bar → pick an existing playlist. → All selected tracks appended to it; selection clears.
- [ ] **Cancel selection**. Tap the X in the bar. → Bar disappears, tiles return to normal.

### Playlists
- [ ] **Create a local playlist**. Long-press a single track in select-empty state? — Wait, long-press now enters selection. Use ⋮ → "Add to playlist…" → "New playlist…" → name it. → Track added, playlist appears in Library → Playlists → Local.
- [ ] **Reorder + delete** in a local playlist. Open the playlist, long-drag a row to reorder, swipe a row to delete. → Order persists across app restart.
- [ ] **Export local playlist as JSON**. Open playlist → menu → Export. → Share sheet opens with a digaudio JSON file.
- [ ] **Import a playlist**. Library → Playlists → "Import playlist…" → pick `.m3u` or digaudio `.json`. → New local playlist, matched tracks visible, unmatched greyed-out.
- [ ] **Subsonic playlist plays**. Library → Playlists → tap any Subsonic playlist → Play. → Full tracklist queues + starts.

### Smart playlists (v0.15.3-4)
- [ ] **4 builtins present on fresh install**. Library → Playlists → "Smart playlists" section. → Lists "All time random", "80s revival", "90s revival", "Recent".
- [ ] **A builtin plays**. Tap "All time random". → Materialises 50 random tracks from the synced library; Play all / Shuffle buttons header.
- [ ] **Decade filter works**. Tap "90s revival". → Shows tracks year-1990–1999 only (verify ≥1 of the displayed tracks has a 199x year).
- [ ] **Create a custom smart playlist**. "+ New" → name "Rock 2000s" → Add rule "genre eq Rock" + "year between 2000 2009" → order random → limit 30 → Save. → Appears in list. Open it. → Materialises matching tracks.
- [ ] **Edit a smart playlist**. Open any → edit icon (AppBar) → tweak a rule → Save. → On view reload, results reflect new rules.
- [ ] **Delete a smart playlist**. Open any → delete icon → confirm. → Removed from list.

### Genre + Decade browsers (v0.15.1)
- [ ] **Genres tab populated**. Library → Genres. → List of genres with track counts (requires library sync).
- [ ] **Decades tab populated**. Library → Decades. → List of decades (1970s, 1980s, …).
- [ ] **Tap a genre → page loads + plays**. → Shows all tracks of that genre; tap Play all → queue + playback starts.
- [ ] **Tap a decade → page loads + plays**. → Same UX as genre.

### Subsonic radio (v0.15.2)
- [ ] **Start radio from a Subsonic track**. ⋮ on a Subsonic track → "Start radio". → Queue replaced with seed + ~30 similar; playback starts. The server's similarity (different from metadata + Last.fm) drives the picks.
- [ ] **Empty fallback**. Try radio on a track the server has no similar data for. → Toast "no similar tracks for X — server returned empty"; original queue untouched.

### Stats — On-this-day + Year-by-year (v0.15.0)
- [ ] **On this day section**. Stats page → "On this day". → For installs ≥1 year old: lists tracks played same MM-DD in prior years. Fresh installs: shows hint text.
- [ ] **Year-by-year**. → For each year present in history, one block with top 5 tracks (tap to play).

### Search
- [ ] **Type query**. Type 2-3 letters in Search. → Results after ~280 ms debounce (Artists, Albums, Tracks sections as relevant).
- [ ] **"Show more"** in any section with ≥20 results. → Section grows by 20; button hides when exhausted.
- [ ] **Local + remote mix**. Type a term matching both your local files and Subsonic. → Local tracks first in Tracks section.

### Sleep timer + speed + crossfade
- [ ] **Sleep timer 5 min** from Now Playing AppBar (bedtime icon). → Countdown badge appears, ticks down each second; playback pauses at 0.
- [ ] **Sleep timer "end of track"** mode. → Bedtime icon active but no countdown; playback pauses at next track end.
- [ ] **Cancel timer** from same sheet. → Badge disappears.
- [ ] **Speed 1.5×**. Tap "1.0x" → pick 1.5×. → Audio audibly faster.
- [ ] **Speed persists** across app restart. → AppBar still shows the previously-set speed.
- [ ] **Crossfade 5s**. Settings → Playback → Crossfade → 5 s. Play an album. Wait for a track to end. → Last ~5 s ramps to silence; next track ramps up over 5 s.

### Equalizer
- [ ] **Apply a preset boost**. Settings → Playback → Equalizer → toggle on. Push the 60 Hz band slider to +6 dB. Play any bass-heavy track. → Bass audibly louder. Slider position persists across restarts.

### Auto-queue
- [ ] **Lookahead fills the queue**. Set Auto-queue ON. Start with a single track. → Queue tab shows the original + ~3 similar follow-ups appended.

### Settings — servers
- [ ] **Add a 2nd server**. Settings → Servers → "Add server" → URL + creds → "Test & save". → "Connected" message; server in list.
- [ ] **Switch active server**. Tap any inactive server. → Active checkmark moves; Home reloads.
- [ ] **Delete a non-builtin server**. Edit it → trash icon → confirm. → Disappears.

### Settings — display
- [ ] **Light theme**. Settings → Display → Light. → Entire app switches.
- [ ] **Follow system**. Set to "Follow system" then toggle OS dark mode. → App follows.
- [ ] **Now Playing tint toggle**. Settings → Display → "Now Playing colour tint". → Toggle controls whether the background gradient appears on Now Playing.

### Offline behaviour
- [ ] **Banner appears on server down**. Toggle airplane mode. Within 60 s. → Amber banner above mini-player.
- [ ] **Banner clears on recover**. Restore network. Within 60 s. → Banner gone.
- [ ] **Cached track plays in offline mode**. While airplane on, play a cached/pinned track. → Plays fine. Stream attempts on uncached tracks fail visibly.

### MediaSession surfaces (deferred — requires hardware)
- [ ] **Android Auto** — connect phone to a car head unit (or AA Desktop Head Unit simulator).
  - digaudio appears in the AA app list.
  - Browse tree shows "Favourites / Recently played / Most played".
  - Tapping a leaf in any of those starts playback.
  - Voice command "Play <song>" works.

### Last.fm ranker (only after secret set)
- [ ] **Subjective check**: after a few weeks of usage, auto-queue picks "feel" more musically related than just artist/genre matches.

### Signed builds (only after keystore secrets set)
- [ ] **First update**: uninstall the previous debug-signed APK, install the new release-signed one — Android shouldn't show "unknown source" warning anymore (or only once when you whitelist GitHub as a source).
- [ ] **Subsequent update** installs in place without uninstall.

---

## 3 · Next horizons — what's still on the table

Categories A and B are **done**. Combo 1 (recommendation engine) is **done**. What follows is everything else from the original brainstorm + a few items the session uncovered.

### A · UX gold — **DONE**
All 7 items shipped. Bulk select was the last, in v0.16.3.

### B · Discovery & smart mixes — **DONE**
All 7 items shipped. Smart playlists is the centerpiece; 4 builtins seeded.

### C · Audio fidelity — **5/5 DONE**

- ~~Replay Gain via OpenSubsonic~~ — **DONE v0.17.2** (off / track / album)
- ~~EQ presets~~ — **DONE v0.17.0** (Flat / Rock / Jazz / Vocal / Bass boost / Treble boost)
- ~~Per-Bluetooth-device EQ profile~~ — **DONE v0.17.3** (save current EQ per BT device, auto-apply on connect)
- ~~Gapless playback verification~~ — **DONE v0.17.1** (was always on via the old `ConcatenatingAudioSource`; now via the preloaded-secondary swap in the new two-player engine)
- ~~**True crossfade with overlap**~~ — **DONE v0.18.0**
  - Two `AudioPlayer` instances (`_primary` audible / `_secondary` preloaded)
  - Manual queue orchestration (no `ConcatenatingAudioSource`)
  - Overlap fade when `crossfadeMs > 0`: secondary fades in while primary fades out, then swap
  - Instant swap when `crossfadeMs == 0`: still gapless (preloaded secondary jumps in at primary's end)
  - All UI streams re-piped through engine-owned broadcast controllers + inner subs re-attached on swap
  - Engine-level loop (`all` wraps, `one` delegates to source loop) + engine-level shuffle (pins current track at 0, shuffles rest, restores via `_originalOrder`)
  - `_silenceSecondary()` called by all skip paths so a mid-fade secondary never plays in the background after a user jump

### D · Platform integration (0/7 shipped)

- **Quick Settings tile** *(M)*  
  Pull down the notification shade — a "digaudio" tile shows play/pause + current track. One tap from anywhere.
- **Homescreen widget (mini-player)** *(L)*  
  Same controls + artwork on the user's homescreen. Glance value.
- **Material You dynamic colour** *(S)*  
  On Android 12+, the accent could mirror the system wallpaper (alternative to the fixed `#1ED760` brand colour).
- **Headphone-removal auto-pause** *(S)*  
  Already free via `audio_session` config — verify it works.
- **Auto-play on BT connect** option *(S)*  
  Resume last queue when wired/wireless headphones connect.
- **Voice search inside the app** *(M)*  
  Today AA does it; in-app could use Android's `SpeechRecognizer`.
- **Wear OS companion** *(L)*  
  Independent music player on Wear OS, syncing playback state with the phone.

### E · Social & external (0/4 shipped)

- **ListenBrainz scrobble** *(S)*  
  Open alternative to Last.fm. Same shape — just a different endpoint + token in Settings.
- **Direct Last.fm scrobble** *(S)*  
  Today scrobbling routes through the Subsonic server. Direct Last.fm scrobble (with user token) bypasses the server — useful if the Subsonic server lacks Last.fm integration.
- **Listening parties / shared queue** *(L)*  
  Realtime sync of playback state across multiple devices (via WebSocket to a relay or via Tailscale-local mesh).
- **Now-Playing share sheet** *(S)*  
  Share what you're listening to as a rich card (artwork + title + artist + deep-link to Subsonic if any).

### F · Library management (0/5 shipped)

- **Subsonic library cache auto-refresh** *(S)*  
  Today you have to tap "Sync" manually. Add a "refresh every N days" or "refresh on app start if >7d old".
- **Multi-server unified search** *(M)*  
  Today Search hits the active server only. Could fan-out across all configured servers + dedupe.
- **Background download queue** *(M)*  
  Today a download is foreground — if you back out of the app it continues but no visible progress. Add a system notification with progress + cancel.
- **Library FTS (full-text search)** *(M)*  
  Drift's `Fts5` virtual table on cached song titles + artists + albums. Search becomes instant, with diacritic folding (already half-built for the playlist importer).
- **"Recently added" on Home** *(S)*  
  Newest-N albums added to the server (Subsonic supports `type=recent` on `getAlbumList2`).

### G · Long-tail polish (0/7 shipped)

- **Accessibility audit** *(S)*  
  Verify TalkBack labels on all interactive elements. Bigger tap targets on small UI (alpha-scroll letters, heatmap cells).
- **Internationalisation** *(M)*  
  Today everything is English. Externalise strings; ship a French translation first.
- **Sleep-timer fade-out** *(S)*  
  Instead of just pausing at 0, ramp volume to 0 over the last 10 s.
- **Notification rich actions** *(S)*  
  "Skip 10s back / forward" buttons in the notification (useful for podcasts).
- **Album-art waveform scrubber** *(L)*  
  Replace the linear slider with a precomputed waveform (decode FLAC/MP3 header → PCM peaks → cached image).
- **Crossfade between BPM-matched tracks only** *(L)*  
  DJ-style: detect BPM, skip the crossfade if next track has wildly different tempo. Highly niche but unique.
- **Subsonic admin actions** *(M)*  
  If logged in as admin: trigger server library scan from the app, see scan status, manage users.

### H · Session-discovered TODOs (added beyond the original brainstorm)

- **Smart playlists v2 — joins** *(M)*  
  Today v1 only filters `CachedSubsonicSongs` columns. v2 would add joins for: `favourite` (= true/false), `playCount30d` (≥ N), `lastPlayedDaysAgo` (≥ N), `pinned`, `cached`, `rating` (when the user starts using 5★). Unlocks "Discover" mix (similar to my favs but never played), "Throwback" (rated high, dormant), etc.
- **Subsonic radio auto-refill loop** *(S)*  
  Currently radio fetches 30 tracks once. Refill via `getSimilarSongs` on the most-recently-played when the queue runs low → endless radio.
- **Bulk select — extend to album / playlist views** *(S)*  
  Currently any TrackTile supports bulk select; the album/playlist page rows are TrackTile already so it should "just work" but needs verification.
- **TrackTile leading checkbox tap area** *(S)*  
  Bulk-select check-circle is currently inside the tile body; should be a tap target on its own row leading.

### I · Strategic combos — the "ultimate" leverage points

1. **Recommendation engine** = Last.fm × library FTS × smart playlists × Subsonic radio.  
   **3/4 done** (Last.fm, smart playlists, Subsonic radio). Adding **library FTS** would let the user write smart-playlist rules with free-text search (e.g. "title contains 'remix' AND year > 2020"). Highest-value remaining single addition.
2. **Pro-listener** = Replay Gain × true crossfade × EQ presets × per-BT-device EQ × FLAC-confirmed × wired-DAC fidelity.  
   **4/6 done** — Replay Gain, true crossfade (overlap, v0.18.0), EQ presets, per-BT EQ all shipped. Remaining: FLAC end-to-end verification (codec + sample-rate display, probably free), wired-DAC fidelity confirmation (probably free via Android system audio).
3. **Friend-share** = ListenBrainz × listening parties × Now-Playing share × wishlist webhook.  
   **0/4 done**. Big lift for the smallest user base.
4. **Daily driver** = Quick Settings tile × homescreen widget × Wear OS × Auto-play on BT × Per-track resume.  
   **1/5 done** (per-track resume). Quick Settings tile + auto-play on BT is the quickest win.

**Next single 10× leap from here**: combo 1 finalisation = **library FTS** (M). Unlocks free-text smart-playlist rules ("title contains 'remix'") + instant search. Smaller than combo 4 (platform integration) and combo 3 (social), bigger impact than the long-tail polish in section G.

---

## Versioning

Latest released: **v0.18.0** (TRUE crossfade — two-player engine refactor).

Categories A, B, C are **DONE**. Combo 1 + 2 are essentially complete (3/4 and 4/6 — remaining items are minor or "verify only"). What's left, in roughly increasing order of effort × decreasing certainty of impact:

- **v0.19.x — Library management** (combo 1 finalisation + browse polish)  
  FTS + cache auto-refresh + multi-server search + "Recently added" + background download queue.
- **v0.20.x — Daily-driver batch** (combo 4)  
  Quick Settings tile + Auto-play on BT + headphone-removal verify + Material You dynamic colour.
- **v0.21.x — Smart playlists v2** (joins for the rules engine)  
  Add `favourite`, `playCount30d`, `lastPlayedDaysAgo`, `pinned`, `cached`, `rating` to the rule fields. Unlocks "real" Discover / Throwback / etc. smart mixes.
- **v0.22.x — Long-tail polish** (i18n, accessibility, sleep-timer fade-out, notification rich actions)
- **v0.23.x — Friend-share batch** (combo 3 — ListenBrainz + Now-Playing share)  
  Listening parties / wishlist webhook deferred until a real use case emerges.
- **v0.24.x — Wear OS + homescreen widget** (combo 4 finishers)
- **v1.0.0** — first "release" milestone after a real-device validation pass on all features

`flutter_launcher_icons` regeneration + build_runner stay required after schema bumps — same workflow as today.
