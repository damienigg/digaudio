import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../domain.dart';
import '../library/local.dart';
import '../subsonic/client.dart';

/// digaudio's single audio engine.
///
/// Wraps [just_audio] with a Subsonic-aware URI resolver and a
/// [just_audio_background] tag mapping so the lockscreen / Android Auto /
/// CarPlay UI get title, artist and artwork for free. The engine never
/// branches on origin at the player level — only when building the URI.
class AudioEngine {
  final SubsonicClient? Function() _subsonic;
  final String? Function(Track) _downloadPathFor;
  final AudioPlayer _player = AudioPlayer();
  ConcatenatingAudioSource? _queue;
  List<Track> _tracks = const [];

  AudioEngine({
    required SubsonicClient? Function() subsonic,
    required String? Function(Track) downloadPathFor,
  })  : _subsonic = subsonic,
        _downloadPathFor = downloadPathFor;

  AudioPlayer get raw => _player;
  List<Track> get currentQueue => _tracks;

  Future<void> init() async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.music());
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
    final uri = _uriFor(t);
    final tag = MediaItem(
      id: t.uniqueKey,
      title: t.title,
      artist: t.artist,
      album: t.album,
      duration: t.duration,
      artUri: _artworkUri(t),
    );
    return AudioSource.uri(uri, tag: tag);
  }

  Uri _uriFor(Track t) {
    // Offline cache always wins over remote streaming.
    final cached = _downloadPathFor(t);
    if (cached != null && File(cached).existsSync()) {
      return Uri.file(cached);
    }
    switch (t.origin) {
      case MediaOrigin.local:
        return Uri.parse(t.localContentUri);
      case MediaOrigin.subsonic:
        final s = _subsonic();
        if (s == null) throw StateError('No Subsonic server configured');
        return s.streamUri(t.id);
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

  Future<void> dispose() => _player.dispose();

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
