import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../audio/providers.dart';
import '../core/db.dart';
import '../domain.dart';
import 'widgets/mini_player.dart';
import 'widgets/theme_ext.dart';
import 'widgets/track_tile.dart';

const _accent = Color(0xFF1ED760);

// =====================================================================
// VIEWER PAGE — runs the rules + displays the matching tracks.
// =====================================================================

class SmartPlaylistViewPage extends ConsumerWidget {
  final int id;
  const SmartPlaylistViewPage({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return FutureBuilder<SmartPlaylist?>(
      future: ref.read(smartPlaylistsProvider).get(id),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final p = snap.data;
        if (p == null) {
          return const Scaffold(body: Center(child: Text('Playlist not found.')));
        }
        return _SmartPlaylistBody(playlist: p);
      },
    );
  }
}

class _SmartPlaylistBody extends ConsumerStatefulWidget {
  final SmartPlaylist playlist;
  const _SmartPlaylistBody({required this.playlist});
  @override
  ConsumerState<_SmartPlaylistBody> createState() => _SmartPlaylistBodyState();
}

class _SmartPlaylistBodyState extends ConsumerState<_SmartPlaylistBody> {
  Future<List<Track>>? _tracks;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  void _reload() {
    final activeFuture = ref.read(settingsStoreProvider).active();
    setState(() {
      _tracks = activeFuture.then((active) {
        if (active == null) return <Track>[];
        return ref
            .read(smartPlaylistsProvider)
            .execute(widget.playlist, active.id);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: const MiniPlayer(),
      appBar: AppBar(
        title: Text(widget.playlist.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
            tooltip: 'Re-run rules',
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            tooltip: 'Edit rules',
            onPressed: () async {
              await context.push('/playlist/smart/${widget.playlist.id}/edit');
              _reload(); // rules may have changed
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete',
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text('Delete "${widget.playlist.name}"?'),
                  content: const Text('Only the rules are removed. The tracks themselves are untouched.'),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                    FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
                  ],
                ),
              );
              if (ok == true && context.mounted) {
                await ref.read(smartPlaylistsProvider).delete(widget.playlist.id);
                if (context.mounted) Navigator.pop(context);
              }
            },
          ),
        ],
      ),
      body: FutureBuilder<List<Track>>(
        future: _tracks,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final tracks = snap.data ?? const [];
          if (tracks.isEmpty) {
            return Center(
                child: Text('No tracks match the current rules.',
                    style: TextStyle(color: context.textMuted)));
          }
          return ListView.builder(
            itemCount: tracks.length + 1,
            itemBuilder: (_, i) {
              if (i == 0) {
                return Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () =>
                              ref.read(audioEngineProvider).setQueue(tracks),
                          icon: const Icon(Icons.play_arrow),
                          label: Text('Play all (${tracks.length})'),
                          style: FilledButton.styleFrom(
                            backgroundColor: _accent,
                            foregroundColor: Colors.black,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton.icon(
                        onPressed: () {
                          final shuffled = [...tracks]..shuffle();
                          ref.read(audioEngineProvider).setQueue(shuffled);
                        },
                        icon: const Icon(Icons.shuffle),
                        label: const Text('Shuffle'),
                      ),
                    ],
                  ),
                );
              }
              return TrackTile(queue: tracks, index: i - 1);
            },
          );
        },
      ),
    );
  }
}

// =====================================================================
// EDITOR PAGE — name + match-all/any + rule rows + order + limit.
// =====================================================================

/// `id == 'new'` ⇒ creation, otherwise edits an existing playlist.
class SmartPlaylistEditPage extends ConsumerStatefulWidget {
  final String id;
  const SmartPlaylistEditPage({super.key, required this.id});
  @override
  ConsumerState<SmartPlaylistEditPage> createState() =>
      _SmartPlaylistEditPageState();
}

class _SmartPlaylistEditPageState extends ConsumerState<SmartPlaylistEditPage> {
  final _name = TextEditingController();
  String _match = 'all';
  List<_RuleDraft> _rules = [];
  String _orderBy = 'random';
  String _orderDir = 'desc';
  int _limit = 50;
  bool _loaded = false;

  bool get _isNew => widget.id == 'new';
  int get _id => int.tryParse(widget.id) ?? 0;

  @override
  void initState() {
    super.initState();
    _hydrate();
  }

