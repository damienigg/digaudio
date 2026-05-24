import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'ui/album_page.dart';
import 'ui/artist_page.dart';
import 'ui/home.dart';
import 'ui/library_page.dart';
import 'ui/now_playing.dart';
import 'ui/playlist_page.dart';
import 'ui/search.dart';
import 'ui/settings.dart';
import 'ui/shell.dart';

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
        GoRoute(
          path: '/playlist/:origin/:id',
          builder: (_, s) => PlaylistPage(origin: s.pathParameters['origin']!, id: s.pathParameters['id']!),
        ),
      ],
    );
