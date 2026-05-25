import 'dart:async';

import '../domain.dart';
import '../subsonic/client.dart';

/// 5-star user ratings, Subsonic-side. The track payload already carries
/// `userRating` from the server, so this manager only owns the in-flight
/// overrides + change notifications — no SQLite mirror (a re-fetch of the
/// track from the server is always authoritative).
///
/// Reading: prefer the local override, fall back to whatever the track
/// payload reported when it was fetched. Writing: optimistic local update
/// followed by the network call; on failure the override is rolled back
/// and the [changes] stream re-emits so the UI snaps to the truth.
class RatingsManager {
  final SubsonicClient? Function() _client;
  final Map<String, int> _overrides = {};
  final _changes = StreamController<void>.broadcast();

  RatingsManager(this._client);

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
    } catch (_) {
      // Roll back the optimistic update.
      _overrides[t.uniqueKey] = prev;
      _changes.add(null);
      rethrow;
    }
  }

  Future<void> dispose() => _changes.close();
}
