import 'dart:typed_data';
import 'dart:ui';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/providers.dart';
import '../../domain.dart';

/// Full-screen "fancy" background rendered globally via
/// `MaterialApp.builder` so EVERY route shows it (Home, Search,
/// Library, Album, Artist, Playlist, etc.). Per-route Scaffolds have
/// `scaffoldBackgroundColor: Colors.transparent` (set on the theme)
/// so this widget bleeds through cleanly behind their content.
///
/// State machine:
/// - No queue loaded → app launcher icon centred at low opacity
///   (subtle brand presence on either theme).
/// - Track playing with artwork → blurred cover, low opacity, fills
///   the viewport. Cross-fades on track change via AnimatedSwitcher.
///
/// `IgnorePointer` so this never intercepts taps — content above is
/// the user-interactive surface.
class AppBackground extends ConsumerWidget {
  const AppBackground({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(currentTrackProvider);
    // Solid base picked from the colour scheme so transparent
    // Scaffolds get a coherent dark/light fill underneath the
    // optional artwork overlay.
    final base = Theme.of(context).colorScheme.surface;
    Widget content;
    if (track == null || track.coverArt == null) {
      content = _IconBg(base: base);
    } else if (track.origin == MediaOrigin.subsonic) {
      final s = ref.watch(subsonicResolverProvider).forId(track.serverId);
      content = (s == null)
          ? _IconBg(base: base)
          : _ArtworkBg(
              key: ValueKey('${track.uniqueKey}:appbg'),
              image: CachedNetworkImageProvider(
                s.coverUri(track.coverArt!, size: 512).toString(),
                cacheKey: '${track.uniqueKey}:appbg',
              ),
              base: base,
            );
    } else {
      content = _LocalArtworkBg(
        key: ValueKey('${track.uniqueKey}:appbg'),
        coverArt: track.coverArt!,
        base: base,
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
  final Color base;
  const _IconBg({required this.base});
  @override
  Widget build(BuildContext context) => Container(
        color: base,
        alignment: Alignment.center,
        child: Opacity(
          opacity: 0.06,
          child: Image.asset(
            'assets/icon/digaudio_icon.png',
            width: 380,
            height: 380,
            fit: BoxFit.contain,
            cacheWidth: 760,
          ),
        ),
      );
}

class _ArtworkBg extends StatelessWidget {
  final ImageProvider image;
  final Color base;
  const _ArtworkBg({super.key, required this.image, required this.base});
  @override
  Widget build(BuildContext context) => Stack(
        fit: StackFit.expand,
        children: [
          Container(color: base),
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
  final Color base;
  const _LocalArtworkBg(
      {super.key, required this.coverArt, required this.base});
  @override
  Widget build(BuildContext context, WidgetRef ref) =>
      FutureBuilder<Uint8List?>(
        future: ref.read(localLibraryProvider).getArtwork(coverArt, size: 512),
        builder: (c, snap) {
          if (!snap.hasData || snap.data == null) {
            return _IconBg(base: base);
          }
          return _ArtworkBg(image: MemoryImage(snap.data!), base: base);
        },
      );
}
