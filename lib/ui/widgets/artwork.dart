import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/providers.dart';
import '../../domain.dart';

/// Source-agnostic artwork renderer.
///
/// - Subsonic: cached network image via the Subsonic `getCoverArt` URL.
/// - Local:    PNG bytes fetched from our own MediaStore MethodChannel.
/// - Missing:  a soft placeholder — no flash of unstyled content.
///
/// Reads its dependencies (Subsonic client, LocalLibrary) from Riverpod so
/// every caller is just `Artwork(coverArt:..., origin:..., size:...)`.
class Artwork extends ConsumerWidget {
  final String? coverArt;
  final MediaOrigin origin;
  final double size;
  final BorderRadius? borderRadius;

  const Artwork({
    super.key,
    required this.origin,
    required this.coverArt,
    this.size = 56,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final br = borderRadius ?? BorderRadius.circular(6);
    Widget child;
    if (coverArt == null) {
      child = _placeholder();
    } else if (origin == MediaOrigin.subsonic) {
      final s = ref.watch(subsonicProvider);
      child = s == null
          ? _placeholder()
          : CachedNetworkImage(
              imageUrl: s.coverUri(coverArt!, size: size.toInt() * 2).toString(),
              width: size,
              height: size,
              fit: BoxFit.cover,
              placeholder: (_, __) => _placeholder(),
              errorWidget: (_, __, ___) => _placeholder(),
            );
    } else {
      child = FutureBuilder<Uint8List?>(
        future: ref.read(localLibraryProvider).getArtwork(coverArt!, size: size.toInt() * 2),
        builder: (_, snap) {
          if (!snap.hasData || snap.data == null) return _placeholder();
          return Image.memory(snap.data!, width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true);
        },
      );
    }
    return ClipRRect(borderRadius: br, child: SizedBox(width: size, height: size, child: child));
  }

  Widget _placeholder() => Container(
        width: size,
        height: size,
        color: const Color(0xFF1E1E22),
        child: Icon(Icons.music_note, color: Colors.white.withOpacity(0.35), size: size * 0.5),
      );
}
