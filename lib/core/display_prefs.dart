import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App-wide display preferences (theme mode today; accent colour, font
/// scale etc. tomorrow). Kept separate from `PlaybackPrefs` because the
/// concerns are unrelated — playback prefs cluster around the engine,
/// display prefs around the widget tree.
class DisplayPrefs {
  static const _kThemeMode = 'display.theme_mode';

  ThemeMode themeMode = ThemeMode.dark;

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    themeMode = switch (p.getString(_kThemeMode)) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kThemeMode, themeMode.name);
  }
}
