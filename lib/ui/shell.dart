import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../audio/providers.dart';
import 'widgets/download_banner.dart';
import 'widgets/mini_player.dart';
import 'widgets/selection_bar.dart';

/// The persistent bottom-nav shell: tabs preserve their own navigation stack,
/// and the mini-player sits above the bar so it's always reachable. A thin
/// banner appears between body and mini-player when the active Subsonic
/// server is unreachable — so the user knows they're seeing cached state.
class AppShell extends ConsumerWidget {
  final StatefulNavigationShell shell;
  const AppShell({super.key, required this.shell});

  static const _items = [
    (icon: Icons.home_outlined, selected: Icons.home, label: 'Home'),
    (icon: Icons.search, selected: Icons.search, label: 'Search'),
    (icon: Icons.library_music_outlined, selected: Icons.library_music, label: 'Library'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reachable = ref.watch(serverReachableProvider).valueOrNull ?? true;
    final selecting = ref.watch(selectionProvider).isNotEmpty;
    final downloadActive =
        ref.watch(downloadQueueStateProvider).valueOrNull?.isActive ?? false;
    return Scaffold(
      body: shell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!reachable) const _OfflineBanner(),
          if (downloadActive) const DownloadBanner(),
          if (selecting) const SelectionBar(),
          const MiniPlayer(),
          NavigationBar(
            selectedIndex: shell.currentIndex,
            onDestinationSelected: (i) =>
                shell.goBranch(i, initialLocation: i == shell.currentIndex),
            destinations: [
              for (final it in _items)
                NavigationDestination(
                    icon: Icon(it.icon),
                    selectedIcon: Icon(it.selected),
                    label: it.label),
            ],
          ),
        ],
      ),
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();
  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        color: Colors.amber.shade900,
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.wifi_off, size: 14, color: Colors.white),
            SizedBox(width: 6),
            Text('Server unreachable — cached + local content only',
                style: TextStyle(fontSize: 12, color: Colors.white)),
          ],
        ),
      );
}
