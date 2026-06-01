import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'ui/album_page.dart';
import 'ui/artist_page.dart';
import 'ui/favorites_page.dart';
import 'ui/genre_decade_page.dart';
import 'ui/home.dart';
import 'ui/library_page.dart';
import 'ui/local_playlist_page.dart';
import 'ui/now_playing.dart';
import 'ui/playlist_page.dart';
import 'ui/search.dart';
import 'ui/settings.dart';
import 'ui/shell.dart';
import 'ui/smart_playlist_pages.dart';
import 'ui/stats_page.dart';
import 'ui/wishlist_page.dart';

/// Push `/now-playing` exactly once no matter how many times the user
/// taps the mini player or the bottom-nav Now Playing icon. Mashing
/// either previously stacked one fullscreen-dialog per tap; the user
/// then had to hit the back arrow N times to peel them off.
/// Both call sites (`MiniPlayer.onTap` + `AppShell.onDestinationSelected`)
/// route through this helper.
///
/// Also drops the primary focus before pushing — without this, if the
/// search TextField was focused (e.g. the user just came from /home's
/// permanent search bar which auto-focuses /search), Flutter would
/// reopen the keyboard the moment the user pops /now-playing back.
/// The rule is: keyboard pops only on a deliberate tap of the home
/// search bar, the bottom-nav search icon, or directly inside the
/// TextField — never as a side effect of returning from /now-playing.
void openNowPlaying(BuildContext context) {
  if (GoRouterState.of(context).uri.path == '/now-playing') return;
  FocusManager.instance.primaryFocus?.unfocus();
  context.push('/now-playing');
}

GoRouter buildRouter() => GoRouter(
      initialLocation: '/home',
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, __, shell) => AppShell(shell: shell),
          branches: [
            StatefulShellBranch(routes: [GoRoute(path: '/home', builder: (_, __) => const HomePage())]),
            StatefulShellBranch(routes: [GoRoute(path: '/search', builder: (_, __) => const SearchPage())]),
            StatefulShellBranch(routes: [GoRoute(path: '/library', builder: (_, __) => const LibraryPage())]),
          ],
        ),
        GoRoute(
          path: '/now-playing',
          pageBuilder: (_, state) => MaterialPage(fullscreenDialog: true, child: const NowPlayingPage(), key: state.pageKey),
        ),
        GoRoute(path: '/settings', builder: (_, __) => const SettingsPage()),
        GoRoute(path: '/settings/servers', builder: (_, __) => const ServersPage()),
        GoRoute(path: '/settings/playback', builder: (_, __) => const PlaybackPage()),
        GoRoute(path: '/settings/display', builder: (_, __) => const DisplayPage()),
        GoRoute(
          path: '/settings/server/:id',
          builder: (_, s) => ServerEditPage(id: s.pathParameters['id']!),
        ),
        GoRoute(
          path: '/album/:origin/:id',
          builder: (_, s) => AlbumPage(origin: s.pathParameters['origin']!, id: s.pathParameters['id']!),
        ),
        GoRoute(
          path: '/artist/:origin/:id',
          builder: (_, s) => ArtistPage(origin: s.pathParameters['origin']!, id: s.pathParameters['id']!),
        ),
        // ORDER MATTERS — go-router scans routes top-to-bottom and the
        // first pattern that matches wins. The smart-playlist routes
        // share the `/playlist/` prefix with the catch-all
        // `/playlist/:origin/:id`, so they have to come BEFORE it.
        // Previously they sat below and `/playlist/smart/1` was being
        // routed to `PlaylistPage(origin: 'smart', id: '1')` — a
        // bogus MediaOrigin that landed users on a blank gray screen
        // ("DiagnosticsProperty<void>" in logcat).
        GoRoute(
          path: '/playlist/local/:id',
          builder: (_, s) => LocalPlaylistPage(playlistId: int.parse(s.pathParameters['id']!)),
        ),
        GoRoute(
          path: '/playlist/smart/:id/edit',
          builder: (_, s) =>
              SmartPlaylistEditPage(id: s.pathParameters['id']!),
        ),
        GoRoute(
          path: '/playlist/smart/:id',
          builder: (_, s) => SmartPlaylistViewPage(
              id: int.parse(s.pathParameters['id']!)),
        ),
        GoRoute(
          path: '/playlist/:origin/:id',
          builder: (_, s) => PlaylistPage(origin: s.pathParameters['origin']!, id: s.pathParameters['id']!),
        ),
        GoRoute(path: '/favorites', builder: (_, __) => const FavoritesPage()),
        GoRoute(path: '/wishlist', builder: (_, __) => const WishlistPage()),
        GoRoute(path: '/stats', builder: (_, __) => const StatsPage()),
        GoRoute(
          path: '/genre/:name',
          builder: (_, s) => GenrePage(
              genre: Uri.decodeComponent(s.pathParameters['name']!)),
        ),
        GoRoute(
          path: '/decade/:year',
          builder: (_, s) =>
              DecadePage(decade: int.parse(s.pathParameters['year']!)),
        ),
      ],
    );
