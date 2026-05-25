import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide display preferences (theme mode today; accent colour, font
/// scale etc. tomorrow). Kept separate from `PlaybackPrefs` because the
/// concerns are unrelated — playback prefs cluster around the engine,
/// display prefs around the widget tree.
class DisplayPrefs {
  static const _kThemeMode = 'display.theme_mode';
  static const _kLongPressPlays = 'display.long_press_plays';
  static const _kNowPlayingTint = 'display.now_playing_tint';

  ThemeMode themeMode = ThemeMode.dark;

  /// When true, long-pressing a track tile plays the track (queue =
  /// surrounding list, just like tap); the actions sheet then moves to
  /// the trailing ⋮ button only. Power-user toggle for the "I tap to
  /// browse, hold to start playing fast" workflow.
  bool longPressPlays = false;

  /// Now Playing background uses a tint derived from the current
  /// artwork's dominant colour (via palette_generator). Default on —
  /// adds life. Toggle off if the colour shifts are distracting.
  bool nowPlayingTint = true;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    themeMode = switch (p.getString(_kThemeMode)) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
    longPressPlays = p.getBool(_kLongPressPlays) ?? false;
    nowPlayingTint = p.getBool(_kNowPlayingTint) ?? true;
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kThemeMode, themeMode.name);
    await p.setBool(_kLongPressPlays, longPressPlays);
    await p.setBool(_kNowPlayingTint, nowPlayingTint);
  }
}
