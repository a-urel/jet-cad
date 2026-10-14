// The chords the plan's keyboard binds (spec 2a P2, "The keyboard"),
// ported from jet_cad_floor_plan/lib/src/shell_commands.dart:10-61: Cmd
// and Ctrl with each key, on every platform. PlanShortcuts binds them
// (Task 16); the guard keeps Undo and Redo out of a focused field.
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart' show SingleActivator;

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
