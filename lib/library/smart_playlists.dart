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

    // Alias `s` lets v2 join-based fields reference the outer row
    // unambiguously (`s.song_id`) from inside subqueries.
    final sql = 'SELECT s.* FROM cached_subsonic_songs s '
        'WHERE s.server_id = ? $filterClause '
        'ORDER BY $orderClause LIMIT ${limit.clamp(1, 1000)}';

    final rows = await _db
        .customSelect(sql,
            variables: vars,
            readsFrom: {
              _db.cachedSubsonicSongs,
              _db.favorites,
              _db.downloads,
              _db.recentPlays,
            })
        .get();
    return rows.map(_rowToTrack).toList();
  }

  /// Returns null when the rule is malformed or the field/op is unknown
  /// — silently drops so a single bad rule doesn't tank the whole query.
  ///
  /// Three field families:
  ///   1. Plain columns (v1): genre / year / artist / album / title /
  ///      durationSec → compared via the usual operators.
  ///   2. Boolean join fields (v2): favourite / pinned / cached → only
  ///      `eq` makes sense; rendered as EXISTS / NOT EXISTS.
  ///   3. Computed int fields (v2): playCount30d / playCountAll /
  ///      lastPlayedDaysAgo → subquery returns an int; standard int
  ///      comparators apply.
  String? _ruleToSql(Map<String, dynamic> rule, List<Variable> vars) {
    final field = rule['field'] as String?;
    final op = rule['op'] as String?;
    final value = rule['value'];
    if (field == null || op == null) return null;

    // ── Family 2: boolean join fields ────────────────────────────────
    if (field == 'favourite' || field == 'pinned' || field == 'cached') {
      if (op != 'eq') return null;
      final wantTrue = value == true || value == 1 || value == 'true';
      final inner = switch (field) {
        'favourite' =>
          "SELECT 1 FROM favorites f "
              "WHERE f.track_key = 'subsonic:' || s.song_id",
        'pinned' =>
          "SELECT 1 FROM downloads d "
              "WHERE d.track_key = 'subsonic:' || s.song_id AND d.pinned = 1",
        'cached' =>
          "SELECT 1 FROM downloads d "
              "WHERE d.track_key = 'subsonic:' || s.song_id",
        _ => null,
      };
      if (inner == null) return null;
      return wantTrue ? 'EXISTS ($inner)' : 'NOT EXISTS ($inner)';
    }

    // ── Family 3: computed int from joins ────────────────────────────
    final intLhs = _intExpr(field, vars);
    if (intLhs != null) return _intOp(intLhs, op, value, vars);

    // ── Family 1: plain columns (v1 behaviour) ───────────────────────
    final col = _fieldToColumn(field);
    if (col == null) return null;
    return _columnOp(col, op, value, vars);
  }

  /// Generates the LHS expression for one of the v2 computed int
  /// fields. `playCount30d` adds a `played_at >= ?` variable; the
  /// others don't bind extra vars.
  String? _intExpr(String field, List<Variable> vars) {
    switch (field) {
      case 'playCount30d':
        final cutoff = DateTime.now().subtract(const Duration(days: 30));
        vars.add(Variable<int>(cutoff.millisecondsSinceEpoch ~/ 1000));
        return "(SELECT COUNT(*) FROM recent_plays rp "
            "WHERE rp.track_key = 'subsonic:' || s.song_id "
            "AND rp.played_at >= ?)";
      case 'playCountAll':
        return "(SELECT COUNT(*) FROM recent_plays rp "
            "WHERE rp.track_key = 'subsonic:' || s.song_id)";
      case 'lastPlayedDaysAgo':
        // (now − last_play_epoch_seconds) / 86_400, falling back to
        // a huge number when the track was never played so "≥ 90"
        // matches dormant tracks instead of accidentally selecting
        // never-played ones (treats them as "infinitely dormant").
        return "((strftime('%s', 'now') - "
            "COALESCE((SELECT MAX(rp.played_at) FROM recent_plays rp "
            "WHERE rp.track_key = 'subsonic:' || s.song_id), 0)) / 86400)";
    }
    return null;
  }

  /// Standard comparator generator for an integer LHS (column or
  /// subquery). `contains` is intentionally skipped — meaningless on
  /// ints.
  String? _intOp(String lhs, String op, dynamic value, List<Variable> vars) {
    switch (op) {
      case 'eq':
        vars.add(Variable<int>((value as num).toInt()));
        return '$lhs = ?';
      case 'neq':
        vars.add(Variable<int>((value as num).toInt()));
        return '$lhs != ?';
      case 'gt':
        vars.add(Variable<int>((value as num).toInt()));
        return '$lhs > ?';
      case 'gte':
        vars.add(Variable<int>((value as num).toInt()));
        return '$lhs >= ?';
      case 'lt':
        vars.add(Variable<int>((value as num).toInt()));
        return '$lhs < ?';
      case 'lte':
        vars.add(Variable<int>((value as num).toInt()));
        return '$lhs <= ?';
      case 'between':
        if (value is! List || value.length != 2) return null;
        vars.add(Variable<int>((value[0] as num).toInt()));
        vars.add(Variable<int>((value[1] as num).toInt()));
        return '$lhs BETWEEN ? AND ?';
    }
    return null;
  }

  /// Column comparator generator — preserves the original v1 behaviour
  /// (handles eq / neq / gt / gte / lt / lte / between / contains).
  String? _columnOp(String col, String op, dynamic value, List<Variable> vars) {
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
        return 's.genre';
      case 'year':
        return 's.year';
      case 'artist':
        return 's.artist';
      case 'album':
        return 's.album';
      case 'durationSec':
        return 's.duration_sec';
      case 'title':
        return 's.title';
    }
    return null;
  }

  String _orderClause(String orderBy, String dir) {
    final d = (dir == 'asc') ? 'ASC' : 'DESC';
    switch (orderBy) {
      case 'random':
        return 'RANDOM()';
      case 'year':
        return 's.year $d';
      case 'title':
        return 's.title $d';
      case 'artist':
        return 's.artist $d';
      case 'durationSec':
        return 's.duration_sec $d';
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
