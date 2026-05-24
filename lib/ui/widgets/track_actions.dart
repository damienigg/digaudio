import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/providers.dart';
import '../../domain.dart';
import '../../library/downloads.dart';
import '../../subsonic/client.dart';
import 'artwork.dart';

/// Bottom sheet with the per-track actions: favorites, playlists, queue ops.
/// After adding to a playlist or favorites, surfaces a "Suggested next track"
/// hint computed via the same Similarity algorithm used by the auto-queue.
Future<void> showTrackActions(BuildContext context, WidgetRef ref, Track track) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF18181B),
    showDragHandle: true,
    builder: (_) => _TrackActionsSheet(track: track),
  );
}

class _TrackActionsSheet extends ConsumerWidget {
  final Track track;
  const _TrackActionsSheet({required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final favKeys = ref.watch(favoriteKeysProvider).valueOrNull ?? const [];
    final isFav = favKeys.contains(track.uniqueKey);
    final engine = ref.watch(audioEngineProvider);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Artwork(coverArt: track.coverArt, origin: track.origin, size: 56),
              title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(track.displayArtist, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            const Divider(height: 1, color: Colors.white12),
            ListTile(
              leading: Icon(isFav ? Icons.favorite : Icons.favorite_border,
                  color: isFav ? const Color(0xFF1ED760) : null),
              title: Text(isFav ? 'Remove from favorites' : 'Add to favorites'),
              onTap: () async {
                final scaffoldMessenger = ScaffoldMessenger.of(context);
                Navigator.pop(context);
                final fav = ref.read(favoritesProvider);
                await fav.toggle(track.uniqueKey);
                if (!isFav) await _suggestAfterFav(scaffoldMessenger, ref, track);
              },
            ),
            ListTile(
              leading: const Icon(Icons.playlist_add),
              title: const Text('Add to playlist'),
              onTap: () async {
                Navigator.pop(context);
                await showPlaylistPicker(context, ref, track);
              },
            ),
            ListTile(
              leading: const Icon(Icons.queue_music),
              title: const Text('Play next'),
              onTap: () {
                Navigator.pop(context);
                engine.playNext(track);
              },
            ),
            ListTile(
              leading: const Icon(Icons.add_to_queue),
              title: const Text('Add to queue'),
              onTap: () {
                Navigator.pop(context);
                engine.appendToQueue(track);
              },
            ),
            if (track.origin == MediaOrigin.subsonic)
              _DownloadTile(
                track: track,
                downloads: ref.read(downloadsProvider),
                subsonic: ref.read(subsonicProvider),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _suggestAfterFav(
      ScaffoldMessengerState messenger, WidgetRef ref, Track seed) async {
    final fav = ref.read(favoritesProvider);
    final excluded = (await fav.keys()).toSet();
    final suggestion = await ref.read(autoQueueProvider).suggestNext(seed, exclude: excluded);
    if (suggestion == null) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text('Suggested: ${suggestion.title} — ${suggestion.displayArtist}'),
        action: SnackBarAction(
          label: 'Add',
          onPressed: () => ref.read(favoritesProvider).add(suggestion.uniqueKey),
        ),
        duration: const Duration(seconds: 6),
      ),
    );
  }
}

Future<void> showPlaylistPicker(BuildContext context, WidgetRef ref, Track track) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: const Color(0xFF18181B),
    showDragHandle: true,
    builder: (_) => _PlaylistPicker(track: track),
  );
}

class _PlaylistPicker extends ConsumerWidget {
  final Track track;
  const _PlaylistPicker({required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playlists = ref.watch(localPlaylistsProvider);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text('Add to playlist',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          ),
          ListTile(
            leading: const Icon(Icons.add),
            title: const Text('New playlist…'),
            onTap: () async {
              final name = await _askName(context);
              if (name == null || name.isEmpty) return;
              final mgr = ref.read(playlistsProvider);
              final id = await mgr.create(name);
              await mgr.append(id, track.uniqueKey);
              if (context.mounted) {
                Navigator.pop(context);
                _suggestAfterPlaylistAdd(context, ref, track, id);
              }
            },
          ),
          const Divider(height: 1, color: Colors.white12),
          Flexible(
            child: playlists.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('$e'),
              data: (list) => list.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No playlists yet — create one above.',
                          style: TextStyle(color: Colors.white54)))
                  : ListView(
                      shrinkWrap: true,
                      children: [
                        for (final p in list)
                          ListTile(
                            leading: const Icon(Icons.queue_music),
                            title: Text(p.name),
                            onTap: () async {
                              await ref.read(playlistsProvider).append(p.id, track.uniqueKey);
                              if (context.mounted) {
                                Navigator.pop(context);
                                _suggestAfterPlaylistAdd(context, ref, track, p.id);
                              }
                            },
                          ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<String?> _askName(BuildContext context) async {
  final c = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('New playlist'),
      content: TextField(
        controller: c,
        autofocus: true,
        decoration: const InputDecoration(hintText: 'Playlist name'),
        textInputAction: TextInputAction.done,
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create')),
      ],
    ),
  );
  return (ok == true) ? c.text.trim() : null;
}

class _DownloadTile extends StatelessWidget {
  final Track track;
  final DownloadsManager downloads;
  final SubsonicClient? subsonic;
  const _DownloadTile({required this.track, required this.downloads, required this.subsonic});

  @override
  Widget build(BuildContext context) {
    final cached = downloads.cachedPathFor(track) != null;
    return ListTile(
      leading: Icon(cached ? Icons.download_done : Icons.download_for_offline),
      title: Text(cached ? 'Remove download' : 'Download for offline'),
      subtitle: subsonic == null && !cached
          ? const Text('No active server', style: TextStyle(fontSize: 11, color: Colors.white38))
          : null,
      enabled: cached || subsonic != null,
      onTap: () async {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        if (cached) {
          await downloads.remove(track);
          messenger.showSnackBar(const SnackBar(content: Text('Download removed')));
          return;
        }
        if (subsonic == null) return;
        messenger.showSnackBar(SnackBar(
          content: Text('Downloading "${track.title}"…'),
          duration: const Duration(minutes: 5),
        ));
        try {
          await downloads.download(track, subsonic!);
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(SnackBar(content: Text('Downloaded "${track.title}"')));
        } catch (e) {
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(SnackBar(content: Text('Download failed: $e')));
        }
      },
    );
  }
}

Future<void> _suggestAfterPlaylistAdd(
    BuildContext context, WidgetRef ref, Track seed, int playlistId) async {
  final mgr = ref.read(playlistsProvider);
  final excluded = (await mgr.trackKeys(playlistId)).toSet();
  final suggestion = await ref.read(autoQueueProvider).suggestNext(seed, exclude: excluded);
  if (suggestion == null || !context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Suggested: ${suggestion.title} — ${suggestion.displayArtist}'),
      action: SnackBarAction(
        label: 'Add',
        onPressed: () => mgr.append(playlistId, suggestion.uniqueKey),
      ),
      duration: const Duration(seconds: 6),
    ),
  );
}
