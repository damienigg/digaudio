import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/providers.dart';
import '../domain.dart';
import 'widgets/album_card.dart';
import 'widgets/track_tile.dart';

class ArtistPage extends ConsumerWidget {
  final String origin;
  final String id;
  const ArtistPage({super.key, required this.origin, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mo = MediaOrigin.values.firstWhere((e) => e.name == origin);
    return Scaffold(
      appBar: AppBar(),
      body: mo == MediaOrigin.subsonic
          ? FutureBuilder<({Artist artist, List<Album> albums})>(
              future: ref.read(subsonicProvider)?.getArtist(id),
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final a = snap.data!.artist;
                final albums = snap.data!.albums;
                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Text(a.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                    ),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 180,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.75,
                      ),
                      itemCount: albums.length,
                      itemBuilder: (_, i) => AlbumCard(album: albums[i], width: 160),
                    ),
                  ],
                );
              },
            )
          : FutureBuilder<List<Track>>(
              future: ref.read(localLibraryProvider).getSongsByArtist(id),
              builder: (context, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final tracks = snap.data!;
                return ListView.builder(
                  itemCount: tracks.length,
                  itemBuilder: (_, i) => TrackTile(queue: tracks, index: i),
                );
              },
            ),
    );
  }
}
