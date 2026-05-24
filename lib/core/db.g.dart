// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'db.dart';

// ignore_for_file: type=lint
class $DownloadsTable extends Downloads
    with TableInfo<$DownloadsTable, Download> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DownloadsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _trackKeyMeta =
      const VerificationMeta('trackKey');
  @override
  late final GeneratedColumn<String> trackKey = GeneratedColumn<String>(
      'track_key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _filePathMeta =
      const VerificationMeta('filePath');
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
      'file_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sizeBytesMeta =
      const VerificationMeta('sizeBytes');
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
      'size_bytes', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _completedAtMeta =
      const VerificationMeta('completedAt');
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
      'completed_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [trackKey, filePath, sizeBytes, completedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'downloads';
  @override
  VerificationContext validateIntegrity(Insertable<Download> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('track_key')) {
      context.handle(_trackKeyMeta,
          trackKey.isAcceptableOrUnknown(data['track_key']!, _trackKeyMeta));
    } else if (isInserting) {
      context.missing(_trackKeyMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(_filePathMeta,
          filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta));
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('size_bytes')) {
      context.handle(_sizeBytesMeta,
          sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta));
    }
    if (data.containsKey('completed_at')) {
      context.handle(
          _completedAtMeta,
          completedAt.isAcceptableOrUnknown(
              data['completed_at']!, _completedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {trackKey};
  @override
  Download map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Download(
      trackKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}track_key'])!,
      filePath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}file_path'])!,
      sizeBytes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}size_bytes'])!,
      completedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}completed_at']),
    );
  }

  @override
  $DownloadsTable createAlias(String alias) {
    return $DownloadsTable(attachedDatabase, alias);
  }
}

