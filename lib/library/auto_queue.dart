import 'dart:async';

import '../audio/player.dart';
import '../domain.dart';
import '../library/local.dart';
import '../subsonic/client.dart';
import 'similarity.dart';

/// Watches the audio engine and appends a similar track when the queue is
/// about to run out — same [Similarity] algorithm as the "suggest next" hint
/// in the playlists UI.
///
/// Candidate pool:
///   - all local songs (cheap; already cached by [LocalLibrary])
///   - a sample of recent / random Subsonic songs (capped, fetched once and
///     refreshed lazily — we don't scan a 200k-track server)
class AutoQueueService {
  final AudioEngine _engine;
  final LocalLibrary _local;
  final SubsonicClient? Function() _subsonic;
  final int _subsonicSampleSize;

  StreamSubscription<int?>? _sub;
  bool _enabled = true;
  List<Track> _subsonicSample = const [];
  final Set<String> _autoAppended = {}; // avoid the same track appending twice

  AutoQueueService({
    required AudioEngine engine,
    required LocalLibrary local,
    required SubsonicClient? Function() subsonic,
    int subsonicSampleSize = 200,
  })  : _engine = engine,
        _local = local,
        _subsonic = subsonic,
        _subsonicSampleSize = subsonicSampleSize;

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
    // Trigger when we're now playing the LAST track in the queue.
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
    final remotes = await _ensureSubsonicSample();
    return Similarity.pickBest(seed, [...locals, ...remotes], exclude: exclude);
  }

  Future<List<Track>> _ensureSubsonicSample() async {
    if (_subsonicSample.isNotEmpty) return _subsonicSample;
    final s = _subsonic();
    if (s == null) return const [];
    try {
      _subsonicSample = await s.getRandomSongs(size: _subsonicSampleSize);
    } catch (_) {
      _subsonicSample = const [];
    }
    return _subsonicSample;
  }

  /// Drops the cached Subsonic sample so the next call re-fetches. Call when
  /// the active server changes or after a long playback session.
  void invalidateSubsonicSample() {
    _subsonicSample = const [];
    _autoAppended.clear();
  }
}
