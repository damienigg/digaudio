import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/db.dart';
import '../domain.dart';
import '../subsonic/client.dart';

/// Per-server local cache of the slim song metadata the similarity scorer
/// needs.
///
/// Built once by paginating `getAlbumList2` then calling `getAlbum` per
/// album — the only realistic way to enumerate a full Subsonic library
/// (the API has no "all songs" endpoint). For ~1000 albums on a
/// Tailscale-local server that's roughly 1-2 minutes of background HTTP.
///
/// Once built, AutoQueue scores against the WHOLE library instantly
/// instead of a 200-song random sample. The cache is scoped by serverId
/// so multiple Subsonic servers coexist without cross-contamination.
class SubsonicLibraryCache {
  static const int _pageSize = 500;
  static const String _kLastSyncPrefix = 'subsonic.cache.lastSync.';
  static const String _kCountPrefix = 'subsonic.cache.count.';

  final AppDb _db;
  SubsonicLibraryCache(this._db);

  /// Total number of cached songs for this server, or 0 if never synced.
  Future<int> count(String serverId) async {
    final cnt = _db.cachedSubsonicSongs.songId.count();
    final row = await (_db.selectOnly(_db.cachedSubsonicSongs)
          ..addColumns([cnt])
          ..where(_db.cachedSubsonicSongs.serverId.equals(serverId)))
        .getSingle();
    return row.read(cnt) ?? 0;
  }

  Future<DateTime?> lastSync(String serverId) async {
    final p = await SharedPreferences.getInstance();
    final iso = p.getString('$_kLastSyncPrefix$serverId');
    return iso == null ? null : DateTime.tryParse(iso);
  }

  /// Reads the entire cached library for [serverId] as full [Track]
  /// objects. Cheap — even a 50k-row scan returns in tens of ms.
  /// Derives the full album list for [serverId] from the cached
  /// per-track data — same shape `LocalLibrary.getAllAlbums` exposes,
  /// so the Library tabs can union local + Subsonic uniformly.
  Future<List<Album>> allAlbums(String serverId) async {
    final tracks = await all(serverId);
    final groups = <String, List<Track>>{};
    for (final t in tracks) {
      if (t.albumId == null) continue;
      groups.putIfAbsent(t.albumId!, () => []).add(t);
    }
    return groups.entries
        .map((e) {
          final first = e.value.first;
          return Album(
            id: e.key,
            title: first.album ?? 'Unknown',
            artist: first.artist,
            artistId: first.artistId,
            coverArt: first.coverArt,
            songCount: e.value.length,
            origin: MediaOrigin.subsonic,
            serverId: serverId,
          );
        })
        .toList(growable: false)
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  }

