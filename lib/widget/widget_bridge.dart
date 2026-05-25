import 'package:flutter/services.dart';

/// Bridge to the Android-side homescreen widget. One method call
/// per update; the Kotlin handler ([WidgetChannel]) iterates every
/// active widget instance and stamps the new metadata via
/// [DigaudioWidgetProvider.pushUpdate].
///
/// Safe to call when no widget is on the homescreen — the Android
/// side iterates an empty `getAppWidgetIds` array and no-ops.
class WidgetBridge {
  static const _channel = MethodChannel('digaudio/widget');

  static Future<void> update({
    String? title,
    String? artist,
    required bool isPlaying,
    String? artworkPath,
  }) async {
    try {
      await _channel.invokeMethod<void>('update', {
        'title': title,
        'artist': artist,
        'isPlaying': isPlaying,
        'artworkPath': artworkPath,
      });
    } catch (_) {
      // Best-effort — failing to update the widget never breaks playback.
    }
  }
}
