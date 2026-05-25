import 'dart:async';
import 'dart:convert';

import 'package:audio_session/audio_session.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/playback_prefs.dart';
import 'player.dart';

/// Per-Bluetooth-device EQ override. The default EQ
/// (`PlaybackPrefs.eqGainsDb`) is always what sliders + presets
/// edit; this service kicks in only when a known BT device becomes
/// the active output and an override has been saved for it.
///
/// Storage key per device = `"<name>|<type.name>"` so a wired
/// "speaker" and a BT "speaker" with the same name don't collide.
/// When the active BT device disconnects (or any device change
/// leaves us without a saved-override BT device), we revert to the
/// default gains.
class BtEqService {
  static const _kProfiles = 'pb.eq.bt.profiles';

  final AudioEngine _engine;
  final Future<List<double>> Function() _defaultGains;
  final PlaybackPrefs _prefs;
  StreamSubscription<AudioDevicesChangedEvent>? _sub;
  String? _activeKey;
  final _activeKeyStream = StreamController<String?>.broadcast();

  BtEqService(this._engine, this._defaultGains, this._prefs);

  /// Currently-active BT device key, or null. UI label.
  Stream<String?> get activeKeyStream => _activeKeyStream.stream;
  String? get activeKey => _activeKey;

  Future<Map<String, List<double>>> profiles() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kProfiles);
    if (raw == null || raw.isEmpty) return {};
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return m.map((k, v) => MapEntry(
        k, (v as List).map((e) => (e as num).toDouble()).toList()));
  }

  Future<void> _writeProfiles(Map<String, List<double>> m) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kProfiles, jsonEncode(m));
  }

  Future<void> saveCurrentAs(String key, List<double> gains) async {
    final m = await profiles();
    m[key] = gains;
    await _writeProfiles(m);
    if (key == _activeKey) await _engine.applyEqGains(gains);
  }

  Future<void> forget(String key) async {
    final m = await profiles();
    m.remove(key);
    await _writeProfiles(m);
    if (key == _activeKey) {
      await _engine.applyEqGains(await _defaultGains());
    }
  }

  Future<void> start() async {
    final session = await AudioSession.instance;
    // Apply whatever's currently active right now (cold start).
    await _onDevicesChanged(await session.getDevices());
    _sub = session.devicesChangedEventStream.listen((_) async {
      await _onDevicesChanged(await session.getDevices());
    });
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    await _activeKeyStream.close();
  }

  Future<void> _onDevicesChanged(Set<AudioDevice> devices) async {
    final bt = devices.firstWhere(
      (d) =>
          d.isOutput &&
          (d.type == AudioDeviceType.bluetoothA2dp ||
              d.type == AudioDeviceType.bluetoothLe ||
              d.type == AudioDeviceType.bluetoothSco),
      orElse: () => AudioDevice(
          id: '', name: '', isInput: false, isOutput: false, type: AudioDeviceType.unknown),
    );
    final newKey = bt.name.isEmpty ? null : '${bt.name}|${bt.type.name}';
    if (newKey == _activeKey) return;
    final wasNull = _activeKey == null;
    _activeKey = newKey;
    _activeKeyStream.add(newKey);

    final m = await profiles();
    if (newKey != null && m.containsKey(newKey)) {
      await _engine.applyEqGains(m[newKey]!);
    } else {
      // No saved override for the new active device → fall back to
      // whatever the user's default EQ is.
      await _engine.applyEqGains(await _defaultGains());
    }

    // Auto-play on BT connect: when a BT output just became active
    // (was null, now isn't), the user opted in, the queue isn't
    // empty, and we're not already playing → kick playback off.
    if (newKey != null && wasNull && _prefs.autoPlayOnBtConnect) {
      final state = _engine.raw.playerState;
      if (_engine.currentQueue.isNotEmpty && !state.playing) {
        unawaited(_engine.play());
      }
    }
  }
}
