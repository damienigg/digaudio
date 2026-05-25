# digaudio — STATUS (v0.14.2, 2026-05-25)

Three things in one document:

1. **Inventory** — what's actually shipped, by area, with the path to invoke it.
2. **User test plan** — a checklist a human can run through on a real phone to verify each shipped feature.
3. **Next horizons** — what we could still add to make this the ultimate Android music player. Prioritised by impact × effort.

---

## 1 · Inventory (what's shipped)

### Audio engine
- **just_audio** + custom `BaseAudioHandler` (audio_service) — single source of truth for playback state.
- Single AudioPlayer for now; pseudo-crossfade via volume ramps (no second player).
- Origin-agnostic queue: local + Subsonic mix freely.
- MediaSession surface: lockscreen, notification, Bluetooth, Android Auto — all driven by the same handler.

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
| Crossfade off / 2s / 5s / 10s | Settings → Playback → Crossfade chips |
| Equalizer (5 bands, ±15 dB on most devices) | Settings → Playback → Equalizer |
| Auto-queue (similar-track append, lookahead 3) | Settings → Playback → Auto-queue toggle |

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
| Library tracks / albums / artists / playlists | Library tab → 4 sub-tabs |
| Alphabetical quick-scroll | Library → Artists (right edge) |
| Artist page (discography) | Tap any artist |
| Album page (tracklist + play) | Tap any album |
| Subsonic playlists | Library → Playlists |
| Local playlists (editable, reorderable, exportable JSON) | Library → Playlists |
| Import playlist (M3U / M3U8 / digaudio JSON) | Library → Playlists → "Import playlist…" |
| Favourites | Library → Playlists → Favorites |
| Wishlist (local-only) | Library → Playlists → Wishlist |
| Stats page | Library → Playlists → Stats |

### Track-level actions
| Action | Where |
|---|---|
| Add / remove favourite | Long-press tile → sheet, **OR** heart icon on Now Playing |
| 5-star rating (Subsonic, server-synced) | Long-press tile → 5-star row in sheet |
| Add to playlist | Long-press tile → "Add to playlist…" |
| Play next | Long-press tile → "Play next" |
| Add to queue | Long-press tile → "Add to queue" |
| Download / pin / remove | Long-press tile → contextual label |

### Recommendation engine
- Metadata score (artist +10, album +5, genre +6, year ±5 +3, duration ±60s +1).
- Optional Last.fm `track.getSimilar` ranker (+12 max if key baked at build time).
- Lookahead 3 tracks ahead of current.
- Chains off the **last** track in the queue, not the original seed — so the trajectory stays coherent.

### Stats
| Feature | Where |
|---|---|
| Time-window picker (30 d / 90 d / all time) | Stats page top |
| Totals — plays / unique tracks / listening days | Stats page header |
| Current + longest streak | Two flame chips |
| Year-grid heatmap (365 days, GitHub style) | Below totals |
| "Most played" smart mix button | Plays top 50 in window |
| Top 10 tracks (window) | List |
| Top 10 artists (window, aggregated from top 50 tracks) | List |
| Monthly tops (last 12 months, top 3 each, newest first) | Bottom of stats page |

### Now Playing
| Feature | Where |
|---|---|
| Full-screen artwork | Player tab |
| Title + artist + heart toggle | Below artwork |
| Position scrubber + duration | Below title |
| Transport (shuffle / prev / play/pause / next / repeat) | Below scrubber |
| Speed + Sleep timer actions | AppBar |
| Active queue (reorderable in future) | Queue tab |
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
- Subsonic library cache (drift): full song-level metadata for autoqueue scoring against the whole library, not just a random sample.
- Subsonic scrobble at track-start + at Last.fm-style played-threshold.

### Theme & UI
- Dark theme (default, Spotify-inspired).
- Light theme (system / dark / light picker in Settings → Display).
- Brand accent `#1ED760` everywhere.
- Custom launcher icon (golden shovel + "DIG" + music notes).
- Bottom-nav shell (Home / Search / Library) + persistent mini-player.

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
- [ ] APK installed (v0.14.2 or later).
- [ ] At least one Subsonic server configured & active (Settings → Servers).
- [ ] At least one local audio file on the device (`/sdcard/Music/*.flac|mp3|…`).
- [ ] (Recommended) Library cache synced once: Settings → Playback → Storage shows "Subsonic library cache" with non-zero count.

