import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';

import '../domain.dart';

/// Local device music library — backed by our own Kotlin MethodChannel
/// (`digaudio/media_store`). Two native calls only: list songs, fetch artwork.
/// Albums and artists are derived client-side from the song list.
class LocalLibrary {
  static const _channel = MethodChannel('digaudio/media_store');

  Future<bool> requestPermission() async {
    final audio = await Permission.audio.request();
    if (audio.isGranted) return true;
    final storage = await Permission.storage.request();
    return storage.isGranted;
  }

  List<Track>? _cachedSongs;

  Future<List<Track>> getAllSongs() async {
    if (_cachedSongs != null) return _cachedSongs!;
    final raw = await _channel.invokeListMethod<Map<dynamic, dynamic>>('getAllSongs') ?? const [];
    _cachedSongs = raw.map(_mapToTrack).toList(growable: false);
    return _cachedSongs!;
  }

  /// Force the next `getAllSongs` call to re-query MediaStore.
  void invalidate() => _cachedSongs = null;

  Future<List<Album>> getAllAlbums() async {
    final songs = await getAllSongs();
    final groups = <String, List<Track>>{};
    for (final t in songs) {
      final id = t.albumId;
      if (id == null) continue;
      groups.putIfAbsent(id, () => []).add(t);
    }
    return groups.entries
        .map((e) {
          final first = e.value.first;
          return Album(
            id: e.key,
            title: first.album ?? 'Unknown album',
            artist: first.artist,
            artistId: first.artistId,
            songCount: e.value.length,
            coverArt: e.value.first.id, // any song id from the album resolves to its art
            origin: MediaOrigin.local,
          );
        })
        .toList(growable: false)
      ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
  }

  Future<List<Artist>> getAllArtists() async {
    final songs = await getAllSongs();
    final groups = <String, Set<String>>{};
    final names = <String, String>{};
    for (final t in songs) {
      final id = t.artistId;
      if (id == null) continue;
      groups.putIfAbsent(id, () => <String>{}).add(t.albumId ?? '');
      names[id] = t.artist ?? 'Unknown artist';
    }
    return groups.entries
        .map((e) => Artist(
              id: e.key,
              name: names[e.key]!,
              albumCount: e.value.where((a) => a.isNotEmpty).length,
              origin: MediaOrigin.local,
            ))
        .toList(growable: false)
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  Future<List<Track>> getSongsInAlbum(String albumId) async =>
      (await getAllSongs()).where((t) => t.albumId == albumId).toList();

  Future<List<Track>> getSongsByArtist(String artistId) async =>
      (await getAllSongs()).where((t) => t.artistId == artistId).toList();

  /// Resolves a track id (the MediaStore _ID, as a String) back to a [Track].
  Future<Track?> getSongById(String id) async {
    final all = await getAllSongs();
    for (final t in all) {
      if (t.id == id) return t;
    }
    return null;
  }

  Future<Uint8List?> getArtwork(String songId, {int size = 400}) async {
    final id = int.tryParse(songId);
    if (id == null) return null;
    return _channel.invokeMethod<Uint8List>('getArtwork', {'id': id, 'size': size});
  }

  Track _mapToTrack(Map<dynamic, dynamic> m) {
    final durationMs = (m['duration'] as num?)?.toInt() ?? 0;
    final id = (m['id'] as num).toInt().toString();
    return Track(
      id: id,
      title: (m['title'] as String?) ?? 'Unknown',
      artist: m['artist'] as String?,
      album: m['album'] as String?,
      albumId: (m['albumId'] as num?)?.toInt().toString(),
      artistId: (m['artistId'] as num?)?.toInt().toString(),
      duration: durationMs > 0 ? Duration(milliseconds: durationMs) : null,
      coverArt: id,
      trackNumber: (m['track'] as num?)?.toInt(),
      contentType: m['mime'] as String?,
      origin: MediaOrigin.local,
    );
  }
}

/// File-URI for a local Track — fed straight to just_audio.
extension LocalTrackUri on Track {
  String get localContentUri => 'content://media/external/audio/media/$id';
}
