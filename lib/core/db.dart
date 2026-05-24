import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'db.g.dart';

class Downloads extends Table {
  TextColumn get trackKey => text()(); // origin:id
  TextColumn get filePath => text()();
  IntColumn get sizeBytes => integer().withDefault(const Constant(0))();
  DateTimeColumn get completedAt => dateTime().nullable()();
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

class RecentPlays extends Table {
  TextColumn get trackKey => text()();
  DateTimeColumn get playedAt => dateTime()();
  @override
  Set<Column> get primaryKey => {trackKey};
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
])
class AppDb extends _$AppDb {
  AppDb() : super(_open());

  @override
  int get schemaVersion => 3;

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
        },
      );
}

LazyDatabase _open() => LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      return NativeDatabase.createInBackground(File(p.join(dir.path, 'digaudio.sqlite')));
    });
