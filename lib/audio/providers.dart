import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../core/db.dart';
import '../core/playback_prefs.dart';
import '../core/settings.dart';
import '../domain.dart';
import '../library/downloads.dart';
import '../library/local.dart';
import '../subsonic/client.dart';
import 'player.dart';

/// Central Riverpod wiring.
///
/// One file so collaborators see the full graph at a glance. Each provider is
/// stateless construction; lifecycle (init/dispose) happens inside the engine.

// ---- Core singletons -------------------------------------------------------

final settingsStoreProvider = Provider<SettingsStore>((_) => SettingsStore());

/// All registered Subsonic servers (built-in + user-added).
final serversProvider = FutureProvider<List<ServerConfig>>((ref) =>
    ref.watch(settingsStoreProvider).servers());

/// Active server (the one the engine streams from). Null if no server has
/// credentials yet.
final activeServerProvider = FutureProvider<ServerConfig?>((ref) async {
  // Tie this to serversProvider so invalidating the list also refreshes here.
  await ref.watch(serversProvider.future);
  return ref.watch(settingsStoreProvider).active();
});

final subsonicProvider = Provider<SubsonicClient?>((ref) =>
    ref.watch(activeServerProvider).valueOrNull?.client());

final dbProvider = Provider<AppDb>((ref) {
  final db = AppDb();
  ref.onDispose(db.close);
  return db;
});

final downloadsProvider = Provider<DownloadsManager>((ref) {
  final mgr = DownloadsManager(ref.watch(dbProvider));
  ref.onDispose(mgr.dispose);
  return mgr;
});

final localLibraryProvider = Provider<LocalLibrary>((_) => LocalLibrary());

final audioEngineProvider = Provider<AudioEngine>((ref) {
  final engine = AudioEngine(
    subsonic: () => ref.read(subsonicProvider),
    downloadPathFor: (t) => ref.read(downloadsProvider).cachedPathFor(t),
  );
  ref.onDispose(engine.dispose);
  return engine;
});

final playbackPrefsProvider = Provider<PlaybackPrefs>((_) => PlaybackPrefs());

// ---- Player streams (cheap projections for UI) -----------------------------

final playerStateProvider = StreamProvider<PlayerState>((ref) =>
    ref.watch(audioEngineProvider).playerStateStream);

final positionProvider = StreamProvider<Duration>((ref) =>
    ref.watch(audioEngineProvider).positionStream);

final durationProvider = StreamProvider<Duration?>((ref) =>
    ref.watch(audioEngineProvider).durationStream);

final currentTrackProvider = StreamProvider<Track?>((ref) =>
    ref.watch(audioEngineProvider).currentTrackStream);

final shuffleProvider = StreamProvider<bool>((ref) =>
    ref.watch(audioEngineProvider).shuffleModeStream);

final loopProvider = StreamProvider<LoopMode>((ref) =>
    ref.watch(audioEngineProvider).loopModeStream);

// ---- Browse data (lazy) ----------------------------------------------------

final newestAlbumsProvider = FutureProvider<List<Album>>((ref) async {
  final s = ref.watch(subsonicProvider);
  if (s == null) return const [];
  return s.getAlbumList(type: 'newest', size: 30);
});

final randomSongsProvider = FutureProvider<List<Track>>((ref) async {
  final s = ref.watch(subsonicProvider);
  if (s == null) return const [];
  return s.getRandomSongs(size: 30);
});

final subsonicArtistsProvider = FutureProvider<List<Artist>>((ref) async {
  final s = ref.watch(subsonicProvider);
  if (s == null) return const [];
  return s.getArtists();
});

final subsonicPlaylistsProvider = FutureProvider<List<Playlist>>((ref) async {
  final s = ref.watch(subsonicProvider);
  if (s == null) return const [];
  return s.getPlaylists();
});

final localSongsProvider = FutureProvider<List<Track>>((ref) async =>
    ref.watch(localLibraryProvider).getAllSongs());

final localAlbumsProvider = FutureProvider<List<Album>>((ref) async =>
    ref.watch(localLibraryProvider).getAllAlbums());

final localArtistsProvider = FutureProvider<List<Artist>>((ref) async =>
    ref.watch(localLibraryProvider).getAllArtists());

final searchQueryProvider = StateProvider<String>((_) => '');

final searchResultsProvider = FutureProvider<SearchResults>((ref) async {
  final q = ref.watch(searchQueryProvider).trim();
  if (q.isEmpty) return const SearchResults();
  final s = ref.watch(subsonicProvider);
  final local = ref.watch(localLibraryProvider);
  // Local search: client-side filter (MediaStore has no FTS).
  final allLocal = await local.getAllSongs();
  final lq = q.toLowerCase();
  final localTracks = allLocal.where((t) =>
      t.title.toLowerCase().contains(lq) ||
      (t.artist?.toLowerCase().contains(lq) ?? false) ||
      (t.album?.toLowerCase().contains(lq) ?? false)).take(30).toList();

  if (s == null) return SearchResults(tracks: localTracks);
  final remote = await s.search(q);
  return SearchResults(
    tracks: [...localTracks, ...remote.tracks],
    albums: remote.albums,
    artists: remote.artists,
  );
});
