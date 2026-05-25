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
import '../library/track_positions.dart';
import '../subsonic/client.dart';

/// digaudio's audio engine + AA bridge with **true crossfade** between
/// consecutive tracks.
///
/// **Two-player design.** [_a] and [_b] are `AudioPlayer` instances;
/// [_primary] always points at the one currently audible at full
/// `_targetVolume`, [_secondary] is either idle or pre-loaded with the
/// next track ready to fade in. The queue (`_tracks`) is managed
/// manually — no `ConcatenatingAudioSource` — so we can suppress
/// auto-advance and replace it with our own controlled transitions
/// (overlap fades when `crossfadeMs > 0`, instant swap when 0; the
/// latter is still gapless because the next player has already started
/// loading and is primed to play the moment the current ends).
///
/// All streams the UI subscribes to are **engine-owned** broadcast
/// controllers, fed by whichever player is currently primary. On swap,
/// the inner subscriptions are re-wired transparently so subscribers
/// stay valid across transitions.
///
/// AA browsable tree (today) — three top-level nodes:
///   - Favorites      (FavoritesManager.keys)
///   - Recently played (PlayHistoryManager.recentUnique 20)
///   - Most played    (PlayHistoryManager.topTracks 50)
class AudioEngine extends BaseAudioHandler {
  final SubsonicClient? Function() _subsonic;
  final TrackResolver Function() _resolver;
  final FavoritesManager _favorites;
  final DownloadsManager _cache;
  final PlaybackPrefs _prefs;
  final PlayHistoryManager _history;
  final TrackPositionsManager _positions;

  // Equalizers per player — kept in sync via [applyEqGains] and
  // [setEqEnabled] so swapping doesn't change perceived EQ.
  final AndroidEqualizer _eqA = AndroidEqualizer();
  final AndroidEqualizer _eqB = AndroidEqualizer();
  late final AudioPlayer _a =
      AudioPlayer(audioPipeline: AudioPipeline(androidAudioEffects: [_eqA]));
  late final AudioPlayer _b =
      AudioPlayer(audioPipeline: AudioPipeline(androidAudioEffects: [_eqB]));

  late AudioPlayer _primary = _a;
  late AudioPlayer _secondary = _b;

  // ----- queue + index (manual) ----------------------------------------------
  List<Track> _tracks = const [];
  int _currentIndex = -1;
  // Index loaded on [_secondary] (preloaded next, if any). Reset to null
  // whenever the queue is mutated or after the secondary is consumed.
  int? _preloadedIndex;

  // ----- transition state ----------------------------------------------------
  bool _inTransition = false;
  Timer? _transitionTimer;

  // ----- engine-owned broadcast streams (UI subscribes here) -----------------
  final _playerStateController = StreamController<PlayerState>.broadcast();
  final _positionController = StreamController<Duration>.broadcast();
  final _durationController = StreamController<Duration?>.broadcast();
  final _bufferedController = StreamController<Duration?>.broadcast();
  final _indexController = StreamController<int?>.broadcast();
  final _trackController = StreamController<Track?>.broadcast();
  final _loopController = StreamController<LoopMode>.broadcast();
  final _shuffleController = StreamController<bool>.broadcast();

  // Inner subs on _primary — re-wired on every swap.
  StreamSubscription<PlayerState>? _innerPlayerStateSub;
  StreamSubscription<Duration>? _innerPositionSub;
  StreamSubscription<Duration?>? _innerDurationSub;
  StreamSubscription<Duration>? _innerBufferedSub;
  StreamSubscription<LoopMode>? _innerLoopSub;
  StreamSubscription<bool>? _innerShuffleSub;
  StreamSubscription<PlaybackEvent>? _innerEventSub;
  StreamSubscription<ProcessingState>? _innerProcStateSub;

