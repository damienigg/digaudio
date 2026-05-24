import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../audio/providers.dart';
import '../core/settings.dart';
import '../subsonic/client.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});
  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _url = TextEditingController();
  final _user = TextEditingController();
  final _pass = TextEditingController();
  String? _status;
  bool _busy = false;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  Future<void> _hydrate() async {
    final cfg = await ref.read(settingsStoreProvider).load();
    if (cfg != null) {
      _url.text = cfg.url;
      _user.text = cfg.username;
      _pass.text = cfg.password;
    }
    if (mounted) setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _url.dispose();
    _user.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _testAndSave() async {
    setState(() {
      _busy = true;
      _status = null;
    });
    try {
      final client = SubsonicClient(
        baseUrl: _url.text.trim(),
        username: _user.text.trim(),
        password: _pass.text,
      );
      final ok = await client.ping();
      if (!ok) {
        setState(() => _status = 'Ping failed — check URL & credentials.');
        return;
      }
      await ref.read(settingsStoreProvider).save(ServerConfig(
            url: _url.text.trim(),
            username: _user.text.trim(),
            password: _pass.text,
          ));
      ref.invalidate(serverConfigProvider);
      ref.invalidate(newestAlbumsProvider);
      ref.invalidate(randomSongsProvider);
      ref.invalidate(subsonicArtistsProvider);
      ref.invalidate(subsonicPlaylistsProvider);
      setState(() => _status = 'Connected.');
    } catch (e) {
      setState(() => _status = 'Error: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _clear() async {
    await ref.read(settingsStoreProvider).clear();
    ref.invalidate(serverConfigProvider);
    if (mounted) {
      _url.clear();
      _user.clear();
      _pass.clear();
      setState(() => _status = 'Cleared.');
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Settings')),
        body: !_loaded
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text('Subsonic server',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _url,
                    decoration: const InputDecoration(hintText: 'https://music.example.com'),
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
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: _busy ? null : _testAndSave,
                          child: _busy
                              ? const SizedBox(
                                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Test & save'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      TextButton(onPressed: _busy ? null : _clear, child: const Text('Clear')),
                    ],
                  ),
                  if (_status != null) ...[
                    const SizedBox(height: 16),
                    Text(_status!, style: const TextStyle(color: Colors.white70)),
                  ],
                ],
              ),
      );
}
