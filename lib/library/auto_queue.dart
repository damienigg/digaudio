import 'dart:async';

import '../audio/player.dart';
import '../core/settings.dart';
import '../domain.dart';
import '../library/local.dart';
import '../subsonic/client.dart';
import 'lastfm.dart';
import 'similarity.dart';
import 'subsonic_cache.dart';

/// Watches the audio engine and appends a similar track when the queue is
/// about to run out — same [Similarity] algorithm as the "suggest next"
/// hint in the playlists UI.
///
/// Candidate pool:
///   - all local songs (cheap; already cached by [LocalLibrary])
///   - the FULL Subsonic library, read from [SubsonicLibraryCache] (drift
///     table). If the cache for the active server is empty, falls back to
///     a 200-song random sample so behaviour degrades gracefully when the
///     user hasn't run a sync yet.
class AutoQueueService {
  final AudioEngine _engine;
  final LocalLibrary _local;
  final SubsonicClient? Function() _subsonic;
  final SubsonicLibraryCache _libraryCache;
  final SettingsStore _settings;
  final LastfmClient _lastfm;
  final int _subsonicFallbackSize;
  // Last.fm match (0..1) scaled into the same integer score space as
  // [Similarity.score]. K = 12 so a perfect match (1.0) outranks an
  // artist-only metadata hit (+10) — Last.fm's signal is stronger
  // evidence than "same artist" alone.
  static const _lastfmBoostK = 12;

  StreamSubscription<int?>? _sub;
  bool _enabled = true;
  List<Track> _subsonicPool = const [];
  String? _poolServerId;
  final Set<String> _autoAppended = {}; // avoid the same track appending twice

  AutoQueueService({
    required AudioEngine engine,
    required LocalLibrary local,
    required SubsonicClient? Function() subsonic,
    required SubsonicLibraryCache libraryCache,
    required SettingsStore settings,
    required LastfmClient lastfm,
    int subsonicFallbackSize = 200,
  })  : _engine = engine,
        _local = local,
        _subsonic = subsonic,
        _libraryCache = libraryCache,
        _settings = settings,
        _lastfm = lastfm,
        _subsonicFallbackSize = subsonicFallbackSize;

  bool get enabled => _enabled;
  set enabled(bool v) {
    _enabled = v;
    if (!v) _autoAppended.clear();
  }

  /// Starts listening. Idempotent.
  void start() {
    _sub ??= _engine.currentIndexStream.listen(_onIndexChanged);
  }

  void dispose() {
    _sub?.cancel();
    _sub = null;
  }

  /// Lookahead — keep this many tracks queued past the currently-playing
  /// one. 1 → degrades to the old "append at end" behaviour; 3 gives the
  /// engine + LockCachingAudioSource time to prefetch + warm the cache
  /// before each transition, so crossfade has audio ready.
  static const _lookahead = 3;

  Future<void> _onIndexChanged(int? i) async {
    if (!_enabled || i == null) return;
    final queue = _engine.currentQueue;
    if (queue.isEmpty) return;
    final tail = queue.length - 1 - i; // tracks remaining after current
    if (tail >= _lookahead) return;

    final needed = _lookahead - tail;
    final exclude = {...queue.map((t) => t.uniqueKey), ..._autoAppended};
    // Chain similarity off the LAST track in the queue (most recent
    // context) so each appended pick stays coherent with the trajectory
    // the user is actually moving through, not with the seed they
    // started on N tracks ago.
    var seed = queue.last;
    for (var n = 0; n < needed; n++) {
      final next = await _pickSimilar(seed, exclude);
      if (next == null) break;
      exclude.add(next.uniqueKey);
      _autoAppended.add(next.uniqueKey);
      await _engine.appendToQueue(next);
      seed = next;
    }
  }

  /// Public hook for the "suggest next" UI — same logic as auto-queue, just
  /// returned to the caller instead of pushed to the engine.
  Future<Track?> suggestNext(Track seed, {Set<String> exclude = const {}}) =>
      _pickSimilar(seed, {seed.uniqueKey, ...exclude});

  Future<Track?> _pickSimilar(Track seed, Set<String> exclude) async {
    final locals = await _local.getAllSongs();
    final remotes = await _ensureSubsonicPool();
    final candidates = [...locals, ...remotes];

    // Optional Last.fm boost. Empty map when the key isn't baked in or the
    // call fails — the loop below collapses to pure metadata in that case.
    final boost = await _lastfm.similarTracks(
      artist: seed.artist,
      track: seed.title,
    );
    if (boost.isEmpty) {
      return Similarity.pickBest(seed, candidates, exclude: exclude);
    }

    Track? best;
    var bestScore = 0;
    for (final c in candidates) {
      if (exclude.contains(c.uniqueKey) || c.uniqueKey == seed.uniqueKey) continue;
      var s = Similarity.score(seed, c);
      final k = '${(c.artist ?? '').toLowerCase()}|${c.title.toLowerCase()}';
      final match = boost[k];
      if (match != null) s += (match * _lastfmBoostK).round();
      if (s > bestScore) {
        best = c;
        bestScore = s;
      }
    }
    return best;
  }

  /// Loads the full cached library for the active server. Falls back to a
  /// random sample if the cache hasn't been built yet. Result is memoized
  /// per active server.
  Future<List<Track>> _ensureSubsonicPool() async {
    final active = await _settings.active();
    if (active == null) return const [];

    // Invalidate memoized pool when the active server changes.
    if (_poolServerId != active.id) {
      _subsonicPool = const [];
      _poolServerId = active.id;
      _autoAppended.clear();
    }
    if (_subsonicPool.isNotEmpty) return _subsonicPool;

    // 1) Full cached library, if synced.
    final cached = await _libraryCache.all(active.id);
    if (cached.isNotEmpty) {
      _subsonicPool = cached;
      return cached;
    }

    // 2) Graceful fallback: random sample (so AutoQueue isn't a no-op
    //    before the user has triggered a sync).
    final s = _subsonic();
    if (s == null) return const [];
    try {
      _subsonicPool = await s.getRandomSongs(size: _subsonicFallbackSize);
    } catch (_) {
      _subsonicPool = const [];
    }
    return _subsonicPool;
  }

  /// Force the next call to rebuild the pool from the cache — call after
  /// a manual sync completes so AutoQueue picks up the new entries.
  void invalidatePool() {
    _subsonicPool = const [];
    _autoAppended.clear();
  }
}
