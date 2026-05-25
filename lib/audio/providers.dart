import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../core/db.dart';
import '../core/playback_prefs.dart';
import '../core/settings.dart';
import '../domain.dart';
import '../library/auto_queue.dart';
import '../library/collections.dart';
import '../library/downloads.dart';
import '../library/importer.dart';
import '../library/local.dart';
import '../library/subsonic_cache.dart';
import '../library/wishlist.dart';
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

final playbackPrefsProvider = Provider<PlaybackPrefs>((_) => PlaybackPrefs());

final audioEngineProvider = Provider<AudioEngine>((ref) {
  final engine = AudioEngine(
    subsonic: () => ref.read(subsonicProvider),
    cache: ref.watch(downloadsProvider),
    prefs: ref.watch(playbackPrefsProvider),
  );
  ref.onDispose(engine.dispose);
  return engine;
});

final favoritesProvider = Provider<FavoritesManager>((ref) =>
    FavoritesManager(ref.watch(dbProvider)));

final playlistsProvider = Provider<LocalPlaylistsManager>((ref) =>
    LocalPlaylistsManager(ref.watch(dbProvider)));

final trackResolverProvider = Provider<TrackResolver>((ref) => TrackResolver(
      local: ref.watch(localLibraryProvider),
      subsonic: () => ref.read(subsonicProvider),
      playlists: ref.watch(playlistsProvider),
    ));

final subsonicCacheProvider = Provider<SubsonicLibraryCache>((ref) =>
    SubsonicLibraryCache(ref.watch(dbProvider)));

final autoQueueProvider = Provider<AutoQueueService>((ref) {
  final svc = AutoQueueService(
    engine: ref.watch(audioEngineProvider),
    local: ref.watch(localLibraryProvider),
    subsonic: () => ref.read(subsonicProvider),
    libraryCache: ref.watch(subsonicCacheProvider),
    settings: ref.watch(settingsStoreProvider),
  );
  ref.onDispose(svc.dispose);
  return svc;
});

/// Stream of favorite track keys (drift-watched). UI uses this to render
/// the heart toggle reactively.
final favoriteKeysProvider = StreamProvider<List<String>>((ref) =>
    ref.watch(favoritesProvider).watchKeys());

/// Drift-watched map `trackKey → pinned?`. Absent key = not cached. Powers
/// the badge on track tiles and the dynamic label in the actions sheet.
final cacheStateProvider = StreamProvider<Map<String, bool>>((ref) =>
    ref.watch(downloadsProvider).cacheStateStream());

/// Stream of all local playlists.
final localPlaylistsProvider = StreamProvider<List<LocalPlaylist>>((ref) =>
    ref.watch(playlistsProvider).watchAll());

/// Single playlist by id (one-shot read; rebuilds when invalidated).
final playlistByIdProvider = FutureProvider.family<LocalPlaylist?, int>((ref, id) =>
    ref.watch(playlistsProvider).get(id));

/// Live track keys for a given playlist (drift-watched).
final playlistKeysProvider = StreamProvider.family<List<String>, int>((ref, id) =>
    ref.watch(playlistsProvider).watchTrackKeys(id));

final wishlistManagerProvider = Provider<WishlistManager>((ref) =>
    WishlistManager(ref.watch(dbProvider)));

final wishlistProvider = StreamProvider<List<WishlistData>>((ref) =>
    ref.watch(wishlistManagerProvider).watchAll());

final playlistImporterProvider = Provider<PlaylistImporter>((ref) => PlaylistImporter(
      local: ref.watch(localLibraryProvider),
      subsonic: () => ref.read(subsonicProvider),
      playlists: ref.watch(playlistsProvider),
    ));

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
