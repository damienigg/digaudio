import 'package:flutter/material.dart';

import 'theme_ext.dart';

/// Long-list scroller with an A→Z sidebar. Items are passed in their
/// existing order (the caller is responsible for sorting); the sidebar
/// computes the first index per letter on the fly. Tap or drag a letter
/// to jump — letters with no matching item are dimmed and inert. Items
/// share a fixed [itemExtent] so the jump can be done as
/// `controller.jumpTo(letterIndex * itemExtent)` without per-item layout.
class AlphaScrollList<T> extends StatefulWidget {
  final List<T> items;
  final String Function(T) labelOf;
  final Widget Function(BuildContext, T) builder;
  final double itemExtent;

  const AlphaScrollList({
    super.key,
    required this.items,
    required this.labelOf,
    required this.builder,
    this.itemExtent = 65,
  });

  @override
  State<AlphaScrollList<T>> createState() => _AlphaScrollListState<T>();
}

class _AlphaScrollListState<T> extends State<AlphaScrollList<T>> {
  final _ctrl = ScrollController();

  static const _letters = <String>[
    '#',
    'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J', 'K', 'L', 'M',
    'N', 'O', 'P', 'Q', 'R', 'S', 'T', 'U', 'V', 'W', 'X', 'Y', 'Z',
  ];

  String _letterOf(T item) {
    final s = widget.labelOf(item).trim();
    if (s.isEmpty) return '#';
    final c = s[0].toUpperCase();
    final cu = c.codeUnitAt(0);
    if (cu < 0x41 || cu > 0x5A) return '#';
    return c;
  }

  Map<String, int> _firstIndexByLetter() {
    final out = <String, int>{};
    for (var i = 0; i < widget.items.length; i++) {
      out.putIfAbsent(_letterOf(widget.items[i]), () => i);
    }
    return out;
  }

  /// Jump to the first item whose letter ≥ [letter], so empty letters
  /// gracefully degrade to the next populated one (better UX than no-op).
  void _jumpToLetter(String letter, Map<String, int> idx) {
    final start = _letters.indexOf(letter);
    if (start < 0) return;
    for (var i = start; i < _letters.length; i++) {
      final target = idx[_letters[i]];
      if (target != null) {
        _ctrl.jumpTo((target * widget.itemExtent)
            .clamp(0.0, _ctrl.position.maxScrollExtent));
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final idx = _firstIndexByLetter();
    return Row(
      children: [
        Expanded(
          child: ListView.builder(
            controller: _ctrl,
            itemCount: widget.items.length,
            itemExtent: widget.itemExtent,
            itemBuilder: (ctx, i) => widget.builder(ctx, widget.items[i]),
          ),
        ),
        SizedBox(
          width: 20,
          child: LayoutBuilder(
            builder: (_, c) {
              final letterHeight =
                  (c.maxHeight / _letters.length).clamp(10.0, 18.0);
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) => _jumpToLetter(
                  _letters[(d.localPosition.dy / letterHeight)
                      .floor()
                      .clamp(0, _letters.length - 1)],
                  idx,
                ),
                onVerticalDragUpdate: (d) => _jumpToLetter(
                  _letters[(d.localPosition.dy / letterHeight)
                      .floor()
                      .clamp(0, _letters.length - 1)],
                  idx,
                ),
                child: Column(
                  children: [
                    for (final l in _letters)
                      SizedBox(
                        height: letterHeight,
                        child: Center(
                          child: Text(
                            l,
                            style: TextStyle(
                              color: idx.containsKey(l)
                                  ? context.textSecondary
                                  : context.outlineStrong,
                              fontSize: 10,
                              fontWeight: idx.containsKey(l)
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }
}
