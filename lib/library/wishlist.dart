import 'package:drift/drift.dart';

import '../core/db.dart';

/// Tracks/albums the user wants to land on a Subsonic server later.
///
/// Lidarr integration roadmap (deferred — not implemented in this build):
///   - Add Lidarr server config (URL + API key) in Settings.
///   - On `add(...)` here, additionally POST to Lidarr `/api/v1/album/lookup`
///     to find a release candidate, then `/api/v1/album` to add it to
///     Lidarr's monitoring list — store the returned albumId in `notes`.
///   - Periodic sync that removes wishlist items once they appear in the
///     library (via [PlaylistImporter] match logic, applied to the wish
///     list rather than an imported playlist).
class WishlistManager {
  final AppDb _db;
  WishlistManager(this._db);

  Future<int> add({required String title, String? artist, String? album, String? notes}) =>
      _db.into(_db.wishlist).insert(WishlistCompanion(
            title: Value(title),
            artist: Value(artist),
            album: Value(album),
            requestedAt: Value(DateTime.now()),
            notes: Value(notes),
          ));

  Future<void> remove(int id) =>
      (_db.delete(_db.wishlist)..where((w) => w.id.equals(id))).go();

  Stream<List<WishlistData>> watchAll() =>
      (_db.select(_db.wishlist)..orderBy([(w) => OrderingTerm.desc(w.requestedAt)])).watch();
}
