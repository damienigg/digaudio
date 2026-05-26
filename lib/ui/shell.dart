import 'dart:typed_data';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../audio/providers.dart';
import '../domain.dart';
import 'widgets/download_banner.dart';
import 'widgets/mini_player.dart';
import 'widgets/selection_bar.dart';

/// The persistent bottom-nav shell: 3 branch tabs (Home / Search / Library)
/// preserve their own navigation stacks, plus a 4th "Now Playing"
/// destination that pushes the `/now-playing` route on tap WITHOUT
/// switching branch (so the back arrow returns to whichever tab the
/// user was on). The mini-player still sits above the bar — when it
/// renders it gives one-tap transport — but the Now Playing nav icon
/// is the always-reachable entry point regardless of the
/// mini-player's state.
class AppShell extends ConsumerWidget {
  final StatefulNavigationShell shell;
  const AppShell({super.key, required this.shell});

  /// First 3 entries map 1:1 to the [StatefulNavigationShell] branches.
  /// The 4th (Now Playing) is handled separately in
  /// [onDestinationSelected] — it pushes a route instead of switching
  /// branches, so the selectedIndex stays on whichever tab is current.
  static const _items = [
    (icon: Icons.home_outlined, selected: Icons.home, label: 'Home'),
    (icon: Icons.search, selected: Icons.search, label: 'Search'),
    (icon: Icons.library_music_outlined, selected: Icons.library_music, label: 'Library'),
    (icon: Icons.play_circle_outline, selected: Icons.play_circle, label: 'Now Playing'),
  ];
  static const _nowPlayingIndex = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reachable = ref.watch(serverReachableProvider).valueOrNull ?? true;
    final selecting = ref.watch(selectionProvider).isNotEmpty;
    final downloadActive =
        ref.watch(downloadQueueStateProvider).valueOrNull?.isActive ?? false;
    final bgEnabled = ref.watch(displayPrefsProvider).appBackgroundEnabled;
    return Scaffold(
      body: bgEnabled
          ? Stack(fit: StackFit.expand, children: [
              const _AppBackground(),
              shell,
            ])
          : shell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!reachable) const _OfflineBanner(),
          if (downloadActive) const DownloadBanner(),
          if (selecting) const SelectionBar(),
          const MiniPlayer(),
          NavigationBar(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: (i) {
              if (i == _nowPlayingIndex) {
                context.push('/now-playing');
              } else {
                shell.goBranch(i, initialLocation: i == shell.currentIndex);
              }
            },
            destinations: [
              for (final it in _items)
                NavigationDestination(
                    icon: Icon(it.icon),
                    selectedIcon: Icon(it.selected),
                    label: it.label),
            ],
          ),
        ],
      ),
    );
  }
}

/// Full-screen "fancy" background behind Home / Search / Library.
/// - No queue loaded → app launcher icon centred at low opacity
///   (subtle brand presence, on any theme).
/// - Track playing with artwork → blurred cover, low opacity, fills
///   the viewport. Cross-fades on track change.
/// Always behind the Scaffold's body content, never intercepts
/// taps. Opt-out via Settings → Display → "App background".
class _AppBackground extends ConsumerWidget {
  const _AppBackground();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(currentTrackProvider);
    final scaffoldBg = Theme.of(context).scaffoldBackgroundColor;
    Widget content;
    if (track == null || track.coverArt == null) {
      content = _IconBg(scaffoldBg: scaffoldBg);
    } else if (track.origin == MediaOrigin.subsonic) {
      final s = ref.watch(subsonicResolverProvider).forId(track.serverId);
      content = (s == null)
          ? _IconBg(scaffoldBg: scaffoldBg)
          : _ArtworkBg(
              key: ValueKey('${track.uniqueKey}:appbg'),
              image: CachedNetworkImageProvider(
                s.coverUri(track.coverArt!, size: 512).toString(),
              ),
              scaffoldBg: scaffoldBg,
            );
    } else {
      content = _LocalArtworkBg(
        key: ValueKey('${track.uniqueKey}:appbg'),
        coverArt: track.coverArt!,
        scaffoldBg: scaffoldBg,
      );
    }
    return IgnorePointer(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 350),
        child: content,
      ),
    );
  }
}

class _IconBg extends StatelessWidget {
  final Color scaffoldBg;
  const _IconBg({required this.scaffoldBg});
  @override
  Widget build(BuildContext context) => Container(
        color: scaffoldBg,
        alignment: Alignment.center,
        child: Opacity(
          opacity: 0.06,
          child: Image.asset(
            'assets/icon/digaudio_icon.png',
            width: 380,
            height: 380,
            fit: BoxFit.contain,
            // Decode once at the target size — Image.asset's default
            // cache is per-bytes, not per-resolution. cacheWidth keeps
            // memory bounded on big screens.
            cacheWidth: 760,
          ),
        ),
      );
}

class _ArtworkBg extends StatelessWidget {
  final ImageProvider image;
  final Color scaffoldBg;
  const _ArtworkBg({super.key, required this.image, required this.scaffoldBg});
  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          Container(color: scaffoldBg),
          // ImageFiltered applies the blur at composite time — much
          // cheaper than BackdropFilter (which re-rasterises the
          // entire layer below).
          ImageFiltered(
            imageFilter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
            child: Opacity(
              opacity: 0.22,
              child: Image(image: image, fit: BoxFit.cover),
            ),
          ),
        ],
      );
}

class _LocalArtworkBg extends ConsumerWidget {
  final String coverArt;
  final Color scaffoldBg;
  const _LocalArtworkBg(
      {super.key, required this.coverArt, required this.scaffoldBg});
  @override
  Widget build(BuildContext context, WidgetRef ref) => FutureBuilder<Uint8List?>(
        future:
            ref.read(localLibraryProvider).getArtwork(coverArt, size: 512),
        builder: (c, snap) {
          if (!snap.hasData || snap.data == null) {
            return _IconBg(scaffoldBg: scaffoldBg);
          }
          return _ArtworkBg(
            image: MemoryImage(snap.data!),
            scaffoldBg: scaffoldBg,
          );
        },
      );
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: Colors.amber.shade900,
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, size: 14, color: Colors.white),
            SizedBox(width: 6),
            Text('Server unreachable — cached + local content only',
                style: TextStyle(fontSize: 12, color: Colors.white)),
          ],
        ),
      );
}
