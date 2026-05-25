import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';

import '../core/playback_prefs.dart';
import '../domain.dart';
import '../library/collections.dart';
import '../library/downloads.dart';
import '../library/local.dart';
import '../library/play_history.dart';
import '../subsonic/client.dart';

/// digaudio's single audio engine + AA bridge.
///
/// Subclasses [BaseAudioHandler] so the same instance powers the in-app
/// UI AND the Android Auto / MediaSession surface — no parallel paths.
/// Subsonic streams are piped through [LockCachingAudioSource] so the
/// played bytes land in the on-disk pool ([DownloadsManager]) — one
/// network roundtrip serves both playback and offline re-listen.
///
/// AA browsable tree (today) — three top-level nodes:
///   - Favorites      (FavoritesManager.keys)
///   - Recently played (PlayHistoryManager.recentUnique 20)
///   - Most played    (PlayHistoryManager.topTracks 50)
/// `playFromMediaId` resolves any leaf MediaItem back to a Track via
/// [TrackResolver] and starts a single-track queue.
class AudioEngine extends BaseAudioHandler {
  final SubsonicClient? Function() _subsonic;
  final TrackResolver Function() _resolver;
  final FavoritesManager _favorites;
  final DownloadsManager _cache;
  final PlaybackPrefs _prefs;
  final PlayHistoryManager _history;
  final AndroidEqualizer _equalizer = AndroidEqualizer();
  late final AudioPlayer _player = AudioPlayer(
    audioPipeline: AudioPipeline(androidAudioEffects: [_equalizer]),
  );
  ConcatenatingAudioSource? _queue;
  List<Track> _tracks = const [];
  StreamSubscription<int?>? _indexSub;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<PlaybackEvent>? _eventSub;
  String? _nowPlayingKey;
  bool _scrobbledCurrent = false;

  AudioEngine({
    required SubsonicClient? Function() subsonic,
    required TrackResolver Function() resolver,
    required FavoritesManager favorites,
    required DownloadsManager cache,
    required PlaybackPrefs prefs,
    required PlayHistoryManager history,
  })  : _subsonic = subsonic,
        _resolver = resolver,
        _favorites = favorites,
        _cache = cache,
        _prefs = prefs,
        _history = history;

  AudioPlayer get raw => _player;
  AndroidEqualizer get equalizer => _equalizer;
  List<Track> get currentQueue => _tracks;

