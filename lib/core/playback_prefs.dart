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

  bool eqEnabled = false;

  /// Band gains in dB, indexed left-to-right (low → high frequency). The list
  /// is sized at runtime from `AndroidEqualizer.parameters.bands`; we just
  /// persist what's set. Missing indices default to 0 dB.
  List<double> eqGainsDb = const [];

  /// When the playback queue is about to end, append a similar track from
  /// the library (same algorithm as the "Suggested next" hint).
  bool autoQueueEnabled = true;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    eqEnabled = p.getBool(_kEqEnabled) ?? false;
    autoQueueEnabled = p.getBool(_kAutoQueue) ?? true;
    final raw = p.getString(_kEqGains);
    if (raw != null && raw.isNotEmpty) {
      eqGainsDb = (jsonDecode(raw) as List).map((e) => (e as num).toDouble()).toList();
    }
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kEqEnabled, eqEnabled);
    await p.setBool(_kAutoQueue, autoQueueEnabled);
    await p.setString(_kEqGains, jsonEncode(eqGainsDb));
  }
}
