import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../domain.dart';
import 'artwork.dart';

class AlbumCard extends ConsumerWidget {
  final Album album;
  final double width;
  const AlbumCard({super.key, required this.album, this.width = 140});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return InkWell(
      onTap: () => context.push('/album/${album.origin.name}/${album.id}'),
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: width,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Artwork(coverArt: album.coverArt, origin: album.origin, size: width),
            const SizedBox(height: 8),
            Text(album.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            if (album.artist != null)
              Text(album.artist!, maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white60, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}
