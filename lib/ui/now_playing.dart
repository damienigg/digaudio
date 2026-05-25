import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../audio/providers.dart';
import '../domain.dart';
import 'widgets/artwork.dart';
import 'widgets/track_tile.dart';

const _accent = Color(0xFF1ED760);

class NowPlayingPage extends ConsumerWidget {
  const NowPlayingPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(currentTrackProvider).valueOrNull;
    if (track == null) {
      return const Scaffold(body: Center(child: Text('Nothing playing.')));
    }
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.keyboard_arrow_down), onPressed: () => Navigator.maybePop(context)),
          title: Text(track.album ?? track.title, style: const TextStyle(fontSize: 14)),
          actions: const [_SpeedAction(), _SleepAction()],
          bottom: const TabBar(
            indicatorColor: _accent,
            tabs: [Tab(text: 'Player'), Tab(text: 'Queue'), Tab(text: 'Lyrics')],
          ),
        ),
        body: TabBarView(children: [
          _PlayerTab(track: track),
          const _QueueTab(),
          _LyricsTab(track: track),
        ]),
      ),
    );
  }
}

class _PlayerTab extends ConsumerWidget {
  final Track track;
  const _PlayerTab({required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.watch(audioEngineProvider);
    final state = ref.watch(playerStateProvider).valueOrNull;
    final playing = state?.playing ?? false;
    final position = ref.watch(positionProvider).valueOrNull ?? Duration.zero;
    final duration = ref.watch(durationProvider).valueOrNull ?? Duration.zero;
    final shuffle = ref.watch(shuffleProvider).valueOrNull ?? false;
    final loop = ref.watch(loopProvider).valueOrNull ?? LoopMode.off;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            Expanded(
              flex: 5,
              child: Center(
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Artwork(
                    coverArt: track.coverArt,
                    origin: track.origin,
                    size: 600,
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(track.displayArtist, style: const TextStyle(color: Colors.white60, fontSize: 14)),
            const SizedBox(height: 12),
            Slider(
              value: position.inMilliseconds.toDouble().clamp(0, duration.inMilliseconds.toDouble()),
              max: duration.inMilliseconds.toDouble().clamp(1, double.maxFinite),
              onChanged: (v) => engine.seek(Duration(milliseconds: v.toInt())),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_fmt(position), style: const TextStyle(color: Colors.white60, fontSize: 11)),
                  Text(_fmt(duration), style: const TextStyle(color: Colors.white60, fontSize: 11)),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                IconButton(
                  icon: Icon(Icons.shuffle, color: shuffle ? _accent : Colors.white70),
                  onPressed: () => engine.setShuffle(!shuffle),
                ),
                IconButton(iconSize: 40, icon: const Icon(Icons.skip_previous), onPressed: engine.previous),
                FloatingActionButton(
                  onPressed: () => playing ? engine.pause() : engine.play(),
                  backgroundColor: _accent,
                  foregroundColor: Colors.black,
                  child: Icon(playing ? Icons.pause : Icons.play_arrow, size: 32),
                ),
                IconButton(iconSize: 40, icon: const Icon(Icons.skip_next), onPressed: engine.next),
                IconButton(
                  icon: Icon(
                    loop == LoopMode.one ? Icons.repeat_one : Icons.repeat,
                    color: loop == LoopMode.off ? Colors.white70 : _accent,
                  ),
                  onPressed: () => engine.setRepeat(_cycleLoop(loop)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  LoopMode _cycleLoop(LoopMode m) =>
      m == LoopMode.off ? LoopMode.all : (m == LoopMode.all ? LoopMode.one : LoopMode.off);
}

class _QueueTab extends ConsumerWidget {
  const _QueueTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final engine = ref.watch(audioEngineProvider);
    final queue = engine.currentQueue;
    if (queue.isEmpty) return const Center(child: Text('Empty queue'));
    return ListView.builder(
      itemCount: queue.length,
      itemBuilder: (_, i) => TrackTile(queue: queue, index: i),
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
  Future<String?>? _future;

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

  void _fetch() {
    final s = ref.read(subsonicProvider);
    _future = s?.getLyrics(artist: widget.track.artist, title: widget.track.title) ??
        Future.value(null);
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<String?>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final lyrics = snap.data;
          if (lyrics == null || lyrics.isEmpty) {
            return const Center(child: Text('No lyrics available.', style: TextStyle(color: Colors.white54)));
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Text(lyrics, style: const TextStyle(fontSize: 16, height: 1.6)),
          );
        },
      );
}

String _fmt(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
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
    return TextButton(
      onPressed: () => _show(context, ref, speed),
      style: TextButton.styleFrom(
        foregroundColor: active ? _accent : Colors.white70,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      child: Text('${_fmtSpeed(speed)}x',
          style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
    );
  }

  Future<void> _show(BuildContext context, WidgetRef ref, double current) =>
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
                      color: o == current ? _accent : null),
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
    final active = remaining != null || endOfTrack;
    return TextButton(
      onPressed: () => _show(context, ref),
      style: TextButton.styleFrom(
        foregroundColor: active ? _accent : Colors.white70,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(active ? Icons.bedtime : Icons.bedtime_outlined, size: 20),
          if (active) ...[
            const SizedBox(width: 4),
            Text(
              remaining != null ? _fmt(remaining) : 'EOT',
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
                timer.startAtEndOfTrack();
              },
            ),
            const Divider(height: 1, color: Colors.white12),
            for (final mins in const [5, 15, 30, 45, 60])
              ListTile(
                leading: const Icon(Icons.bedtime_outlined),
                title: Text('$mins minutes'),
                onTap: () {
                  Navigator.pop(context);
                  timer.start(Duration(minutes: mins));
                },
              ),
            if (timer.active) ...[
              const Divider(height: 1, color: Colors.white12),
              ListTile(
                leading: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
                title: const Text('Cancel timer', style: TextStyle(color: Colors.redAccent)),
                onTap: () {
                  Navigator.pop(context);
                  timer.cancel();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
