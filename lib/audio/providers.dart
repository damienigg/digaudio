import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../core/db.dart';
import '../core/display_prefs.dart';
import '../core/playback_prefs.dart';
import '../core/settings.dart';
import '../domain.dart';
import '../library/auto_queue.dart';
import '../library/collections.dart';
import '../library/downloads.dart';
import '../library/importer.dart';
import '../library/lastfm.dart';
import '../library/local.dart';
import '../library/play_history.dart';
import '../library/ratings.dart';
import '../library/selection.dart';
import '../library/server_health.dart';
import '../library/smart_playlists.dart';
import '../library/subsonic_cache.dart';
import '../library/track_positions.dart';
import '../library/wishlist.dart';
import '../subsonic/client.dart';
import 'album_mode.dart';
import 'bt_eq.dart';
import 'player.dart';
import 'sleep_timer.dart';

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

final displayPrefsProvider = Provider<DisplayPrefs>((_) => DisplayPrefs());

/// Reactive theme mode — seeded from [DisplayPrefs] in main and updated
/// from the Display settings picker. MaterialApp.router watches this.
final themeModeProvider = StateProvider<ThemeMode>((_) => ThemeMode.dark);

/// Reactive mirror of [PlaybackPrefs.playbackSpeed]. The prefs object itself
/// is mutable and not Riverpod-watched; this StateProvider feeds the AppBar
/// speed button so the label updates instantly when the user picks a new
/// rate. Kept in sync at the one writer (Speed sheet) and at startup.
final playbackSpeedProvider = StateProvider<double>((_) => 1.0);

/// The AudioEngine is now an [AudioService] handler (Android Auto needs
/// to discover a single, process-lifetime instance via the
/// MediaBrowserService — multiple instances would race over the same
/// MediaSession). It's built once in [main] and registered through
/// [registerAudioEngine]; reading the provider before that throws.
AudioEngine? _audioEngineSingleton;

void registerAudioEngine(AudioEngine engine) {
  _audioEngineSingleton = engine;
}

final audioEngineProvider = Provider<AudioEngine>((_) {
  final e = _audioEngineSingleton;
  if (e == null) {
    throw StateError(
        'audioEngineProvider read before main() registered the handler');
  }
  return e;
});

final sleepTimerProvider = Provider<SleepTimerService>((ref) {
  final svc = SleepTimerService(ref.watch(audioEngineProvider));
  ref.onDispose(svc.dispose);
  return svc;
});

final albumModeProvider = Provider<AlbumModeService>((ref) {
  final svc = AlbumModeService(ref.watch(audioEngineProvider));
  ref.onDispose(svc.dispose);
  return svc;
});

final btEqProvider = Provider<BtEqService>((ref) {
  final svc = BtEqService(
    ref.watch(audioEngineProvider),
    () async => ref.read(playbackPrefsProvider).eqGainsDb,
  );
  ref.onDispose(svc.stop);
  return svc;
});

/// Currently-active BT device key, or null if no BT output. UI uses
/// this to surface the "save current EQ for this device" button.
final btActiveDeviceProvider = StreamProvider<String?>((ref) =>
    ref.watch(btEqProvider).activeKeyStream);

/// True iff "stop after current album" is armed.
final albumModeArmedProvider = StreamProvider<bool>((ref) =>
    ref.watch(albumModeProvider).armedStream);

/// Countdown stream — `null` whenever no duration timer is running.
final sleepRemainingProvider = StreamProvider<Duration?>((ref) =>
    ref.watch(sleepTimerProvider).remainingStream);

/// True iff the "stop at end of current track" mode is armed.
final sleepEndOfTrackProvider = StreamProvider<bool>((ref) =>
    ref.watch(sleepTimerProvider).endOfTrackActiveStream);

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

/// Last.fm client — `--dart-define=LASTFM_API_KEY=...` at build time
/// (sourced from a GitHub repo secret in CI). With no key, [enabled]
/// is false and the autoqueue silently falls back to pure metadata.
const _lastfmKey = String.fromEnvironment('LASTFM_API_KEY', defaultValue: '');
final lastfmClientProvider = Provider<LastfmClient>((_) => LastfmClient(_lastfmKey));

