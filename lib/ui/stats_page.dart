import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/providers.dart';
import '../domain.dart';
import '../library/collections.dart';
import '../library/play_history.dart';
import 'widgets/artwork.dart';

const _accent = Color(0xFF1ED760);

/// Listening stats + "Most played" smart mix. Time window switchable
/// (30 d / 90 d / all time). Top-tracks list is also the seed for the
/// smart-mix button — one query, two surfaces.
class StatsPage extends ConsumerStatefulWidget {
  const StatsPage({super.key});
  @override
  ConsumerState<StatsPage> createState() => _StatsState();
}

class _StatsState extends ConsumerState<StatsPage> {
  int? _sinceDays = 30;
  Future<_StatsData>? _future;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final history = ref.read(playHistoryProvider);
    final resolver = ref.read(trackResolverProvider);
    setState(() => _future = _load(history, resolver, _sinceDays));
  }

  /// Single round-trip: pull top 50 trackKeys, resolve them once, then
  /// derive top-tracks (first 10) AND top-artists (group all 50). This
  /// is the same payload powering the "Most played" smart-mix button.
  /// Streaks + heatmap are window-independent (always full history /
  /// last 30 days respectively).
  static Future<_StatsData> _load(
      PlayHistoryManager h, TrackResolver r, int? sinceDays) async {
    final total = await h.totalPlays(sinceDays: sinceDays);
    final unique = await h.uniqueTracks(sinceDays: sinceDays);
    final days = await h.listeningDays(sinceDays: sinceDays);
    final streaks = await h.streaks();
    final heatmap = await h.dailyCounts(days: 30);
    final tops = await h.topTracks(sinceDays: sinceDays, limit: 50);
    final tracks = <(Track, int)>[];
    for (final e in tops) {
      final t = await r.resolve(e.trackKey);
      if (t != null) tracks.add((t, e.count));
    }
    final artistCounts = <String, int>{};
    for (final (t, c) in tracks) {
      final a = t.displayArtist;
      artistCounts[a] = (artistCounts[a] ?? 0) + c;
    }
    final topArtists = artistCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return _StatsData(
      totalPlays: total,
      uniqueTracks: unique,
      listeningDays: days,
      currentStreak: streaks.current,
      longestStreak: streaks.longest,
      heatmap: heatmap,
      topTracks: tracks.take(10).toList(),
      topArtists: topArtists.take(10).map((e) => (e.key, e.value)).toList(),
      mixSeed: tracks.map((e) => e.$1).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Stats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: FutureBuilder<_StatsData>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('${snap.error}',
                style: const TextStyle(color: Colors.redAccent)));
          }
          final data = snap.data!;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _RangePicker(value: _sinceDays, onChanged: (d) {
                _sinceDays = d;
                _reload();
              }),
              const SizedBox(height: 16),
              _Totals(data: data),
              const SizedBox(height: 12),
              _Streaks(current: data.currentStreak, longest: data.longestStreak),
              const SizedBox(height: 16),
              const _SectionHeader('Last 30 days'),
              _Heatmap(counts: data.heatmap),
              const SizedBox(height: 16),
              if (data.mixSeed.isNotEmpty) ...[
                _PlayMixButton(seed: data.mixSeed),
                const SizedBox(height: 16),
              ],
              const _SectionHeader('Top tracks'),
              if (data.topTracks.isEmpty)
                const _EmptyHint('No plays in this window yet.')
              else
                ...data.topTracks.map((e) => _TopTrackRow(track: e.$1, count: e.$2)),
              const SizedBox(height: 16),
              const _SectionHeader('Top artists'),
              if (data.topArtists.isEmpty)
                const _EmptyHint('No plays in this window yet.')
              else
                ...data.topArtists.map((e) => _TopArtistRow(name: e.$1, count: e.$2)),
            ],
          );
        },
      ),
    );
  }
}

class _StatsData {
  final int totalPlays;
  final int uniqueTracks;
  final int listeningDays;
  final int currentStreak;
  final int longestStreak;
  /// `date → play count` for the last 30 days; missing keys = 0.
  final Map<DateTime, int> heatmap;
  final List<(Track, int)> topTracks;
  final List<(String, int)> topArtists;
  // Full 50-track seed for the "Most played" smart mix. Order = play-count
  // descending, so the queue is itself a rank-sorted mix.
  final List<Track> mixSeed;
  _StatsData({
    required this.totalPlays,
    required this.uniqueTracks,
    required this.listeningDays,
    required this.currentStreak,
    required this.longestStreak,
    required this.heatmap,
    required this.topTracks,
    required this.topArtists,
    required this.mixSeed,
  });
}

