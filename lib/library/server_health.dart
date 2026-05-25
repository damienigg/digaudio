import 'dart:async';

import '../subsonic/client.dart';

/// Periodic Subsonic ping + reactive reachability flag.
///
/// Two trigger paths:
///   - Background timer (every 60 s) — catches recovery without the user
///     having to retry anything.
///   - [markUnreachable] from any caller that just got a network error —
///     flips the flag immediately, no wait for the next tick. The next
///     tick then re-checks for recovery.
///
/// Emits `false` only after a probe failure; emits `true` when a probe
/// succeeds. The initial state is optimistic (`true`) so the UI doesn't
/// show "offline" before the first ping fires.
class ServerHealthService {
  final SubsonicClient? Function() _client;
  final Duration interval;
  Timer? _timer;
  bool _reachable = true;
  final _stream = StreamController<bool>.broadcast();

  ServerHealthService(this._client, {this.interval = const Duration(seconds: 60)});

  bool get reachable => _reachable;
  Stream<bool> get stream => _stream.stream;

  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(interval, (_) => _probe());
    _probe(); // first check on start
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// Force the flag to `false` after a caller observed a real failure
  /// (e.g. a browse call that threw). Idempotent.
  void markUnreachable() {
    if (_reachable) {
      _reachable = false;
      _stream.add(false);
    }
  }

  Future<void> _probe() async {
    final c = _client();
    if (c == null) {
      // No active server == nothing to be reachable. Keep last state to
      // avoid flapping the UI in the seconds between server switches.
      return;
    }
    final ok = await c.ping();
    if (ok != _reachable) {
      _reachable = ok;
      _stream.add(ok);
    }
  }

  Future<void> dispose() async {
    _timer?.cancel();
    await _stream.close();
  }
}
