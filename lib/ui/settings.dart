import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../audio/providers.dart';
import '../core/playback_prefs.dart';
import '../core/settings.dart';
import '../subsonic/client.dart';
import 'widgets/theme_ext.dart';

/// Top-level Settings hub. Subpages handle the actual configuration.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: ListView(
          children: [
            ListTile(
              leading: const Icon(Icons.cloud_outlined),
              title: const Text('Servers'),
              subtitle: const Text('Subsonic servers and credentials'),
              trailing: Icon(Icons.chevron_right, color: context.textDisabled),
              onTap: () => context.push('/settings/servers'),
            ),
            Divider(height: 1, color: context.dividerSoft),
            ListTile(
              leading: const Icon(Icons.equalizer),
              title: const Text('Playback'),
              subtitle: const Text('Storage · auto-queue · equalizer'),
              trailing: Icon(Icons.chevron_right, color: context.textDisabled),
              onTap: () => context.push('/settings/playback'),
            ),
            Divider(height: 1, color: context.dividerSoft),
            ListTile(
              leading: const Icon(Icons.brightness_6_outlined),
              title: const Text('Display'),
              subtitle: const Text('Theme'),
              trailing: Icon(Icons.chevron_right, color: context.textDisabled),
              onTap: () => context.push('/settings/display'),
            ),
            const SizedBox(height: 32),
            const _AppVersionFooter(),
          ],
        ),
      );
}

/// Tiny build-info line at the bottom of Settings — "digaudio v0.30.13 ·
/// build 79". Reads from PackageManager via `package_info_plus`. Useful
/// when triaging bugs: the user can read it back at a glance instead
/// of guessing which APK they have installed. Low-contrast so it
/// doesn't draw attention away from the settings tiles.
class _AppVersionFooter extends StatefulWidget {
  const _AppVersionFooter();
  @override
  State<_AppVersionFooter> createState() => _AppVersionFooterState();
}

class _AppVersionFooterState extends State<_AppVersionFooter> {
  late final Future<PackageInfo> _info = PackageInfo.fromPlatform();

  @override
  Widget build(BuildContext context) => FutureBuilder<PackageInfo>(
        future: _info,
        builder: (ctx, snap) {
          final label = snap.hasData
              ? 'digaudio v${snap.data!.version} · build ${snap.data!.buildNumber}'
              : '…';
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Center(
              child: Text(
                label,
                style: TextStyle(
                  color: ctx.textDisabled,
                  fontSize: 11,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          );
        },
      );
}

/// List of Subsonic servers. One is active at a time. The built-in entry
/// (URL baked at build time) is seeded once on first run.
class ServersPage extends ConsumerWidget {
  const ServersPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servers = ref.watch(serversProvider);
    final activeAsync = ref.watch(activeServerProvider);
    final activeId = activeAsync.valueOrNull?.id;
    return Scaffold(
      appBar: AppBar(title: const Text('Servers')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/settings/server/new'),
        icon: const Icon(Icons.add),
        label: const Text('Add server'),
      ),
      body: servers.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e', style: const TextStyle(color: Colors.redAccent))),
        data: (list) => list.isEmpty
            ? const _EmptyHint()
            : ListView.separated(
                padding: const EdgeInsets.only(top: 8, bottom: 96),
                itemCount: list.length,
                separatorBuilder: (_, __) => Divider(height: 1, color: context.dividerSoft),
                itemBuilder: (_, i) => _ServerTile(
                  server: list[i],
                  active: list[i].id == activeId,
                  onActivate: () async {
                    await ref.read(settingsStoreProvider).setActiveId(list[i].id);
                    _invalidateAll(ref);
                  },
                ),
              ),
      ),
    );
  }
}

void _invalidateAll(WidgetRef ref) {
  ref.invalidate(serversProvider);
  ref.invalidate(activeServerProvider);
  ref.invalidate(newestAlbumsProvider);
  ref.invalidate(randomSongsProvider);
  ref.invalidate(subsonicArtistsProvider);
  ref.invalidate(subsonicPlaylistsProvider);
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(
            'No Subsonic server registered yet.\nTap "Add server" to start.',
            textAlign: TextAlign.center,
            style: TextStyle(color: context.textTertiary),
          ),
        ),
      );
}

class _ServerTile extends ConsumerWidget {
  final ServerConfig server;
  final bool active;
  final VoidCallback onActivate;
  const _ServerTile({required this.server, required this.active, required this.onActivate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = server.isConfigured
        ? (active ? 'Active' : 'Tap to activate')
        : 'Credentials missing — tap to set';
    final accent = ref.watch(accentTintProvider).valueOrNull ?? brandAccent;
    final color = active ? accent : context.textMuted;
    return ListTile(
      leading: Icon(active ? Icons.cloud_done : Icons.cloud_outlined, color: color),
      title: Row(
        children: [
          Flexible(child: Text(server.label, overflow: TextOverflow.ellipsis)),
          if (server.builtin) ...[
            const SizedBox(width: 8),
            const _Badge('built-in'),
          ],
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(server.url, overflow: TextOverflow.ellipsis,
              style: TextStyle(color: context.textMuted, fontSize: 11)),
          Text(status, style: TextStyle(color: color, fontSize: 11)),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.edit_outlined),
        tooltip: 'Edit server',
        onPressed: () => context.push('/settings/server/${server.id}'),
      ),
      onTap: server.isConfigured && !active
          ? onActivate
          : () => context.push('/settings/server/${server.id}'),
    );
  }
}

class _Badge extends StatelessWidget {
  final String text;
  const _Badge(this.text);
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        decoration: BoxDecoration(
          color: context.dividerSoft,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(text, style: TextStyle(fontSize: 10, color: context.textSecondary)),
      );
}

/// Add (id == 'new') or edit a Subsonic server entry.
class ServerEditPage extends ConsumerStatefulWidget {
  final String id;
  const ServerEditPage({super.key, required this.id});
  @override
  ConsumerState<ServerEditPage> createState() => _ServerEditPageState();
}

class _ServerEditPageState extends ConsumerState<ServerEditPage> {
  final _label = TextEditingController();
  final _url = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  ServerConfig? _existing;
  String? _status;
  bool _busy = false;
  bool _loaded = false;
  // Admin scan state — null = not yet queried; populated on demand and
  // after each trigger. _scanError surfaces "not authorized" for non-
  // admin users without an exception bubbling up.
  ScanStatus? _scan;
  String? _scanError;
  bool _scanBusy = false;

