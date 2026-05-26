import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/providers.dart';
import '../domain.dart';
import '../library/collections.dart';
import '../library/play_history.dart';
import 'widgets/artwork.dart';
import 'widgets/mini_player.dart';
import 'widgets/theme_ext.dart';

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
  /// Streaks / year heatmap / monthly tops are window-independent
  /// (always full history / last 365 days / last 12 months).
  static Future<_StatsData> _load(
      PlayHistoryManager h, TrackResolver r, int? sinceDays) async {
    final total = await h.totalPlays(sinceDays: sinceDays);
    final unique = await h.uniqueTracks(sinceDays: sinceDays);
    final days = await h.listeningDays(sinceDays: sinceDays);
    final streaks = await h.streaks();
    final heatmap = await h.dailyCounts(days: 365);
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

    // Resolve monthly tops once. For each month, take the top 3 trackKeys
    // and resolve to Tracks — only 36 lookups for a year of history.
    final rawMonthly = await h.topPerMonth(12);
    final monthly = <(String month, List<(Track track, int count)>)>[];
    final monthKeys = rawMonthly.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final m in monthKeys) {
      final entries = rawMonthly[m]!.take(3).toList();
      final resolved = <(Track, int)>[];
      for (final e in entries) {
        final t = await r.resolve(e.trackKey);
        if (t != null) resolved.add((t, e.count));
      }
      if (resolved.isNotEmpty) monthly.add((m, resolved));
    }

    // "On this day" — distinct tracks played on the same MM-DD in prior
    // years. Empty for fresh installs (< 1 year of history) — UI shows
    // a hint in that case.
    final onThisDayKeys = await h.onThisDay(limit: 10);
    final onThisDay = <Track>[];
    for (final k in onThisDayKeys) {
      final t = await r.resolve(k);
      if (t != null) onThisDay.add(t);
    }

    // Year-by-year tops — one block per year present in history, top 5
    // tracks each. Same resolve-once-then-render pattern as monthly.
    final rawYearly = await h.topPerYear(perYear: 5);
    final yearly = <(String year, List<(Track, int)>)>[];
    final yearKeys = rawYearly.keys.toList()..sort((a, b) => b.compareTo(a));
    for (final y in yearKeys) {
      final entries = rawYearly[y]!;
      final resolved = <(Track, int)>[];
      for (final e in entries) {
        final t = await r.resolve(e.trackKey);
        if (t != null) resolved.add((t, e.count));
      }
      if (resolved.isNotEmpty) yearly.add((y, resolved));
    }

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
      monthlyTops: monthly,
      onThisDay: onThisDay,
      yearlyTops: yearly,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const MiniPlayer(),
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
              const _SectionHeader('Last 365 days'),
              _YearHeatmap(counts: data.heatmap),
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
              const SizedBox(height: 16),
              const _SectionHeader('On this day'),
              if (data.onThisDay.isEmpty)
                const _EmptyHint(
                    'Nothing yet — build a year of history and this section '
                    'will surface tracks you played the same day in prior years.')
              else
                _OnThisDay(tracks: data.onThisDay),
              const SizedBox(height: 16),
              const _SectionHeader('Year by year'),
              if (data.yearlyTops.isEmpty)
                const _EmptyHint('No yearly history yet.')
              else
                ...data.yearlyTops
                    .map((y) => _MonthBlock(yyyymm: y.$1, tracks: y.$2)),
              const SizedBox(height: 16),
              const _SectionHeader('Monthly tops'),
              if (data.monthlyTops.isEmpty)
                const _EmptyHint('No monthly history yet.')
              else
                ...data.monthlyTops
                    .map((m) => _MonthBlock(yyyymm: m.$1, tracks: m.$2)),
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
  /// `date → play count` for the last 365 days; missing keys = 0.
  final Map<DateTime, int> heatmap;
  final List<(Track, int)> topTracks;
  final List<(String, int)> topArtists;
  // Full 50-track seed for the "Most played" smart mix. Order = play-count
  // descending, so the queue is itself a rank-sorted mix.
  final List<Track> mixSeed;
  /// `YYYY-MM → top 3 tracks` for the last 12 months, newest first.
  /// Already-resolved Tracks so the renderer is sync.
  final List<(String month, List<(Track, int)>)> monthlyTops;
  /// Tracks played on the same MM-DD as today in past years (excl. today).
  final List<Track> onThisDay;
  /// `YYYY → top 5 tracks` for every year present in history, newest first.
  final List<(String year, List<(Track, int)>)> yearlyTops;
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
    required this.monthlyTops,
    required this.onThisDay,
    required this.yearlyTops,
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
            labelStyle: TextStyle(color: value == days ? Colors.black : context.textSecondary),
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
                style: TextStyle(color: context.textTertiary, fontSize: 11)),
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
            color: context.dividerSoft,
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
                      style: TextStyle(color: context.textTertiary, fontSize: 10)),
                ],
              ),
            ],
          ),
        ),
      );
}

