import 'dart:async';

import '../domain.dart';
import '../subsonic/client.dart';
import 'subsonic_cache.dart';

/// 5-star user ratings, Subsonic-side. The track payload carries
/// `userRating` from the server; this manager owns the in-flight
/// override map and (on successful writes) propagates the new value
/// to the local SubsonicLibraryCache so Library → Rated and smart-
/// playlist rating filters stay live without a re-sync.
///
/// Read: override → cache → t.userRating, in that order. Write:
/// optimistic local update + network call; on success, persist to
/// cache; on failure, roll the override back and re-emit so the UI
/// snaps to truth.
class RatingsManager {
  final SubsonicClient? Function() _client;
  final SubsonicLibraryCache? _cache;
  final Map<String, int> _overrides = {};
  final _changes = StreamController<void>.broadcast();

  RatingsManager(this._client, {SubsonicLibraryCache? cache}) : _cache = cache;

  Stream<void> get changes => _changes.stream;

  /// 0 = unrated (or local origin). Local tracks always 0 — the Subsonic
  /// rating endpoint doesn't apply.
  int ratingOf(Track t) {
    if (t.origin != MediaOrigin.subsonic) return 0;
    return _overrides[t.uniqueKey] ?? t.userRating ?? 0;
  }

  Future<void> setRating(Track t, int rating) async {
    if (t.origin != MediaOrigin.subsonic) return;
    final c = _client();
    if (c == null) return;
    final prev = ratingOf(t);
    _overrides[t.uniqueKey] = rating;
    _changes.add(null);
    try {
      await c.setRating(t.id, rating);
      // Persist to the local cache so Library → Rated + smart playlists
      // see the new rating without waiting for the next library sync.
      final sid = t.serverId;
      if (_cache != null && sid != null) {
        await _cache.updateRating(sid, t.id, rating);
      }
    } catch (_) {
      // Roll back the optimistic update.
      _overrides[t.uniqueKey] = prev;
      _changes.add(null);
      rethrow;
    }
  }

  Future<void> dispose() => _changes.close();
}
