import '../domain.dart';

/// Lightweight, metadata-only similarity score between two [Track]s.
///
/// Same algorithm is used by:
///   - the "suggest next" hint after adding a track to a playlist / favorites
///   - the auto-queue that appends a similar track when the queue is about
///     to end during playback
///
/// No external service, no audio analysis — purely based on fields we
/// already have. The score is intentionally interpretable: each matching
/// feature adds a fixed weight, and the highest-scoring candidate wins.
class Similarity {
  /// Higher = more similar. Score of 0 means "nothing in common".
  static int score(Track a, Track b) {
    if (a.uniqueKey == b.uniqueKey) return -1; // never suggest the same track
    var s = 0;
    if (_eq(a.artist, b.artist)) s += 10;
    if (_eq(a.albumId, b.albumId) || _eq(a.album, b.album)) s += 5;
    if (_eq(a.genre, b.genre)) s += 6;
    if (a.year != null && b.year != null && (a.year! - b.year!).abs() <= 5) s += 3;
    if (a.duration != null && b.duration != null) {
      final diff = (a.duration!.inSeconds - b.duration!.inSeconds).abs();
      if (diff <= 60) s += 1;
    }
    return s;
  }

  /// Best candidate by score, excluding [exclude] keys. Returns null if no
  /// candidate scores above 0.
  static Track? pickBest(
    Track seed,
    Iterable<Track> candidates, {
    Set<String> exclude = const {},
  }) {
    Track? best;
    var bestScore = 0;
    for (final c in candidates) {
      if (exclude.contains(c.uniqueKey) || c.uniqueKey == seed.uniqueKey) continue;
      final s = score(seed, c);
      if (s > bestScore) {
        best = c;
        bestScore = s;
      }
    }
    return best;
  }

  /// Top-N candidates sorted by descending score (score > 0 only).
  static List<Track> topN(
    Track seed,
    Iterable<Track> candidates,
    int n, {
    Set<String> exclude = const {},
  }) {
    final scored = <(Track, int)>[];
    for (final c in candidates) {
      if (exclude.contains(c.uniqueKey) || c.uniqueKey == seed.uniqueKey) continue;
      final s = score(seed, c);
      if (s > 0) scored.add((c, s));
    }
    scored.sort((x, y) => y.$2.compareTo(x.$2));
    return scored.take(n).map((e) => e.$1).toList();
  }

  static bool _eq(String? a, String? b) =>
      a != null && b != null && a.isNotEmpty && b.isNotEmpty && a.toLowerCase() == b.toLowerCase();
}
