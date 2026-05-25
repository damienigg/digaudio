import 'package:audio_service/audio_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';
import 'audio/player.dart';
import 'audio/providers.dart';

/// Boot order matters: build the Riverpod container, hydrate the prefs +
/// downloads pool the engine reads at source-build time, **then** spin up
/// the AudioService handler. Android Auto / MediaSession need a single
/// process-lifetime handler instance — created here, registered into the
/// Riverpod graph via [registerAudioEngine].
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = ProviderContainer();

  // Pre-hydrate the state the handler reads on its first source build.
  await container.read(downloadsProvider).hydrate();
  final prefs = container.read(playbackPrefsProvider);
  await prefs.load();
  final display = container.read(displayPrefsProvider);
  await display.load();
  container.read(themeModeProvider.notifier).state = display.themeMode;

  final handler = await AudioService.init(
    builder: () => AudioEngine(
      subsonic: () => container.read(subsonicProvider),
      resolver: () => container.read(trackResolverProvider),
      favorites: container.read(favoritesProvider),
      cache: container.read(downloadsProvider),
      prefs: prefs,
      history: container.read(playHistoryProvider),
      positions: container.read(trackPositionsProvider),
      listenbrainz: () => container.read(listenbrainzClientProvider),
    ),
    config: const AudioServiceConfig(
      androidNotificationChannelId: 'com.digaudio.audio',
      androidNotificationChannelName: 'digaudio playback',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidNotificationIcon: 'mipmap/ic_launcher',
    ),
  );
  await handler.init();

  // Restore persisted EQ + speed before the first track plays.
  await handler.setEqEnabled(prefs.eqEnabled);
  if (prefs.eqGainsDb.isNotEmpty) await handler.applyEqGains(prefs.eqGainsDb);
  if (prefs.playbackSpeed != 1.0) await handler.setSpeed(prefs.playbackSpeed);

  registerAudioEngine(handler);

  runApp(UncontrolledProviderScope(
    container: container,
    child: const DigaudioApp(),
  ));
}
