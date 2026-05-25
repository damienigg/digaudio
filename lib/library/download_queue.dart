import 'dart:async';

import '../domain.dart';
import '../subsonic/client.dart';
import 'downloads.dart';

/// Queue of pinned downloads processed one at a time.
///
/// Today's [DownloadsManager.download] is a single-shot await; if the
/// user taps Download in rapid succession or bulk-selects N tracks,
/// they want all of them eventually downloaded without waiting at
/// each tap. This wraps it: [enqueue] adds to a list, [_loop] pops
/// + downloads sequentially, [stateStream] surfaces the progress to
/// the AppShell banner.
///
/// Concurrency = 1. Concurrent downloads to one server would just
/// contend for the same connection and slow each one; serial is
/// closer to wall-clock optimum.
///
/// Cancellation: [cancelAll] clears the *pending* list. The
/// currently-running job continues — Dio's stream-write semantics
/// don't expose a clean mid-stream cancel without restructuring.
/// Acceptable for v1; the user-facing effect is "stops queuing
/// more" which is what they usually mean.
class DownloadQueueService {
  final DownloadsManager _downloads;
  final SubsonicClient? Function() _subsonic;

  final List<Track> _pending = [];
  Track? _current;
  bool _running = false;
  final _stateController = StreamController<DownloadQueueState>.broadcast();

  DownloadQueueService(this._downloads, this._subsonic);

  Stream<DownloadQueueState> get stateStream => _stateController.stream;

  DownloadQueueState get state => DownloadQueueState(
        current: _current,
        pending: List.unmodifiable(_pending),
      );

  void enqueue(Track t) {
    if (!_accept(t)) return;
    _pending.add(t);
    _emit();
    unawaited(_loop());
  }

  void enqueueAll(Iterable<Track> tracks) {
    var added = 0;
    for (final t in tracks) {
      if (!_accept(t)) continue;
      _pending.add(t);
      added++;
    }
    if (added == 0) return;
    _emit();
    unawaited(_loop());
  }

  bool _accept(Track t) {
    // Only Subsonic streams can be downloaded; local files are
    // already on disk.
    if (t.origin != MediaOrigin.subsonic) return false;
    if (_current?.uniqueKey == t.uniqueKey) return false;
    if (_pending.any((p) => p.uniqueKey == t.uniqueKey)) return false;
    return true;
  }

  void cancelAll() {
    if (_pending.isEmpty) return;
    _pending.clear();
    _emit();
  }

  Future<void> _loop() async {
    if (_running) return;
    _running = true;
    try {
      while (_pending.isNotEmpty) {
        final next = _pending.removeAt(0);
        _current = next;
        _emit();
        final s = _subsonic();
        if (s == null) continue; // active server vanished — skip
        try {
          await _downloads.download(next, s);
        } catch (_) {
          // Single failed download shouldn't kill the queue; just
          // move on. DownloadsManager itself doesn't expose a
          // failure-state stream, so the user only knows by the
          // missing badge — acceptable for v1.
        }
      }
    } finally {
      _current = null;
      _running = false;
      _emit();
    }
  }

  void _emit() => _stateController.add(state);

  Future<void> dispose() async {
    _pending.clear();
    await _stateController.close();
  }
}

class DownloadQueueState {
  final Track? current;
  final List<Track> pending;
  const DownloadQueueState({this.current, this.pending = const []});

  bool get isActive => current != null || pending.isNotEmpty;
  /// Total work units left (current job + every still-pending entry).
  int get total => pending.length + (current == null ? 0 : 1);
}
