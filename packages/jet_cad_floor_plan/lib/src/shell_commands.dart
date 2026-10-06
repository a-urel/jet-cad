// The command table (spec 12a D6): one definition per command, which the
// toolbar (D7) and the shell's shortcuts are both built from, so the two
// cannot disagree.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';

/// Cmd and Ctrl with [key] (and Shift when [shift]): both modifiers are
/// bound on every platform (spec 12a D6, S-26).
List<SingleActivator> _chord(LogicalKeyboardKey key, {bool shift = false}) => [
      SingleActivator(key, meta: true, shift: shift),
      SingleActivator(key, control: true, shift: shift),
    ];

/// New: Meta+N, Ctrl+N.
final List<SingleActivator> kNewChords = _chord(LogicalKeyboardKey.keyN);

/// Open: Meta+O, Ctrl+O.
final List<SingleActivator> kOpenChords = _chord(LogicalKeyboardKey.keyO);

/// Save: Meta+S, Ctrl+S.
final List<SingleActivator> kSaveChords = _chord(LogicalKeyboardKey.keyS);

/// Save As: Meta+Shift+S, Ctrl+Shift+S.
final List<SingleActivator> kSaveAsChords =
    _chord(LogicalKeyboardKey.keyS, shift: true);

/// Export: Meta+E, Ctrl+E (spec 13 D8).
final List<SingleActivator> kExportChords = _chord(LogicalKeyboardKey.keyE);

/// Print: Meta+P, Ctrl+P (spec 13 D9). Bare P is the Polyline tool's
/// letter; the chord is not.
final List<SingleActivator> kPrintChords = _chord(LogicalKeyboardKey.keyP);

/// Undo: Meta+Z, Ctrl+Z.
final List<SingleActivator> kUndoChords = _chord(LogicalKeyboardKey.keyZ);

/// Redo: Meta+Shift+Z, Ctrl+Shift+Z, and Ctrl+Y.
final List<SingleActivator> kRedoChords = [
  ..._chord(LogicalKeyboardKey.keyZ, shift: true),
  const SingleActivator(LogicalKeyboardKey.keyY, control: true),
];

/// Every file command's chord: what the app binds a second time above the
/// Navigator, consume-only (spec 12a D6, U-3, R-10). Export's and Print's
/// join them (spec 13 D8, R-8): with a dialog up, Ctrl+P must not reach the
/// browser's own print.
final List<SingleActivator> kFileChords = [
  ...kNewChords,
  ...kOpenChords,
  ...kSaveChords,
  ...kSaveAsChords,
  ...kExportChords,
  ...kPrintChords,
];

/// The file commands that need the document's page (spec 13 D8, D9): the
/// shell enables them only while it has one, besides idle.
const Set<String> kPageCommandIds = {'export', 'print'};

/// One command of the shell (spec 12a D6): New, Open, Open sample, Save,
/// Save As, Export, Print (spec 13 D8, D9), Undo, Redo.
///
/// A command is **invoked** only through [invoke], by its toolbar button
/// and by its shortcuts alike: a disabled command's binding stays present
/// (so the key is consumed, S-26) and does nothing -- it never calls the
/// flow or the dispatcher and lets it refuse (S-8).
@immutable
final class ShellCommand {
  const ShellCommand({
    required this.id,
    required this.label,
    required this.icon,
    this.shortcuts = const <SingleActivator>[],
    required this.enabled,
    required this.run,
  });

  /// The toolbar button's key is `toolbar-<id>`.
  final String id;
  final String label;
  final IconData icon;

  /// Every chord bound to the command; the first one names it in the
  /// tooltip.
  final List<SingleActivator> shortcuts;

  /// Whether the command can act now. Read at every invocation.
  final ValueListenable<bool> enabled;

  /// What the command does. Called only by [invoke], when [enabled].
  final Future<void> Function() run;

  /// The label and the first chord's glyph for [defaultTargetPlatform]:
  /// `⌘S` on macOS (which web on a Mac reports too), `Ctrl+S` elsewhere
  /// (spec 12a D6, S-26).
  String get tooltip => tooltipFor(defaultTargetPlatform);

  /// [tooltip] as it reads on [platform]; off macOS the modifiers are
  /// named [control] and [shift] (spec 14d L4: `Strg` in German).
  String tooltipFor(TargetPlatform platform,
      {String control = 'Ctrl', String shift = 'Shift'}) {
    if (shortcuts.isEmpty) return label;
    final chord = shortcuts.first;
    final key = chord.trigger.keyLabel;
    final glyph = platform == TargetPlatform.macOS
        ? '⌘${chord.shift ? '⇧' : ''}$key'
        : '$control+${chord.shift ? '$shift+' : ''}$key';
    return '$label ($glyph)';
  }

  /// Runs the command when it is enabled, and otherwise does nothing.
  void invoke() {
    if (!enabled.value) return;
    unawaited(run());
  }

  /// The same command, enabled only while [enabled] is.
  ShellCommand withEnabled(ValueListenable<bool> enabled) => ShellCommand(
      id: id,
      label: label,
      icon: icon,
      shortcuts: shortcuts,
      enabled: enabled,
      run: run);
}

/// A flag computed from other state: [value] is [compute]'s answer at the
/// moment it is read, and listeners hear when that answer changes.
///
/// It re-computes when one of [sources] notifies, or when [update] is
/// called (for a source that is not a [Listenable], such as the
/// dispatcher's change stream), and notifies only when the answer differs
/// from the last one it announced: a tool that notifies on every hover
/// does not rebuild the toolbar.
class DerivedFlag extends ChangeNotifier implements ValueListenable<bool> {
  DerivedFlag(List<Listenable> sources, this._compute)
      : _sources = List.unmodifiable(sources) {
    _last = _compute();
    for (final s in _sources) {
      s.addListener(update);
    }
  }

  final List<Listenable> _sources;
  final bool Function() _compute;
  late bool _last;

  @override
  bool get value => _compute();

  /// Re-computes, and notifies when the answer changed.
  void update() {
    final now = _compute();
    if (now == _last) return;
    _last = now;
    notifyListeners();
  }

  @override
  void dispose() {
    for (final s in _sources) {
      s.removeListener(update);
    }
    super.dispose();
  }
}
