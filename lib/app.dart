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
    // main() already constructed the handler and applied persisted EQ /
    // speed before runApp. Here we only handle bookkeeping that needs a
    // Riverpod ref: mirror the speed into the reactive StateProvider for
    // the Now Playing AppBar, and start the AutoQueue listener.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final prefs = ref.read(playbackPrefsProvider);
      ref.read(playbackSpeedProvider.notifier).state = prefs.playbackSpeed;
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
