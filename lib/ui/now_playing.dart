import 'dart:async';
import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:share_plus/share_plus.dart';

import '../audio/audio_info.dart';
import '../audio/providers.dart';
import '../domain.dart';
import '../library/local.dart' show LocalTrackUri;
import '../subsonic/client.dart';
import 'widgets/artwork.dart';
import 'widgets/mini_player.dart';
import 'widgets/theme_ext.dart';
import 'widgets/track_tile.dart';

const _accent = brandAccent;

class NowPlayingPage extends ConsumerWidget {
  const NowPlayingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(currentTrackProvider);
    if (track == null) {
      return const Scaffold(body: Center(child: Text('Nothing playing.')));
    }
    final accent = ref.watch(accentTintProvider).valueOrNull ?? _accent;
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(tooltip: 'Close', icon: const Icon(Icons.keyboard_arrow_down), onPressed: () => Navigator.maybePop(context)),
          // Album icon button (only when there's an albumId to route to).
          // Replaces the previous tappable album name — the icon makes
          // the affordance unambiguous ("this takes me to the album").
          title: (track.albumId != null)
              ? IconButton(
                  tooltip: track.album ?? 'Album',
                  icon: const Icon(Icons.album_outlined),
                  onPressed: () => context.push(
                      '/album/${track.origin.name}/${track.albumId}'),
                )
              : null,
          actions: const [
            // Album mode toggle removed from the AppBar — it now lives
            // as "Stop at end of album" inside the sleep-timer sheet
            // (the round album icon was ambiguous on its own; users
            // didn't recognise it as a stop-after affordance).
            _ShareAction(),
            _SpeedAction(),
            _SleepAction(),
          ],
          bottom: TabBar(
            indicatorColor: accent,
            labelColor: accent,
            tabs: const [Tab(text: 'Player'), Tab(text: 'Queue'), Tab(text: 'Lyrics')],
          ),
        ),
        body: _TintBackground(
          child: TabBarView(children: [
            _PlayerTab(track: track),
            const _QueueTab(),
            _LyricsTab(track: track),
          ]),
        ),
        // Mini-player at the bottom of Now Playing too — gives quick
        // transport access from the Queue + Lyrics tabs where the
        // FAB isn't visible. Slightly redundant on the Player tab
        // (transport is right above) but harmless.
        bottomNavigationBar: const MiniPlayer(),
      ),
    );
  }
}

/// Soft top-down gradient using the dominant colour of the currently
/// playing artwork — adds life to Now Playing instead of a flat dark
/// scaffold. Computed once per track via palette_generator and cached
/// in state. Disabled when the user turns off the toggle or the track
/// has no fetchable artwork (local files without a URI).
class _TintBackground extends ConsumerWidget {
  final Widget child;
  const _TintBackground({required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Single source of truth for the tint colour lives in
    // [accentTintProvider]; this widget just renders the
    // soft top-down gradient when the provider yields a non-null
    // colour. The same provider feeds slider / FAB / heart accents,
    // so the visual stays consistent across the screen.
    final tint = ref.watch(accentTintProvider).valueOrNull;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (tint != null)
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [tint.withOpacity(0.30), Colors.transparent],
              ),
            ),
          ),
        child,
      ],
    );
  }
}

