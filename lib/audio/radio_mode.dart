import 'dart:async';

import '../domain.dart';
import '../subsonic/client.dart';
import 'player.dart';

/// Endless Subsonic radio. The Subsonic `getSimilarSongs2` endpoint
/// returns up to 30 tracks similar to a seed; this service uses it
/// once at start (seed + 30) and then keeps refilling from the queue's
/// tail as the user listens through, so the radio never ends.
///
/// **Self-disengagement.** The service tracks every key it added to
/// the queue. On every track-index change, if the now-playing track
/// is **not** in that set, the user must have switched to a queue
/// from somewhere else (a playlist, an album, a smart mix). We
/// transparently stop refilling — without this guard, after the user
/// jumps to "Daft Punk Discovery" the radio would keep appending
/// stuff similar to whatever's at the tail of *that* queue, which
/// the user didn't ask for.
///
/// Re-entry: any new `startRadio(...)` call resets the tracked set
/// and is idempotent — replaces the current queue with the new seed
/// + similar.
class RadioModeService {
  final AudioEngine _engine;
  final SubsonicClient? Function() _subsonic;
  static const _bufferThreshold = 3; // refill when fewer than this remain
  static const _refillCount = 30;    // how many to ask from the server

  bool _active = false;
  bool _refilling = false;
  final Set<String> _radioKeys = {};
  StreamSubscription<int?>? _sub;

  RadioModeService(this._engine, this._subsonic);

  bool get active => _active;

  /// Seed the queue with [seed] + up to 30 similar tracks. No-op
  /// when seed isn't Subsonic-origin or the server returns nothing.
  /// On second + subsequent calls, replaces the current radio.
  Future<bool> startRadio(Track seed) async {
    if (seed.origin != MediaOrigin.subsonic) return false;
    final s = _subsonic();
    if (s == null) return false;
    final similar = await s.getSimilarSongs(seed.id, count: _refillCount);
    if (similar.isEmpty) return false;
    _radioKeys
      ..clear()
      ..add(seed.uniqueKey)
      ..addAll(similar.map((t) => t.uniqueKey));
    _active = true;
    _sub ??= _engine.currentIndexStream.listen(_onIndexChanged);
    await _engine.setQueue([seed, ...similar]);
    return true;
  }

  void stop() {
    _active = false;
    _radioKeys.clear();
  }

  Future<void> _onIndexChanged(int? i) async {
    if (!_active || i == null) return;
    final queue = _engine.currentQueue;
    if (queue.isEmpty || i < 0 || i >= queue.length) {
      stop();
      return;
    }
    // Self-disengage: user switched to a non-radio queue.
    if (!_radioKeys.contains(queue[i].uniqueKey)) {
      stop();
      return;
    }
    // Plenty of buffer left → no refill needed.
    if (queue.length - 1 - i > _bufferThreshold) return;
    if (_refilling) return;
    _refilling = true;
    try {
      final tail = queue.last;
      if (tail.origin != MediaOrigin.subsonic) return;
      final s = _subsonic();
      if (s == null) return;
      final more = await s.getSimilarSongs(tail.id, count: _refillCount);
      final excluded = queue.map((t) => t.uniqueKey).toSet();
      var appended = 0;
      for (final t in more) {
        if (excluded.contains(t.uniqueKey)) continue;
        await _engine.appendToQueue(t);
        _radioKeys.add(t.uniqueKey);
        appended++;
        if (appended >= 10) break;
      }
    } catch (_) {
      // Network hiccup — fall through; next track change retries.
    } finally {
      _refilling = false;
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }
}
