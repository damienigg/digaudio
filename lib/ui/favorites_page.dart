import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/providers.dart';
import '../domain.dart';
import 'widgets/track_tile.dart';

class FavoritesPage extends ConsumerWidget {
  const FavoritesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keys = ref.watch(favoriteKeysProvider).valueOrNull ?? const [];
    final resolver = ref.watch(trackResolverProvider);
    final engine = ref.watch(audioEngineProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Favorites'),
        actions: [
          if (keys.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.play_arrow),
              tooltip: 'Play all',
              onPressed: () async {
                final tracks = await resolver.resolveAll(keys);
                if (tracks.isNotEmpty) await engine.setQueue(tracks);
              },
            ),
        ],
      ),
      body: keys.isEmpty
          ? const _Empty()
          : FutureBuilder<List<Track>>(
              future: resolver.resolveAll(keys),
              builder: (_, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final tracks = snap.data!;
                if (tracks.isEmpty) {
                  return const Center(
                      child: Text('Favorites unavailable — check server / library.',
                          style: TextStyle(color: Colors.white54)));
                }
                return ListView.builder(
                  itemCount: tracks.length,
                  itemBuilder: (_, i) => TrackTile(queue: tracks, index: i),
                );
              },
            ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No favorites yet.\nTap the heart on any track to add it.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60),
          ),
        ),
      );
}