  bool get _isNew => widget.id == 'new';

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  Future<void> _hydrate() async {
    if (!_isNew) {
      final all = await ref.read(settingsStoreProvider).servers();
      _existing = all.firstWhere((s) => s.id == widget.id,
          orElse: () => const ServerConfig(id: '', label: '', url: ''));
      if (_existing!.id.isNotEmpty) {
        _label.text = _existing!.label;
        _url.text = _existing!.url;
        _user.text = _existing!.username;
        _pass.text = _existing!.password;
      }
    }
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _label.dispose();
    _url.dispose();
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  ServerConfig _draft() => ServerConfig(
        id: _existing?.id ?? SettingsStore.newId(),
        label: _label.text.trim().isEmpty ? 'Subsonic' : _label.text.trim(),
        url: _url.text.trim(),
        username: _user.text.trim(),
        password: _pass.text,
        builtin: _existing?.builtin ?? false,
      );

  Future<void> _testAndSave() async {
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final draft = _draft();
      final client = draft.client();
      if (client == null) {
        setState(() => _status = 'Fill in username and password before testing.');
        return;
      }
      final ok = await client.ping();
      if (!ok) {
        setState(() => _status = 'Ping failed — check URL & credentials.');
        return;
      }
      final store = ref.read(settingsStoreProvider);
      await store.upsert(draft);
      // Make this server the active one on save: that's the user's intent
      // whenever they tap Test & save.
      await store.setActiveId(draft.id);
      _invalidateAll(ref);
      if (mounted) {
        setState(() => _status = 'Connected.');
        Navigator.maybePop(context);
      }
    } catch (e) {
      setState(() => _status = 'Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Either kicks off a scan (when [trigger] true) or just queries
  /// the current status. Both paths share error handling — the
  /// startScan endpoint is admin-only and returns Subsonic error 50
  /// for non-admins, surfaced inline as `_scanError`.
  Future<void> _scanRequest({required bool trigger}) async {
    final client = _existing?.client();
    if (client == null) return;
    setState(() {
      _scanBusy = true;
      _scanError = null;
    });
    try {
      _scan = trigger ? await client.startScan() : await client.getScanStatus();
    } on SubsonicException catch (e) {
      _scanError = e.code == 50
          ? 'Admin role required on this server.'
          : 'Scan error: ${e.message}';
    } catch (e) {
      _scanError = 'Network error: $e';
    } finally {
      if (mounted) setState(() => _scanBusy = false);
    }
  }

  Future<void> _delete() async {
    if (_existing == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Remove ${_existing!.label}?'),
        content: const Text('This will not delete anything on the server itself.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(settingsStoreProvider).remove(_existing!.id);
    _invalidateAll(ref);
    if (mounted) Navigator.maybePop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isBuiltin = _existing?.builtin ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Add Subsonic server' : 'Edit server'),
        actions: [
          if (!_isNew && !isBuiltin)
            IconButton(tooltip: 'Delete server', icon: const Icon(Icons.delete_outline), onPressed: _busy ? null : _delete),
        ],
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextField(
                  controller: _label,
                  decoration: const InputDecoration(hintText: 'Name (e.g. home-nas)'),
                  autocorrect: false,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _url,
                  enabled: !isBuiltin,
                  decoration: InputDecoration(
                    hintText: 'https://music.example.com',
                    helperText: isBuiltin ? 'URL is baked into this build and cannot be changed.' : null,
                  ),
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _user,
                  decoration: const InputDecoration(hintText: 'Username'),
                  autocorrect: false,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _pass,
                  decoration: const InputDecoration(hintText: 'Password'),
                  obscureText: true,
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _testAndSave,
                  child: _busy
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Test & save'),
                ),
                if (_status != null) ...[
                  const SizedBox(height: 16),
                  Text(_status!, style: TextStyle(color: context.textSecondary)),
                ],
                if (!_isNew && (_existing?.isConfigured ?? false)) ...[
                  const SizedBox(height: 32),
                  Divider(color: context.dividerSoft),
                  const SizedBox(height: 16),
                  Text('Library scan (admin)',
                      style: TextStyle(
                          color: context.textSecondary,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Text(
                    _scan == null
                        ? 'Not queried yet.'
                        : _scan!.scanning
                            ? 'Scanning… ${_scan!.count} songs indexed so far'
                            : 'Idle — ${_scan!.count} songs in the library',
                    style: TextStyle(color: context.textMuted, fontSize: 12),
                  ),
                  if (_scanError != null) ...[
                    const SizedBox(height: 4),
                    Text(_scanError!,
                        style: const TextStyle(
                            color: Colors.redAccent, fontSize: 12)),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      OutlinedButton.icon(
                        icon: const Icon(Icons.refresh, size: 18),
                        label: const Text('Check status'),
                        onPressed: _scanBusy
                            ? null
                            : () => _scanRequest(trigger: false),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        icon: const Icon(Icons.cloud_sync, size: 18),
                        label: const Text('Trigger scan'),
                        onPressed: _scanBusy
                            ? null
                            : () => _scanRequest(trigger: true),
                      ),
                      if (_scanBusy) ...[
                        const SizedBox(width: 12),
                        const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      ],
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}

/// Display settings — theme mode picker today. Persisted via [DisplayPrefs]
/// and mirrored into [themeModeProvider] so MaterialApp.router redraws
/// instantly without a restart.
///
/// Note: the light theme is **experimental** — many digaudio widgets
/// hardcode `Colors.white*` (artefact of the dark-only roots) and render
/// with low contrast in light mode. Will be migrated incrementally.
class DisplayPage extends ConsumerWidget {
  const DisplayPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeModeProvider);
    final accent = ref.watch(accentTintProvider).valueOrNull ?? brandAccent;
    Widget tile(ThemeMode m, IconData icon, String label, String hint) =>
        RadioListTile<ThemeMode>(
          value: m,
          groupValue: current,
          activeColor: accent,
          secondary: Icon(icon),
          title: Text(label),
          subtitle: Text(hint, style: const TextStyle(fontSize: 11)),
          onChanged: (v) async {
            if (v == null) return;
            ref.read(themeModeProvider.notifier).state = v;
            final prefs = ref.read(displayPrefsProvider);
            prefs.themeMode = v;
            await prefs.save();
          },
        );
    return Scaffold(
      appBar: AppBar(title: const Text('Display')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
            child: Text('Theme',
                style: TextStyle(
                    color: context.textTertiary,
                    fontSize: 11,
                    letterSpacing: 1.5)),
          ),
          tile(ThemeMode.dark, Icons.dark_mode, 'Dark', 'Default — every widget tested here.'),
          tile(ThemeMode.light, Icons.light_mode, 'Light',
              'Experimental — some surfaces still use dark-only colors.'),
          tile(ThemeMode.system, Icons.settings_brightness, 'Follow system',
              'Switches with the OS dark-mode setting.'),
          Divider(height: 32, color: context.dividerSoft),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 6),
            child: Text('Behaviour',
                style: TextStyle(
                    color: Colors.white60,
                    fontSize: 11,
                    letterSpacing: 1.5)),
          ),
          // longPressPlays toggle removed in v0.16.3 — long-press is now
          // dedicated to entering selection mode (standard mobile
          // pattern). The pref field stays in DisplayPrefs for forward
          // compatibility but is no longer surfaced or read.
          _DisplayToggle(
            title: 'Now Playing colour tint',
            subtitle:
                'Background gradient uses the dominant colour of the current artwork.',
            value: ref.watch(displayPrefsProvider).nowPlayingTint,
            onChanged: (v) async {
              final p = ref.read(displayPrefsProvider);
              p.nowPlayingTint = v;
              await p.save();
            },
          ),
          _DisplayToggle(
            title: 'Display infos for audio geeks',
            subtitle:
                'Show the codec / bit-depth / sample-rate / device line '
                'under the artist on Now Playing. Off by default — '
                'Android always mixes built-in speakers at 48 kHz so the '
                'resampling indicator fires for nearly every track.',
            value: ref.watch(displayPrefsProvider).audioGeekInfoEnabled,
            onChanged: (v) async {
              final p = ref.read(displayPrefsProvider);
              p.audioGeekInfoEnabled = v;
              await p.save();
            },
          ),
          _DisplayToggle(
            title: 'App background',
            subtitle:
                'Show a soft full-screen background on Home / Search / '
                'Library: app icon at low opacity when nothing is '
                'playing, blurred current-track artwork when a queue '
                'is loaded. On by default — turn off for a flat scaffold.',
            value: ref.watch(displayPrefsProvider).appBackgroundEnabled,
            onChanged: (v) async {
              final p = ref.read(displayPrefsProvider);
              p.appBackgroundEnabled = v;
              await p.save();
            },
          ),
          _DisplayToggle(
            title: 'Debug mode',
            subtitle:
                'Stream verbose [digaudio.dbg] engine / provider / '
                'mini-player events to logcat (adb logcat | grep digaudio.dbg). '
                'Off by default — turn on when reproducing a bug so the '
                'maintainer can read the chain.',
            value: ref.watch(displayPrefsProvider).debugLogsEnabled,
            onChanged: (v) async {
              final p = ref.read(displayPrefsProvider);
              p.debugLogsEnabled = v;
              await p.save();
            },
          ),
        ],
      ),
    );
  }
}

class _DisplayToggle extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
  const _DisplayToggle({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) => SwitchListTile.adaptive(
        title: Text(title),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
        value: value,
        onChanged: onChanged,
      );
}

/// Playback settings. Today: equalizer only. Crossfade lives here once the
/// audio_service refactor lands (true two-player overlap, see CHANGELOG).
class PlaybackPage extends ConsumerStatefulWidget {
  const PlaybackPage({super.key});
  @override
  ConsumerState<PlaybackPage> createState() => _PlaybackPageState();
}

class _PlaybackPageState extends ConsumerState<PlaybackPage> {
  bool _ready = false;
  int _cachedCount = 0;
  DateTime? _lastSync;
  bool _syncing = false;
  int _syncDone = 0;
  int _syncTotal = 0;
  bool _cancelSync = false;
  int _autoBytes = 0;
  int _pinnedBytes = 0;
  bool _autoCacheEnabled = true;
  int _cacheMaxBytes = PlaybackPrefs.defaultCacheMaxBytes;

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  /// Loads prefs + fast drift queries only. The equalizer used to be
  /// awaited here, but `AndroidEqualizer.parameters` only resolves once
  /// the engine has materialised an AudioTrack (i.e. after the first
  /// play). On a fresh process before any track has played, that
  /// Future hangs forever — gating the whole Settings → Playback page
  /// on it spun a `CircularProgressIndicator` indefinitely. The EQ
  /// section now owns its own readiness in [_EqualizerSection].
  Future<void> _hydrate() async {
    final prefs = ref.read(playbackPrefsProvider);
    await prefs.load();
    await _refreshCacheStatus();
    await _refreshStorage();
    if (mounted) setState(() => _ready = true);
  }

  Future<void> _refreshStorage() async {
    final cache = ref.read(downloadsProvider);
    _autoBytes = await cache.autoCacheBytes();
    _pinnedBytes = await cache.pinnedBytes();
    final prefs = ref.read(playbackPrefsProvider);
    _autoCacheEnabled = prefs.autoCacheEnabled;
    _cacheMaxBytes = prefs.cacheMaxBytes;
  }

  Future<void> _toggleAutoCache(bool v) async {
    final prefs = ref.read(playbackPrefsProvider);
    prefs.autoCacheEnabled = v;
    await prefs.save();
    setState(() => _autoCacheEnabled = v);
  }

  Future<void> _setCacheMax(int bytes) async {
    final prefs = ref.read(playbackPrefsProvider);
    prefs.cacheMaxBytes = bytes;
    await prefs.save();
    // Shrinking the budget evicts immediately so the user sees the impact.
    await ref.read(downloadsProvider).evictTo(bytes);
    await _refreshStorage();
    if (mounted) setState(() {});
  }

  Future<void> _clearAutoCache() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Clear auto-cache?'),
        content: const Text('Removes every auto-cached track. Pinned downloads stay.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Clear')),
        ],
      ),
    );
    if (ok != true) return;
    await ref.read(downloadsProvider).clearAuto();
    await _refreshStorage();
    if (mounted) setState(() {});
  }

