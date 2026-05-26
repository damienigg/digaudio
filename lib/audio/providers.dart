import 'dart:async';

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
import '../library/download_queue.dart';
import '../library/downloads.dart';
import '../library/importer.dart';
import '../library/lastfm.dart';
import '../library/lastfm_scrobble.dart';
import '../library/listenbrainz.dart';
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
import 'radio_mode.dart';
import 'sleep_timer.dart';
import '../core/dbg.dart';

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
    ref.watch(subsonicResolverProvider).active);

/// Multi-server router (v0.27.0). Built from [serversProvider] +
/// [activeServerProvider]; used by the engine + Artwork + search fan-out
/// to route per-track URIs to the originating server. [subsonicProvider]
/// is now a thin alias for `.active` (back-compat for single-server callers).
final subsonicResolverProvider = Provider<SubsonicResolver>((ref) {
  final list = ref.watch(serversProvider).valueOrNull ?? const <ServerConfig>[];
  final active = ref.watch(activeServerProvider).valueOrNull?.client();
  final byId = <String, SubsonicClient>{};
  for (final s in list) {
    final c = s.client();
    if (c != null) byId[s.id] = c;
  }
  return SubsonicResolver(active: active, byId: byId);
});

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

// `ChangeNotifierProvider` (not the plain `Provider`) so widgets that
// `ref.watch` it auto-rebuild on `notifyListeners()` — which the
// `save()` method now calls. Plain Provider returned the singleton
// without ever emitting "I changed", and the previous workaround
// (`ref.invalidate(displayPrefsProvider)` after each toggle) destroyed
// the singleton + reset every other persisted pref in-memory. See
// `DisplayPrefs`'s class doc for the full rationale.
final displayPrefsProvider =
    ChangeNotifierProvider<DisplayPrefs>((_) => DisplayPrefs());

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

final radioModeProvider = Provider<RadioModeService>((ref) {
  final svc = RadioModeService(
    ref.watch(audioEngineProvider),
    () => ref.read(subsonicProvider),
  );
  ref.onDispose(svc.dispose);
  return svc;
});

