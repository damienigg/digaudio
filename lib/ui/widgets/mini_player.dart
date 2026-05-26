import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../audio/providers.dart';
import 'artwork.dart';
import 'theme_ext.dart';

/// Persistent mini player above the bottom nav. Disappears when no queue.
class MiniPlayer extends ConsumerWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final track = ref.watch(currentTrackProvider);
    if (track == null) return const SizedBox.shrink();

    final state = ref.watch(playerStateProvider);
    final playing = state.playing;
    final engine = ref.watch(audioEngineProvider);
    final position = ref.watch(positionProvider);
    final duration = ref.watch(durationProvider) ?? Duration.zero;
    final progress = (duration.inMilliseconds == 0)
        ? 0.0
        : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

    return Material(
      color: const Color(0xFF18181B),
      child: InkWell(
        onTap: () => context.push('/now-playing'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 2,
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 2,
                backgroundColor: context.dividerSoft,
                valueColor: const AlwaysStoppedAnimation(Color(0xFF1ED760)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Row(
                children: [
                  Artwork(coverArt: track.coverArt, origin: track.origin, size: 44),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                        Text(track.displayArtist, maxLines: 1, overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: context.textTertiary, fontSize: 11)),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: playing ? 'Pause' : 'Play',
                    icon: Icon(playing ? Icons.pause : Icons.play_arrow, size: 28),
                    onPressed: () => playing ? engine.pause() : engine.play(),
                  ),
                  IconButton(
                    tooltip: 'Next track',
                    icon: const Icon(Icons.skip_next),
                    onPressed: engine.next,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
