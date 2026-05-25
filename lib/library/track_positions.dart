import 'package:drift/drift.dart';

import '../core/db.dart';

/// Last-known playback position per track. Engine debounces writes
/// (~5 s cadence) so this is *not* a hot table. UI never reads it
/// directly — the engine consults it when starting a track and skips
/// the seek when the saved position is too close to start/end to be
/// meaningful (the "I just played 2 s then stopped" case shouldn't
/// resume at 0:02 on the next play).
class TrackPositionsManager {
  final AppDb _db;
  TrackPositionsManager(this._db);

  /// Persist the current position. Idempotent — uses insertOrReplace.
  Future<void> save(String trackKey, Duration position) =>
      _db.into(_db.trackPositions).insertOnConflictUpdate(TrackPositionsCompanion(
            trackKey: Value(trackKey),
            positionMs: Value(position.inMilliseconds),
            updatedAt: Value(DateTime.now()),
          ));

  Future<Duration?> get(String trackKey) async {
    final row = await (_db.select(_db.trackPositions)
          ..where((p) => p.trackKey.equals(trackKey)))
        .getSingleOrNull();
    if (row == null) return null;
    return Duration(milliseconds: row.positionMs);
  }

  Future<void> clear(String trackKey) =>
      (_db.delete(_db.trackPositions)..where((p) => p.trackKey.equals(trackKey)))
          .go();
}
