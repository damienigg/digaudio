import 'dart:convert';

import 'package:dio/dio.dart';

/// Last.fm `track.getSimilar` ranker — augments the metadata-only score
/// in [Similarity] with crowd-sourced track similarity. Key is baked at
/// build time via `--dart-define=LASTFM_API_KEY=...` (sourced from a
/// repo secret in CI). With no key, [enabled] is false and every call
/// returns an empty map — the autoqueue gracefully falls back to pure
/// metadata.
///
/// We never block on Last.fm: timeouts are aggressive (5 s connect /
/// 10 s receive) and any error swallows to an empty result. Picking the
/// next track must always succeed even if last.fm is down.
class LastfmClient {
  static const _root = 'https://ws.audioscrobbler.com/2.0/';
  final String? apiKey;
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 10),
  ));

  LastfmClient(this.apiKey);

  bool get enabled => apiKey != null && apiKey!.isNotEmpty;

  /// `"artist|track"` (both lower-cased) → match score (0..1). Empty if
  /// disabled, network failure, or seed has no artist.
  Future<Map<String, double>> similarTracks({
    required String? artist,
    required String track,
    int limit = 30,
  }) async {
    if (!enabled || artist == null || artist.isEmpty) return const {};
    try {
      final res = await _dio.getUri(Uri.parse(_root).replace(queryParameters: {
        'method': 'track.getSimilar',
        'artist': artist,
        'track': track,
        'api_key': apiKey!,
        'format': 'json',
        'limit': '$limit',
        'autocorrect': '1',
      }));
      final data = res.data is Map
          ? res.data as Map<String, dynamic>
          : jsonDecode(res.data as String) as Map<String, dynamic>;
      final list = (data['similartracks']?['track'] as List?) ?? const [];
      final out = <String, double>{};
      for (final raw in list) {
        final t = raw as Map<String, dynamic>;
        final name = (t['name'] as String?)?.trim();
        final artistName = (t['artist'] as Map?)?['name']?.toString().trim();
        final match = double.tryParse(t['match']?.toString() ?? '0') ?? 0.0;
        if (name != null && artistName != null && name.isNotEmpty) {
          out['${artistName.toLowerCase()}|${name.toLowerCase()}'] = match;
        }
      }
      return out;
    } catch (_) {
      return const {};
    }
  }
}
