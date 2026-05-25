import 'dart:async';

import 'player.dart';

/// "Stop after this album" — one-shot toggle. When armed, listens for
/// the next track switch where the new track's `albumId` differs from
/// the armed one and pauses playback there. Disarms itself after
/// firing OR when the user explicitly calls `disarm()`.
///
/// Tracks without an `albumId` (e.g. some local files) effectively
/// disable the feature — the next switch will be treated as a new
/// album so playback pauses immediately. Acceptable v1; UI can warn
/// later if needed.
class AlbumModeService {
  final AudioEngine _engine;
  StreamSubscription<int?>? _sub;
  bool _armed = false;
  String? _albumId;
  final _state = StreamController<bool>.broadcast();

  AlbumModeService(this._engine);

  bool get armed => _armed;
  Stream<bool> get armedStream => _state.stream;

  /// Arm using the current track's albumId. If there's no current
  /// track, the call is a no-op so the toggle visibly stays off.
  void armForCurrent() {
    final t = _engine.currentTrack;
    if (t == null) return;
    _albumId = t.albumId;
    _armed = true;
    _state.add(true);
    _sub ??= _engine.currentIndexStream.listen(_onIndexChanged);
  }

  void disarm() {
    _armed = false;
    _albumId = null;
    _state.add(false);
  }

  void _onIndexChanged(int? i) {
    if (!_armed || i == null) return;
    final tracks = _engine.currentQueue;
    if (i >= tracks.length) return;
    if (tracks[i].albumId != _albumId) {
      _engine.pause();
      disarm();
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _state.close();
  }
}
