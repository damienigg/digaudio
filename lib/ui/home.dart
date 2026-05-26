import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../audio/providers.dart';
import '../domain.dart';
import 'widgets/album_card.dart';
import 'widgets/artwork.dart';
import 'widgets/theme_ext.dart';

const _accent = Color(0xFF1ED760);

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newestAlbums = ref.watch(newestAlbumsProvider);
    final recentAlbums = ref.watch(recentlyPlayedAlbumsProvider);
    final random = ref.watch(randomSongsProvider);
    final subsonicConfigured = ref.watch(subsonicProvider) != null;

    return Scaffold(
      // Drop the opaque app-bar bandeau noir so the global
      // AppBackground bleeds all the way up to the status bar. The
      // settings gear stays accessible top-right, just floating over
      // the background instead of sitting on a dark strip.
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            tooltip: 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: !subsonicConfigured
          ? _SetupHint(onConfigure: () => context.push('/settings'))
          : RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(newestAlbumsProvider);
                ref.invalidate(recentlyPlayedAlbumsProvider);
                ref.invalidate(randomSongsProvider);
              },
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  const _HomeHero(),
                  const _StatsDashboard(),
                  _Section(title: 'Newest releases', child: _AlbumRow(state: newestAlbums)),
                  // Section hides itself when there's no recent-play data
                  // (fresh install / fresh server) — avoids an empty row.
                  recentAlbums.when(
                    loading: () => _Section(
                        title: 'Recently played',
                        child: _AlbumRow(state: recentAlbums)),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (list) => list.isEmpty
                        ? const SizedBox.shrink()
                        : _Section(
                            title: 'Recently played',
                            child: _AlbumRow(state: recentAlbums)),
                  ),
                  _Section(title: 'Random picks', child: _TracksRow(state: random)),
                ],
              ),
            ),
    );
  }
}

/// Top-of-home brand strip — icon (large) + name + tagline. Shown only
/// when a Subsonic server is configured (the SetupHint already has its
/// own hero). `cacheWidth: 192` decodes the 1024 source at ~2× the
/// display size — sharp on retina without loading the full bitmap.
class _HomeHero extends StatelessWidget {
  const _HomeHero();
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'assets/icon/digaudio_icon.png',
                width: 72,
                height: 72,
                cacheWidth: 192,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('DIGaudio',
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5)),
                  const SizedBox(height: 2),
                  Text('Dig your audio.',
                      style: TextStyle(
                          color: context.textTertiary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          ],
        ),
      );
}

class _SetupHint extends StatelessWidget {
  final VoidCallback onConfigure;
  const _SetupHint({required this.onConfigure});
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.cloud_off, size: 48, color: context.textDisabled),
              const SizedBox(height: 12),
              Text('No Subsonic server configured.',
                  style: TextStyle(color: context.textSecondary)),
              const SizedBox(height: 4),
              Text('Your local library still works — set up a server to stream.',
                  textAlign: TextAlign.center, style: TextStyle(color: context.textDisabled, fontSize: 12)),
              const SizedBox(height: 16),
              FilledButton(onPressed: onConfigure, child: const Text('Configure server')),
            ],
          ),
        ),
      );
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;
  const _Section({required this.title, required this.child});
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: 16, left: 16, right: 16, bottom: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      );
}

class _AlbumRow extends StatelessWidget {
  final AsyncValue<List<Album>> state;
  const _AlbumRow({required this.state});
  @override
  Widget build(BuildContext context) => SizedBox(
        height: 200,
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('$e', style: const TextStyle(color: Colors.redAccent)),
          data: (albums) => albums.isEmpty
              ? Text('Nothing here yet.', style: TextStyle(color: context.textMuted))
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: albums.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => AlbumCard(album: albums[i]),
                ),
        ),
      );
}

class _TracksRow extends ConsumerWidget {
  final AsyncValue<List<Track>> state;
  const _TracksRow({required this.state});
  @override
  Widget build(BuildContext context, WidgetRef ref) => SizedBox(
        height: 200,
        child: state.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('$e', style: const TextStyle(color: Colors.redAccent)),
          data: (tracks) => tracks.isEmpty
              ? Text('Nothing here yet.', style: TextStyle(color: context.textMuted))
              : ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: tracks.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (_, i) => _TrackCard(queue: tracks, index: i),
                ),
        ),
      );
}

