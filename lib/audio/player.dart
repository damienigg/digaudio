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
import '../library/lastfm_scrobble.dart';
import '../library/listenbrainz.dart';
import '../library/local.dart';
import '../library/play_history.dart';
import '../library/track_positions.dart';
import '../subsonic/client.dart';
import '../widget/widget_art.dart';
import '../widget/widget_bridge.dart';

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
  /// Resolver that maps a [Track]'s `serverId` to the right [SubsonicClient].
  /// Per-track routing (vs. an "active client only" callback) is what makes
  /// multi-server search playback work — tracks from server B keep streaming
  /// from B even after the user switches the active server to A. Stale ids
  /// fall back to active; see [SubsonicResolver.forId].
  final SubsonicResolver Function() _subsonicResolver;
  final TrackResolver Function() _resolver;
  final FavoritesManager _favorites;
  final DownloadsManager _cache;
  final PlaybackPrefs _prefs;
  final PlayHistoryManager _history;
  final TrackPositionsManager _positions;
  final ListenBrainzClient Function() _listenbrainz;
  final LastfmScrobbleClient Function() _lastfmScrobble;

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
  /// Fires whenever `_tracks` mutates (setQueue, appendToQueue,
  /// playNext, moveInQueue, removeFromQueue, shuffle toggle). Drives
  /// the `currentQueueProvider` so the Now Playing Queue tab + the
  /// Up Next strip stay synchronised with auto-queue appends without
  /// waiting for a track change.
  final _queueController = StreamController<List<Track>>.broadcast();
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
  /// Last successfully-prefetched artwork path for the homescreen widget.
  /// Persists across pause/resume so the playbackEventStream listener can
  /// re-push it on every state tick without re-downloading. Cleared
  /// implicitly on track change (overwritten by the prefetch result).
  String? _widgetArtPath;
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
    required SubsonicResolver Function() subsonicResolver,
    required TrackResolver Function() resolver,
    required FavoritesManager favorites,
    required DownloadsManager cache,
    required PlaybackPrefs prefs,
    required PlayHistoryManager history,
    required TrackPositionsManager positions,
    required ListenBrainzClient Function() listenbrainz,
    required LastfmScrobbleClient Function() lastfmScrobble,
  })  : _subsonicResolver = subsonicResolver,
        _resolver = resolver,
        _favorites = favorites,
        _cache = cache,
        _prefs = prefs,
        _history = history,
        _positions = positions,
        _listenbrainz = listenbrainz,
        _lastfmScrobble = lastfmScrobble {
    // ignore: avoid_print
    print('[digaudio.dbg] AudioEngine ctor: instance=${identityHashCode(this)}, '
        'trackController=${identityHashCode(_trackController)}');
  }

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
    _innerEventSub = _primary.playbackEventStream.listen((_) {
      _broadcastState();
      // Mirror play/pause into the homescreen widget so its
      // play-pause icon stays in sync with reality.
      _pushWidget();
    });

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

    // Definitive scrobble at the Last.fm threshold (≥ 4 min OR
    // ≥ 50 % of duration, whichever is shorter). Fires once per
    // track via _scrobbledCurrent. Subsonic (server-side scrobble),
    // ListenBrainz and Last.fm direct (v0.30.0) all fire from the
    // same threshold so the user's external scrobble counters
    // stay aligned.
    if (!_scrobbledCurrent) {
      final durSec = _primary.duration?.inSeconds ?? 0;
      final thresholdSec = durSec == 0 ? 240 : min(240, durSec ~/ 2);
      if (pos.inSeconds >= thresholdSec) {
        _scrobbledCurrent = true;
        if (t.origin == MediaOrigin.subsonic) {
          _subsonicResolver().forTrack(t)?.scrobble(t.id, submission: true);
        }
        _listenbrainz().submitListen(
          trackName: t.title,
          artistName: t.artist,
          releaseName: t.album,
        );
        _lastfmScrobble().scrobble(
          track: t.title,
          artist: t.artist,
          album: t.album,
          durationSec: t.duration?.inSeconds,
        );
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
    // a single track (we want the natural loop, not a transition), and
    // when [pauseAtEndOfTrack] is armed (sleep-timer EOT / album mode
    // — we want the track to end naturally so `_onProcessingState`
    // can honour the gate; otherwise crossfade swaps to the next
    // track and the `completed` event never fires for the gated one).
    if (_inTransition || _loopMode == LoopMode.one) return;
    if (pauseAtEndOfTrack) return;
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

  /// When true, the next end-of-track event pauses the engine instead
  /// of auto-advancing to the next queued track. Used by the sleep
  /// timer's "Stop at end of current track" + the album-mode
  /// "Stop after this album". Both features previously listened to
  /// the engine's playerStateStream and called `pause()` themselves,
  /// but lost a race with the auto-advance which already fired on
  /// the same `completed` event — net effect: the next track started
  /// playing anyway. The flag is read inside [_onProcessingState]
  /// before any advance, so the gate is honoured deterministically.
  /// Auto-resets on consumption (single-shot).
  bool pauseAtEndOfTrack = false;

  void _onProcessingState(ProcessingState state) {
    if (state != ProcessingState.completed) return;
    if (_inTransition) return;
    if (pauseAtEndOfTrack) {
      pauseAtEndOfTrack = false;
      // Don't auto-advance. Keep mediaItem on the current track so
      // the lockscreen / widget continue to show what was playing
      // (looks like a paused state, which is exactly the intent).
      // Sleep / album-mode listeners will tidy their own UI from
      // their own playerState subscription.
      return;
    }
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
      // play() must NOT be awaited — just_audio resolves that future
      // only when playback stops. See setQueue's note for the full
      // explanation. _finalizeAdvance fires _onTrackChanged directly.
      unawaited(_secondary.play());
      await _primary.stop();
      _finalizeAdvance(nextIndex, nextTrack, nextTarget);
      return;
    }

    // Overlap window: both players audible, A fades out, B fades in.
    await _secondary.setVolume(0.0);
    unawaited(_secondary.play());

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
      // See setQueue's note: never await player.play() — that future
      // only resolves on stop, blocking the rest of the chain.
      unawaited(_secondary.play());
      await _primary.stop();
      _finalizeAdvance(nextIndex, nextTrack, nextTarget);
    } else {
      await _silenceSecondary();
      try {
        await _primary.setAudioSource(_sourceFor(nextTrack));
        await _primary.setVolume(nextTarget);
        unawaited(_primary.play());
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
    // ignore: avoid_print
    print('[digaudio.dbg] _onTrackChanged: "${t.title}" '
        '(uniqueKey=${t.uniqueKey}, idx=$_currentIndex, '
        'engine=${identityHashCode(this)})');
    _cache.touch(t.uniqueKey);
    _history.recordPlay(t.uniqueKey);
    mediaItem.add(_toMediaItem(t));
    _indexController.add(_currentIndex);
    _trackController.add(t);
    // ignore: avoid_print
    print('[digaudio.dbg] _trackController.add fired '
        '(controller=${identityHashCode(_trackController)}, '
        'isClosed=${_trackController.isClosed})');
    _nowPlayingKey = t.uniqueKey;
    _scrobbledCurrent = false;
    if (t.origin == MediaOrigin.subsonic) {
      _subsonicResolver().forTrack(t)?.scrobble(t.id, submission: false);
    }
    // ListenBrainz "playing_now" — works for any origin as long as
    // we have artist + title. Token gated inside the client.
    _listenbrainz().submitNowPlaying(
      trackName: t.title,
      artistName: t.artist,
      releaseName: t.album,
    );
    // Last.fm direct Now-Playing (v0.30.0) — same origin-agnostic
    // story; session-key gated inside the client. Runs in parallel
    // with Subsonic + ListenBrainz.
    _lastfmScrobble().updateNowPlaying(
      track: t.title,
      artist: t.artist,
      album: t.album,
      durationSec: t.duration?.inSeconds,
    );
    // Homescreen widget refresh. Carries over the previous track's
    // art for the brief window until the prefetch lands — slight
    // cross-track flicker but no blank slot. The playerState listener
    // re-pushes on every event so updates stay current.
    _pushWidget();
    unawaited(WidgetArtFetcher
        .fetch(t, _subsonicResolver().forTrack(t))
        .then((path) {
      // Guard against fast skip: if the user has already moved past
      // [t], the file written by WidgetArtFetcher belongs to the
      // previous fetch race-winner — don't stamp it onto the
      // current notification.
      if (currentTrack?.uniqueKey != t.uniqueKey) return;
      _widgetArtPath = path;
      _pushWidget();
      // Re-publish MediaItem with the local file URI. The notification
      // + lockscreen artwork on Android come from audio_service which
      // tries to download MediaItem.artUri itself; in our setup that
      // download is flaky on Tailscale-hosted Subsonic (the
      // MediaSession service runs in a process that doesn't share the
      // app's network namespace 1:1). Pointing at the tmp JPEG we
      // already downloaded ourselves cuts out the second fetch and
      // makes the notification artwork reliable.
      if (path != null) {
        mediaItem.add(_toMediaItem(t, overrideArtUri: Uri.file(path)));
      }
    }));
  }

  /// Single point of truth for widget pushes — title / artist / play
  /// state from the current track, plus the latest prefetched art path.
  /// Called from [_onTrackChanged] (kicks off a fresh prefetch) and on
  /// every playbackEvent tick (preserves the existing art across
  /// pause/resume/seek without re-downloading).
  void _pushWidget() {
    final t = currentTrack;
    WidgetBridge.update(
      title: t?.title,
      artist: t?.displayArtist,
      isPlaying: _primary.playing,
      artworkPath: _widgetArtPath,
    );
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
  /// True after the engine has restored one saved position in this
  /// session. We only auto-resume the *first* track played per
  /// session — the feature exists to pick up where the user left off
  /// after closing the app, not to surprise them mid-session by
  /// re-playing a track from its old paused offset (user-reported:
  /// "ce comportement ne devrait s'appliquer que quand on revient
  /// apres avoir fermé l'app"). In-session replays always start at 0.
  /// Resets implicitly on app process restart since the engine
  /// instance is fresh.
  bool _sessionResumeApplied = false;

  void _maybeResume(Track t) async {
    if (_sessionResumeApplied) return;
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
        _sessionResumeApplied = true;
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
    // ignore: avoid_print
    print('[digaudio.dbg] setQueue: entering (${tracks.length} tracks, '
        'idx=$initialIndex, hasListener=${_trackController.hasListener})');
    if (tracks.isEmpty) return;
    _transitionTimer?.cancel();
    _inTransition = false;
    // Stop secondary if anything was loaded — fresh queue invalidates
    // every preload.
    if (_secondary.processingState != ProcessingState.idle) {
      // ignore: avoid_print
      print('[digaudio.dbg] setQueue: stopping secondary…');
      await _secondary.stop();
      // ignore: avoid_print
      print('[digaudio.dbg] setQueue: secondary stopped');
    }
    _tracks = List.unmodifiable(tracks);
    _originalOrder = _tracks;
    if (_shuffleEnabled) {
      // _applyShuffle pins `tracks[initialIndex]` at position 0 and
      // sets _currentIndex = 0. Previously we then *overwrote*
      // _currentIndex with initialIndex.clamp(...), which pointed at
      // some random shuffled track instead of the user's pick — net
      // effect: shuffle on + tap song → played a different (random)
      // song. Skip the post-shuffle reassignment.
      _applyShuffle(initialIndex);
    } else {
      _currentIndex = initialIndex.clamp(0, _tracks.length - 1);
    }
    _preloadedIndex = null;
    _publishQueue();

    final t = _tracks[_currentIndex];
    _targetVolume = _rgVolumeFor(t);
    // ignore: avoid_print
    print('[digaudio.dbg] setQueue: about to setAudioSource (${t.title})');
    final src = _sourceFor(t);
    // ignore: avoid_print
    print('[digaudio.dbg] setQueue: source built, awaiting setAudioSource…');
    try {
      await _primary.setAudioSource(src);
    } catch (e, st) {
      // ignore: avoid_print
      print('[digaudio.dbg] setQueue: setAudioSource THREW: $e\n$st');
      rethrow;
    }
    // ignore: avoid_print
    print('[digaudio.dbg] setQueue: setAudioSource returned, '
        'awaiting setVolume…');
    await _primary.setVolume(_targetVolume);
    // ignore: avoid_print
    print('[digaudio.dbg] setQueue: setVolume returned, firing play() '
        '(fire-and-forget) + _onTrackChanged…');
    // DO NOT await player.play(). just_audio's `play()` returns a
    // Future that completes when playback STOPS (paused/completed/
    // stopped), not when it starts. Awaiting it blocks _onTrackChanged
    // for the entire duration of the track — so mini-player +
    // currentTrackProvider never see the new track until playback
    // ends. Years-old latent bug exposed by v0.30.7's StateNotifier
    // refactor (which made the symptom obvious because the seeded
    // initial value was null and nothing replaced it until track-end).
    unawaited(_primary.play());
    _onTrackChanged(t);
    unawaited(_preloadNextIfNeeded());
    _maybeResume(t);
  }

  Future<void> playSingle(Track t) => setQueue([t]);

  Future<void> appendToQueue(Track t) async {
    _tracks = List.unmodifiable([..._tracks, t]);
    _publishQueue();
    // Append might have introduced a new "next" (if we were at the end).
    unawaited(_preloadNextIfNeeded());
  }

  Future<void> playNext(Track t) async {
    final idx = (_currentIndex + 1).clamp(0, _tracks.length);
    _tracks = List.unmodifiable([..._tracks]..insert(idx, t));
    _publishQueue();
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
    _publishQueue();
    _preloadedIndex = null;
    unawaited(_preloadNextIfNeeded());
  }

  Future<void> removeFromQueue(int index) async {
    if (index < 0 || index >= _tracks.length) return;
    if (index == _currentIndex) return; // safer to no-op than dance around
    final list = [..._tracks]..removeAt(index);
    _tracks = List.unmodifiable(list);
    if (index < _currentIndex) _currentIndex--;
    _publishQueue();
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
        final s = _subsonicResolver().forTrack(t);
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

  MediaItem _toMediaItem(Track t, {Uri? overrideArtUri}) => MediaItem(
        id: t.uniqueKey,
        title: t.title,
        artist: t.artist,
        album: t.album,
        duration: t.duration,
        artUri: overrideArtUri ?? _artworkUri(t),
        playable: true,
      );

  Uri? _artworkUri(Track t) {
    if (t.coverArt == null) return null;
    if (t.origin == MediaOrigin.subsonic) {
      return _subsonicResolver().forTrack(t)?.coverUri(t.coverArt!);
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

  /// Notification rich actions: skip 10 s forward / back. Standard
  /// podcast-style shortcuts surfaced via MediaAction.fastForward /
  /// .rewind in _broadcastState. Clamps to track bounds (negative
  /// seek = 0; past-end = duration).
  @override
  Future<void> fastForward() async {
    final dur = _primary.duration;
    final next = _primary.position + const Duration(seconds: 10);
    await _primary.seek(dur == null ? next : (next > dur ? dur : next));
  }

  @override
  Future<void> rewind() async {
    final next = _primary.position - const Duration(seconds: 10);
    await _primary.seek(next < Duration.zero ? Duration.zero : next);
  }

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
      // Fire-and-forget — see setQueue's note.
      unawaited(_primary.play());
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
      // Fire-and-forget — see setQueue's note.
      unawaited(_primary.play());
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
    _publishQueue();
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
      // 5 controls is the Android max. Notification shows rewind / prev
      // / play-pause / next / fastForward — same shape as podcast apps.
      // Stop is no longer in the list (user swipes the notification to
      // dismiss when paused via `androidStopForegroundOnPause: true`).
      // androidCompactActionIndices [1, 2, 3] picks prev/play-pause/next
      // for the collapsed view; rewind + fastForward only appear when
      // the user expands the notification, which is the standard place
      // for them.
      controls: [
        MediaControl.rewind,
        MediaControl.skipToPrevious,
        if (playing) MediaControl.pause else MediaControl.play,
        MediaControl.skipToNext,
        MediaControl.fastForward,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.skipToPrevious,
        MediaAction.skipToNext,
        MediaAction.fastForward,
        MediaAction.rewind,
        MediaAction.setShuffleMode,
        MediaAction.setRepeatMode,
        MediaAction.setSpeed,
      },
      androidCompactActionIndices: const [1, 2, 3],
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
    await _queueController.close();
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

  /// Engine-managed index into [_tracks] for the audibly-playing track.
  /// `-1` when no queue is loaded. Do NOT use `engine.raw.currentIndex`
  /// for queue-relative reads — that's just_audio's per-source index
  /// which is always 0 in our two-player engine (each player owns one
  /// AudioSource at a time).
  int get currentIndex => _currentIndex;

  Stream<Track?> get currentTrackStream => _trackController.stream;

  Stream<List<Track>> get currentQueueStream => _queueController.stream;

  /// Single point of truth for "queue contents changed" broadcasts.
  /// Pushes to audio_service's MediaItem queue (lockscreen / Android
  /// Auto consumers) AND to our internal `_queueController`
  /// (Now Playing Queue tab + Up Next strip). Must be called after
  /// EVERY mutation of `_tracks` so the UI never reads a stale
  /// snapshot — previously some mutation paths (auto-queue append,
  /// shuffle toggle) updated audio_service but not the in-app
  /// widgets.
  void _publishQueue() {
    _publishQueue();
    _queueController.add(_tracks);
  }
}
