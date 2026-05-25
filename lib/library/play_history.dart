import 'package:drift/drift.dart';

import '../core/db.dart';

/// Append-only play log + aggregation queries. Powers the Stats page and
/// the "Most played" smart mix. One row per playback (no dedup), so
/// COUNT(*) gives true play counts.
///
/// All time-windowed queries use `playedAt >= cutoff` driven by drift
/// expressions (drift handles DateTime ↔ INTEGER-seconds itself).
class PlayHistoryManager {
  final AppDb _db;
  PlayHistoryManager(this._db);

  Future<void> recordPlay(String trackKey, [DateTime? at]) async {
    await _db.into(_db.recentPlays).insert(RecentPlaysCompanion(
          trackKey: Value(trackKey),
          playedAt: Value(at ?? DateTime.now()),
        ));
  }

  Future<int> totalPlays({int? sinceDays}) async {
    final countExpr = _db.recentPlays.id.count();
    final q = _db.selectOnly(_db.recentPlays)..addColumns([countExpr]);
    final cutoff = _cutoff(sinceDays);
    if (cutoff != null) q.where(_db.recentPlays.playedAt.isBiggerOrEqualValue(cutoff));
    final r = await q.getSingle();
    return r.read(countExpr) ?? 0;
  }

  Future<int> uniqueTracks({int? sinceDays}) async {
    final countExpr = _db.recentPlays.trackKey.count(distinct: true);
    final q = _db.selectOnly(_db.recentPlays)..addColumns([countExpr]);
    final cutoff = _cutoff(sinceDays);
    if (cutoff != null) q.where(_db.recentPlays.playedAt.isBiggerOrEqualValue(cutoff));
    final r = await q.getSingle();
    return r.read(countExpr) ?? 0;
  }

  /// Distinct calendar days that had at least one play. Uses SQLite's
  /// `date(played_at, 'unixepoch')` because drift's typed expressions
  /// don't expose a day-truncate operator.
  Future<int> listeningDays({int? sinceDays}) async {
    final cutoff = _cutoff(sinceDays);
    final result = await _db.customSelect(
      cutoff == null
          ? "SELECT COUNT(DISTINCT date(played_at, 'unixepoch')) AS c FROM recent_plays"
          : "SELECT COUNT(DISTINCT date(played_at, 'unixepoch')) AS c FROM recent_plays WHERE played_at >= ?",
      variables: cutoff == null
          ? const []
          : [Variable<int>(cutoff.millisecondsSinceEpoch ~/ 1000)],
      readsFrom: {_db.recentPlays},
    ).getSingle();
    return result.read<int>('c');
  }

  /// Top trackKeys by play count. Caller resolves them to Tracks for the UI.
  Future<List<({String trackKey, int count})>> topTracks({
    int? sinceDays,
    int limit = 10,
  }) async {
    final countExpr = _db.recentPlays.id.count();
    final q = _db.selectOnly(_db.recentPlays)
      ..addColumns([_db.recentPlays.trackKey, countExpr])
      ..groupBy([_db.recentPlays.trackKey])
      ..orderBy([OrderingTerm(expression: countExpr, mode: OrderingMode.desc)])
      ..limit(limit);
    final cutoff = _cutoff(sinceDays);
    if (cutoff != null) q.where(_db.recentPlays.playedAt.isBiggerOrEqualValue(cutoff));
    final rows = await q.get();
    return rows
        .map((r) => (
              trackKey: r.read(_db.recentPlays.trackKey)!,
              count: r.read(countExpr) ?? 0,
            ))
        .toList();
  }

  /// (current, longest) consecutive-day streaks. Day boundaries follow the
  /// device's local-equivalent UTC date returned by SQLite's `date()`
  /// (Subsonic / device clocks differ; we accept that for simplicity).
  /// "current" tolerates a missed *today* — it walks back from yesterday
  /// if no play was logged today yet — so the streak doesn't visually
  /// reset at midnight before the morning's listen.
  Future<({int current, int longest})> streaks() async {
    final rows = await _db.customSelect(
      "SELECT DISTINCT date(played_at, 'unixepoch') AS d FROM recent_plays ORDER BY d ASC",
      readsFrom: {_db.recentPlays},
    ).get();
    if (rows.isEmpty) return (current: 0, longest: 0);

    final days = rows.map((r) => DateTime.parse(r.read<String>('d'))).toList();
    var longest = 1;
    var run = 1;
    for (var i = 1; i < days.length; i++) {
      if (days[i].difference(days[i - 1]).inDays == 1) {
        run++;
        if (run > longest) longest = run;
      } else {
        run = 1;
      }
    }

    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    final daySet = days.toSet();
    var current = 0;
    var cursor = daySet.contains(today) ? today : today.subtract(const Duration(days: 1));
    while (daySet.contains(cursor)) {
      current++;
      cursor = cursor.subtract(const Duration(days: 1));
    }
    return (current: current, longest: longest);
  }

  /// `date → play count` for the last [days] days. UI renders this as a
  /// heatmap row. Days with zero plays are absent from the map (the
  /// renderer defaults to 0 / white12).
  Future<Map<DateTime, int>> dailyCounts({int days = 30}) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final rows = await _db.customSelect(
      "SELECT date(played_at, 'unixepoch') AS d, COUNT(*) AS c FROM recent_plays WHERE played_at >= ? GROUP BY d",
      variables: [Variable<int>(cutoff.millisecondsSinceEpoch ~/ 1000)],
      readsFrom: {_db.recentPlays},
    ).get();
    return {for (final r in rows) DateTime.parse(r.read<String>('d')): r.read<int>('c')};
  }

  /// Most-recent N distinct trackKeys, most-recent first. Powers the
  /// Android Auto "Recently played" browsable node.
  Future<List<String>> recentUnique(int n) async {
    final rows = await _db.customSelect(
      'SELECT track_key, MAX(played_at) AS last FROM recent_plays '
      'GROUP BY track_key ORDER BY last DESC LIMIT ?',
      variables: [Variable<int>(n)],
      readsFrom: {_db.recentPlays},
    ).get();
    return rows.map((r) => r.read<String>('track_key')).toList();
  }

  /// Wipes the history (Settings → "Reset stats").
  Future<void> clear() => _db.delete(_db.recentPlays).go();

  DateTime? _cutoff(int? sinceDays) =>
      sinceDays == null ? null : DateTime.now().subtract(Duration(days: sinceDays));
}