  Future<void> _refreshCacheStatus() async {
    final active = await ref.read(settingsStoreProvider).active();
    if (active == null) {
      _cachedCount = 0;
      _lastSync = null;
      return;
    }
    final cache = ref.read(subsonicCacheProvider);
    _cachedCount = await cache.count(active.id);
    _lastSync = await cache.lastSync(active.id);
  }

  Future<void> _syncLibrary() async {
    final messenger = ScaffoldMessenger.of(context);
    final active = await ref.read(settingsStoreProvider).active();
    final client = ref.read(subsonicProvider);
    if (active == null || client == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('No active Subsonic server.')),
      );
      return;
    }
    setState(() {
      _syncing = true;
      _syncDone = 0;
      _syncTotal = 0;
      _cancelSync = false;
    });
    try {
      await ref.read(subsonicCacheProvider).rebuild(
        client,
        active.id,
        onAlbum: (done, total) {
          if (mounted) setState(() { _syncDone = done; _syncTotal = total; });
        },
        shouldCancel: () => _cancelSync,
      );
      ref.read(autoQueueProvider).invalidatePool();
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Sync failed: $e')));
    } finally {
      await _refreshCacheStatus();
      if (mounted) setState(() => _syncing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Playback')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SubsonicCacheCard(
            cachedCount: _cachedCount,
            lastSync: _lastSync,
            syncing: _syncing,
            done: _syncDone,
            total: _syncTotal,
            onSync: _syncLibrary,
            onCancel: () => setState(() => _cancelSync = true),
            refreshDays: ref.watch(playbackPrefsProvider).cacheRefreshDays,
            onSetRefreshDays: (d) async {
              final prefs = ref.read(playbackPrefsProvider);
              prefs.cacheRefreshDays = d;
              await prefs.save();
              setState(() {});
            },
          ),
          Divider(height: 32, color: context.dividerSoft),
          _StorageCard(
            enabled: _autoCacheEnabled,
            autoBytes: _autoBytes,
            pinnedBytes: _pinnedBytes,
            maxBytes: _cacheMaxBytes,
            onToggleAuto: _toggleAutoCache,
            onSetMax: _setCacheMax,
            onClear: _clearAutoCache,
          ),
          Divider(height: 32, color: context.dividerSoft),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto-queue similar tracks',
                style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(
              'When the queue is about to end, append a similar track from '
              'your library (same algorithm as the "Suggested next" hint).',
              style: TextStyle(color: context.textMuted, fontSize: 12),
            ),
            value: ref.watch(playbackPrefsProvider).autoQueueEnabled,
            onChanged: (v) async {
              final prefs = ref.read(playbackPrefsProvider);
              prefs.autoQueueEnabled = v;
              await prefs.save();
              ref.read(autoQueueProvider).enabled = v;
              setState(() {});
            },
          ),
          Divider(height: 32, color: context.dividerSoft),
          _CrossfadePicker(
            currentMs: ref.watch(playbackPrefsProvider).crossfadeMs,
            onChanged: (v) async {
              final prefs = ref.read(playbackPrefsProvider);
              prefs.crossfadeMs = v;
              await prefs.save();
              setState(() {});
            },
          ),
          Divider(height: 32, color: context.dividerSoft),
          _RgPicker(
            mode: ref.watch(playbackPrefsProvider).rgMode,
            onChanged: (v) async {
              final prefs = ref.read(playbackPrefsProvider);
              prefs.rgMode = v;
              await prefs.save();
              setState(() {});
            },
          ),
          Divider(height: 32, color: context.dividerSoft),
          _ListenBrainzCard(
            token: ref.watch(playbackPrefsProvider).listenbrainzToken,
            onChanged: (v) async {
              final prefs = ref.read(playbackPrefsProvider);
              prefs.listenbrainzToken = v;
              await prefs.save();
              setState(() {});
            },
          ),
          Divider(height: 32, color: context.dividerSoft),
          const _LastfmCard(),
          Divider(height: 32, color: context.dividerSoft),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto-play when Bluetooth connects',
                style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(
              'When a BT output becomes active and the queue is loaded '
              'but paused, automatically resume playback. '
              'Headphone-removal still auto-pauses (via the music session) '
              'regardless of this toggle.',
              style: TextStyle(color: context.textMuted, fontSize: 12),
            ),
            value: ref.watch(playbackPrefsProvider).autoPlayOnBtConnect,
            onChanged: (v) async {
              final prefs = ref.read(playbackPrefsProvider);
              prefs.autoPlayOnBtConnect = v;
              await prefs.save();
              setState(() {});
            },
          ),
          Divider(height: 32, color: context.dividerSoft),
          const _EqualizerSection(),
        ],
      ),
    );
  }
}

