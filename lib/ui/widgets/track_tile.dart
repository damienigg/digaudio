import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/providers.dart';
import '../../domain.dart';
import 'artwork.dart';
import 'theme_ext.dart';
import 'track_actions.dart';

/// One row in any list of tracks. Tapping plays from this index in the given
/// queue (so playback context — album/playlist — is preserved). Long-press or
/// the trailing button opens the per-track actions sheet (favorites,
/// playlists, queue ops).
class TrackTile extends ConsumerWidget {
  final List<Track> queue;
  final int index;
  final VoidCallback? onMore;

  const TrackTile({super.key, required this.queue, required this.index, this.onMore});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = queue[index];
    final engine = ref.watch(audioEngineProvider);
    final favKeys = ref.watch(favoriteKeysProvider).valueOrNull ?? const [];
    final isFav = favKeys.contains(t.uniqueKey);
    final cacheState = ref.watch(cacheStateProvider).valueOrNull ?? const {};
    // null = uncached, false = auto-cached (LRU-evictable), true = pinned
    final cachePinned = cacheState[t.uniqueKey];
    final openActions = onMore ?? () => showTrackActions(context, ref, t);
    return InkWell(
      onTap: () => engine.setQueue(queue, initialIndex: index),
      onLongPress: openActions,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Artwork(coverArt: t.coverArt, origin: t.origin, size: 48),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isFav) ...[
                        const Icon(Icons.favorite, size: 12, color: Color(0xFF1ED760)),
                        const SizedBox(width: 4),
                      ],
                      if (cachePinned != null) ...[
                        Icon(Icons.download_done_rounded,
                            size: 12,
                            color: cachePinned ? const Color(0xFF1ED760) : context.textDisabled),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(t.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(t.displayArtist, maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: context.textTertiary, fontSize: 12)),
                ],
              ),
            ),
            if (t.duration != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(_fmt(t.duration!),
                    style: TextStyle(color: context.textMuted, fontSize: 12, fontFeatures: const [FontFeature.tabularFigures()])),
              ),
            IconButton(
              icon: Icon(Icons.more_vert, color: context.textMuted),
              onPressed: openActions,
            ),
          ],
        ),
      ),
    );
  }
}

String _fmt(Duration d) {
  final m = d.inMinutes;
  final s = d.inSeconds % 60;
  return '$m:${s.toString().padLeft(2, '0')}';
}