  Future<void> _hydrate() async {
    if (!_isNew) {
      final p = await ref.read(smartPlaylistsProvider).get(_id);
      if (p != null) {
        _name.text = p.name;
        final rules = jsonDecode(p.rulesJson) as Map<String, dynamic>;
        _match = (rules['match'] as String?) ?? 'all';
        _orderBy = (rules['orderBy'] as String?) ?? 'random';
        _orderDir = (rules['orderDir'] as String?) ?? 'desc';
        _limit = (rules['limit'] as int?) ?? 50;
        _rules = ((rules['rules'] as List?) ?? [])
            .map((r) => _RuleDraft.fromJson(r as Map<String, dynamic>))
            .toList();
      }
    }
    if (_rules.isEmpty) _rules = [_RuleDraft()];
    setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Map<String, dynamic> _build() => {
        'match': _match,
        'rules': _rules.where((r) => r.isValid()).map((r) => r.toJson()).toList(),
        'orderBy': _orderBy,
        'orderDir': _orderDir,
        'limit': _limit,
      };

  Future<void> _save() async {
    final mgr = ref.read(smartPlaylistsProvider);
    final name = _name.text.trim().isEmpty ? 'Smart playlist' : _name.text.trim();
    if (_isNew) {
      await mgr.create(name: name, rules: _build());
    } else {
      await mgr.update(_id, name: name, rules: _build());
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      bottomNavigationBar: const MiniPlayer(),
      appBar: AppBar(
        title: Text(_isNew ? 'New smart playlist' : 'Edit smart playlist'),
        actions: [
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(hintText: 'Name'),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Match'),
              const SizedBox(width: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'all', label: Text('All')),
                  ButtonSegment(value: 'any', label: Text('Any')),
                ],
                selected: {_match},
                onSelectionChanged: (s) => setState(() => _match = s.first),
              ),
            ],
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < _rules.length; i++)
            _RuleRow(
              draft: _rules[i],
              onChange: () => setState(() {}),
              onDelete: () => setState(() => _rules.removeAt(i)),
            ),
          TextButton.icon(
            icon: const Icon(Icons.add),
            label: const Text('Add rule'),
            onPressed: () => setState(() => _rules.add(_RuleDraft())),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              const Text('Order by'),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButton<String>(
                  value: _orderBy,
                  isExpanded: true,
                  items: const [
                    DropdownMenuItem(value: 'random', child: Text('Random')),
                    DropdownMenuItem(value: 'year', child: Text('Year')),
                    DropdownMenuItem(value: 'title', child: Text('Title')),
                    DropdownMenuItem(value: 'artist', child: Text('Artist')),
                    DropdownMenuItem(value: 'durationSec', child: Text('Duration')),
                  ],
                  onChanged: (v) => setState(() => _orderBy = v ?? 'random'),
                ),
              ),
              if (_orderBy != 'random')
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'asc', label: Text('↑')),
                    ButtonSegment(value: 'desc', label: Text('↓')),
                  ],
                  selected: {_orderDir},
                  onSelectionChanged: (s) => setState(() => _orderDir = s.first),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Limit'),
              const SizedBox(width: 12),
              SizedBox(
                width: 80,
                child: TextFormField(
                  initialValue: '$_limit',
                  keyboardType: TextInputType.number,
                  onChanged: (v) {
                    final n = int.tryParse(v);
                    if (n != null && n > 0) _limit = n.clamp(1, 1000);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Text('tracks',
                  style: TextStyle(color: context.textTertiary, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _RuleDraft {
  String field;
  String op;
  String value; // serialised as text in the UI; parsed on save
  String value2; // for "between"

  _RuleDraft({
    this.field = 'genre',
    this.op = 'eq',
    this.value = '',
    this.value2 = '',
  });

  factory _RuleDraft.fromJson(Map<String, dynamic> j) {
    final f = j['field'] as String? ?? 'genre';
    final o = j['op'] as String? ?? 'eq';
    final v = j['value'];
    String s1 = '';
    String s2 = '';
    if (v is List && v.length == 2) {
      s1 = v[0].toString();
      s2 = v[1].toString();
    } else if (v != null) {
      s1 = v.toString();
    }
    return _RuleDraft(field: f, op: o, value: s1, value2: s2);
  }

  Map<String, dynamic> toJson() {
    dynamic v;
    if (op == 'between') {
      v = [_parse(value), _parse(value2)];
    } else {
      v = _parse(value);
    }
    return {'field': field, 'op': op, 'value': v};
  }

  dynamic _parse(String s) {
    if (_isBoolField()) return value == 'true';
    if (_isIntField()) return int.tryParse(s) ?? 0;
    return s;
  }

  bool isValid() {
    // Boolean fields don't have a free-text value — they're set via
    // the segmented true/false control, always valid.
    if (_isBoolField()) return true;
    if (value.isEmpty) return false;
    if (op == 'between' && value2.isEmpty) return false;
    return true;
  }

  /// Plain integer columns from CachedSubsonicSongs.
  bool _isIntField() =>
      field == 'year' ||
      field == 'durationSec' ||
      _isComputedIntField();

  /// v2 fields backed by subquery COUNT / time-delta — int comparison
  /// semantics, just not stored as a column.
  bool _isComputedIntField() =>
      field == 'playCount30d' ||
      field == 'playCountAll' ||
      field == 'lastPlayedDaysAgo';

  /// v2 fields backed by EXISTS / NOT EXISTS joins.
  bool _isBoolField() =>
      field == 'favourite' || field == 'pinned' || field == 'cached';
}

class _RuleRow extends StatelessWidget {
  final _RuleDraft draft;
  final VoidCallback onChange;
  final VoidCallback onDelete;
  const _RuleRow({
    required this.draft,
    required this.onChange,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // Op set varies by family: bool fields force eq, ints get the
    // full comparator set (no `contains`), text columns get eq/neq/
    // contains. v1 logic preserved for plain columns.
    final ops = draft._isBoolField()
        ? const ['eq']
        : draft._isIntField()
            ? const ['eq', 'neq', 'gt', 'gte', 'lt', 'lte', 'between']
            : const ['eq', 'neq', 'contains'];
    if (!ops.contains(draft.op)) draft.op = ops.first;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          // Field
          Expanded(
            flex: 3,
            child: DropdownButton<String>(
              value: draft.field,
              isExpanded: true,
              items: const [
                // Plain columns (v1)
                DropdownMenuItem(value: 'genre', child: Text('Genre')),
                DropdownMenuItem(value: 'artist', child: Text('Artist')),
                DropdownMenuItem(value: 'album', child: Text('Album')),
                DropdownMenuItem(value: 'title', child: Text('Title')),
                DropdownMenuItem(value: 'year', child: Text('Year')),
                DropdownMenuItem(value: 'durationSec', child: Text('Duration s')),
                // v2 boolean joins
                DropdownMenuItem(value: 'favourite', child: Text('Favourite')),
                DropdownMenuItem(value: 'pinned', child: Text('Pinned')),
                DropdownMenuItem(value: 'cached', child: Text('Cached')),
                // v2 computed ints
                DropdownMenuItem(value: 'playCount30d', child: Text('Plays (30 d)')),
                DropdownMenuItem(value: 'playCountAll', child: Text('Plays (all-time)')),
                DropdownMenuItem(value: 'lastPlayedDaysAgo', child: Text('Days since last play')),
              ],
              onChanged: (v) {
                draft.field = v ?? 'genre';
                onChange();
              },
            ),
          ),
          const SizedBox(width: 6),
          // Op
          Expanded(
            flex: 2,
            child: DropdownButton<String>(
              value: draft.op,
              isExpanded: true,
              items: [
                for (final o in ops)
                  DropdownMenuItem(value: o, child: Text(_opLabel(o))),
              ],
              onChanged: (v) {
                draft.op = v ?? 'eq';
                onChange();
              },
            ),
          ),
          const SizedBox(width: 6),
          // Value(s)
          Expanded(
            flex: 3,
            child: draft._isBoolField()
                ? SegmentedButton<String>(
                    style: const ButtonStyle(
                      visualDensity: VisualDensity.compact,
                    ),
                    segments: const [
                      ButtonSegment(value: 'true', label: Text('Yes')),
                      ButtonSegment(value: 'false', label: Text('No')),
                    ],
                    selected: {draft.value.isEmpty ? 'true' : draft.value},
                    onSelectionChanged: (s) {
                      draft.value = s.first;
                      onChange();
                    },
                  )
                : draft.op == 'between'
                    ? Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              initialValue: draft.value,
                              keyboardType: draft._isIntField()
                                  ? TextInputType.number
                                  : TextInputType.text,
                              decoration: const InputDecoration(hintText: 'min'),
                              onChanged: (v) {
                                draft.value = v;
                                onChange();
                              },
                            ),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: TextFormField(
                              initialValue: draft.value2,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(hintText: 'max'),
                              onChanged: (v) {
                                draft.value2 = v;
                                onChange();
                              },
                            ),
                          ),
                        ],
                      )
                    : TextFormField(
                        initialValue: draft.value,
                        keyboardType: draft._isIntField()
                            ? TextInputType.number
                            : TextInputType.text,
                        decoration: const InputDecoration(hintText: 'value'),
                        onChanged: (v) {
                      draft.value = v;
                      onChange();
                    },
                  ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            tooltip: 'Remove rule',
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }

  String _opLabel(String op) {
    switch (op) {
      case 'eq':
        return '=';
      case 'neq':
        return '≠';
      case 'gt':
        return '>';
      case 'gte':
        return '≥';
      case 'lt':
        return '<';
      case 'lte':
        return '≤';
      case 'between':
        return 'between';
      case 'contains':
        return 'contains';
    }
    return op;
  }
}
