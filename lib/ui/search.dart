import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../audio/providers.dart';
import 'widgets/artwork.dart';
import 'widgets/track_tile.dart';


class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});
  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  final _ctrl = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () {
      ref.read(searchQueryProvider.notifier).state = v;
    });
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchResultsProvider);
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _ctrl,
          autofocus: false,
          decoration: const InputDecoration(
            hintText: 'Search tracks, albums, artists…',
            prefixIcon: Icon(Icons.search),
            isDense: true,
          ),
          onChanged: _onChanged,
        ),
      ),
      body: results.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: Colors.redAccent))),
        data: (r) => r.isEmpty
            ? const Center(child: Text('Type to search.', style: TextStyle(color: Colors.white38)))
            : ListView(
                children: [
                  if (r.artists.isNotEmpty) ...[
                    const _Header('Artists'),
                    for (final a in r.artists)
                      ListTile(
                        leading: Artwork(coverArt: a.coverArt, origin: a.origin, size: 48,
                            borderRadius: BorderRadius.circular(24)),
                        title: Text(a.name),
                        subtitle: a.albumCount != null ? Text('${a.albumCount} albums') : null,
                        onTap: () => context.push('/artist/${a.origin.name}/${a.id}'),
                      ),
                  ],
                  if (r.albums.isNotEmpty) ...[
                    const _Header('Albums'),
                    for (final a in r.albums)
                      ListTile(
                        leading: Artwork(coverArt: a.coverArt, origin: a.origin, size: 48),
                        title: Text(a.title),
                        subtitle: a.artist != null ? Text(a.artist!) : null,
                        onTap: () => context.push('/album/${a.origin.name}/${a.id}'),
                      ),
                  ],
                  if (r.tracks.isNotEmpty) ...[
                    const _Header('Tracks'),
                    for (var i = 0; i < r.tracks.length; i++) TrackTile(queue: r.tracks, index: i),
                  ],
                ],
              ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(text, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      );
}