/// Equalizer + per-Bluetooth-device EQ — extracted out of [PlaybackPage]
/// so its readiness is independent of the rest of the page. `AndroidEqualizer.parameters`
/// only resolves once the engine has materialised an AudioTrack (i.e.
/// after the user has played at least one track in this process).
/// Awaiting that future at the page level used to spin a global
/// `CircularProgressIndicator` forever on a fresh launch. This widget
/// now renders an inline placeholder explaining the constraint instead,
/// and swaps in the full EQ UI the instant the future lands (without
/// the user having to leave + re-enter the page).
class _EqualizerSection extends ConsumerStatefulWidget {
  const _EqualizerSection();
  @override
  ConsumerState<_EqualizerSection> createState() => _EqualizerSectionState();
}

class _EqualizerSectionState extends ConsumerState<_EqualizerSection> {
  AndroidEqualizerParameters? _params;
  List<double> _gainsDb = const [];
  bool _enabled = false;

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  Future<void> _hydrate() async {
    final engine = ref.read(audioEngineProvider);
    final params = await engine.eqParameters;
    if (!mounted) return;
    final prefs = ref.read(playbackPrefsProvider);
    final stored = List<double>.from(prefs.eqGainsDb);
    while (stored.length < params.bands.length) {
      stored.add(0);
    }
    setState(() {
      _params = params;
      _enabled = prefs.eqEnabled;
      _gainsDb = stored;
    });
  }

  Future<void> _toggleEnabled(bool v) async {
    setState(() => _enabled = v);
    final prefs = ref.read(playbackPrefsProvider);
    prefs.eqEnabled = v;
    await prefs.save();
    await ref.read(audioEngineProvider).setEqEnabled(v);
  }

  Future<void> _setBandGain(int i, double db) async {
    setState(() => _gainsDb[i] = db);
    final prefs = ref.read(playbackPrefsProvider);
    prefs.eqGainsDb = List.of(_gainsDb);
    await prefs.save();
    final engine = ref.read(audioEngineProvider);
    final params = _params!;
    await params.bands[i].setGain(db.clamp(params.minDecibels, params.maxDecibels));
    if (!_enabled) {
      // Auto-enable when the user starts moving sliders — otherwise the gains
      // wouldn't actually do anything, which is confusing UX.
      await _toggleEnabled(true);
      await engine.applyEqGains(_gainsDb);
    }
  }

