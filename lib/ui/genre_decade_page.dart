import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/providers.dart';
import '../domain.dart';
import 'widgets/mini_player.dart';
import 'widgets/theme_ext.dart';
import 'widgets/track_tile.dart';

const _accent = Color(0xFF1ED760);

/// Shared scaffold for genre / decade detail pages — fetches a track
/// list from [SubsonicLibraryCache], shows a Play-all + Shuffle header,
/// then a scrollable TrackTile list. Used by both routes; the only
/// difference is the title + which cache method we call.
class _BrowsePage extends ConsumerWidget {
  final String title;
  final Future<List<Track>> Function() loader;
  const _BrowsePage({required this.title, required this.loader});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      bottomNavigationBar: const MiniPlayer(),
      appBar: AppBar(title: Text(title)),
      body: FutureBuilder<List<Track>>(
        future: loader(),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final tracks = snap.data ?? const [];
          if (tracks.isEmpty) {
            return Center(
                child: Text('No tracks here.',
                    style: TextStyle(color: context.textMuted)));
          }
          return ListView.builder(
            itemCount: tracks.length + 1,
            itemBuilder: (_, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () =>
                              ref.read(audioEngineProvider).setQueue(tracks),
                          icon: const Icon(Icons.play_arrow),
                          label: Text('Play all (${tracks.length})'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () {
                          final shuffled = [...tracks]..shuffle();
                          ref.read(audioEngineProvider).setQueue(shuffled);
                        },
                        icon: const Icon(Icons.shuffle),
                        label: const Text('Shuffle'),
                      ),
                    ],
                  ),
                );
              }
              return TrackTile(queue: tracks, index: i - 1);
            },
          );
        },
      ),
    );
  }
}

class GenrePage extends ConsumerWidget {
  final String genre;
  const GenrePage({super.key, required this.genre});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeAsync = ref.watch(activeServerProvider);
    final active = activeAsync.valueOrNull;
    return _BrowsePage(
      title: genre,
      loader: () => active == null
          ? Future.value(const [])
          : ref.read(subsonicCacheProvider).tracksOfGenre(active.id, genre),
    );
  }
}

class DecadePage extends ConsumerWidget {
  final int decade;
  const DecadePage({super.key, required this.decade});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeAsync = ref.watch(activeServerProvider);
    final active = activeAsync.valueOrNull;
    return _BrowsePage(
      title: '${decade}s',
      loader: () => active == null
          ? Future.value(const [])
          : ref.read(subsonicCacheProvider).tracksOfDecade(active.id, decade),
    );
  }
}
