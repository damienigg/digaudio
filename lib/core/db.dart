import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'db.g.dart';

/// Unified on-disk media pool: explicit user downloads AND play-through
/// auto-cache live in the same table. `pinned` distinguishes them — pinned
/// rows are kept forever, non-pinned rows are LRU-evicted by
/// `lastAccessedAt` once total size exceeds the user's cache budget.
class Downloads extends Table {
  TextColumn get trackKey => text()(); // origin:id
  TextColumn get filePath => text()();
  IntColumn get sizeBytes => integer().withDefault(const Constant(0))();
  DateTimeColumn get completedAt => dateTime().nullable()();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  DateTimeColumn get lastAccessedAt => dateTime().nullable()();
  @override
  Set<Column> get primaryKey => {trackKey};
}

class Favorites extends Table {
  TextColumn get trackKey => text()();
  DateTimeColumn get addedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {trackKey};
}

class LocalPlaylists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();
}

class LocalPlaylistTracks extends Table {
  IntColumn get playlistId => integer().references(LocalPlaylists, #id, onDelete: KeyAction.cascade)();
  TextColumn get trackKey => text()();
  IntColumn get position => integer()();
  @override
  Set<Column> get primaryKey => {playlistId, position};
}

/// Append-only play log — one row per playback, never overwritten. Powers
/// totals, top-tracks/artists queries, and "Tuned In"-style smart mixes.
/// Pre-v5 used `trackKey` as PK (which silently overwrote replays); v5
/// switched to an autoincrement `id` so every play is preserved.
class RecentPlays extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get trackKey => text()();
  DateTimeColumn get playedAt => dateTime()();
}

/// Imported playlist entries whose source track couldn't be matched against
/// any local file or configured Subsonic server. Stored under sentinel keys
/// (`missing:<uuid>`) referenced from [LocalPlaylistTracks.trackKey] — keeps
/// the schema for resolved tracks untouched.
class MissingTracks extends Table {
  TextColumn get trackKey => text()(); // 'missing:<uuid>'
  TextColumn get title => text()();
  TextColumn get artist => text().nullable()();
  TextColumn get album => text().nullable()();
  @override
  Set<Column> get primaryKey => {trackKey};
}

/// User's wish list — tracks/albums they want to land on a Subsonic server
/// (eventually via Lidarr; see lib/library/wishlist.dart).
class Wishlist extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get title => text()();
  TextColumn get artist => text().nullable()();
  TextColumn get album => text().nullable()();
  DateTimeColumn get requestedAt => dateTime()();
  TextColumn get notes => text().nullable()();
}

/// Last-known playback position per track. Engine debounces position
/// writes (every ~5 s) so this isn't a hot table. On track replay the
/// engine seeks here if the saved position is sufficiently mid-track
/// (avoids the "play resumes at 0:01" bug).
class TrackPositions extends Table {
  TextColumn get trackKey => text()();
  IntColumn get positionMs => integer()();
  DateTimeColumn get updatedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {trackKey};
}

/// Rules-based playlists that materialise on the fly. The user defines
/// a set of rules (genre = Rock, year between 2000–2010, …); opening
/// the playlist runs them against `CachedSubsonicSongs` and shows the
/// matching tracks. Stored as JSON because rule shapes evolve faster
/// than schemas should.
class SmartPlaylists extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get rulesJson => text()();
  DateTimeColumn get createdAt => dateTime()();
}

/// Per-server cache of every song in the Subsonic library — the slim set of
/// fields the similarity scorer needs, so AutoQueue can pick from the WHOLE
/// library instead of a 200-song random sample. Built once by syncing the
/// server (paginated getAlbumList2 + getAlbum per album); refreshed when
/// the user explicitly hits "Sync" again. Scoped by [serverId] so multiple
/// servers coexist without cross-contamination.
class CachedSubsonicSongs extends Table {
  TextColumn get serverId => text()();
  TextColumn get songId => text()();
  TextColumn get title => text()();
  TextColumn get artist => text().nullable()();
  TextColumn get album => text().nullable()();
  TextColumn get albumId => text().nullable()();
  TextColumn get artistId => text().nullable()();
  TextColumn get coverArt => text().nullable()();
  IntColumn get year => integer().nullable()();
  IntColumn get durationSec => integer().nullable()();
  TextColumn get genre => text().nullable()();
  @override
  Set<Column> get primaryKey => {serverId, songId};
}

@DriftDatabase(tables: [
  Downloads,
  Favorites,
  LocalPlaylists,
  LocalPlaylistTracks,
  RecentPlays,
  MissingTracks,
  Wishlist,
  CachedSubsonicSongs,
  SmartPlaylists,
  TrackPositions,
])
class AppDb extends _$AppDb {
  AppDb() : super(_open());

  @override
  int get schemaVersion => 7;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(missingTracks);
            await m.createTable(wishlist);
          }
          if (from < 3) {
            await m.createTable(cachedSubsonicSongs);
          }
          if (from < 4) {
            await m.addColumn(downloads, downloads.pinned);
            await m.addColumn(downloads, downloads.lastAccessedAt);
            // Pre-v4 rows were all user-initiated downloads → preserve intent.
            await customStatement('UPDATE downloads SET pinned = 1');
          }
          if (from < 5) {
            // RecentPlays was unused before v5 — safe to drop + recreate
            // with the new append-only shape (autoincrement id).
            await customStatement('DROP TABLE IF EXISTS recent_plays');
            await m.createTable(recentPlays);
          }
          if (from < 6) {
            await m.createTable(smartPlaylists);
          }
          if (from < 7) {
            await m.createTable(trackPositions);
          }
        },
      );
}

LazyDatabase _open() => LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      return NativeDatabase.createInBackground(File(p.join(dir.path, 'digaudio.sqlite')));
    });
