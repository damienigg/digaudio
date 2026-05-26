// ignore_for_file: avoid_print

/// Runtime gate for `[digaudio.dbg]` verbose prints. Wired to
/// `DisplayPrefs.debugLogsEnabled` — flipped at boot (after prefs load)
/// and on every toggle in Settings → Display. Off by default so users
/// don't get spammed in logcat; flipping the Settings toggle takes
/// effect immediately, no restart.
bool dbgEnabled = false;

@pragma('vm:prefer-inline')
void dbg(String msg) {
  if (!dbgEnabled) return;
  print('[digaudio.dbg] $msg');
}
