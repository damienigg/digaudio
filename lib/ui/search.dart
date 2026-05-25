import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../audio/providers.dart';
import '../domain.dart';
import '../voice/voice_bridge.dart';
import 'widgets/artwork.dart';
import 'widgets/theme_ext.dart';
import 'widgets/track_tile.dart';

/// Search page with per-category "Show more" pagination.
///
/// First batch comes from [searchResultsProvider] (local songs + the
/// initial 20 remote results of each kind). Subsequent batches are
/// fetched via [SubsonicClient.search] with a per-category offset and
/// kept in local state, reset whenever the query changes. A
/// "Show more" button appears at the end of each section until a fetch
/// returns fewer than the requested page size (= server has no more).
class SearchPage extends ConsumerStatefulWidget {
  const SearchPage({super.key});
  @override
  ConsumerState<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends ConsumerState<SearchPage> {
  static const _pageSize = 20;

  final _ctrl = TextEditingController();
  Timer? _debounce;
  String _currentQuery = '';

  // Per-category extras fetched on "Show more". Reset whenever the
  // query string changes so we never mix results across searches.
  List<Track> _extraTracks = const [];
  List<Album> _extraAlbums = const [];
  List<Artist> _extraArtists = const [];
  bool _tracksExhausted = false;
  bool _albumsExhausted = false;
  bool _artistsExhausted = false;
  bool _loadingTracks = false;
  bool _loadingAlbums = false;
  bool _loadingArtists = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    super.dispose();
  }

  void _applyQuery(String v) {
    ref.read(searchQueryProvider.notifier).state = v;
    if (v == _currentQuery) return;
    _currentQuery = v;
    setState(() {
      _extraTracks = const [];
      _extraAlbums = const [];
      _extraArtists = const [];
      _tracksExhausted = false;
      _albumsExhausted = false;
      _artistsExhausted = false;
    });
  }