### Playback basics
- [ ] **Play a Subsonic track from search**. Search a known song, tap result. → Now Playing opens, audio starts within 1–2 s, artwork visible.
- [ ] **Play a local track from Library → Tracks**. → Same UX as Subsonic.
- [ ] **Background playback survives screen-off**. Play, lock screen, wait 30 s. → Still playing; lockscreen shows artwork + transport.
- [ ] **Bluetooth play/pause/next**. Connect BT headphones, play, tap pause on headphones, tap next. → App responds, lockscreen reflects new state.
- [ ] **Notification controls**. Pull down notification shade during playback. → Compact + expanded controls present, all functional.

### Queue & navigation
- [ ] **Album play-all**. Open any album, tap play. → Queue = full tracklist in order, plays from track 1.
- [ ] **Play next**. Long-press a track → "Play next". → Track inserted right after current.
- [ ] **Add to queue**. Long-press → "Add to queue". → Track appended at end of Now Playing → Queue tab.
- [ ] **Skip prev / next** from Now Playing transport. → Moves through queue cleanly, no audio glitch.
- [ ] **Scrubber**. Drag the position slider. → Audio seeks to that point.
- [ ] **Shuffle on/off**. Toggle shuffle icon in transport row. → Becomes accent green when active.
- [ ] **Repeat off/one/all** (cycle). Tap repeat icon. → Cycles through the 3 states, icon reflects mode.

### Auto-cache + downloads
- [ ] **Auto-cache toggles a fresh play**. Make sure auto-cache is ON. Play a Subsonic track you've never played before. Wait for it to finish. Reopen Now Playing for the same track. → Track tile now shows the grey ✓ cached badge.
- [ ] **Cached track plays offline**. Toggle airplane mode. Play the same cached track. → It plays from disk; offline banner appears at the bottom.
- [ ] **Pin a download**. Long-press a cached track → "Keep download". → Badge turns green ✓ (pinned).
- [ ] **Remove a download**. Long-press a pinned track → "Remove download". → Badge disappears; file gone from device.
- [ ] **Cache budget enforced**. Set Settings → Playback → Storage → Max cache to 512 MB. Play music until usage approaches limit. → Oldest non-pinned tracks get evicted; usage stays ≤ 512 MB.
- [ ] **"Clear auto-cache" preserves pinned**. With both pinned + auto-cached tracks present, tap "Clear auto-cache" in Settings. → Auto-cached gone, pinned remain.

### Favourites & ratings
- [ ] **Heart on Now Playing**. Play any track, tap heart icon next to title. → Icon fills + turns green; tile badge appears everywhere else (search, library, etc.).
- [ ] **Heart via long-press menu**. Long-press tile → "Add to favourites". → Same as above.
- [ ] **5-star rating** on a Subsonic track. Long-press tile → tap a star (e.g. 4th). → Stars 1–4 fill, server receives the rating (verify by re-opening sheet — stars persist).
- [ ] **Clear rating**. Tap the current rating star again. → Stars clear.
- [ ] **Rating row hidden for local tracks**. Long-press a local-MediaStore track. → No star row (Subsonic-only feature).

### Playlists
- [ ] **Create a local playlist**. Long-press track → "Add to playlist…" → "New playlist…" → name it. → Track added, playlist appears in Library → Playlists → Local.
- [ ] **Reorder + delete** in a local playlist. Open the playlist, long-drag a row to reorder, swipe a row to delete. → Order persists across app restart.
- [ ] **Export local playlist as JSON**. Open playlist → menu → Export. → Share sheet opens with a digaudio JSON file.
- [ ] **Import a playlist**. Library → Playlists → "Import playlist…" → pick a `.m3u` or digaudio `.json`. → New local playlist created, matched tracks visible, unmatched shown greyed-out.
- [ ] **Subsonic playlist plays**. Library → Playlists → tap any Subsonic playlist → Play. → Full tracklist queues + starts.

### Stats
- [ ] **Totals reflect listening**. Play ≥5 tracks. Open Library → Playlists → Stats (window: 30 d). → Plays count = total played, unique tracks = distinct, listening days ≥ 1.
- [ ] **Top tracks / artists populated**. With ≥10 plays. → Both lists show entries with `N×` counter.
- [ ] **Streak counter increments**. Play any track today. → "current streak" = at least 1 d.
- [ ] **Year heatmap shows today**. → Right-most cell of the strip is non-empty (green-tinted) after today's plays.
- [ ] **"Most played" mix queues**. Tap the button. → Now Playing fills with top-N tracks of the window.
- [ ] **Monthly tops** show the current month with the most-played track. → Row visible at the bottom of the page.

