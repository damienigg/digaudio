import 'dart:convert';

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
  static const _kMaterialYou = 'display.material_you';
  static const _kAudioGeekInfo = 'display.audio_geek_info';
  static const _kRecentSearches = 'display.recent_searches';
  static const _kDebugLogsEnabled = 'display.debug_logs';

  /// Cap on persisted recent searches — anything past this is the
  /// LRU tail and gets evicted. 10 fits comfortably in the empty
  /// state of Search without scrolling.
  static const recentSearchesCap = 10;

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

  /// Material You — when on (and the OS provides a dynamic palette,
  /// i.e. Android 12+), the app's `ColorScheme` follows the system
  /// wallpaper. Brand accent stays the fallback whenever the OS
  /// doesn't expose a palette. Default off so existing users don't
  /// see a surprise re-skin on update.
  bool materialYouEnabled = false;

  /// Show the codec / bit-depth / sample-rate / device line on Now
  /// Playing. Off by default — Android's audio mixer always runs at
  /// 48 kHz on built-in speakers so the resampling indicator fires
  /// for 99 % of tracks; the line ends up being visual noise for
  /// non-audiophile users. Opt-in via Settings → Display.
  bool audioGeekInfoEnabled = false;

  /// Whether the `[digaudio.dbg]` verbose engine + provider +
  /// mini-player prints fire in logcat. Default off so production
  /// users don't get spammed. Currently *not* wired — the prints
  /// fire unconditionally until a follow-up release switches them
  /// to gate on this flag. Surfaced now so the toggle exists when
  /// we flip the wiring.
  bool debugLogsEnabled = false;

  /// LRU-ordered list of recent search queries (most recent first).
  /// Surfaced as tappable chips on the Search empty-state so the user
  /// doesn't have to retype "daft punk" each session. Capped at
  /// [recentSearchesCap]; mutation goes through [touchRecentSearch] /
  /// [removeRecentSearch] / [clearRecentSearches] which handle dedup
  /// and persistence.
  List<String> recentSearches = const [];

  /// Move (or insert) `q` to the head of [recentSearches], dedup'd
  /// case-sensitively against existing entries, capped at the LRU
  /// limit. Returns true when the list changed (so callers can
  /// debounce-skip a no-op save).
  bool touchRecentSearch(String q) {
    final trimmed = q.trim();
    if (trimmed.isEmpty) return false;
    final next = [trimmed, ...recentSearches.where((e) => e != trimmed)];
    if (next.length > recentSearchesCap) {
      next.removeRange(recentSearchesCap, next.length);
    }
    if (next.length == recentSearches.length &&
        next.first == recentSearches.firstOrNull) {
      return false;
    }
    recentSearches = next;
    return true;
  }

  void removeRecentSearch(String q) {
    recentSearches = recentSearches.where((e) => e != q).toList();
  }

  void clearRecentSearches() {
    recentSearches = const [];
  }

  Future<void> load() async {
    final p = await SharedPreferences.getInstance();
    themeMode = switch (p.getString(_kThemeMode)) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
    longPressPlays = p.getBool(_kLongPressPlays) ?? false;
    nowPlayingTint = p.getBool(_kNowPlayingTint) ?? true;
    materialYouEnabled = p.getBool(_kMaterialYou) ?? false;
    audioGeekInfoEnabled = p.getBool(_kAudioGeekInfo) ?? false;
    debugLogsEnabled = p.getBool(_kDebugLogsEnabled) ?? false;
    final raw = p.getString(_kRecentSearches);
    if (raw != null && raw.isNotEmpty) {
      recentSearches =
          (jsonDecode(raw) as List).map((e) => e as String).toList();
    }
  }

  Future<void> save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kThemeMode, themeMode.name);
    await p.setBool(_kLongPressPlays, longPressPlays);
    await p.setBool(_kNowPlayingTint, nowPlayingTint);
    await p.setBool(_kMaterialYou, materialYouEnabled);
    await p.setBool(_kAudioGeekInfo, audioGeekInfoEnabled);
    await p.setBool(_kDebugLogsEnabled, debugLogsEnabled);
    await p.setString(_kRecentSearches, jsonEncode(recentSearches));
  }
}
