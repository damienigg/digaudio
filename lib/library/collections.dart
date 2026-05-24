import 'dart:math';

import 'package:drift/drift.dart';

import '../core/db.dart';
import '../domain.dart';
import '../library/local.dart';
import '../subsonic/client.dart';

const String _missingPrefix = 'missing:';
bool isMissingKey(String key) => key.startsWith(_missingPrefix);

/// CRUD for favorites and local playlists, backed by drift.
///
/// Tracks are stored by their stable [Track.uniqueKey] ("origin:id"). They're
/// resolved back to full [Track] instances on read via [TrackResolver].
class FavoritesManager {
  final AppDb _db;
  FavoritesManager(this._db);

  Future<bool> isFavorite(String trackKey) async {
    final row = await (_db.select(_db.favorites)..where((f) => f.trackKey.equals(trackKey)))
        .getSingleOrNull();
    return row != null;
  }

  Future<void> add(String trackKey) async {
    await _db.into(_db.favorites).insertOnConflictUpdate(
          FavoritesCompanion(trackKey: Value(trackKey), addedAt: Value(DateTime.now())),
        );
  }

  Future<void> remove(String trackKey) =>
      (_db.delete(_db.favorites)..where((f) => f.trackKey.equals(trackKey))).go();

  Future<void> toggle(String trackKey) async {
    if (await isFavorite(trackKey)) {
      await remove(trackKey);
    } else {
      await add(trackKey);
    }
  }

  /// All favorite track keys, most recently added first.
  Future<List<String>> keys() async {
    final rows = await (_db.select(_db.favorites)
          ..orderBy([(f) => OrderingTerm.desc(f.addedAt)]))
        .get();
    return rows.map((r) => r.trackKey).toList();
  }

  Stream<List<String>> watchKeys() {
    final q = _db.select(_db.favorites)..orderBy([(f) => OrderingTerm.desc(f.addedAt)]);
    return q.watch().map((rows) => rows.map((r) => r.trackKey).toList());
  }
}

class LocalPlaylistsManager {
  final AppDb _db;
  LocalPlaylistsManager(this._db);

  Future<int> create(String name) =>
      _db.into(_db.localPlaylists).insert(LocalPlaylistsCompanion(
            name: Value(name),
            createdAt: Value(DateTime.now()),
          ));

  Future<void> rename(int id, String name) async {
    await (_db.update(_db.localPlaylists)..where((p) => p.id.equals(id)))
        .write(LocalPlaylistsCompanion(name: Value(name)));
  }

  Future<void> delete(int id) =>
      (_db.delete(_db.localPlaylists)..where((p) => p.id.equals(id))).go();

  Future<List<LocalPlaylist>> all() async {
    return (_db.select(_db.localPlaylists)
          ..orderBy([(p) => OrderingTerm.desc(p.createdAt)]))
        .get();
  }

  Stream<List<LocalPlaylist>> watchAll() =>
      (_db.select(_db.localPlaylists)..orderBy([(p) => OrderingTerm.desc(p.createdAt)]))
          .watch();

  Future<LocalPlaylist?> get(int id) =>
      (_db.select(_db.localPlaylists)..where((p) => p.id.equals(id))).getSingleOrNull();

  /// Returns the track keys in playlist order.
  Future<List<String>> trackKeys(int playlistId) async {
    final rows = await (_db.select(_db.localPlaylistTracks)
          ..where((t) => t.playlistId.equals(playlistId))
          ..orderBy([(t) => OrderingTerm.asc(t.position)]))
        .get();
    return rows.map((r) => r.trackKey).toList();
  }

  Stream<List<String>> watchTrackKeys(int playlistId) {
    final q = _db.select(_db.localPlaylistTracks)
      ..where((t) => t.playlistId.equals(playlistId))
      ..orderBy([(t) => OrderingTerm.asc(t.position)]);
    return q.watch().map((rows) => rows.map((r) => r.trackKey).toList());
  }

  Future<void> append(int playlistId, String trackKey) async {
    final existing = await trackKeys(playlistId);
    await _db.into(_db.localPlaylistTracks).insertOnConflictUpdate(
          LocalPlaylistTracksCompanion(
            playlistId: Value(playlistId),
            trackKey: Value(trackKey),
            position: Value(existing.length),
          ),
        );
  }