class Download extends DataClass implements Insertable<Download> {
  final String trackKey;
  final String filePath;
  final int sizeBytes;
  final DateTime? completedAt;
  const Download(
      {required this.trackKey,
      required this.filePath,
      required this.sizeBytes,
      this.completedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['track_key'] = Variable<String>(trackKey);
    map['file_path'] = Variable<String>(filePath);
    map['size_bytes'] = Variable<int>(sizeBytes);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    return map;
  }

  DownloadsCompanion toCompanion(bool nullToAbsent) {
    return DownloadsCompanion(
      trackKey: Value(trackKey),
      filePath: Value(filePath),
      sizeBytes: Value(sizeBytes),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory Download.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Download(
      trackKey: serializer.fromJson<String>(json['trackKey']),
      filePath: serializer.fromJson<String>(json['filePath']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'trackKey': serializer.toJson<String>(trackKey),
      'filePath': serializer.toJson<String>(filePath),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
    };
  }

  Download copyWith(
          {String? trackKey,
          String? filePath,
          int? sizeBytes,
          Value<DateTime?> completedAt = const Value.absent()}) =>
      Download(
        trackKey: trackKey ?? this.trackKey,
        filePath: filePath ?? this.filePath,
        sizeBytes: sizeBytes ?? this.sizeBytes,
        completedAt: completedAt.present ? completedAt.value : this.completedAt,
      );
  Download copyWithCompanion(DownloadsCompanion data) {
    return Download(
      trackKey: data.trackKey.present ? data.trackKey.value : this.trackKey,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      completedAt:
          data.completedAt.present ? data.completedAt.value : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Download(')
          ..write('trackKey: $trackKey, ')
          ..write('filePath: $filePath, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(trackKey, filePath, sizeBytes, completedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Download &&
          other.trackKey == this.trackKey &&
          other.filePath == this.filePath &&
          other.sizeBytes == this.sizeBytes &&
          other.completedAt == this.completedAt);
}

class DownloadsCompanion extends UpdateCompanion<Download> {
  final Value<String> trackKey;
  final Value<String> filePath;
  final Value<int> sizeBytes;
  final Value<DateTime?> completedAt;
  final Value<int> rowid;
  const DownloadsCompanion({
    this.trackKey = const Value.absent(),
    this.filePath = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DownloadsCompanion.insert({
    required String trackKey,
    required String filePath,
    this.sizeBytes = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : trackKey = Value(trackKey),
        filePath = Value(filePath);
  static Insertable<Download> custom({
    Expression<String>? trackKey,
    Expression<String>? filePath,
    Expression<int>? sizeBytes,
    Expression<DateTime>? completedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (trackKey != null) 'track_key': trackKey,
      if (filePath != null) 'file_path': filePath,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (completedAt != null) 'completed_at': completedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DownloadsCompanion copyWith(
      {Value<String>? trackKey,
      Value<String>? filePath,
      Value<int>? sizeBytes,
      Value<DateTime?>? completedAt,
      Value<int>? rowid}) {
    return DownloadsCompanion(
      trackKey: trackKey ?? this.trackKey,
      filePath: filePath ?? this.filePath,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      completedAt: completedAt ?? this.completedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (trackKey.present) {
      map['track_key'] = Variable<String>(trackKey.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DownloadsCompanion(')
          ..write('trackKey: $trackKey, ')
          ..write('filePath: $filePath, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('completedAt: $completedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $FavoritesTable extends Favorites
    with TableInfo<$FavoritesTable, Favorite> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FavoritesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _trackKeyMeta =
      const VerificationMeta('trackKey');
  @override
  late final GeneratedColumn<String> trackKey = GeneratedColumn<String>(
      'track_key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _addedAtMeta =
      const VerificationMeta('addedAt');
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
      'added_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [trackKey, addedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'favorites';
  @override
  VerificationContext validateIntegrity(Insertable<Favorite> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('track_key')) {
      context.handle(_trackKeyMeta,
          trackKey.isAcceptableOrUnknown(data['track_key']!, _trackKeyMeta));
    } else if (isInserting) {
      context.missing(_trackKeyMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(_addedAtMeta,
          addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta));
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {trackKey};
  @override
  Favorite map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Favorite(
      trackKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}track_key'])!,
      addedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}added_at'])!,
    );
  }

  @override
  $FavoritesTable createAlias(String alias) {
    return $FavoritesTable(attachedDatabase, alias);
  }
}

class Favorite extends DataClass implements Insertable<Favorite> {
  final String trackKey;
  final DateTime addedAt;
  const Favorite({required this.trackKey, required this.addedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['track_key'] = Variable<String>(trackKey);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  FavoritesCompanion toCompanion(bool nullToAbsent) {
    return FavoritesCompanion(
      trackKey: Value(trackKey),
      addedAt: Value(addedAt),
    );
  }

  factory Favorite.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Favorite(
      trackKey: serializer.fromJson<String>(json['trackKey']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'trackKey': serializer.toJson<String>(trackKey),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  Favorite copyWith({String? trackKey, DateTime? addedAt}) => Favorite(
        trackKey: trackKey ?? this.trackKey,
        addedAt: addedAt ?? this.addedAt,
      );
  Favorite copyWithCompanion(FavoritesCompanion data) {
    return Favorite(
      trackKey: data.trackKey.present ? data.trackKey.value : this.trackKey,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Favorite(')
          ..write('trackKey: $trackKey, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(trackKey, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Favorite &&
          other.trackKey == this.trackKey &&
          other.addedAt == this.addedAt);
}

class FavoritesCompanion extends UpdateCompanion<Favorite> {
  final Value<String> trackKey;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const FavoritesCompanion({
    this.trackKey = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  FavoritesCompanion.insert({
    required String trackKey,
    required DateTime addedAt,
    this.rowid = const Value.absent(),
  })  : trackKey = Value(trackKey),
        addedAt = Value(addedAt);
  static Insertable<Favorite> custom({
    Expression<String>? trackKey,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (trackKey != null) 'track_key': trackKey,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  FavoritesCompanion copyWith(
      {Value<String>? trackKey, Value<DateTime>? addedAt, Value<int>? rowid}) {
    return FavoritesCompanion(
      trackKey: trackKey ?? this.trackKey,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (trackKey.present) {
      map['track_key'] = Variable<String>(trackKey.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FavoritesCompanion(')
          ..write('trackKey: $trackKey, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalPlaylistsTable extends LocalPlaylists
    with TableInfo<$LocalPlaylistsTable, LocalPlaylist> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalPlaylistsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, name, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_playlists';
  @override
  VerificationContext validateIntegrity(Insertable<LocalPlaylist> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalPlaylist map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalPlaylist(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $LocalPlaylistsTable createAlias(String alias) {
    return $LocalPlaylistsTable(attachedDatabase, alias);
  }
}

class LocalPlaylist extends DataClass implements Insertable<LocalPlaylist> {
  final int id;
  final String name;
  final DateTime createdAt;
  const LocalPlaylist(
      {required this.id, required this.name, required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  LocalPlaylistsCompanion toCompanion(bool nullToAbsent) {
    return LocalPlaylistsCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(createdAt),
    );
  }

  factory LocalPlaylist.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalPlaylist(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  LocalPlaylist copyWith({int? id, String? name, DateTime? createdAt}) =>
      LocalPlaylist(
        id: id ?? this.id,
        name: name ?? this.name,
        createdAt: createdAt ?? this.createdAt,
      );
  LocalPlaylist copyWithCompanion(LocalPlaylistsCompanion data) {
    return LocalPlaylist(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalPlaylist(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalPlaylist &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdAt == this.createdAt);
}

class LocalPlaylistsCompanion extends UpdateCompanion<LocalPlaylist> {
  final Value<int> id;
  final Value<String> name;
  final Value<DateTime> createdAt;
  const LocalPlaylistsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  LocalPlaylistsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required DateTime createdAt,
  })  : name = Value(name),
        createdAt = Value(createdAt);
  static Insertable<LocalPlaylist> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  LocalPlaylistsCompanion copyWith(
      {Value<int>? id, Value<String>? name, Value<DateTime>? createdAt}) {
    return LocalPlaylistsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalPlaylistsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $LocalPlaylistTracksTable extends LocalPlaylistTracks
    with TableInfo<$LocalPlaylistTracksTable, LocalPlaylistTrack> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalPlaylistTracksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _playlistIdMeta =
      const VerificationMeta('playlistId');
  @override
  late final GeneratedColumn<int> playlistId = GeneratedColumn<int>(
      'playlist_id', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'REFERENCES local_playlists (id) ON DELETE CASCADE'));
  static const VerificationMeta _trackKeyMeta =
      const VerificationMeta('trackKey');
  @override
  late final GeneratedColumn<String> trackKey = GeneratedColumn<String>(
      'track_key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _positionMeta =
      const VerificationMeta('position');
  @override
  late final GeneratedColumn<int> position = GeneratedColumn<int>(
      'position', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [playlistId, trackKey, position];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_playlist_tracks';
  @override
  VerificationContext validateIntegrity(Insertable<LocalPlaylistTrack> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('playlist_id')) {
      context.handle(
          _playlistIdMeta,
          playlistId.isAcceptableOrUnknown(
              data['playlist_id']!, _playlistIdMeta));
    } else if (isInserting) {
      context.missing(_playlistIdMeta);
    }
    if (data.containsKey('track_key')) {
      context.handle(_trackKeyMeta,
          trackKey.isAcceptableOrUnknown(data['track_key']!, _trackKeyMeta));
    } else if (isInserting) {
      context.missing(_trackKeyMeta);
    }
    if (data.containsKey('position')) {
      context.handle(_positionMeta,
          position.isAcceptableOrUnknown(data['position']!, _positionMeta));
    } else if (isInserting) {
      context.missing(_positionMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {playlistId, position};
  @override
  LocalPlaylistTrack map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalPlaylistTrack(
      playlistId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}playlist_id'])!,
      trackKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}track_key'])!,
      position: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}position'])!,
    );
  }

  @override
  $LocalPlaylistTracksTable createAlias(String alias) {
    return $LocalPlaylistTracksTable(attachedDatabase, alias);
  }
}

class LocalPlaylistTrack extends DataClass
    implements Insertable<LocalPlaylistTrack> {
  final int playlistId;
  final String trackKey;
  final int position;
  const LocalPlaylistTrack(
      {required this.playlistId,
      required this.trackKey,
      required this.position});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['playlist_id'] = Variable<int>(playlistId);
    map['track_key'] = Variable<String>(trackKey);
    map['position'] = Variable<int>(position);
    return map;
  }

  LocalPlaylistTracksCompanion toCompanion(bool nullToAbsent) {
    return LocalPlaylistTracksCompanion(
      playlistId: Value(playlistId),
      trackKey: Value(trackKey),
      position: Value(position),
    );
  }

  factory LocalPlaylistTrack.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalPlaylistTrack(
      playlistId: serializer.fromJson<int>(json['playlistId']),
      trackKey: serializer.fromJson<String>(json['trackKey']),
      position: serializer.fromJson<int>(json['position']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'playlistId': serializer.toJson<int>(playlistId),
      'trackKey': serializer.toJson<String>(trackKey),
      'position': serializer.toJson<int>(position),
    };
  }

  LocalPlaylistTrack copyWith(
          {int? playlistId, String? trackKey, int? position}) =>
      LocalPlaylistTrack(
        playlistId: playlistId ?? this.playlistId,
        trackKey: trackKey ?? this.trackKey,
        position: position ?? this.position,
      );
  LocalPlaylistTrack copyWithCompanion(LocalPlaylistTracksCompanion data) {
    return LocalPlaylistTrack(
      playlistId:
          data.playlistId.present ? data.playlistId.value : this.playlistId,
      trackKey: data.trackKey.present ? data.trackKey.value : this.trackKey,
      position: data.position.present ? data.position.value : this.position,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalPlaylistTrack(')
          ..write('playlistId: $playlistId, ')
          ..write('trackKey: $trackKey, ')
          ..write('position: $position')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(playlistId, trackKey, position);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalPlaylistTrack &&
          other.playlistId == this.playlistId &&
          other.trackKey == this.trackKey &&
          other.position == this.position);
}

class LocalPlaylistTracksCompanion extends UpdateCompanion<LocalPlaylistTrack> {
  final Value<int> playlistId;
  final Value<String> trackKey;
  final Value<int> position;
  final Value<int> rowid;
  const LocalPlaylistTracksCompanion({
    this.playlistId = const Value.absent(),
    this.trackKey = const Value.absent(),
    this.position = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalPlaylistTracksCompanion.insert({
    required int playlistId,
    required String trackKey,
    required int position,
    this.rowid = const Value.absent(),
  })  : playlistId = Value(playlistId),
        trackKey = Value(trackKey),
        position = Value(position);
  static Insertable<LocalPlaylistTrack> custom({
    Expression<int>? playlistId,
    Expression<String>? trackKey,
    Expression<int>? position,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (playlistId != null) 'playlist_id': playlistId,
      if (trackKey != null) 'track_key': trackKey,
      if (position != null) 'position': position,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalPlaylistTracksCompanion copyWith(
      {Value<int>? playlistId,
      Value<String>? trackKey,
      Value<int>? position,
      Value<int>? rowid}) {
    return LocalPlaylistTracksCompanion(
      playlistId: playlistId ?? this.playlistId,
      trackKey: trackKey ?? this.trackKey,
      position: position ?? this.position,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (playlistId.present) {
      map['playlist_id'] = Variable<int>(playlistId.value);
    }
    if (trackKey.present) {
      map['track_key'] = Variable<String>(trackKey.value);
    }
    if (position.present) {
      map['position'] = Variable<int>(position.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalPlaylistTracksCompanion(')
          ..write('playlistId: $playlistId, ')
          ..write('trackKey: $trackKey, ')
          ..write('position: $position, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RecentPlaysTable extends RecentPlays
    with TableInfo<$RecentPlaysTable, RecentPlay> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecentPlaysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _trackKeyMeta =
      const VerificationMeta('trackKey');
  @override
  late final GeneratedColumn<String> trackKey = GeneratedColumn<String>(
      'track_key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _playedAtMeta =
      const VerificationMeta('playedAt');
  @override
  late final GeneratedColumn<DateTime> playedAt = GeneratedColumn<DateTime>(
      'played_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [trackKey, playedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recent_plays';
  @override
  VerificationContext validateIntegrity(Insertable<RecentPlay> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('track_key')) {
      context.handle(_trackKeyMeta,
          trackKey.isAcceptableOrUnknown(data['track_key']!, _trackKeyMeta));
    } else if (isInserting) {
      context.missing(_trackKeyMeta);
    }
    if (data.containsKey('played_at')) {
      context.handle(_playedAtMeta,
          playedAt.isAcceptableOrUnknown(data['played_at']!, _playedAtMeta));
    } else if (isInserting) {
      context.missing(_playedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {trackKey};
  @override
  RecentPlay map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecentPlay(
      trackKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}track_key'])!,
      playedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}played_at'])!,
    );
  }

  @override
  $RecentPlaysTable createAlias(String alias) {
    return $RecentPlaysTable(attachedDatabase, alias);
  }
}

class RecentPlay extends DataClass implements Insertable<RecentPlay> {
  final String trackKey;
  final DateTime playedAt;
  const RecentPlay({required this.trackKey, required this.playedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['track_key'] = Variable<String>(trackKey);
    map['played_at'] = Variable<DateTime>(playedAt);
    return map;
  }

  RecentPlaysCompanion toCompanion(bool nullToAbsent) {
    return RecentPlaysCompanion(
      trackKey: Value(trackKey),
      playedAt: Value(playedAt),
    );
  }

  factory RecentPlay.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecentPlay(
      trackKey: serializer.fromJson<String>(json['trackKey']),
      playedAt: serializer.fromJson<DateTime>(json['playedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'trackKey': serializer.toJson<String>(trackKey),
      'playedAt': serializer.toJson<DateTime>(playedAt),
    };
  }

  RecentPlay copyWith({String? trackKey, DateTime? playedAt}) => RecentPlay(
        trackKey: trackKey ?? this.trackKey,
        playedAt: playedAt ?? this.playedAt,
      );
  RecentPlay copyWithCompanion(RecentPlaysCompanion data) {
    return RecentPlay(
      trackKey: data.trackKey.present ? data.trackKey.value : this.trackKey,
      playedAt: data.playedAt.present ? data.playedAt.value : this.playedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecentPlay(')
          ..write('trackKey: $trackKey, ')
          ..write('playedAt: $playedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(trackKey, playedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecentPlay &&
          other.trackKey == this.trackKey &&
          other.playedAt == this.playedAt);
}

class RecentPlaysCompanion extends UpdateCompanion<RecentPlay> {
  final Value<String> trackKey;
  final Value<DateTime> playedAt;
  final Value<int> rowid;
  const RecentPlaysCompanion({
    this.trackKey = const Value.absent(),
    this.playedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RecentPlaysCompanion.insert({
    required String trackKey,
    required DateTime playedAt,
    this.rowid = const Value.absent(),
  })  : trackKey = Value(trackKey),
        playedAt = Value(playedAt);
  static Insertable<RecentPlay> custom({
    Expression<String>? trackKey,
    Expression<DateTime>? playedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (trackKey != null) 'track_key': trackKey,
      if (playedAt != null) 'played_at': playedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RecentPlaysCompanion copyWith(
      {Value<String>? trackKey, Value<DateTime>? playedAt, Value<int>? rowid}) {
    return RecentPlaysCompanion(
      trackKey: trackKey ?? this.trackKey,
      playedAt: playedAt ?? this.playedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (trackKey.present) {
      map['track_key'] = Variable<String>(trackKey.value);
    }
    if (playedAt.present) {
      map['played_at'] = Variable<DateTime>(playedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecentPlaysCompanion(')
          ..write('trackKey: $trackKey, ')
          ..write('playedAt: $playedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDb extends GeneratedDatabase {
  _$AppDb(QueryExecutor e) : super(e);
  $AppDbManager get managers => $AppDbManager(this);
  late final $DownloadsTable downloads = $DownloadsTable(this);
  late final $FavoritesTable favorites = $FavoritesTable(this);
  late final $LocalPlaylistsTable localPlaylists = $LocalPlaylistsTable(this);
  late final $LocalPlaylistTracksTable localPlaylistTracks =
      $LocalPlaylistTracksTable(this);
  late final $RecentPlaysTable recentPlays = $RecentPlaysTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [downloads, favorites, localPlaylists, localPlaylistTracks, recentPlays];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules(
        [
          WritePropagation(
            on: TableUpdateQuery.onTableName('local_playlists',
                limitUpdateKind: UpdateKind.delete),
            result: [
              TableUpdate('local_playlist_tracks', kind: UpdateKind.delete),
            ],
          ),
        ],
      );
}

typedef $$DownloadsTableCreateCompanionBuilder = DownloadsCompanion Function({
  required String trackKey,
  required String filePath,
  Value<int> sizeBytes,
  Value<DateTime?> completedAt,
  Value<int> rowid,
});
typedef $$DownloadsTableUpdateCompanionBuilder = DownloadsCompanion Function({
  Value<String> trackKey,
  Value<String> filePath,
  Value<int> sizeBytes,
  Value<DateTime?> completedAt,
  Value<int> rowid,
});

class $$DownloadsTableFilterComposer
    extends Composer<_$AppDb, $DownloadsTable> {
  $$DownloadsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get trackKey => $composableBuilder(
      column: $table.trackKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get sizeBytes => $composableBuilder(
      column: $table.sizeBytes, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnFilters(column));
}

class $$DownloadsTableOrderingComposer
    extends Composer<_$AppDb, $DownloadsTable> {
  $$DownloadsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get trackKey => $composableBuilder(
      column: $table.trackKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get filePath => $composableBuilder(
      column: $table.filePath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
      column: $table.sizeBytes, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnOrderings(column));
}

class $$DownloadsTableAnnotationComposer
    extends Composer<_$AppDb, $DownloadsTable> {
  $$DownloadsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get trackKey =>
      $composableBuilder(column: $table.trackKey, builder: (column) => column);

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => column);
}

class $$DownloadsTableTableManager extends RootTableManager<
    _$AppDb,
    $DownloadsTable,
    Download,
    $$DownloadsTableFilterComposer,
    $$DownloadsTableOrderingComposer,
    $$DownloadsTableAnnotationComposer,
    $$DownloadsTableCreateCompanionBuilder,
    $$DownloadsTableUpdateCompanionBuilder,
    (Download, BaseReferences<_$AppDb, $DownloadsTable, Download>),
    Download,
    PrefetchHooks Function()> {
  $$DownloadsTableTableManager(_$AppDb db, $DownloadsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DownloadsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DownloadsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DownloadsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> trackKey = const Value.absent(),
            Value<String> filePath = const Value.absent(),
            Value<int> sizeBytes = const Value.absent(),
            Value<DateTime?> completedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DownloadsCompanion(
            trackKey: trackKey,
            filePath: filePath,
            sizeBytes: sizeBytes,
            completedAt: completedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String trackKey,
            required String filePath,
            Value<int> sizeBytes = const Value.absent(),
            Value<DateTime?> completedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DownloadsCompanion.insert(
            trackKey: trackKey,
            filePath: filePath,
            sizeBytes: sizeBytes,
            completedAt: completedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$DownloadsTableProcessedTableManager = ProcessedTableManager<
    _$AppDb,
    $DownloadsTable,
    Download,
    $$DownloadsTableFilterComposer,
    $$DownloadsTableOrderingComposer,
    $$DownloadsTableAnnotationComposer,
    $$DownloadsTableCreateCompanionBuilder,
    $$DownloadsTableUpdateCompanionBuilder,
    (Download, BaseReferences<_$AppDb, $DownloadsTable, Download>),
    Download,
    PrefetchHooks Function()>;
typedef $$FavoritesTableCreateCompanionBuilder = FavoritesCompanion Function({
  required String trackKey,
  required DateTime addedAt,
  Value<int> rowid,
});
typedef $$FavoritesTableUpdateCompanionBuilder = FavoritesCompanion Function({
  Value<String> trackKey,
  Value<DateTime> addedAt,
  Value<int> rowid,
});

class $$FavoritesTableFilterComposer
    extends Composer<_$AppDb, $FavoritesTable> {
  $$FavoritesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get trackKey => $composableBuilder(
      column: $table.trackKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
      column: $table.addedAt, builder: (column) => ColumnFilters(column));
}

class $$FavoritesTableOrderingComposer
    extends Composer<_$AppDb, $FavoritesTable> {
  $$FavoritesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get trackKey => $composableBuilder(
      column: $table.trackKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
      column: $table.addedAt, builder: (column) => ColumnOrderings(column));
}

class $$FavoritesTableAnnotationComposer
    extends Composer<_$AppDb, $FavoritesTable> {
  $$FavoritesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get trackKey =>
      $composableBuilder(column: $table.trackKey, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);
}

class $$FavoritesTableTableManager extends RootTableManager<
    _$AppDb,
    $FavoritesTable,
    Favorite,
    $$FavoritesTableFilterComposer,
    $$FavoritesTableOrderingComposer,
    $$FavoritesTableAnnotationComposer,
    $$FavoritesTableCreateCompanionBuilder,
    $$FavoritesTableUpdateCompanionBuilder,
    (Favorite, BaseReferences<_$AppDb, $FavoritesTable, Favorite>),
    Favorite,
    PrefetchHooks Function()> {
  $$FavoritesTableTableManager(_$AppDb db, $FavoritesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FavoritesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FavoritesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FavoritesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> trackKey = const Value.absent(),
            Value<DateTime> addedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              FavoritesCompanion(
            trackKey: trackKey,
            addedAt: addedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String trackKey,
            required DateTime addedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              FavoritesCompanion.insert(
            trackKey: trackKey,
            addedAt: addedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$FavoritesTableProcessedTableManager = ProcessedTableManager<
    _$AppDb,
    $FavoritesTable,
    Favorite,
    $$FavoritesTableFilterComposer,
    $$FavoritesTableOrderingComposer,
    $$FavoritesTableAnnotationComposer,
    $$FavoritesTableCreateCompanionBuilder,
    $$FavoritesTableUpdateCompanionBuilder,
    (Favorite, BaseReferences<_$AppDb, $FavoritesTable, Favorite>),
    Favorite,
    PrefetchHooks Function()>;
typedef $$LocalPlaylistsTableCreateCompanionBuilder = LocalPlaylistsCompanion
    Function({
  Value<int> id,
  required String name,
  required DateTime createdAt,
});
typedef $$LocalPlaylistsTableUpdateCompanionBuilder = LocalPlaylistsCompanion
    Function({
  Value<int> id,
  Value<String> name,
  Value<DateTime> createdAt,
});

final class $$LocalPlaylistsTableReferences
    extends BaseReferences<_$AppDb, $LocalPlaylistsTable, LocalPlaylist> {
  $$LocalPlaylistsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$LocalPlaylistTracksTable,
      List<LocalPlaylistTrack>> _localPlaylistTracksRefsTable(
          _$AppDb db) =>
      MultiTypedResultKey.fromTable(db.localPlaylistTracks,
          aliasName: $_aliasNameGenerator(
              db.localPlaylists.id, db.localPlaylistTracks.playlistId));

  $$LocalPlaylistTracksTableProcessedTableManager get localPlaylistTracksRefs {
    final manager =
        $$LocalPlaylistTracksTableTableManager($_db, $_db.localPlaylistTracks)
            .filter((f) => f.playlistId.id($_item.id));

    final cache =
        $_typedResult.readTableOrNull(_localPlaylistTracksRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$LocalPlaylistsTableFilterComposer
    extends Composer<_$AppDb, $LocalPlaylistsTable> {
  $$LocalPlaylistsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  Expression<bool> localPlaylistTracksRefs(
      Expression<bool> Function($$LocalPlaylistTracksTableFilterComposer f) f) {
    final $$LocalPlaylistTracksTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.localPlaylistTracks,
        getReferencedColumn: (t) => t.playlistId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$LocalPlaylistTracksTableFilterComposer(
              $db: $db,
              $table: $db.localPlaylistTracks,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$LocalPlaylistsTableOrderingComposer
    extends Composer<_$AppDb, $LocalPlaylistsTable> {
  $$LocalPlaylistsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$LocalPlaylistsTableAnnotationComposer
    extends Composer<_$AppDb, $LocalPlaylistsTable> {
  $$LocalPlaylistsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> localPlaylistTracksRefs<T extends Object>(
      Expression<T> Function($$LocalPlaylistTracksTableAnnotationComposer a)
          f) {
    final $$LocalPlaylistTracksTableAnnotationComposer composer =
        $composerBuilder(
            composer: this,
            getCurrentColumn: (t) => t.id,
            referencedTable: $db.localPlaylistTracks,
            getReferencedColumn: (t) => t.playlistId,
            builder: (joinBuilder,
                    {$addJoinBuilderToRootComposer,
                    $removeJoinBuilderFromRootComposer}) =>
                $$LocalPlaylistTracksTableAnnotationComposer(
                  $db: $db,
                  $table: $db.localPlaylistTracks,
                  $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                  joinBuilder: joinBuilder,
                  $removeJoinBuilderFromRootComposer:
                      $removeJoinBuilderFromRootComposer,
                ));
    return f(composer);
  }
}

class $$LocalPlaylistsTableTableManager extends RootTableManager<
    _$AppDb,
    $LocalPlaylistsTable,
    LocalPlaylist,
    $$LocalPlaylistsTableFilterComposer,
    $$LocalPlaylistsTableOrderingComposer,
    $$LocalPlaylistsTableAnnotationComposer,
    $$LocalPlaylistsTableCreateCompanionBuilder,
    $$LocalPlaylistsTableUpdateCompanionBuilder,
    (LocalPlaylist, $$LocalPlaylistsTableReferences),
    LocalPlaylist,
    PrefetchHooks Function({bool localPlaylistTracksRefs})> {
  $$LocalPlaylistsTableTableManager(_$AppDb db, $LocalPlaylistsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalPlaylistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalPlaylistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalPlaylistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              LocalPlaylistsCompanion(
            id: id,
            name: name,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            required DateTime createdAt,
          }) =>
              LocalPlaylistsCompanion.insert(
            id: id,
            name: name,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$LocalPlaylistsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({localPlaylistTracksRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (localPlaylistTracksRefs) db.localPlaylistTracks
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (localPlaylistTracksRefs)
                    await $_getPrefetchedData(
                        currentTable: table,
                        referencedTable: $$LocalPlaylistsTableReferences
                            ._localPlaylistTracksRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$LocalPlaylistsTableReferences(db, table, p0)
                                .localPlaylistTracksRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.playlistId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$LocalPlaylistsTableProcessedTableManager = ProcessedTableManager<
    _$AppDb,
    $LocalPlaylistsTable,
    LocalPlaylist,
    $$LocalPlaylistsTableFilterComposer,
    $$LocalPlaylistsTableOrderingComposer,
    $$LocalPlaylistsTableAnnotationComposer,
    $$LocalPlaylistsTableCreateCompanionBuilder,
    $$LocalPlaylistsTableUpdateCompanionBuilder,
    (LocalPlaylist, $$LocalPlaylistsTableReferences),
    LocalPlaylist,
    PrefetchHooks Function({bool localPlaylistTracksRefs})>;
typedef $$LocalPlaylistTracksTableCreateCompanionBuilder
    = LocalPlaylistTracksCompanion Function({
  required int playlistId,
  required String trackKey,
  required int position,
  Value<int> rowid,
});
typedef $$LocalPlaylistTracksTableUpdateCompanionBuilder
    = LocalPlaylistTracksCompanion Function({
  Value<int> playlistId,
  Value<String> trackKey,
  Value<int> position,
  Value<int> rowid,
});

final class $$LocalPlaylistTracksTableReferences extends BaseReferences<_$AppDb,
    $LocalPlaylistTracksTable, LocalPlaylistTrack> {
  $$LocalPlaylistTracksTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $LocalPlaylistsTable _playlistIdTable(_$AppDb db) =>
      db.localPlaylists.createAlias($_aliasNameGenerator(
          db.localPlaylistTracks.playlistId, db.localPlaylists.id));

  $$LocalPlaylistsTableProcessedTableManager get playlistId {
    final manager = $$LocalPlaylistsTableTableManager($_db, $_db.localPlaylists)
        .filter((f) => f.id($_item.playlistId));
    final item = $_typedResult.readTableOrNull(_playlistIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$LocalPlaylistTracksTableFilterComposer
    extends Composer<_$AppDb, $LocalPlaylistTracksTable> {
  $$LocalPlaylistTracksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get trackKey => $composableBuilder(
      column: $table.trackKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnFilters(column));

  $$LocalPlaylistsTableFilterComposer get playlistId {
    final $$LocalPlaylistsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.playlistId,
        referencedTable: $db.localPlaylists,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$LocalPlaylistsTableFilterComposer(
              $db: $db,
              $table: $db.localPlaylists,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$LocalPlaylistTracksTableOrderingComposer
    extends Composer<_$AppDb, $LocalPlaylistTracksTable> {
  $$LocalPlaylistTracksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get trackKey => $composableBuilder(
      column: $table.trackKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get position => $composableBuilder(
      column: $table.position, builder: (column) => ColumnOrderings(column));

  $$LocalPlaylistsTableOrderingComposer get playlistId {
    final $$LocalPlaylistsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.playlistId,
        referencedTable: $db.localPlaylists,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$LocalPlaylistsTableOrderingComposer(
              $db: $db,
              $table: $db.localPlaylists,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$LocalPlaylistTracksTableAnnotationComposer
    extends Composer<_$AppDb, $LocalPlaylistTracksTable> {
  $$LocalPlaylistTracksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get trackKey =>
      $composableBuilder(column: $table.trackKey, builder: (column) => column);

  GeneratedColumn<int> get position =>
      $composableBuilder(column: $table.position, builder: (column) => column);

  $$LocalPlaylistsTableAnnotationComposer get playlistId {
    final $$LocalPlaylistsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.playlistId,
        referencedTable: $db.localPlaylists,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$LocalPlaylistsTableAnnotationComposer(
              $db: $db,
              $table: $db.localPlaylists,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$LocalPlaylistTracksTableTableManager extends RootTableManager<
    _$AppDb,
    $LocalPlaylistTracksTable,
    LocalPlaylistTrack,
    $$LocalPlaylistTracksTableFilterComposer,
    $$LocalPlaylistTracksTableOrderingComposer,
    $$LocalPlaylistTracksTableAnnotationComposer,
    $$LocalPlaylistTracksTableCreateCompanionBuilder,
    $$LocalPlaylistTracksTableUpdateCompanionBuilder,
    (LocalPlaylistTrack, $$LocalPlaylistTracksTableReferences),
    LocalPlaylistTrack,
    PrefetchHooks Function({bool playlistId})> {
  $$LocalPlaylistTracksTableTableManager(
      _$AppDb db, $LocalPlaylistTracksTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalPlaylistTracksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalPlaylistTracksTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalPlaylistTracksTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> playlistId = const Value.absent(),
            Value<String> trackKey = const Value.absent(),
            Value<int> position = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalPlaylistTracksCompanion(
            playlistId: playlistId,
            trackKey: trackKey,
            position: position,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required int playlistId,
            required String trackKey,
            required int position,
            Value<int> rowid = const Value.absent(),
          }) =>
              LocalPlaylistTracksCompanion.insert(
            playlistId: playlistId,
            trackKey: trackKey,
            position: position,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$LocalPlaylistTracksTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({playlistId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (playlistId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.playlistId,
                    referencedTable: $$LocalPlaylistTracksTableReferences
                        ._playlistIdTable(db),
                    referencedColumn: $$LocalPlaylistTracksTableReferences
                        ._playlistIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$LocalPlaylistTracksTableProcessedTableManager = ProcessedTableManager<
    _$AppDb,
    $LocalPlaylistTracksTable,
    LocalPlaylistTrack,
    $$LocalPlaylistTracksTableFilterComposer,
    $$LocalPlaylistTracksTableOrderingComposer,
    $$LocalPlaylistTracksTableAnnotationComposer,
    $$LocalPlaylistTracksTableCreateCompanionBuilder,
    $$LocalPlaylistTracksTableUpdateCompanionBuilder,
    (LocalPlaylistTrack, $$LocalPlaylistTracksTableReferences),
    LocalPlaylistTrack,
    PrefetchHooks Function({bool playlistId})>;
typedef $$RecentPlaysTableCreateCompanionBuilder = RecentPlaysCompanion
    Function({
  required String trackKey,
  required DateTime playedAt,
  Value<int> rowid,
});
typedef $$RecentPlaysTableUpdateCompanionBuilder = RecentPlaysCompanion
    Function({
  Value<String> trackKey,
  Value<DateTime> playedAt,
  Value<int> rowid,
});

class $$RecentPlaysTableFilterComposer
    extends Composer<_$AppDb, $RecentPlaysTable> {
  $$RecentPlaysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get trackKey => $composableBuilder(
      column: $table.trackKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get playedAt => $composableBuilder(
      column: $table.playedAt, builder: (column) => ColumnFilters(column));
}

class $$RecentPlaysTableOrderingComposer
    extends Composer<_$AppDb, $RecentPlaysTable> {
  $$RecentPlaysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get trackKey => $composableBuilder(
      column: $table.trackKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get playedAt => $composableBuilder(
      column: $table.playedAt, builder: (column) => ColumnOrderings(column));
}

class $$RecentPlaysTableAnnotationComposer
    extends Composer<_$AppDb, $RecentPlaysTable> {
  $$RecentPlaysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get trackKey =>
      $composableBuilder(column: $table.trackKey, builder: (column) => column);

  GeneratedColumn<DateTime> get playedAt =>
      $composableBuilder(column: $table.playedAt, builder: (column) => column);
}

class $$RecentPlaysTableTableManager extends RootTableManager<
    _$AppDb,
    $RecentPlaysTable,
    RecentPlay,
    $$RecentPlaysTableFilterComposer,
    $$RecentPlaysTableOrderingComposer,
    $$RecentPlaysTableAnnotationComposer,
    $$RecentPlaysTableCreateCompanionBuilder,
    $$RecentPlaysTableUpdateCompanionBuilder,
    (RecentPlay, BaseReferences<_$AppDb, $RecentPlaysTable, RecentPlay>),
    RecentPlay,
    PrefetchHooks Function()> {
  $$RecentPlaysTableTableManager(_$AppDb db, $RecentPlaysTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecentPlaysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecentPlaysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecentPlaysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> trackKey = const Value.absent(),
            Value<DateTime> playedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              RecentPlaysCompanion(
            trackKey: trackKey,
            playedAt: playedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String trackKey,
            required DateTime playedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              RecentPlaysCompanion.insert(
            trackKey: trackKey,
            playedAt: playedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$RecentPlaysTableProcessedTableManager = ProcessedTableManager<
    _$AppDb,
    $RecentPlaysTable,
    RecentPlay,
    $$RecentPlaysTableFilterComposer,
    $$RecentPlaysTableOrderingComposer,
    $$RecentPlaysTableAnnotationComposer,
    $$RecentPlaysTableCreateCompanionBuilder,
    $$RecentPlaysTableUpdateCompanionBuilder,
    (RecentPlay, BaseReferences<_$AppDb, $RecentPlaysTable, RecentPlay>),
    RecentPlay,
    PrefetchHooks Function()>;

class $AppDbManager {
  final _$AppDb _db;
  $AppDbManager(this._db);
  $$DownloadsTableTableManager get downloads =>
      $$DownloadsTableTableManager(_db, _db.downloads);
  $$FavoritesTableTableManager get favorites =>
      $$FavoritesTableTableManager(_db, _db.favorites);
  $$LocalPlaylistsTableTableManager get localPlaylists =>
      $$LocalPlaylistsTableTableManager(_db, _db.localPlaylists);
  $$LocalPlaylistTracksTableTableManager get localPlaylistTracks =>
      $$LocalPlaylistTracksTableTableManager(_db, _db.localPlaylistTracks);
  $$RecentPlaysTableTableManager get recentPlays =>
      $$RecentPlaysTableTableManager(_db, _db.recentPlays);
}
