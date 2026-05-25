import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    // Warm the engine + downloads cache + playback prefs as soon as the app
    // is mounted. EQ is applied only after a track starts playing (Android
    // attaches the effect to the active audio session), but we restore the
    // saved enabled-state + gains here so the first track honours them.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Order matters: the engine resolves cache paths + reads
      // autoCacheEnabled at source-build time, so DownloadsManager.hydrate()
      // and PlaybackPrefs.load() must complete before any track plays.
      await ref.read(downloadsProvider).hydrate();
      final prefs = ref.read(playbackPrefsProvider);
      await prefs.load();
      final engine = ref.read(audioEngineProvider);
      await engine.init();
      await engine.setEqEnabled(prefs.eqEnabled);
      if (prefs.eqGainsDb.isNotEmpty) {
        await engine.applyEqGains(prefs.eqGainsDb);
      }
      // Auto-queue similar songs as the playback queue runs out. The
      // listener is always attached; `enabled` gates the behaviour and is
      // restored from PlaybackPrefs.
      final autoQueue = ref.read(autoQueueProvider);
      autoQueue.enabled = prefs.autoQueueEnabled;
      autoQueue.start();
    });
  }

  @override
  Widget build(BuildContext context) => MaterialApp.router(
        title: 'digaudio',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.dark(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.dark,
        routerConfig: _router,
      );
}