  /// Derives the full artist list for [serverId]. albumCount is the
  /// number of distinct albumIds linked to that artist via the cache.
  Future<List<Artist>> allArtists(String serverId) async {
    final tracks = await all(serverId);
    final byId = <String, ({String name, Set<String> albums})>{};
    for (final t in tracks) {
      if (t.artistId == null) continue;
      final existing = byId[t.artistId!];
      final albums = existing?.albums ?? <String>{};
      if (t.albumId != null) albums.add(t.albumId!);
      byId[t.artistId!] = (name: t.artist ?? 'Unknown', albums: albums);
    }
    return byId.entries
        .map((e) => Artist(
              id: e.key,
              name: e.value.name,
              albumCount: e.value.albums.length,
              origin: MediaOrigin.subsonic,
              serverId: serverId,
            ))
        .toList(growable: false)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<List<Track>> all(String serverId) async {
    final rows = await (_db.select(_db.cachedSubsonicSongs)
          ..where((s) => s.serverId.equals(serverId)))
        .get();
    return rows.map(_toTrack).toList(growable: false);
  }

  /// Batch lookup by song id — one SQL `WHERE song_id IN (…)` instead
  /// of N per-track HTTP requests. Server-agnostic (returns the first
  /// row per id across all cached servers); id collisions across
  /// distinct Subsonic servers are astronomically rare in practice.
  /// Used by [TrackResolver.resolveKeys] to short-circuit the stats
  /// page's huge resolve fan-out.
  Future<Map<String, Track>> byIds(Iterable<String> ids) async {
    final list = ids.toList(growable: false);
    if (list.isEmpty) return const {};
    final rows = await (_db.select(_db.cachedSubsonicSongs)
          ..where((s) => s.songId.isIn(list)))
        .get();
    return {for (final r in rows) r.songId: _toTrack(r)};
  }

  /// Distinct genres present in the cache, sorted by track count desc.
  /// Returns `(genre, trackCount)` pairs. Empty if cache not yet synced.
  Future<List<({String genre, int count})>> genres(String serverId) async {
    final rows = await _db.customSelect(
      'SELECT genre, COUNT(*) AS c FROM cached_subsonic_songs '
      'WHERE server_id = ? AND genre IS NOT NULL AND genre != "" '
      'GROUP BY genre ORDER BY c DESC, genre ASC',
      variables: [Variable<String>(serverId)],
      readsFrom: {_db.cachedSubsonicSongs},
    ).get();
    return rows
        .map((r) => (genre: r.read<String>('genre'), count: r.read<int>('c')))
        .toList();
  }

  /// Distinct decades present in the cache (1970, 1980, …). Returns
  /// `(decade, trackCount)` pairs sorted newest-decade-first.
  Future<List<({int decade, int count})>> decades(String serverId) async {
    final rows = await _db.customSelect(
      'SELECT (year / 10) * 10 AS d, COUNT(*) AS c FROM cached_subsonic_songs '
      'WHERE server_id = ? AND year IS NOT NULL AND year > 0 '
      'GROUP BY d ORDER BY d DESC',
      variables: [Variable<String>(serverId)],
      readsFrom: {_db.cachedSubsonicSongs},
    ).get();
    return rows
        .map((r) => (decade: r.read<int>('d'), count: r.read<int>('c')))
        .toList();
  }

  Future<List<Track>> tracksOfGenre(String serverId, String genre) async {
    final rows = await (_db.select(_db.cachedSubsonicSongs)
          ..where((s) => s.serverId.equals(serverId) & s.genre.equals(genre))
          ..orderBy([(s) => OrderingTerm.asc(s.artist), (s) => OrderingTerm.asc(s.title)]))
        .get();
    return rows.map(_toTrack).toList(growable: false);
  }

  Future<List<Track>> tracksOfDecade(String serverId, int decade) async {
    final rows = await (_db.select(_db.cachedSubsonicSongs)
          ..where((s) =>
              s.serverId.equals(serverId) &
              s.year.isBetweenValues(decade, decade + 9))
          ..orderBy([(s) => OrderingTerm.asc(s.year), (s) => OrderingTerm.asc(s.artist)]))
        .get();
    return rows.map(_toTrack).toList(growable: false);
  }

  /// Instant FTS5 search over the cached library — title / artist /
  /// album / genre. Empty list for blank queries OR when the cache for
  /// [serverId] hasn't been synced yet. Returns up to [limit] tracks.
  ///
  /// User input is sanitised to a safe FTS5 query by stripping non-
  /// alphanumeric chars (FTS5 syntax has special meaning for quotes,
  /// parens, etc.) and joining whitespace-separated terms with `AND`
  /// + appending `*` so each term matches as a prefix
  /// (`daf` → "Daft Punk"). 1-char terms are dropped — they'd flood
  /// the result with noise.
  Future<List<Track>> searchFts(String serverId, String query,
      {int limit = 50}) async {
    final ftsQuery = _sanitiseFts(query);
    if (ftsQuery.isEmpty) return const [];
    final rows = await _db.customSelect(
      'SELECT s.* FROM cached_subsonic_songs s '
      'JOIN cached_subsonic_songs_fts f '
      'ON f.server_id = s.server_id AND f.song_id = s.song_id '
      'WHERE f.cached_subsonic_songs_fts MATCH ? '
      'AND s.server_id = ? '
      'ORDER BY rank LIMIT ?',
      variables: [
        Variable<String>(ftsQuery),
        Variable<String>(serverId),
        Variable<int>(limit),
      ],
      readsFrom: {_db.cachedSubsonicSongs},
    ).get();
    return rows.map((r) => Track(
          id: r.read<String>('song_id'),
          title: r.read<String>('title'),
          artist: r.readNullable<String>('artist'),
          album: r.readNullable<String>('album'),
          albumId: r.readNullable<String>('album_id'),
          artistId: r.readNullable<String>('artist_id'),
          coverArt: r.readNullable<String>('cover_art'),
          year: r.readNullable<int>('year'),
          duration: r.readNullable<int>('duration_sec') == null
              ? null
              : Duration(seconds: r.read<int>('duration_sec')),
          genre: r.readNullable<String>('genre'),
          origin: MediaOrigin.subsonic,
        )).toList();
  }

  /// Strip everything but `[\p{L}\p{N}\s]`, drop 1-char terms, and
  /// produce `term1* AND term2*` for prefix-AND matching. Returns
  /// empty when the sanitised query is empty (caller should skip).
  String _sanitiseFts(String raw) {
    final cleaned = raw.replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), ' ');
    final terms = cleaned
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 2)
        .toList();
    if (terms.isEmpty) return '';
    return terms.map((t) => '$t*').join(' AND ');
  }

  /// Rebuilds the cache for [serverId] by enumerating every album on the
  /// server and storing each song's slim metadata. Reports progress via
  /// [onAlbum] (current 1-based, total). Returns the final song count.
  Future<int> rebuild(
    SubsonicClient client,
    String serverId, {
    void Function(int doneAlbums, int totalAlbums)? onAlbum,
    bool Function()? shouldCancel,
  }) async {
    // 1) Paginate getAlbumList2 to gather every album id.
    final albumIds = <String>[];
    for (var offset = 0;; offset += _pageSize) {
      final page = await client.getAlbumList(
        type: 'alphabeticalByArtist', size: _pageSize, offset: offset,
      );
      if (page.isEmpty) break;
      albumIds.addAll(page.map((a) => a.id));
      if (shouldCancel?.call() ?? false) return await count(serverId);
      if (page.length < _pageSize) break;
    }

    // 2) Wipe this server's slice and refill from getAlbum per album.
    await _db.transaction(() async {
      await (_db.delete(_db.cachedSubsonicSongs)
            ..where((s) => s.serverId.equals(serverId)))
          .go();
    });

    var done = 0;
    for (final id in albumIds) {
      if (shouldCancel?.call() ?? false) break;
      try {
        final res = await client.getAlbum(id);
        // Bulk insert this album's songs in one transaction (cheap with
        // SQLite + drift's prepared statements).
        await _db.batch((b) {
          for (final t in res.tracks) {
            b.insert(
              _db.cachedSubsonicSongs,
              CachedSubsonicSongsCompanion(
                serverId: Value(serverId),
                songId: Value(t.id),
                title: Value(t.title),
                artist: Value(t.artist),
                album: Value(t.album),
                albumId: Value(t.albumId),
                artistId: Value(t.artistId),
                coverArt: Value(t.coverArt),
                year: Value(t.year),
                durationSec: Value(t.duration?.inSeconds),
                genre: Value(t.genre),
              ),
              mode: InsertMode.insertOrReplace,
            );
          }
        });
      } catch (_) {
        // Skip broken albums (deleted server-side mid-sync, etc.).
      }
      done++;
      onAlbum?.call(done, albumIds.length);
    }

    // Genre back-fill — Navidrome ships `genres: []` per Child in
    // getAlbum responses even when the tags exist, so the column above
    // is mostly NULL post-album-loop. Subsonic's native getSongsByGenre
    // reads the server's own genre index correctly; one pass per genre
    // hydrates the column. `genre.isNull()` in the WHERE clause gives
    // first-genre-wins for multi-genre tracks (matches our single
    // genre column shape, deterministic across re-syncs).
    if (!(shouldCancel?.call() ?? false)) {
      try {
        final genres = await client.getGenres();
        const pageSize = 500;
        for (final g in genres) {
          if (shouldCancel?.call() ?? false) break;
          try {
            for (var offset = 0;; offset += pageSize) {
              final songs = await client.getSongsByGenre(g.name,
                  count: pageSize, offset: offset);
              if (songs.isEmpty) break;
              await _db.batch((b) {
                for (final t in songs) {
                  b.update(
                    _db.cachedSubsonicSongs,
                    CachedSubsonicSongsCompanion(genre: Value(g.name)),
                    where: (s) =>
                        s.serverId.equals(serverId) &
                        s.songId.equals(t.id) &
                        s.genre.isNull(),
                  );
                }
              });
              if (songs.length < pageSize) break;
            }
          } catch (_) {
            // Skip broken genres, keep walking the rest.
          }
        }
      } catch (_) {
        // Server doesn't support getGenres — fall through. Track.genre
        // stays NULL for Subsonic; local tracks still carry their tag.
      }
    }

    final total = await count(serverId);
    final p = await SharedPreferences.getInstance();
    await p.setString('$_kLastSyncPrefix$serverId', DateTime.now().toIso8601String());
    await p.setInt('$_kCountPrefix$serverId', total);
    return total;
  }

  /// Drops the cache for a single server (used when removing a server
  /// from Settings).
  Future<void> drop(String serverId) async {
    await (_db.delete(_db.cachedSubsonicSongs)
          ..where((s) => s.serverId.equals(serverId)))
        .go();
    final p = await SharedPreferences.getInstance();
    await p.remove('$_kLastSyncPrefix$serverId');
    await p.remove('$_kCountPrefix$serverId');
  }

  Track _toTrack(CachedSubsonicSong r) => Track(
        id: r.songId,
        title: r.title,
        artist: r.artist,
        album: r.album,
        albumId: r.albumId,
        artistId: r.artistId,
        duration: r.durationSec != null ? Duration(seconds: r.durationSec!) : null,
        coverArt: r.coverArt,
        year: r.year,
        genre: r.genre,
        origin: MediaOrigin.subsonic,
      );
}
