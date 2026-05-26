import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../audio/providers.dart';
import 'widgets/album_card.dart';
import 'widgets/alpha_scroll.dart';
import 'widgets/artwork.dart';
import 'widgets/theme_ext.dart';
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
      length: 6,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Library'),
          actions: const [_LibrarySourceToggle()],
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: Color(0xFF1ED760),
            tabs: [
              Tab(text: 'Tracks'),
              Tab(text: 'Albums'),
              Tab(text: 'Artists'),
              Tab(text: 'Genres'),
              Tab(text: 'Decades'),
              Tab(text: 'Playlists'),
            ],
          ),
        ),
        body: const TabBarView(children: [
          _TracksTab(),
          _AlbumsTab(),
          _ArtistsTab(),
          _GenresTab(),
          _DecadesTab(),
          _PlaylistsTab(),
        ]),
      ),
    );
  }
}

/// Genres come from the Subsonic library cache. Empty list = cache not
/// synced yet → show a hint pointing the user to Settings → Playback →
/// Sync library.
class _GenresTab extends ConsumerWidget {
  const _GenresTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeAsync = ref.watch(activeServerProvider);
    final active = activeAsync.valueOrNull;
    if (active == null) {
      return const _Empty('No active Subsonic server.');
    }
    return FutureBuilder<List<({String genre, int count})>>(
      future: ref.read(subsonicCacheProvider).genres(active.id),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snap.data ?? const [];
        if (list.isEmpty) {
          return const _Empty(
              'No genres — sync the library first (Settings → Playback → Sync library).');
        }
        return ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, __) =>
              Divider(height: 1, color: context.dividerSoft),
          itemBuilder: (_, i) => ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFF1E1E22),
              child: Icon(Icons.label_outline, size: 18),
            ),
            title: Text(list[i].genre),
            subtitle: Text('${list[i].count} tracks'),
            onTap: () => context.push(
                '/genre/${Uri.encodeComponent(list[i].genre)}'),
          ),
        );
      },
    );
  }
}

class _DecadesTab extends ConsumerWidget {
  const _DecadesTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeAsync = ref.watch(activeServerProvider);
    final active = activeAsync.valueOrNull;
    if (active == null) {
      return const _Empty('No active Subsonic server.');
    }
    return FutureBuilder<List<({int decade, int count})>>(
      future: ref.read(subsonicCacheProvider).decades(active.id),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snap.data ?? const [];
        if (list.isEmpty) {
          return const _Empty(
              'No decades — sync the library first (Settings → Playback → Sync library).');
        }
        return ListView.separated(
          itemCount: list.length,
          separatorBuilder: (_, __) =>
              Divider(height: 1, color: context.dividerSoft),
          itemBuilder: (_, i) => ListTile(
            leading: const CircleAvatar(
              backgroundColor: Color(0xFF1E1E22),
              child: Icon(Icons.history, size: 18),
            ),
            title: Text("${list[i].decade}s"),
            subtitle: Text('${list[i].count} tracks'),
            onTap: () => context.push('/decade/${list[i].decade}'),
          ),
        );
      },
    );
  }
}

