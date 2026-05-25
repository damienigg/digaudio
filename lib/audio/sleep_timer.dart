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
        cancel();
      } else {
        _remaining.add(r);
      }
    });
    _remaining.add(d);
  }

  void startAtEndOfTrack() {
    cancel();
    _endOfTrackSub = _engine.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed) {
        _engine.pause();
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
    _remaining.add(null);
    _endOfTrackActive.add(false);
  }

  Future<void> dispose() async {
    cancel();
    await _remaining.close();
    await _endOfTrackActive.close();
  }
}
