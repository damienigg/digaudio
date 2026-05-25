import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain.dart';

/// Global multi-select state for any TrackTile list. Keyed by
/// [Track.uniqueKey]; full Tracks are kept so the bulk-action bar can
/// act on them without re-resolving (favourite / queue / playlist add
/// only need the keys, but download + play-next need the full Track).
///
/// Selection is global on purpose — a user can long-press tracks in
/// Library → Tracks, navigate to Search to find more, long-press a few
/// from there, then act on the union from the bottom bar. The X button
/// always clears.
class SelectionNotifier extends StateNotifier<Map<String, Track>> {
  SelectionNotifier() : super(const {});

  bool contains(String key) => state.containsKey(key);
  bool get isEmpty => state.isEmpty;
  int get length => state.length;
  List<Track> get tracks => state.values.toList();

  void toggle(Track t) {
    final next = Map<String, Track>.from(state);
    if (next.containsKey(t.uniqueKey)) {
      next.remove(t.uniqueKey);
    } else {
      next[t.uniqueKey] = t;
    }
    state = next;
  }

  void clear() {
    if (state.isNotEmpty) state = const {};
  }
}
