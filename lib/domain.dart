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
  final String? genre;
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
    this.genre,
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

/// An item in a (local) playlist — either a resolved [Track] or a [Missing]
/// entry whose source couldn't be matched on import.
sealed class PlaylistEntry {
  const PlaylistEntry();
  String get displayTitle;
  String get displayArtist;
}

class TrackEntry extends PlaylistEntry {
  final Track track;
  const TrackEntry(this.track);
  @override
  String get displayTitle => track.title;
  @override
  String get displayArtist => track.displayArtist;
}

class MissingEntry extends PlaylistEntry {
  /// Sentinel key stored in `LocalPlaylistTracks.trackKey`, format
  /// `missing:<uuid>`. Used to look the entry back up in `MissingTracks`.
  final String key;
  final String title;
  final String? artist;
  final String? album;
  const MissingEntry({required this.key, required this.title, this.artist, this.album});
  @override
  String get displayTitle => title;
  @override
  String get displayArtist => artist ?? 'Unknown';
}