  /// Apply a preset to all bands. Pads/truncates if the preset's length
  /// doesn't match the device's actual band count (Android usually
  /// returns 5; some return 10).
  Future<void> _applyPreset(List<double> presetGains) async {
    final params = _params!;
    final gains = List<double>.filled(params.bands.length, 0);
    for (var i = 0; i < gains.length; i++) {
      final raw = i < presetGains.length ? presetGains[i] : 0.0;
      gains[i] = raw.clamp(params.minDecibels, params.maxDecibels).toDouble();
    }
    setState(() => _gainsDb = gains);
    final prefs = ref.read(playbackPrefsProvider);
    prefs.eqGainsDb = gains;
    await prefs.save();
    final engine = ref.read(audioEngineProvider);
    await engine.applyEqGains(gains);
    if (!_enabled) await _toggleEnabled(true);
  }

  Future<void> _resetFlat() async {
    final params = _params!;
    final flat = List<double>.filled(params.bands.length, 0);
    setState(() => _gainsDb = flat);
    final prefs = ref.read(playbackPrefsProvider);
    prefs.eqGainsDb = flat;
    await prefs.save();
    await ref.read(audioEngineProvider).applyEqGains(flat);
  }

  /// Persist the current band curve under a user-provided name.
  /// Name conflicts simply append — no de-dup (user can delete the
  /// stale one if they want a clean slate).
  Future<void> _saveCustomPreset() async {
    if (_params == null) return;
    final nameCtrl = TextEditingController();
    final name = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Save EQ preset'),
        content: TextField(
          controller: nameCtrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'My custom curve'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, nameCtrl.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (name == null || name.isEmpty) return;
    final prefs = ref.read(playbackPrefsProvider);
    prefs.customEqPresets = [
      ...prefs.customEqPresets,
      (name: name, gains: List<double>.from(_gainsDb)),
    ];
    await prefs.save();
    if (mounted) setState(() {});
  }

  Future<void> _deleteCustomPreset(
      ({String name, List<double> gains}) p) async {
    final prefs = ref.read(playbackPrefsProvider);
    prefs.customEqPresets =
        prefs.customEqPresets.where((x) => x.name != p.name).toList();
    await prefs.save();
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final params = _params;
    if (params == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Equalizer',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Becomes available once a track has played in this session — '
            'Android only reports the equalizer band layout after an '
            'AudioTrack is live. Play any track briefly, then come back '
            'and the bands appear here automatically.',
            style: TextStyle(color: context.textMuted, fontSize: 12),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                title: const Text('Equalizer',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  params.bands.isEmpty
                      ? 'No equalizer available on this device.'
                      : '${params.bands.length} bands · '
                          '${params.minDecibels.toStringAsFixed(0)} to ${params.maxDecibels.toStringAsFixed(0)} dB',
                  style: TextStyle(color: context.textMuted, fontSize: 12),
                ),
                value: _enabled,
                onChanged: params.bands.isEmpty ? null : _toggleEnabled,
              ),
            ),
            if (params.bands.isNotEmpty)
              TextButton(onPressed: _resetFlat, child: const Text('Flat')),
          ],
        ),
        if (params.bands.isNotEmpty) ...[
          const SizedBox(height: 8),
          _EqPresets(
            enabled: _enabled,
            bandCount: params.bands.length,
            onApply: _applyPreset,
            customPresets: ref.watch(playbackPrefsProvider).customEqPresets,
            onDelete: _deleteCustomPreset,
            onSave: _saveCustomPreset,
          ),
        ],
        const SizedBox(height: 8),
        for (var i = 0; i < params.bands.length; i++)
          _BandRow(
            band: params.bands[i],
            gainDb: _gainsDb[i],
            minDb: params.minDecibels,
            maxDb: params.maxDecibels,
            enabled: _enabled,
            onChanged: (v) => _setBandGain(i, v),
          ),
        if (params.bands.isNotEmpty) ...[
          Divider(height: 32, color: context.dividerSoft),
          const _BtEqCard(),
        ],
      ],
    );
  }
}

class _SubsonicCacheCard extends StatelessWidget {
  final int cachedCount;
  final DateTime? lastSync;
  final bool syncing;
  final int done;
  final int total;
  final VoidCallback onSync;
  final VoidCallback onCancel;
  final int refreshDays;
  final ValueChanged<int> onSetRefreshDays;
  const _SubsonicCacheCard({
    required this.cachedCount,
    required this.lastSync,
    required this.syncing,
    required this.done,
    required this.total,
    required this.onSync,
    required this.onCancel,
    required this.refreshDays,
    required this.onSetRefreshDays,
  });

  @override
  Widget build(BuildContext context) {
    final status = syncing
        ? (total > 0 ? 'Syncing — $done / $total albums' : 'Syncing — listing albums…')
        : cachedCount == 0
            ? 'Not synced yet · AutoQueue falls back to a 200-song random sample.'
            : '$cachedCount songs cached${lastSync != null ? ' · synced ${_when(lastSync!)}' : ''}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Subsonic library cache',
            style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          'AutoQueue and "Suggested next" score against this cache instead of '
          'a random sample. Sync once after configuring a server; refresh '
          'when you add music server-side.',
          style: TextStyle(color: context.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 12),
        Text(status, style: const TextStyle(fontSize: 12)),
        if (syncing && total > 0) ...[
          const SizedBox(height: 6),
          LinearProgressIndicator(value: done / total),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            FilledButton.icon(
              onPressed: syncing ? null : onSync,
              icon: const Icon(Icons.sync),
              label: Text(cachedCount == 0 ? 'Sync library' : 'Re-sync'),
            ),
            const SizedBox(width: 12),
            if (syncing)
              TextButton(onPressed: onCancel, child: const Text('Cancel')),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text('Auto-refresh',
                style: TextStyle(color: context.textTertiary, fontSize: 12)),
            const Spacer(),
            DropdownButton<int>(
              value: const [0, 1, 3, 7, 14, 30].contains(refreshDays)
                  ? refreshDays
                  : 7,
              items: const [
                DropdownMenuItem(value: 0, child: Text('Off')),
                DropdownMenuItem(value: 1, child: Text('Daily')),
                DropdownMenuItem(value: 3, child: Text('Every 3 days')),
                DropdownMenuItem(value: 7, child: Text('Weekly')),
                DropdownMenuItem(value: 14, child: Text('Every 2 weeks')),
                DropdownMenuItem(value: 30, child: Text('Monthly')),
              ],
              onChanged: (v) { if (v != null) onSetRefreshDays(v); },
            ),
          ],
        ),
      ],
    );
  }

  static String _when(DateTime t) {
    final d = DateTime.now().difference(t);
    if (d.inMinutes < 1) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes} min ago';
    if (d.inHours < 24) return '${d.inHours} h ago';
    return '${d.inDays} d ago';
  }
}

