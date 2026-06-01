import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../audio/providers.dart';

/// Thin banner above the mini-player whenever a background download
/// is in flight. Shows the current track's title + how many are
/// still queued + a live progress bar + a Cancel button (clears the
/// pending list; in-flight download finishes — Dio doesn't easily
/// expose mid-stream cancel).
class DownloadBanner extends ConsumerWidget {
  const DownloadBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ref.watch(accentTintProvider).valueOrNull ?? brandAccent;
    final state = ref.watch(downloadQueueStateProvider).valueOrNull;
    final progressMap = ref.watch(downloadProgressProvider).valueOrNull ?? const {};
    if (state == null || !state.isActive) return const SizedBox.shrink();
    final current = state.current;
    final progressForCurrent =
        current == null ? null : (progressMap[current.uniqueKey] ?? 0.0);
    return Material(
      color: const Color(0xFF18181B),
      elevation: 2,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 2,
            child: LinearProgressIndicator(
              value: progressForCurrent,
              minHeight: 2,
              backgroundColor: const Color(0xFF333339),
              valueColor: AlwaysStoppedAnimation(accent),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Icon(Icons.download_for_offline,
                    size: 16, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    current == null
                        ? '${state.pending.length} tracks queued'
                        : 'Downloading "${current.title}"'
                            '${state.pending.isNotEmpty ? '  ·  ${state.pending.length} more' : ''}',
                    style: const TextStyle(fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ),
                if (state.pending.isNotEmpty)
                  TextButton(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      minimumSize: const Size(0, 28),
                    ),
                    onPressed: () =>
                        ref.read(downloadQueueProvider).cancelAll(),
                    child: const Text('Cancel'),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
