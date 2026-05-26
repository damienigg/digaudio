import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/providers.dart';
import '../domain.dart';
import 'widgets/artwork.dart';
import 'widgets/mini_player.dart';
import 'widgets/theme_ext.dart';
import 'widgets/track_tile.dart';

class PlaylistPage extends ConsumerWidget {
  final String origin;
  final String id;
  const PlaylistPage({super.key, required this.origin, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mo = MediaOrigin.values.firstWhere((e) => e.name == origin);
    if (mo != MediaOrigin.subsonic) {
      return const Scaffold(body: Center(child: Text('Local playlists not yet supported.')));
    }
    return Scaffold(
      bottomNavigationBar: const MiniPlayer(),
      appBar: AppBar(),
      body: FutureBuilder<({Playlist playlist, List<Track> tracks})>(
        future: ref.read(subsonicProvider)?.getPlaylist(id),
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final pl = snap.data!.playlist;
          final tracks = snap.data!.tracks;
          final engine = ref.watch(audioEngineProvider);
          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Artwork(coverArt: pl.coverArt, origin: pl.origin, size: 96),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(pl.name,
                                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
                            Text('${tracks.length} tracks',
                                style: TextStyle(color: context.textMuted, fontSize: 12)),
                            const SizedBox(height: 8),
                            FilledButton.icon(
                              icon: const Icon(Icons.play_arrow),
                              label: const Text('Play'),
                              onPressed: tracks.isEmpty ? null : () => engine.setQueue(tracks),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverList.builder(
                itemCount: tracks.length,
                itemBuilder: (_, i) => TrackTile(queue: tracks, index: i),
              ),
            ],
          );
        },
      ),
    );
  }
}