class _RangePicker extends StatelessWidget {
  final int? value;
  final ValueChanged<int?> onChanged;
  const _RangePicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    Widget chip(String label, int? days) => Padding(
          padding: const EdgeInsets.only(right: 8),
          child: ChoiceChip(
            label: Text(label),
            selected: value == days,
            onSelected: (_) => onChanged(days),
            selectedColor: _accent,
            labelStyle: TextStyle(color: value == days ? Colors.black : Colors.white70),
          ),
        );
    return Row(children: [chip('30 d', 30), chip('90 d', 90), chip('All time', null)]);
  }
}

class _Totals extends StatelessWidget {
  final _StatsData data;
  const _Totals({required this.data});
  @override
  Widget build(BuildContext context) => Row(
        children: [
          _Metric(value: '${data.totalPlays}', label: 'plays'),
          _Metric(value: '${data.uniqueTracks}', label: 'unique tracks'),
          _Metric(value: '${data.listeningDays}', label: 'listening days'),
        ],
      );
}

class _Metric extends StatelessWidget {
  final String value;
  final String label;
  const _Metric({required this.value, required this.label});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text(value,
                style: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: _accent,
                    fontFeatures: [FontFeature.tabularFigures()])),
            Text(label,
                style: const TextStyle(color: Colors.white60, fontSize: 11)),
          ],
        ),
      );
}

/// Two compact streak counters (current / longest), styled like the
/// other metrics but flagged with a flame so they read as a separate
/// kind of stat ("you've listened N days in a row").
class _Streaks extends StatelessWidget {
  final int current;
  final int longest;
  const _Streaks({required this.current, required this.longest});
  @override
  Widget build(BuildContext context) => Row(
        children: [
          _StreakChip(label: 'current streak', days: current),
          const SizedBox(width: 12),
          _StreakChip(label: 'longest streak', days: longest),
        ],
      );
}

class _StreakChip extends StatelessWidget {
  final String label;
  final int days;
  const _StreakChip({required this.label, required this.days});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white10,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              const Icon(Icons.local_fire_department, color: _accent, size: 22),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$days d',
                      style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                          fontFeatures: [FontFeature.tabularFigures()])),
                  Text(label,
                      style: const TextStyle(color: Colors.white60, fontSize: 10)),
                ],
              ),
            ],
          ),
        ),
      );
}

/// 30-day heatmap row. Each square = one day, intensity = play count
/// normalised against the window's max. Days with zero plays render as
/// white12 (visible but inert). Oldest left, today right.
class _Heatmap extends StatelessWidget {
  final Map<DateTime, int> counts;
  const _Heatmap({required this.counts});

  @override
  Widget build(BuildContext context) {
    final maxCount = counts.values.fold<int>(0, (a, b) => b > a ? b : a);
    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    return SizedBox(
      height: 16,
      child: Row(
        children: [
          for (var i = 29; i >= 0; i--)
            Expanded(
              child: () {
                final d = today.subtract(Duration(days: i));
                final c = counts[d] ?? 0;
                final t = maxCount == 0 ? 0.0 : (c / maxCount).clamp(0.0, 1.0);
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: BoxDecoration(
                    color: c == 0
                        ? Colors.white10
                        : Color.lerp(Colors.white24, _accent, t),
                    borderRadius: BorderRadius.circular(2),
                  ),
                );
              }(),
            ),
        ],
      ),
    );
  }
}

class _PlayMixButton extends ConsumerWidget {
  final List<Track> seed;
  const _PlayMixButton({required this.seed});
  @override
  Widget build(BuildContext context, WidgetRef ref) => FilledButton.icon(
        icon: const Icon(Icons.play_arrow),
        label: Text('Play "Most played" (${seed.length} tracks)'),
        onPressed: () => ref.read(audioEngineProvider).setQueue(seed),
        style: FilledButton.styleFrom(
          backgroundColor: _accent,
          foregroundColor: Colors.black,
          minimumSize: const Size.fromHeight(44),
        ),
      );
}

class _TopTrackRow extends StatelessWidget {
  final Track track;
  final int count;
  const _TopTrackRow({required this.track, required this.count});
  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Artwork(coverArt: track.coverArt, origin: track.origin, size: 48),
        title: Text(track.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(track.displayArtist,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Text('$count×',
            style: const TextStyle(
                color: _accent,
                fontWeight: FontWeight.w700,
                fontFeatures: [FontFeature.tabularFigures()])),
      );
}

class _TopArtistRow extends StatelessWidget {
  final String name;
  final int count;
  const _TopArtistRow({required this.name, required this.count});
  @override
  Widget build(BuildContext context) => ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          backgroundColor: const Color(0xFF1E1E22),
          child: Text(name.isNotEmpty ? name[0].toUpperCase() : '?'),
        ),
        title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: Text('$count plays',
            style: const TextStyle(color: Colors.white60, fontSize: 12)),
      );
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text,
            style: const TextStyle(
                color: Colors.white60,
                fontSize: 11,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w700)),
      );
}

class _EmptyHint extends StatelessWidget {
  final String text;
  const _EmptyHint(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Text(text, style: const TextStyle(color: Colors.white54)),
      );
}
