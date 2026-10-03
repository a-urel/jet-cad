import 'package:flutter/services.dart' show LogicalKeyboardKey;
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
