import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';

/// Routing snapshot reported by [AudioInfoChannel] (Kotlin side).
///
/// `deviceName` is the OEM product name when known (e.g. "FiiO Q3"),
/// null for built-in devices that don't expose one.
/// `deviceType` is one of: `USB`, `Bluetooth`, `Wired`, `Speaker`,
/// `Earpiece`, `Other`.
/// `outputSampleRate` is the system mixer's preferred output rate
/// (`AudioManager.PROPERTY_OUTPUT_SAMPLE_RATE`), Hz.
class AudioRouting {
  final String? deviceName;
  final String deviceType;
  final int? outputSampleRate;
  const AudioRouting({
    required this.deviceName,
    required this.deviceType,
    required this.outputSampleRate,
  });

  /// `USB: FiiO Q3` if both known, else just the type label.
  String get label =>
      deviceName == null ? deviceType : '$deviceType: $deviceName';
}

class AudioInfoBridge {
  static const _channel = MethodChannel('digaudio/audio_info');

  static Future<AudioRouting?> getRouting() async {
    try {
      final r = await _channel.invokeMapMethod<String, dynamic>('getRouting');
      if (r == null) return null;
      return AudioRouting(
        deviceName: r['deviceName'] as String?,
        deviceType: (r['deviceType'] as String?) ?? 'Other',
        outputSampleRate: r['outputSampleRate'] as int?,
      );
    } catch (_) {
      // Best-effort — routing info missing must never break Now Playing.
      return null;
    }
  }
}

/// Re-queries the active routing every time the current track changes.
/// That's the moment the user cares — between tracks the answer stays
/// the same and there's no point polling.
final audioRoutingProvider = FutureProvider<AudioRouting?>((ref) async {
  ref.watch(currentTrackProvider);
  return AudioInfoBridge.getRouting();
});
