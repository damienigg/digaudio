import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/providers.dart';
import '../domain.dart';
import 'widgets/artwork.dart';
import 'widgets/track_tile.dart';

class AlbumPage extends ConsumerWidget {
  final String origin;
  final String id;
  const AlbumPage({super.key, required this.origin, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mo = MediaOrigin.values.firstWhere((e) => e.name == origin);
    final loader = mo == MediaOrigin.subsonic
        ? _subsonicAlbum(ref, id)
        : _localAlbum(ref, id);

    return Scaffold(
      body: FutureBuilder<({Album album, List<Track> tracks})>(
        future: loader,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final album = snap.data!.album;
          final tracks = snap.data!.tracks;
          final engine = ref.watch(audioEngineProvider);
          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 320,
                pinned: true,
                flexibleSpace: FlexibleSpaceBar(
                  title: Text(album.title, style: const TextStyle(fontSize: 14)),
                  background: Artwork(
                    coverArt: album.coverArt,
                    origin: album.origin,
                    size: 360,
                    borderRadius: BorderRadius.zero,
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(album.title,
                                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
                            if (album.artist != null)
                              Text(album.artist!, style: const TextStyle(color: Colors.white60)),
                            Text('${tracks.length} tracks', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                          ],
                        ),
                      ),
                      FilledButton.icon(
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('Play'),
                        onPressed: tracks.isEmpty ? null : () => engine.setQueue(tracks),
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

  Future<({Album album, List<Track> tracks})> _subsonicAlbum(WidgetRef ref, String id) {
    final s = ref.read(subsonicProvider);
    if (s == null) {
      return Future.value((
        album: Album(id: id, title: 'No server', origin: MediaOrigin.subsonic),
        tracks: const <Track>[],
      ));
    }
    return s.getAlbum(id);
  }

  Future<({Album album, List<Track> tracks})> _localAlbum(WidgetRef ref, String id) async {
    final lib = ref.read(localLibraryProvider);
    final tracks = await lib.getSongsInAlbum(id);
    final albums = await lib.getAllAlbums();
    final album = albums.firstWhere((a) => a.id == id,
        orElse: () => Album(id: id, title: 'Album', origin: MediaOrigin.local));
    return (album: album, tracks: tracks);
  }
}
