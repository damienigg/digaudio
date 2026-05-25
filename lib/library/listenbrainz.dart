import 'dart:convert';

import 'package:dio/dio.dart';

/// ListenBrainz scrobble client — token-authenticated POST to
/// `submit-listens`. Two listen types:
///   - `playing_now` — fired at track start so the user's profile
///     shows what's currently spinning.
///   - `single`     — fired when the user has listened long enough
///     to count as a real listen (≥ 4 min or ≥ 50 % of the track,
///     same Last.fm threshold the existing Subsonic scrobble uses).
///
/// Errors are swallowed; a failed scrobble shouldn't interrupt
/// playback. Empty / missing token = `enabled = false`, all calls
/// no-op.
class ListenBrainzClient {
  static const _root = 'https://api.listenbrainz.org';
  final String? token;
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 10),
  ));

  ListenBrainzClient(this.token);

  bool get enabled => token != null && token!.isNotEmpty;

  Future<void> submitNowPlaying({
    required String trackName,
    required String? artistName,
    String? releaseName,
  }) async {
    if (!enabled || artistName == null || artistName.isEmpty) return;
    await _post(<String, dynamic>{
      'listen_type': 'playing_now',
      'payload': [
        {
          'track_metadata': _metadata(trackName, artistName, releaseName),
        }
      ],
    });
  }

  Future<void> submitListen({
    required String trackName,
    required String? artistName,
    String? releaseName,
    DateTime? listenedAt,
  }) async {
    if (!enabled || artistName == null || artistName.isEmpty) return;
    await _post(<String, dynamic>{
      'listen_type': 'single',
      'payload': [
        {
          'listened_at':
              (listenedAt ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000,
          'track_metadata': _metadata(trackName, artistName, releaseName),
        }
      ],
    });
  }

  Map<String, dynamic> _metadata(String track, String artist, String? release) {
    return {
      'track_name': track,
      'artist_name': artist,
      if (release != null && release.isNotEmpty) 'release_name': release,
    };
  }

  Future<void> _post(Map<String, dynamic> body) async {
    try {
      await _dio.post<dynamic>(
        '$_root/1/submit-listens',
        data: jsonEncode(body),
        options: Options(headers: {
          'Authorization': 'Token $token',
          'Content-Type': 'application/json',
        }),
      );
    } catch (_) {
      // Best-effort — a failed scrobble must never interrupt playback.
    }
  }
}
