import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../subsonic/client.dart';

/// One Subsonic server entry.
///
/// Multiple [ServerConfig]s coexist in [SettingsStore]; exactly one is active
/// at any time. A server is *configured* (and usable by the engine) only when
/// both [username] and [password] are filled — the built-in default ships
/// with an empty creds pair, the user fills them on first use.
class ServerConfig {
  final String id;
  final String label;
  final String url;
  final String username;
  final String password;
  final bool builtin;

  const ServerConfig({
    required this.id,
    required this.label,
    required this.url,
    this.username = '',
    this.password = '',
    this.builtin = false,
  });

  bool get isConfigured => username.isNotEmpty && password.isNotEmpty;

  /// Returns a client iff credentials are present, else null. UI guards on this.
  /// The client stamps every parsed model with [id] so per-track stream / cover
  /// resolution routes back to the right host (multi-server search, v0.27.0).
  SubsonicClient? client() => isConfigured
      ? SubsonicClient(
          baseUrl: url,
          username: username,
          password: password,
          serverId: id,
        )
      : null;

  ServerConfig copyWith({String? label, String? url, String? username, String? password}) =>
      ServerConfig(
        id: id,
        label: label ?? this.label,
        url: url ?? this.url,
        username: username ?? this.username,
        password: password ?? this.password,
        builtin: builtin,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'label': label,
        'url': url,
        'username': username,
        'password': password,
        'builtin': builtin,
      };

  static ServerConfig fromJson(Map<String, dynamic> j) => ServerConfig(
        id: j['id'] as String,
        label: j['label'] as String,
        url: j['url'] as String,
        username: (j['username'] as String?) ?? '',
        password: (j['password'] as String?) ?? '',
        builtin: (j['builtin'] as bool?) ?? false,
      );
}

/// Compile-time built-in server URL (no credentials baked in — those are the
/// user's). Set with `--dart-define=SUBSONIC_URL=... [SUBSONIC_LABEL=...]`.
/// See `tool/run.example.sh`.
const String _envUrl = String.fromEnvironment('SUBSONIC_URL');
const String _envLabel = String.fromEnvironment('SUBSONIC_LABEL', defaultValue: 'Default server');
// `final` (not `const`) because `String.isEmpty` is not a const expression.
final ServerConfig? builtinServer = _envUrl.isEmpty
    ? null
    : const ServerConfig(id: 'builtin', label: _envLabel, url: _envUrl, builtin: true);

/// Persisted multi-server store. Encodes the list as a single JSON blob in
/// secure storage (one read/write per operation; trivially encrypted by the
/// platform keychain via `flutter_secure_storage`).
class SettingsStore {
  static const _kList = 'servers.v1.list';
  static const _kActive = 'servers.v1.active';
  static const _kSeeded = 'servers.v1.seeded';
  final FlutterSecureStorage _s = const FlutterSecureStorage();

  /// Loads all servers, seeding the built-in entry on the very first run (if
  /// available). The seed runs exactly once per install — user can remove the
  /// built-in afterwards without it being re-injected on every launch.
  Future<List<ServerConfig>> servers() async {
    final raw = await _s.read(key: _kList);
    final list = (raw == null || raw.isEmpty)
        ? <ServerConfig>[]
        : (jsonDecode(raw) as List)
            .map((e) => ServerConfig.fromJson(e as Map<String, dynamic>))
            .toList();
    if (list.isEmpty && builtinServer != null && (await _s.read(key: _kSeeded)) == null) {
      list.add(builtinServer!);
      await _writeList(list);
      await setActiveId(builtinServer!.id);
      await _s.write(key: _kSeeded, value: '1');
    }
    return list;
  }

  Future<String?> activeId() => _s.read(key: _kActive);

  Future<ServerConfig?> active() async {
    final id = await activeId();
    if (id == null) return null;
    final all = await servers();
    for (final s in all) {
      if (s.id == id) return s;
    }
    return all.isEmpty ? null : all.first;
  }

  Future<void> setActiveId(String id) => _s.write(key: _kActive, value: id);

  Future<void> upsert(ServerConfig server) async {
    final all = await servers();
    final i = all.indexWhere((s) => s.id == server.id);
    if (i >= 0) {
      all[i] = server;
    } else {
      all.add(server);
    }
    await _writeList(all);
  }

  Future<void> remove(String id) async {
    final all = await servers();
    all.removeWhere((s) => s.id == id);
    await _writeList(all);
    if (await activeId() == id) {
      await _s.write(key: _kActive, value: all.isEmpty ? '' : all.first.id);
    }
  }

  Future<void> _writeList(List<ServerConfig> list) =>
      _s.write(key: _kList, value: jsonEncode(list.map((s) => s.toJson()).toList()));

  /// Generates a fresh, opaque server id. Not cryptographically strong — just
  /// collision-resistant for a small local list.
  static String newId() =>
      DateTime.now().microsecondsSinceEpoch.toRadixString(36) +
      DateTime.now().millisecond.toRadixString(36);
}
