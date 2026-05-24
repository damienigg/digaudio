import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

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

  final String baseUrl;
  final String username;
  final String _password;
  final Dio _dio;

  SubsonicClient({
    required this.baseUrl,
    required this.username,
    required String password,
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

  Future<SearchResults> search(String query, {int songCount = 20, int albumCount = 20, int artistCount = 20}) async {
    final r = await _get('search3', {
      'query': query,
      'songCount': '$songCount',
      'albumCount': '$albumCount',
      'artistCount': '$artistCount',
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

  Future<Track?> getSong(String id) async {
    try {
      final r = await _get('getSong', {'id': id});
      return _parseSong(r['song'] as Map<String, dynamic>);
    } catch (_) {
      return null;
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
        genre: j['genre'] as String?,
        origin: MediaOrigin.subsonic,
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
      );

  Artist _parseArtist(Map<String, dynamic> j) => Artist(
        id: j['id'] as String,
        name: (j['name'] as String?) ?? 'Unknown',
        albumCount: j['albumCount'] as int?,
        coverArt: j['coverArt']?.toString(),
        origin: MediaOrigin.subsonic,
      );

  Playlist _parsePlaylist(Map<String, dynamic> j) => Playlist(
        id: j['id'].toString(),
        name: (j['name'] as String?) ?? 'Playlist',
        songCount: j['songCount'] as int?,
        duration: j['duration'] is int ? Duration(seconds: j['duration'] as int) : null,
        coverArt: j['coverArt']?.toString(),
        owner: j['owner'] as String?,
        origin: MediaOrigin.subsonic,
      );
}

class SubsonicException implements Exception {
  final String message;
  final int code;
  SubsonicException(this.message, this.code);
  @override
  String toString() => 'SubsonicException($code): $message';
}
