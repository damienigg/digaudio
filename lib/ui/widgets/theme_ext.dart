import 'package:flutter/material.dart';

/// Theme-aware replacements for the hardcoded `Colors.white*` palette that
/// originated when digaudio was dark-only. Each opacity step on white
/// maps to one named alias here, defined relative to `colorScheme.onSurface`
/// so the same UI re-skins automatically when the user picks light mode.
///
/// Mapping rationale:
///   - Colors.white70 → primary secondary text (icon-on-surface)
///   - Colors.white60 → muted secondary
///   - Colors.white54 → subtitle / hint-ish
///   - Colors.white38 → disabled, very low emphasis
///   - Colors.white24 → strong outline / inactive control track
///   - Colors.white12 → soft divider / row separator
extension DigaudioColors on BuildContext {
  ColorScheme get _cs => Theme.of(this).colorScheme;

  Color get textPrimary => _cs.onSurface;
  Color get textSecondary => _cs.onSurface.withOpacity(0.72);
  Color get textTertiary => _cs.onSurface.withOpacity(0.55);
  Color get textMuted => _cs.onSurface.withOpacity(0.45);
  Color get textDisabled => _cs.onSurface.withOpacity(0.32);
  Color get outlineStrong => _cs.onSurface.withOpacity(0.22);
  Color get dividerSoft => _cs.onSurface.withOpacity(0.10);
}
