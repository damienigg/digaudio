import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

/// Last.fm direct scrobble + Now-Playing + 2-step browser-roundtrip auth.
///
/// Why this exists alongside Subsonic's own scrobble: Navidrome (the
/// user's Subsonic implementation) has a Last.fm integration that only
/// pulls metadata — it does NOT forward user listens to Last.fm.
/// Without this client, scrobbles never reach Last.fm even when the
/// server says it's "configured for Last.fm".
///
/// Auth flow (2 steps, classic Last.fm desktop pattern):
///   1. [requestToken] → POST `auth.getToken` (signed with api_key +
///      shared_secret). Returns a token valid 60 min, plus the URL
///      the user must open in a browser to approve.
///   2. After the user clicks "Yes, allow access" on the Last.fm site,
///      [exchangeToken] → POST `auth.getSession`. Returns the
///      session key (long-lived) + the username. Both get persisted
///      to [PlaybackPrefs]; from then on every scrobble + Now-Playing
///      call signs with that session key.
///
/// All authenticated calls follow the Last.fm signature spec:
///   - Sort params alphabetically by key (excluding `format`).
///   - Concat as `k1v1k2v2...`.
///   - Append the shared secret.
///   - MD5 → `api_sig`.
///
/// [enabled] is false when either the build-time `LASTFM_API_KEY` /
/// `LASTFM_SHARED_SECRET` are missing OR the session key isn't set.
/// Every call short-circuits to no-op in that case, so the engine
/// never breaks when Last.fm isn't configured.
class LastfmScrobbleClient {
  static const _root = 'https://ws.audioscrobbler.com/2.0/';
  static const _authBrowserRoot = 'https://www.last.fm/api/auth/';

