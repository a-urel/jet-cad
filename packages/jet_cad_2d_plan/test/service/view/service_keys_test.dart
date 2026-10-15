// Ported from jet_cad_floor_plan/test/host/keyboard_focus_test.dart and
// test/host/host_text_keys_test.dart; assertions unchanged.
//
// Ports, from keyboard_focus_test.dart: M-H41b and T6-g (the group
// "shortcuts: false in the selection mode"), the service half of
// "shortcuts: false: undo() and exportPlan act in each mode", DS4, T6-a's
// selection-mode case and "T6-a the host field focused, the view in a
// focus scope of its own"; from host_text_keys_test.dart: "selection,
// shortcuts: false/true: a host field in the service bar keeps its keys",
// the selection case of "…, shortcuts: false, the canvas focused" and the
// selection case of "(final review F-6, mutant S25)". The design groups
// are 2a's (plan_shortcuts_test.dart, host_text_keys_test.dart).
//
// Host embedding API spec C-7 (2b spec S4 "Options": `shortcuts`,
// `autofocus`): the view's keys in service, through PlanEditor (the one
// widget whose mode switch these tests exercise). The service cases run
// on the embedding fixture under `embeddingCamera()`; DS4 and the text
// keys on the unit editor fixture (Task 8). A host `CallbackShortcuts` or
// `Shortcuts` above the editor counts every key that reaches it.
//
// Adaptations: FloorPlanView -> PlanEditor; FloorPlanMode.selection ->
// PlanMode.service; cameraController -> camera; resetLayout ->
// resetService; designJson -> save; selectedTables -> selectedUnits;
// exportPlan(png96) -> the controller's export of 2a's `png96`
// (page_flows_test.dart's `exportAs`); the host's export dialog takes 2a's
// three arguments; the editor fixture -> unit_editor_fixture.dart.
import 'dart:typed_data';

import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show InteractionLayer, ViewportTransform;
import 'package:jet_cad_2d_plan/src/controller/plan_controller.dart';
import 'package:jet_cad_2d_plan/src/editor/plan_editor.dart';
import 'package:jet_cad_2d_plan/src/export/page_printer.dart';
import 'package:jet_cad_2d_plan/src/service/service_session.dart' show PlanMode;
import 'package:jet_cad_2d_plan/src/service/view/plan_service_bar.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat;

import '../../export/page_flows_test.dart' as pf;
import '../../support/service_fixtures.dart';
import '../../support/service_host.dart' show serviceController;
import '../../support/unit_editor_fixture.dart'
    show editorCamera, kEditorSurface, unitEditorPlanJson;

Finder byKey(String k) => find.byKey(Key(k));

/// A chord the host binds: its name, its key and its modifiers.
typedef Chord = (
  String,
  LogicalKeyboardKey, {
  bool ctrl,
  bool meta,
  bool shift
});

/// Every chord jet-cad binds in the selection mode (its Undo, Redo, Export
/// and Print), in both modifier forms where both are bound.
const List<Chord> kServiceChords = [
  ('ctrl+z', LogicalKeyboardKey.keyZ, ctrl: true, meta: false, shift: false),
  ('cmd+z', LogicalKeyboardKey.keyZ, ctrl: false, meta: true, shift: false),
  (
    'ctrl+shift+z',
    LogicalKeyboardKey.keyZ,
    ctrl: true,
    meta: false,
    shift: true
  ),
  (
    'cmd+shift+z',
    LogicalKeyboardKey.keyZ,
    ctrl: false,
    meta: true,
    shift: true
  ),
  ('ctrl+y', LogicalKeyboardKey.keyY, ctrl: true, meta: false, shift: false),
  ('ctrl+e', LogicalKeyboardKey.keyE, ctrl: true, meta: false, shift: false),
  ('cmd+e', LogicalKeyboardKey.keyE, ctrl: false, meta: true, shift: false),
  ('ctrl+p', LogicalKeyboardKey.keyP, ctrl: true, meta: false, shift: false),
  ('cmd+p', LogicalKeyboardKey.keyP, ctrl: false, meta: true, shift: false),
];

