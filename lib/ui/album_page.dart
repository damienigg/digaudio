import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/providers.dart';
import '../domain.dart';
import 'widgets/artwork.dart';
import 'widgets/mini_player.dart';
import 'widgets/theme_ext.dart';
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
      bottomNavigationBar: const MiniPlayer(),
      body: FutureBuilder<({Album album, List<Track> tracks})>(
        future: loader,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final album = snap.data!.album;
          final tracks = snap.data!.tracks;
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
                              Text(album.artist!, style: TextStyle(color: context.textTertiary)),
                            Text('${tracks.length} tracks', style: TextStyle(color: context.textDisabled, fontSize: 12)),
                          ],
                        ),
                      ),
                      _AlbumPlayButton(album: album, tracks: tracks),
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

/// Play CTA on the Album page header — tinted from the album's cover
/// palette so it matches the visual on Now Playing controls. Falls back
/// to brand accent green when the album is local / has no cover /
/// palette extraction fails.
class _AlbumPlayButton extends ConsumerWidget {
  final Album album;
  final List<Track> tracks;
  const _AlbumPlayButton({required this.album, required this.tracks});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = (album.origin == MediaOrigin.subsonic &&
            album.coverArt != null)
        ? (ref
                .watch(coverAccentProvider(
                    (serverId: album.serverId, coverArt: album.coverArt!)))
                .valueOrNull ??
            brandAccent)
        : brandAccent;
    return FilledButton.icon(
      icon: const Icon(Icons.play_arrow),
      label: const Text('Play'),
      style: FilledButton.styleFrom(
        backgroundColor: accent,
        foregroundColor: Colors.black,
      ),
      onPressed: tracks.isEmpty
          ? null
          : () => ref.read(audioEngineProvider).setQueue(tracks),
    );
  }
}