/// Storage / auto-cache controls. Reads usage from [DownloadsManager],
/// writes the toggle + budget to [PlaybackPrefs]. The progress bar
/// visualises auto-cache pool occupancy; pinned downloads are reported
/// separately because they don't count against the budget.
class _StorageCard extends StatelessWidget {
  final bool enabled;
  final int autoBytes;
  final int pinnedBytes;
  final int maxBytes;
  final ValueChanged<bool> onToggleAuto;
  final ValueChanged<int> onSetMax;
  final VoidCallback onClear;
  const _StorageCard({
    required this.enabled,
    required this.autoBytes,
    required this.pinnedBytes,
    required this.maxBytes,
    required this.onToggleAuto,
    required this.onSetMax,
    required this.onClear,
  });

  // Round, human-meaningful stops. Linear-in-GB beyond 1 GB.
  static const _maxOptions = <int>[
    536870912,   // 512 MB
    1073741824,  // 1 GB
    2147483648,  // 2 GB
    5368709120,  // 5 GB
    10737418240, // 10 GB
    21474836480, // 20 GB
  ];

  static String _fmt(int b) {
    if (b >= 1024 * 1024 * 1024) {
      final gb = b / 1024 / 1024 / 1024;
      return gb >= 10 ? '${gb.toStringAsFixed(0)} GB' : '${gb.toStringAsFixed(gb == gb.truncateToDouble() ? 0 : 1)} GB';
    }
    return '${(b / 1024 / 1024).round()} MB';
  }

  @override
  Widget build(BuildContext context) {
    final filled = maxBytes <= 0 ? 0.0 : (autoBytes / maxBytes).clamp(0.0, 1.0);
    final dropdownValue = _maxOptions.contains(maxBytes)
        ? maxBytes
        : _maxOptions.firstWhere((o) => o >= maxBytes, orElse: () => _maxOptions.last);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Storage', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          'Anything you play is written to the on-disk pool so the next '
          'listen is offline-instant. The pool is LRU-evicted — pinned '
          'downloads are never touched.',
          style: TextStyle(color: context.textMuted, fontSize: 12),
        ),
        SwitchListTile.adaptive(
          contentPadding: EdgeInsets.zero,
          title: const Text('Auto-cache on play'),
          value: enabled,
          onChanged: onToggleAuto,
        ),
        Row(
          children: [
            Text('Max cache size',
                style: TextStyle(color: context.textSecondary, fontSize: 12)),
            const Spacer(),
            DropdownButton<int>(
              value: dropdownValue,
              items: _maxOptions
                  .map((b) => DropdownMenuItem(value: b, child: Text(_fmt(b))))
                  .toList(),
              onChanged: (v) { if (v != null) onSetMax(v); },
            ),
          ],
        ),
        const SizedBox(height: 6),
        LinearProgressIndicator(value: filled),
        const SizedBox(height: 6),
        Text(
          '${_fmt(autoBytes)} cached / ${_fmt(maxBytes)} max'
          '${pinnedBytes > 0 ? '   ·   ${_fmt(pinnedBytes)} pinned' : ''}',
          style: TextStyle(color: context.textTertiary, fontSize: 11),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: autoBytes > 0 ? onClear : null,
          icon: const Icon(Icons.delete_sweep_outlined),
          label: const Text('Clear auto-cache'),
        ),
      ],
    );
  }
}

/// Crossfade duration picker — off / 2s / 5s / 10s. The values come
/// straight from PlaybackPrefs; the engine reads `prefs.crossfadeMs`
/// every position tick + on every track switch, so picker changes take
/// effect at the next transition.
class _CrossfadePicker extends ConsumerWidget {
  final int currentMs;
  final ValueChanged<int> onChanged;
  const _CrossfadePicker({required this.currentMs, required this.onChanged});

  static const _options = <(int ms, String label)>[
    (0, 'Off'),
    (2000, '2 s'),
    (5000, '5 s'),
    (10000, '10 s'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ref.watch(accentTintProvider).valueOrNull ?? brandAccent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Crossfade',
            style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          'Fades the end of one track into the start of the next. '
          'Pseudo-crossfade — no overlap, but the perceived effect is '
          'the same for typical music. Gapless playback (no silent '
          'gap between tracks of the same album) is always on.',
          style: TextStyle(color: context.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final o in _options)
              ChoiceChip(
                label: Text(o.$2),
                selected: currentMs == o.$1,
                onSelected: (_) => onChanged(o.$1),
                selectedColor: accent,
                labelStyle: TextStyle(
                    color: currentMs == o.$1
                        ? Colors.black
                        : context.textSecondary),
              ),
          ],
        ),
      ],
    );
  }
}

/// Per-Bluetooth-device EQ override. Shows the currently-connected BT
/// device (if any) + a button to capture the current sliders as that
/// device's saved profile. Below: list of every remembered device
/// with a delete button. Auto-applies when a known BT device becomes
/// the active output (handled by [BtEqService] in app boot).
class _BtEqCard extends ConsumerStatefulWidget {
  const _BtEqCard();
  @override
  ConsumerState<_BtEqCard> createState() => _BtEqCardState();
}

