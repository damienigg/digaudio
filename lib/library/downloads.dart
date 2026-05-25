import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value, OrderingTerm;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/db.dart';
import '../domain.dart';
import '../subsonic/client.dart';

/// On-disk media pool — unified for explicit downloads (pinned, never evicted)
/// and play-through auto-cache (LRU-evictable). Files live at
/// `<appDocs>/downloads/<trackKey>.<ext>`. The [Downloads] drift table is the
/// source of truth: a row + a real file on disk = the engine can play it
/// offline. `pinned` distinguishes the two roles.
class DownloadsManager {
  final AppDb _db;
  final Dio _dio = Dio();
  final _progress = StreamController<Map<String, double>>.broadcast();
  final Map<String, double> _live = {};
  final Map<String, String> _paths = {}; // trackKey → file path (sync, hot)
  final Set<String> _pinned = {};
  String _dir = '';

  DownloadsManager(this._db);

  /// Populates in-memory caches + resolves the on-disk directory. Call once
  /// at startup; without it [cachedPathFor] / [targetFileFor] return nothing.
  Future<void> hydrate() async {
    _dir = p.join((await getApplicationDocumentsDirectory()).path, 'downloads');
    Directory(_dir).createSync(recursive: true);
    final rows = await _db.select(_db.downloads).get();
    _paths
      ..clear()
      ..addEntries(rows.map((r) => MapEntry(r.trackKey, r.filePath)));
    _pinned
      ..clear()
      ..addAll(rows.where((r) => r.pinned).map((r) => r.trackKey));
  }

  /// Sync lookup used by the audio engine when building a source.
  String? cachedPathFor(Track t) => _paths[t.uniqueKey];

  bool isPinned(Track t) => _pinned.contains(t.uniqueKey);

  /// Where a future cache file for [t] *would* live. Sync (relies on
  /// [hydrate] having been called); fed to `LockCachingAudioSource` so the
  /// engine and the manager agree on a single canonical location.
  File targetFileFor(Track t) {
    final ext = t.contentType?.split('/').last ?? 'audio';
    return File(p.join(_dir, '${t.uniqueKey.replaceAll(':', '_')}.$ext'));
  }

  Stream<Map<String, double>> get progressStream => _progress.stream;
  Map<String, double> get currentProgress => Map.unmodifiable(_live);

  /// Drift-watched stream: `trackKey → pinned?`. Absent key = not cached.
  /// UI uses this for the download/cache badge on track tiles.
  Stream<Map<String, bool>> cacheStateStream() => _db.select(_db.downloads).watch().map(
      (rows) => {for (final r in rows) r.trackKey: r.pinned});

  /// Explicit user download — fetches the whole file synchronously, pins it.
  Future<void> download(Track t, SubsonicClient subsonic) async {
    if (t.origin != MediaOrigin.subsonic) return;
    final file = targetFileFor(t);
    _emit(t.uniqueKey, 0);
    await _dio.downloadUri(
      subsonic.streamUri(t.id),
      file.path,
      onReceiveProgress: (rec, total) {
        if (total > 0) _emit(t.uniqueKey, rec / total);
      },
    );
    await _writeRow(t, file, pinned: true);
    _emit(t.uniqueKey, 1);
  }

  /// Promote an already-cached row to pinned (keeps the file, never evicts).
  Future<void> pin(Track t) async {
    await (_db.update(_db.downloads)..where((d) => d.trackKey.equals(t.uniqueKey)))
        .write(const DownloadsCompanion(pinned: Value(true)));
    _pinned.add(t.uniqueKey);
  }

  /// Demote a pinned row to plain cache (becomes LRU-evictable, file stays).
  Future<void> unpin(Track t) async {
    await (_db.update(_db.downloads)..where((d) => d.trackKey.equals(t.uniqueKey)))
        .write(const DownloadsCompanion(pinned: Value(false)));
    _pinned.remove(t.uniqueKey);
  }

