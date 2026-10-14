// Ported from jet_cad_floor_plan/test/host/host_text_keys_test.dart; assertions unchanged.
//
// Slice 4, Task 7 finding 1: a host's `Shortcuts` above the plan binding
// Delete, Backspace, letters and digits never takes a key typed into a
// host's own text field beside the plan, with `shortcuts` true or false.
// Over the design composition (design_harness.dart). The panel fields'
// cases go with their panels (Tasks 13, 17, 18); the canvas-focused case
// asserted a table selection and is KB-3's (plan_shortcuts_test.dart).
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../support/canvas_fixture.dart';
import '../support/design_harness.dart';

Finder byKey(String key) => find.byKey(Key(key));

/// An intent the host's own `Shortcuts` maps a key to, by name.
class PosIntent extends Intent {
  const PosIntent(this.name);
  final String name;
}

/// The host's keys: a point of sale's Delete and Backspace, a letter the
/// planner binds (W) and one it does not (K), a digit, Space and Ctrl+Z.
final Map<String, (SingleActivator, LogicalKeyboardKey)> kPosKeys = {
  'delete': (
    const SingleActivator(LogicalKeyboardKey.delete),
    LogicalKeyboardKey.delete
  ),
  'backspace': (
    const SingleActivator(LogicalKeyboardKey.backspace),
    LogicalKeyboardKey.backspace
  ),
  'w': (
    const SingleActivator(LogicalKeyboardKey.keyW),
    LogicalKeyboardKey.keyW
  ),
  'k': (
    const SingleActivator(LogicalKeyboardKey.keyK),
    LogicalKeyboardKey.keyK
  ),
  '1': (
    const SingleActivator(LogicalKeyboardKey.digit1),
    LogicalKeyboardKey.digit1
  ),
  'space': (
    const SingleActivator(LogicalKeyboardKey.space),
    LogicalKeyboardKey.space
  ),
  'enter': (
    const SingleActivator(LogicalKeyboardKey.enter),
    LogicalKeyboardKey.enter
  ),
};

/// A host chord no field takes: it reaches the host from a field too.
const SingleActivator kPosChord =
    SingleActivator(LogicalKeyboardKey.keyK, control: true);

final class PosHost {
  PosHost(this.c, bool shortcuts) : shortcuts = ValueNotifier(shortcuts);

  final PlanController c;
  final ValueNotifier<bool> shortcuts;

  /// The host's intents that fired, by name.
  final Map<String, int> fired = {for (final n in kPosKeys.keys) n: 0};

  /// [kPosChord]'s.
  int chords = 0;
}

/// The plan under a host's `Shortcuts` + `Actions` + `Focus`, with a host
/// field beside the status line.
Future<PosHost> mountPos(WidgetTester tester, {bool shortcuts = false}) async {
  final c = drawController().c;
  final h = PosHost(c, shortcuts);
  addTearDown(h.shortcuts.dispose);
  await pumpDesign(tester, c,
      shortcuts: shortcuts,
      hostField: true,
      host: (plan) => Shortcuts(
            shortcuts: {
              for (final MapEntry(:key, :value) in kPosKeys.entries)
                value.$1: PosIntent(key),
              kPosChord: const PosIntent('chord'),
            },
            child: Actions(
              actions: {
                PosIntent: CallbackAction<PosIntent>(
                    onInvoke: (i) => i.name == 'chord'
                        ? h.chords++
                        : h.fired[i.name] = h.fired[i.name]! + 1),
              },
              child: Focus(child: plan),
            ),
          ));
  return h;
}

/// The focused field's text.
String focusedText() {
  final context = FocusManager.instance.primaryFocus!.context!;
  return context
      .findAncestorStateOfType<EditableTextState>()!
      .textEditingValue
      .text;
}

/// Whether a text field has the primary focus.
bool inField() =>
    FocusManager.instance.primaryFocus?.context
        ?.findAncestorWidgetOfExactType<EditableText>() !=
    null;

/// [text] put into the field [key] (focused), the cursor at [cursor].
Future<void> fill(
    WidgetTester tester, String key, String text, int cursor) async {
  await tester.enterText(byKey(key), text);
  await tester.pump();
  tester.testTextInput.updateEditingValue(TextEditingValue(
      text: text, selection: TextSelection.collapsed(offset: cursor)));
  await tester.pump();
}

/// In the focused field [key]: Backspace and Delete edit it; W, K, 1,
/// Space and Enter go to the platform's text input (no handler takes
/// them); none of the host's intents fires and the field keeps the focus.
/// Ctrl+K, a chord, still reaches the host.
Future<void> typeInto(WidgetTester tester, PosHost h, String key) async {
  await fill(tester, key, '123', 2);
  expect(inField(), isTrue, reason: '$key: premise, the field focused');
  await press(tester, LogicalKeyboardKey.backspace);
  expect(focusedText(), '13', reason: '$key: Backspace edits the field');
  await press(tester, LogicalKeyboardKey.delete);
  expect(focusedText(), '1', reason: '$key: Delete edits the field');
  for (final name in ['w', 'k', '1', 'space', 'enter']) {
    final handled = await press(tester, kPosKeys[name]!.$2);
    expect(handled, isFalse, reason: '$key: $name goes to the text input');
  }
  expect(h.fired, {for (final n in kPosKeys.keys) n: 0}, reason: key);
  expect(inField(), isTrue, reason: '$key: the field keeps the focus');
  final chords = h.chords;
  await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
  expect(h.chords, chords + 1, reason: '$key: a chord is no typing');
}

void main() {
  for (final shortcuts in [false, true]) {
    testWidgets(
        'shortcuts: $shortcuts: a host field beside the plan keeps its keys '
        "from the host's own bindings (a chord reaches it)", (tester) async {
      final h = await mountPos(tester, shortcuts: shortcuts);
      await typeInto(tester, h, 'host-field');
    });
  }

  testWidgets(
      '(final review F-6, mutant S25): a held key typed in a field, its '
      "repeats included, never fires the host's intent", (tester) async {
    final h = await mountPos(tester);
    const key = 'host-field';
    await fill(tester, key, '123', 2);
    expect(inField(), isTrue, reason: 'premise: the field focused');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyK);
    await tester.pump();
    expect(h.fired['k'], 0);
    expect(inField(), isTrue, reason: 'the field keeps the focus');
  });
}