/// The bare keys the host binds, by name.
const Map<String, LogicalKeyboardKey> kBareKeys = {
  'escape': LogicalKeyboardKey.escape,
  'delete': LogicalKeyboardKey.delete,
  'backspace': LogicalKeyboardKey.backspace,
  'w': LogicalKeyboardKey.keyW,
  'f': LogicalKeyboardKey.keyF,
  'f3': LogicalKeyboardKey.f3,
};

/// A printer that records each call and is done at once.
class CountingPrinter implements PagePrinter {
  int calls = 0;

  @override
  Future<void> print(Uint8List pdf, String name, PdfPageFormat format) async {
    calls++;
  }
}

final class KeyHost {
  KeyHost(this.c, bool shortcuts) : shortcuts = ValueNotifier(shortcuts);

  final PlanController c;
  final ValueNotifier<bool> shortcuts;
  final CountingPrinter printer = CountingPrinter();

  /// The keys that reached the host's bindings, by name.
  final Map<String, int> reached = {
    for (final (name, _, ctrl: _, meta: _, shift: _) in kServiceChords) name: 0,
    for (final name in kBareKeys.keys) name: 0,
  };

  int dialogs = 0;
  int exports = 0;
}

/// The editor over [json] in [mode] under a host's bindings, with
/// [shortcuts] (changeable at runtime through [KeyHost.shortcuts]).
Future<KeyHost> mountKeys(WidgetTester tester,
    {required String json,
    required ViewportTransform camera,
    PlanMode mode = PlanMode.design,
    bool shortcuts = false}) async {
  final c = serviceController(json: json);
  c.setMode(mode);
  final h = KeyHost(c, shortcuts);
  addTearDown(h.shortcuts.dispose);
  await tester.binding.setSurfaceSize(kEditorSurface);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  void count(String name) => h.reached[name] = h.reached[name]! + 1;
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: CallbackShortcuts(
    bindings: {
      for (final (name, key, :ctrl, :meta, :shift) in kServiceChords)
        SingleActivator(key, control: ctrl, meta: meta, shift: shift): () =>
            count(name),
      for (final MapEntry(:key, :value) in kBareKeys.entries)
        SingleActivator(value): () => count(key),
    },
    child: ValueListenableBuilder<bool>(
        valueListenable: h.shortcuts,
        builder: (_, keys, __) => PlanEditor(
            controller: c,
            onExport: (_) => h.exports++,
            onExportDialog: (_, __, ___) async {
              h.dialogs++;
              return null;
            },
            printer: h.printer,
            shortcuts: keys)),
  ))));
  await tester.pump();
  await tester.pump();
  c.camera.value = camera;
  await tester.pump();
  return h;
}

