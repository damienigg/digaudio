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

@DriftDatabase(tables: [Downloads, Favorites, LocalPlaylists, LocalPlaylistTracks, RecentPlays])
class AppDb extends _$AppDb {
  AppDb() : super(_open());

  @override
  int get schemaVersion => 1;
}

LazyDatabase _open() => LazyDatabase(() async {
      final dir = await getApplicationDocumentsDirectory();
      return NativeDatabase.createInBackground(File(p.join(dir.path, 'digaudio.sqlite')));
    });
