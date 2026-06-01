import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../core/dbg.dart';
import '../domain.dart';

/// Subsonic API client.
///
/// Implements salt+token auth (Subsonic API >= 1.13.0). All responses are
/// requested as JSON via `f=json`. Endpoints used cover browsing, search,
/// streaming, cover art and lyrics. Streaming/cover URLs are returned ready to
/// hand to `just_audio` / `cached_network_image` directly — no proxy needed.
class SubsonicClient {
  static const _client = 'digaudio';
  static const _version = '1.16.1';

  /// Identifies the [ServerConfig] this client was minted from. Stamped
  /// on every parsed [Track] / [Album] / [Artist] / [Playlist] so the
  /// engine and Artwork widget can route stream / cover URIs to the
  /// originating server even when the active server has changed (e.g.
  /// during a multi-server unified search). Null only in tests that
  /// instantiate the client outside the ServerConfig path.
  final String? serverId;
  final String baseUrl;
  final String username;
  final String _password;
  final Dio _dio;

  SubsonicClient({
    required this.baseUrl,
    required this.username,
    required String password,
    this.serverId,
  })  : _password = password,
        _dio = Dio(BaseOptions(
          connectTimeout: const Duration(seconds: 10),
          receiveTimeout: const Duration(seconds: 30),
        ));

  // --- Auth ----------------------------------------------------------------

  Map<String, String> _authParams() {
    final salt = _randomSalt();
    final token = md5.convert(utf8.encode(_password + salt)).toString();
    return {
      'u': username,
      't': token,
      's': salt,
      'v': _version,
      'c': _client,
      'f': 'json',
    };
  }

  String _randomSalt() {
    final r = Random.secure();
    return List.generate(12, (_) => r.nextInt(36).toRadixString(36)).join();
  }

  Uri _url(String endpoint, [Map<String, String> extra = const {}]) {
    final base = baseUrl.endsWith('/') ? baseUrl : '$baseUrl/';
    return Uri.parse('${base}rest/$endpoint').replace(
      queryParameters: {..._authParams(), ...extra},
    );
  }

  Future<Map<String, dynamic>> _get(String endpoint, [Map<String, String> extra = const {}]) async {
    final res = await _dio.getUri(_url(endpoint, extra));
    final body = res.data is Map ? res.data as Map<String, dynamic> : jsonDecode(res.data as String);
    final root = body['subsonic-response'] as Map<String, dynamic>;
    if (root['status'] != 'ok') {
      final err = root['error'] as Map<String, dynamic>?;
      throw SubsonicException(err?['message'] as String? ?? 'Subsonic error', err?['code'] as int? ?? -1);
    }
    return root;
  }

  // --- Endpoints -----------------------------------------------------------

