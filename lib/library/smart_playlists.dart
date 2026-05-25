import 'dart:convert';

import 'package:drift/drift.dart';

import '../core/db.dart';
import '../domain.dart';

/// Rules-based playlists that materialise at open-time. The rule shape:
///
/// ```json
/// {
///   "match": "all",      // "all" = AND, "any" = OR
///   "rules": [
///     {"field": "genre", "op": "eq", "value": "Rock"},
///     {"field": "year", "op": "between", "value": [2000, 2010]},
///     {"field": "artist", "op": "contains", "value": "daft"}
///   ],
///   "orderBy": "year",   // year | title | artist | durationSec | random
///   "orderDir": "desc",  // ignored when orderBy = random
///   "limit": 50
/// }
/// ```
///
/// **v1 scope**: filters only on [CachedSubsonicSongs] columns. Joins
/// against favourites / play counts / pinned downloads are deliberately
/// deferred so the engine is small + bug-free; they'll come in a v2
/// once the basic version proves itself.
class SmartPlaylistsManager {
  final AppDb _db;
  SmartPlaylistsManager(this._db);

  Stream<List<SmartPlaylist>> watchAll() =>
      (_db.select(_db.smartPlaylists)..orderBy([(p) => OrderingTerm.asc(p.name)]))
          .watch();

  Future<SmartPlaylist?> get(int id) async =>
      (_db.select(_db.smartPlaylists)..where((p) => p.id.equals(id)))
          .getSingleOrNull();

  Future<int> create({required String name, required Map<String, dynamic> rules}) =>
      _db.into(_db.smartPlaylists).insert(SmartPlaylistsCompanion(
            name: Value(name),
            rulesJson: Value(jsonEncode(rules)),
            createdAt: Value(DateTime.now()),
          ));

  Future<void> update(int id,
          {required String name, required Map<String, dynamic> rules}) =>
      (_db.update(_db.smartPlaylists)..where((p) => p.id.equals(id))).write(
        SmartPlaylistsCompanion(
            name: Value(name), rulesJson: Value(jsonEncode(rules))),
      );

  Future<void> delete(int id) =>
      (_db.delete(_db.smartPlaylists)..where((p) => p.id.equals(id))).go();

  /// Seeds the table with starter smart playlists on first launch only.
  /// Caller is responsible for the "ever-seeded" flag (typically in
  /// SharedPreferences) — that way a user who deletes them all keeps
  /// them deleted instead of fighting the seeder forever.
  Future<void> seedBuiltins() async {
    final year = DateTime.now().year;
    await create(name: 'All time random', rules: const {
      'match': 'all',
      'rules': [],
      'orderBy': 'random',
      'limit': 50,
    });
    await create(name: '80s revival', rules: const {
      'match': 'all',
      'rules': [
        {'field': 'year', 'op': 'between', 'value': [1980, 1989]}
      ],
      'orderBy': 'random',
      'limit': 50,
    });
    await create(name: '90s revival', rules: const {
      'match': 'all',
      'rules': [
        {'field': 'year', 'op': 'between', 'value': [1990, 1999]}
      ],
      'orderBy': 'random',
      'limit': 50,
    });
    await create(name: 'Recent (${year - 4}–$year)', rules: {
      'match': 'all',
      'rules': [
        {'field': 'year', 'op': 'gte', 'value': year - 4}
      ],
      'orderBy': 'random',
      'limit': 50,
    });
  }

  /// Materialises the playlist for the active [serverId]. Returns the
  /// matching tracks in the order specified by the rules.
  Future<List<Track>> execute(SmartPlaylist p, String serverId) =>
      executeRules(jsonDecode(p.rulesJson) as Map<String, dynamic>, serverId);

  Future<List<Track>> executeRules(
      Map<String, dynamic> rules, String serverId) async {
    final match = (rules['match'] as String?) ?? 'all';
    final ruleList = (rules['rules'] as List?) ?? const [];
    final orderBy = (rules['orderBy'] as String?) ?? 'random';
    final orderDir = (rules['orderDir'] as String?) ?? 'desc';
    final limit = (rules['limit'] as int?) ?? 50;

    final whereSql = <String>[];
    final vars = <Variable>[Variable<String>(serverId)];
    for (final r in ruleList) {
      final part = _ruleToSql(r as Map<String, dynamic>, vars);
      if (part != null) whereSql.add(part);
    }

    final filterClause = whereSql.isEmpty
        ? ''
        : ' AND (${whereSql.join(match == 'any' ? ' OR ' : ' AND ')})';
    final orderClause = _orderClause(orderBy, orderDir);

    final sql = 'SELECT * FROM cached_subsonic_songs '
        'WHERE server_id = ? $filterClause '
        'ORDER BY $orderClause LIMIT ${limit.clamp(1, 1000)}';

    final rows = await _db
        .customSelect(sql, variables: vars, readsFrom: {_db.cachedSubsonicSongs})
        .get();
    return rows.map(_rowToTrack).toList();
  }

  /// Returns null when the rule is malformed or the field/op is unknown
  /// — silently drops so a single bad rule doesn't tank the whole query.
  String? _ruleToSql(Map<String, dynamic> rule, List<Variable> vars) {
    final field = rule['field'] as String?;
    final op = rule['op'] as String?;
    final value = rule['value'];
    final col = _fieldToColumn(field);
    if (col == null || op == null) return null;

    switch (op) {
      case 'eq':
        vars.add(_var(value));
        return '$col = ?';
      case 'neq':
        vars.add(_var(value));
        return '$col != ?';
      case 'gt':
        vars.add(_var(value));
        return '$col > ?';
      case 'gte':
        vars.add(_var(value));
        return '$col >= ?';
      case 'lt':
        vars.add(_var(value));
        return '$col < ?';
      case 'lte':
        vars.add(_var(value));
        return '$col <= ?';
      case 'between':
        if (value is! List || value.length != 2) return null;
        vars.add(_var(value[0]));
        vars.add(_var(value[1]));
        return '$col BETWEEN ? AND ?';
      case 'contains':
        vars.add(Variable<String>('%${value.toString().toLowerCase()}%'));
        return 'LOWER($col) LIKE ?';
    }
    return null;
  }

  String? _fieldToColumn(String? field) {
    switch (field) {
      case 'genre':
        return 'genre';
      case 'year':
        return 'year';
      case 'artist':
        return 'artist';
      case 'album':
        return 'album';
      case 'durationSec':
        return 'duration_sec';
      case 'title':
        return 'title';
    }
    return null;
  }

  String _orderClause(String orderBy, String dir) {
    final d = (dir == 'asc') ? 'ASC' : 'DESC';
    switch (orderBy) {
      case 'random':
        return 'RANDOM()';
      case 'year':
        return 'year $d';
      case 'title':
        return 'title $d';
      case 'artist':
        return 'artist $d';
      case 'durationSec':
        return 'duration_sec $d';
    }
    return 'RANDOM()';
  }

  Variable _var(dynamic v) {
    if (v is bool) return Variable<bool>(v);
    if (v is int) return Variable<int>(v);
    if (v is double) return Variable<double>(v);
    return Variable<String>(v.toString());
  }

  Track _rowToTrack(QueryRow r) => Track(
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
      );
}