/// GitHub-contributions-style year heatmap. 7 rows × ~53 cols; rows
/// = days of week (Mon top, Sun bottom); cols = ISO weeks; oldest left,
/// today right. Cell intensity normalises against the window's max so
/// a quiet listener still sees relative shape. Cells before the start
/// of the window OR after today render blank (no slot).
///
/// Width is 53 × ~7dp ≈ 370dp — fits a phone in portrait without
/// horizontal scroll, just barely. If a future device is narrower
/// we'd swap to a SingleChildScrollView wrapper.
class _YearHeatmap extends StatelessWidget {
  final Map<DateTime, int> counts;
  const _YearHeatmap({required this.counts});

  static const _cellSize = 5.5;
  static const _gap = 1.5;

  @override
  Widget build(BuildContext context) {
    final maxCount = counts.values.fold<int>(0, (a, b) => b > a ? b : a);
    final now = DateTime.now();
    final today = DateTime.utc(now.year, now.month, now.day);
    final oldest = today.subtract(const Duration(days: 364));
    // Align the grid to Monday on the left so columns are clean weeks.
    final daysBackToMonday = (oldest.weekday - DateTime.monday) % 7;
    final firstColDate = oldest.subtract(Duration(days: daysBackToMonday));
    final totalDays = today.difference(firstColDate).inDays + 1;
    final cols = (totalDays / 7).ceil();

    return Semantics(
      label: 'Listening heatmap, last 365 days',
      container: true,
      excludeSemantics: true,
      child: SizedBox(
        height: 7 * (_cellSize + _gap) - _gap,
        child: Row(
          children: [
            for (var w = 0; w < cols; w++) ...[
              if (w > 0) const SizedBox(width: _gap),
              Expanded(
                child: Column(
                  children: [
                    for (var d = 0; d < 7; d++) ...[
                      if (d > 0) const SizedBox(height: _gap),
                      Expanded(
                        child: () {
                          final cellDate =
                              firstColDate.add(Duration(days: w * 7 + d));
                          if (cellDate.isBefore(oldest) ||
                              cellDate.isAfter(today)) {
                            return const SizedBox();
                          }
                          final c = counts[cellDate] ?? 0;
                          final t = maxCount == 0
                              ? 0.0
                              : (c / maxCount).clamp(0.0, 1.0);
                          return Container(
                            decoration: BoxDecoration(
                              color: c == 0
                                  ? context.dividerSoft
                                  : Color.lerp(
                                      context.outlineStrong, _accent, t),
                              borderRadius: BorderRadius.circular(1.5),
                            ),
                          );
                        }(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Tracks played on this calendar day in past years (distinct, most-
/// recent first). One-tap row to play, plus a "Play all" button that
/// queues the whole nostalgic batch as a single retrospective mix.
class _OnThisDay extends ConsumerWidget {
  final List<Track> tracks;
  const _OnThisDay({required this.tracks});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FilledButton.icon(
            onPressed: () => ref.read(audioEngineProvider).setQueue(tracks),
            icon: const Icon(Icons.play_arrow),
            label: Text('Play all (${tracks.length} tracks)'),
            style: FilledButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.black,
              minimumSize: const Size.fromHeight(40),
            ),
          ),
          const SizedBox(height: 8),
          for (final t in tracks)
            InkWell(
              onTap: () => ref.read(audioEngineProvider).playSingle(t),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Artwork(coverArt: t.coverArt, origin: t.origin, size: 40),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13)),
                          Text(t.displayArtist,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: context.textTertiary, fontSize: 11)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      );
}

/// One month's leaderboard: title row (Mar 2026) + the 3 most-played
/// tracks of the month with play counts. Tap row → engine.playSingle.
class _MonthBlock extends ConsumerWidget {
  final String yyyymm; // "2026-03"
  final List<(Track, int)> tracks;
  const _MonthBlock({required this.yyyymm, required this.tracks});

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// Accepts `YYYY-MM` (renders "Mar 2026") or just `YYYY` (renders
  /// "2026") — the year-by-year section reuses this block.
  String _label() {
    final parts = yyyymm.split('-');
    if (parts.length < 2) return yyyymm; // year-only
    final y = int.tryParse(parts.first) ?? 0;
    final m = int.tryParse(parts.last) ?? 1;
    return '${_months[(m - 1).clamp(0, 11)]} $y';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_label(),
                style: TextStyle(
                    color: context.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            for (final (t, c) in tracks)
              InkWell(
                onTap: () => ref.read(audioEngineProvider).playSingle(t),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(t.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13)),
                            Text(t.displayArtist,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                    color: context.textTertiary,
                                    fontSize: 11)),
                          ],
                        ),
                      ),
                      Text('$c×',
                          style: const TextStyle(
                              color: _accent,
                              fontWeight: FontWeight.w700,
                              fontFeatures: [FontFeature.tabularFigures()])),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
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
            style: TextStyle(color: context.textTertiary, fontSize: 12)),
      );
}

class _SectionHeader extends StatelessWidget {
  final String text;
  const _SectionHeader(this.text);
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(text,
            style: TextStyle(
                color: context.textTertiary,
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
        child: Text(text, style: TextStyle(color: context.textMuted)),
      );
}
