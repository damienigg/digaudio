import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/providers.dart';
import 'widgets/mini_player.dart';
import 'widgets/theme_ext.dart';

class WishlistPage extends ConsumerWidget {
  const WishlistPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(wishlistProvider).valueOrNull ?? const [];
    return Scaffold(
      bottomNavigationBar: const MiniPlayer(),
      appBar: AppBar(title: const Text('Wishlist')),
      floatingActionButton: FloatingActionButton.extended(
        icon: const Icon(Icons.add),
        label: const Text('Request'),
        onPressed: () => _add(context, ref),
      ),
      body: items.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Text(
                  'Nothing here yet.\n\nAdd tracks the active server is missing — '
                  'they\'ll show up here so you can grow your library.\n\n'
                  'Lidarr integration is planned (auto-push of artist/album to '
                  'a Lidarr instance via API key).',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.textTertiary),
                ),
              ),
            )
          : ListView.separated(
              itemCount: items.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: context.dividerSoft),
              itemBuilder: (_, i) {
                final w = items[i];
                return Dismissible(
                  key: ValueKey('wl-${w.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: Colors.redAccent.withOpacity(0.5),
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: 16),
                    child: const Icon(Icons.delete),
                  ),
                  onDismissed: (_) => ref.read(wishlistManagerProvider).remove(w.id),
                  child: ListTile(
                    leading: const Icon(Icons.bookmark_outline),
                    title: Text(w.title),
                    subtitle: Text([
                      if (w.artist != null) w.artist,
                      if (w.album != null) w.album,
                    ].whereType<String>().join(' • ')),
                  ),
                );
              },
            ),
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final title = TextEditingController();
    final artist = TextEditingController();
    final album = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Wishlist entry'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: title, autofocus: true,
                decoration: const InputDecoration(hintText: 'Title')),
            const SizedBox(height: 8),
            TextField(controller: artist,
                decoration: const InputDecoration(hintText: 'Artist (optional)')),
            const SizedBox(height: 8),
            TextField(controller: album,
                decoration: const InputDecoration(hintText: 'Album (optional)')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Add')),
        ],
      ),
    );
    if (ok == true && title.text.trim().isNotEmpty) {
      await ref.read(wishlistManagerProvider).add(
            title: title.text.trim(),
            artist: artist.text.trim().isEmpty ? null : artist.text.trim(),
            album: album.text.trim().isEmpty ? null : album.text.trim(),
          );
    }
  }
}
