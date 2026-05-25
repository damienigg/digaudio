import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Non-secret playback preferences. EQ state lives here (band gains, on/off);
/// future crossfade / replay-gain settings would too. Stored in
/// `shared_preferences` — no encryption needed (no credentials), one read at
/// startup, write on every change.
class PlaybackPrefs {
  static const _kEqEnabled = 'pb.eq.enabled';
  static const _kEqGains = 'pb.eq.gains.json';
  static const _kAutoQueue = 'pb.autoqueue.enabled';
  static const _kAutoCache = 'pb.autocache.enabled';
  static const _kCacheMaxBytes = 'pb.cache.max_bytes';
  static const _kSpeed = 'pb.speed';
  static const _kCrossfadeMs = 'pb.crossfade.ms';

  /// Default cap for the auto-cache pool. Pinned downloads don't count against
  /// it. 2 GB matches what Spotify ships and survives a long road trip without
  /// thrashing the LRU. Adjustable from Settings → Playback.
  static const defaultCacheMaxBytes = 2 * 1024 * 1024 * 1024;

  bool eqEnabled = false;

  /// Band gains in dB, indexed left-to-right (low → high frequency). The list
  /// is sized at runtime from `AndroidEqualizer.parameters.bands`; we just
  /// persist what's set. Missing indices default to 0 dB.
  List<double> eqGainsDb = const [];

  /// When the playback queue is about to end, append a similar track from
  /// the library (same algorithm as the "Suggested next" hint).
  bool autoQueueEnabled = true;

  /// Stream each played Subsonic track straight into the local cache so the
  /// next listen is offline-instant. LRU-evicted by [cacheMaxBytes]; pinned
  /// downloads are never touched.
  bool autoCacheEnabled = true;

  /// Hard cap on the auto-cache pool (bytes). Pinned downloads excluded.
  int cacheMaxBytes = defaultCacheMaxBytes;

  /// Playback speed multiplier (1.0 = real-time). Restored at startup so a
  /// podcast listener doesn't have to re-set 1.5x every launch.
  double playbackSpeed = 1.0;

  /// Crossfade duration in ms (0 = off). At track end the volume ramps to 0
  /// over this window; the next track's volume ramps from 0 to 1 over the
  /// same window. Pseudo-crossfade — not a true overlap (no second player)
  /// but the perceived effect is the same for typical music.
  int crossfadeMs = 0;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    eqEnabled = p.getBool(_kEqEnabled) ?? false;
    autoQueueEnabled = p.getBool(_kAutoQueue) ?? true;
    autoCacheEnabled = p.getBool(_kAutoCache) ?? true;
    cacheMaxBytes = p.getInt(_kCacheMaxBytes) ?? defaultCacheMaxBytes;
    playbackSpeed = p.getDouble(_kSpeed) ?? 1.0;
    crossfadeMs = p.getInt(_kCrossfadeMs) ?? 0;
    final raw = p.getString(_kEqGains);
    if (raw != null && raw.isNotEmpty) {
      eqGainsDb = (jsonDecode(raw) as List).map((e) => (e as num).toDouble()).toList();
    }
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kEqEnabled, eqEnabled);
    await p.setBool(_kAutoQueue, autoQueueEnabled);
    await p.setBool(_kAutoCache, autoCacheEnabled);
    await p.setInt(_kCacheMaxBytes, cacheMaxBytes);
    await p.setDouble(_kSpeed, playbackSpeed);
    await p.setInt(_kCrossfadeMs, crossfadeMs);
    await p.setString(_kEqGains, jsonEncode(eqGainsDb));
  }
}