  final String? apiKey;
  final String? sharedSecret;
  /// Live getter so the client always sees the **current** session key
  /// from [PlaybackPrefs] without the provider having to rebuild. The
  /// `PlaybackPrefs` singleton mutates in place on save — Riverpod
  /// can't tell that mutation happened, so a cached `String?` would
  /// stay empty forever after the OAuth handshake. Reading via a
  /// closure dodges the problem entirely (and `disconnect` likewise
  /// flips `enabled` back to false on the next call).
  final String? Function() sessionKey;
  final Dio _dio = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 5),
    receiveTimeout: const Duration(seconds: 10),
  ));

  LastfmScrobbleClient({
    this.apiKey,
    this.sharedSecret,
    required this.sessionKey,
  });

  /// True once we have everything needed to scrobble: build-time creds
  /// AND a session key from a completed auth handshake.
  bool get enabled {
    final sk = sessionKey();
    return _hasBuildCreds && sk != null && sk.isNotEmpty;
  }

  bool get _hasBuildCreds =>
      apiKey != null &&
      apiKey!.isNotEmpty &&
      sharedSecret != null &&
      sharedSecret!.isNotEmpty;

  /// True once the build has the API key + shared secret baked in. The
  /// auth UI uses this to decide whether to show "Connect Last.fm" at
  /// all — without these secrets, there's nothing the user can do.
  bool get configurable => _hasBuildCreds;

  // ===========================================================================
  // Step 1 — request token + browser URL
  // ===========================================================================

  /// Calls `auth.getToken` and returns `(token, browserUrl)`. The token
  /// is valid for 60 min and must be approved via [browserUrl] before
  /// [exchangeToken] will succeed. Throws on network / API error so the
  /// UI can surface a real reason to retry.
  Future<({String token, String browserUrl})> requestToken() async {
    if (!_hasBuildCreds) {
      throw StateError('Last.fm direct scrobble not built in — missing '
          'LASTFM_API_KEY or LASTFM_SHARED_SECRET dart-define.');
    }
    final params = <String, String>{
      'method': 'auth.getToken',
      'api_key': apiKey!,
    };
    final data = await _signedPost(params);
    final token = data['token'] as String?;
    if (token == null || token.isEmpty) {
      throw StateError('Last.fm returned no token: $data');
    }
    final browserUrl = Uri.parse(_authBrowserRoot).replace(queryParameters: {
      'api_key': apiKey!,
      'token': token,
    }).toString();
    return (token: token, browserUrl: browserUrl);
  }

  // ===========================================================================
  // Step 2 — exchange approved token for session key
  // ===========================================================================

  /// Calls `auth.getSession` and returns `(sessionKey, username)`.
  /// Caller persists these in [PlaybackPrefs]. Throws on 14
  /// (`Invalid auth token`) — the most useful signal is that the user
  /// hasn't clicked "Approve" in the browser yet; the UI should ask
  /// them to and retry.
  Future<({String sessionKey, String username})> exchangeToken(
      String token) async {
    if (!_hasBuildCreds) {
      throw StateError('Last.fm direct scrobble not built in — missing '
          'LASTFM_API_KEY or LASTFM_SHARED_SECRET dart-define.');
    }
    final params = <String, String>{
      'method': 'auth.getSession',
      'api_key': apiKey!,
      'token': token,
    };
    final data = await _signedPost(params);
    final session = data['session'] as Map?;
    final key = session?['key'] as String?;
    final name = session?['name'] as String?;
    if (key == null || key.isEmpty) {
      throw StateError('Last.fm returned no session key — has the user '
          'approved the token in the browser yet?');
    }
    return (sessionKey: key, username: name ?? 'last.fm user');
  }

  // ===========================================================================
  // Scrobble + Now-Playing
  // ===========================================================================

  /// Fires `track.updateNowPlaying` so the user's Last.fm profile
  /// shows what's currently spinning. No effect on the play count.
  Future<void> updateNowPlaying({
    required String track,
    required String? artist,
    String? album,
    int? durationSec,
  }) async {
    if (!enabled || artist == null || artist.isEmpty) return;
    final params = <String, String>{
      'method': 'track.updateNowPlaying',
      'track': track,
      'artist': artist,
      'api_key': apiKey!,
      'sk': sessionKey()!,
      if (album != null && album.isNotEmpty) 'album': album,
      if (durationSec != null && durationSec > 0)
        'duration': durationSec.toString(),
    };
    await _safePost(params);
  }

  /// Fires `track.scrobble` with a UNIX timestamp. Caller should fire
  /// this once per track at the Last.fm threshold (≥ 4 min OR ≥ 50 %
  /// of duration, whichever is shorter) — same trigger as the
  /// existing Subsonic + ListenBrainz scrobble paths.
  Future<void> scrobble({
    required String track,
    required String? artist,
    String? album,
    int? durationSec,
    DateTime? at,
  }) async {
    if (!enabled || artist == null || artist.isEmpty) return;
    final ts = ((at ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000).toString();
    final params = <String, String>{
      'method': 'track.scrobble',
      'track': track,
      'artist': artist,
      'timestamp': ts,
      'api_key': apiKey!,
      'sk': sessionKey()!,
      if (album != null && album.isNotEmpty) 'album': album,
      if (durationSec != null && durationSec > 0)
        'duration': durationSec.toString(),
    };
    await _safePost(params);
  }

  // ===========================================================================
  // Internals: signed POST
  // ===========================================================================

  /// `api_sig` per Last.fm spec: concat sorted `key + value` pairs,
  /// append `shared_secret`, MD5. Excludes `format` and `callback` as
  /// the spec dictates (irrelevant for the methods we call).
  String _sign(Map<String, String> params) {
    final sorted = params.keys.toList()..sort();
    final buf = StringBuffer();
    for (final k in sorted) {
      if (k == 'format' || k == 'callback') continue;
      buf
        ..write(k)
        ..write(params[k]);
    }
    buf.write(sharedSecret!);
    return md5.convert(utf8.encode(buf.toString())).toString();
  }

  /// Throws on error — used by the auth flow which wants real signals
  /// (no token / not-yet-approved). Adds api_sig + format=json.
  Future<Map<String, dynamic>> _signedPost(Map<String, String> params) async {
    final signed = Map<String, String>.from(params);
    signed['api_sig'] = _sign(signed);
    signed['format'] = 'json';
    final res = await _dio.post<dynamic>(
      _root,
      data: signed,
      options: Options(
        contentType: 'application/x-www-form-urlencoded',
      ),
    );
    final body = res.data;
    final map = body is Map<String, dynamic>
        ? body
        : jsonDecode(body as String) as Map<String, dynamic>;
    if (map.containsKey('error')) {
      throw StateError('Last.fm error ${map['error']}: ${map['message']}');
    }
    return map;
  }

  /// Swallow-and-forget variant for the scrobble path — a failed
  /// scrobble must never interrupt playback.
  Future<void> _safePost(Map<String, String> params) async {
    try {
      await _signedPost(params);
    } catch (_) {
      // intentional: scrobble best-effort.
    }
  }
}
