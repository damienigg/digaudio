import 'package:flutter/services.dart';

/// Thin wrapper over the Android `digaudio/voice` MethodChannel.
/// Returns the recognised text (top hypothesis) or null if the user
/// cancelled / no recogniser is installed / nothing was captured.
class VoiceBridge {
  static const _ch = MethodChannel('digaudio/voice');

  static Future<String?> recognize() async {
    try {
      final r = await _ch.invokeMethod<String?>('recognize');
      final t = r?.trim();
      return (t == null || t.isEmpty) ? null : t;
    } catch (_) {
      return null;
    }
  }
}