class _BtEqCardState extends ConsumerState<_BtEqCard> {
  Map<String, List<double>> _profiles = const {};

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final m = await ref.read(btEqProvider).profiles();
    if (mounted) setState(() => _profiles = m);
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(btActiveDeviceProvider).valueOrNull;
    final prefs = ref.read(playbackPrefsProvider);
    final accent = ref.watch(accentTintProvider).valueOrNull ?? brandAccent;
    final entries = _profiles.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Per-Bluetooth-device EQ',
            style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(
          'Save a snapshot of the current EQ sliders as the profile for '
          'a specific BT device. Auto-applied next time that device '
          'becomes the active output.',
          style: TextStyle(color: context.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 10),
        if (active != null)
          Row(
            children: [
              Icon(Icons.bluetooth_audio, size: 16, color: accent),
              const SizedBox(width: 6),
              Expanded(
                child: Text(active.split('|').first,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ),
              FilledButton.icon(
                icon: const Icon(Icons.save, size: 16),
                label: const Text('Save current EQ'),
                onPressed: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  await ref
                      .read(btEqProvider)
                      .saveCurrentAs(active, List.of(prefs.eqGainsDb));
                  await _refresh();
                  messenger.showSnackBar(SnackBar(
                      content:
                          Text('Saved for "${active.split('|').first}"')));
                },
              ),
            ],
          )
        else
          Text('No Bluetooth output active.',
              style: TextStyle(color: context.textTertiary, fontSize: 12)),
        if (entries.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('Saved profiles',
              style: TextStyle(
                  color: context.textTertiary,
                  fontSize: 11,
                  letterSpacing: 1.2,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          for (final e in entries)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.bluetooth, size: 16),
              title: Text(e.key.split('|').first,
                  style: const TextStyle(fontSize: 13)),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, size: 18),
                tooltip: 'Forget device',
                onPressed: () async {
                  await ref.read(btEqProvider).forget(e.key);
                  await _refresh();
                },
              ),
            ),
        ],
      ],
    );
  }
}

/// ListenBrainz token field. When set, the engine also scrobbles
/// "playing_now" + "single" listens to listenbrainz.org alongside the
/// Subsonic server scrobble. Get a token from
/// https://listenbrainz.org/profile/ → "User token".
class _ListenBrainzCard extends ConsumerStatefulWidget {
  final String token;
  final ValueChanged<String> onChanged;
  const _ListenBrainzCard({required this.token, required this.onChanged});
  @override
  ConsumerState<_ListenBrainzCard> createState() => _ListenBrainzCardState();
}

class _ListenBrainzCardState extends ConsumerState<_ListenBrainzCard> {
  late final TextEditingController _ctrl;
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: widget.token);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.token.isNotEmpty;
    final accent = ref.watch(accentTintProvider).valueOrNull ?? brandAccent;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('ListenBrainz',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            if (active)
              Icon(Icons.check_circle, size: 14, color: accent),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Open scrobbling alternative to Last.fm. Paste a user token '
          'from https://listenbrainz.org/profile/ → "User token" — the '
          'engine then sends "playing_now" at track start and a '
          '"single" listen at the Last.fm threshold. Subsonic scrobbling '
          '(if your server has it) keeps running in parallel.',
          style: TextStyle(color: context.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _ctrl,
          obscureText: _obscure,
          decoration: InputDecoration(
            hintText: 'User token (UUID)',
            suffixIcon: IconButton(
              tooltip: _obscure ? 'Show token' : 'Hide token',
              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          onChanged: widget.onChanged,
        ),
      ],
    );
  }
}

/// Last.fm direct scrobble — runs in parallel to ListenBrainz +
/// Subsonic-server scrobble. Needed because Navidrome's Last.fm
/// integration only enriches metadata; it does NOT forward user
/// listens to Last.fm. Auth is the classic 2-step desktop flow
/// (request token → browser approval → exchange for session key);
/// the session key is persisted in [PlaybackPrefs] and reused for
/// every subsequent scrobble.
///
/// If the build was made without the `LASTFM_API_KEY` /
/// `LASTFM_SHARED_SECRET` dart-defines (e.g. a debug local build),
/// the card disables itself and explains why — there's nothing the
/// user can do at runtime to fix that.
class _LastfmCard extends ConsumerStatefulWidget {
  const _LastfmCard();
  @override
  ConsumerState<_LastfmCard> createState() => _LastfmCardState();
}

class _LastfmCardState extends ConsumerState<_LastfmCard> {
  /// Set after step 1 (requestToken). Null again after step 2
  /// (exchangeToken) succeeds OR the user cancels.
  String? _pendingToken;
  String? _pendingBrowserUrl;
  bool _busy = false;
  String? _error;

  Future<void> _connect() async {
    final client = ref.read(lastfmScrobbleClientProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await client.requestToken();
      await launchUrl(Uri.parse(r.browserUrl), mode: LaunchMode.externalApplication);
      if (!mounted) return;
      setState(() {
        _pendingToken = r.token;
        _pendingBrowserUrl = r.browserUrl;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _finish() async {
    final token = _pendingToken;
    if (token == null) return;
    final client = ref.read(lastfmScrobbleClientProvider);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await client.exchangeToken(token);
      final prefs = ref.read(playbackPrefsProvider);
      prefs.lastfmSessionKey = r.sessionKey;
      prefs.lastfmUsername = r.username;
      await prefs.save();
      if (!mounted) return;
      setState(() {
        _pendingToken = null;
        _pendingBrowserUrl = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _disconnect() async {
    final prefs = ref.read(playbackPrefsProvider);
    prefs.lastfmSessionKey = '';
    prefs.lastfmUsername = '';
    await prefs.save();
    if (mounted) {
      setState(() {
        _pendingToken = null;
        _pendingBrowserUrl = null;
        _error = null;
      });
    }
  }

  void _cancelPending() {
    setState(() {
      _pendingToken = null;
      _pendingBrowserUrl = null;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final prefs = ref.watch(playbackPrefsProvider);
    final client = ref.watch(lastfmScrobbleClientProvider);
    final connected = client.enabled;
    final pending = _pendingToken != null;
    final accent = ref.watch(accentTintProvider).valueOrNull ?? brandAccent;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('Last.fm', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(width: 8),
            if (connected)
              Icon(Icons.check_circle, size: 14, color: accent),
            if (connected) ...[
              const SizedBox(width: 6),
              Text(prefs.lastfmUsername,
                  style: TextStyle(color: context.textMuted, fontSize: 12)),
            ],
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Scrobble directly to Last.fm in parallel with Subsonic and '
          'ListenBrainz. Navidrome\'s Last.fm integration only fetches '
          'artist images / similar artists — it does NOT forward your '
          'listens, so this is the only way to get your plays on '
          'last.fm/user/<you> when running Navidrome.',
          style: TextStyle(color: context.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 8),
        if (!client.configurable)
          Text(
            'This APK was built without LASTFM_API_KEY / '
            'LASTFM_SHARED_SECRET dart-defines. Last.fm direct scrobble '
            'is unavailable in this build.',
            style: TextStyle(
                color: Colors.amber.shade300,
                fontStyle: FontStyle.italic,
                fontSize: 12),
          )
        else if (connected)
          OutlinedButton.icon(
            onPressed: _busy ? null : _disconnect,
            icon: const Icon(Icons.link_off, size: 16),
            label: const Text('Disconnect Last.fm'),
          )
        else if (pending)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Step 2 of 2: in the browser tab that just opened, click '
                '"Yes, allow access". When it shows "You can now close '
                'this window", come back here and tap Finish.',
                style: TextStyle(color: context.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  FilledButton.icon(
                    onPressed: _busy ? null : _finish,
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.black,
                    ),
                    icon: _busy
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.black))
                        : const Icon(Icons.check, size: 16),
                    label: const Text('I approved — finish'),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: _busy ? null : _cancelPending,
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  if (_pendingBrowserUrl != null)
                    IconButton(
                      tooltip: 'Copy approval URL',
                      icon: const Icon(Icons.copy, size: 18),
                      onPressed: () => Clipboard.setData(
                          ClipboardData(text: _pendingBrowserUrl!)),
                    ),
                ],
              ),
            ],
          )
        else
          FilledButton.icon(
            onPressed: _busy ? null : _connect,
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.black,
            ),
            icon: _busy
                ? const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black))
                : const Icon(Icons.link, size: 16),
            label: const Text('Connect Last.fm'),
          ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Text(
            _error!,
            style: TextStyle(color: Colors.redAccent.shade200, fontSize: 12),
          ),
        ],
      ],
    );
  }
}

