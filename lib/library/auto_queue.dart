import 'dart:async';

import '../audio/player.dart';
import '../core/settings.dart';
import '../domain.dart';
import '../library/local.dart';
import '../subsonic/client.dart';
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
  final int _subsonicFallbackSize;

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
    int subsonicFallbackSize = 200,
  })  : _engine = engine,
        _local = local,
        _subsonic = subsonic,
        _libraryCache = libraryCache,
        _settings = settings,
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

  Future<void> _onIndexChanged(int? i) async {
    if (!_enabled || i == null) return;
    final queue = _engine.currentQueue;
    if (queue.isEmpty) return;
    if (i != queue.length - 1) return;
    final seed = queue[i];
    final next = await _pickSimilar(seed, queue.map((t) => t.uniqueKey).toSet());
    if (next == null) return;
    if (!_autoAppended.add(next.uniqueKey)) return;
    await _engine.appendToQueue(next);
  }

  /// Public hook for the "suggest next" UI — same logic as auto-queue, just
  /// returned to the caller instead of pushed to the engine.
  Future<Track?> suggestNext(Track seed, {Set<String> exclude = const {}}) =>
      _pickSimilar(seed, {seed.uniqueKey, ...exclude});

  Future<Track?> _pickSimilar(Track seed, Set<String> exclude) async {
    final locals = await _local.getAllSongs();
    final remotes = await _ensureSubsonicPool();
    return Similarity.pickBest(seed, [...locals, ...remotes], exclude: exclude);
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
