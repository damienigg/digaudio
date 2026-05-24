import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:drift/drift.dart' show Value;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../core/db.dart';
import '../domain.dart';
import '../subsonic/client.dart';

/// Manages offline copies of Subsonic tracks.
///
/// Files live under <appDocs>/downloads/<trackKey>.<ext>. Presence in the
/// [Downloads] drift table is the source of truth: if the row exists and the
/// file is on disk, the engine plays the local file instead of streaming.
class DownloadsManager {
  final AppDb _db;
  final Dio _dio = Dio();
  final _progress = StreamController<Map<String, double>>.broadcast();
  final Map<String, double> _live = {};
  final Map<String, String> _cache = {}; // trackKey → file path (sync, hot)

  DownloadsManager(this._db);

  /// Populates the in-memory cache. Call once at startup.
  Future<void> hydrate() async {
    _cache
      ..clear()
      ..addAll(await loadIndex());
  }

  /// Synchronous lookup used by the audio engine.
  String? cachedPathFor(Track t) => _cache[t.uniqueKey];

  Stream<Map<String, double>> get progressStream => _progress.stream;
  Map<String, double> get currentProgress => Map.unmodifiable(_live);

  Future<Map<String, String>> loadIndex() async {
    final rows = await _db.select(_db.downloads).get();
    return {for (final r in rows) r.trackKey: r.filePath};
  }

  Future<String?> pathFor(Track t) async {
    final row = await (_db.select(_db.downloads)..where((d) => d.trackKey.equals(t.uniqueKey)))
        .getSingleOrNull();
    if (row == null) return null;
    return File(row.filePath).existsSync() ? row.filePath : null;
  }

  Future<void> download(Track t, SubsonicClient subsonic) async {
    if (t.origin != MediaOrigin.subsonic) return;
    final dir = await getApplicationDocumentsDirectory();
    final downloadsDir = Directory(p.join(dir.path, 'downloads'));
    if (!downloadsDir.existsSync()) downloadsDir.createSync(recursive: true);
    final ext = t.contentType?.split('/').last ?? 'audio';
    final file = File(p.join(downloadsDir.path, '${t.uniqueKey.replaceAll(':', '_')}.$ext'));
    final uri = subsonic.streamUri(t.id);

    _emit(t.uniqueKey, 0);
    await _dio.downloadUri(
      uri,
      file.path,
      onReceiveProgress: (rec, total) {
        if (total > 0) _emit(t.uniqueKey, rec / total);
      },
    );
    await _db.into(_db.downloads).insertOnConflictUpdate(DownloadsCompanion(
          trackKey: Value(t.uniqueKey),
          filePath: Value(file.path),
          sizeBytes: Value(file.lengthSync()),
          completedAt: Value(DateTime.now()),
        ));
    _cache[t.uniqueKey] = file.path;
    _emit(t.uniqueKey, 1);
  }

  Future<void> remove(Track t) async {
    final row = await (_db.select(_db.downloads)..where((d) => d.trackKey.equals(t.uniqueKey)))
        .getSingleOrNull();
    if (row == null) return;
    final f = File(row.filePath);
    if (f.existsSync()) f.deleteSync();
    await (_db.delete(_db.downloads)..where((d) => d.trackKey.equals(t.uniqueKey))).go();
    _cache.remove(t.uniqueKey);
    _live.remove(t.uniqueKey);
    _progress.add(currentProgress);
  }

  void _emit(String key, double v) {
    _live[key] = v;
    _progress.add(currentProgress);
  }

  Future<void> dispose() => _progress.close();
}
