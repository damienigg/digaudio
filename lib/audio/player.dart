import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../core/playback_prefs.dart';
import '../domain.dart';
import '../library/downloads.dart';
import '../library/local.dart';
import '../subsonic/client.dart';

/// digaudio's single audio engine.
///
/// Wraps [just_audio] with a Subsonic-aware source builder and a
/// [just_audio_background] tag mapping so the lockscreen / Android Auto /
/// CarPlay UI get title, artist and artwork for free. Subsonic streams are
/// piped through [LockCachingAudioSource] so the bytes played are written
/// straight into the on-disk pool ([DownloadsManager]) — one network
/// roundtrip serves both playback and offline re-listen.
class AudioEngine {
  final SubsonicClient? Function() _subsonic;
  final DownloadsManager _cache;
  final PlaybackPrefs _prefs;
  final AndroidEqualizer _equalizer = AndroidEqualizer();
  late final AudioPlayer _player = AudioPlayer(
    audioPipeline: AudioPipeline(androidAudioEffects: [_equalizer]),
  );
  ConcatenatingAudioSource? _queue;
  List<Track> _tracks = const [];
  StreamSubscription<int?>? _indexSub;
  StreamSubscription<Duration>? _posSub;
  // Scrobble bookkeeping: which trackKey we last reported "now playing" for,
  // and whether we've already fired the definitive (submission=true) scrobble
  // for the currently-playing track.
  String? _nowPlayingKey;
  bool _scrobbledCurrent = false;

  AudioEngine({
    required SubsonicClient? Function() subsonic,
    required DownloadsManager cache,
    required PlaybackPrefs prefs,
  })  : _subsonic = subsonic,
        _cache = cache,
        _prefs = prefs;

  AudioPlayer get raw => _player;
  AndroidEqualizer get equalizer => _equalizer;
  List<Track> get currentQueue => _tracks;

  Future<void> init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
    // On every track switch: refresh LRU access time, fire a Subsonic "now
    // playing" hint, and reset the played-threshold tracker so the next
    // scrobble(true) only fires for the new track.
    _indexSub = _player.currentIndexStream.listen((i) {
      if (i == null || i < 0 || i >= _tracks.length) return;
      final t = _tracks[i];
      _cache.touch(t.uniqueKey);
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

  /// Read-only access to the actual band layout the OS reports (band count
  /// and center frequencies are device-dependent — Android typically returns
  /// 5 bands centered around 60Hz / 230Hz / 910Hz / 3.6kHz / 14kHz).
  Future<AndroidEqualizerParameters> get eqParameters => _equalizer.parameters;

  Future<void> setEqEnabled(bool on) => _equalizer.setEnabled(on);

  /// Applies a list of gains (dB) to the EQ bands, truncating / padding as
  /// needed. Out-of-range bands are skipped silently.
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
  }

  Future<void> playNext(Track t) async {
    if (_queue == null) return playSingle(t);
    final idx = (_player.currentIndex ?? 0) + 1;
    await _queue!.insert(idx, _sourceFor(t));
    _tracks = [..._tracks]..insert(idx, t);
  }

  AudioSource _sourceFor(Track t) {
    final tag = MediaItem(
      id: t.uniqueKey,
      title: t.title,
      artist: t.artist,
      album: t.album,
      duration: t.duration,
      artUri: _artworkUri(t),
    );
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

  // --- Transport -----------------------------------------------------------

  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();
  Future<void> stop() => _player.stop();
  Future<void> seek(Duration d) => _player.seek(d);
  Future<void> next() => _player.seekToNext();
  Future<void> previous() => _player.seekToPrevious();
  Future<void> seekToIndex(int i) => _player.seek(Duration.zero, index: i);
  Future<void> setShuffle(bool on) async {
    if (on) await _player.shuffle();
    await _player.setShuffleModeEnabled(on);
  }

  Future<void> setRepeat(LoopMode mode) => _player.setLoopMode(mode);
  Future<void> setVolume(double v) => _player.setVolume(v);
  Future<void> setSpeed(double s) => _player.setSpeed(s);

  Future<void> dispose() async {
    await _indexSub?.cancel();
    await _posSub?.cancel();
    await _player.dispose();
  }

  // --- Streams (re-exported for providers) ---------------------------------

  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get bufferedPositionStream => _player.bufferedPositionStream.cast<Duration?>();
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

  Stream<Track?> get currentTrackStream =>
      _player.currentIndexStream.map((i) => (i == null || i < 0 || i >= _tracks.length) ? null : _tracks[i]);
}
