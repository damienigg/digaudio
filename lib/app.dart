import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'audio/providers.dart';
import 'router.dart';
import 'theme.dart';

class DigaudioApp extends ConsumerStatefulWidget {
  const DigaudioApp({super.key});
  @override
  ConsumerState<DigaudioApp> createState() => _DigaudioAppState();
}

class _DigaudioAppState extends ConsumerState<DigaudioApp> {
  late final _router = buildRouter();

  @override
  void initState() {
    super.initState();
    // main() already constructed the handler and applied persisted EQ /
    // speed before runApp. Here we only handle bookkeeping that needs a
    // Riverpod ref: mirror the speed into the reactive StateProvider for
    // the Now Playing AppBar, and start the AutoQueue listener.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final prefs = ref.read(playbackPrefsProvider);
      ref.read(playbackSpeedProvider.notifier).state = prefs.playbackSpeed;
      final autoQueue = ref.read(autoQueueProvider);
      autoQueue.enabled = prefs.autoQueueEnabled;
      autoQueue.start();
      // Periodic Subsonic ping so the offline banner appears / clears
      // without any user action.
      ref.read(serverHealthProvider).start();
      // Watch BT output device changes — applies per-device EQ
      // override when a known device becomes active.
      ref.read(btEqProvider).start();
      // Seed builtin smart playlists once. Once seeded, the flag survives
      // even if the user deletes them all — they stay deleted.
      final sp = await SharedPreferences.getInstance();
      if (sp.getBool('smart.builtins.seeded') != true) {
        await ref.read(smartPlaylistsProvider).seedBuiltins();
        await sp.setBool('smart.builtins.seeded', true);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final mode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'digaudio',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      routerConfig: _router,
    );
  }
}