  /// Registers a freshly-completed auto-cache write. Idempotent — safe to
  /// call from every `downloadProgressStream` 1.0 emission. If the row is
  /// already pinned, the pin survives (we only refresh size + LRU).
  Future<void> registerAutoCached(Track t, File file) async {
    if (!file.existsSync()) return;
    if (_pinned.contains(t.uniqueKey)) {
      await (_db.update(_db.downloads)..where((d) => d.trackKey.equals(t.uniqueKey)))
          .write(DownloadsCompanion(
            filePath: Value(file.path),
            sizeBytes: Value(file.lengthSync()),
            lastAccessedAt: Value(DateTime.now()),
          ));
      _paths[t.uniqueKey] = file.path;
      return;
    }
    await _writeRow(t, file, pinned: false);
  }

  /// Updates LRU access time. Called on every play start.
  Future<void> touch(String trackKey) async {
    if (!_paths.containsKey(trackKey)) return;
    await (_db.update(_db.downloads)..where((d) => d.trackKey.equals(trackKey)))
        .write(DownloadsCompanion(lastAccessedAt: Value(DateTime.now())));
  }

  /// Deletes the cache file + row. Works for pinned and non-pinned alike —
  /// this is the user-facing "Remove download" action.
  Future<void> remove(Track t) async {
    final row = await (_db.select(_db.downloads)..where((d) => d.trackKey.equals(t.uniqueKey)))
        .getSingleOrNull();
    if (row == null) return;
    final f = File(row.filePath);
    if (f.existsSync()) f.deleteSync();
    await (_db.delete(_db.downloads)..where((d) => d.trackKey.equals(t.uniqueKey))).go();
    _paths.remove(t.uniqueKey);
    _pinned.remove(t.uniqueKey);
    _live.remove(t.uniqueKey);
    _progress.add(currentProgress);
  }

  /// Total bytes occupied by non-pinned rows (the budget that [evictTo]
  /// controls). Pinned bytes are unbounded by user intent.
  Future<int> autoCacheBytes() async {
    final rows = await (_db.select(_db.downloads)..where((d) => d.pinned.equals(false))).get();
    return rows.fold<int>(0, (s, r) => s + r.sizeBytes);
  }

  Future<int> pinnedBytes() async {
    final rows = await (_db.select(_db.downloads)..where((d) => d.pinned.equals(true))).get();
    return rows.fold<int>(0, (s, r) => s + r.sizeBytes);
  }

  /// LRU sweep: drop oldest non-pinned rows until the auto-cache pool fits
  /// within [maxBytes]. Touched-but-never-completed partial entries (no
  /// `lastAccessedAt`) are evicted first.
  Future<void> evictTo(int maxBytes) async {
    if (maxBytes <= 0) return;
    var bytes = await autoCacheBytes();
    if (bytes <= maxBytes) return;
    final victims = await (_db.select(_db.downloads)
          ..where((d) => d.pinned.equals(false))
          ..orderBy([(d) => OrderingTerm.asc(d.lastAccessedAt)]))
        .get();
    for (final r in victims) {
      if (bytes <= maxBytes) break;
      final f = File(r.filePath);
      if (f.existsSync()) f.deleteSync();
      await (_db.delete(_db.downloads)..where((d) => d.trackKey.equals(r.trackKey))).go();
      _paths.remove(r.trackKey);
      bytes -= r.sizeBytes;
    }
  }

  /// Nukes every non-pinned row + file. Pinned downloads survive.
  Future<void> clearAuto() async {
    final rows = await (_db.select(_db.downloads)..where((d) => d.pinned.equals(false))).get();
    for (final r in rows) {
      final f = File(r.filePath);
      if (f.existsSync()) f.deleteSync();
      _paths.remove(r.trackKey);
    }
    await (_db.delete(_db.downloads)..where((d) => d.pinned.equals(false))).go();
  }

  // ---- internals -----------------------------------------------------------

  Future<void> _writeRow(Track t, File file, {required bool pinned}) async {
    await _db.into(_db.downloads).insertOnConflictUpdate(DownloadsCompanion(
          trackKey: Value(t.uniqueKey),
          filePath: Value(file.path),
          sizeBytes: Value(file.lengthSync()),
          completedAt: Value(DateTime.now()),
          lastAccessedAt: Value(DateTime.now()),
          pinned: Value(pinned),
        ));
    _paths[t.uniqueKey] = file.path;
    if (pinned) _pinned.add(t.uniqueKey);
  }

  void _emit(String key, double v) {
    _live[key] = v;
    _progress.add(currentProgress);
  }

  Future<void> dispose() => _progress.close();
}
