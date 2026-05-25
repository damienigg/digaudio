import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../audio/providers.dart';
import '../core/db.dart';
import '../domain.dart';
import 'widgets/theme_ext.dart';
import 'widgets/track_tile.dart';

class LocalPlaylistPage extends ConsumerStatefulWidget {
  final int playlistId;
  const LocalPlaylistPage({super.key, required this.playlistId});
  @override
  ConsumerState<LocalPlaylistPage> createState() => _LocalPlaylistPageState();
}

class _LocalPlaylistPageState extends ConsumerState<LocalPlaylistPage> {
  @override
  Widget build(BuildContext context) {
    final playlist = ref.watch(playlistByIdProvider(widget.playlistId));
    return playlist.when(
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => Scaffold(body: Center(child: Text('$e'))),
      data: (pl) => pl == null
          ? const Scaffold(body: Center(child: Text('Playlist not found.')))
          : _Body(playlist: pl),
    );
  }
}

class _Body extends ConsumerWidget {
  final LocalPlaylist playlist;
  const _Body({required this.playlist});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final keys = ref.watch(playlistKeysProvider(playlist.id)).valueOrNull ?? const [];
    final resolver = ref.watch(trackResolverProvider);
    final mgr = ref.watch(playlistsProvider);
    final engine = ref.watch(audioEngineProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(playlist.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Rename',
            onPressed: () async {
              final name = await _renameDialog(context, playlist.name);
              if (name != null && name.isNotEmpty) await mgr.rename(playlist.id, name);
            },
          ),
          IconButton(
            icon: const Icon(Icons.ios_share),
            tooltip: 'Export',
            onPressed: keys.isEmpty
                ? null
                : () async {
                    final entries = await resolver.resolveEntries(keys);
                    if (context.mounted) await _export(context, playlist, entries);
                  },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
            onPressed: () async {
              final ok = await _confirmDelete(context, playlist.name);
              if (ok != true) return;
              await mgr.delete(playlist.id);
              if (context.mounted) Navigator.maybePop(context);
            },
          ),
        ],
      ),
      body: keys.isEmpty
          ? const _Empty()
          : FutureBuilder<List<PlaylistEntry>>(
              future: resolver.resolveEntries(keys),
              builder: (_, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final entries = snap.data!;
                final playable = entries.whereType<TrackEntry>().map((e) => e.track).toList();
                final missingCount = entries.length - playable.length;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Text(
                            missingCount == 0
                                ? '${entries.length} tracks'
                                : '${playable.length} of ${entries.length} available',
                            style: TextStyle(color: context.textTertiary, fontSize: 12),
                          ),
                          const Spacer(),
                          FilledButton.icon(
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Play'),
                            onPressed: playable.isEmpty ? null : () => engine.setQueue(playable),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ReorderableListView(
                        buildDefaultDragHandles: false,
                        onReorder: (oldIndex, newIndex) async {
                          final reordered = List<String>.from(keys);
                          if (newIndex > oldIndex) newIndex -= 1;
                          final moved = reordered.removeAt(oldIndex);
                          reordered.insert(newIndex, moved);
                          await mgr.reorder(playlist.id, reordered);
                        },
                        children: [
                          for (var i = 0; i < entries.length; i++)
                            _EntryRow(
                              key: ValueKey('plr-${playlist.id}-$i-${keys[i]}'),
                              entry: entries[i],
                              playableQueue: playable,
                              index: i,
                              onRemove: () => mgr.removeAt(playlist.id, i),
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }
}

class _EntryRow extends ConsumerWidget {
  final PlaylistEntry entry;
  final List<Track> playableQueue;
  final int index;
  final VoidCallback onRemove;
  const _EntryRow({
    super.key,
    required this.entry,
    required this.playableQueue,
    required this.index,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Dismissible(
      key: ValueKey('dis-$index-${entry.displayTitle}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.redAccent.withOpacity(0.5),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 16),
        child: const Icon(Icons.delete),
      ),
      onDismissed: (_) => onRemove(),
      child: Row(
        children: [
          Expanded(
            child: switch (entry) {
              TrackEntry(:final track) => TrackTile(
                  queue: playableQueue,
                  index: playableQueue.indexOf(track).clamp(0, playableQueue.length - 1),
                ),
              MissingEntry m => _MissingTile(entry: m),
            },
          ),
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Icon(Icons.drag_indicator, color: context.textDisabled),
            ),
          ),
        ],
      ),
    );
  }
}

class _MissingTile extends ConsumerWidget {
  final MissingEntry entry;
  const _MissingTile({required this.entry});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Opacity(
        opacity: 0.5,
        child: ListTile(
          leading: Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF1E1E22),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: context.outlineStrong, width: 1),
            ),
            child: Icon(Icons.cloud_off, color: context.textDisabled),
          ),
          title: Text(entry.title, style: const TextStyle(decoration: TextDecoration.lineThrough)),
          subtitle: Text(
            [entry.artist, entry.album].whereType<String>().join(' • '),
            style: const TextStyle(fontSize: 11),
          ),
          trailing: IconButton(
            tooltip: 'Add to wishlist',
            icon: const Icon(Icons.bookmark_add_outlined),
            onPressed: () async {
              await ref.read(wishlistManagerProvider).add(
                    title: entry.title,
                    artist: entry.artist,
                    album: entry.album,
                  );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Added to wishlist')),
                );
              }
            },
          ),
        ),
      );
}

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('Empty playlist — open a track and tap "Add to playlist".',
              textAlign: TextAlign.center, style: TextStyle(color: context.textMuted)),
        ),
      );
}

Future<String?> _renameDialog(BuildContext context, String current) async {
  final c = TextEditingController(text: current);
  final ok = await showDialog<bool>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Rename playlist'),
      content: TextField(controller: c, autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
      ],
    ),
  );
  return (ok == true) ? c.text.trim() : null;
}

Future<bool?> _confirmDelete(BuildContext context, String name) => showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Delete "$name"?'),
        content: const Text('Tracks themselves are kept; only the playlist is removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );

Future<void> _export(BuildContext context, LocalPlaylist pl, List<PlaylistEntry> entries) async {
  // Portable JSON: preserves origin AND missing entries so a roundtrip keeps
  // the user's intent. No credentials, no stream URLs.
  final payload = {
    'format': 'digaudio.playlist.v1',
    'name': pl.name,
    'exportedAt': DateTime.now().toIso8601String(),
    'tracks': entries
        .map((e) => switch (e) {
              TrackEntry(:final track) => {
                  'key': track.uniqueKey,
                  'title': track.title,
                  'artist': track.artist,
                  'album': track.album,
                  'year': track.year,
                  'duration_ms': track.duration?.inMilliseconds,
                  'genre': track.genre,
                },
              MissingEntry m => {
                  'missing': true,
                  'title': m.title,
                  'artist': m.artist,
                  'album': m.album,
                },
            })
        .toList(),
  };
  final dir = await getTemporaryDirectory();
  final safe = pl.name.replaceAll(RegExp(r'[^A-Za-z0-9_\-]+'), '_');
  final file = File(p.join(dir.path, '$safe.digaudio.json'));
  await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
  await Share.shareXFiles([XFile(file.path, mimeType: 'application/json')], subject: pl.name);
}
