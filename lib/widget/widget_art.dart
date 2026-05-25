import 'dart:io';

import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';

import '../domain.dart';
import '../subsonic/client.dart';

/// One-shot artwork pre-fetcher for the homescreen widget.
///
/// RemoteViews can't load a network image — `setImageViewBitmap` needs a
/// decoded Bitmap. So we download the Subsonic cover at 256 px into a
/// single tmp file ([_fileName], overwritten each track change), then
/// hand the path to Kotlin via the WidgetChannel.
///
/// Local-only tracks are skipped (consistent with the existing
/// MediaItem `artUri` behaviour on lockscreen / notification — same
/// hidden cost would surface here, deferred to a v3).
class WidgetArtFetcher {
  static const _fileName = 'widget_art.jpg';
  static final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 30),
    responseType: ResponseType.bytes,
  ));

  /// Returns the absolute path of the downloaded artwork, or null when
  /// the track has no cover / origin isn't Subsonic / the network call
  /// failed. Always overwrites the same tmp file (single-slot cache —
  /// no eviction needed, the widget only shows one image at a time).
  static Future<String?> fetch(Track t, SubsonicClient? client) async {
    if (client == null) return null;
    if (t.origin != MediaOrigin.subsonic) return null;
    if (t.coverArt == null) return null;
    try {
      final dir = await getTemporaryDirectory();
      final path = '${dir.path}/$_fileName';
      final url = client.coverUri(t.coverArt!, size: 256).toString();
      final res = await _dio.get<List<int>>(url);
      final bytes = res.data;
      if (bytes == null || bytes.isEmpty) return null;
      await File(path).writeAsBytes(bytes, flush: true);
      return path;
    } catch (_) {
      return null;
    }
  }
}
