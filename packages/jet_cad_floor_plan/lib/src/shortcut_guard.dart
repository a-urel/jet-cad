import 'package:flutter/services.dart'
    show HardwareKeyboard, KeyEvent, KeyUpEvent, LogicalKeyboardKey;
import 'package:flutter/widgets.dart';

import 'shell_commands.dart';

/// The shell's single-letter tool shortcuts (spec 05 D5).
const List<LogicalKeyboardKey> kShellLetterKeys = [
  LogicalKeyboardKey.keyV,
  LogicalKeyboardKey.keyL,
  LogicalKeyboardKey.keyP,
  LogicalKeyboardKey.keyR,
  LogicalKeyboardKey.keyB,
  LogicalKeyboardKey.keyW,
  LogicalKeyboardKey.keyD,
  LogicalKeyboardKey.keyN,
  LogicalKeyboardKey.keyG,
  LogicalKeyboardKey.keyM,
  LogicalKeyboardKey.keyS,
  LogicalKeyboardKey.keyI,
  LogicalKeyboardKey.keyC,
  LogicalKeyboardKey.keyA,
  LogicalKeyboardKey.keyT,
  LogicalKeyboardKey.keyF,
];

/// Spec 05 D9 and Ruling 05-8.
///
/// **Why this exists.** A `Shortcuts` or `CallbackShortcuts` above a text
/// field takes the field's keystrokes ("Shortcuts prevent text input fields
/// from receiving their keystrokes as text input", Flutter's
/// `editable_text.dart`). The shell's tool letters, its Undo and Redo
/// chords and its Escape are such shortcuts.
///
/// **What it does.** It maps each of them, **nearer** the field, to
/// `DoNothingAndStopPropagationTextIntent`. `EditableText` answers that
/// intent with `DoNothingAction(consumesKey: false)`, so the key stops here
/// and reaches the field as text.
///
/// **Elsewhere it is inert.** With focus anywhere other than a text field,
/// no action is found, and the key bubbles up to the shell as before.
class ShellShortcutGuard extends StatelessWidget {
  const ShellShortcutGuard({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Shortcuts(
        shortcuts: <ShortcutActivator, Intent>{
          for (final key in kShellLetterKeys)
            SingleActivator(key): const DoNothingAndStopPropagationTextIntent(),
          // Undo (Meta+Z, Ctrl+Z) and, since spec 12a D6 (S-7), Redo
          // (Meta+Shift+Z, Ctrl+Shift+Z, Ctrl+Y): in a focused field they
          // never reach the document. A `SingleActivator` matches its
          // modifiers exactly, so each chord is listed. The file chords are
          // not guarded: Cmd+S in a panel field saves.
          for (final chord in [...kUndoChords, ...kRedoChords])
            chord: const DoNothingAndStopPropagationTextIntent(),
          // The shell binds Escape too (spec 05 D9): in the page panel's
          // field it must not drop a pending shape. The text-entry field's
          // own Escape binding sits nearer, so it still cancels there.
          const SingleActivator(LogicalKeyboardKey.escape):
              const DoNothingAndStopPropagationTextIntent(),
        },
        child: child,
      );
}

/// Slice 4, Task 7 finding 1: the text fields inside the view keep their
/// keys from a host's bindings above it, in both modes.
///
/// **Why this exists.** Flutter binds the text-editing keys (Backspace,
/// Delete, the arrows, select all, copy, paste) once, in `WidgetsApp`, at
/// the top of the tree, and a key typed into a field bubbles through every
/// ancestor first. A host's `Shortcuts` above the view binding Delete,
/// Backspace or a letter (a point of sale's own keys) would take a key
/// typed into a panel's field, the Symbols search, a layer's rename, the
/// TEXT entry, or a host field in a bar or in the inspector.
///
/// **What it does.** It wraps the view in:
/// - Flutter's `DefaultTextEditingShortcuts` again, nearer than any host
///   binding, so an editing key in a field is the field's (Enter and
///   Space among them: they stop there for the platform's text input);
/// - above it, a key that types a character (no Control or Meta held),
///   Delete and Backspace, mapped to
///   `DoNothingAndStopPropagationTextIntent`: in a field (a read-only one
///   too, whose own editing actions refuse Delete and Backspace) the key
///   stops here and goes to the platform's text input, as
///   [ShellShortcutGuard] does for the shell's keys. A chord (Control or
///   Meta held) that no field takes still reaches the host.
///
/// **Elsewhere it is inert.** Only a focused `EditableText` answers those
/// intents: with the focus on the canvas or on a button no action is found
/// and the key bubbles up to the host as before. The planner's own
/// bindings (the shell's and the selection mode's chords, letters and
/// Escape, [ShellShortcutGuard]) sit nearer the fields and act as before.
class PlannerTextKeys extends StatelessWidget {
  const PlannerTextKeys({super.key, required this.child});

  final Widget child;

  static final Map<ShortcutActivator, Intent> _stop = {
    const _TypingActivator(): const DoNothingAndStopPropagationTextIntent(),
    const SingleActivator(LogicalKeyboardKey.delete):
        const DoNothingAndStopPropagationTextIntent(),
    const SingleActivator(LogicalKeyboardKey.backspace):
        const DoNothingAndStopPropagationTextIntent(),
  };

  @override
  Widget build(BuildContext context) => Shortcuts(
        debugLabel: 'PlannerTextKeys',
        shortcuts: _stop,
        child: DefaultTextEditingShortcuts(child: child),
      );
}

/// A key-down or repeat that types a printable character, with neither
/// Control nor Meta held (those are chords, not typing).
class _TypingActivator extends ShortcutActivator {
  const _TypingActivator();

  @override
  Iterable<LogicalKeyboardKey>? get triggers => null;

  @override
  bool accepts(KeyEvent event, HardwareKeyboard state) {
    if (event is KeyUpEvent) return false;
    final character = event.character;
    if (character == null || character.isEmpty) return false;
    final unit = character.codeUnitAt(0);
    if (unit < 0x20 || unit == 0x7f) return false;
    return !state.isControlPressed && !state.isMetaPressed;
  }

  @override
  String debugDescribeKeys() => 'a key that types a character';
}
