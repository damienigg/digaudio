import 'dart:convert';
import 'dart:io';

import '../domain.dart';
import '../subsonic/client.dart';
import 'collections.dart';
import 'local.dart';

/// One parsed entry from an external playlist before matching.
class _RawEntry {
  final String title;
  final String? artist;
  final String? album;
  const _RawEntry({required this.title, this.artist, this.album});
}

/// Result of importing one entry: either matched to a known [Track] (its
/// `uniqueKey`) or recorded as missing (sentinel `missing:<uuid>` key).
/// In both cases the value is the key that ends up in the playlist.
class ImportedEntry {
  final String key;
  final bool matched;
  final String displayTitle;
  final String? displayArtist;
  const ImportedEntry({
    required this.key,
    required this.matched,
    required this.displayTitle,
    this.displayArtist,
  });
}

class ImportReport {
  final String playlistName;
  final List<ImportedEntry> entries;
  const ImportReport({required this.playlistName, required this.entries});
  int get matched => entries.where((e) => e.matched).length;
  int get missing => entries.length - matched;
}

/// Reads M3U/M3U8 and digaudio JSON playlists, resolves each entry against
/// the local library and the active Subsonic server (in that order), and
/// records unmatched rows as `missing:<uuid>` placeholders so they render
/// as greyed-out tiles in the playlist UI.
class PlaylistImporter {
  final LocalLibrary local;
  final SubsonicClient? Function() subsonic;
  final LocalPlaylistsManager playlists;
  PlaylistImporter({
    required this.local,
    required this.subsonic,
    required this.playlists,
  });

  /// Picks the right parser by content / extension and imports into a new
  /// (or existing) playlist. Returns a report the UI can show as a summary.
  Future<ImportReport> importFile(File file) async {
    final raw = await file.readAsString();
    final lower = file.path.toLowerCase();
    final isJson = lower.endsWith('.json') || raw.trimLeft().startsWith('{');
    final parsed = isJson ? _parseDigaudioJson(raw, file) : _parseM3u(raw, file);

    final imported = <ImportedEntry>[];
    for (final e in parsed.entries) {
      final matchedKey = await _match(e);
      if (matchedKey != null) {
        imported.add(ImportedEntry(
          key: matchedKey,
          matched: true,
          displayTitle: e.title,
          displayArtist: e.artist,
        ));
      } else {
        final key = await playlists.recordMissing(
          title: e.title, artist: e.artist, album: e.album,
        );
        imported.add(ImportedEntry(
          key: key,
          matched: false,
          displayTitle: e.title,
          displayArtist: e.artist,
        ));
      }
    }

    final id = await playlists.create(parsed.name);
    for (final e in imported) {
      await playlists.append(id, e.key);
    }
    return ImportReport(playlistName: parsed.name, entries: imported);
  }

  // ---- Matching -----------------------------------------------------------

  Future<String?> _match(_RawEntry e) async {
    final nt = _norm(e.title);
    if (nt.isEmpty) return null;
    final na = e.artist == null ? null : _norm(e.artist!);

    // 1) Local — cheap, in-memory.
    final locals = await local.getAllSongs();
    for (final t in locals) {
      if (_norm(t.title) == nt && (na == null || _norm(t.artist ?? '') == na)) {
        return t.uniqueKey;
      }
    }

    // 2) Subsonic — one search per entry. Cap at small page; iterate in order
    //    until we find an exact normalized match (best-effort).
    final s = subsonic();
    if (s != null) {
      try {
        final q = (e.artist?.isNotEmpty ?? false) ? '${e.title} ${e.artist}' : e.title;
        final res = await s.search(q, songCount: 15, albumCount: 0, artistCount: 0);
        for (final t in res.tracks) {
          if (_norm(t.title) == nt && (na == null || _norm(t.artist ?? '') == na)) {
            return t.uniqueKey;
          }
        }
      } catch (_) {
        // Network / auth errors fall through — entry will land as missing.
      }
    }

    return null;
  }

  /// Lowercase, strip diacritics (best-effort ASCII fold), strip leading/
  /// trailing whitespace and surrounding punctuation. Conservative enough
  /// that "Café del Mar" and "cafe del mar" collide.
  static String _norm(String s) {
    var t = s.toLowerCase().trim();
    const diacritics =
        'àáâãäåāăąèéêëēĕėęěìíîïĩīĭįòóôõöøōŏőùúûüũūŭůűųñçćĉċčðśŝşšżźžýÿ';
    const replacements =
        'aaaaaaaaaeeeeeeeeeiiiiiiiiooooooooouuuuuuuuuncccccdsssszzzyy';
    final sb = StringBuffer();
    for (final c in t.runes) {
      final i = diacritics.indexOf(String.fromCharCode(c));
      sb.write(i >= 0 ? replacements[i] : String.fromCharCode(c));
    }
    return sb.toString().replaceAll(RegExp(r'[^\w\s]'), '').replaceAll(RegExp(r'\s+'), ' ');
  }

  // ---- Parsers ------------------------------------------------------------

  static ({String name, List<_RawEntry> entries}) _parseM3u(String raw, File file) {
    final entries = <_RawEntry>[];
    String? pendingTitle;
    String? pendingArtist;
    for (final line in const LineSplitter().convert(raw)) {
      final l = line.trim();
      if (l.isEmpty) continue;
      if (l.startsWith('#EXTINF')) {
        // #EXTINF:duration,Artist - Title
        final comma = l.indexOf(',');
        if (comma > 0) {
          final meta = l.substring(comma + 1).trim();
          final dash = meta.indexOf(' - ');
          if (dash > 0) {
            pendingArtist = meta.substring(0, dash).trim();
            pendingTitle = meta.substring(dash + 3).trim();
          } else {
            pendingTitle = meta;
          }
        }
        continue;
      }
      if (l.startsWith('#')) continue;
      // Treat the line as the track reference — title fallback to filename.
      final title = pendingTitle ?? _basenameNoExt(l);
      entries.add(_RawEntry(title: title, artist: pendingArtist));
      pendingTitle = null;
      pendingArtist = null;
    }
    return (name: _basenameNoExt(file.path), entries: entries);
  }

  static ({String name, List<_RawEntry> entries}) _parseDigaudioJson(String raw, File file) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    final name = (j['name'] as String?) ?? _basenameNoExt(file.path);
    final tracks = (j['tracks'] as List?) ?? const [];
    final entries = <_RawEntry>[];
    for (final t in tracks) {
      final m = t as Map<String, dynamic>;
      entries.add(_RawEntry(
        title: (m['title'] as String?) ?? '?',
        artist: m['artist'] as String?,
        album: m['album'] as String?,
      ));
    }
    return (name: name, entries: entries);
  }

  static String _basenameNoExt(String path) {
    final slash = path.lastIndexOf('/');
    final base = slash >= 0 ? path.substring(slash + 1) : path;
    final dot = base.lastIndexOf('.');
    return dot > 0 ? base.substring(0, dot) : base;
  }
}
