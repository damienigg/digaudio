import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/providers.dart';
import '../../domain.dart';
import 'artwork.dart';
import 'theme_ext.dart';

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
            Divider(height: 1, color: context.dividerSoft),
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
            if (track.origin == MediaOrigin.subsonic) _RatingRow(track: track),
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
              ListTile(
                leading: const Icon(Icons.radio),
                title: const Text('Start radio'),
                subtitle: const Text(
                    'Endless queue based on this track. Auto-refills via the '
                    'Subsonic similarity engine as you listen — disengages '
                    'when you switch to another queue.',
                    style: TextStyle(fontSize: 11)),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  Navigator.pop(context);
                  final ok = await ref
                      .read(radioModeProvider)
                      .startRadio(track);
                  if (!ok) {
                    messenger.showSnackBar(SnackBar(
                        content: Text(
                            'No similar tracks for "${track.title}" — server returned empty.')));
                  }
                },
              ),
            if (track.origin == MediaOrigin.subsonic) _DownloadTile(track: track),
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
          Divider(height: 1, color: context.dividerSoft),
          Flexible(
            child: playlists.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('$e'),
              data: (list) => list.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('No playlists yet — create one above.',
                          style: TextStyle(color: context.textMuted)))
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

/// Three states, three actions:
///   - uncached            → "Download for offline" (fetch + pin)
///   - auto-cached (false) → "Keep download" (pin existing file, no network)
///   - pinned    (true)    → "Remove download" (delete file + row)
class _DownloadTile extends ConsumerWidget {
  final Track track;
  const _DownloadTile({required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final downloads = ref.read(downloadsProvider);
    final subsonic = ref.watch(subsonicProvider);
    final state = ref.watch(cacheStateProvider).valueOrNull ?? const {};
    final pinned = state[track.uniqueKey]; // null | false | true

    late final IconData icon;
    late final String label;
    String? subtitle;
    VoidCallback? onTap;

    if (pinned == true) {
      icon = Icons.download_done;
      label = 'Remove download';
      onTap = () async {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        await downloads.remove(track);
        messenger.showSnackBar(const SnackBar(content: Text('Download removed')));
      };
    } else if (pinned == false) {
      icon = Icons.push_pin_outlined;
      label = 'Keep download';
      subtitle = 'Already cached — pin to protect from auto-eviction.';
      onTap = () async {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.pop(context);
        await downloads.pin(track);
        messenger.showSnackBar(const SnackBar(content: Text('Pinned')));
      };
    } else {
      icon = Icons.download_for_offline;
      label = 'Download for offline';
      if (subsonic == null) {
        subtitle = 'No active server';
      } else {
        onTap = () {
          final messenger = ScaffoldMessenger.of(context);
          Navigator.pop(context);
          ref.read(downloadQueueProvider).enqueue(track);
          messenger.showSnackBar(SnackBar(
            content: Text('Queued "${track.title}"'),
            duration: const Duration(seconds: 2),
          ));
        };
      }
    }

    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      subtitle: subtitle == null
          ? null
          : Text(subtitle, style: TextStyle(fontSize: 11, color: context.textDisabled)),
      enabled: onTap != null,
      onTap: onTap,
    );
  }
}

/// 5-star Subsonic rating. Tapping the current rating clears it (parity
/// with Substreamer / Symfonium). Optimistic UI — the manager rolls back
/// on network failure and emits a change so the row redraws to the truth.
class _RatingRow extends ConsumerWidget {
  final Track track;
  const _RatingRow({required this.track});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(ratingsChangesProvider); // rebuild on any rating change
    final mgr = ref.read(ratingsManagerProvider);
    final current = mgr.ratingOf(track);
    return ListTile(
      leading: Icon(current == 0 ? Icons.star_border : Icons.star,
          color: current == 0 ? null : const Color(0xFF1ED760)),
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 1; i <= 5; i++)
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              tooltip: i == current ? 'Clear rating' : 'Rate $i star${i == 1 ? '' : 's'}',
              icon: Icon(
                i <= current ? Icons.star : Icons.star_border,
                color: i <= current ? const Color(0xFF1ED760) : context.textTertiary,
              ),
              // Tap on the current rating clears it; otherwise sets to i.
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await mgr.setRating(track, i == current ? 0 : i);
                } catch (e) {
                  messenger.showSnackBar(SnackBar(content: Text('Rating failed: $e')));
                }
              },
            ),
        ],
      ),
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
