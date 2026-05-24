import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../audio/providers.dart';
import 'widgets/album_card.dart';
import 'widgets/artwork.dart';
import 'widgets/track_tile.dart';

class LibraryPage extends ConsumerStatefulWidget {
  const LibraryPage({super.key});
  @override
  ConsumerState<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends ConsumerState<LibraryPage> {
  bool _permissionAsked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (_permissionAsked) return;
      _permissionAsked = true;
      await ref.read(localLibraryProvider).requestPermission();
      ref.invalidate(localSongsProvider);
      ref.invalidate(localAlbumsProvider);
      ref.invalidate(localArtistsProvider);
    });
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Library'),
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: Color(0xFF1ED760),
            tabs: [
              Tab(text: 'Tracks'),
              Tab(text: 'Albums'),
              Tab(text: 'Artists'),
              Tab(text: 'Playlists'),
            ],
          ),
        ),
        body: const TabBarView(children: [
          _TracksTab(),
          _AlbumsTab(),
          _ArtistsTab(),
          _PlaylistsTab(),
        ]),
      ),
    );
  }
}

class _TracksTab extends ConsumerWidget {
  const _TracksTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = ref.watch(localSongsProvider);
    return local.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: Colors.redAccent))),
      data: (tracks) => tracks.isEmpty
          ? const _Empty('No local tracks found.')
          : ListView.builder(
              itemCount: tracks.length,
              itemBuilder: (_, i) => TrackTile(queue: tracks, index: i),
            ),
    );
  }
}

class _AlbumsTab extends ConsumerWidget {
  const _AlbumsTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final local = ref.watch(localAlbumsProvider);
    return local.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: Colors.redAccent))),
      data: (albums) => albums.isEmpty
          ? const _Empty('No albums.')
          : GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 180,
                mainAxisSpacing: 16,
                crossAxisSpacing: 12,
                childAspectRatio: 0.75,
              ),
              itemCount: albums.length,
              itemBuilder: (_, i) => AlbumCard(album: albums[i], width: 160),
            ),
    );
  }
}

class _ArtistsTab extends ConsumerWidget {
  const _ArtistsTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(localArtistsProvider);
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: Colors.redAccent))),
      data: (artists) => artists.isEmpty
          ? const _Empty('No artists.')
          : ListView.separated(
              itemCount: artists.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white12),
              itemBuilder: (_, i) {
                final a = artists[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF1E1E22),
                    child: Text(a.name.isNotEmpty ? a.name[0].toUpperCase() : '?'),
                  ),
                  title: Text(a.name),
                  subtitle: a.albumCount != null ? Text('${a.albumCount} albums') : null,
                  onTap: () => context.push('/artist/${a.origin.name}/${a.id}'),
                );
              },
            ),
    );
  }
}

class _PlaylistsTab extends ConsumerWidget {
  const _PlaylistsTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(subsonicPlaylistsProvider);
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: Colors.redAccent))),
      data: (lists) => lists.isEmpty
          ? const _Empty('No playlists.\nCreate playlists on your Subsonic server, or add local ones.')
          : ListView.separated(
              itemCount: lists.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white12),
              itemBuilder: (_, i) {
                final pl = lists[i];
                return ListTile(
                  leading: Artwork(coverArt: pl.coverArt, origin: pl.origin, size: 48),
                  title: Text(pl.name),
                  subtitle: Text('${pl.songCount ?? 0} tracks'),
                  onTap: () => context.push('/playlist/${pl.origin.name}/${pl.id}'),
                );
              },
            ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String text;
  const _Empty(this.text);
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(text, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white54)),
        ),
      );
}