class _PlayerTab extends ConsumerWidget {
  final Track track;
  const _PlayerTab({required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.watch(audioEngineProvider);
    final state = ref.watch(playerStateProvider);
    final playing = state.playing;
    final accent = ref.watch(accentTintProvider).valueOrNull ?? _accent;
    final shuffle = ref.watch(shuffleProvider);
    final loop = ref.watch(loopProvider);

    // Position is NOT watched here — it ticks at ~10 Hz and would
    // rebuild the entire tab (including Artwork) every 100 ms.
    // [Artwork] then re-builds the signed Subsonic cover URL each
    // time (fresh salt+token per call) → CachedNetworkImage cancels
    // the in-flight fetch and restarts, infinitely → cover never
    // renders. Position lives inside [_ScrubberAndTimes] which is
    // the only widget that actually needs to rebuild on tick.

    return Stack(
      fit: StackFit.expand,
      children: [
        // Full-bleed background artwork. 1024 px source so up-scaling
        // to phone screen (1080 px native on a 411 dp width) stays
        // crisp. BoxFit.cover crops left/right edges of the square
        // cover to fill the tall portrait viewport — focal centre of
        // the artwork stays visible.
        _BgArtwork(track: track),
        // Dark gradient overlay: legibility of title / scrubber /
        // transport regardless of how bright the artwork is. Pure
        // black at the bottom (where the controls sit) fades to a
        // soft tint at the top.
        const _LegibilityScrim(),
        // Foreground content — pushed to the lower portion so the
        // artwork breathes above.
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                const Spacer(flex: 4),
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(track.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 22, fontWeight: FontWeight.w800)),
                          const SizedBox(height: 4),
                          Text(track.displayArtist,
                              style: TextStyle(
                                  color: context.textTertiary, fontSize: 14)),
                          if (ref
                              .watch(displayPrefsProvider)
                              .audioGeekInfoEnabled)
                            _AudioInfoLine(track: track),
                        ],
                      ),
                    ),
                    _FavoriteToggle(track: track),
                  ],
                ),
                const SizedBox(height: 12),
                const _ScrubberAndTimes(),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      tooltip: shuffle ? 'Shuffle on' : 'Shuffle off',
                      icon: Icon(Icons.shuffle,
                          color: shuffle ? accent : context.textSecondary),
                      onPressed: () => engine.setShuffle(!shuffle),
                    ),
                    IconButton(
                      tooltip: 'Previous track',
                      iconSize: 40,
                      icon: Icon(Icons.skip_previous, color: accent),
                      onPressed: engine.previous,
                    ),
                    FloatingActionButton(
                      onPressed: () => playing ? engine.pause() : engine.play(),
                      backgroundColor: accent,
                      foregroundColor: Colors.black,
                      child: Icon(playing ? Icons.pause : Icons.play_arrow, size: 32),
                    ),
                    IconButton(
                      tooltip: 'Next track',
                      iconSize: 40,
                      icon: Icon(Icons.skip_next, color: accent),
                      onPressed: engine.next,
                    ),
                    IconButton(
                      tooltip: loop == LoopMode.one
                          ? 'Repeat one'
                          : (loop == LoopMode.all ? 'Repeat all' : 'Repeat off'),
                      icon: Icon(
                        loop == LoopMode.one ? Icons.repeat_one : Icons.repeat,
                        color: loop == LoopMode.off
                            ? context.textSecondary
                            : accent,
                      ),
                      onPressed: () => engine.setRepeat(_cycleLoop(loop)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const _UpNextStrip(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  LoopMode _cycleLoop(LoopMode m) =>
      m == LoopMode.off ? LoopMode.all : (m == LoopMode.all ? LoopMode.one : LoopMode.off);
}

/// Full-bleed background artwork — replaces the centred rounded
/// square that previously dominated the Player tab. Renders at a
/// large source size (1024 px) so the up-scale to phone width stays
/// crisp; `BoxFit.cover` crops the square cover left+right to fill
/// the tall portrait viewport. `cacheKey` keyed by track unique key
/// rather than the salt-mutated URL so a rebuild doesn't trigger a
/// re-fetch (same defence as the main Artwork widget, but inlined
/// here because [Artwork] is hardcoded to a fixed `SizedBox(size)`).
class _BgArtwork extends ConsumerWidget {
  final Track track;
  const _BgArtwork({required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fallback = Container(color: const Color(0xFF18181B));
    if (track.coverArt == null) return fallback;
    // Subsonic: fetch the cover via the resolver — same source-of-
    // truth as the regular Artwork widget, but bigger (1024 px) +
    // BoxFit.cover so the square stretches to fill the tall portrait.
    if (track.origin == MediaOrigin.subsonic) {
      final s = ref.watch(subsonicResolverProvider).forId(track.serverId);
      if (s == null) return fallback;
      return CachedNetworkImage(
        imageUrl: s.coverUri(track.coverArt!, size: 1024).toString(),
        cacheKey: '${track.uniqueKey}:bg',
        fit: BoxFit.cover,
        fadeInDuration: const Duration(milliseconds: 220),
        fadeOutDuration: const Duration(milliseconds: 120),
        placeholder: (c, __) => fallback,
        errorWidget: (c, __, ___) => fallback,
      );
    }
    // Local: pull the embedded picture from MediaStore via our own
    // Kotlin channel (LocalLibrary.getArtwork). 1024 px target —
    // MediaStoreChannel's MediaMetadataRetriever fallback decodes +
    // downscales to whatever we ask, so we get a sharp full-bleed
    // background even from MP3s whose APIC frame MediaStore's own
    // loadThumbnail failed to extract.
    return FutureBuilder<Uint8List?>(
      future: ref.read(localLibraryProvider).getArtwork(
            track.coverArt!,
            size: 1024,
          ),
      builder: (c, snap) {
        if (!snap.hasData || snap.data == null) return fallback;
        return Image.memory(
          snap.data!,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        );
      },
    );
  }
}

/// Dark gradient over the full-bleed artwork — title, scrubber and
/// transport sit in the bottom half, where this scrim is darkest, so
/// they stay legible on any artwork brightness. Top is barely tinted
/// so the artwork stays the focal element.
class _LegibilityScrim extends StatelessWidget {
  const _LegibilityScrim();
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withOpacity(0.20),
              Colors.transparent,
              Colors.black.withOpacity(0.65),
              Colors.black.withOpacity(0.92),
            ],
            stops: const [0.0, 0.35, 0.78, 1.0],
          ),
        ),
      );
}

