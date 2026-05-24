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
                    final tracks = await resolver.resolveAll(keys);
                    if (context.mounted) await _export(context, playlist, tracks);
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
          : FutureBuilder<List<Track>>(
              future: resolver.resolveAll(keys),
              builder: (_, snap) {
                if (!snap.hasData) return const Center(child: CircularProgressIndicator());
                final tracks = snap.data!;
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Text('${tracks.length} tracks',
                              style: const TextStyle(color: Colors.white60, fontSize: 12)),
                          const Spacer(),
                          FilledButton.icon(
                            icon: const Icon(Icons.play_arrow),
                            label: const Text('Play'),
                            onPressed: tracks.isEmpty ? null : () => engine.setQueue(tracks),
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
                          for (var i = 0; i < tracks.length; i++)
                            Dismissible(
                              key: ValueKey('plr-${playlist.id}-${tracks[i].uniqueKey}-$i'),
                              direction: DismissDirection.endToStart,
                              background: Container(
                                color: Colors.redAccent.withOpacity(0.5),
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 16),
                                child: const Icon(Icons.delete),
                              ),
                              onDismissed: (_) => mgr.removeAt(playlist.id, i),
                              child: Row(
                                children: [
                                  Expanded(child: TrackTile(queue: tracks, index: i)),
                                  ReorderableDragStartListener(
                                    index: i,
                                    child: const Padding(
                                      padding: EdgeInsets.symmetric(horizontal: 8),
                                      child: Icon(Icons.drag_indicator, color: Colors.white38),
                                    ),
                                  ),
                                ],
                              ),
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

class _Empty extends StatelessWidget {
  const _Empty();
  @override
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Empty playlist — open a track and tap "Add to playlist".',
              textAlign: TextAlign.center, style: TextStyle(color: Colors.white54)),
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

Future<void> _export(BuildContext context, LocalPlaylist pl, List<Track> tracks) async {
  // Portable JSON: keeps origin so it can be re-imported in another digaudio
  // install. Subsonic stream URLs and credentials are NOT included.
  final payload = {
    'format': 'digaudio.playlist.v1',
    'name': pl.name,
    'exportedAt': DateTime.now().toIso8601String(),
    'tracks': tracks
        .map((t) => {
              'key': t.uniqueKey,
              'title': t.title,
              'artist': t.artist,
              'album': t.album,
              'year': t.year,
              'duration_ms': t.duration?.inMilliseconds,
              'genre': t.genre,
            })
        .toList(),
  };
  final dir = await getTemporaryDirectory();
  final safe = pl.name.replaceAll(RegExp(r'[^A-Za-z0-9_\-]+'), '_');
  final file = File(p.join(dir.path, '$safe.digaudio.json'));
  await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload));
  await Share.shareXFiles([XFile(file.path, mimeType: 'application/json')], subject: pl.name);
}

