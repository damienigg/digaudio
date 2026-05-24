/// Unified, source-agnostic domain models for digaudio.
///
/// A [Track] / [Album] / [Artist] / [Playlist] has a stable [origin] (local
/// device vs Subsonic server). UI and the audio engine never branch on origin
/// for display logic — only the data layer (artwork URL, stream URL, etc.).
library;

enum MediaOrigin { local, subsonic }

class Track {
  final String id;
  final String title;
  final String? artist;
  final String? album;
  final String? albumId;
  final String? artistId;
  final Duration? duration;
  final String? coverArt;
  final int? year;
  final int? trackNumber;
  final int? bitRate;
  final String? contentType;
  final MediaOrigin origin;

  const Track({
    required this.id,
    required this.title,
    required this.origin,
    this.artist,
    this.album,
    this.albumId,
    this.artistId,
    this.duration,
    this.coverArt,
    this.year,
    this.trackNumber,
    this.bitRate,
    this.contentType,
  });

  /// Unique key across all origins (collision-free).
  String get uniqueKey => '${origin.name}:$id';

  String get displayArtist => artist ?? 'Unknown artist';
}

class Album {
  final String id;
  final String title;
  final String? artist;
  final String? artistId;
  final int? year;
  final int? songCount;
  final Duration? duration;
  final String? coverArt;
  final MediaOrigin origin;

  const Album({
    required this.id,
    required this.title,
    required this.origin,
    this.artist,
    this.artistId,
    this.year,
    this.songCount,
    this.duration,
    this.coverArt,
  });

  String get uniqueKey => '${origin.name}:$id';
}

class Artist {
  final String id;
  final String name;
  final int? albumCount;
  final String? coverArt;
  final MediaOrigin origin;

  const Artist({
    required this.id,
    required this.name,
    required this.origin,
    this.albumCount,
    this.coverArt,
  });

  String get uniqueKey => '${origin.name}:$id';
}

class Playlist {
  final String id;
  final String name;
  final int? songCount;
  final Duration? duration;
  final String? coverArt;
  final String? owner;
  final MediaOrigin origin;

  const Playlist({
    required this.id,
    required this.name,
    required this.origin,
    this.songCount,
    this.duration,
    this.coverArt,
    this.owner,
  });

  String get uniqueKey => '${origin.name}:$id';
}

class SearchResults {
  final List<Track> tracks;
  final List<Album> albums;
  final List<Artist> artists;
  const SearchResults({this.tracks = const [], this.albums = const [], this.artists = const []});

  bool get isEmpty => tracks.isEmpty && albums.isEmpty && artists.isEmpty;
}
