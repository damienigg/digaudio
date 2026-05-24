import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../audio/providers.dart';
import '../domain.dart';
import 'widgets/artwork.dart';
import 'widgets/track_tile.dart';

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
          bottom: const TabBar(
            indicatorColor: Color(0xFF1ED760),
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
                  icon: Icon(Icons.shuffle, color: shuffle ? const Color(0xFF1ED760) : Colors.white70),
                  onPressed: () => engine.setShuffle(!shuffle),
                ),
                IconButton(iconSize: 40, icon: const Icon(Icons.skip_previous), onPressed: engine.previous),
                FloatingActionButton(
                  onPressed: () => playing ? engine.pause() : engine.play(),
                  backgroundColor: const Color(0xFF1ED760),
                  foregroundColor: Colors.black,
                  child: Icon(playing ? Icons.pause : Icons.play_arrow, size: 32),
                ),
                IconButton(iconSize: 40, icon: const Icon(Icons.skip_next), onPressed: engine.next),
                IconButton(
                  icon: Icon(
                    loop == LoopMode.one ? Icons.repeat_one : Icons.repeat,
                    color: loop == LoopMode.off ? Colors.white70 : const Color(0xFF1ED760),
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
