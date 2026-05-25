import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/providers.dart';
import '../../domain.dart';

const _accent = Color(0xFF1ED760);

/// Bulk-action toolbar that appears above the mini-player whenever any
/// track is selected via long-press. Five actions:
///   - Cancel (X)         — clear the selection, exit selection mode
///   - Favourite          — adds every selected track to favourites
///   - Add to playlist    — opens the local playlist picker
///   - Play next          — inserts the selection right after current
///   - Add to queue       — appends to the end of the queue
/// Actions clear the selection on success. Lives in AppShell so it's
/// available from every screen — start selecting in Library, navigate
/// to Search, add more, act on the union.
class SelectionBar extends ConsumerWidget {
  const SelectionBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sel = ref.watch(selectionProvider);
    final tracks = sel.values.toList();
    return Material(
      color: const Color(0xFF1E1E22),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.close),
              tooltip: 'Clear selection',
              onPressed: () => ref.read(selectionProvider.notifier).clear(),
            ),
            Text('${tracks.length} selected',
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.favorite_border),
              tooltip: 'Add to favourites',
              onPressed: () async {
                final fav = ref.read(favoritesProvider);
                for (final t in tracks) {
                  await fav.add(t.uniqueKey);
                }
                ref.read(selectionProvider.notifier).clear();
              },
            ),
            IconButton(
              icon: const Icon(Icons.playlist_add),
              tooltip: 'Add to playlist',
              onPressed: () => _addToPlaylist(context, ref, tracks),
            ),
            IconButton(
              icon: const Icon(Icons.queue_music),
              tooltip: 'Play next',
              onPressed: () async {
                final engine = ref.read(audioEngineProvider);
                // Reverse so that the first selected track ends up next
                // (each insert pushes the previous one further).
                for (final t in tracks.reversed) {
                  await engine.playNext(t);
                }
                ref.read(selectionProvider.notifier).clear();
              },
            ),
            IconButton(
              icon: const Icon(Icons.add_to_queue),
              tooltip: 'Add to queue',
              onPressed: () async {
                final engine = ref.read(audioEngineProvider);
                for (final t in tracks) {
                  await engine.appendToQueue(t);
                }
                ref.read(selectionProvider.notifier).clear();
              },
            ),
            IconButton(
              icon: const Icon(Icons.download_for_offline_outlined),
              tooltip: 'Download (Subsonic tracks)',
              onPressed: () {
                final messenger = ScaffoldMessenger.of(context);
                ref.read(downloadQueueProvider).enqueueAll(tracks);
                // enqueueAll filters non-Subsonic / already-queued silently;
                // just acknowledge with the input count.
                messenger.showSnackBar(SnackBar(
                  content: Text('Queued ${tracks.length} for download'),
                  duration: const Duration(seconds: 2),
                ));
                ref.read(selectionProvider.notifier).clear();
              },
            ),
            const SizedBox(width: 4),
            // Accent-coloured Play button so the primary action stands
            // out — replaces the current queue with the selection.
            FilledButton.icon(
              icon: const Icon(Icons.play_arrow, size: 18),
              label: const Text('Play'),
              style: FilledButton.styleFrom(
                backgroundColor: _accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                minimumSize: const Size(0, 36),
              ),
              onPressed: () async {
                await ref.read(audioEngineProvider).setQueue(tracks);
                ref.read(selectionProvider.notifier).clear();
              },
            ),
            const SizedBox(width: 4),
          ],
        ),
      ),
    );
  }

  /// Local playlist picker variant — same data source as the per-track
  /// picker but appends N keys instead of 1 on tap.
  Future<void> _addToPlaylist(
      BuildContext context, WidgetRef ref, List<Track> tracks) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: const Color(0xFF18181B),
      showDragHandle: true,
      builder: (_) {
        final lists = ref.watch(localPlaylistsProvider);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Text('Add ${tracks.length} tracks to playlist',
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 16)),
              ),
              lists.when(
                loading: () => const SizedBox(
                    height: 80, child: Center(child: CircularProgressIndicator())),
                error: (e, _) => Text('$e'),
                data: (items) => items.isEmpty
                    ? const Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                            'No playlists yet — create one from a single track first.'),
                      )
                    : Column(
                        children: [
                          for (final p in items)
                            ListTile(
                              leading: const Icon(Icons.queue_music),
                              title: Text(p.name),
                              onTap: () => Navigator.pop(context, p.id),
                            ),
                        ],
                      ),
              ),
            ],
          ),
        );
      },
    );
    if (picked == null) return;
    final mgr = ref.read(playlistsProvider);
    for (final t in tracks) {
      await mgr.append(picked, t.uniqueKey);
    }
    ref.read(selectionProvider.notifier).clear();
  }
}