final btEqProvider = Provider<BtEqService>((ref) {
  final svc = BtEqService(
    ref.watch(audioEngineProvider),
    () async => ref.read(playbackPrefsProvider).eqGainsDb,
    ref.read(playbackPrefsProvider),
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
const _lastfmSecret =
    String.fromEnvironment('LASTFM_SHARED_SECRET', defaultValue: '');
final lastfmClientProvider = Provider<LastfmClient>((_) => LastfmClient(_lastfmKey));

/// Last.fm direct scrobble client (v0.30.0). Build-time api_key and
/// shared_secret come from dart-defines; the session key is read
/// **live** from [PlaybackPrefs] via a closure so a successful
/// "Connect Last.fm" in Settings flips `client.enabled` to true on
/// the next read — without an app restart and without depending on
/// Riverpod noticing a mutation inside the prefs singleton (which it
/// can't, because PlaybackPrefs is the same instance before/after
/// save).
final lastfmScrobbleClientProvider =
    Provider<LastfmScrobbleClient>((ref) => LastfmScrobbleClient(
          apiKey: _lastfmKey,
          sharedSecret: _lastfmSecret,
          sessionKey: () => ref.read(playbackPrefsProvider).lastfmSessionKey,
        ));

/// ListenBrainz client — reads the user token live from prefs so a
/// change in Settings takes effect on the next track switch without
/// requiring an app restart. Token from
/// https://listenbrainz.org/profile/.
final listenbrainzClientProvider = Provider<ListenBrainzClient>((ref) =>
    ListenBrainzClient(ref.watch(playbackPrefsProvider).listenbrainzToken));

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

/// Per-download progress map (trackKey → 0..1). Powers the live bar
/// inside the download-queue banner.
final downloadProgressProvider = StreamProvider<Map<String, double>>((ref) =>
    ref.watch(downloadsProvider).progressStream);

/// Background queue of pinned downloads. Wraps DownloadsManager so
/// callers can fire-and-forget instead of awaiting each tap.
final downloadQueueProvider = Provider<DownloadQueueService>((ref) {
  final svc = DownloadQueueService(
    ref.watch(downloadsProvider),
    () => ref.read(subsonicProvider),
  );
  ref.onDispose(svc.dispose);
  return svc;
});

final downloadQueueStateProvider = StreamProvider<DownloadQueueState>((ref) =>
    ref.watch(downloadQueueProvider).stateStream);

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
//
// Each engine projection wraps an internal `StreamController.broadcast()`.
// Broadcast streams do NOT replay past events to new subscribers, which
// caused a long-running mystery: the very first track-change event fires
// inside `setQueue()` synchronously — at that moment the mini-player /
// Now Playing have already subscribed via `ref.watch(...)`, BUT the
// previous attempt to seed via `async*` had a race (the seed-yield gave
// control back to the event loop before `yield*` subscribed to the
// underlying stream; events arriving in that window were dropped).
//
// Definitive fix: replace `StreamProvider` + `async*` with
// `StateNotifierProvider`. The notifier reads the engine's current
// synchronous state at construction (no race possible — sync read),
// then subscribes to the broadcast stream and writes every event into
// `state`. Riverpod listeners read `state` directly (no
// `AsyncValue.valueOrNull` chain), which is always the latest known
// value from the moment the provider was first watched.

class _StreamMirror<T> extends StateNotifier<T> {
  late final StreamSubscription<T> _sub;
  // Regular param (not `super.initial`) so the body can reference it
  // for debug logging. The use_super_parameters lint preference loses
  // to the instrumentation need this version.
  _StreamMirror(T initial, Stream<T> source) : super(initial) {
    dbg('_StreamMirror<$T> ctor: initial=$initial, '
        'stream=${identityHashCode(source)}, '
        'isBroadcast=${source.isBroadcast}');
    _sub = source.listen(
      (v) {
        dbg('_StreamMirror<$T> onData: $v');
        state = v;
      },
      onError: (e, st) {
        dbg('_StreamMirror<$T> onError: $e');
      },
      onDone: () {
        dbg('_StreamMirror<$T> onDone');
      },
    );
  }
  @override
  void dispose() {
    dbg('_StreamMirror<$T> dispose');
    _sub.cancel();
    super.dispose();
  }
}

final currentTrackProvider =
    StateNotifierProvider<_StreamMirror<Track?>, Track?>((ref) {
  final engine = ref.watch(audioEngineProvider);
  return _StreamMirror<Track?>(engine.currentTrack, engine.currentTrackStream);
});

final playerStateProvider =
    StateNotifierProvider<_StreamMirror<PlayerState>, PlayerState>((ref) {
  final engine = ref.watch(audioEngineProvider);
  return _StreamMirror<PlayerState>(
      engine.raw.playerState, engine.playerStateStream);
});

final positionProvider =
    StateNotifierProvider<_StreamMirror<Duration>, Duration>((ref) {
  final engine = ref.watch(audioEngineProvider);
  return _StreamMirror<Duration>(engine.raw.position, engine.positionStream);
});

final durationProvider =
    StateNotifierProvider<_StreamMirror<Duration?>, Duration?>((ref) {
  final engine = ref.watch(audioEngineProvider);
  return _StreamMirror<Duration?>(engine.raw.duration, engine.durationStream);
});

final shuffleProvider =
    StateNotifierProvider<_StreamMirror<bool>, bool>((ref) {
  final engine = ref.watch(audioEngineProvider);
  return _StreamMirror<bool>(
      engine.raw.shuffleModeEnabled, engine.shuffleModeStream);
});

final loopProvider =
    StateNotifierProvider<_StreamMirror<LoopMode>, LoopMode>((ref) {
  final engine = ref.watch(audioEngineProvider);
  return _StreamMirror<LoopMode>(engine.raw.loopMode, engine.loopModeStream);
});

/// Mirrors the engine's queue contents. Fires on every mutation
/// (setQueue, appendToQueue, playNext, moveInQueue, removeFromQueue,
/// shuffle toggle). UI surfaces — Now Playing Queue tab + Up Next
/// strip — watch this so they stay perfectly in sync regardless of
/// who mutated the queue (user action, auto-queue append, etc.).
final currentQueueProvider =
    StateNotifierProvider<_StreamMirror<List<Track>>, List<Track>>((ref) {
  final engine = ref.watch(audioEngineProvider);
  return _StreamMirror<List<Track>>(
      engine.currentQueue, engine.currentQueueStream);
});

// ---- Browse data (lazy) ----------------------------------------------------

final newestAlbumsProvider = FutureProvider<List<Album>>((ref) async {
  final s = ref.watch(subsonicProvider);
  if (s == null) return const [];
  return s.getAlbumList(type: 'newest', size: 30);
});

/// Albums the user (or anyone on this Subsonic server) played most
/// recently. Different from the local stats — this comes from the
/// server's own play history and stays useful across devices. Empty
/// for fresh installs / fresh servers with no play data yet.
final recentlyPlayedAlbumsProvider = FutureProvider<List<Album>>((ref) async {
  final s = ref.watch(subsonicProvider);
  if (s == null) return const [];
  return s.getAlbumList(type: 'recent', size: 20);
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

/// Library tab source filter: Local-only / Subsonic-only / Both.
/// Default `both` because that's what most users expect (Library =
/// "everything I can play"). Combined providers below switch on this.
enum LibrarySource { local, remote, both }

final librarySourceProvider =
    StateProvider<LibrarySource>((_) => LibrarySource.both);

/// Returns local + Subsonic-cached tracks combined per [librarySourceProvider].
/// Subsonic side reads from the local drift cache (synced via
/// Settings → Playback → Sync library) — so it works offline too.
final libraryTracksProvider = FutureProvider<List<Track>>((ref) async {
  final src = ref.watch(librarySourceProvider);
  final local = src != LibrarySource.remote
      ? (ref.watch(localSongsProvider).valueOrNull ?? const <Track>[])
      : const <Track>[];
  if (src == LibrarySource.local) return local;
  final active = await ref.watch(activeServerProvider.future);
  final remote = active == null
      ? const <Track>[]
      : await ref.read(subsonicCacheProvider).all(active.id);
  if (src == LibrarySource.remote) return remote;
  return [...local, ...remote]
    ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
});

final libraryAlbumsProvider = FutureProvider<List<Album>>((ref) async {
  final src = ref.watch(librarySourceProvider);
  final local = src != LibrarySource.remote
      ? (ref.watch(localAlbumsProvider).valueOrNull ?? const <Album>[])
      : const <Album>[];
  if (src == LibrarySource.local) return local;
  final active = await ref.watch(activeServerProvider.future);
  final remote = active == null
      ? const <Album>[]
      : await ref.read(subsonicCacheProvider).allAlbums(active.id);
  if (src == LibrarySource.remote) return remote;
  return [...local, ...remote]
    ..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
});

final libraryArtistsProvider = FutureProvider<List<Artist>>((ref) async {
  final src = ref.watch(librarySourceProvider);
  final local = src != LibrarySource.remote
      ? (ref.watch(localArtistsProvider).valueOrNull ?? const <Artist>[])
      : const <Artist>[];
  if (src == LibrarySource.local) return local;
  final active = await ref.watch(activeServerProvider.future);
  final remote = active == null
      ? const <Artist>[]
      : await ref.read(subsonicCacheProvider).allArtists(active.id);
  if (src == LibrarySource.remote) return remote;
  return [...local, ...remote]
    ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
});

final searchQueryProvider = StateProvider<String>((_) => '');

/// Multi-server, multi-origin search (v0.27.0, two-stage streaming since v0.30.29).
///
/// Yields TWICE so the UI can render instantly off the local + FTS5 cache
/// (sub-50ms) without waiting on Subsonic round-trips:
///   1. **Fast yield** — local MediaStore in-memory filter + each server's
///      FTS5 library cache (parallel). No network. Renders the moment the
///      user stops typing past the debounce.
///   2. **Enriched yield** — adds live `search3` per server in parallel, each
///      capped at a 2s timeout so one unreachable Tailscale link can't gate
///      the others. Albums + artists arrive only here (FTS5 covers tracks
///      only); a slow server simply contributes nothing for this query.
///
/// Dedup uses a server-aware key (`origin:serverId:id`) — bare ids collide
/// across unrelated Subsonic servers. Local first, then per-server bundles
/// in `serversProvider` order.
final searchResultsProvider = StreamProvider<SearchResults>((ref) async* {
  final q = ref.watch(searchQueryProvider).trim();
  if (q.isEmpty) {
    yield const SearchResults();
    return;
  }
  final local = ref.watch(localLibraryProvider);
  final resolver = ref.watch(subsonicResolverProvider);
  final cache = ref.read(subsonicCacheProvider);

  final allLocal = await local.getAllSongs();
  final lq = q.toLowerCase();
  final localTracks = allLocal.where((t) =>
      t.title.toLowerCase().contains(lq) ||
      (t.artist?.toLowerCase().contains(lq) ?? false) ||
      (t.album?.toLowerCase().contains(lq) ?? false)).take(30).toList();

  final clients = resolver.all.toList();

  String key(Track t) => '${t.origin.name}:${t.serverId ?? ''}:${t.id}';
  final seen = <String>{...localTracks.map(key)};
  final tracks = <Track>[...localTracks];

  // Stage 1 — local + FTS5 cache per server, parallel, no network.
  final ftsFutures = clients.map((c) async {
    final sid = c.serverId;
    if (sid == null) return const <Track>[];
    return cache.searchFts(sid, q, limit: 30).catchError((_) => const <Track>[]);
  });
  final ftsPerServer = await Future.wait(ftsFutures);
  for (final fts in ftsPerServer) {
    for (final t in fts) {
      if (seen.add(key(t))) tracks.add(t);
    }
  }
  yield SearchResults(tracks: List.unmodifiable(tracks));

  if (clients.isEmpty) return;

  // Stage 2 — live search3 per server in parallel, 2s timeout each so the
  // slowest server can never gate the others.
  final remoteFutures = clients.map((c) => c
      .search(q)
      .timeout(const Duration(seconds: 2),
          onTimeout: () => const SearchResults())
      .catchError((_) => const SearchResults()));
  final perServerRemote = await Future.wait(remoteFutures);

  final albums = <Album>[];
  final artists = <Artist>[];
  for (final r in perServerRemote) {
    for (final t in r.tracks) {
      if (seen.add(key(t))) tracks.add(t);
    }
    albums.addAll(r.albums);
    artists.addAll(r.artists);
  }
  yield SearchResults(
    tracks: List.unmodifiable(tracks),
    albums: List.unmodifiable(albums),
    artists: List.unmodifiable(artists),
  );
});
