import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../audio/providers.dart';
import '../domain.dart';
import 'widgets/album_card.dart';
import 'widgets/theme_ext.dart';
import 'widgets/track_tile.dart';

class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final newestAlbums = ref.watch(newestAlbumsProvider);
    final random = ref.watch(randomSongsProvider);
    final subsonicConfigured = ref.watch(subsonicProvider) != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('digaudio'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: !subsonicConfigured
          ? _SetupHint(onConfigure: () => context.push('/settings'))
          : RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(newestAlbumsProvider);
                ref.invalidate(randomSongsProvider);
              },
              child: ListView(
                padding: const EdgeInsets.only(bottom: 24),
                children: [
                  const _HomeHero(),
                  _Section(title: 'Newest releases', child: _AlbumRow(state: newestAlbums)),
                  _Section(title: 'Random picks', child: _TracksColumn(state: random)),
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
                  const Text('digaudio',
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

class _TracksColumn extends StatelessWidget {
  final AsyncValue<List<Track>> state;
  const _TracksColumn({required this.state});
  @override
  Widget build(BuildContext context) => state.when(
        loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
        error: (e, _) => Text('$e', style: const TextStyle(color: Colors.redAccent)),
        data: (tracks) => Column(
          children: [
            for (var i = 0; i < tracks.length; i++) TrackTile(queue: tracks, index: i),
          ],
        ),
      );
}
