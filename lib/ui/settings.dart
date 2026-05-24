import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../audio/providers.dart';
import '../core/settings.dart';

/// Settings = list of Subsonic servers. One is active at a time.
/// The built-in entry (URL baked at build time) is seeded once on first run.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servers = ref.watch(serversProvider);
    final activeAsync = ref.watch(activeServerProvider);
    final activeId = activeAsync.valueOrNull?.id;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
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