  Future<void> removeAt(int playlistId, int position) async {
    await _db.transaction(() async {
      await (_db.delete(_db.localPlaylistTracks)
            ..where((t) =>
                t.playlistId.equals(playlistId) & t.position.equals(position)))
          .go();
      // Compact subsequent positions to keep them dense.
      final after = await (_db.select(_db.localPlaylistTracks)
            ..where((t) =>
                t.playlistId.equals(playlistId) & t.position.isBiggerThanValue(position))
            ..orderBy([(t) => OrderingTerm.asc(t.position)]))
          .get();
      for (final row in after) {
        await (_db.update(_db.localPlaylistTracks)
              ..where((t) =>
                  t.playlistId.equals(playlistId) & t.position.equals(row.position)))
            .write(LocalPlaylistTracksCompanion(position: Value(row.position - 1)));
      }
    });
  }

  /// Reorders the entire playlist using the given key list as the new order.
  Future<void> reorder(int playlistId, List<String> orderedKeys) async {
    await _db.transaction(() async {
      await (_db.delete(_db.localPlaylistTracks)
            ..where((t) => t.playlistId.equals(playlistId)))
          .go();
      for (var i = 0; i < orderedKeys.length; i++) {
        await _db.into(_db.localPlaylistTracks).insert(
              LocalPlaylistTracksCompanion(
                playlistId: Value(playlistId),
                trackKey: Value(orderedKeys[i]),
                position: Value(i),
              ),
            );
      }
    });
  }

  // --- Missing-entry helpers ----------------------------------------------

  /// Persists a missing-track placeholder and returns its sentinel key
  /// (`missing:<uuid>`). The key is appended to a playlist like any other.
  Future<String> recordMissing({
    required String title,
    String? artist,
    String? album,
  }) async {
    final key = '$_missingPrefix${_uuid()}';
    await _db.into(_db.missingTracks).insertOnConflictUpdate(MissingTracksCompanion(
          trackKey: Value(key),
          title: Value(title),
          artist: Value(artist),
          album: Value(album),
        ));
    return key;
  }

  Future<MissingEntry?> readMissing(String key) async {
    final row = await (_db.select(_db.missingTracks)..where((m) => m.trackKey.equals(key)))
        .getSingleOrNull();
    if (row == null) return null;
    return MissingEntry(key: key, title: row.title, artist: row.artist, album: row.album);
  }

  static String _uuid() {
    final r = Random.secure();
    final now = DateTime.now().microsecondsSinceEpoch.toRadixString(36);
    final suffix = List.generate(6, (_) => r.nextInt(36).toRadixString(36)).join();
    return '$now$suffix';
  }
}

/// Resolves stored track keys back to full [Track] / [PlaylistEntry]
/// objects, choosing the right backend per origin. Subsonic resolution is
/// best-effort and may return null if the server is unreachable.
class TrackResolver {
  final LocalLibrary local;
  final SubsonicClient? Function() subsonic;
  final LocalPlaylistsManager playlists;
  TrackResolver({required this.local, required this.subsonic, required this.playlists});

  Future<Track?> resolve(String key) async {
    if (isMissingKey(key)) return null; // missing entries aren't playable
    final i = key.indexOf(':');
    if (i < 0) return null;
    final origin = key.substring(0, i);
    final id = key.substring(i + 1);
    if (origin == MediaOrigin.local.name) return local.getSongById(id);
    if (origin == MediaOrigin.subsonic.name) return subsonic()?.getSong(id);
    return null;
  }

  /// Resolves a list of keys to plain [Track]s, dropping anything that
  /// can't be played (missing entries, unreachable Subsonic). Use for
  /// "Play all" flows where missing rows would only confuse the engine.
  Future<List<Track>> resolveAll(List<String> keys) async {
    final out = <Track>[];
    for (final k in keys) {
      final t = await resolve(k);
      if (t != null) out.add(t);
    }
    return out;
  }

  /// Resolves keys to mixed [PlaylistEntry] (track OR missing) preserving
  /// input order. Used by the playlist detail view so missing imports
  /// render as greyed-out placeholders.
  Future<List<PlaylistEntry>> resolveEntries(List<String> keys) async {
    final out = <PlaylistEntry>[];
    for (final k in keys) {
      if (isMissingKey(k)) {
        final m = await playlists.readMissing(k);
        if (m != null) out.add(m);
      } else {
        final t = await resolve(k);
        if (t != null) out.add(TrackEntry(t));
      }
    }
    return out;
  }
}
