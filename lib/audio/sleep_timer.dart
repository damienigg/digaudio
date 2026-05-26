import 'dart:async';

import 'package:just_audio/just_audio.dart';

import 'player.dart';

/// Sleep-timer state machine. Two modes:
///   - **Duration**: pause playback after a fixed delay; ticks countdown
///     to the UI every second.
///   - **End-of-track**: pause as soon as the current track completes.
///     No countdown — the player's own processingState drives it.
///
/// Cancellable from anywhere; emits `null` when inactive so the UI can
/// trivially toggle a badge.
class SleepTimerService {
  final AudioEngine _engine;
  Timer? _timer;
  StreamSubscription<PlayerState>? _endOfTrackSub;
  DateTime? _endsAt;
  final _remaining = StreamController<Duration?>.broadcast();
  // Emits true while waiting for end-of-track, false otherwise. Lets the UI
  // distinguish "sleep at end of track" from "no timer" since both have a
  // null countdown.
  final _endOfTrackActive = StreamController<bool>.broadcast();
  // Snapshot of the engine's master volume captured the moment the
  // fade-out window opens. Restored on pause + on manual cancel so
  // the next play doesn't start at 0.
  static const _fadeOutWindowSec = 10;
  double? _preFadeVolume;

  SleepTimerService(this._engine);

  /// Live countdown stream. `null` = no duration-based timer active. UI
  /// subscribes once and renders a badge.
  Stream<Duration?> get remainingStream => _remaining.stream;
  Stream<bool> get endOfTrackActiveStream => _endOfTrackActive.stream;

  Duration? get remaining => _endsAt?.difference(DateTime.now());
  bool get endOfTrackActive => _endOfTrackSub != null;
  bool get active => _timer != null || _endOfTrackSub != null;

  void start(Duration d) {
    cancel();
    _endsAt = DateTime.now().add(d);
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      final r = remaining;
      if (r == null || r.isNegative || r.inSeconds <= 0) {
        _engine.pause();
        _restoreVolume();
        cancel();
        return;
      }
      _remaining.add(r);
      // Fade-out window: snapshot the current master volume the
      // first time we enter the window, then ramp toward 0 each
      // tick. Restored on pause + on manual cancel so the next
      // play isn't muted.
      if (r.inSeconds <= _fadeOutWindowSec) {
        _preFadeVolume ??= _engine.raw.volume;
        final ratio = r.inSeconds / _fadeOutWindowSec;
        _engine.raw.setVolume(ratio * _preFadeVolume!);
      }
    });
    _remaining.add(d);
  }

  void startAtEndOfTrack() {
    cancel();
    // Arm the engine-level gate so the auto-advance is suppressed
    // for the next end-of-track. Without this we lost a race with
    // `_onProcessingState` (it fired the swap before our listener
    // could pause) and the user heard the next track despite the
    // sleep timer.
    _engine.pauseAtEndOfTrack = true;
    _endOfTrackSub = _engine.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed) {
        // Engine already gated the advance — we only tidy our own UI
        // state (badge / `_endOfTrackActive`).
        cancel();
      }
    });
    _endOfTrackActive.add(true);
  }

  void cancel() {
    _timer?.cancel();
    _endOfTrackSub?.cancel();
    _timer = null;
    _endOfTrackSub = null;
    _endsAt = null;
    // Disarm the engine gate so a future natural end-of-track resumes
    // auto-advance behaviour.
    _engine.pauseAtEndOfTrack = false;
    _restoreVolume();
    _remaining.add(null);
    _endOfTrackActive.add(false);
  }

  /// If a fade-out was in progress, put the master volume back to its
  /// pre-fade value. Idempotent — no-op when [_preFadeVolume] is null.
  void _restoreVolume() {
    if (_preFadeVolume == null) return;
    _engine.raw.setVolume(_preFadeVolume!);
    _preFadeVolume = null;
  }

  Future<void> dispose() async {
    cancel();
    await _remaining.close();
    await _endOfTrackActive.close();
  }
}
