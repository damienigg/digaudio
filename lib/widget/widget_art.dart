import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../domain.dart';
import '../subsonic/client.dart';

/// One-shot artwork pre-fetcher for the homescreen widget and lockscreen
/// notification.
///
/// RemoteViews can't load a network image — `setImageViewBitmap` needs a
/// decoded Bitmap. Same constraint applies to MediaItem.artUri served as
/// a file:// URL: Android's MediaSession caches the decoded bitmap **by
/// URI string**, so if we kept writing to a single `widget_art.jpg` the
/// lockscreen would freeze on the first track's artwork (URI never
/// changes → cached bitmap survives every overwrite). Per-track
/// filenames force a fresh URI on every track change so the cache key
/// flips and MediaSession reloads.
///
/// Local-only tracks are skipped (consistent with the existing
/// MediaItem `artUri` behaviour on lockscreen / notification — same
/// hidden cost would surface here, deferred to a v3).
class WidgetArtFetcher {
  static const _prefix = 'widget_art_';
  static const _suffix = '.jpg';
  static const _keepLatest = 16;
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
    responseType: ResponseType.bytes,
  ));

  /// Returns the absolute path of the downloaded artwork, or null when
  /// the track has no cover / origin isn't Subsonic / the network call
  /// failed. The filename is keyed by [Track.uniqueKey] (sanitised to a
  /// filesystem-safe form), so every track gets its own file → distinct
  /// `Uri.file()` → MediaSession can't reuse a stale cached bitmap.
  /// After writing, prunes the oldest files past [_keepLatest] so the
  /// tmp dir doesn't grow without bound.
  static Future<String?> fetch(Track t, SubsonicClient? client) async {
    if (client == null) return null;
    if (t.origin != MediaOrigin.subsonic) return null;
    if (t.coverArt == null) return null;
    try {
      final dir = await getTemporaryDirectory();
      final safeId = t.uniqueKey.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
      final path = '${dir.path}/$_prefix$safeId$_suffix';
      final url = client.coverUri(t.coverArt!, size: 256).toString();
      final res = await _dio.get<List<int>>(url);
      final bytes = res.data;
      if (bytes == null || bytes.isEmpty) return null;
      await File(path).writeAsBytes(bytes, flush: true);
      unawaited(_prune(dir));
      return path;
    } catch (_) {
      return null;
    }
  }

  /// Best-effort LRU cap on the tmp dir. Lists every `widget_art_*.jpg`
  /// we wrote, sorts by mtime desc, deletes anything past [_keepLatest].
  /// Errors are swallowed — pruning failure must never break playback.
  static Future<void> _prune(Directory dir) async {
    try {
      final files = await dir
          .list()
          .where((e) =>
              e is File &&
              e.path.contains('/$_prefix') &&
              e.path.endsWith(_suffix))
          .cast<File>()
          .toList();
      if (files.length <= _keepLatest) return;
      files.sort((a, b) =>
          b.statSync().modified.compareTo(a.statSync().modified));
      for (final f in files.skip(_keepLatest)) {
        try {
          await f.delete();
        } catch (_) {/* ignore */}
      }
    } catch (_) {/* ignore */}
  }
}