### Search
- [ ] **Type query**. Type 2-3 letters in Search. → Results appear after ~280 ms debounce (Artists, Albums, Tracks sections as relevant).
- [ ] **"Show more"** in any section with ≥20 results. Tap. → Section grows by another 20 entries; button shows spinner during fetch.
- [ ] **Local + remote mix**. Type a term matching both your local files and Subsonic. → Local tracks come first in Tracks section, then remote.

### Sleep timer + speed
- [ ] **Sleep timer 5 min** from Now Playing AppBar (bedtime icon). → Countdown badge appears, ticks down each second; playback pauses at 0.
- [ ] **Sleep timer "end of track"** mode. → Bedtime icon active but no countdown; playback pauses at next track end.
- [ ] **Cancel timer** from same sheet. → Badge disappears.
- [ ] **Speed 1.5×**. Tap "1.0x" → pick 1.5×. → Audio audibly faster; label shows `1.5x` (green).
- [ ] **Speed persists** across app restart. Kill the app, reopen. → Now Playing AppBar still shows the previously-set speed.

### Crossfade
- [ ] **Crossfade 5s**. Settings → Playback → Crossfade → 5 s. Play an album. Wait for a track to end naturally. → Last ~5 s of current ramps to silence; next track starts silent and ramps up over 5 s. No abrupt cut.
- [ ] **Off** behaves like before. Set Crossfade → Off. Same album end. → Tracks transition with no fade (instant flip).

### Equalizer
- [ ] **Apply a preset boost**. Settings → Playback → Equalizer → toggle on. Push the 60 Hz band slider to +6 dB. Play any bass-heavy track. → Bass audibly louder. Slider position persists across restarts.

### Auto-queue
- [ ] **Lookahead fills the queue**. Set Auto-queue ON. Start with a single track via "Play single". → Now Playing → Queue tab shows the original track + ~3 similar follow-ups appended (look for "logical" similar-artist/album suggestions).
- [ ] **As the user listens through, new picks keep appearing**. → After the current track changes, queue length stays ≈ current+3.

### Settings — servers
- [ ] **Add a 2nd server**. Settings → Servers → "Add server" → enter URL + creds → "Test & save". → "Connected" message; server appears in list.
- [ ] **Switch active server**. Tap any inactive server. → Active checkmark moves; Home reloads with new server's albums.
- [ ] **Delete a non-builtin server**. Edit it → trash icon → confirm. → Disappears from list.

### Settings — display
- [ ] **Light theme**. Settings → Display → Light. → Entire app switches to light theme without restart.
- [ ] **Follow system**. Set to "Follow system" then toggle OS dark mode in Quick Settings. → App follows.

### Offline behaviour
- [ ] **Banner appears on server down**. Toggle airplane mode. Within 60 s. → Amber "Server unreachable — cached + local content only" banner appears above mini-player.
- [ ] **Banner clears on recover**. Restore network. Within 60 s. → Banner gone.
- [ ] **Cached track plays in offline mode**. While airplane mode is on, play a cached/pinned track. → Plays fine. Stream attempts on uncached tracks fail visibly (acceptable degradation).

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

## 3 · Next horizons — what would make this the ultimate Android music player

Categorised by theme; each item rated **S/M/L** for implementation effort. Items at the top of each section are highest-leverage.

### A · UX gold (daily-use wins)

- **Drag-to-reorder + swipe-to-remove in active queue** *(M)*  
  Today the Queue tab is read-only — you skip to but can't reshape. Standard music-player UX.
- **Album mode / "stop after current album"** *(S)*  
  A toggle that auto-stops at the last track of the current album — bridge between sleep timer and full queue play.
- **Per-track resume position** *(M)*  
  Useful for audiobooks / long mixes. Engine remembers the last position per trackKey and resumes there on next play.
- **"Up Next" inline strip on Now Playing** *(M)*  
  Apple Music-style — the next 3 tracks visible without leaving the Player tab.
- **Colour extraction from album art** *(S)*  
  Now Playing background uses a blurred dominant-colour gradient from the artwork. Hero polish.