  Future<void> init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());

    // Bridge just_audio state → audio_service playbackState so MediaSession
    // / Bluetooth / Android Auto controls reflect what we're actually doing.
    _eventSub = _player.playbackEventStream.listen((_) => _broadcastState());

    // On every track switch: refresh LRU, log the play, push the MediaItem
    // for the new track, fire a Subsonic "now playing" hint, and reset the
    // scrobble-completion tracker.
    _indexSub = _player.currentIndexStream.listen((i) {
      if (i == null || i < 0 || i >= _tracks.length) {
        mediaItem.add(null);
        return;
      }
      final t = _tracks[i];
      _cache.touch(t.uniqueKey);
      _history.recordPlay(t.uniqueKey);
      mediaItem.add(_toMediaItem(t));
      _nowPlayingKey = t.uniqueKey;
      _scrobbledCurrent = false;
      if (t.origin == MediaOrigin.subsonic) {
        _subsonic()?.scrobble(t.id, submission: false);
      }
    });

    // Definitive scrobble at ≥4 min played OR ≥50% of duration — Last.fm's
    // classic threshold (Subsonic forwards to Last.fm server-side when
    // configured). Position-stream throttling keeps overhead trivial.
    _posSub = _player.positionStream.listen((pos) {
      if (_scrobbledCurrent) return;
      final t = currentTrack;
      if (t == null || t.origin != MediaOrigin.subsonic) return;
      if (t.uniqueKey != _nowPlayingKey) return;
      final durSec = _player.duration?.inSeconds ?? 0;
      final thresholdSec = durSec == 0 ? 240 : min(240, durSec ~/ 2);
      if (pos.inSeconds >= thresholdSec) {
        _scrobbledCurrent = true;
        _subsonic()?.scrobble(t.id, submission: true);
      }
    });
  }

  // --- Equalizer ------------------------------------------------------------

  Future<AndroidEqualizerParameters> get eqParameters => _equalizer.parameters;

  Future<void> setEqEnabled(bool on) => _equalizer.setEnabled(on);

  Future<void> applyEqGains(List<double> gainsDb) async {
    final params = await _equalizer.parameters;
    for (var i = 0; i < params.bands.length; i++) {
      final g = i < gainsDb.length ? gainsDb[i] : 0.0;
      await params.bands[i].setGain(g.clamp(params.minDecibels, params.maxDecibels));
    }
  }

  // --- Queue control -------------------------------------------------------

  Future<void> setQueue(List<Track> tracks, {int initialIndex = 0}) async {
    if (tracks.isEmpty) return;
    _tracks = List.unmodifiable(tracks);
    _queue = ConcatenatingAudioSource(children: tracks.map(_sourceFor).toList());
    // Mirror queue → audio_service queue so MediaSession / AA show it.
    queue.add(_tracks.map(_toMediaItem).toList());
    await _player.setAudioSource(
      _queue!,
      initialIndex: initialIndex.clamp(0, tracks.length - 1),
      preload: true,
    );
    await _player.play();
  }

  Future<void> playSingle(Track t) => setQueue([t]);

  Future<void> appendToQueue(Track t) async {
    await _queue?.add(_sourceFor(t));
    _tracks = [..._tracks, t];
    queue.add(_tracks.map(_toMediaItem).toList());
  }

  Future<void> playNext(Track t) async {
    if (_queue == null) return playSingle(t);
    final idx = (_player.currentIndex ?? 0) + 1;
    await _queue!.insert(idx, _sourceFor(t));
    _tracks = [..._tracks]..insert(idx, t);
    queue.add(_tracks.map(_toMediaItem).toList());
  }

  AudioSource _sourceFor(Track t) {
    final tag = _toMediaItem(t);
    // Offline file always wins — regardless of origin.
    final cached = _cache.cachedPathFor(t);
    if (cached != null && File(cached).existsSync()) {
      return AudioSource.uri(Uri.file(cached), tag: tag);
    }
    switch (t.origin) {
      case MediaOrigin.local:
        return AudioSource.uri(Uri.parse(t.localContentUri), tag: tag);
      case MediaOrigin.subsonic:
        final s = _subsonic();
        if (s == null) throw StateError('No Subsonic server configured');
        final uri = s.streamUri(t.id);
        if (!_prefs.autoCacheEnabled) {
          return AudioSource.uri(uri, tag: tag);
        }
        // LockCachingAudioSource tees the stream into [target] as it plays.
        // On completion (progress = 1.0) we register the row and run an
        // LRU sweep so the pool stays under the user's budget.
        final target = _cache.targetFileFor(t);
        final src = LockCachingAudioSource(uri, cacheFile: target, tag: tag);
        var registered = false;
        src.downloadProgressStream.listen((p) async {
          if (p >= 1.0 && !registered) {
            registered = true;
            await _cache.registerAutoCached(t, target);
            await _cache.evictTo(_prefs.cacheMaxBytes);
          }
        });
        return src;
    }
  }

  MediaItem _toMediaItem(Track t) => MediaItem(
        id: t.uniqueKey,
        title: t.title,
        artist: t.artist,
        album: t.album,
        duration: t.duration,
        artUri: _artworkUri(t),
        playable: true,
      );

  Uri? _artworkUri(Track t) {
    if (t.coverArt == null) return null;
    if (t.origin == MediaOrigin.subsonic) {
      return _subsonic()?.coverUri(t.coverArt!);
    }
    // Local artwork is fetched out-of-band via our MediaStore channel; keeping
    // it off the MediaItem keeps the audio payload light and avoids
    // serialising bitmap bytes through the notification.
    return null;
  }

  // --- BaseAudioHandler overrides (MediaSession / Android Auto) ------------

  @override
  Future<void> play() => _player.play();
  @override
  Future<void> pause() => _player.pause();
  @override
  Future<void> stop() => _player.stop();
  @override
  Future<void> seek(Duration position) => _player.seek(position);
  @override
  Future<void> skipToNext() => _player.seekToNext();
  @override
  Future<void> skipToPrevious() => _player.seekToPrevious();
  @override
  Future<void> skipToQueueItem(int index) => _player.seek(Duration.zero, index: index);
  @override
  Future<void> setSpeed(double speed) => _player.setSpeed(speed);
  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final on = shuffleMode != AudioServiceShuffleMode.none;
    if (on) await _player.shuffle();
    await _player.setShuffleModeEnabled(on);
  }
  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) =>
      _player.setLoopMode(switch (repeatMode) {
        AudioServiceRepeatMode.none => LoopMode.off,
        AudioServiceRepeatMode.one => LoopMode.one,
        AudioServiceRepeatMode.all => LoopMode.all,
        AudioServiceRepeatMode.group => LoopMode.all, // no group concept here
      });

  /// AA browsable tree. Categories are unplayable; their children are
  /// resolved Track MediaItems that route back through [playFromMediaId].
  @override
  Future<List<MediaItem>> getChildren(String parentMediaId,
      [Map<String, dynamic>? options]) async {
    if (parentMediaId == AudioService.browsableRootId) {
      return const [
        MediaItem(
            id: 'cat:favorites',
            title: 'Favorites',
            playable: false,
            extras: {'browsable': true}),
        MediaItem(
            id: 'cat:recent',
            title: 'Recently played',
            playable: false,
            extras: {'browsable': true}),
        MediaItem(
            id: 'cat:top',
            title: 'Most played',
            playable: false,
            extras: {'browsable': true}),
      ];
    }
    final keys = await _keysFor(parentMediaId);
    if (keys.isEmpty) return const [];
    final tracks = await _resolver().resolveAll(keys);
    return tracks.map(_toMediaItem).toList();
  }

  Future<List<String>> _keysFor(String parentMediaId) async {
    switch (parentMediaId) {
      case 'cat:favorites':
        return _favorites.keys();
      case 'cat:recent':
        return _history.recentUnique(20);
      case 'cat:top':
        final tops = await _history.topTracks(limit: 50);
        return tops.map((e) => e.trackKey).toList();
    }
    return const [];
  }

  @override
  Future<void> playFromMediaId(String mediaId,
      [Map<String, dynamic>? extras]) async {
    if (mediaId.startsWith('cat:')) return;
    final t = await _resolver().resolve(mediaId);
    if (t != null) await playSingle(t);
  }

  /// Snapshot the just_audio state into the audio_service [playbackState]
  /// stream. Called on every PlaybackEvent so MediaSession / Bluetooth /
  /// Android Auto controls reflect the actual player.
  void _broadcastState() {
    final playing = _player.playing;
    playbackState.add(playbackState.value.copyWith(
      controls: [
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.stop,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.skipToPrevious,
        MediaAction.skipToNext,
        MediaAction.setShuffleMode,
        MediaAction.setRepeatMode,
        MediaAction.setSpeed,
      },
      androidCompactActionIndices: const [0, 1, 2],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: _player.currentIndex,
    ));
  }

  // --- Engine-only conveniences kept for existing UI call sites ------------

  Future<void> setShuffle(bool on) =>
      setShuffleMode(on ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none);

  Future<void> setRepeat(LoopMode mode) => _player.setLoopMode(mode);

  Future<void> next() => skipToNext();
  Future<void> previous() => skipToPrevious();
  Future<void> seekToIndex(int i) => skipToQueueItem(i);
  Future<void> setVolume(double v) => _player.setVolume(v);

  @override
  Future<void> onTaskRemoved() => stop();

  Future<void> dispose() async {
    await _indexSub?.cancel();
    await _posSub?.cancel();
    await _eventSub?.cancel();
    await _player.dispose();
  }

  // --- Streams (re-exported for providers) ---------------------------------

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get bufferedPositionStream =>
      _player.bufferedPositionStream.cast<Duration?>();
  Stream<Duration?> get durationStream => _player.durationStream;
  Stream<int?> get currentIndexStream => _player.currentIndexStream;
  Stream<LoopMode> get loopModeStream => _player.loopModeStream;
  Stream<bool> get shuffleModeStream => _player.shuffleModeEnabledStream;

  /// Current Track from currentIndex + queue. Null before any play.
  Track? get currentTrack {
    final i = _player.currentIndex;
    if (i == null || i < 0 || i >= _tracks.length) return null;
    return _tracks[i];
  }

  Stream<Track?> get currentTrackStream => _player.currentIndexStream.map(
      (i) => (i == null || i < 0 || i >= _tracks.length) ? null : _tracks[i]);
}
