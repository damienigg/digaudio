import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/providers.dart';
import '../../domain.dart';
import 'artwork.dart';
import 'theme_ext.dart';
import 'track_actions.dart';
import '../../core/dbg.dart';

/// One row in any list of tracks. Tapping plays from this index in the given
/// queue (so playback context — album/playlist — is preserved). Long-press or
/// the trailing button opens the per-track actions sheet (favorites,
/// playlists, queue ops).
class TrackTile extends ConsumerWidget {
  final List<Track> queue;
  final int index;
  final VoidCallback? onMore;
  /// When set, appended to the artist subtitle (" · <label>"). Used by the
  /// multi-server search page to surface which server each row came from.
  /// Null elsewhere = subtitle stays clean.
  final String? serverLabel;

  /// When true, the title renders in bold accent-green and a play-arrow
  /// is overlaid on the artwork — used by the Now Playing queue tab to
  /// signal which row is the current track. Defaults to false so every
  /// other caller (search, album, playlist…) renders unchanged.
  final bool isPlaying;

  const TrackTile({
    super.key,
    required this.queue,
    required this.index,
    this.onMore,
    this.serverLabel,
    this.isPlaying = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = queue[index];
    final engine = ref.watch(audioEngineProvider);
    final favKeys = ref.watch(favoriteKeysProvider).valueOrNull ?? const [];
    final isFav = favKeys.contains(t.uniqueKey);
    final cacheState = ref.watch(cacheStateProvider).valueOrNull ?? const {};
    // null = uncached, false = auto-cached (LRU-evictable), true = pinned
    final cachePinned = cacheState[t.uniqueKey];
    // Watch the ratings change-tick so star changes (set / clear via the
    // actions sheet) redraw the tile immediately.
    ref.watch(ratingsChangesProvider);
    final rating = ref.read(ratingsManagerProvider).ratingOf(t);
    final selection = ref.watch(selectionProvider);
    final selecting = selection.isNotEmpty;
    final isSelected = selection.containsKey(t.uniqueKey);
    final accent = ref.watch(accentTintProvider).valueOrNull ?? brandAccent;
    final openActions = onMore ?? () => showTrackActions(context, ref, t);

    // Long-press always toggles selection (standard mobile pattern;
    // overrides the legacy long-press = play / sheet options which are
    // now reachable via tap + the ⋮ button respectively). When already
    // in selection mode, tap also toggles instead of playing.
    return InkWell(
      onTap: selecting
          ? () => ref.read(selectionProvider.notifier).toggle(t)
          : () {
              dbg('TrackTile.onTap: index=$index, '
                  'title="${t.title}", queue.length=${queue.length}');
              engine.setQueue(queue, initialIndex: index);
            },
      onLongPress: () => ref.read(selectionProvider.notifier).toggle(t),
      child: Container(
        color: isSelected ? accent.withOpacity(0.20) : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // In selection mode, the leading 48 dp slot becomes the
            // check-circle: same footprint as the artwork it replaces
            // so the row height doesn't jump, but the tap target is
            // dedicated + unambiguous. Out of selection mode → keep
            // the artwork as-is.
            if (selecting)
              SizedBox(
                width: 48,
                height: 48,
                child: Icon(
                  isSelected
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  size: 36,
                  color: isSelected ? accent : context.textTertiary,
                ),
              )
            else
              SizedBox(
                width: 48,
                height: 48,
                child: Stack(
                  children: [
                    Artwork(
                      coverArt: t.coverArt,
                      origin: t.origin,
                      size: 48,
                      serverId: t.serverId,
                    ),
                    if (isPlaying)
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.45),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.play_arrow_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isFav) ...[
                        Icon(Icons.favorite, size: 12, color: accent),
                        const SizedBox(width: 4),
                      ],
                      if (cachePinned != null) ...[
                        Icon(Icons.download_done_rounded,
                            size: 12,
                            color: cachePinned
                                ? accent
                                : context.textDisabled),
                        const SizedBox(width: 4),
                      ],
                      if (rating > 0) ...[
                        Icon(Icons.star_rounded, size: 13, color: accent),
                        Text('$rating',
                            style: TextStyle(
                                color: accent,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                        const SizedBox(width: 4),
                      ],
                      Expanded(
                        child: Text(t.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: isPlaying
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                              fontSize: 15,
                              color: isPlaying ? accent : null,
                            )),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    serverLabel == null
                        ? t.displayArtist
                        : '${t.displayArtist} · $serverLabel',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: context.textTertiary, fontSize: 12),
                  ),
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
              tooltip: 'Track actions',
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
