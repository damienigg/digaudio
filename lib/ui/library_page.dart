import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../audio/providers.dart';
import 'widgets/album_card.dart';
import 'widgets/alpha_scroll.dart';
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
      data: (artists) {
        if (artists.isEmpty) return const _Empty('No artists.');
        // Sort once so the A→Z sidebar lines up; respect locale.
        final sorted = [...artists]
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        return AlphaScrollList(
          items: sorted,
          labelOf: (a) => a.name,
          builder: (_, a) => ListTile(
            leading: CircleAvatar(
              backgroundColor: const Color(0xFF1E1E22),
              child: Text(a.name.isNotEmpty ? a.name[0].toUpperCase() : '?'),
            ),
            title: Text(a.name),
            subtitle: a.albumCount != null ? Text('${a.albumCount} albums') : null,
            onTap: () => context.push('/artist/${a.origin.name}/${a.id}'),
          ),
        );
      },
    );
  }
}

class _PlaylistsTab extends ConsumerWidget {
  const _PlaylistsTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final subsonicState = ref.watch(subsonicPlaylistsProvider);
    final favKeys = ref.watch(favoriteKeysProvider).valueOrNull ?? const [];
    final localState = ref.watch(localPlaylistsProvider);
    return ListView(
      children: [
        ListTile(
          leading: const CircleAvatar(
            backgroundColor: Color(0xFF1ED760),
            child: Icon(Icons.favorite, color: Colors.black),
          ),
          title: const Text('Favorites'),
          subtitle: Text('${favKeys.length} tracks'),
          onTap: () => context.push('/favorites'),
        ),
        const Divider(height: 1, color: Colors.white12),
        ListTile(
          leading: const Icon(Icons.bookmark_outline),
          title: const Text('Wishlist'),
          subtitle: const Text('Tracks you\'d like to add to your library'),
          onTap: () => context.push('/wishlist'),
        ),
        const Divider(height: 1, color: Colors.white12),
        _ImportTile(),
        const Divider(height: 1, color: Colors.white12),
        const _SectionHeader('Local playlists'),
        localState.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(padding: const EdgeInsets.all(16), child: Text('$e')),
          data: (lists) => lists.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No local playlists yet — long-press a track and "Add to playlist" to create one.',
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                )
              : Column(
                  children: [
                    for (final pl in lists)
                      ListTile(
                        leading: const Icon(Icons.queue_music),
                        title: Text(pl.name),
                        onTap: () => context.push('/playlist/local/${pl.id}'),
                      ),
                  ],
                ),
        ),
        const Divider(height: 1, color: Colors.white12),
        const _SectionHeader('Subsonic playlists'),
        subsonicState.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(padding: const EdgeInsets.all(16), child: Text('$e')),
          data: (lists) => lists.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16),
                  child: Text('No Subsonic playlists.',
                      style: TextStyle(color: Colors.white54, fontSize: 12)),
                )
              : Column(
                  children: [
                    for (final pl in lists)
                      ListTile(
                        leading: Artwork(coverArt: pl.coverArt, origin: pl.origin, size: 48),
                        title: Text(pl.name),
                        subtitle: Text('${pl.songCount ?? 0} tracks'),
                        onTap: () => context.push('/playlist/${pl.origin.name}/${pl.id}'),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
        child: Text(text,
            style: const TextStyle(color: Colors.white60, fontSize: 11, letterSpacing: 1.5)),
      );
}

class _ImportTile extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) => ListTile(
        leading: const Icon(Icons.file_open_outlined),
        title: const Text('Import playlist…'),
        subtitle: const Text('From M3U / M3U8 or digaudio JSON'),
        onTap: () => _runImport(context, ref),
      );

  Future<void> _runImport(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['m3u', 'm3u8', 'json'],
    );
    if (picked == null || picked.files.isEmpty) return;
    final path = picked.files.single.path;
    if (path == null) return;

    messenger.showSnackBar(const SnackBar(content: Text('Importing…')));
    try {
      final report = await ref.read(playlistImporterProvider).importFile(File(path));
      messenger.showSnackBar(SnackBar(
        content: Text('Imported "${report.playlistName}" — '
            '${report.matched} matched, ${report.missing} missing'),
        duration: const Duration(seconds: 5),
      ));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Import failed: $e')));
    }
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
