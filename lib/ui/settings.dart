import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:just_audio/just_audio.dart';

import '../audio/providers.dart';
import '../core/settings.dart';

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
              trailing: const Icon(Icons.chevron_right, color: Colors.white38),
              onTap: () => context.push('/settings/servers'),
            ),
            const Divider(height: 1, color: Colors.white12),
            ListTile(
              leading: const Icon(Icons.equalizer),
              title: const Text('Playback'),
              subtitle: const Text('Equalizer'),
              trailing: const Icon(Icons.chevron_right, color: Colors.white38),
              onTap: () => context.push('/settings/playback'),
            ),
          ],
        ),
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
                separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white12),
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
  Widget build(BuildContext context) => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text(
            'No Subsonic server registered yet.\nTap "Add server" to start.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white60),
          ),
        ),
      );
}

class _ServerTile extends StatelessWidget {
  final ServerConfig server;
  final bool active;
  final VoidCallback onActivate;
  const _ServerTile({required this.server, required this.active, required this.onActivate});

  @override
  Widget build(BuildContext context) {
    final status = server.isConfigured
        ? (active ? 'Active' : 'Tap to activate')
        : 'Credentials missing — tap to set';
    final color = active ? const Color(0xFF1ED760) : Colors.white54;
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
              style: const TextStyle(color: Colors.white54, fontSize: 11)),
          Text(status, style: TextStyle(color: color, fontSize: 11)),
        ],
      ),
      trailing: IconButton(
        icon: const Icon(Icons.edit_outlined),
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
          color: Colors.white12,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(text, style: const TextStyle(fontSize: 10, color: Colors.white70)),
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
            IconButton(icon: const Icon(Icons.delete_outline), onPressed: _busy ? null : _delete),
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
                  Text(_status!, style: const TextStyle(color: Colors.white70)),
                ],
              ],
            ),
    );
  }
}

/// Playback settings. Today: equalizer only. Crossfade lives here once the
/// audio_service refactor lands (true two-player overlap, see CHANGELOG).
class PlaybackPage extends ConsumerStatefulWidget {
  const PlaybackPage({super.key});
  @override
  ConsumerState<PlaybackPage> createState() => _PlaybackPageState();
}

class _PlaybackPageState extends ConsumerState<PlaybackPage> {
  AndroidEqualizerParameters? _params;
  List<double> _gainsDb = const [];
  bool _enabled = false;
  bool _ready = false;
  int _cachedCount = 0;
  DateTime? _lastSync;
  bool _syncing = false;
  int _syncDone = 0;
  int _syncTotal = 0;
  bool _cancelSync = false;

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  Future<void> _hydrate() async {
    final prefs = ref.read(playbackPrefsProvider);
    await prefs.load();
    final engine = ref.read(audioEngineProvider);
    final params = await engine.eqParameters;
    final stored = List<double>.from(prefs.eqGainsDb);
    while (stored.length < params.bands.length) {
      stored.add(0);
    }
    await _refreshCacheStatus();
    setState(() {
      _params = params;
      _enabled = prefs.eqEnabled;
      _gainsDb = stored;
      _ready = true;
    });
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

  Future<void> _resetFlat() async {
    final params = _params!;
    final flat = List<double>.filled(params.bands.length, 0);
    setState(() => _gainsDb = flat);
    final prefs = ref.read(playbackPrefsProvider);
    prefs.eqGainsDb = flat;
    await prefs.save();
    await ref.read(audioEngineProvider).applyEqGains(flat);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final params = _params!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Playback'),
        actions: [
          TextButton(onPressed: _resetFlat, child: const Text('Flat')),
        ],
      ),
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
          ),
          const Divider(height: 32, color: Colors.white12),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Auto-queue similar tracks',
                style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: const Text(
              'When the queue is about to end, append a similar track from '
              'your library (same algorithm as the "Suggested next" hint).',
              style: TextStyle(color: Colors.white54, fontSize: 12),
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
          const Divider(height: 32, color: Colors.white12),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Equalizer', style: TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(
              params.bands.isEmpty
                  ? 'No equalizer available on this device.'
                  : '${params.bands.length} bands · '
                      '${params.minDecibels.toStringAsFixed(0)} to ${params.maxDecibels.toStringAsFixed(0)} dB',
              style: const TextStyle(color: Colors.white54, fontSize: 12),
            ),
            value: _enabled,
            onChanged: params.bands.isEmpty ? null : _toggleEnabled,
          ),
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
        ],
      ),
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
  const _SubsonicCacheCard({
    required this.cachedCount,
    required this.lastSync,
    required this.syncing,
    required this.done,
    required this.total,
    required this.onSync,
    required this.onCancel,
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
        const Text(
          'AutoQueue and "Suggested next" score against this cache instead of '
          'a random sample. Sync once after configuring a server; refresh '
          'when you add music server-side.',
          style: TextStyle(color: Colors.white54, fontSize: 12),
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
            child: Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
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
                color: enabled ? Colors.white70 : Colors.white30,
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