- **Long-press = quick play** option in track tiles *(S)*  
  Today long-press opens the actions sheet. A setting to swap: long-press = "play this in queue context", tap = sheet — for power users.
- **Bulk select in any list** *(M)*  
  Multi-select mode (long-press → select more → bulk add to playlist / favourite / queue / download). Standard email-app pattern.

### B · Discovery & smart mixes

- **Smart playlists** *(L)*  
  Rule-based: "5★ songs not played in 6 months", "songs added this year", "FLAC only". Persists rules + auto-rebuilds when opened. Top Symfonium feature.
- **More smart mixes** *(M)*  
  "Discover" (similar to your top tracks but never played), "Throwback" (rated high, dormant), "Decade mix" (random songs from one decade), "Genre mix" (all rock, all jazz, …).
- **Subsonic radio mode** *(M)*  
  Uses Subsonic `getSimilarSongs` for a seed track and streams forever — like Pandora.
- **"On this day" past listening** *(S)*  
  Shows what you played on the same calendar day in past years (uses RecentPlays).
- **Year-by-year top 10** *(S)*  
  Stats page gets a "top tracks of 2024" / "top of 2025" etc. block.
- **Genre browser** *(M)*  
  Library tab gets a 5th sub-tab "Genres" — list of genres from your library cache; tap a genre → all tracks of that genre.
- **Decade browser** *(S)*  
  Same idea: 1950s / 60s / … / 2020s.

### C · Audio fidelity

- **Replay Gain / volume normalisation** *(M)*  
  Avoids the "this song is much louder than the previous" problem. Use track-level or album-level RG tags if present.
- **True crossfade with overlap** *(L)*  
  Second AudioPlayer + parallel pipeline. The current pseudo-crossfade is good enough for most music but cuts through transients (e.g. an orchestral hit at track end).
- **EQ presets** *(S)*  
  Rock / Jazz / Vocal Boost / Bass Boost / Custom. Saves the user from dialling sliders.
- **Per-Bluetooth-device EQ profile** *(M)*  
  Different profile when JBL Charge 4 connects vs Sony WH-1000XM5.
- **Gapless playback verification** *(S)*  
  We get it for free from `ConcatenatingAudioSource` but should add a test track-pair (a DJ mix split into 2) to verify.

### D · Platform integration

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

### E · Social & external

- **ListenBrainz scrobble** *(S)*  
  Open alternative to Last.fm. Same shape — just a different endpoint + token in Settings.
- **Direct Last.fm scrobble** *(S)*  
  Today scrobbling routes through the Subsonic server. Direct Last.fm scrobble (with user token) bypasses the server — useful if the Subsonic server lacks Last.fm integration.
- **Listening parties / shared queue** *(L)*  
  Realtime sync of playback state across multiple devices (via WebSocket to a relay or via Tailscale-local mesh).
- **Now-Playing share sheet** *(S)*  
  Share what you're listening to as a rich card (artwork + title + artist + deep-link to Subsonic if any).

### F · Library management

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

### G · Long-tail polish

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

### H · Building toward "the ultimate" — strategic combos

The categories above are mostly individual items. The real differentiators emerge from **combos** :

1. **"Recommendation engine"** = Last.fm ranker (done) × library FTS × smart playlists × Subsonic radio mode. Result: digaudio knows your library + global taste data well enough to surface anything on demand ("play something like Daft Punk from the early 2000s I haven't heard in months").
2. **"Pro-listener"** = Replay Gain × true crossfade × EQ presets × per-BT-device EQ × FLAC-confirmed × wired-DAC fidelity. Audiophile target.
3. **"Friend-share"** = ListenBrainz × listening parties × Now-Playing share × wishlist webhook. Social tier.
4. **"Daily driver"** = Quick Settings tile × homescreen widget × Wear OS × Auto-play on BT × Per-track resume. Frictionless habit.

If you want a single 10× leap, **smart playlists + true recommendation engine** (combo 1) is what users feel every day and what would put digaudio in Symfonium territory.

---

## Versioning

Today's max: **v0.14.2**. Suggested next minor bumps if the items below are tackled:

- v0.15.x — Smart playlists + drag-to-reorder queue (UX gold + smart mixes)
- v0.16.x — Replay Gain + EQ presets (audio fidelity)
- v0.17.x — Quick Settings tile + homescreen widget (platform integration)

`flutter_launcher_icons` regeneration & build_runner stay required after schema bumps — same workflow as today.
