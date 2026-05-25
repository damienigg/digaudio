import 'dart:typed_data';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/providers.dart';
import '../../domain.dart';
import 'theme_ext.dart';

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
  /// Originating server for Subsonic art. Null = use active server
  /// (covers local artwork + legacy callers that don't know about
  /// multi-server search). Search results stamp the right id so a
  /// cover from server B doesn't get fetched from active server A.
  final String? serverId;

  const Artwork({
    super.key,
    required this.origin,
    required this.coverArt,
    this.size = 56,
    this.borderRadius,
    this.serverId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final br = borderRadius ?? BorderRadius.circular(6);
    Widget child;
    if (coverArt == null) {
      child = _placeholder(context);
    } else if (origin == MediaOrigin.subsonic) {
      final s = ref.watch(subsonicResolverProvider).forId(serverId);
      child = s == null
          ? _placeholder(context)
          : CachedNetworkImage(
              imageUrl: s.coverUri(coverArt!, size: size.toInt() * 2).toString(),
              width: size,
              height: size,
              fit: BoxFit.cover,
              placeholder: (c, __) => _placeholder(c),
              errorWidget: (c, __, ___) => _placeholder(c),
            );
    } else {
      child = FutureBuilder<Uint8List?>(
        future: ref.read(localLibraryProvider).getArtwork(coverArt!, size: size.toInt() * 2),
        builder: (c, snap) {
          if (!snap.hasData || snap.data == null) return _placeholder(c);
          return Image.memory(snap.data!, width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true);
        },
      );
    }
    return ClipRRect(borderRadius: br, child: SizedBox(width: size, height: size, child: child));
  }

  Widget _placeholder(BuildContext context) => Container(
        width: size,
        height: size,
        color: const Color(0xFF1E1E22),
        child: Icon(Icons.music_note, color: context.textPrimary.withOpacity(0.35), size: size * 0.5),
      );
}
