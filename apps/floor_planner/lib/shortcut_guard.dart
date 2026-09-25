import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter/widgets.dart';

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
/// `editable_text.dart`). The shell's tool letters, its cmd/ctrl+Z and its
/// Escape are such shortcuts.
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
          const SingleActivator(LogicalKeyboardKey.keyZ, meta: true):
              const DoNothingAndStopPropagationTextIntent(),
          const SingleActivator(LogicalKeyboardKey.keyZ, control: true):
              const DoNothingAndStopPropagationTextIntent(),
          // The shell binds Escape too (spec 05 D9): in the page panel's
          // field it must not drop a pending shape. The text-entry field's
          // own Escape binding sits nearer, so it still cancels there.
          const SingleActivator(LogicalKeyboardKey.escape):
              const DoNothingAndStopPropagationTextIntent(),
        },
        child: child,
      );
}