  // ----- bookkeeping ---------------------------------------------------------
  String? _nowPlayingKey;
  bool _scrobbledCurrent = false;
  DateTime _lastPositionSave = DateTime(0);
  /// Replay-Gain-adjusted ceiling for the current track. Transition
  /// ramps tween toward this value instead of 1.0 so RG doesn't get
  /// clobbered by the fade orchestrator.
  double _targetVolume = 1.0;
  // Loop mode lives at the engine level now (manual advance) instead
  // of just_audio's per-source mode.
  LoopMode _loopMode = LoopMode.off;
  bool _shuffleEnabled = false;
  // Original (insertion-order) copy of the queue, used when shuffle
  // toggles back off so we can restore the user's order.
  List<Track> _originalOrder = const [];

  AudioEngine({
    required SubsonicClient? Function() subsonic,
    required TrackResolver Function() resolver,
    required FavoritesManager favorites,
    required DownloadsManager cache,
    required PlaybackPrefs prefs,
    required PlayHistoryManager history,
    required TrackPositionsManager positions,
  })  : _subsonic = subsonic,
        _resolver = resolver,
        _favorites = favorites,
        _cache = cache,
        _prefs = prefs,
        _history = history,
        _positions = positions;

  // Compat with old callers that grabbed `raw` for ad-hoc operations.
  AudioPlayer get raw => _primary;
  AndroidEqualizer get equalizer => _eqA;
  List<Track> get currentQueue => _tracks;

