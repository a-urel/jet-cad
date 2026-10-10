// Slice 4, Task 7 finding 1: a host's `Shortcuts` above the view binding
// Delete, Backspace, letters and digits never takes a key typed into a
// text field inside the view -- the editor's panel fields, the Symbols
// search, a layer's rename, a host's own field in a bar -- in either mode,
// with `shortcuts` true or false; with the focus outside every field the
// host's intents still fire under `shortcuts: false`. Through
// `FloorPlanView` on the editor fixture under `editorCamera()`.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_floor_plan/jet_cad_floor_plan.dart';

import 'editor_fixture.dart';
import 'editor_tools_test.dart' as t;
import 'embedding_fixture.dart';
import 'keyboard_focus_test.dart' as k;

typedef Caps = FloorPlanEditorCapabilities;

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
  PosHost(this.c, bool shortcuts, Caps caps)
      : shortcuts = ValueNotifier(shortcuts),
        caps = ValueNotifier(caps);

  final FloorPlanController c;
  final ValueNotifier<bool> shortcuts;
  final ValueNotifier<Caps> caps;

  /// The host's intents that fired, by name.
  final Map<String, int> fired = {for (final n in kPosKeys.keys) n: 0};

  /// [kPosChord]'s.
  int chords = 0;
}

/// The view under a host's `Shortcuts` + `Actions` + `Focus`, with a host
/// field in the service bar's leading slot.
Future<PosHost> mountPos(WidgetTester tester,
    {FloorPlanMode mode = FloorPlanMode.design,
    bool shortcuts = false,
    Caps caps = Caps.full}) async {
  final c = FloorPlanController(json: editorPlanJson());
  addTearDown(c.dispose);
  c.setMode(mode);
  final h = PosHost(c, shortcuts, caps);
  addTearDown(h.shortcuts.dispose);
  addTearDown(h.caps.dispose);
  await tester.binding.setSurfaceSize(kEditorSurface);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: Shortcuts(
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
                  child: Focus(
                      child: ListenableBuilder(
                          listenable: Listenable.merge([h.shortcuts, h.caps]),
                          builder: (_, __) => FloorPlanView(
                              controller: c,
                              editorCapabilities: h.caps.value,
                              serviceBar: const FloorPlanServiceBar(leading: [
                                SizedBox(
                                    width: 160,
                                    child:
                                        TextField(key: Key('host-bar-field'))),
                              ]),
                              shortcuts: h.shortcuts.value))))))));
  await tester.pump();
  await tester.pump();
  c.cameraController.value =
      mode == FloorPlanMode.design ? editorCamera() : embeddingCamera();
  await tester.pump();
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
  await t.press(tester, LogicalKeyboardKey.backspace);
  expect(focusedText(), '13', reason: '$key: Backspace edits the field');
  await t.press(tester, LogicalKeyboardKey.delete);
  expect(focusedText(), '1', reason: '$key: Delete edits the field');
  for (final name in ['w', 'k', '1', 'space', 'enter']) {
    final handled = await t.press(tester, kPosKeys[name]!.$2);
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
        'design, shortcuts: $shortcuts: in the table number, the page scale, '
        "the Symbols search and a layer's rename, Backspace and Delete edit "
        'the field and the letters, the digit, Space and Enter reach the '
        "text input; the host's intents never fire (a chord does)",
        (tester) async {
      final h = await mountPos(tester, shortcuts: shortcuts);
      final c = h.c;
      c.select({'1'});
      await tester.pump();
      await typeInto(tester, h, 'table-number');
      // Left without a commit: the number field reverts on focus loss.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await typeInto(tester, h, 'page-scale');
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      // A layer's rename: a double tap on its name.
      final hidden = c.activeDocument.tables.layers.records
          .firstWhere((r) => r.name == kEmbeddingHidden)
          .handle
          .toHex();
      await tester.tap(byKey('layer-name-$hidden'));
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(byKey('layer-name-$hidden'));
      await tester.pump();
      await tester.pump();
      expect(byKey('layer-name-field-$hidden'), findsOneWidget,
          reason: 'premise: the rename open');
      await typeInto(tester, h, 'layer-name-field-$hidden');
      await t.press(tester, LogicalKeyboardKey.escape);
      await t.openSymbols(tester, c);
      await typeInto(tester, h, 'symbol-search');
      // The rename's double tap leaves a gesture timer.
      await tester.pump(const Duration(seconds: 1));
    });
  }

  testWidgets(
      "readOnly: in the table number, read-only, Backspace and Delete edit "
      "nothing and reach no host intent", (tester) async {
    final h = await mountPos(tester, caps: Caps.readOnly);
    final c = h.c;
    c.select({'1'});
    await tester.pump();
    final field = tester.widget<TextField>(byKey('table-number'));
    expect(field.readOnly, isTrue, reason: 'premise');
    await tester.tap(byKey('table-number'));
    await tester.pump();
    expect(inField(), isTrue, reason: 'premise: focused');
    for (final key in [
      LogicalKeyboardKey.backspace,
      LogicalKeyboardKey.delete,
      LogicalKeyboardKey.keyK
    ]) {
      await t.press(tester, key);
    }
    expect(field.controller!.text, '1');
    expect(h.fired, {for (final n in kPosKeys.keys) n: 0});
  });

  for (final shortcuts in [false, true]) {
    testWidgets(
        'selection, shortcuts: $shortcuts: a host field in the service bar '
        "keeps its keys from the host's own bindings (a chord reaches it)",
        (tester) async {
      final h = await mountPos(tester,
          mode: FloorPlanMode.selection, shortcuts: shortcuts);
      await typeInto(tester, h, 'host-bar-field');
    });
  }

  for (final mode in FloorPlanMode.values) {
    testWidgets(
        '${mode.name}, shortcuts: false, the canvas focused: Delete, '
        "Backspace, W, K, 1, Space and Enter each fire the host's intent; "
        'the plan is unchanged', (tester) async {
      final h = await mountPos(tester, mode: mode);
      final c = h.c;
      await k.focusCanvas(tester);
      c.select({'1'});
      await tester.pump();
      final before = k.encoded(c);
      for (final MapEntry(:key, :value) in kPosKeys.entries) {
        await t.press(tester, value.$2);
        expect(h.fired[key], 1, reason: key);
      }
      expect(k.encoded(c), before);
      expect(c.selectedTables.value, {'1'});
      expect(t.canvasFocused(), isTrue);
    });
  }

  for (final mode in FloorPlanMode.values) {
    testWidgets(
        '${mode.name} (final review F-6, mutant S25): a held key typed in a '
        "field, its repeats included, never fires the host's intent",
        (tester) async {
      final h = await mountPos(tester, mode: mode);
      final c = h.c;
      final String key;
      if (mode == FloorPlanMode.design) {
        c.select({'1'});
        await tester.pump();
        key = 'table-number';
      } else {
        key = 'host-bar-field';
      }
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
}
