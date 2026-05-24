import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'widgets/mini_player.dart';

/// The persistent bottom-nav shell: tabs preserve their own navigation stack,
/// and the mini-player sits above the bar so it's always reachable.
class AppShell extends StatelessWidget {
  final StatefulNavigationShell shell;
  const AppShell({super.key, required this.shell});

  static const _items = [
    (icon: Icons.home_outlined, selected: Icons.home, label: 'Home'),
    (icon: Icons.search, selected: Icons.search, label: 'Search'),
    (icon: Icons.library_music_outlined, selected: Icons.library_music, label: 'Library'),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        body: shell,
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const MiniPlayer(),
            NavigationBar(
              selectedIndex: shell.currentIndex,
              onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
              destinations: [
                for (final it in _items)
                  NavigationDestination(icon: Icon(it.icon), selectedIcon: Icon(it.selected), label: it.label),
              ],
            ),
          ],
        ),
      );
}