/// Editable queue: drag the handle to reorder, swipe a row to remove.
/// Watches `currentIndexStream` so the list rebuilds when auto-queue
/// appends a track at the tail without us having to invalidate
/// anything manually.
class _QueueTab extends ConsumerWidget {
  const _QueueTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(currentTrackProvider); // rebuild on track change
    // Watching currentQueueProvider so the full queue stays in sync
    // with auto-queue appends + Up Next. Without this the two views
    // could drift apart whenever a mutation happened between tracks.
    final queue = ref.watch(currentQueueProvider);
    final engine = ref.watch(audioEngineProvider);
    final currentIndex = engine.currentIndex;
    if (queue.isEmpty) return const Center(child: Text('Empty queue'));
    return ReorderableListView.builder(
      itemCount: queue.length,
      buildDefaultDragHandles: false,
      onReorder: (oldIndex, newIndex) {
        // ReorderableListView uses the "before-removal" newIndex convention,
        // hence the −1 when moving down. AudioEngine.moveInQueue expects the
        // final position post-move; we adjust here.
        final adjusted = newIndex > oldIndex ? newIndex - 1 : newIndex;
        engine.moveInQueue(oldIndex, adjusted);
      },
      itemBuilder: (_, i) => Dismissible(
        key: ValueKey('${queue[i].uniqueKey}-$i'),
        direction: DismissDirection.endToStart,
        background: Container(
          color: Colors.redAccent.withOpacity(0.7),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          child: const Icon(Icons.delete, color: Colors.white),
        ),
        onDismissed: (_) => engine.removeFromQueue(i),
        child: Row(
          children: [
            Expanded(
                child: TrackTile(
                    queue: queue, index: i, isPlaying: i == currentIndex)),
            ReorderableDragStartListener(
              index: i,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Icon(Icons.drag_handle, color: context.textTertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LyricsTab extends ConsumerStatefulWidget {
  final Track track;
  const _LyricsTab({required this.track});
  @override
  ConsumerState<_LyricsTab> createState() => _LyricsTabState();
}

class _LyricsTabState extends ConsumerState<_LyricsTab> {
  Future<SyncedLyrics?>? _future;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  @override
  void didUpdateWidget(covariant _LyricsTab old) {
    super.didUpdateWidget(old);
    if (old.track.id != widget.track.id) _fetch();
  }

  /// Tries OpenSubsonic `getLyricsBySongId` first (only call that yields
  /// timestamps); if the server doesn't implement it OR has no synced
  /// version, falls back to the classic `getLyrics` (plain text, wrapped
  /// into a synced=false payload so the renderer stays uniform).
  void _fetch() {
    final s = ref.read(subsonicProvider);
    if (s == null) {
      _future = Future.value(null);
      return;
    }
    _future = () async {
      final synced = await s.getLyricsBySongId(widget.track.id);
      if (synced != null) return synced;
      final plain = await s.getLyrics(
          artist: widget.track.artist, title: widget.track.title);
      if (plain == null || plain.isEmpty) return null;
      return SyncedLyrics(
        synced: false,
        lines: plain
            .split('\n')
            .map((l) => LyricsLine(start: Duration.zero, text: l))
            .toList(),
      );
    }();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<SyncedLyrics?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final r = snap.data;
          if (r == null || r.lines.isEmpty) {
            return Center(
                child: Text('No lyrics available.',
                    style: TextStyle(color: context.textMuted)));
          }
          if (r.synced) return _SyncedLyricsView(lyrics: r);
          // Plain — single block of text, nothing to sync against.
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Text(
              r.lines.map((l) => l.text).join('\n'),
              style: const TextStyle(fontSize: 16, height: 1.6),
            ),
          );
        },
      );
}

/// Renders timestamped lyrics with the active line highlighted in accent
/// + auto-scrolled to ~1/3 from the top. Subscribes once to the engine's
/// positionStream so the position-tick rate (10–30 Hz) doesn't trigger a
/// full ListView rebuild — only [setState] when the active index actually
/// changes (per line, every few seconds).
class _SyncedLyricsView extends ConsumerStatefulWidget {
  final SyncedLyrics lyrics;
  const _SyncedLyricsView({required this.lyrics});
  @override
  ConsumerState<_SyncedLyricsView> createState() => _SyncedLyricsViewState();
}

class _SyncedLyricsViewState extends ConsumerState<_SyncedLyricsView> {
  static const _lineHeight = 36.0;
  final _ctrl = ScrollController();
  StreamSubscription<Duration>? _posSub;
  int _active = -1;

  @override
  void initState() {
    super.initState();
    _posSub = ref.read(audioEngineProvider).positionStream.listen(_onPos);
  }

  void _onPos(Duration pos) {
    final lines = widget.lyrics.lines;
    var newActive = -1;
    for (var i = lines.length - 1; i >= 0; i--) {
      if (lines[i].start <= pos) {
        newActive = i;
        break;
      }
    }
    if (newActive == _active || newActive < 0 || !mounted) return;
    setState(() => _active = newActive);
    if (_ctrl.hasClients) {
      final target = (newActive * _lineHeight) - 120;
      _ctrl.animateTo(
        target.clamp(0, _ctrl.position.maxScrollExtent),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lines = widget.lyrics.lines;
    final accent = ref.watch(accentTintProvider).valueOrNull ?? _accent;
    return ListView.builder(
      controller: _ctrl,
      padding: const EdgeInsets.symmetric(vertical: 80, horizontal: 24),
      itemCount: lines.length,
      itemExtent: _lineHeight,
      itemBuilder: (ctx, i) {
        final active = i == _active;
        final text = lines[i].text.trim();
        return Center(
          child: Text(
            text.isEmpty ? '·' : text,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: active ? 19 : 15,
              fontWeight: active ? FontWeight.w800 : FontWeight.w500,
              color: active ? accent : ctx.textMuted,
            ),
          ),
        );
      },
    );
  }
}

/// Compact preview of the next 3 tracks in the queue, shown below the
/// transport on Now Playing → Player tab so the user can see what's
/// coming without jumping to the Queue tab. Tap a row → skip to that
/// track. Hides itself if there's nothing queued after the current.
class _UpNextStrip extends ConsumerWidget {
  const _UpNextStrip();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(currentTrackProvider); // rebuild on track change
    // Watching currentQueueProvider keeps Up Next perfectly in sync
    // with auto-queue appends, removals, reorders — previously we
    // only triggered on track change, so a queue mutation between
    // tracks wouldn't refresh the strip.
    final queue = ref.watch(currentQueueProvider);
    final engine = ref.watch(audioEngineProvider);
    final currentIdx = engine.currentIndex;
    // Show up to 6 upcoming tracks (2 columns × 3 rows) — user
    // request for a denser preview without scrolling.
    final upcoming = (currentIdx >= 0 && currentIdx + 1 < queue.length)
        ? queue.sublist(currentIdx + 1, (currentIdx + 7).clamp(0, queue.length))
        : const <Track>[];
    if (upcoming.isEmpty) return const SizedBox.shrink();
    Widget tile(int i) => InkWell(
          onTap: () => engine.seekToIndex(currentIdx + 1 + i),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                Artwork(
                    coverArt: upcoming[i].coverArt,
                    origin: upcoming[i].origin,
                    serverId: upcoming[i].serverId,
                    size: 32),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(upcoming[i].title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12)),
                      Text(upcoming[i].displayArtist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: context.textTertiary, fontSize: 10)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
    // 2-column layout: row N has tile (2N) on the left + tile (2N+1)
    // on the right when present. Odd total → last row has one tile
    // + an empty Expanded so the columns stay aligned.
    final rowCount = (upcoming.length + 1) ~/ 2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 4),
          child: Text('UP NEXT',
              style: TextStyle(
                  color: context.textTertiary,
                  fontSize: 10,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w700)),
        ),
        for (var row = 0; row < rowCount; row++)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(child: tile(row * 2)),
              const SizedBox(width: 12),
              Expanded(
                child: (row * 2 + 1 < upcoming.length)
                    ? tile(row * 2 + 1)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
      ],
    );
  }
}

/// AppBar action: share the currently-playing track as a text card.
/// `"Listening to {title} — {artist} · via digaudio"` — kept minimal
/// (no rich deep-link). Future: Subsonic `createShare` would
/// generate a server-side URL but needs share permissions on the
/// server, so out of scope for v1.
class _ShareAction extends ConsumerWidget {
  const _ShareAction();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(currentTrackProvider);
    return IconButton(
      tooltip: 'Share track',
      onPressed:
          track == null ? null : () => _shareTrack(context, ref, track),
      icon: const Icon(Icons.share_outlined),
    );
  }

  /// Real music share — not the old text card.
  ///
  /// **Subsonic**: calls `createShare` on the originating server,
  /// which returns a public URL anyone can use without auth (server
  /// streams to the recipient, no app required). Subject to the
  /// server's share permissions (Navidrome restricts to admins by
  /// default → surfaces error 50).
  ///
  /// **Local**: shares the file via Android's content URI. The
  /// system share sheet hands the file over to whichever app the
  /// user picks (Messages, Telegram, Drive, etc.).
  Future<void> _shareTrack(
      BuildContext context, WidgetRef ref, Track track) async {
    final messenger = ScaffoldMessenger.of(context);
    final subject = '${track.title} — ${track.displayArtist}';
    try {
      if (track.origin == MediaOrigin.subsonic) {
        final s = ref.read(subsonicResolverProvider).forTrack(track);
        if (s == null) {
          messenger.showSnackBar(
              const SnackBar(content: Text('No Subsonic server available.')));
          return;
        }
        final url = await s.createShare(track.id, description: subject);
        await Share.share(url, subject: subject);
      } else {
        // Local: hand the Android content URI to share_plus, which
        // wraps it through FileProvider so the recipient app gets a
        // proper attachable file.
        await Share.shareXFiles(
          [XFile(track.localContentUri)],
          subject: subject,
        );
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(
        content: Text(
          e.toString().contains('error 50')
              ? 'Server requires admin role to create shares.'
              : 'Share failed: $e',
        ),
      ));
    }
  }
}

// `_AlbumModeAction` removed in v0.30.25 — the round album icon was
// ambiguous on its own. The feature lives under
// "Stop at end of album" inside the sleep-timer sheet
// ([_SleepAction._show]). The underlying `AlbumModeService` is still
// the implementation.

/// Direct favorite toggle on Now Playing — no need to dive into the
/// actions sheet. Reads [favoriteKeysProvider] so it lights up the
/// instant any other surface (track tile, actions sheet) toggles.
class _FavoriteToggle extends ConsumerWidget {
  final Track track;
  const _FavoriteToggle({required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favKeys = ref.watch(favoriteKeysProvider).valueOrNull ?? const [];
    final isFav = favKeys.contains(track.uniqueKey);
    final accent = ref.watch(accentTintProvider).valueOrNull ?? _accent;
    return IconButton(
      tooltip: isFav ? 'Remove from favorites' : 'Add to favorites',
      iconSize: 28,
      icon: Icon(
        isFav ? Icons.favorite : Icons.favorite_border,
        color: isFav ? accent : context.textSecondary,
      ),
      onPressed: () => ref.read(favoritesProvider).toggle(track.uniqueKey),
    );
  }
}

String _fmt(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}

/// Scrubber + start/end time labels. Isolated so the ~10 Hz position
/// stream only rebuilds these tiny widgets — keeping the artwork +
/// transport + audio-info line out of the rebuild path. Critical for
/// the Subsonic cover: a rebuild calls [SubsonicClient.coverUri]
/// which generates a fresh salt+token URL each time, and
/// CachedNetworkImage would cancel + restart the fetch on every URL
/// change, never letting the cover land.
class _ScrubberAndTimes extends ConsumerWidget {
  const _ScrubberAndTimes();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.watch(audioEngineProvider);
    final position = ref.watch(positionProvider);
    final duration = ref.watch(durationProvider) ?? Duration.zero;
    final accent = ref.watch(accentTintProvider).valueOrNull ?? _accent;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: accent,
            thumbColor: accent,
            overlayColor: accent.withOpacity(0.25),
          ),
          child: Slider(
            value: position.inMilliseconds
                .toDouble()
                .clamp(0, duration.inMilliseconds.toDouble()),
            max: duration.inMilliseconds.toDouble().clamp(1, double.maxFinite),
            onChanged: (v) => engine.seek(Duration(milliseconds: v.toInt())),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmt(position),
                  style: TextStyle(color: context.textTertiary, fontSize: 11)),
              Text(_fmt(duration),
                  style: TextStyle(color: context.textTertiary, fontSize: 11)),
            ],
          ),
        ),
      ],
    );
  }
}