  void _onChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 280), () => _applyQuery(v));
  }

  Future<void> _voiceSearch() async {
    final text = await VoiceBridge.recognize();
    if (text == null || !mounted) return;
    _ctrl.text = text;
    _ctrl.selection = TextSelection.collapsed(offset: text.length);
    // Bypass the 280 ms debounce — the user spoke a complete query.
    _debounce?.cancel();
    _applyQuery(text);
  }

  /// Generic "load more" path — each call hits one category at offset
  /// `displayedRemoteCount` and either appends or marks exhausted.
  Future<void> _loadMore({
    required _Cat cat,
    required int currentRemoteCount,
  }) async {
    final s = ref.read(subsonicProvider);
    final q = _currentQuery.trim();
    if (s == null || q.isEmpty) return;
    if (cat == _Cat.tracks && _loadingTracks) return;
    if (cat == _Cat.albums && _loadingAlbums) return;
    if (cat == _Cat.artists && _loadingArtists) return;

    setState(() {
      if (cat == _Cat.tracks) _loadingTracks = true;
      if (cat == _Cat.albums) _loadingAlbums = true;
      if (cat == _Cat.artists) _loadingArtists = true;
    });
    try {
      final more = await s.search(
        q,
        // Zero the other categories so we only fetch the one we need.
        songCount: cat == _Cat.tracks ? _pageSize : 0,
        songOffset: cat == _Cat.tracks ? currentRemoteCount : 0,
        albumCount: cat == _Cat.albums ? _pageSize : 0,
        albumOffset: cat == _Cat.albums ? currentRemoteCount : 0,
        artistCount: cat == _Cat.artists ? _pageSize : 0,
        artistOffset: cat == _Cat.artists ? currentRemoteCount : 0,
      );
      if (!mounted || q != _currentQuery) return;
      setState(() {
        switch (cat) {
          case _Cat.tracks:
            _extraTracks = [..._extraTracks, ...more.tracks];
            if (more.tracks.length < _pageSize) _tracksExhausted = true;
          case _Cat.albums:
            _extraAlbums = [..._extraAlbums, ...more.albums];
            if (more.albums.length < _pageSize) _albumsExhausted = true;
          case _Cat.artists:
            _extraArtists = [..._extraArtists, ...more.artists];
            if (more.artists.length < _pageSize) _artistsExhausted = true;
        }
      });
    } catch (_) {
      // Silent — the user can tap again.
    } finally {
      if (mounted) {
        setState(() {
          if (cat == _Cat.tracks) _loadingTracks = false;
          if (cat == _Cat.albums) _loadingAlbums = false;
          if (cat == _Cat.artists) _loadingArtists = false;
        });
      }
    }
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
        actions: [
          IconButton(
            icon: const Icon(Icons.mic),
            tooltip: 'Voice search',
            onPressed: _voiceSearch,
          ),
        ],
      ),
      body: results.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e',
            style: const TextStyle(color: Colors.redAccent))),
        data: (r) {
          if (r.isEmpty) {
            return Center(
                child: Text('Type to search.',
                    style: TextStyle(color: context.textDisabled)));
          }
          final allArtists = [...r.artists, ..._extraArtists];
          final allAlbums = [...r.albums, ..._extraAlbums];
          // Local matches kept up front (provider gave them first);
          // remote tracks (initial + extras) follow. TrackTile uses
          // the index to play from the merged queue.
          final allTracks = [...r.tracks, ..._extraTracks];
          // The provider's r.artists/r.albums are the initial remote
          // page; remote-count = initial + extras for the offset.
          final remoteTrackOffset = r.tracks
                  .where((t) => t.origin == MediaOrigin.subsonic)
                  .length +
              _extraTracks.length;
          return ListView(
            children: [
              if (allArtists.isNotEmpty) ...[
                const _Header('Artists'),
                for (final a in allArtists)
                  ListTile(
                    leading: Artwork(
                        coverArt: a.coverArt,
                        origin: a.origin,
                        size: 48,
                        borderRadius: BorderRadius.circular(24)),
                    title: Text(a.name),
                    subtitle: a.albumCount != null
                        ? Text('${a.albumCount} albums')
                        : null,
                    onTap: () => context.push('/artist/${a.origin.name}/${a.id}'),
                  ),
                if (!_artistsExhausted)
                  _ShowMoreButton(
                      loading: _loadingArtists,
                      onPressed: () => _loadMore(
                          cat: _Cat.artists,
                          currentRemoteCount:
                              r.artists.length + _extraArtists.length)),
              ],
              if (allAlbums.isNotEmpty) ...[
                const _Header('Albums'),
                for (final a in allAlbums)
                  ListTile(
                    leading: Artwork(
                        coverArt: a.coverArt, origin: a.origin, size: 48),
                    title: Text(a.title),
                    subtitle: a.artist != null ? Text(a.artist!) : null,
                    onTap: () => context.push('/album/${a.origin.name}/${a.id}'),
                  ),
                if (!_albumsExhausted)
                  _ShowMoreButton(
                      loading: _loadingAlbums,
                      onPressed: () => _loadMore(
                          cat: _Cat.albums,
                          currentRemoteCount:
                              r.albums.length + _extraAlbums.length)),
              ],
              if (allTracks.isNotEmpty) ...[
                const _Header('Tracks'),
                for (var i = 0; i < allTracks.length; i++)
                  TrackTile(queue: allTracks, index: i),
                if (!_tracksExhausted)
                  _ShowMoreButton(
                      loading: _loadingTracks,
                      onPressed: () => _loadMore(
                          cat: _Cat.tracks,
                          currentRemoteCount: remoteTrackOffset)),
              ],
            ],
          );
        },
      ),
    );
  }
}

enum _Cat { tracks, albums, artists }

class _Header extends StatelessWidget {
  final String text;
  const _Header(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(text,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
      );
}

class _ShowMoreButton extends StatelessWidget {
  final bool loading;
  final VoidCallback onPressed;
  const _ShowMoreButton({required this.loading, required this.onPressed});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: loading ? null : onPressed,
            child: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Show more'),
          ),
        ),
      );
}