class _TracksTab extends ConsumerWidget {
  const _TracksTab();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(libraryTracksProvider);
    return state.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: Colors.redAccent))),
      data: (tracks) => tracks.isEmpty
          ? const _Empty('No tracks. (Sync the Subsonic library cache via Settings → Playback.)')
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
    final local = ref.watch(libraryAlbumsProvider);
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
    final state = ref.watch(libraryArtistsProvider);
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
        Divider(height: 1, color: context.dividerSoft),
        ListTile(
          leading: const Icon(Icons.bookmark_outline),
          title: const Text('Wishlist'),
          subtitle: const Text('Tracks you\'d like to add to your library'),
          onTap: () => context.push('/wishlist'),
        ),
        Divider(height: 1, color: context.dividerSoft),
        ListTile(
          leading: const Icon(Icons.bar_chart),
          title: const Text('Stats'),
          subtitle: const Text('Top tracks, top artists, and the "Most played" smart mix'),
          onTap: () => context.push('/stats'),
        ),
        Divider(height: 1, color: context.dividerSoft),
        const _SmartPlaylistsSection(),
        Divider(height: 1, color: context.dividerSoft),
        _ImportTile(),
        Divider(height: 1, color: context.dividerSoft),
        const _SectionHeader('Local playlists'),
        localState.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(padding: const EdgeInsets.all(16), child: Text('$e')),
          data: (lists) => lists.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No local playlists yet — long-press a track and "Add to playlist" to create one.',
                      style: TextStyle(color: context.textMuted, fontSize: 12)),
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
        Divider(height: 1, color: context.dividerSoft),
        const _SectionHeader('Subsonic playlists'),
        subsonicState.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          ),
          error: (e, _) => Padding(padding: const EdgeInsets.all(16), child: Text('$e')),
          data: (lists) => lists.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text('No Subsonic playlists.',
                      style: TextStyle(color: context.textMuted, fontSize: 12)),
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
            style: TextStyle(color: context.textTertiary, fontSize: 11, letterSpacing: 1.5)),
      );
}

/// Header row + "New smart playlist" + drift-watched list of existing
/// smart playlists. Tap a playlist → viewer page. Tap the action chip
/// → editor in creation mode.
class _SmartPlaylistsSection extends ConsumerWidget {
  const _SmartPlaylistsSection();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(smartPlaylistsListProvider);
    return Column(
      children: [
        ListTile(
          leading: const Icon(Icons.auto_awesome),
          title: const Text('Smart playlists'),
          subtitle: const Text('Rules-based — materialise from your library on open'),
          trailing: TextButton.icon(
            icon: const Icon(Icons.add, size: 18),
            label: const Text('New'),
            onPressed: () => context.push('/playlist/smart/new/edit'),
          ),
        ),
        list.when(
          loading: () => const SizedBox(height: 8),
          error: (e, _) => Padding(
              padding: const EdgeInsets.all(16), child: Text('$e')),
          data: (items) => items.isEmpty
              ? const SizedBox()
              : Column(
                  children: [
                    for (final p in items)
                      ListTile(
                        leading: const Icon(Icons.filter_alt_outlined),
                        title: Text(p.name),
                        onTap: () => context.push('/playlist/smart/${p.id}'),
                      ),
                  ],
                ),
        ),
      ],
    );
  }
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
          child: Text(text, textAlign: TextAlign.center, style: TextStyle(color: context.textMuted)),
        ),
      );
}

/// Source picker for the Library Tracks/Albums/Artists tabs — local
/// files / Subsonic cache / both. Sits in the Library AppBar as a
/// popup so it doesn't fight for nav-bar real estate.
class _LibrarySourceToggle extends ConsumerWidget {
  const _LibrarySourceToggle();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final src = ref.watch(librarySourceProvider);
    final icon = switch (src) {
      LibrarySource.local => Icons.phone_android,
      LibrarySource.remote => Icons.cloud_outlined,
      LibrarySource.both => Icons.all_inclusive,
    };
    return PopupMenuButton<LibrarySource>(
      tooltip: 'Library source',
      icon: Icon(icon),
      initialValue: src,
      onSelected: (v) =>
          ref.read(librarySourceProvider.notifier).state = v,
      itemBuilder: (_) => const [
        PopupMenuItem(
            value: LibrarySource.both,
            child: Row(children: [
              Icon(Icons.all_inclusive, size: 18),
              SizedBox(width: 8),
              Text('Local + Subsonic'),
            ])),
        PopupMenuItem(
            value: LibrarySource.local,
            child: Row(children: [
              Icon(Icons.phone_android, size: 18),
              SizedBox(width: 8),
              Text('Local only'),
            ])),
        PopupMenuItem(
            value: LibrarySource.remote,
            child: Row(children: [
              Icon(Icons.cloud_outlined, size: 18),
              SizedBox(width: 8),
              Text('Subsonic only'),
            ])),
      ],
    );
  }
}
