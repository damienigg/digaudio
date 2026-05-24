import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../subsonic/client.dart';

/// Persisted Subsonic server configuration.
///
/// One server tonight (the most common case). Credentials live in the platform
/// keychain via `flutter_secure_storage` — never in plaintext on disk.
class ServerConfig {
  final String url;
  final String username;
  final String password;
  const ServerConfig({required this.url, required this.username, required this.password});

  SubsonicClient client() => SubsonicClient(baseUrl: url, username: username, password: password);
}

class SettingsStore {
  static const _kUrl = 'subsonic.url';
  static const _kUser = 'subsonic.user';
  static const _kPass = 'subsonic.pass';
  final FlutterSecureStorage _s = const FlutterSecureStorage();

  Future<ServerConfig?> load() async {
    final url = await _s.read(key: _kUrl);
    final user = await _s.read(key: _kUser);
    final pass = await _s.read(key: _kPass);
    if (url == null || user == null || pass == null) return null;
    return ServerConfig(url: url, username: user, password: pass);
  }

  Future<void> save(ServerConfig c) async {
    await _s.write(key: _kUrl, value: c.url);
    await _s.write(key: _kUser, value: c.username);
    await _s.write(key: _kPass, value: c.password);
  }

  Future<void> clear() async {
    await _s.delete(key: _kUrl);
    await _s.delete(key: _kUser);
    await _s.delete(key: _kPass);
  }
}
