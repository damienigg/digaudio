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
    // Warm the engine + downloads cache as soon as the app is mounted.
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await ref.read(audioEngineProvider).init();
      await ref.read(downloadsProvider).hydrate();
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