final autoQueueProvider = Provider<AutoQueueService>((ref) {
  final svc = AutoQueueService(
    engine: ref.watch(audioEngineProvider),
    local: ref.watch(localLibraryProvider),
    subsonic: () => ref.read(subsonicProvider),
    libraryCache: ref.watch(subsonicCacheProvider),
    settings: ref.watch(settingsStoreProvider),
    lastfm: ref.watch(lastfmClientProvider),
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

final smartPlaylistsProvider = Provider<SmartPlaylistsManager>((ref) =>
    SmartPlaylistsManager(ref.watch(dbProvider)));

/// Drift-watched list of all smart playlists, sorted by name. Used by
/// the Library → Playlists tab to render them inline.
final smartPlaylistsListProvider = StreamProvider<List<SmartPlaylist>>((ref) =>
    ref.watch(smartPlaylistsProvider).watchAll());

final playHistoryProvider = Provider<PlayHistoryManager>((ref) =>
    PlayHistoryManager(ref.watch(dbProvider)));

final trackPositionsProvider = Provider<TrackPositionsManager>((ref) =>
    TrackPositionsManager(ref.watch(dbProvider)));

/// Global multi-select state for TrackTile lists. Empty Map = no
/// selection mode; non-empty = the bulk-action bar appears in AppShell.
final selectionProvider =
    StateNotifierProvider<SelectionNotifier, Map<String, Track>>(
        (_) => SelectionNotifier());

final ratingsManagerProvider = Provider<RatingsManager>((ref) {
  final mgr = RatingsManager(() => ref.read(subsonicProvider));
  ref.onDispose(mgr.dispose);
  return mgr;
});

/// Bumps every time a rating changes — UI watches this to redraw stars
/// without re-fetching the underlying track.
final ratingsChangesProvider = StreamProvider<void>((ref) =>
    ref.watch(ratingsManagerProvider).changes);

/// Periodic Subsonic ping + reachability flag. Started once at app boot
/// (see [DigaudioApp.initState]) and lives as long as the container.
final serverHealthProvider = Provider<ServerHealthService>((ref) {
  final svc = ServerHealthService(() => ref.read(subsonicProvider));
  ref.onDispose(svc.dispose);
  return svc;
});

/// `true` = active server reachable (or no active server). UI flips a
/// banner on `false`.
final serverReachableProvider = StreamProvider<bool>((ref) =>
    ref.watch(serverHealthProvider).stream);

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

  // Local-MediaStore filter (in-memory; MediaStore has no FTS).
  final allLocal = await local.getAllSongs();
  final lq = q.toLowerCase();
  final localTracks = allLocal.where((t) =>
      t.title.toLowerCase().contains(lq) ||
      (t.artist?.toLowerCase().contains(lq) ?? false) ||
      (t.album?.toLowerCase().contains(lq) ?? false)).take(30).toList();

  if (s == null) return SearchResults(tracks: localTracks);

  // Two parallel queries:
  //   - FTS5 against the cached Subsonic library → instant, runs even
  //     when offline, covers everything synced.
  //   - Subsonic search3 against the live server → catches anything
  //     added server-side since the last cache sync.
  // Merged + deduped by uniqueKey, FTS hits first (instant feels
  // primary), remote-only hits appended.
  final active = await ref.watch(settingsStoreProvider).active();
  final ftsFuture = active == null
      ? Future.value(const <Track>[])
      : ref.read(subsonicCacheProvider).searchFts(active.id, q, limit: 30);
  // Remote can fail (offline mode etc.) — fall back to empty results
  // so FTS still surfaces matches from the cache.
  final remoteFuture =
      s.search(q).catchError((_) => const SearchResults());

  final results = await Future.wait([ftsFuture, remoteFuture]);
  final ftsTracks = results[0] as List<Track>;
  final remote = results[1] as SearchResults;

  final seen = <String>{
    ...localTracks.map((t) => t.uniqueKey),
    ...ftsTracks.map((t) => t.uniqueKey),
  };
  final remoteOnly =
      remote.tracks.where((t) => seen.add(t.uniqueKey)).toList();

  return SearchResults(
    tracks: [...localTracks, ...ftsTracks, ...remoteOnly],
    albums: remote.albums,
    artists: remote.artists,
  );
});
