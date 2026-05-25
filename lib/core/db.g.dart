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
  static const VerificationMeta _pinnedMeta = const VerificationMeta('pinned');
  @override
  late final GeneratedColumn<bool> pinned = GeneratedColumn<bool>(
      'pinned', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("pinned" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _lastAccessedAtMeta =
      const VerificationMeta('lastAccessedAt');
  @override
  late final GeneratedColumn<DateTime> lastAccessedAt =
      GeneratedColumn<DateTime>('last_accessed_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [trackKey, filePath, sizeBytes, completedAt, pinned, lastAccessedAt];
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
    if (data.containsKey('pinned')) {
      context.handle(_pinnedMeta,
          pinned.isAcceptableOrUnknown(data['pinned']!, _pinnedMeta));
    }
    if (data.containsKey('last_accessed_at')) {
      context.handle(
          _lastAccessedAtMeta,
          lastAccessedAt.isAcceptableOrUnknown(
              data['last_accessed_at']!, _lastAccessedAtMeta));
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
      pinned: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}pinned'])!,
      lastAccessedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_accessed_at']),
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
  final bool pinned;
  final DateTime? lastAccessedAt;
  const Download(
      {required this.trackKey,
      required this.filePath,
      required this.sizeBytes,
      this.completedAt,
      required this.pinned,
      this.lastAccessedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['track_key'] = Variable<String>(trackKey);
    map['file_path'] = Variable<String>(filePath);
    map['size_bytes'] = Variable<int>(sizeBytes);
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    map['pinned'] = Variable<bool>(pinned);
    if (!nullToAbsent || lastAccessedAt != null) {
      map['last_accessed_at'] = Variable<DateTime>(lastAccessedAt);
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
      pinned: Value(pinned),
      lastAccessedAt: lastAccessedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAccessedAt),
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
      pinned: serializer.fromJson<bool>(json['pinned']),
      lastAccessedAt: serializer.fromJson<DateTime?>(json['lastAccessedAt']),
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
      'pinned': serializer.toJson<bool>(pinned),
      'lastAccessedAt': serializer.toJson<DateTime?>(lastAccessedAt),
    };
  }

  Download copyWith(
          {String? trackKey,
          String? filePath,
          int? sizeBytes,
          Value<DateTime?> completedAt = const Value.absent(),
          bool? pinned,
          Value<DateTime?> lastAccessedAt = const Value.absent()}) =>
      Download(
        trackKey: trackKey ?? this.trackKey,
        filePath: filePath ?? this.filePath,
        sizeBytes: sizeBytes ?? this.sizeBytes,
        completedAt: completedAt.present ? completedAt.value : this.completedAt,
        pinned: pinned ?? this.pinned,
        lastAccessedAt:
            lastAccessedAt.present ? lastAccessedAt.value : this.lastAccessedAt,
      );
  Download copyWithCompanion(DownloadsCompanion data) {
    return Download(
      trackKey: data.trackKey.present ? data.trackKey.value : this.trackKey,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      completedAt:
          data.completedAt.present ? data.completedAt.value : this.completedAt,
      pinned: data.pinned.present ? data.pinned.value : this.pinned,
      lastAccessedAt: data.lastAccessedAt.present
          ? data.lastAccessedAt.value
          : this.lastAccessedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Download(')
          ..write('trackKey: $trackKey, ')
          ..write('filePath: $filePath, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('completedAt: $completedAt, ')
          ..write('pinned: $pinned, ')
          ..write('lastAccessedAt: $lastAccessedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      trackKey, filePath, sizeBytes, completedAt, pinned, lastAccessedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Download &&
          other.trackKey == this.trackKey &&
          other.filePath == this.filePath &&
          other.sizeBytes == this.sizeBytes &&
          other.completedAt == this.completedAt &&
          other.pinned == this.pinned &&
          other.lastAccessedAt == this.lastAccessedAt);
}

class DownloadsCompanion extends UpdateCompanion<Download> {
  final Value<String> trackKey;
  final Value<String> filePath;
  final Value<int> sizeBytes;
  final Value<DateTime?> completedAt;
  final Value<bool> pinned;
  final Value<DateTime?> lastAccessedAt;
  final Value<int> rowid;
  const DownloadsCompanion({
    this.trackKey = const Value.absent(),
    this.filePath = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.pinned = const Value.absent(),
    this.lastAccessedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DownloadsCompanion.insert({
    required String trackKey,
    required String filePath,
    this.sizeBytes = const Value.absent(),
    this.completedAt = const Value.absent(),
    this.pinned = const Value.absent(),
    this.lastAccessedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : trackKey = Value(trackKey),
        filePath = Value(filePath);
  static Insertable<Download> custom({
    Expression<String>? trackKey,
    Expression<String>? filePath,
    Expression<int>? sizeBytes,
    Expression<DateTime>? completedAt,
    Expression<bool>? pinned,
    Expression<DateTime>? lastAccessedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (trackKey != null) 'track_key': trackKey,
      if (filePath != null) 'file_path': filePath,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (completedAt != null) 'completed_at': completedAt,
      if (pinned != null) 'pinned': pinned,
      if (lastAccessedAt != null) 'last_accessed_at': lastAccessedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DownloadsCompanion copyWith(
      {Value<String>? trackKey,
      Value<String>? filePath,
      Value<int>? sizeBytes,
      Value<DateTime?>? completedAt,
      Value<bool>? pinned,
      Value<DateTime?>? lastAccessedAt,
      Value<int>? rowid}) {
    return DownloadsCompanion(
      trackKey: trackKey ?? this.trackKey,
      filePath: filePath ?? this.filePath,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      completedAt: completedAt ?? this.completedAt,
      pinned: pinned ?? this.pinned,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
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
    if (pinned.present) {
      map['pinned'] = Variable<bool>(pinned.value);
    }
    if (lastAccessedAt.present) {
      map['last_accessed_at'] = Variable<DateTime>(lastAccessedAt.value);
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
          ..write('pinned: $pinned, ')
          ..write('lastAccessedAt: $lastAccessedAt, ')
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
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
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
  List<GeneratedColumn> get $columns => [id, trackKey, playedAt];
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
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RecentPlay map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecentPlay(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
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
  final int id;
  final String trackKey;
  final DateTime playedAt;
  const RecentPlay(
      {required this.id, required this.trackKey, required this.playedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['track_key'] = Variable<String>(trackKey);
    map['played_at'] = Variable<DateTime>(playedAt);
    return map;
  }

  RecentPlaysCompanion toCompanion(bool nullToAbsent) {
    return RecentPlaysCompanion(
      id: Value(id),
      trackKey: Value(trackKey),
      playedAt: Value(playedAt),
    );
  }

  factory RecentPlay.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecentPlay(
      id: serializer.fromJson<int>(json['id']),
      trackKey: serializer.fromJson<String>(json['trackKey']),
      playedAt: serializer.fromJson<DateTime>(json['playedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'trackKey': serializer.toJson<String>(trackKey),
      'playedAt': serializer.toJson<DateTime>(playedAt),
    };
  }

  RecentPlay copyWith({int? id, String? trackKey, DateTime? playedAt}) =>
      RecentPlay(
        id: id ?? this.id,
        trackKey: trackKey ?? this.trackKey,
        playedAt: playedAt ?? this.playedAt,
      );
  RecentPlay copyWithCompanion(RecentPlaysCompanion data) {
    return RecentPlay(
      id: data.id.present ? data.id.value : this.id,
      trackKey: data.trackKey.present ? data.trackKey.value : this.trackKey,
      playedAt: data.playedAt.present ? data.playedAt.value : this.playedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecentPlay(')
          ..write('id: $id, ')
          ..write('trackKey: $trackKey, ')
          ..write('playedAt: $playedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, trackKey, playedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecentPlay &&
          other.id == this.id &&
          other.trackKey == this.trackKey &&
          other.playedAt == this.playedAt);
}

class RecentPlaysCompanion extends UpdateCompanion<RecentPlay> {
  final Value<int> id;
  final Value<String> trackKey;
  final Value<DateTime> playedAt;
  const RecentPlaysCompanion({
    this.id = const Value.absent(),
    this.trackKey = const Value.absent(),
    this.playedAt = const Value.absent(),
  });
  RecentPlaysCompanion.insert({
    this.id = const Value.absent(),
    required String trackKey,
    required DateTime playedAt,
  })  : trackKey = Value(trackKey),
        playedAt = Value(playedAt);
  static Insertable<RecentPlay> custom({
    Expression<int>? id,
    Expression<String>? trackKey,
    Expression<DateTime>? playedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (trackKey != null) 'track_key': trackKey,
      if (playedAt != null) 'played_at': playedAt,
    });
  }

  RecentPlaysCompanion copyWith(
      {Value<int>? id, Value<String>? trackKey, Value<DateTime>? playedAt}) {
    return RecentPlaysCompanion(
      id: id ?? this.id,
      trackKey: trackKey ?? this.trackKey,
      playedAt: playedAt ?? this.playedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (trackKey.present) {
      map['track_key'] = Variable<String>(trackKey.value);
    }
    if (playedAt.present) {
      map['played_at'] = Variable<DateTime>(playedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecentPlaysCompanion(')
          ..write('id: $id, ')
          ..write('trackKey: $trackKey, ')
          ..write('playedAt: $playedAt')
          ..write(')'))
        .toString();
  }
}

class $MissingTracksTable extends MissingTracks
    with TableInfo<$MissingTracksTable, MissingTrack> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MissingTracksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _trackKeyMeta =
      const VerificationMeta('trackKey');
  @override
  late final GeneratedColumn<String> trackKey = GeneratedColumn<String>(
      'track_key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
      'artist', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _albumMeta = const VerificationMeta('album');
  @override
  late final GeneratedColumn<String> album = GeneratedColumn<String>(
      'album', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [trackKey, title, artist, album];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'missing_tracks';
  @override
  VerificationContext validateIntegrity(Insertable<MissingTrack> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('track_key')) {
      context.handle(_trackKeyMeta,
          trackKey.isAcceptableOrUnknown(data['track_key']!, _trackKeyMeta));
    } else if (isInserting) {
      context.missing(_trackKeyMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('artist')) {
      context.handle(_artistMeta,
          artist.isAcceptableOrUnknown(data['artist']!, _artistMeta));
    }
    if (data.containsKey('album')) {
      context.handle(
          _albumMeta, album.isAcceptableOrUnknown(data['album']!, _albumMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {trackKey};
  @override
  MissingTrack map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MissingTrack(
      trackKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}track_key'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      artist: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}artist']),
      album: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}album']),
    );
  }

  @override
  $MissingTracksTable createAlias(String alias) {
    return $MissingTracksTable(attachedDatabase, alias);
  }
}

class MissingTrack extends DataClass implements Insertable<MissingTrack> {
  final String trackKey;
  final String title;
  final String? artist;
  final String? album;
  const MissingTrack(
      {required this.trackKey, required this.title, this.artist, this.album});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['track_key'] = Variable<String>(trackKey);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || artist != null) {
      map['artist'] = Variable<String>(artist);
    }
    if (!nullToAbsent || album != null) {
      map['album'] = Variable<String>(album);
    }
    return map;
  }

  MissingTracksCompanion toCompanion(bool nullToAbsent) {
    return MissingTracksCompanion(
      trackKey: Value(trackKey),
      title: Value(title),
      artist:
          artist == null && nullToAbsent ? const Value.absent() : Value(artist),
      album:
          album == null && nullToAbsent ? const Value.absent() : Value(album),
    );
  }

  factory MissingTrack.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MissingTrack(
      trackKey: serializer.fromJson<String>(json['trackKey']),
      title: serializer.fromJson<String>(json['title']),
      artist: serializer.fromJson<String?>(json['artist']),
      album: serializer.fromJson<String?>(json['album']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'trackKey': serializer.toJson<String>(trackKey),
      'title': serializer.toJson<String>(title),
      'artist': serializer.toJson<String?>(artist),
      'album': serializer.toJson<String?>(album),
    };
  }

  MissingTrack copyWith(
          {String? trackKey,
          String? title,
          Value<String?> artist = const Value.absent(),
          Value<String?> album = const Value.absent()}) =>
      MissingTrack(
        trackKey: trackKey ?? this.trackKey,
        title: title ?? this.title,
        artist: artist.present ? artist.value : this.artist,
        album: album.present ? album.value : this.album,
      );
  MissingTrack copyWithCompanion(MissingTracksCompanion data) {
    return MissingTrack(
      trackKey: data.trackKey.present ? data.trackKey.value : this.trackKey,
      title: data.title.present ? data.title.value : this.title,
      artist: data.artist.present ? data.artist.value : this.artist,
      album: data.album.present ? data.album.value : this.album,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MissingTrack(')
          ..write('trackKey: $trackKey, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('album: $album')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(trackKey, title, artist, album);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MissingTrack &&
          other.trackKey == this.trackKey &&
          other.title == this.title &&
          other.artist == this.artist &&
          other.album == this.album);
}

class MissingTracksCompanion extends UpdateCompanion<MissingTrack> {
  final Value<String> trackKey;
  final Value<String> title;
  final Value<String?> artist;
  final Value<String?> album;
  final Value<int> rowid;
  const MissingTracksCompanion({
    this.trackKey = const Value.absent(),
    this.title = const Value.absent(),
    this.artist = const Value.absent(),
    this.album = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MissingTracksCompanion.insert({
    required String trackKey,
    required String title,
    this.artist = const Value.absent(),
    this.album = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : trackKey = Value(trackKey),
        title = Value(title);
  static Insertable<MissingTrack> custom({
    Expression<String>? trackKey,
    Expression<String>? title,
    Expression<String>? artist,
    Expression<String>? album,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (trackKey != null) 'track_key': trackKey,
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (album != null) 'album': album,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MissingTracksCompanion copyWith(
      {Value<String>? trackKey,
      Value<String>? title,
      Value<String?>? artist,
      Value<String?>? album,
      Value<int>? rowid}) {
    return MissingTracksCompanion(
      trackKey: trackKey ?? this.trackKey,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (trackKey.present) {
      map['track_key'] = Variable<String>(trackKey.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (album.present) {
      map['album'] = Variable<String>(album.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MissingTracksCompanion(')
          ..write('trackKey: $trackKey, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $WishlistTable extends Wishlist
    with TableInfo<$WishlistTable, WishlistData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WishlistTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
      'artist', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _albumMeta = const VerificationMeta('album');
  @override
  late final GeneratedColumn<String> album = GeneratedColumn<String>(
      'album', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _requestedAtMeta =
      const VerificationMeta('requestedAt');
  @override
  late final GeneratedColumn<DateTime> requestedAt = GeneratedColumn<DateTime>(
      'requested_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
      'notes', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, title, artist, album, requestedAt, notes];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'wishlist';
  @override
  VerificationContext validateIntegrity(Insertable<WishlistData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('artist')) {
      context.handle(_artistMeta,
          artist.isAcceptableOrUnknown(data['artist']!, _artistMeta));
    }
    if (data.containsKey('album')) {
      context.handle(
          _albumMeta, album.isAcceptableOrUnknown(data['album']!, _albumMeta));
    }
    if (data.containsKey('requested_at')) {
      context.handle(
          _requestedAtMeta,
          requestedAt.isAcceptableOrUnknown(
              data['requested_at']!, _requestedAtMeta));
    } else if (isInserting) {
      context.missing(_requestedAtMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
          _notesMeta, notes.isAcceptableOrUnknown(data['notes']!, _notesMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WishlistData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WishlistData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      artist: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}artist']),
      album: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}album']),
      requestedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}requested_at'])!,
      notes: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}notes']),
    );
  }

  @override
  $WishlistTable createAlias(String alias) {
    return $WishlistTable(attachedDatabase, alias);
  }
}

class WishlistData extends DataClass implements Insertable<WishlistData> {
  final int id;
  final String title;
  final String? artist;
  final String? album;
  final DateTime requestedAt;
  final String? notes;
  const WishlistData(
      {required this.id,
      required this.title,
      this.artist,
      this.album,
      required this.requestedAt,
      this.notes});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || artist != null) {
      map['artist'] = Variable<String>(artist);
    }
    if (!nullToAbsent || album != null) {
      map['album'] = Variable<String>(album);
    }
    map['requested_at'] = Variable<DateTime>(requestedAt);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  WishlistCompanion toCompanion(bool nullToAbsent) {
    return WishlistCompanion(
      id: Value(id),
      title: Value(title),
      artist:
          artist == null && nullToAbsent ? const Value.absent() : Value(artist),
      album:
          album == null && nullToAbsent ? const Value.absent() : Value(album),
      requestedAt: Value(requestedAt),
      notes:
          notes == null && nullToAbsent ? const Value.absent() : Value(notes),
    );
  }

  factory WishlistData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WishlistData(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      artist: serializer.fromJson<String?>(json['artist']),
      album: serializer.fromJson<String?>(json['album']),
      requestedAt: serializer.fromJson<DateTime>(json['requestedAt']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'artist': serializer.toJson<String?>(artist),
      'album': serializer.toJson<String?>(album),
      'requestedAt': serializer.toJson<DateTime>(requestedAt),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  WishlistData copyWith(
          {int? id,
          String? title,
          Value<String?> artist = const Value.absent(),
          Value<String?> album = const Value.absent(),
          DateTime? requestedAt,
          Value<String?> notes = const Value.absent()}) =>
      WishlistData(
        id: id ?? this.id,
        title: title ?? this.title,
        artist: artist.present ? artist.value : this.artist,
        album: album.present ? album.value : this.album,
        requestedAt: requestedAt ?? this.requestedAt,
        notes: notes.present ? notes.value : this.notes,
      );
  WishlistData copyWithCompanion(WishlistCompanion data) {
    return WishlistData(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      artist: data.artist.present ? data.artist.value : this.artist,
      album: data.album.present ? data.album.value : this.album,
      requestedAt:
          data.requestedAt.present ? data.requestedAt.value : this.requestedAt,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WishlistData(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('requestedAt: $requestedAt, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, artist, album, requestedAt, notes);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WishlistData &&
          other.id == this.id &&
          other.title == this.title &&
          other.artist == this.artist &&
          other.album == this.album &&
          other.requestedAt == this.requestedAt &&
          other.notes == this.notes);
}

class WishlistCompanion extends UpdateCompanion<WishlistData> {
  final Value<int> id;
  final Value<String> title;
  final Value<String?> artist;
  final Value<String?> album;
  final Value<DateTime> requestedAt;
  final Value<String?> notes;
  const WishlistCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.artist = const Value.absent(),
    this.album = const Value.absent(),
    this.requestedAt = const Value.absent(),
    this.notes = const Value.absent(),
  });
  WishlistCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    this.artist = const Value.absent(),
    this.album = const Value.absent(),
    required DateTime requestedAt,
    this.notes = const Value.absent(),
  })  : title = Value(title),
        requestedAt = Value(requestedAt);
  static Insertable<WishlistData> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? artist,
    Expression<String>? album,
    Expression<DateTime>? requestedAt,
    Expression<String>? notes,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (album != null) 'album': album,
      if (requestedAt != null) 'requested_at': requestedAt,
      if (notes != null) 'notes': notes,
    });
  }

  WishlistCompanion copyWith(
      {Value<int>? id,
      Value<String>? title,
      Value<String?>? artist,
      Value<String?>? album,
      Value<DateTime>? requestedAt,
      Value<String?>? notes}) {
    return WishlistCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      requestedAt: requestedAt ?? this.requestedAt,
      notes: notes ?? this.notes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (album.present) {
      map['album'] = Variable<String>(album.value);
    }
    if (requestedAt.present) {
      map['requested_at'] = Variable<DateTime>(requestedAt.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WishlistCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('requestedAt: $requestedAt, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }
}

class $CachedSubsonicSongsTable extends CachedSubsonicSongs
    with TableInfo<$CachedSubsonicSongsTable, CachedSubsonicSong> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedSubsonicSongsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _serverIdMeta =
      const VerificationMeta('serverId');
  @override
  late final GeneratedColumn<String> serverId = GeneratedColumn<String>(
      'server_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _songIdMeta = const VerificationMeta('songId');
  @override
  late final GeneratedColumn<String> songId = GeneratedColumn<String>(
      'song_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _artistMeta = const VerificationMeta('artist');
  @override
  late final GeneratedColumn<String> artist = GeneratedColumn<String>(
      'artist', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _albumMeta = const VerificationMeta('album');
  @override
  late final GeneratedColumn<String> album = GeneratedColumn<String>(
      'album', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _albumIdMeta =
      const VerificationMeta('albumId');
  @override
  late final GeneratedColumn<String> albumId = GeneratedColumn<String>(
      'album_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _artistIdMeta =
      const VerificationMeta('artistId');
  @override
  late final GeneratedColumn<String> artistId = GeneratedColumn<String>(
      'artist_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _coverArtMeta =
      const VerificationMeta('coverArt');
  @override
  late final GeneratedColumn<String> coverArt = GeneratedColumn<String>(
      'cover_art', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _yearMeta = const VerificationMeta('year');
  @override
  late final GeneratedColumn<int> year = GeneratedColumn<int>(
      'year', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _durationSecMeta =
      const VerificationMeta('durationSec');
  @override
  late final GeneratedColumn<int> durationSec = GeneratedColumn<int>(
      'duration_sec', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _genreMeta = const VerificationMeta('genre');
  @override
  late final GeneratedColumn<String> genre = GeneratedColumn<String>(
      'genre', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        serverId,
        songId,
        title,
        artist,
        album,
        albumId,
        artistId,
        coverArt,
        year,
        durationSec,
        genre
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_subsonic_songs';
  @override
  VerificationContext validateIntegrity(Insertable<CachedSubsonicSong> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('server_id')) {
      context.handle(_serverIdMeta,
          serverId.isAcceptableOrUnknown(data['server_id']!, _serverIdMeta));
    } else if (isInserting) {
      context.missing(_serverIdMeta);
    }
    if (data.containsKey('song_id')) {
      context.handle(_songIdMeta,
          songId.isAcceptableOrUnknown(data['song_id']!, _songIdMeta));
    } else if (isInserting) {
      context.missing(_songIdMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('artist')) {
      context.handle(_artistMeta,
          artist.isAcceptableOrUnknown(data['artist']!, _artistMeta));
    }
    if (data.containsKey('album')) {
      context.handle(
          _albumMeta, album.isAcceptableOrUnknown(data['album']!, _albumMeta));
    }
    if (data.containsKey('album_id')) {
      context.handle(_albumIdMeta,
          albumId.isAcceptableOrUnknown(data['album_id']!, _albumIdMeta));
    }
    if (data.containsKey('artist_id')) {
      context.handle(_artistIdMeta,
          artistId.isAcceptableOrUnknown(data['artist_id']!, _artistIdMeta));
    }
    if (data.containsKey('cover_art')) {
      context.handle(_coverArtMeta,
          coverArt.isAcceptableOrUnknown(data['cover_art']!, _coverArtMeta));
    }
    if (data.containsKey('year')) {
      context.handle(
          _yearMeta, year.isAcceptableOrUnknown(data['year']!, _yearMeta));
    }
    if (data.containsKey('duration_sec')) {
      context.handle(
          _durationSecMeta,
          durationSec.isAcceptableOrUnknown(
              data['duration_sec']!, _durationSecMeta));
    }
    if (data.containsKey('genre')) {
      context.handle(
          _genreMeta, genre.isAcceptableOrUnknown(data['genre']!, _genreMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {serverId, songId};
  @override
  CachedSubsonicSong map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedSubsonicSong(
      serverId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}server_id'])!,
      songId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}song_id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      artist: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}artist']),
      album: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}album']),
      albumId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}album_id']),
      artistId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}artist_id']),
      coverArt: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cover_art']),
      year: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}year']),
      durationSec: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}duration_sec']),
      genre: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}genre']),
    );
  }

  @override
  $CachedSubsonicSongsTable createAlias(String alias) {
    return $CachedSubsonicSongsTable(attachedDatabase, alias);
  }
}

class CachedSubsonicSong extends DataClass
    implements Insertable<CachedSubsonicSong> {
  final String serverId;
  final String songId;
  final String title;
  final String? artist;
  final String? album;
  final String? albumId;
  final String? artistId;
  final String? coverArt;
  final int? year;
  final int? durationSec;
  final String? genre;
  const CachedSubsonicSong(
      {required this.serverId,
      required this.songId,
      required this.title,
      this.artist,
      this.album,
      this.albumId,
      this.artistId,
      this.coverArt,
      this.year,
      this.durationSec,
      this.genre});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['server_id'] = Variable<String>(serverId);
    map['song_id'] = Variable<String>(songId);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || artist != null) {
      map['artist'] = Variable<String>(artist);
    }
    if (!nullToAbsent || album != null) {
      map['album'] = Variable<String>(album);
    }
    if (!nullToAbsent || albumId != null) {
      map['album_id'] = Variable<String>(albumId);
    }
    if (!nullToAbsent || artistId != null) {
      map['artist_id'] = Variable<String>(artistId);
    }
    if (!nullToAbsent || coverArt != null) {
      map['cover_art'] = Variable<String>(coverArt);
    }
    if (!nullToAbsent || year != null) {
      map['year'] = Variable<int>(year);
    }
    if (!nullToAbsent || durationSec != null) {
      map['duration_sec'] = Variable<int>(durationSec);
    }
    if (!nullToAbsent || genre != null) {
      map['genre'] = Variable<String>(genre);
    }
    return map;
  }

  CachedSubsonicSongsCompanion toCompanion(bool nullToAbsent) {
    return CachedSubsonicSongsCompanion(
      serverId: Value(serverId),
      songId: Value(songId),
      title: Value(title),
      artist:
          artist == null && nullToAbsent ? const Value.absent() : Value(artist),
      album:
          album == null && nullToAbsent ? const Value.absent() : Value(album),
      albumId: albumId == null && nullToAbsent
          ? const Value.absent()
          : Value(albumId),
      artistId: artistId == null && nullToAbsent
          ? const Value.absent()
          : Value(artistId),
      coverArt: coverArt == null && nullToAbsent
          ? const Value.absent()
          : Value(coverArt),
      year: year == null && nullToAbsent ? const Value.absent() : Value(year),
      durationSec: durationSec == null && nullToAbsent
          ? const Value.absent()
          : Value(durationSec),
      genre:
          genre == null && nullToAbsent ? const Value.absent() : Value(genre),
    );
  }

  factory CachedSubsonicSong.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedSubsonicSong(
      serverId: serializer.fromJson<String>(json['serverId']),
      songId: serializer.fromJson<String>(json['songId']),
      title: serializer.fromJson<String>(json['title']),
      artist: serializer.fromJson<String?>(json['artist']),
      album: serializer.fromJson<String?>(json['album']),
      albumId: serializer.fromJson<String?>(json['albumId']),
      artistId: serializer.fromJson<String?>(json['artistId']),
      coverArt: serializer.fromJson<String?>(json['coverArt']),
      year: serializer.fromJson<int?>(json['year']),
      durationSec: serializer.fromJson<int?>(json['durationSec']),
      genre: serializer.fromJson<String?>(json['genre']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'serverId': serializer.toJson<String>(serverId),
      'songId': serializer.toJson<String>(songId),
      'title': serializer.toJson<String>(title),
      'artist': serializer.toJson<String?>(artist),
      'album': serializer.toJson<String?>(album),
      'albumId': serializer.toJson<String?>(albumId),
      'artistId': serializer.toJson<String?>(artistId),
      'coverArt': serializer.toJson<String?>(coverArt),
      'year': serializer.toJson<int?>(year),
      'durationSec': serializer.toJson<int?>(durationSec),
      'genre': serializer.toJson<String?>(genre),
    };
  }

  CachedSubsonicSong copyWith(
          {String? serverId,
          String? songId,
          String? title,
          Value<String?> artist = const Value.absent(),
          Value<String?> album = const Value.absent(),
          Value<String?> albumId = const Value.absent(),
          Value<String?> artistId = const Value.absent(),
          Value<String?> coverArt = const Value.absent(),
          Value<int?> year = const Value.absent(),
          Value<int?> durationSec = const Value.absent(),
          Value<String?> genre = const Value.absent()}) =>
      CachedSubsonicSong(
        serverId: serverId ?? this.serverId,
        songId: songId ?? this.songId,
        title: title ?? this.title,
        artist: artist.present ? artist.value : this.artist,
        album: album.present ? album.value : this.album,
        albumId: albumId.present ? albumId.value : this.albumId,
        artistId: artistId.present ? artistId.value : this.artistId,
        coverArt: coverArt.present ? coverArt.value : this.coverArt,
        year: year.present ? year.value : this.year,
        durationSec: durationSec.present ? durationSec.value : this.durationSec,
        genre: genre.present ? genre.value : this.genre,
      );
  CachedSubsonicSong copyWithCompanion(CachedSubsonicSongsCompanion data) {
    return CachedSubsonicSong(
      serverId: data.serverId.present ? data.serverId.value : this.serverId,
      songId: data.songId.present ? data.songId.value : this.songId,
      title: data.title.present ? data.title.value : this.title,
      artist: data.artist.present ? data.artist.value : this.artist,
      album: data.album.present ? data.album.value : this.album,
      albumId: data.albumId.present ? data.albumId.value : this.albumId,
      artistId: data.artistId.present ? data.artistId.value : this.artistId,
      coverArt: data.coverArt.present ? data.coverArt.value : this.coverArt,
      year: data.year.present ? data.year.value : this.year,
      durationSec:
          data.durationSec.present ? data.durationSec.value : this.durationSec,
      genre: data.genre.present ? data.genre.value : this.genre,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedSubsonicSong(')
          ..write('serverId: $serverId, ')
          ..write('songId: $songId, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('albumId: $albumId, ')
          ..write('artistId: $artistId, ')
          ..write('coverArt: $coverArt, ')
          ..write('year: $year, ')
          ..write('durationSec: $durationSec, ')
          ..write('genre: $genre')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(serverId, songId, title, artist, album,
      albumId, artistId, coverArt, year, durationSec, genre);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedSubsonicSong &&
          other.serverId == this.serverId &&
          other.songId == this.songId &&
          other.title == this.title &&
          other.artist == this.artist &&
          other.album == this.album &&
          other.albumId == this.albumId &&
          other.artistId == this.artistId &&
          other.coverArt == this.coverArt &&
          other.year == this.year &&
          other.durationSec == this.durationSec &&
          other.genre == this.genre);
}

class CachedSubsonicSongsCompanion extends UpdateCompanion<CachedSubsonicSong> {
  final Value<String> serverId;
  final Value<String> songId;
  final Value<String> title;
  final Value<String?> artist;
  final Value<String?> album;
  final Value<String?> albumId;
  final Value<String?> artistId;
  final Value<String?> coverArt;
  final Value<int?> year;
  final Value<int?> durationSec;
  final Value<String?> genre;
  final Value<int> rowid;
  const CachedSubsonicSongsCompanion({
    this.serverId = const Value.absent(),
    this.songId = const Value.absent(),
    this.title = const Value.absent(),
    this.artist = const Value.absent(),
    this.album = const Value.absent(),
    this.albumId = const Value.absent(),
    this.artistId = const Value.absent(),
    this.coverArt = const Value.absent(),
    this.year = const Value.absent(),
    this.durationSec = const Value.absent(),
    this.genre = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedSubsonicSongsCompanion.insert({
    required String serverId,
    required String songId,
    required String title,
    this.artist = const Value.absent(),
    this.album = const Value.absent(),
    this.albumId = const Value.absent(),
    this.artistId = const Value.absent(),
    this.coverArt = const Value.absent(),
    this.year = const Value.absent(),
    this.durationSec = const Value.absent(),
    this.genre = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : serverId = Value(serverId),
        songId = Value(songId),
        title = Value(title);
  static Insertable<CachedSubsonicSong> custom({
    Expression<String>? serverId,
    Expression<String>? songId,
    Expression<String>? title,
    Expression<String>? artist,
    Expression<String>? album,
    Expression<String>? albumId,
    Expression<String>? artistId,
    Expression<String>? coverArt,
    Expression<int>? year,
    Expression<int>? durationSec,
    Expression<String>? genre,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (serverId != null) 'server_id': serverId,
      if (songId != null) 'song_id': songId,
      if (title != null) 'title': title,
      if (artist != null) 'artist': artist,
      if (album != null) 'album': album,
      if (albumId != null) 'album_id': albumId,
      if (artistId != null) 'artist_id': artistId,
      if (coverArt != null) 'cover_art': coverArt,
      if (year != null) 'year': year,
      if (durationSec != null) 'duration_sec': durationSec,
      if (genre != null) 'genre': genre,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedSubsonicSongsCompanion copyWith(
      {Value<String>? serverId,
      Value<String>? songId,
      Value<String>? title,
      Value<String?>? artist,
      Value<String?>? album,
      Value<String?>? albumId,
      Value<String?>? artistId,
      Value<String?>? coverArt,
      Value<int?>? year,
      Value<int?>? durationSec,
      Value<String?>? genre,
      Value<int>? rowid}) {
    return CachedSubsonicSongsCompanion(
      serverId: serverId ?? this.serverId,
      songId: songId ?? this.songId,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumId: albumId ?? this.albumId,
      artistId: artistId ?? this.artistId,
      coverArt: coverArt ?? this.coverArt,
      year: year ?? this.year,
      durationSec: durationSec ?? this.durationSec,
      genre: genre ?? this.genre,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (serverId.present) {
      map['server_id'] = Variable<String>(serverId.value);
    }
    if (songId.present) {
      map['song_id'] = Variable<String>(songId.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (artist.present) {
      map['artist'] = Variable<String>(artist.value);
    }
    if (album.present) {
      map['album'] = Variable<String>(album.value);
    }
    if (albumId.present) {
      map['album_id'] = Variable<String>(albumId.value);
    }
    if (artistId.present) {
      map['artist_id'] = Variable<String>(artistId.value);
    }
    if (coverArt.present) {
      map['cover_art'] = Variable<String>(coverArt.value);
    }
    if (year.present) {
      map['year'] = Variable<int>(year.value);
    }
    if (durationSec.present) {
      map['duration_sec'] = Variable<int>(durationSec.value);
    }
    if (genre.present) {
      map['genre'] = Variable<String>(genre.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CachedSubsonicSongsCompanion(')
          ..write('serverId: $serverId, ')
          ..write('songId: $songId, ')
          ..write('title: $title, ')
          ..write('artist: $artist, ')
          ..write('album: $album, ')
          ..write('albumId: $albumId, ')
          ..write('artistId: $artistId, ')
          ..write('coverArt: $coverArt, ')
          ..write('year: $year, ')
          ..write('durationSec: $durationSec, ')
          ..write('genre: $genre, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SmartPlaylistsTable extends SmartPlaylists
    with TableInfo<$SmartPlaylistsTable, SmartPlaylist> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SmartPlaylistsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _rulesJsonMeta =
      const VerificationMeta('rulesJson');
  @override
  late final GeneratedColumn<String> rulesJson = GeneratedColumn<String>(
      'rules_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, name, rulesJson, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'smart_playlists';
  @override
  VerificationContext validateIntegrity(Insertable<SmartPlaylist> instance,
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
    if (data.containsKey('rules_json')) {
      context.handle(_rulesJsonMeta,
          rulesJson.isAcceptableOrUnknown(data['rules_json']!, _rulesJsonMeta));
    } else if (isInserting) {
      context.missing(_rulesJsonMeta);
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
  SmartPlaylist map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SmartPlaylist(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      rulesJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}rules_json'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $SmartPlaylistsTable createAlias(String alias) {
    return $SmartPlaylistsTable(attachedDatabase, alias);
  }
}

class SmartPlaylist extends DataClass implements Insertable<SmartPlaylist> {
  final int id;
  final String name;
  final String rulesJson;
  final DateTime createdAt;
  const SmartPlaylist(
      {required this.id,
      required this.name,
      required this.rulesJson,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['rules_json'] = Variable<String>(rulesJson);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  SmartPlaylistsCompanion toCompanion(bool nullToAbsent) {
    return SmartPlaylistsCompanion(
      id: Value(id),
      name: Value(name),
      rulesJson: Value(rulesJson),
      createdAt: Value(createdAt),
    );
  }

  factory SmartPlaylist.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SmartPlaylist(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      rulesJson: serializer.fromJson<String>(json['rulesJson']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'rulesJson': serializer.toJson<String>(rulesJson),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  SmartPlaylist copyWith(
          {int? id, String? name, String? rulesJson, DateTime? createdAt}) =>
      SmartPlaylist(
        id: id ?? this.id,
        name: name ?? this.name,
        rulesJson: rulesJson ?? this.rulesJson,
        createdAt: createdAt ?? this.createdAt,
      );
  SmartPlaylist copyWithCompanion(SmartPlaylistsCompanion data) {
    return SmartPlaylist(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      rulesJson: data.rulesJson.present ? data.rulesJson.value : this.rulesJson,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SmartPlaylist(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('rulesJson: $rulesJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, rulesJson, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SmartPlaylist &&
          other.id == this.id &&
          other.name == this.name &&
          other.rulesJson == this.rulesJson &&
          other.createdAt == this.createdAt);
}

class SmartPlaylistsCompanion extends UpdateCompanion<SmartPlaylist> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> rulesJson;
  final Value<DateTime> createdAt;
  const SmartPlaylistsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.rulesJson = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  SmartPlaylistsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String rulesJson,
    required DateTime createdAt,
  })  : name = Value(name),
        rulesJson = Value(rulesJson),
        createdAt = Value(createdAt);
  static Insertable<SmartPlaylist> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? rulesJson,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (rulesJson != null) 'rules_json': rulesJson,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  SmartPlaylistsCompanion copyWith(
      {Value<int>? id,
      Value<String>? name,
      Value<String>? rulesJson,
      Value<DateTime>? createdAt}) {
    return SmartPlaylistsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      rulesJson: rulesJson ?? this.rulesJson,
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
    if (rulesJson.present) {
      map['rules_json'] = Variable<String>(rulesJson.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SmartPlaylistsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('rulesJson: $rulesJson, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $TrackPositionsTable extends TrackPositions
    with TableInfo<$TrackPositionsTable, TrackPosition> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TrackPositionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _trackKeyMeta =
      const VerificationMeta('trackKey');
  @override
  late final GeneratedColumn<String> trackKey = GeneratedColumn<String>(
      'track_key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _positionMsMeta =
      const VerificationMeta('positionMs');
  @override
  late final GeneratedColumn<int> positionMs = GeneratedColumn<int>(
      'position_ms', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [trackKey, positionMs, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'track_positions';
  @override
  VerificationContext validateIntegrity(Insertable<TrackPosition> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('track_key')) {
      context.handle(_trackKeyMeta,
          trackKey.isAcceptableOrUnknown(data['track_key']!, _trackKeyMeta));
    } else if (isInserting) {
      context.missing(_trackKeyMeta);
    }
    if (data.containsKey('position_ms')) {
      context.handle(
          _positionMsMeta,
          positionMs.isAcceptableOrUnknown(
              data['position_ms']!, _positionMsMeta));
    } else if (isInserting) {
      context.missing(_positionMsMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {trackKey};
  @override
  TrackPosition map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TrackPosition(
      trackKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}track_key'])!,
      positionMs: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}position_ms'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $TrackPositionsTable createAlias(String alias) {
    return $TrackPositionsTable(attachedDatabase, alias);
  }
}

class TrackPosition extends DataClass implements Insertable<TrackPosition> {
  final String trackKey;
  final int positionMs;
  final DateTime updatedAt;
  const TrackPosition(
      {required this.trackKey,
      required this.positionMs,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['track_key'] = Variable<String>(trackKey);
    map['position_ms'] = Variable<int>(positionMs);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  TrackPositionsCompanion toCompanion(bool nullToAbsent) {
    return TrackPositionsCompanion(
      trackKey: Value(trackKey),
      positionMs: Value(positionMs),
      updatedAt: Value(updatedAt),
    );
  }

  factory TrackPosition.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TrackPosition(
      trackKey: serializer.fromJson<String>(json['trackKey']),
      positionMs: serializer.fromJson<int>(json['positionMs']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'trackKey': serializer.toJson<String>(trackKey),
      'positionMs': serializer.toJson<int>(positionMs),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  TrackPosition copyWith(
          {String? trackKey, int? positionMs, DateTime? updatedAt}) =>
      TrackPosition(
        trackKey: trackKey ?? this.trackKey,
        positionMs: positionMs ?? this.positionMs,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  TrackPosition copyWithCompanion(TrackPositionsCompanion data) {
    return TrackPosition(
      trackKey: data.trackKey.present ? data.trackKey.value : this.trackKey,
      positionMs:
          data.positionMs.present ? data.positionMs.value : this.positionMs,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TrackPosition(')
          ..write('trackKey: $trackKey, ')
          ..write('positionMs: $positionMs, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(trackKey, positionMs, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TrackPosition &&
          other.trackKey == this.trackKey &&
          other.positionMs == this.positionMs &&
          other.updatedAt == this.updatedAt);
}

class TrackPositionsCompanion extends UpdateCompanion<TrackPosition> {
  final Value<String> trackKey;
  final Value<int> positionMs;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const TrackPositionsCompanion({
    this.trackKey = const Value.absent(),
    this.positionMs = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  TrackPositionsCompanion.insert({
    required String trackKey,
    required int positionMs,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  })  : trackKey = Value(trackKey),
        positionMs = Value(positionMs),
        updatedAt = Value(updatedAt);
  static Insertable<TrackPosition> custom({
    Expression<String>? trackKey,
    Expression<int>? positionMs,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (trackKey != null) 'track_key': trackKey,
      if (positionMs != null) 'position_ms': positionMs,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  TrackPositionsCompanion copyWith(
      {Value<String>? trackKey,
      Value<int>? positionMs,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return TrackPositionsCompanion(
      trackKey: trackKey ?? this.trackKey,
      positionMs: positionMs ?? this.positionMs,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (trackKey.present) {
      map['track_key'] = Variable<String>(trackKey.value);
    }
    if (positionMs.present) {
      map['position_ms'] = Variable<int>(positionMs.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TrackPositionsCompanion(')
          ..write('trackKey: $trackKey, ')
          ..write('positionMs: $positionMs, ')
          ..write('updatedAt: $updatedAt, ')
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
  late final $MissingTracksTable missingTracks = $MissingTracksTable(this);
  late final $WishlistTable wishlist = $WishlistTable(this);
  late final $CachedSubsonicSongsTable cachedSubsonicSongs =
      $CachedSubsonicSongsTable(this);
  late final $SmartPlaylistsTable smartPlaylists = $SmartPlaylistsTable(this);
  late final $TrackPositionsTable trackPositions = $TrackPositionsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        downloads,
        favorites,
        localPlaylists,
        localPlaylistTracks,
        recentPlays,
        missingTracks,
        wishlist,
        cachedSubsonicSongs,
        smartPlaylists,
        trackPositions
      ];
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
  Value<bool> pinned,
  Value<DateTime?> lastAccessedAt,
  Value<int> rowid,
});
typedef $$DownloadsTableUpdateCompanionBuilder = DownloadsCompanion Function({
  Value<String> trackKey,
  Value<String> filePath,
  Value<int> sizeBytes,
  Value<DateTime?> completedAt,
  Value<bool> pinned,
  Value<DateTime?> lastAccessedAt,
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

  ColumnFilters<bool> get pinned => $composableBuilder(
      column: $table.pinned, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastAccessedAt => $composableBuilder(
      column: $table.lastAccessedAt,
      builder: (column) => ColumnFilters(column));
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

  ColumnOrderings<bool> get pinned => $composableBuilder(
      column: $table.pinned, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastAccessedAt => $composableBuilder(
      column: $table.lastAccessedAt,
      builder: (column) => ColumnOrderings(column));
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

  GeneratedColumn<bool> get pinned =>
      $composableBuilder(column: $table.pinned, builder: (column) => column);

  GeneratedColumn<DateTime> get lastAccessedAt => $composableBuilder(
      column: $table.lastAccessedAt, builder: (column) => column);
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
            Value<bool> pinned = const Value.absent(),
            Value<DateTime?> lastAccessedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DownloadsCompanion(
            trackKey: trackKey,
            filePath: filePath,
            sizeBytes: sizeBytes,
            completedAt: completedAt,
            pinned: pinned,
            lastAccessedAt: lastAccessedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String trackKey,
            required String filePath,
            Value<int> sizeBytes = const Value.absent(),
            Value<DateTime?> completedAt = const Value.absent(),
            Value<bool> pinned = const Value.absent(),
            Value<DateTime?> lastAccessedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              DownloadsCompanion.insert(
            trackKey: trackKey,
            filePath: filePath,
            sizeBytes: sizeBytes,
            completedAt: completedAt,
            pinned: pinned,
            lastAccessedAt: lastAccessedAt,
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
  Value<int> id,
  required String trackKey,
  required DateTime playedAt,
});
typedef $$RecentPlaysTableUpdateCompanionBuilder = RecentPlaysCompanion
    Function({
  Value<int> id,
  Value<String> trackKey,
  Value<DateTime> playedAt,
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
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

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
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

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
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

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
            Value<int> id = const Value.absent(),
            Value<String> trackKey = const Value.absent(),
            Value<DateTime> playedAt = const Value.absent(),
          }) =>
              RecentPlaysCompanion(
            id: id,
            trackKey: trackKey,
            playedAt: playedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String trackKey,
            required DateTime playedAt,
          }) =>
              RecentPlaysCompanion.insert(
            id: id,
            trackKey: trackKey,
            playedAt: playedAt,
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
typedef $$MissingTracksTableCreateCompanionBuilder = MissingTracksCompanion
    Function({
  required String trackKey,
  required String title,
  Value<String?> artist,
  Value<String?> album,
  Value<int> rowid,
});
typedef $$MissingTracksTableUpdateCompanionBuilder = MissingTracksCompanion
    Function({
  Value<String> trackKey,
  Value<String> title,
  Value<String?> artist,
  Value<String?> album,
  Value<int> rowid,
});

class $$MissingTracksTableFilterComposer
    extends Composer<_$AppDb, $MissingTracksTable> {
  $$MissingTracksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get trackKey => $composableBuilder(
      column: $table.trackKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get artist => $composableBuilder(
      column: $table.artist, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get album => $composableBuilder(
      column: $table.album, builder: (column) => ColumnFilters(column));
}

class $$MissingTracksTableOrderingComposer
    extends Composer<_$AppDb, $MissingTracksTable> {
  $$MissingTracksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get trackKey => $composableBuilder(
      column: $table.trackKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get artist => $composableBuilder(
      column: $table.artist, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get album => $composableBuilder(
      column: $table.album, builder: (column) => ColumnOrderings(column));
}

class $$MissingTracksTableAnnotationComposer
    extends Composer<_$AppDb, $MissingTracksTable> {
  $$MissingTracksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get trackKey =>
      $composableBuilder(column: $table.trackKey, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumn<String> get album =>
      $composableBuilder(column: $table.album, builder: (column) => column);
}

class $$MissingTracksTableTableManager extends RootTableManager<
    _$AppDb,
    $MissingTracksTable,
    MissingTrack,
    $$MissingTracksTableFilterComposer,
    $$MissingTracksTableOrderingComposer,
    $$MissingTracksTableAnnotationComposer,
    $$MissingTracksTableCreateCompanionBuilder,
    $$MissingTracksTableUpdateCompanionBuilder,
    (MissingTrack, BaseReferences<_$AppDb, $MissingTracksTable, MissingTrack>),
    MissingTrack,
    PrefetchHooks Function()> {
  $$MissingTracksTableTableManager(_$AppDb db, $MissingTracksTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MissingTracksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MissingTracksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MissingTracksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> trackKey = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> artist = const Value.absent(),
            Value<String?> album = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MissingTracksCompanion(
            trackKey: trackKey,
            title: title,
            artist: artist,
            album: album,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String trackKey,
            required String title,
            Value<String?> artist = const Value.absent(),
            Value<String?> album = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MissingTracksCompanion.insert(
            trackKey: trackKey,
            title: title,
            artist: artist,
            album: album,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$MissingTracksTableProcessedTableManager = ProcessedTableManager<
    _$AppDb,
    $MissingTracksTable,
    MissingTrack,
    $$MissingTracksTableFilterComposer,
    $$MissingTracksTableOrderingComposer,
    $$MissingTracksTableAnnotationComposer,
    $$MissingTracksTableCreateCompanionBuilder,
    $$MissingTracksTableUpdateCompanionBuilder,
    (MissingTrack, BaseReferences<_$AppDb, $MissingTracksTable, MissingTrack>),
    MissingTrack,
    PrefetchHooks Function()>;
typedef $$WishlistTableCreateCompanionBuilder = WishlistCompanion Function({
  Value<int> id,
  required String title,
  Value<String?> artist,
  Value<String?> album,
  required DateTime requestedAt,
  Value<String?> notes,
});
typedef $$WishlistTableUpdateCompanionBuilder = WishlistCompanion Function({
  Value<int> id,
  Value<String> title,
  Value<String?> artist,
  Value<String?> album,
  Value<DateTime> requestedAt,
  Value<String?> notes,
});

class $$WishlistTableFilterComposer extends Composer<_$AppDb, $WishlistTable> {
  $$WishlistTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get artist => $composableBuilder(
      column: $table.artist, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get album => $composableBuilder(
      column: $table.album, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get requestedAt => $composableBuilder(
      column: $table.requestedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnFilters(column));
}

class $$WishlistTableOrderingComposer
    extends Composer<_$AppDb, $WishlistTable> {
  $$WishlistTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get artist => $composableBuilder(
      column: $table.artist, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get album => $composableBuilder(
      column: $table.album, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get requestedAt => $composableBuilder(
      column: $table.requestedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get notes => $composableBuilder(
      column: $table.notes, builder: (column) => ColumnOrderings(column));
}

class $$WishlistTableAnnotationComposer
    extends Composer<_$AppDb, $WishlistTable> {
  $$WishlistTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumn<String> get album =>
      $composableBuilder(column: $table.album, builder: (column) => column);

  GeneratedColumn<DateTime> get requestedAt => $composableBuilder(
      column: $table.requestedAt, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);
}

class $$WishlistTableTableManager extends RootTableManager<
    _$AppDb,
    $WishlistTable,
    WishlistData,
    $$WishlistTableFilterComposer,
    $$WishlistTableOrderingComposer,
    $$WishlistTableAnnotationComposer,
    $$WishlistTableCreateCompanionBuilder,
    $$WishlistTableUpdateCompanionBuilder,
    (WishlistData, BaseReferences<_$AppDb, $WishlistTable, WishlistData>),
    WishlistData,
    PrefetchHooks Function()> {
  $$WishlistTableTableManager(_$AppDb db, $WishlistTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WishlistTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WishlistTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WishlistTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> artist = const Value.absent(),
            Value<String?> album = const Value.absent(),
            Value<DateTime> requestedAt = const Value.absent(),
            Value<String?> notes = const Value.absent(),
          }) =>
              WishlistCompanion(
            id: id,
            title: title,
            artist: artist,
            album: album,
            requestedAt: requestedAt,
            notes: notes,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String title,
            Value<String?> artist = const Value.absent(),
            Value<String?> album = const Value.absent(),
            required DateTime requestedAt,
            Value<String?> notes = const Value.absent(),
          }) =>
              WishlistCompanion.insert(
            id: id,
            title: title,
            artist: artist,
            album: album,
            requestedAt: requestedAt,
            notes: notes,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$WishlistTableProcessedTableManager = ProcessedTableManager<
    _$AppDb,
    $WishlistTable,
    WishlistData,
    $$WishlistTableFilterComposer,
    $$WishlistTableOrderingComposer,
    $$WishlistTableAnnotationComposer,
    $$WishlistTableCreateCompanionBuilder,
    $$WishlistTableUpdateCompanionBuilder,
    (WishlistData, BaseReferences<_$AppDb, $WishlistTable, WishlistData>),
    WishlistData,
    PrefetchHooks Function()>;
typedef $$CachedSubsonicSongsTableCreateCompanionBuilder
    = CachedSubsonicSongsCompanion Function({
  required String serverId,
  required String songId,
  required String title,
  Value<String?> artist,
  Value<String?> album,
  Value<String?> albumId,
  Value<String?> artistId,
  Value<String?> coverArt,
  Value<int?> year,
  Value<int?> durationSec,
  Value<String?> genre,
  Value<int> rowid,
});
typedef $$CachedSubsonicSongsTableUpdateCompanionBuilder
    = CachedSubsonicSongsCompanion Function({
  Value<String> serverId,
  Value<String> songId,
  Value<String> title,
  Value<String?> artist,
  Value<String?> album,
  Value<String?> albumId,
  Value<String?> artistId,
  Value<String?> coverArt,
  Value<int?> year,
  Value<int?> durationSec,
  Value<String?> genre,
  Value<int> rowid,
});

class $$CachedSubsonicSongsTableFilterComposer
    extends Composer<_$AppDb, $CachedSubsonicSongsTable> {
  $$CachedSubsonicSongsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get serverId => $composableBuilder(
      column: $table.serverId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get songId => $composableBuilder(
      column: $table.songId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get artist => $composableBuilder(
      column: $table.artist, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get album => $composableBuilder(
      column: $table.album, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get albumId => $composableBuilder(
      column: $table.albumId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get artistId => $composableBuilder(
      column: $table.artistId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get coverArt => $composableBuilder(
      column: $table.coverArt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get year => $composableBuilder(
      column: $table.year, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get durationSec => $composableBuilder(
      column: $table.durationSec, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get genre => $composableBuilder(
      column: $table.genre, builder: (column) => ColumnFilters(column));
}

class $$CachedSubsonicSongsTableOrderingComposer
    extends Composer<_$AppDb, $CachedSubsonicSongsTable> {
  $$CachedSubsonicSongsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get serverId => $composableBuilder(
      column: $table.serverId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get songId => $composableBuilder(
      column: $table.songId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get artist => $composableBuilder(
      column: $table.artist, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get album => $composableBuilder(
      column: $table.album, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get albumId => $composableBuilder(
      column: $table.albumId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get artistId => $composableBuilder(
      column: $table.artistId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get coverArt => $composableBuilder(
      column: $table.coverArt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get year => $composableBuilder(
      column: $table.year, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get durationSec => $composableBuilder(
      column: $table.durationSec, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get genre => $composableBuilder(
      column: $table.genre, builder: (column) => ColumnOrderings(column));
}

class $$CachedSubsonicSongsTableAnnotationComposer
    extends Composer<_$AppDb, $CachedSubsonicSongsTable> {
  $$CachedSubsonicSongsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get serverId =>
      $composableBuilder(column: $table.serverId, builder: (column) => column);

  GeneratedColumn<String> get songId =>
      $composableBuilder(column: $table.songId, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get artist =>
      $composableBuilder(column: $table.artist, builder: (column) => column);

  GeneratedColumn<String> get album =>
      $composableBuilder(column: $table.album, builder: (column) => column);

  GeneratedColumn<String> get albumId =>
      $composableBuilder(column: $table.albumId, builder: (column) => column);

  GeneratedColumn<String> get artistId =>
      $composableBuilder(column: $table.artistId, builder: (column) => column);

  GeneratedColumn<String> get coverArt =>
      $composableBuilder(column: $table.coverArt, builder: (column) => column);

  GeneratedColumn<int> get year =>
      $composableBuilder(column: $table.year, builder: (column) => column);

  GeneratedColumn<int> get durationSec => $composableBuilder(
      column: $table.durationSec, builder: (column) => column);

  GeneratedColumn<String> get genre =>
      $composableBuilder(column: $table.genre, builder: (column) => column);
}

class $$CachedSubsonicSongsTableTableManager extends RootTableManager<
    _$AppDb,
    $CachedSubsonicSongsTable,
    CachedSubsonicSong,
    $$CachedSubsonicSongsTableFilterComposer,
    $$CachedSubsonicSongsTableOrderingComposer,
    $$CachedSubsonicSongsTableAnnotationComposer,
    $$CachedSubsonicSongsTableCreateCompanionBuilder,
    $$CachedSubsonicSongsTableUpdateCompanionBuilder,
    (
      CachedSubsonicSong,
      BaseReferences<_$AppDb, $CachedSubsonicSongsTable, CachedSubsonicSong>
    ),
    CachedSubsonicSong,
    PrefetchHooks Function()> {
  $$CachedSubsonicSongsTableTableManager(
      _$AppDb db, $CachedSubsonicSongsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedSubsonicSongsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedSubsonicSongsTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedSubsonicSongsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> serverId = const Value.absent(),
            Value<String> songId = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<String?> artist = const Value.absent(),
            Value<String?> album = const Value.absent(),
            Value<String?> albumId = const Value.absent(),
            Value<String?> artistId = const Value.absent(),
            Value<String?> coverArt = const Value.absent(),
            Value<int?> year = const Value.absent(),
            Value<int?> durationSec = const Value.absent(),
            Value<String?> genre = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedSubsonicSongsCompanion(
            serverId: serverId,
            songId: songId,
            title: title,
            artist: artist,
            album: album,
            albumId: albumId,
            artistId: artistId,
            coverArt: coverArt,
            year: year,
            durationSec: durationSec,
            genre: genre,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String serverId,
            required String songId,
            required String title,
            Value<String?> artist = const Value.absent(),
            Value<String?> album = const Value.absent(),
            Value<String?> albumId = const Value.absent(),
            Value<String?> artistId = const Value.absent(),
            Value<String?> coverArt = const Value.absent(),
            Value<int?> year = const Value.absent(),
            Value<int?> durationSec = const Value.absent(),
            Value<String?> genre = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              CachedSubsonicSongsCompanion.insert(
            serverId: serverId,
            songId: songId,
            title: title,
            artist: artist,
            album: album,
            albumId: albumId,
            artistId: artistId,
            coverArt: coverArt,
            year: year,
            durationSec: durationSec,
            genre: genre,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$CachedSubsonicSongsTableProcessedTableManager = ProcessedTableManager<
    _$AppDb,
    $CachedSubsonicSongsTable,
    CachedSubsonicSong,
    $$CachedSubsonicSongsTableFilterComposer,
    $$CachedSubsonicSongsTableOrderingComposer,
    $$CachedSubsonicSongsTableAnnotationComposer,
    $$CachedSubsonicSongsTableCreateCompanionBuilder,
    $$CachedSubsonicSongsTableUpdateCompanionBuilder,
    (
      CachedSubsonicSong,
      BaseReferences<_$AppDb, $CachedSubsonicSongsTable, CachedSubsonicSong>
    ),
    CachedSubsonicSong,
    PrefetchHooks Function()>;
typedef $$SmartPlaylistsTableCreateCompanionBuilder = SmartPlaylistsCompanion
    Function({
  Value<int> id,
  required String name,
  required String rulesJson,
  required DateTime createdAt,
});
typedef $$SmartPlaylistsTableUpdateCompanionBuilder = SmartPlaylistsCompanion
    Function({
  Value<int> id,
  Value<String> name,
  Value<String> rulesJson,
  Value<DateTime> createdAt,
});

class $$SmartPlaylistsTableFilterComposer
    extends Composer<_$AppDb, $SmartPlaylistsTable> {
  $$SmartPlaylistsTableFilterComposer({
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

  ColumnFilters<String> get rulesJson => $composableBuilder(
      column: $table.rulesJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$SmartPlaylistsTableOrderingComposer
    extends Composer<_$AppDb, $SmartPlaylistsTable> {
  $$SmartPlaylistsTableOrderingComposer({
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

  ColumnOrderings<String> get rulesJson => $composableBuilder(
      column: $table.rulesJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$SmartPlaylistsTableAnnotationComposer
    extends Composer<_$AppDb, $SmartPlaylistsTable> {
  $$SmartPlaylistsTableAnnotationComposer({
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

  GeneratedColumn<String> get rulesJson =>
      $composableBuilder(column: $table.rulesJson, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$SmartPlaylistsTableTableManager extends RootTableManager<
    _$AppDb,
    $SmartPlaylistsTable,
    SmartPlaylist,
    $$SmartPlaylistsTableFilterComposer,
    $$SmartPlaylistsTableOrderingComposer,
    $$SmartPlaylistsTableAnnotationComposer,
    $$SmartPlaylistsTableCreateCompanionBuilder,
    $$SmartPlaylistsTableUpdateCompanionBuilder,
    (
      SmartPlaylist,
      BaseReferences<_$AppDb, $SmartPlaylistsTable, SmartPlaylist>
    ),
    SmartPlaylist,
    PrefetchHooks Function()> {
  $$SmartPlaylistsTableTableManager(_$AppDb db, $SmartPlaylistsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SmartPlaylistsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SmartPlaylistsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SmartPlaylistsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> rulesJson = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              SmartPlaylistsCompanion(
            id: id,
            name: name,
            rulesJson: rulesJson,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            required String rulesJson,
            required DateTime createdAt,
          }) =>
              SmartPlaylistsCompanion.insert(
            id: id,
            name: name,
            rulesJson: rulesJson,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SmartPlaylistsTableProcessedTableManager = ProcessedTableManager<
    _$AppDb,
    $SmartPlaylistsTable,
    SmartPlaylist,
    $$SmartPlaylistsTableFilterComposer,
    $$SmartPlaylistsTableOrderingComposer,
    $$SmartPlaylistsTableAnnotationComposer,
    $$SmartPlaylistsTableCreateCompanionBuilder,
    $$SmartPlaylistsTableUpdateCompanionBuilder,
    (
      SmartPlaylist,
      BaseReferences<_$AppDb, $SmartPlaylistsTable, SmartPlaylist>
    ),
    SmartPlaylist,
    PrefetchHooks Function()>;
typedef $$TrackPositionsTableCreateCompanionBuilder = TrackPositionsCompanion
    Function({
  required String trackKey,
  required int positionMs,
  required DateTime updatedAt,
  Value<int> rowid,
});
typedef $$TrackPositionsTableUpdateCompanionBuilder = TrackPositionsCompanion
    Function({
  Value<String> trackKey,
  Value<int> positionMs,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

class $$TrackPositionsTableFilterComposer
    extends Composer<_$AppDb, $TrackPositionsTable> {
  $$TrackPositionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get trackKey => $composableBuilder(
      column: $table.trackKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get positionMs => $composableBuilder(
      column: $table.positionMs, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$TrackPositionsTableOrderingComposer
    extends Composer<_$AppDb, $TrackPositionsTable> {
  $$TrackPositionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get trackKey => $composableBuilder(
      column: $table.trackKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get positionMs => $composableBuilder(
      column: $table.positionMs, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$TrackPositionsTableAnnotationComposer
    extends Composer<_$AppDb, $TrackPositionsTable> {
  $$TrackPositionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get trackKey =>
      $composableBuilder(column: $table.trackKey, builder: (column) => column);

  GeneratedColumn<int> get positionMs => $composableBuilder(
      column: $table.positionMs, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$TrackPositionsTableTableManager extends RootTableManager<
    _$AppDb,
    $TrackPositionsTable,
    TrackPosition,
    $$TrackPositionsTableFilterComposer,
    $$TrackPositionsTableOrderingComposer,
    $$TrackPositionsTableAnnotationComposer,
    $$TrackPositionsTableCreateCompanionBuilder,
    $$TrackPositionsTableUpdateCompanionBuilder,
    (
      TrackPosition,
      BaseReferences<_$AppDb, $TrackPositionsTable, TrackPosition>
    ),
    TrackPosition,
    PrefetchHooks Function()> {
  $$TrackPositionsTableTableManager(_$AppDb db, $TrackPositionsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TrackPositionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TrackPositionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TrackPositionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> trackKey = const Value.absent(),
            Value<int> positionMs = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              TrackPositionsCompanion(
            trackKey: trackKey,
            positionMs: positionMs,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String trackKey,
            required int positionMs,
            required DateTime updatedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              TrackPositionsCompanion.insert(
            trackKey: trackKey,
            positionMs: positionMs,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$TrackPositionsTableProcessedTableManager = ProcessedTableManager<
    _$AppDb,
    $TrackPositionsTable,
    TrackPosition,
    $$TrackPositionsTableFilterComposer,
    $$TrackPositionsTableOrderingComposer,
    $$TrackPositionsTableAnnotationComposer,
    $$TrackPositionsTableCreateCompanionBuilder,
    $$TrackPositionsTableUpdateCompanionBuilder,
    (
      TrackPosition,
      BaseReferences<_$AppDb, $TrackPositionsTable, TrackPosition>
    ),
    TrackPosition,
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
  $$MissingTracksTableTableManager get missingTracks =>
      $$MissingTracksTableTableManager(_db, _db.missingTracks);
  $$WishlistTableTableManager get wishlist =>
      $$WishlistTableTableManager(_db, _db.wishlist);
  $$CachedSubsonicSongsTableTableManager get cachedSubsonicSongs =>
      $$CachedSubsonicSongsTableTableManager(_db, _db.cachedSubsonicSongs);
  $$SmartPlaylistsTableTableManager get smartPlaylists =>
      $$SmartPlaylistsTableTableManager(_db, _db.smartPlaylists);
  $$TrackPositionsTableTableManager get trackPositions =>
      $$TrackPositionsTableTableManager(_db, _db.trackPositions);
}
