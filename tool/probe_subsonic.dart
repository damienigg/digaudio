// Standalone Subsonic ping + browse probe. Run with:
//   dart run tool/probe_subsonic.dart <baseUrl> <username> <password>
// Exits 0 on success, prints the first few albums + a random song. Useful to
// validate server reachability and credentials without touching the UI.
//
// ignore_for_file: avoid_print

import 'package:digaudio/subsonic/client.dart';

Future<void> main(List<String> args) async {
  if (args.length != 3) {
    print('usage: dart run tool/probe_subsonic.dart <baseUrl> <username> <password>');
    return;
  }
  final c = SubsonicClient(baseUrl: args[0], username: args[1], password: args[2]);
  final ok = await c.ping();
  print('ping: $ok');
  if (!ok) return;
  final albums = await c.getAlbumList(size: 5);
  print('newest ${albums.length} albums:');
  for (final a in albums) {
    print('  - ${a.artist ?? "?"} — ${a.title}${a.year != null ? " (${a.year})" : ""}');
  }
  final randoms = await c.getRandomSongs(size: 3);
  print('random ${randoms.length} songs:');
  for (final s in randoms) {
    print('  - ${s.displayArtist} — ${s.title}  [${s.contentType ?? "?"}${s.bitRate != null ? ", ${s.bitRate} kbps" : ""}]');
  }
}