  Future<bool> ping() async {
    try {
      await _get('ping');
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<List<Album>> getAlbumList({String type = 'newest', int size = 30, int offset = 0}) async {
    final r = await _get('getAlbumList2', {'type': type, 'size': '$size', 'offset': '$offset'});
    final list = (r['albumList2']?['album'] as List?) ?? const [];
    return list.map((e) => _parseAlbum(e as Map<String, dynamic>)).toList();
  }

  Future<List<Track>> getRandomSongs({int size = 30}) async {
    final r = await _get('getRandomSongs', {'size': '$size'});
    final list = (r['randomSongs']?['song'] as List?) ?? const [];
    return list.map((e) => _parseSong(e as Map<String, dynamic>)).toList();
  }

  Future<List<Artist>> getArtists() async {
    final r = await _get('getArtists');
    final indices = (r['artists']?['index'] as List?) ?? const [];
    final out = <Artist>[];
    for (final idx in indices) {
      final artistsRaw = ((idx as Map<String, dynamic>)['artist'] as List?) ?? const [];
      out.addAll(artistsRaw.map((a) => _parseArtist(a as Map<String, dynamic>)));
    }
    return out;
  }

  Future<({Artist artist, List<Album> albums})> getArtist(String id) async {
    final r = await _get('getArtist', {'id': id});
    final a = r['artist'] as Map<String, dynamic>;
    final artist = _parseArtist(a);
    final albums = ((a['album'] as List?) ?? const [])
        .map((e) => _parseAlbum(e as Map<String, dynamic>))
        .toList();
    return (artist: artist, albums: albums);
  }

  Future<({Album album, List<Track> tracks})> getAlbum(String id) async {
    final r = await _get('getAlbum', {'id': id});
    final a = r['album'] as Map<String, dynamic>;
    final album = _parseAlbum(a);
    final tracks = ((a['song'] as List?) ?? const [])
        .map((e) => _parseSong(e as Map<String, dynamic>))
        .toList();
    return (album: album, tracks: tracks);
  }

  Future<SearchResults> search(String query, {
    int songCount = 20,
    int songOffset = 0,
    int albumCount = 20,
    int albumOffset = 0,
    int artistCount = 20,
    int artistOffset = 0,
  }) async {
    final r = await _get('search3', {
      'query': query,
      'songCount': '$songCount',
      if (songOffset > 0) 'songOffset': '$songOffset',
      'albumCount': '$albumCount',
      if (albumOffset > 0) 'albumOffset': '$albumOffset',
      'artistCount': '$artistCount',
      if (artistOffset > 0) 'artistOffset': '$artistOffset',
    });
    final s = r['searchResult3'] as Map<String, dynamic>? ?? const {};
    return SearchResults(
      tracks: ((s['song'] as List?) ?? const []).map((e) => _parseSong(e as Map<String, dynamic>)).toList(),
      albums: ((s['album'] as List?) ?? const []).map((e) => _parseAlbum(e as Map<String, dynamic>)).toList(),
      artists: ((s['artist'] as List?) ?? const []).map((e) => _parseArtist(e as Map<String, dynamic>)).toList(),
    );
  }

  Future<List<Playlist>> getPlaylists() async {
    final r = await _get('getPlaylists');
    final list = (r['playlists']?['playlist'] as List?) ?? const [];
    return list.map((e) => _parsePlaylist(e as Map<String, dynamic>)).toList();
  }

  Future<({Playlist playlist, List<Track> tracks})> getPlaylist(String id) async {
    final r = await _get('getPlaylist', {'id': id});
    final p = r['playlist'] as Map<String, dynamic>;
    return (
      playlist: _parsePlaylist(p),
      tracks: ((p['entry'] as List?) ?? const []).map((e) => _parseSong(e as Map<String, dynamic>)).toList(),
    );
  }

  /// Server-side similarity (the same engine Subsonic uses for its own
  /// "radio" feature). Returns up to [count] tracks that sound similar
  /// to [songId] according to the server. Empty list on any failure —
  /// callers fall back to whatever autoqueue would have picked.
  Future<List<Track>> getSimilarSongs(String songId, {int count = 30}) async {
    try {
      final r = await _get('getSimilarSongs2', {
        'id': songId,
        'count': '$count',
      });
      final list = (r['similarSongs2']?['song'] as List?) ?? const [];
      return list
          .map((e) => _parseSong(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<Track?> getSong(String id) async {
    try {
      final r = await _get('getSong', {'id': id});
      return _parseSong(r['song'] as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// 0–5 user rating. `rating: 0` clears any existing rating. Subsonic
  /// returns standard ok-response — we throw on failure so the UI can
  /// roll back the optimistic update.
  Future<void> setRating(String songId, int rating) async {
    await _get('setRating', {'id': songId, 'rating': '${rating.clamp(0, 5)}'});
  }

  /// Subsonic scrobble. `submission=false` ⇒ "now playing" hint sent at
  /// track start; `submission=true` ⇒ definitive scrobble fired once the
  /// played-duration threshold (Last.fm convention: ≥4 min OR ≥50% of
  /// length) is crossed. Errors are swallowed — scrobble never blocks
  /// playback.
  Future<void> scrobble(String songId, {required bool submission, DateTime? time}) async {
    try {
      await _get('scrobble', {
        'id': songId,
        'submission': submission.toString(),
        if (time != null) 'time': '${time.millisecondsSinceEpoch}',
      });
    } catch (_) {
      // Network / server hiccup — losing a scrobble is not worth interrupting.
    }
  }

  Future<String?> getLyrics({String? artist, String? title}) async {
    try {
      final r = await _get('getLyrics', {
        if (artist != null) 'artist': artist,
        if (title != null) 'title': title,
      });
      return (r['lyrics']?['value'] as String?)?.trim();
    } catch (_) {
      return null;
    }
  }

  /// OpenSubsonic extension. Returns `null` when the server doesn't
  /// implement the endpoint (typical Subsonic ≤ 1.16) or when no
  /// lyrics are stored for the track. Callers should fall back to
  /// [getLyrics] for plain-text on null. Synced lyrics carry per-line
  /// timestamps in `start` (ms); when `synced=false` the response is
  /// just per-line plain text without timing info.
  Future<SyncedLyrics?> getLyricsBySongId(String songId) async {
    try {
      final r = await _get('getLyricsBySongId', {'id': songId});
      final list = (r['lyricsList']?['structuredLyrics'] as List?) ?? const [];
      if (list.isEmpty) return null;
      final s = list.first as Map<String, dynamic>;
      final synced = s['synced'] == true;
      final lines = ((s['line'] as List?) ?? const [])
          .map((e) => e as Map<String, dynamic>)
          .map((e) => LyricsLine(
                start: Duration(milliseconds: (e['start'] as num?)?.toInt() ?? 0),
                text: (e['value'] as String?) ?? '',
              ))
          .toList();
      if (lines.isEmpty) return null;
      return SyncedLyrics(synced: synced, lines: lines);
    } catch (_) {
      return null;
    }
  }

  // --- Admin ---------------------------------------------------------------

  /// Triggers a server-side library rescan. Admin-only endpoint:
  /// non-admin users get a Subsonic error code 50 ("not authorized")
  /// which surfaces as a [SubsonicException]. Returns the same shape
  /// as [getScanStatus] (the kick-off response is the live status).
  Future<ScanStatus> startScan() async {
    final r = await _get('startScan');
    return ScanStatus._parse(r);
  }

  /// Polls the current scan state. Safe for any role (Navidrome / Gonic
  /// both let unauthenticated users see this, though we authenticate
  /// regardless).
  Future<ScanStatus> getScanStatus() async {
    final r = await _get('getScanStatus');
    return ScanStatus._parse(r);
  }

  /// Creates a public share for a single song. Returns the public URL
  /// the server hands out. Admin role usually required on Navidrome
  /// (error 50 otherwise) — caller surfaces that to the user.
  ///
  /// Server uses its configured default expiration when `expires` is
  /// null (Navidrome ≈ 30 days by default).
  Future<String> createShare(String songId, {String? description}) async {
    final r = await _get('createShare', {
      'id': songId,
      if (description != null && description.isNotEmpty)
        'description': description,
    });
    final shares = (r['shares'] as Map?)?['share'] as List?;
    if (shares == null || shares.isEmpty) {
      throw StateError('Server returned no share');
    }
    final url = (shares.first as Map)['url'] as String?;
    if (url == null || url.isEmpty) {
      throw StateError('Server returned empty share URL');
    }
    return url;
  }

  // --- URL builders (no auth side-effects beyond a fresh salt) -------------

  Uri streamUri(String songId, {int? maxBitRate, String? format}) => _url('stream', {
        'id': songId,
        if (maxBitRate != null) 'maxBitRate': '$maxBitRate',
        if (format != null) 'format': format,
      });

  Uri coverUri(String coverArtId, {int size = 512}) => _url('getCoverArt', {
        'id': coverArtId,
        'size': '$size',
      });

  // --- Parsers -------------------------------------------------------------

  /// Resolves a song's genre from either the legacy `genre` string field
  /// (Subsonic <1.10.2) or the OpenSubsonic `genres` array — recent
  /// Navidrome omits the legacy field, and forks emit `genres` as either
  /// `[{name: ...}]` or `[...]<String>`. Tolerant of malformed entries:
  /// scans the list for the first non-empty name instead of giving up on
  /// `list.first`. Returns null if nothing usable is found.
  ///
  /// When extraction fails, emits a `[digaudio.dbg]` line listing every
  /// JSON key on the song along with the raw genre / genres values —
  /// gated by the global debug flag so it doesn't spam normal users.
  /// This is how we diagnose "Library → Genres is empty after sync"
  /// reports against servers that bury the field under a non-standard
  /// name (or omit it from getAlbum entirely while keeping it in
  /// getSong).
  static String? _firstGenre(Map<String, dynamic> j) {
    final legacy = j['genre'];
    if (legacy is String && legacy.isNotEmpty) return legacy;
    final list = j['genres'];
    if (list is List) {
      for (final e in list) {
        if (e is String && e.isNotEmpty) return e;
        if (e is Map) {
          final name = e['name'];
          if (name is String && name.isNotEmpty) return name;
        }
      }
    }
    if (dbgEnabled) {
      dbg('[firstGenre] null id=${j['id']} title="${j['title']}" '
          'genre=${j['genre']} genres=${j['genres']} '
          'keys=${j.keys.toList()}');
    }
    return null;
  }

  Track _parseSong(Map<String, dynamic> j) => Track(
        id: j['id'] as String,
        title: (j['title'] as String?) ?? 'Unknown',
        artist: j['artist'] as String?,
        album: j['album'] as String?,
        albumId: j['albumId']?.toString(),
        artistId: j['artistId']?.toString(),
        duration: j['duration'] is int ? Duration(seconds: j['duration'] as int) : null,
        coverArt: j['coverArt']?.toString(),
        year: j['year'] as int?,
        trackNumber: j['track'] as int?,
        bitRate: j['bitRate'] as int?,
        contentType: j['contentType'] as String?,
        // OpenSubsonic extension: stock Subsonic ≤ 1.16 doesn't ship these.
        // Null → Now Playing falls back to codec + bit-rate only.
        samplingRate: j['samplingRate'] as int?,
        bitDepth: j['bitDepth'] as int?,
        // Subsonic <1.10.2 returns `genre` (singular string). OpenSubsonic /
        // recent Navidrome returns `genres: [{name: ...}]` instead and may
        // omit the legacy singular field — without the fallback, the
        // Library → Genres tab stayed empty post-sync.
        genre: _firstGenre(j),
        userRating: (j['userRating'] as num?)?.toInt(),
        // OpenSubsonic extension — newer servers expose Replay Gain.
        // Falls through to null on stock Subsonic ≤ 1.16 → engine
        // silently leaves volume at 1.0 for that track.
        replayGainTrackDb:
            ((j['replayGain'] as Map?)?['trackGain'] as num?)?.toDouble(),
        replayGainAlbumDb:
            ((j['replayGain'] as Map?)?['albumGain'] as num?)?.toDouble(),
        origin: MediaOrigin.subsonic,
        serverId: serverId,
      );

  Album _parseAlbum(Map<String, dynamic> j) => Album(
        id: j['id'] as String,
        title: (j['name'] ?? j['title'] ?? 'Unknown') as String,
        artist: j['artist'] as String?,
        artistId: j['artistId']?.toString(),
        year: j['year'] as int?,
        songCount: j['songCount'] as int?,
        duration: j['duration'] is int ? Duration(seconds: j['duration'] as int) : null,
        coverArt: j['coverArt']?.toString(),
        origin: MediaOrigin.subsonic,
        serverId: serverId,
      );

  Artist _parseArtist(Map<String, dynamic> j) => Artist(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? 'Unknown',
        albumCount: j['albumCount'] as int?,
        coverArt: j['coverArt']?.toString(),
        origin: MediaOrigin.subsonic,
        serverId: serverId,
      );

  Playlist _parsePlaylist(Map<String, dynamic> j) => Playlist(
        id: j['id'].toString(),
        name: (j['name'] as String?) ?? 'Playlist',
        songCount: j['songCount'] as int?,
        duration: j['duration'] is int ? Duration(seconds: j['duration'] as int) : null,
        coverArt: j['coverArt']?.toString(),
        owner: j['owner'] as String?,
        origin: MediaOrigin.subsonic,
        serverId: serverId,
      );
}

/// OpenSubsonic lyrics payload — either timestamped (synced=true) or
/// plain per-line text (synced=false). Renderer in the Now Playing
/// Lyrics tab branches on [synced].
class SyncedLyrics {
  final bool synced;
  final List<LyricsLine> lines;
  SyncedLyrics({required this.synced, required this.lines});
}

class LyricsLine {
  /// Offset from track start. Zero for unsynced lines.
  final Duration start;
  final String text;
  LyricsLine({required this.start, required this.text});
}

/// Multi-server router. Holds every configured [SubsonicClient] keyed by
/// the originating [ServerConfig.id], plus a pointer to the currently-active
/// one. Engine / Artwork / search call [forTrack] / [forId] so a track from
/// server B keeps streaming from B even when the user has switched the
/// active server to A. Built fresh from `serversProvider` on every
/// invalidation — cheap (just a Map<String,SubsonicClient> indexed by id).
class SubsonicResolver {
  final SubsonicClient? active;
  final Map<String, SubsonicClient> _byId;
  const SubsonicResolver({required this.active, required Map<String, SubsonicClient> byId})
      : _byId = byId;

  Iterable<SubsonicClient> get all => _byId.values;

  /// Falls back to [active] when [id] is null (legacy data minted before
  /// v0.27.0) or when the named server is no longer configured (e.g. the
  /// user removed it). Returning the active client there is best-effort —
  /// the stream will 404 if the id space differs, but that's strictly
  /// better than throwing.
  SubsonicClient? forId(String? id) => id == null ? active : (_byId[id] ?? active);

  SubsonicClient? forTrack(Track t) =>
      t.origin == MediaOrigin.subsonic ? forId(t.serverId) : null;
}

/// Subsonic `scanStatus` payload — returned by both `startScan` and
/// `getScanStatus`. [scanning] is true while a scan is in flight;
/// [count] grows during the scan, then stays as the final indexed
/// song count once it settles.
class ScanStatus {
  final bool scanning;
  final int count;
  const ScanStatus({required this.scanning, required this.count});

  static ScanStatus _parse(Map<String, dynamic> r) {
    final s = r['scanStatus'] as Map<String, dynamic>? ?? const {};
    return ScanStatus(
      scanning: (s['scanning'] as bool?) ?? false,
      count: (s['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class SubsonicException implements Exception {
  final String message;
  final int code;
  SubsonicException(this.message, this.code);
  @override
  String toString() => 'SubsonicException($code): $message';
}