/// Presses [chord] (its modifiers down around the key).
Future<void> pressChord(WidgetTester tester, Chord chord) async {
  final (_, key, :ctrl, :meta, :shift) = chord;
  if (ctrl) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (meta) await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(key);
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  if (meta) await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  if (ctrl) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

Chord chordNamed(String name) =>
    kServiceChords.singleWhere((c) => c.$1 == name);

/// editor_tools_test.dart:170-202: the canvas focused, a key, a click.
bool canvasFocused() {
  final context = FocusManager.instance.primaryFocus?.context;
  return context != null &&
      context.findAncestorWidgetOfExactType<InteractionLayer>() != null;
}

Future<bool> press(WidgetTester tester, LogicalKeyboardKey key) async {
  final handled = await tester.sendKeyEvent(key);
  await tester.pump();
  return handled;
}

Future<void> click(WidgetTester tester, Offset at) async {
  final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await g.addPointer(location: at - const Offset(3, 3));
  await g.moveTo(at);
  await tester.pump();
  await g.down(at);
  await tester.pump();
  await g.up();
  await tester.pump();
  await g.removePointer();
  await tester.pump();
}

/// A click on the canvas a little inside its top left: the canvas takes
/// the focus. A floor click (in the selection mode) or an empty one.
Future<void> focusCanvas(WidgetTester tester) async {
  await click(tester,
      tester.getTopLeft(find.byType(InteractionLayer)) + const Offset(6, 6));
  expect(canvasFocused(), isTrue, reason: 'the canvas focused');
}

/// The active plan's encoding: equal means no edit.
String encoded(PlanController c) =>
    DraftDocumentCodec.encodeToString(c.activeDocument);

/// Moves unit [n] of the active plan by (dx, dy), one step.
void move(PlanController c, String n, double dx, double dy) {
  final d = c.activeDocument;
  final node = d.tree[c.unitIndex.withLabel(n).first.instance]! as InstanceNode;
  d.commands.execute(CompoundCommand([
    TransformNodeCommand(
        node.handle, Transform2.translation(dx, dy).multiply(node.transform))
  ], label: 'Move'));
}

/// A host field's tap outside that keeps its focus.
void keepFocus(PointerDownEvent _) {}

/// Whether the primary focus is [node].
bool focused(FocusNode node) => FocusManager.instance.primaryFocus == node;

// ---- host_text_keys_test.dart ----

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

/// The editor under a host's `Shortcuts` + `Actions` + `Focus`, with a
/// host field in the service bar's leading slot.
Future<PosHost> mountPos(WidgetTester tester,
    {PlanMode mode = PlanMode.design, bool shortcuts = false}) async {
  final c = serviceController(json: unitEditorPlanJson());
  c.setMode(mode);
  final h = PosHost(c, shortcuts);
  addTearDown(h.shortcuts.dispose);
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
                          listenable: h.shortcuts,
                          builder: (_, __) => PlanEditor(
                              controller: c,
                              serviceBar: const PlanServiceBar(leading: [
                                SizedBox(
                                    width: 160,
                                    child:
                                        TextField(key: Key('host-bar-field'))),
                              ]),
                              shortcuts: h.shortcuts.value))))))));
  await tester.pump();
  await tester.pump();
  c.camera.value = mode == PlanMode.design ? editorCamera() : embeddingCamera();
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
  group('shortcuts: false in the selection mode', () {
    testWidgets(
        'M-H41b the canvas focused: every service chord (Undo, Redo, Export, '
        'Print, Ctrl and Cmd) reaches the host; a service move stays; nothing '
        'exported or printed. With shortcuts: Ctrl+Z undoes it, the host '
        'hears nothing', (tester) async {
      final h = await mountKeys(tester,
          json: embeddingPlanJson(),
          camera: embeddingCamera(),
          mode: PlanMode.service);
      final c = h.c;
      await focusCanvas(tester);
      move(c, '1', 700, 300);
      await tester.pump();
      expect(c.canUndo.value, isTrue);
      final moved = encoded(c);
      for (final chord in kServiceChords) {
        await pressChord(tester, chord);
        expect(h.reached[chord.$1], 1, reason: chord.$1);
      }
      await pf.letRun(tester, () => false);
      expect(encoded(c), moved, reason: 'the move stays');
      expect(c.canUndo.value, isTrue);
      expect(h.dialogs, 0, reason: 'no export started');
      expect(h.exports, 0);
      expect(h.printer.calls, 0, reason: 'no print started');
      // The control: the same layout with the shortcuts binds them.
      h.shortcuts.value = true;
      await tester.pump();
      await pressChord(tester, chordNamed('ctrl+z'));
      expect(h.reached['ctrl+z'], 1, reason: 'the view took it');
      expect(c.canUndo.value, isFalse, reason: 'undone');
      await pressChord(tester, chordNamed('ctrl+y'));
      expect(h.reached['ctrl+y'], 1);
      expect(encoded(c), moved, reason: 'redone');
      await pressChord(tester, chordNamed('ctrl+e'));
      expect(h.reached['ctrl+e'], 1);
      await tester.pump();
      expect(h.dialogs, 1, reason: "the view's Export asked the hook");
    });

    testWidgets(
        'T6-g 1 selected, Escape: the selection kept, the host\'s Escape '
        'fires; with shortcuts: Escape clears it, the host hears nothing',
        (tester) async {
      final h = await mountKeys(tester,
          json: embeddingPlanJson(),
          camera: embeddingCamera(),
          mode: PlanMode.service);
      final c = h.c;
      await focusCanvas(tester);
      c.select({'1'});
      await tester.pump();
      expect(c.selectedUnits.value, {'1'});
      await press(tester, LogicalKeyboardKey.escape);
      expect(c.selectedUnits.value, {'1'});
      expect(h.reached['escape'], 1);
      h.shortcuts.value = true;
      await tester.pump();
      await press(tester, LogicalKeyboardKey.escape);
      expect(c.selectedUnits.value, isEmpty);
      expect(h.reached['escape'], 1);
    });
  });

  group('the commands stay callable', () {
    testWidgets(
        'shortcuts: false: undo() and exportPlan act in each mode (its '
        'service half)', (tester) async {
      final h = await mountKeys(tester,
          json: embeddingPlanJson(), camera: embeddingCamera());
      final c = h.c;
      for (final mode in [PlanMode.service]) {
        c.setMode(mode);
        await tester.pump();
        await tester.pump();
        final before = encoded(c);
        move(c, '1', 400, 0);
        await tester.pump();
        expect(encoded(c), isNot(before), reason: '$mode');
        c.undo();
        await tester.pump();
        expect(encoded(c), before, reason: '$mode: undo() acts');
        final png = await tester.runAsync(() => pf.exportAs(c, pf.png96));
        expect(png, isNotNull, reason: '$mode: exportPlan acts');
        expect(pf.pngSize(png!.bytes), pf.pagePixels(c, 96));
      }
      expect(h.dialogs, 0);
    });
  });

  group('deleteSelection()', () {
    testWidgets(
        'DS4 false in the selection mode, from the switch on (before the frame '
        'that removes the editor too); the design unchanged', (tester) async {
      final h = await mountKeys(tester,
          json: unitEditorPlanJson(), camera: editorCamera());
      final c = h.c;
      c.select({'1'});
      await tester.pump();
      final before = c.save();
      c.setMode(PlanMode.service);
      c.select({'1'});
      expect(c.selectedUnits.value, {'1'});
      expect(c.deleteSelection(), isFalse, reason: 'switched, not yet built');
      await tester.pump();
      await tester.pump();
      expect(c.deleteSelection(), isFalse, reason: 'the selection mode');
      expect(c.unitIndex.withLabel('1'), isNotEmpty);
      expect(c.save(), before);
      c.setMode(PlanMode.design);
      await tester.pump();
      await tester.pump();
      expect(c.selectedUnits.value, {'1'});
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(c.selectedUnits.value, {'1'});
      // Not ported (a finding for the ledger): today's last two lines,
      // `expect(c.deleteSelection(), isFalse, reason: 'no editor
      // mounted'); expect(c.designJson(), before);`. Their premise is
      // impossible under 2a spec P2: `deleteSelection()` is the
      // controller's own command, refused only with nothing selected,
      // under `delete: false` and for a locked object; it acts with no
      // widget mounted.
    });
  });

  group('autofocus', () {
    /// The view and, after it in the same frame, a host field asking for
    /// the focus: the first request wins, so a view that autofocuses takes
    /// it (the layout the plan pins red, Task 3's T3-i).
    Future<FocusNode> sameFrame(WidgetTester tester, PlanController c,
        {required bool autofocus}) async {
      final field = FocusNode(debugLabel: 'host-field');
      addTearDown(field.dispose);
      await tester.binding.setSurfaceSize(kEditorSurface);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Column(children: [
        Expanded(child: PlanEditor(controller: c, autofocus: autofocus)),
        SizedBox(
            height: 48,
            child: TextField(
                key: const Key('host-field'),
                onTapOutside: keepFocus,
                focusNode: field,
                autofocus: true)),
      ]))));
      await tester.pump();
      await tester.pump();
      return field;
    }

    for (final mode in [PlanMode.service]) {
      testWidgets(
          'T6-a ($mode) the view mounted before a host field that asks for '
          'the focus: with autofocus the view takes it; without, the field '
          'keeps it, and a click on the canvas takes it', (tester) async {
        final c = serviceController();
        c.setMode(mode);
        final control = await sameFrame(tester, c, autofocus: true);
        expect(focused(control), isFalse, reason: 'the control: the view');
        expect(FocusManager.instance.primaryFocus?.context, isNotNull);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        final field = await sameFrame(tester, c, autofocus: false);
        expect(focused(field), isTrue);
        await focusCanvas(tester);
        expect(focused(field), isFalse);
      });
    }

    testWidgets(
        'T6-a the host field focused, the view in a focus scope of its own: '
        'after each setMode, resetLayout and load the field keeps the focus; '
        'with autofocus each new plan shown takes it', (tester) async {
      Future<(PlanController, FocusNode)> scoped(
          {required bool autofocus}) async {
        final c = serviceController();
        final field = FocusNode(debugLabel: 'host-field');
        addTearDown(field.dispose);
        await tester.binding.setSurfaceSize(kEditorSurface);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await tester.pumpWidget(MaterialApp(
            home: Scaffold(
                body: Column(children: [
          SizedBox(
              height: 48,
              child: TextField(
                  key: const Key('host-field'),
                  onTapOutside: keepFocus,
                  focusNode: field)),
          Expanded(
              child: FocusScope(
                  child: PlanEditor(controller: c, autofocus: autofocus))),
        ]))));
        await tester.pump();
        await tester.pump();
        field.requestFocus();
        await tester.pump();
        expect(focused(field), isTrue);
        return (c, field);
      }

      // Each step remounts the view's plan: a mode switch, a new copy, a
      // new plan in each mode.
      final json = embeddingPlanJson();
      final steps = <(String, void Function(PlanController))>[
        ('setMode(selection)', (c) => c.setMode(PlanMode.service)),
        ('resetLayout', (c) => c.resetService()),
        ('load (selection)', (c) => c.load(json)),
        ('setMode(design)', (c) => c.setMode(PlanMode.design)),
        ('load (design)', (c) => c.load(json)),
      ];
      final (control, controlField) = await scoped(autofocus: true);
      for (final (name, step) in steps) {
        controlField.requestFocus();
        await tester.pump();
        step(control);
        await tester.pump();
        await tester.pump();
        expect(focused(controlField), isFalse, reason: 'the control: $name');
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      final (c, field) = await scoped(autofocus: false);
      for (final (name, step) in steps) {
        step(c);
        await tester.pump();
        await tester.pump();
        expect(focused(field), isTrue, reason: name);
      }
      await focusCanvas(tester);
    });
  });

  group('host text keys (host_text_keys_test.dart)', () {
    for (final shortcuts in [false, true]) {
      testWidgets(
          'selection, shortcuts: $shortcuts: a host field in the service bar '
          "keeps its keys from the host's own bindings (a chord reaches it)",
          (tester) async {
        final h = await mountPos(tester,
            mode: PlanMode.service, shortcuts: shortcuts);
        await typeInto(tester, h, 'host-bar-field');
      });
    }

    for (final mode in [PlanMode.service]) {
      testWidgets(
          '${mode.name}, shortcuts: false, the canvas focused: Delete, '
          "Backspace, W, K, 1, Space and Enter each fire the host's intent; "
          'the plan is unchanged', (tester) async {
        final h = await mountPos(tester, mode: mode);
        final c = h.c;
        await focusCanvas(tester);
        c.select({'1'});
        await tester.pump();
        final before = encoded(c);
        for (final MapEntry(:key, :value) in kPosKeys.entries) {
          await press(tester, value.$2);
          expect(h.fired[key], 1, reason: key);
        }
        expect(encoded(c), before);
        expect(c.selectedUnits.value, {'1'});
        expect(canvasFocused(), isTrue);
      });
    }

    for (final mode in [PlanMode.service]) {
      testWidgets(
          '${mode.name} (final review F-6, mutant S25): a held key typed in a '
          "field, its repeats included, never fires the host's intent",
          (tester) async {
        final h = await mountPos(tester, mode: mode);
        const key = 'host-bar-field';
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
  });
}