/// Replay Gain mode picker (off / track / album). Server must expose
/// the OpenSubsonic `replayGain` field per song for this to do
/// anything — stock Subsonic ≤ 1.16 ignores it silently. We don't
/// boost (no pre-amp): RG values are typically negative, so the
/// adjustment is always an attenuation. Loud tracks get pulled down
/// to the loudness reference; quiet tracks are left at 1.0.
class _RgPicker extends StatelessWidget {
  final String mode;
  final ValueChanged<String> onChanged;
  const _RgPicker({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Volume normalisation',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            'Replay Gain — equalises perceived loudness across tracks. '
            'Requires an OpenSubsonic-compatible server (Navidrome, recent '
            'Gonic). Track mode normalises every track; Album mode '
            'preserves intra-album dynamics.',
            style: TextStyle(color: context.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 8),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'off', label: Text('Off')),
              ButtonSegment(value: 'track', label: Text('Track')),
              ButtonSegment(value: 'album', label: Text('Album')),
            ],
            selected: {mode},
            onSelectionChanged: (s) => onChanged(s.first),
          ),
        ],
      );
}

/// 5-band-style presets centered around the typical Android Equalizer
/// layout (60 / 230 / 910 / 3.6k / 14k Hz). On devices with more or
/// fewer bands, [_applyPreset] pads with 0 or truncates.
///
/// Values are derived from iTunes' published preset curves (the
/// de-facto industry reference since 2001 — Apple's audio team
/// recalibrates them per major macOS / iOS release, and most music
/// apps inherit from this set: AIMP, VLC, foobar2000, etc.).
/// All gains are kept ≤ ±5 dB, well below the previous arbitrary
/// ±8 dB curves which produced muddy bass + harsh treble.
///
/// "Loudness" is the Fletcher-Munson compensation curve (AES/ITU
/// reference for perceived flatness at low listening levels — boost
/// bass + a touch of treble when the volume is quiet).
class _EqPresets extends ConsumerWidget {
  final bool enabled;
  final int bandCount;
  final ValueChanged<List<double>> onApply;
  final List<({String name, List<double> gains})> customPresets;
  final ValueChanged<({String name, List<double> gains})> onDelete;
  final VoidCallback onSave;
  const _EqPresets({
    required this.enabled,
    required this.bandCount,
    required this.onApply,
    required this.customPresets,
    required this.onDelete,
    required this.onSave,
  });

  static const _presets = <(String, List<double>)>[
    ('Flat',       [ 0,  0,  0,  0,  0]),
    ('Bass boost', [ 5,  3,  0,  0,  0]),
    ('Jazz',       [ 2,  1,  0,  1,  2]),
    ('Loudness',   [ 4,  0,  0,  0,  3]),
    ('Pop',        [-1,  2,  3,  2, -1]),
    ('Rock',       [ 3,  2, -1,  2,  3]),
    ('Vocal',      [-2, -1,  3,  2,  0]),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final accent = ref.watch(accentTintProvider).valueOrNull ?? brandAccent;
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final p in _presets)
          ActionChip(
            label: Text(p.$1, style: const TextStyle(fontSize: 12)),
            onPressed: enabled
                ? () => onApply(p.$2.map((e) => e.toDouble()).toList())
                : null,
          ),
        // User-saved presets render as InputChips so the user can
        // delete them via the trailing X. The label rounds to the
        // same chip look so they read as peers of the built-ins,
        // not as a separate type of thing.
        for (final p in customPresets)
          InputChip(
            label: Text(p.name, style: const TextStyle(fontSize: 12)),
            onPressed: enabled ? () => onApply(p.gains) : null,
            onDeleted: () => onDelete(p),
            deleteIconColor: accent,
          ),
        // "Save current curve as preset" — always tappable while
        // the eq is configured (params resolved), even when the
        // user has the eq toggle off. Saving the gains shouldn't
        // require the eq to be live.
        ActionChip(
          avatar: const Icon(Icons.add, size: 16),
          label: const Text('Save…', style: TextStyle(fontSize: 12)),
          onPressed: onSave,
        ),
      ],
    );
  }
}

class _BandRow extends StatelessWidget {
  final AndroidEqualizerBand band;
  final double gainDb;
  final double minDb;
  final double maxDb;
  final bool enabled;
  final ValueChanged<double> onChanged;
  const _BandRow({
    required this.band,
    required this.gainDb,
    required this.minDb,
    required this.maxDb,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final hz = band.centerFrequency;
    final label = hz >= 1000 ? '${(hz / 1000).toStringAsFixed(hz % 1000 == 0 ? 0 : 1)} kHz'
                              : '${hz.toStringAsFixed(0)} Hz';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 64,
            child: Text(label, style: TextStyle(color: context.textSecondary, fontSize: 12)),
          ),
          Expanded(
            child: Slider(
              value: gainDb.clamp(minDb, maxDb),
              min: minDb,
              max: maxDb,
              onChanged: enabled ? onChanged : null,
            ),
          ),
          SizedBox(
            width: 56,
            child: Text(
              '${gainDb >= 0 ? '+' : ''}${gainDb.toStringAsFixed(1)} dB',
              textAlign: TextAlign.end,
              style: TextStyle(
                color: enabled ? context.textSecondary : context.textDisabled,
                fontSize: 11,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