class _TrackCard extends ConsumerWidget {
  final List<Track> queue;
  final int index;
  const _TrackCard({required this.queue, required this.index});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = queue[index];
    return InkWell(
      onTap: () =>
          ref.read(audioEngineProvider).setQueue(queue, initialIndex: index),
      borderRadius: BorderRadius.circular(8),
      child: SizedBox(
        width: 140,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Artwork(coverArt: t.coverArt, origin: t.origin, size: 140),
            const SizedBox(height: 8),
            Text(t.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontWeight: FontWeight.w600, fontSize: 13)),
            Text(t.displayArtist,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: context.textTertiary, fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

/// High-level "play habits" dashboard surfaced on Home. Pulls from
/// [homeStatsProvider] (sub-100ms typical) — a compact subset of what
/// the full StatsPage offers, scoped to the last 30 days. Tap anywhere
/// in the card to deep-link into the full page. Empty / loading / error
/// states render the same shell with a hint instead of hiding, so the
/// section is always discoverable from Home.
class _StatsDashboard extends ConsumerWidget {
  const _StatsDashboard();

  Widget _shell(BuildContext context, {required Widget body, VoidCallback? onTap}) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
            decoration: BoxDecoration(
              color: context.dividerSoft,
              borderRadius: BorderRadius.circular(14),
              border:
                  Border.all(color: _accent.withOpacity(0.18), width: 1),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.insights, size: 18, color: _accent),
                    const SizedBox(width: 6),
                    const Text('Your 30-day stats',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w800)),
                    const Spacer(),
                    if (onTap != null)
                      Icon(Icons.chevron_right,
                          color: context.textTertiary, size: 20),
                  ],
                ),
                const SizedBox(height: 12),
                body,
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(homeStatsProvider);
    return stats.when(
      loading: () => _shell(context,
          body: SizedBox(
            height: 32,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('Loading…',
                  style: TextStyle(color: context.textTertiary, fontSize: 12)),
            ),
          )),
      error: (e, _) => _shell(context,
          body: Text('Stats unavailable: $e',
              style: const TextStyle(color: Colors.redAccent, fontSize: 12))),
      data: (s) {
        if (s.isEmpty) {
          return _shell(context,
              onTap: () => context.push('/stats'),
              body: Text(
                'Play a few tracks and your top picks + streak will land here.',
                style: TextStyle(color: context.textTertiary, fontSize: 12),
              ));
        }
        return _shell(context,
          onTap: () => context.push('/stats'),
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _StatTile(value: '${s.plays}', label: 'plays'),
                  _StatTile(value: '${s.uniqueTracks}', label: 'tracks'),
                  _StatTile(value: '${s.listeningDays}', label: 'days'),
                  _StatTile(
                      value: '${s.currentStreak}',
                      label: 'streak',
                      icon: Icons.local_fire_department),
                ],
              ),
              if (s.topTrack != null || s.topArtist != null) ...[
                const SizedBox(height: 12),
                Divider(
                    color: context.outlineStrong.withOpacity(0.3), height: 1),
                const SizedBox(height: 12),
              ],
              if (s.topTrack != null)
                _TopRow(
                  label: 'TOP TRACK',
                  title: s.topTrack!.title,
                  subtitle: s.topTrack!.displayArtist,
                  artwork: Artwork(
                    coverArt: s.topTrack!.coverArt,
                    origin: s.topTrack!.origin,
                    size: 40,
                  ),
                ),
              if (s.topArtist != null) ...[
                const SizedBox(height: 8),
                _TopRow(
                  label: 'TOP ARTIST',
                  title: s.topArtist!,
                  subtitle: '${s.topArtistPlays} plays',
                  artwork: CircleAvatar(
                    radius: 20,
                    backgroundColor: const Color(0xFF1E1E22),
                    child: Text(
                      s.topArtist!.isNotEmpty
                          ? s.topArtist![0].toUpperCase()
                          : '?',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _StatTile extends StatelessWidget {
  final String value;
  final String label;
  final IconData? icon;
  const _StatTile({required this.value, required this.label, this.icon});
  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 18, color: _accent),
                  const SizedBox(width: 2),
                ],
                Text(value,
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        color: _accent,
                        fontFeatures: [FontFeature.tabularFigures()])),
              ],
            ),
            Text(label,
                style: TextStyle(
                    color: context.textTertiary,
                    fontSize: 10,
                    letterSpacing: 0.5)),
          ],
        ),
      );
}

class _TopRow extends StatelessWidget {
  final String label;
  final String title;
  final String subtitle;
  final Widget artwork;
  const _TopRow({
    required this.label,
    required this.title,
    required this.subtitle,
    required this.artwork,
  });
  @override
  Widget build(BuildContext context) => Row(
        children: [
          artwork,
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label,
                    style: TextStyle(
                        color: context.textTertiary,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2)),
                const SizedBox(height: 2),
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w700)),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        color: context.textTertiary, fontSize: 11)),
              ],
            ),
          ),
        ],
      );
}