/// Codec · bit-depth/sample-rate · bitrate  →  device · output-rate
///
/// The whole point is *visual* verification of bit-transparent playback:
/// when the source sample rate is known (OpenSubsonic exposes it) and
/// differs from the system's output mix rate, the line turns amber + a
/// ⚠ glyph appears so the user can spot silent resampling at a glance
/// without trusting their ear. Falls back gracefully when fields are
/// missing (stock Subsonic, local files): we still show codec + device
/// but lose the resampling guarantee.
class _AudioInfoLine extends ConsumerWidget {
  final Track track;
  const _AudioInfoLine({required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routing = ref.watch(audioRoutingProvider).valueOrNull;
    final src = <String>[_codec(track.contentType)];
    if (track.samplingRate != null) {
      src.add(track.bitDepth != null
          ? '${track.bitDepth}-bit/${_khz(track.samplingRate!)}'
          : _khz(track.samplingRate!));
    }
    if (track.bitRate != null) src.add('${track.bitRate} kbps');

    final out = <String>[];
    if (routing != null) {
      out.add(routing.label);
      if (routing.outputSampleRate != null) out.add(_khz(routing.outputSampleRate!));
    }

    final resampling = track.samplingRate != null &&
        routing?.outputSampleRate != null &&
        track.samplingRate != routing!.outputSampleRate;

    final body = out.isEmpty
        ? src.join(' · ')
        : '${src.join(' · ')}  →  ${out.join(' · ')}${resampling ? '  ⚠' : ''}';

    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(
        body,
        // Allow wrapping — single line was clipping device name +
        // output kHz + ⚠ on phones with default 411 dp width. Two
        // lines fit `FLAC · 24-bit/96 kHz · 938 kbps  →  USB:
        // <device>` cleanly even with longer brand names.
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: resampling ? Colors.amber : context.textTertiary,
          fontSize: 11,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

String _codec(String? mime) {
  if (mime == null || mime.isEmpty) return 'Unknown';
  final m = mime.toLowerCase();
  if (m.contains('flac')) return 'FLAC';
  if (m.contains('mpeg') || m.contains('mp3')) return 'MP3';
  if (m.contains('opus')) return 'Opus';
  if (m.contains('vorbis') || m.contains('ogg')) return 'OGG';
  if (m.contains('alac')) return 'ALAC';
  if (m.contains('aac') || m.contains('m4a')) return 'AAC';
  if (m.contains('wav')) return 'WAV';
  return m.split('/').last.toUpperCase();
}

String _khz(int hz) {
  final v = hz / 1000;
  return v == v.truncateToDouble()
      ? '${v.toStringAsFixed(0)} kHz'
      : '${v.toStringAsFixed(1)} kHz';
}

String _fmtSpeed(double s) =>
    s == s.truncateToDouble() ? s.toStringAsFixed(1) : s.toStringAsFixed(2);

const _speedOptions = <double>[0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

/// AppBar action: live playback-speed label, opens a picker on tap.
/// Persistence happens in [PlaybackPrefs]; the [playbackSpeedProvider]
/// StateProvider is the reactive mirror so the label updates the moment
/// the user picks a new rate.
class _SpeedAction extends ConsumerWidget {
  const _SpeedAction();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final speed = ref.watch(playbackSpeedProvider);
    final active = speed != 1.0;
    final accent = ref.watch(accentTintProvider).valueOrNull ?? _accent;
    return TextButton(
      onPressed: () => _show(context, ref, speed, accent),
      style: TextButton.styleFrom(
        foregroundColor: active ? accent : context.textSecondary,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      child: Text('${_fmtSpeed(speed)}x',
          style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
    );
  }

  Future<void> _show(
          BuildContext context, WidgetRef ref, double current, Color accent) =>
      showModalBottomSheet(
        context: context,
        backgroundColor: const Color(0xFF18181B),
        showDragHandle: true,
        builder: (_) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text('Playback speed',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              for (final o in _speedOptions)
                ListTile(
                  leading: Icon(o == current ? Icons.check : Icons.speed,
                      color: o == current ? accent : null),
                  title: Text('${_fmtSpeed(o)}x'),
                  onTap: () async {
                    Navigator.pop(context);
                    final prefs = ref.read(playbackPrefsProvider);
                    prefs.playbackSpeed = o;
                    await prefs.save();
                    await ref.read(audioEngineProvider).setSpeed(o);
                    ref.read(playbackSpeedProvider.notifier).state = o;
                  },
                ),
            ],
          ),
        ),
      );
}

/// AppBar action: bedtime icon + live countdown when a sleep timer is
/// active. Idle = outlined icon, no label. Active = filled icon, "m:ss"
/// or "EOT" (end-of-track mode has no countdown).
class _SleepAction extends ConsumerWidget {
  const _SleepAction();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final remaining = ref.watch(sleepRemainingProvider).valueOrNull;
    final endOfTrack = ref.watch(sleepEndOfTrackProvider).valueOrNull ?? false;
    final albumArmed = ref.watch(albumModeArmedProvider).valueOrNull ?? false;
    final active = remaining != null || endOfTrack || albumArmed;
    final accent = ref.watch(accentTintProvider).valueOrNull ?? _accent;
    return TextButton(
      onPressed: () => _show(context, ref),
      style: TextButton.styleFrom(
        foregroundColor: active ? accent : context.textSecondary,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(active ? Icons.bedtime : Icons.bedtime_outlined, size: 20),
          if (active) ...[
            const SizedBox(width: 4),
            Text(
              remaining != null
                  ? _fmt(remaining)
                  : (albumArmed ? 'EOA' : 'EOT'),
              style: const TextStyle(
                  fontSize: 12, fontFeatures: [FontFeature.tabularFigures()]),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _show(BuildContext context, WidgetRef ref) {
    final timer = ref.read(sleepTimerProvider);
    final albumMode = ref.read(albumModeProvider);
    final albumArmed = ref.read(albumModeArmedProvider).valueOrNull ?? false;
    final anyActive = timer.active || albumArmed;
    return showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF18181B),
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Text('Sleep timer',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ),
            ListTile(
              leading: const Icon(Icons.skip_next),
              title: const Text('Stop at end of current track'),
              onTap: () {
                Navigator.pop(context);
                // Cancel any other sleep mode first.
                albumMode.disarm();
                timer.startAtEndOfTrack();
              },
            ),
            ListTile(
              leading: const Icon(Icons.album_outlined),
              title: const Text('Stop at end of album'),
              onTap: () {
                Navigator.pop(context);
                timer.cancel();
                albumMode.armForCurrent();
              },
            ),
            Divider(height: 1, color: context.dividerSoft),
            for (final mins in const [5, 15, 30, 45, 60])
              ListTile(
                leading: const Icon(Icons.bedtime_outlined),
                title: Text('$mins minutes'),
                onTap: () {
                  Navigator.pop(context);
                  albumMode.disarm();
                  timer.start(Duration(minutes: mins));
                },
              ),
            if (anyActive) ...[
              Divider(height: 1, color: context.dividerSoft),
              ListTile(
                leading: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
                title: const Text('Cancel timer',
                    style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(context);
                  timer.cancel();
                  albumMode.disarm();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