  Future<void> init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    _wirePrimary();
  }

  /// (Re)connects all inner subs to whatever `_primary` currently points
  /// at. Called on init and after every swap so external subscribers
  /// keep seeing a continuous stream.
  void _wirePrimary() {
    _innerPlayerStateSub?.cancel();
    _innerPositionSub?.cancel();
    _innerDurationSub?.cancel();
    _innerBufferedSub?.cancel();
    _innerLoopSub?.cancel();
    _innerShuffleSub?.cancel();
    _innerEventSub?.cancel();
    _innerProcStateSub?.cancel();

    _innerPlayerStateSub = _primary.playerStateStream.listen(_playerStateController.add);
    _innerDurationSub = _primary.durationStream.listen(_durationController.add);
    _innerBufferedSub = _primary.bufferedPositionStream.listen(_bufferedController.add);
    _innerLoopSub = _primary.loopModeStream.listen(_loopController.add);
    _innerShuffleSub = _primary.shuffleModeEnabledStream.listen(_shuffleController.add);
    _innerEventSub = _primary.playbackEventStream.listen((_) => _broadcastState());

    _innerPositionSub = _primary.positionStream.listen((pos) {
      _positionController.add(pos);
      _onPosition(pos);
    });
    _innerProcStateSub = _primary.processingStateStream.listen(_onProcessingState);
  }

  // ===========================================================================
  // Position-stream handlers (scrobble, save, crossfade trigger)
  // ===========================================================================

  void _onPosition(Duration pos) {
    final t = currentTrack;
    if (t == null) return;
    if (t.uniqueKey != _nowPlayingKey) return;

    // Definitive scrobble at the Last.fm threshold.
    if (!_scrobbledCurrent && t.origin == MediaOrigin.subsonic) {
      final durSec = _primary.duration?.inSeconds ?? 0;
      final thresholdSec = durSec == 0 ? 240 : min(240, durSec ~/ 2);
      if (pos.inSeconds >= thresholdSec) {
        _scrobbledCurrent = true;
        _subsonic()?.scrobble(t.id, submission: true);
      }
    }

    // Save resume position every ~5 s.
    final now = DateTime.now();
    if (now.difference(_lastPositionSave) >= const Duration(seconds: 5)) {
      _lastPositionSave = now;
      _positions.save(t.uniqueKey, pos);
    }

    // Crossfade trigger: enter the overlap window when we're inside the
    // last [crossfadeMs] of the current track. Suppressed when looping
    // a single track (we want the natural loop, not a transition).
    if (_inTransition || _loopMode == LoopMode.one) return;
    final fadeMs = _prefs.crossfadeMs;
    if (fadeMs <= 0) return;
    final dur = _primary.duration;
    if (dur == null) return;
    final remainingMs = dur.inMilliseconds - pos.inMilliseconds;
    if (remainingMs <= 0 || remainingMs > fadeMs) return;
    final nextIdx = _peekNextIndex();
    if (nextIdx == null) return;
    _startTransition(nextIdx);
  }

  void _onProcessingState(ProcessingState state) {
    if (state != ProcessingState.completed) return;
    if (_inTransition) return;
    // LoopMode.one: just_audio's loop-one on the source handles it; we
    // shouldn't have hit `completed` here, but bail just in case.
    if (_loopMode == LoopMode.one) return;
    // No crossfade trigger fired (fade=0 OR track shorter than fade
    // window). Advance now with an instant swap.
    final nextIdx = _peekNextIndex();
    if (nextIdx == null) {
      mediaItem.add(null);
      _trackController.add(null);
      return;
    }
    _instantAdvance(nextIdx);
  }

  /// What track plays after the current one? Honours `LoopMode.all`
  /// (wraps to 0) and respects shuffle order (which is already baked
  /// into `_tracks` when shuffle is enabled).
  int? _peekNextIndex() {
    if (_tracks.isEmpty || _currentIndex < 0) return null;
    if (_currentIndex + 1 < _tracks.length) return _currentIndex + 1;
    if (_loopMode == LoopMode.all) return 0;
    return null;
  }

  // ===========================================================================
  // Transitions (crossfade or instant swap)
  // ===========================================================================

  Future<void> _startTransition(int nextIndex) async {
    _inTransition = true;
    final fadeMs = _prefs.crossfadeMs;
    final nextTrack = _tracks[nextIndex];

    // Ensure secondary is loaded with the right track. If preload had
    // a different (stale) index, reload synchronously.
    if (_preloadedIndex != nextIndex) {
      try {
        await _secondary.setAudioSource(_sourceFor(nextTrack));
        _preloadedIndex = nextIndex;
      } catch (_) {
        _inTransition = false;
        return;
      }
    }

    final nextTarget = _rgVolumeFor(nextTrack);
    final primaryStart = _primary.volume;

    if (fadeMs <= 0) {
      // Instant swap — no overlap. Start secondary at full target
      // volume and stop primary the same moment.
      await _secondary.setVolume(nextTarget);
      await _secondary.play();
      await _primary.stop();
      _finalizeAdvance(nextIndex, nextTrack, nextTarget);
      return;
    }

    // Overlap window: both players audible, A fades out, B fades in.
    await _secondary.setVolume(0.0);
    await _secondary.play();

    final start = DateTime.now();
    _transitionTimer?.cancel();
    _transitionTimer = Timer.periodic(const Duration(milliseconds: 40), (timer) async {
      final elapsed = DateTime.now().difference(start).inMilliseconds;
      final progress = (elapsed / fadeMs).clamp(0.0, 1.0);
      _primary.setVolume(primaryStart * (1 - progress));
      _secondary.setVolume(nextTarget * progress);
      if (progress >= 1.0) {
        timer.cancel();
        _transitionTimer = null;
        await _primary.stop();
        _finalizeAdvance(nextIndex, nextTrack, nextTarget);
      }
    });
  }

  /// Instant advance — used when there's no fade window OR the user
  /// hits skip. Reuses the preloaded secondary when available so the
  /// next track plays without a gap; otherwise loads on primary +
  /// silences secondary (which may be mid-fade from a cancelled
  /// crossfade).
  Future<void> _instantAdvance(int nextIndex) async {
    final nextTrack = _tracks[nextIndex];
    final nextTarget = _rgVolumeFor(nextTrack);
    _inTransition = true;
    if (_preloadedIndex == nextIndex) {
      await _secondary.setVolume(nextTarget);
      await _secondary.play();
      await _primary.stop();
      _finalizeAdvance(nextIndex, nextTrack, nextTarget);
    } else {
      await _silenceSecondary();
      try {
        await _primary.setAudioSource(_sourceFor(nextTrack));
        await _primary.setVolume(nextTarget);
        await _primary.play();
      } catch (_) {
        _inTransition = false;
        return;
      }
      _currentIndex = nextIndex;
      _targetVolume = nextTarget;
      _preloadedIndex = null;
      _inTransition = false;
      _onTrackChanged(nextTrack);
      unawaited(_preloadNextIfNeeded());
      _maybeResume(nextTrack);
    }
  }

  /// Common tail of a swap-based transition (overlap or instant via
  /// secondary). Swaps roles, updates state, fires the listeners.
  void _finalizeAdvance(int nextIndex, Track nextTrack, double nextTarget) {
    final tmp = _primary;
    _primary = _secondary;
    _secondary = tmp;
    _currentIndex = nextIndex;
    _targetVolume = nextTarget;
    _preloadedIndex = null;
    _inTransition = false;
    _wirePrimary();
    _onTrackChanged(nextTrack);
    unawaited(_preloadNextIfNeeded());
    _maybeResume(nextTrack);
  }

  /// Called every time the audibly-playing track changes (whether via
  /// natural advance, user skip, or initial setQueue). Updates cache /
  /// history / mediaItem / scrobble + emits index + track streams.
  void _onTrackChanged(Track t) {
    _cache.touch(t.uniqueKey);
    _history.recordPlay(t.uniqueKey);
    mediaItem.add(_toMediaItem(t));
    _indexController.add(_currentIndex);
    _trackController.add(t);
    _nowPlayingKey = t.uniqueKey;
    _scrobbledCurrent = false;
    if (t.origin == MediaOrigin.subsonic) {
      _subsonic()?.scrobble(t.id, submission: false);
    }
  }

  Future<void> _preloadNextIfNeeded() async {
    final nextIdx = _peekNextIndex();
    if (nextIdx == null) {
      _preloadedIndex = null;
      return;
    }
    if (_preloadedIndex == nextIdx) return;
    final next = _tracks[nextIdx];
    try {
      // setAudioSource on secondary without play — primes the buffer +
      // resolves duration metadata so the transition is jank-free.
      await _secondary.setAudioSource(_sourceFor(next), preload: true);
      _preloadedIndex = nextIdx;
    } catch (_) {
      _preloadedIndex = null;
    }
  }

  /// Looks up the saved position for [t] and seeks if it's meaningfully
  /// mid-track. Waits for the duration to be known via a one-shot
  /// listener before deciding (so we don't seek past the end).
  void _maybeResume(Track t) async {
    final saved = await _positions.get(t.uniqueKey);
    if (saved == null || saved < const Duration(seconds: 10)) return;
    if (t.uniqueKey != _nowPlayingKey) return;
    StreamSubscription<Duration?>? sub;
    sub = _primary.durationStream.listen((dur) {
      if (dur == null) return;
      sub?.cancel();
      if (saved < dur - const Duration(seconds: 10) &&
          t.uniqueKey == _nowPlayingKey) {
        _primary.seek(saved);
      }
    });
  }

  // ===========================================================================
  // RG / EQ helpers (unchanged semantics)
  // ===========================================================================

  /// Linear gain (0..1) from the track's Replay Gain metadata + the
  /// user's `rgMode`. Caps at 1.0 (no boost). Subsonic ≤ 1.16 servers
  /// don't expose RG → both fields null → returns 1.0 (no-op).
  double _rgVolumeFor(Track t) {
    if (_prefs.rgMode == 'off') return 1.0;
    final preferAlbum = _prefs.rgMode == 'album';
    final gainDb = (preferAlbum
            ? t.replayGainAlbumDb ?? t.replayGainTrackDb
            : t.replayGainTrackDb ?? t.replayGainAlbumDb) ??
        0.0;
    return pow(10, gainDb / 20).toDouble().clamp(0.0, 1.0);
  }

  Future<AndroidEqualizerParameters> get eqParameters => _eqA.parameters;

  Future<void> setEqEnabled(bool on) async {
    await _eqA.setEnabled(on);
    await _eqB.setEnabled(on);
  }

  Future<void> applyEqGains(List<double> gainsDb) async {
    for (final eq in [_eqA, _eqB]) {
      final params = await eq.parameters;
      for (var i = 0; i < params.bands.length; i++) {
        final g = i < gainsDb.length ? gainsDb[i] : 0.0;
        await params.bands[i]
            .setGain(g.clamp(params.minDecibels, params.maxDecibels));
      }
    }
  }

  // ===========================================================================
  // Queue control
  // ===========================================================================

  Future<void> setQueue(List<Track> tracks, {int initialIndex = 0}) async {
    if (tracks.isEmpty) return;
    _transitionTimer?.cancel();
    _inTransition = false;
    // Stop secondary if anything was loaded — fresh queue invalidates
    // every preload.
    if (_secondary.processingState != ProcessingState.idle) {
      await _secondary.stop();
    }
    _tracks = List.unmodifiable(tracks);
    _originalOrder = _tracks;
    if (_shuffleEnabled) _applyShuffle(initialIndex);
    _currentIndex = initialIndex.clamp(0, _tracks.length - 1);
    _preloadedIndex = null;
    queue.add(_tracks.map(_toMediaItem).toList());

    final t = _tracks[_currentIndex];
    _targetVolume = _rgVolumeFor(t);
    await _primary.setAudioSource(_sourceFor(t));
    await _primary.setVolume(_targetVolume);
    await _primary.play();
    _onTrackChanged(t);
    unawaited(_preloadNextIfNeeded());
    _maybeResume(t);
  }

  Future<void> playSingle(Track t) => setQueue([t]);

  Future<void> appendToQueue(Track t) async {
    _tracks = List.unmodifiable([..._tracks, t]);
    queue.add(_tracks.map(_toMediaItem).toList());
    // Append might have introduced a new "next" (if we were at the end).
    unawaited(_preloadNextIfNeeded());
  }

  Future<void> playNext(Track t) async {
    final idx = (_currentIndex + 1).clamp(0, _tracks.length);
    _tracks = List.unmodifiable([..._tracks]..insert(idx, t));
    queue.add(_tracks.map(_toMediaItem).toList());
    _preloadedIndex = null; // stale — new "next" is the inserted track
    unawaited(_preloadNextIfNeeded());
  }

  /// Reorder a queue entry. UI semantics: `to` = final position
  /// post-move.
  Future<void> moveInQueue(int from, int to) async {
    if (from == to) return;
    if (from < 0 || from >= _tracks.length) return;
    final clamped = to.clamp(0, _tracks.length - 1);
    final list = [..._tracks];
    final t = list.removeAt(from);
    list.insert(clamped, t);
    _tracks = List.unmodifiable(list);
    // Adjust the index of the currently-playing track to follow the move.
    if (from == _currentIndex) {
      _currentIndex = clamped;
    } else if (from < _currentIndex && clamped >= _currentIndex) {
      _currentIndex--;
    } else if (from > _currentIndex && clamped <= _currentIndex) {
      _currentIndex++;
    }
    queue.add(_tracks.map(_toMediaItem).toList());
    _preloadedIndex = null;
    unawaited(_preloadNextIfNeeded());
  }

  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= _tracks.length) return;
    if (index == _currentIndex) return; // safer to no-op than dance around
    final list = [..._tracks]..removeAt(index);
    _tracks = List.unmodifiable(list);
    if (index < _currentIndex) _currentIndex--;
    queue.add(_tracks.map(_toMediaItem).toList());
    _preloadedIndex = null;
    unawaited(_preloadNextIfNeeded());
  }

  // ===========================================================================
  // Source builder (unchanged)
  // ===========================================================================

  AudioSource _sourceFor(Track t) {
    final tag = _toMediaItem(t);
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
    return null;
  }

  // ===========================================================================
  // BaseAudioHandler overrides (MediaSession / Android Auto)
  // ===========================================================================

  @override
  Future<void> play() => _primary.play();

  @override
  Future<void> pause() => _primary.pause();

  @override
  Future<void> stop() async {
    _transitionTimer?.cancel();
    _inTransition = false;
    await _primary.stop();
    if (_secondary.processingState != ProcessingState.idle) {
      await _secondary.stop();
    }
  }

  @override
  Future<void> seek(Duration position) => _primary.seek(position);

  @override
  Future<void> skipToNext() async {
    final nextIdx = _peekNextIndex();
    if (nextIdx == null) return;
    _transitionTimer?.cancel();
    _inTransition = false;
    await _instantAdvance(nextIdx);
  }

  @override
  Future<void> skipToPrevious() async {
    // Standard music-player behaviour: if past 3 s into the current
    // track, restart it; otherwise go to the previous (or first).
    final pos = _primary.position;
    if (pos > const Duration(seconds: 3) || _currentIndex <= 0) {
      await _primary.seek(Duration.zero);
      return;
    }
    final prevIdx = _currentIndex - 1;
    _transitionTimer?.cancel();
    _inTransition = false;
    await _silenceSecondary();
    final prev = _tracks[prevIdx];
    _targetVolume = _rgVolumeFor(prev);
    try {
      await _primary.setAudioSource(_sourceFor(prev));
      await _primary.setVolume(_targetVolume);
      await _primary.play();
    } catch (_) {
      return;
    }
    _currentIndex = prevIdx;
    _preloadedIndex = null;
    _onTrackChanged(prev);
    unawaited(_preloadNextIfNeeded());
    _maybeResume(prev);
  }

  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _tracks.length) return;
    _transitionTimer?.cancel();
    _inTransition = false;
    await _silenceSecondary();
    final t = _tracks[index];
    _targetVolume = _rgVolumeFor(t);
    try {
      await _primary.setAudioSource(_sourceFor(t));
      await _primary.setVolume(_targetVolume);
      await _primary.play();
    } catch (_) {
      return;
    }
    _currentIndex = index;
    _preloadedIndex = null;
    _onTrackChanged(t);
    unawaited(_preloadNextIfNeeded());
    _maybeResume(t);
  }

  /// Ensure the secondary isn't audible — used by skip paths that
  /// bypass the swap (loading new source on primary directly). Without
  /// this, a mid-fade secondary keeps playing in the background after
  /// the user jumped elsewhere.
  Future<void> _silenceSecondary() async {
    if (_secondary.playing) await _secondary.pause();
    await _secondary.setVolume(0.0);
  }

  @override
  Future<void> setSpeed(double speed) async {
    // Keep both players in sync so a fade across a speed change
    // doesn't sound like a tempo jump.
    await _primary.setSpeed(speed);
    await _secondary.setSpeed(speed);
  }

  @override
  Future<void> setShuffleMode(AudioServiceShuffleMode shuffleMode) async {
    final on = shuffleMode != AudioServiceShuffleMode.none;
    _shuffleEnabled = on;
    _shuffleController.add(on);
    if (_tracks.isEmpty) return;
    if (on) {
      _applyShuffle(_currentIndex);
    } else {
      // Restore original order. Recompute _currentIndex against the
      // (now-original) list using the currently playing track's identity.
      final t = currentTrack;
      _tracks = _originalOrder;
      if (t != null) {
        final idx = _tracks.indexWhere((x) => x.uniqueKey == t.uniqueKey);
        if (idx >= 0) _currentIndex = idx;
      }
    }
    queue.add(_tracks.map(_toMediaItem).toList());
    _preloadedIndex = null;
    unawaited(_preloadNextIfNeeded());
  }

  /// Engine-level shuffle: keep the current track in place, shuffle
  /// the rest of the queue. just_audio's per-source `shuffle()` would
  /// only shuffle internal buckets of a ConcatenatingAudioSource —
  /// useless here since we no longer use one.
  void _applyShuffle(int keepIndex) {
    if (_originalOrder.isEmpty) _originalOrder = _tracks;
    final pinned = _tracks[keepIndex];
    final rest = [..._tracks]..removeAt(keepIndex);
    rest.shuffle();
    _tracks = List.unmodifiable([pinned, ...rest]);
    _currentIndex = 0;
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    _loopMode = switch (repeatMode) {
      AudioServiceRepeatMode.none => LoopMode.off,
      AudioServiceRepeatMode.one => LoopMode.one,
      AudioServiceRepeatMode.all => LoopMode.all,
      AudioServiceRepeatMode.group => LoopMode.all,
    };
    // For LoopMode.one we delegate to just_audio's per-source loop
    // (single-track repeats are seamless that way). LoopMode.off /
    // LoopMode.all are handled by our manual _peekNextIndex.
    await _primary.setLoopMode(_loopMode == LoopMode.one ? LoopMode.one : LoopMode.off);
    await _secondary.setLoopMode(_loopMode == LoopMode.one ? LoopMode.one : LoopMode.off);
    _loopController.add(_loopMode);
  }

  /// AA browsable tree.
  @override
  Future<List<MediaItem>> getChildren(String parentMediaId,
      [Map<String, dynamic>? options]) async {
    if (parentMediaId == AudioService.browsableRootId) {
      return const [
        MediaItem(id: 'cat:favorites', title: 'Favorites', playable: false, extras: {'browsable': true}),
        MediaItem(id: 'cat:recent',    title: 'Recently played', playable: false, extras: {'browsable': true}),
        MediaItem(id: 'cat:top',       title: 'Most played', playable: false, extras: {'browsable': true}),
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
  Future<void> playFromMediaId(String mediaId, [Map<String, dynamic>? extras]) async {
    if (mediaId.startsWith('cat:')) return;
    final t = await _resolver().resolve(mediaId);
    if (t != null) await playSingle(t);
  }

  /// Snapshot primary state into audio_service [playbackState] for
  /// MediaSession / Bluetooth / Android Auto.
  void _broadcastState() {
    final playing = _primary.playing;
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
      }[_primary.processingState]!,
      playing: playing,
      updatePosition: _primary.position,
      bufferedPosition: _primary.bufferedPosition,
      speed: _primary.speed,
      queueIndex: _currentIndex,
    ));
  }

  // ===========================================================================
  // Engine-only conveniences kept for existing UI call sites
  // ===========================================================================

  Future<void> setShuffle(bool on) =>
      setShuffleMode(on ? AudioServiceShuffleMode.all : AudioServiceShuffleMode.none);

  Future<void> setRepeat(LoopMode mode) {
    final asAs = switch (mode) {
      LoopMode.off => AudioServiceRepeatMode.none,
      LoopMode.one => AudioServiceRepeatMode.one,
      LoopMode.all => AudioServiceRepeatMode.all,
    };
    return setRepeatMode(asAs);
  }

  Future<void> next() => skipToNext();
  Future<void> previous() => skipToPrevious();
  Future<void> seekToIndex(int i) => skipToQueueItem(i);
  Future<void> setVolume(double v) => _primary.setVolume(v);

  @override
  Future<void> onTaskRemoved() => stop();

  Future<void> dispose() async {
    _transitionTimer?.cancel();
    await _innerPlayerStateSub?.cancel();
    await _innerPositionSub?.cancel();
    await _innerDurationSub?.cancel();
    await _innerBufferedSub?.cancel();
    await _innerLoopSub?.cancel();
    await _innerShuffleSub?.cancel();
    await _innerEventSub?.cancel();
    await _innerProcStateSub?.cancel();
    await _playerStateController.close();
    await _positionController.close();
    await _durationController.close();
    await _bufferedController.close();
    await _indexController.close();
    await _trackController.close();
    await _loopController.close();
    await _shuffleController.close();
    await _a.dispose();
    await _b.dispose();
  }

  // ===========================================================================
  // Streams (re-exported for providers — fed by _wirePrimary)
  // ===========================================================================

  Stream<PlayerState> get playerStateStream => _playerStateController.stream;
  Stream<Duration> get positionStream => _positionController.stream;
  Stream<Duration?> get bufferedPositionStream => _bufferedController.stream;
  Stream<Duration?> get durationStream => _durationController.stream;
  Stream<int?> get currentIndexStream => _indexController.stream;
  Stream<LoopMode> get loopModeStream => _loopController.stream;
  Stream<bool> get shuffleModeStream => _shuffleController.stream;

  Track? get currentTrack {
    if (_currentIndex < 0 || _currentIndex >= _tracks.length) return null;
    return _tracks[_currentIndex];
  }

  Stream<Track?> get currentTrackStream => _trackController.stream;
}
