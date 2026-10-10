// Host embedding API spec C-7 (Slice 4 plan, Task 6; S-16, S-21): the
// view's `shortcuts` and `autofocus` in both modes, and the controller's
// `deleteSelection()` (C-3 as S-16 was ruled). Both modes on the embedding
// fixture under `embeddingCamera()`; the editor's keys and the delete on
// the editor fixture under `editorCamera()`. A host `CallbackShortcuts`
// above the view counts every key that reaches it.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show InteractionLayer, SelectionKey, ViewportTransform;
import 'package:jet_cad_floor_plan/editor.dart' show WallParams, liveObjectsOf;
import 'package:jet_cad_floor_plan/jet_cad_floor_plan.dart';
import 'package:jet_cad_floor_plan/src/tables/table_index.dart';
import 'package:pdf/pdf.dart' show PdfPageFormat;

import 'editor_fixture.dart';
import 'editor_tools_test.dart' as t;
import 'embedding_fixture.dart';
import 'page_flows_test.dart' as pf;

typedef Caps = FloorPlanEditorCapabilities;

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

  final FloorPlanController c;
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

/// The view over [json] in [mode] under a host's bindings, with [caps] and
/// [shortcuts] (changeable at runtime through [KeyHost.shortcuts]).
Future<KeyHost> mountKeys(WidgetTester tester,
    {required String json,
    required ViewportTransform camera,
    FloorPlanMode mode = FloorPlanMode.design,
    bool shortcuts = false,
    Caps caps = Caps.full}) async {
  final c = FloorPlanController(json: json);
  addTearDown(c.dispose);
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
        builder: (_, keys, __) => FloorPlanView(
            controller: c,
            onExport: (_) => h.exports++,
            onExportDialog: (_, __) async {
              h.dialogs++;
              return null;
            },
            printer: h.printer,
            editorCapabilities: caps,
            shortcuts: keys)),
  ))));
  await tester.pump();
  await tester.pump();
  c.cameraController.value = camera;
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

/// A click on the canvas a little inside its top left: the canvas takes
/// the focus. A floor click (in the selection mode) or an empty one.
Future<void> focusCanvas(WidgetTester tester) async {
  await t.click(tester,
      tester.getTopLeft(find.byType(InteractionLayer)) + const Offset(6, 6));
  expect(t.canvasFocused(), isTrue, reason: 'the canvas focused');
}

/// The active plan's encoding: equal means no edit.
String encoded(FloorPlanController c) =>
    DraftDocumentCodec.encodeToString(c.activeDocument);

/// Moves table [n] of the active plan by (dx, dy), one step.
void move(FloorPlanController c, String n, double dx, double dy) {
  final d = c.activeDocument;
  final node =
      d.tree[TableSurvey.of(d).withNumber(n).first.instance]! as InstanceNode;
  d.commands.execute(CompoundCommand([
    TransformNodeCommand(
        node.handle, Transform2.translation(dx, dy).multiply(node.transform))
  ], label: 'Move'));
}

/// Table `1`'s data in the active plan; null when `1` is gone.
Map<String, String>? dataOf1(FloorPlanController c) =>
    c.tableDetails.where((d) => d.table.number == '1').firstOrNull?.data;

/// A host field's tap outside it: nothing. A Material field's default
/// unfocuses it on a mouse press elsewhere, after the canvas asked for the
/// focus, so the press would leave the focus on the route's scope (a
/// Flutter behaviour, `autofocus` or not; the task's report names it).
void keepFocus(PointerDownEvent _) {}

/// Whether the primary focus is [node].
bool focused(FocusNode node) => FocusManager.instance.primaryFocus == node;

/// An intent a host's own `Shortcuts` maps a key to (the point-of-sale
/// shape: `Shortcuts` + `Actions` + a `Focus` above the view), by name.
class HostIntent extends Intent {
  const HostIntent(this.name);
  final String name;
}

/// Every letter the shell binds under `full`, F3, Escape, Delete,
/// Backspace and the design mode's chords (Task 6 review RP1).
final Map<String, SingleActivator> kIntentKeys = {
  for (final l in 'VLPRBWDNGMSICATF'.split(''))
    l: SingleActivator(LogicalKeyboardKey(
        LogicalKeyboardKey.keyA.keyId + l.codeUnitAt(0) - 'A'.codeUnitAt(0))),
  'f3': const SingleActivator(LogicalKeyboardKey.f3),
  'escape': const SingleActivator(LogicalKeyboardKey.escape),
  'delete': const SingleActivator(LogicalKeyboardKey.delete),
  'backspace': const SingleActivator(LogicalKeyboardKey.backspace),
  'ctrl+z': const SingleActivator(LogicalKeyboardKey.keyZ, control: true),
  'cmd+z': const SingleActivator(LogicalKeyboardKey.keyZ, meta: true),
  'ctrl+shift+z': const SingleActivator(LogicalKeyboardKey.keyZ,
      control: true, shift: true),
  'ctrl+y': const SingleActivator(LogicalKeyboardKey.keyY, control: true),
  'ctrl+e': const SingleActivator(LogicalKeyboardKey.keyE, control: true),
  'cmd+e': const SingleActivator(LogicalKeyboardKey.keyE, meta: true),
  'ctrl+p': const SingleActivator(LogicalKeyboardKey.keyP, control: true),
  'cmd+p': const SingleActivator(LogicalKeyboardKey.keyP, meta: true),
};

/// Presses [a] (its modifiers down around its key).
Future<void> sendActivator(WidgetTester tester, SingleActivator a) async {
  if (a.control) await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
  if (a.meta) await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
  if (a.shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.sendKeyEvent(a.trigger);
  if (a.shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  if (a.meta) await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
  if (a.control) await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
  await tester.pump();
}

/// The view under an intent-based host counting every [kIntentKeys]
/// intent that reaches it; `shortcuts` changeable through the notifier.
Future<(FloorPlanController, Map<String, int>, ValueNotifier<bool>)>
    mountIntentHost(WidgetTester tester,
        {required String json,
        required ViewportTransform camera,
        FloorPlanMode mode = FloorPlanMode.design,
        Caps caps = Caps.full,
        bool shortcuts = false}) async {
  final c = FloorPlanController(json: json);
  addTearDown(c.dispose);
  c.setMode(mode);
  final keys = ValueNotifier(shortcuts);
  addTearDown(keys.dispose);
  final reached = <String, int>{for (final n in kIntentKeys.keys) n: 0};
  await tester.binding.setSurfaceSize(kEditorSurface);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(MaterialApp(
      home: Scaffold(
          body: Shortcuts(
              shortcuts: {
        for (final e in kIntentKeys.entries) e.value: HostIntent(e.key),
      },
              child: Actions(
                  actions: {
                    HostIntent: CallbackAction<HostIntent>(
                        onInvoke: (x) =>
                            reached[x.name] = reached[x.name]! + 1),
                  },
                  child: Focus(
                      child: ValueListenableBuilder<bool>(
                          valueListenable: keys,
                          builder: (_, s, __) => FloorPlanView(
                              controller: c,
                              editorCapabilities: caps,
                              onExport: (_) {},
                              onExportDialog: (_, __) async => null,
                              printer: CountingPrinter(),
                              shortcuts: s))))))));
  await tester.pump();
  await tester.pump();
  c.cameraController.value = camera;
  await tester.pump();
  return (c, reached, keys);
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
          mode: FloorPlanMode.selection);
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
          mode: FloorPlanMode.selection);
      final c = h.c;
      await focusCanvas(tester);
      c.select({'1'});
      await tester.pump();
      expect(c.selectedTables.value, {'1'});
      await t.press(tester, LogicalKeyboardKey.escape);
      expect(c.selectedTables.value, {'1'});
      expect(h.reached['escape'], 1);
      h.shortcuts.value = true;
      await tester.pump();
      await t.press(tester, LogicalKeyboardKey.escape);
      expect(c.selectedTables.value, isEmpty);
      expect(h.reached['escape'], 1);
    });
  });

  group('shortcuts: false in the design mode', () {
    testWidgets(
        'T6-b the canvas focused: W, F3, F, Escape and Ctrl+Z each reach the '
        'host; the tool, OSNAP, Fill, the selection and the history are '
        'kept. With shortcuts: the view takes each', (tester) async {
      final h = await mountKeys(tester,
          json: editorPlanJson(), camera: editorCamera());
      final c = h.c;
      await focusCanvas(tester);
      expect(c.setTableData('1', const {'pos': 'a1'}), isTrue);
      await tester.pump();
      c.select({'1'});
      await tester.pump();
      final osnap = tester.widget<Text>(byKey('osnap-text')).data;
      final fill = tester.widget<CheckboxListTile>(byKey('tool-fill')).value;
      await t.press(tester, LogicalKeyboardKey.keyW);
      await t.press(tester, LogicalKeyboardKey.f3);
      await t.press(tester, LogicalKeyboardKey.keyF);
      await t.press(tester, LogicalKeyboardKey.escape);
      await pressChord(tester, chordNamed('ctrl+z'));
      // The file chords (Task 6 review R-2): the host gives an `onExport`,
      // so the shell would bind Export's chords.
      for (final k in ['ctrl+e', 'cmd+e', 'ctrl+p', 'cmd+p']) {
        await pressChord(tester, chordNamed(k));
      }
      await tester.pump();
      for (final k in [
        'w',
        'f3',
        'f',
        'escape',
        'ctrl+z',
        'ctrl+e',
        'cmd+e',
        'ctrl+p',
        'cmd+p'
      ]) {
        expect(h.reached[k], 1, reason: k);
      }
      expect(h.dialogs, 0, reason: 'no export asked');
      expect(h.exports, 0);
      expect(h.printer.calls, 0, reason: 'nothing printed');
      expect(c.activeTool.value, FloorPlanTool.select);
      expect(tester.widget<Text>(byKey('osnap-text')).data, osnap);
      expect(tester.widget<CheckboxListTile>(byKey('tool-fill')).value, fill);
      expect(c.selectedTables.value, {'1'}, reason: 'the idle Escape bubbled');
      expect(dataOf1(c), const {'pos': 'a1'}, reason: 'nothing undone');
      // The control: the view binds them all.
      h.shortcuts.value = true;
      await tester.pump();
      await t.press(tester, LogicalKeyboardKey.escape);
      expect(c.selectedTables.value, isEmpty, reason: "the tool's Escape");
      await t.press(tester, LogicalKeyboardKey.keyW);
      expect(c.activeTool.value, FloorPlanTool.wall);
      await t.press(tester, LogicalKeyboardKey.escape);
      expect(c.activeTool.value, FloorPlanTool.select, reason: "the shell's");
      await t.press(tester, LogicalKeyboardKey.f3);
      expect(tester.widget<Text>(byKey('osnap-text')).data, isNot(osnap));
      await t.press(tester, LogicalKeyboardKey.keyF);
      expect(tester.widget<CheckboxListTile>(byKey('tool-fill')).value,
          isNot(fill));
      await pressChord(tester, chordNamed('ctrl+z'));
      expect(dataOf1(c), isEmpty, reason: 'undone');
      await pressChord(tester, chordNamed('ctrl+e'));
      await tester.pump();
      expect(h.dialogs, 1, reason: "the shell's Export");
      for (final k in ['w', 'f3', 'f', 'escape', 'ctrl+z', 'ctrl+e']) {
        expect(h.reached[k], 1, reason: '$k: the host heard nothing more');
      }
    });

    testWidgets(
        "a gesture's keys stay: the Wall tool chosen by the host, idle, lets "
        'Escape reach the host and stays; part-way, its Escape cancels the '
        'wall and the host hears nothing', (tester) async {
      final h = await mountKeys(tester,
          json: editorPlanJson(), camera: editorCamera());
      final c = h.c;
      await focusCanvas(tester);
      expect(c.selectTool(FloorPlanTool.wall), isTrue,
          reason: 'the command stays callable');
      await tester.pump();
      await t.press(tester, LogicalKeyboardKey.escape);
      expect(h.reached['escape'], 1, reason: "no shell's Escape");
      expect(c.activeTool.value, FloorPlanTool.wall);
      final at = t.screenOf(tester, c, editorTextAt) + const Offset(0, 80);
      await t.click(tester, at);
      expect(t.statusText(tester), contains('Wall'));
      // Part-way: undo waits (S-4), and the Escape is the wall's.
      expect(c.setTableData('1', const {'pos': 'a1'}), isTrue);
      await tester.pump();
      c.undo();
      expect(dataOf1(c), const {'pos': 'a1'}, reason: 'mid-shape: no undo');
      await t.press(tester, LogicalKeyboardKey.escape);
      expect(h.reached['escape'], 1, reason: "the gesture's own Escape");
      c.undo();
      await tester.pump();
      expect(dataOf1(c), isEmpty, reason: 'the wall cancelled: undo acts');
      await t.press(tester, LogicalKeyboardKey.escape);
      expect(h.reached['escape'], 2, reason: 'idle again: the host');
    });

    testWidgets(
        'T6-c tablesOnly, 1 selected: Delete and Backspace remove nothing '
        "and reach the host's bindings; with shortcuts: Delete removes 1",
        (tester) async {
      final h = await mountKeys(tester,
          json: editorPlanJson(),
          camera: editorCamera(),
          caps: Caps.tablesOnly);
      final c = h.c;
      await focusCanvas(tester);
      c.select({'1'});
      await tester.pump();
      final before = encoded(c);
      await t.press(tester, LogicalKeyboardKey.delete);
      await t.press(tester, LogicalKeyboardKey.backspace);
      expect(encoded(c), before);
      expect(h.reached['delete'], 1);
      expect(h.reached['backspace'], 1);
      h.shortcuts.value = true;
      await tester.pump();
      await t.press(tester, LogicalKeyboardKey.delete);
      expect(TableSurvey.of(c.activeDocument).withNumber('1'), isEmpty);
      expect(h.reached['delete'], 1);
    });
  });

  group('the commands stay callable', () {
    testWidgets('shortcuts: false: undo() and exportPlan act in each mode',
        (tester) async {
      final h = await mountKeys(tester,
          json: pf.finitePlanJson(), camera: embeddingCamera());
      final c = h.c;
      for (final mode in FloorPlanMode.values) {
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
        final png = await tester.runAsync(() => c.exportPlan(pf.png96));
        expect(png, isNotNull, reason: '$mode: exportPlan acts');
        expect(pf.pngSize(png!.bytes), pf.pagePixels(c, 96));
      }
      expect(h.dialogs, 0);
    });
  });

  group('deleteSelection()', () {
    testWidgets(
        'DS1 shortcuts: false: Delete deletes nothing, deleteSelection() '
        'deletes 1 and its data in one step, and undo restores both',
        (tester) async {
      final h = await mountKeys(tester,
          json: editorPlanJson(), camera: editorCamera());
      final c = h.c;
      await focusCanvas(tester);
      expect(c.setTableData('1', const {'pos': 'a1'}), isTrue);
      await tester.pump();
      c.select({'1'});
      await tester.pump();
      final before = encoded(c);
      final details = c.tableDetails;
      final depth = c.activeDocument.commands.undoDepth;
      await t.press(tester, LogicalKeyboardKey.delete);
      expect(encoded(c), before, reason: 'the key deletes nothing');
      expect(h.reached['delete'], 1);
      expect(c.deleteSelection(), isTrue);
      await tester.pump();
      expect(TableSurvey.of(c.activeDocument).withNumber('1'), isEmpty);
      expect(dataOf1(c), isNull);
      expect(c.selectedTables.value, isEmpty);
      expect(c.activeDocument.commands.undoDepth, depth + 1,
          reason: 'one step');
      expect(c.deleteSelection(), isFalse, reason: 'nothing selected');
      c.undo();
      await tester.pump();
      // The engine re-inserts an undone node last among the root's
      // children (Task 3's finding), so the encoding is compared through
      // the key's own undo (DS2); here every table's detail, data included.
      expect(c.tableDetails, details, reason: 'one step, undone whole');
      expect(dataOf1(c), const {'pos': 'a1'});
      expect(c.activeDocument.commands.undoDepth, depth);
      c.redo();
      await tester.pump();
      expect(TableSurvey.of(c.activeDocument).withNumber('1'), isEmpty);
    });

    testWidgets(
        'DS2 the call deletes as the key does: 1, 2 (with data) and a wall '
        'selected, the same document after the call (shortcuts: false) and '
        'after the key (shortcuts)', (tester) async {
      Future<List<String>> deleted(bool viaCall) async {
        final h = await mountKeys(tester,
            json: editorPlanJson(),
            camera: editorCamera(),
            shortcuts: !viaCall);
        final c = h.c;
        await focusCanvas(tester);
        expect(c.setTableData('2', const {'pos': 'b2'}), isTrue);
        await tester.pump();
        final d = c.activeDocument;
        c.select({'1', '2'});
        c.activeSelection.replace([
          ...c.activeSelection.keys,
          SelectionKey.root(liveObjectsOf<WallParams>(d).first),
        ]);
        await tester.pump();
        expect(c.activeSelection.length, 3);
        final depth = d.commands.undoDepth;
        if (viaCall) {
          expect(c.deleteSelection(), isTrue);
        } else {
          await t.press(tester, LogicalKeyboardKey.delete);
        }
        await tester.pump();
        expect(d.commands.undoDepth, depth + 1, reason: 'one step');
        final json = encoded(c);
        c.undo();
        await tester.pump();
        expect(d.commands.undoDepth, depth);
        final undone = encoded(c);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        return [json, undone];
      }

      final byCall = await deleted(true);
      final byKey = await deleted(false);
      expect(byCall[0], byKey[0], reason: 'the delete');
      expect(byCall[1], byKey[1], reason: 'its undo');
    });

    testWidgets('DS3 readOnly: false, changing nothing', (tester) async {
      final h = await mountKeys(tester,
          json: editorPlanJson(), camera: editorCamera(), caps: Caps.readOnly);
      final c = h.c;
      c.select({'1'});
      await tester.pump();
      expect(c.selectedTables.value, {'1'});
      final before = encoded(c);
      expect(c.deleteSelection(), isFalse);
      await tester.pump();
      expect(encoded(c), before);
      expect(c.canUndo.value, isFalse);
    });

    testWidgets(
        'DS4 false in the selection mode, from the switch on (before the frame '
        'that removes the editor too), and with no view mounted; the design '
        'unchanged', (tester) async {
      final h = await mountKeys(tester,
          json: editorPlanJson(), camera: editorCamera());
      final c = h.c;
      c.select({'1'});
      await tester.pump();
      final before = c.designJson();
      c.setMode(FloorPlanMode.selection);
      c.select({'1'});
      expect(c.selectedTables.value, {'1'});
      expect(c.deleteSelection(), isFalse, reason: 'switched, not yet built');
      await tester.pump();
      await tester.pump();
      expect(c.deleteSelection(), isFalse, reason: 'the selection mode');
      expect(TableSurvey.of(c.activeDocument).withNumber('1'), isNotEmpty);
      expect(c.designJson(), before);
      c.setMode(FloorPlanMode.design);
      await tester.pump();
      await tester.pump();
      expect(c.selectedTables.value, {'1'});
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      expect(c.selectedTables.value, {'1'});
      expect(c.deleteSelection(), isFalse, reason: 'no editor mounted');
      expect(c.designJson(), before);
    });

    testWidgets(
        'DS5 false while a wall is part-way, the host\'s selection held; '
        'true once the wall is cancelled', (tester) async {
      final h = await mountKeys(tester,
          json: editorPlanJson(), camera: editorCamera());
      final c = h.c;
      await focusCanvas(tester);
      expect(c.selectTool(FloorPlanTool.wall), isTrue);
      await tester.pump();
      await t.click(
          tester, t.screenOf(tester, c, editorTextAt) + const Offset(0, 80));
      c.select({'1'});
      await tester.pump();
      expect(c.selectedTables.value, {'1'});
      final before = encoded(c);
      expect(c.deleteSelection(), isFalse, reason: 'part-way');
      expect(encoded(c), before);
      await t.press(tester, LogicalKeyboardKey.escape);
      c.select({'1'});
      await tester.pump();
      expect(c.deleteSelection(), isTrue, reason: 'idle: the selection goes');
      expect(TableSurvey.of(c.activeDocument).withNumber('1'), isEmpty);
    });

    testWidgets(
        'DS6 a typed value is settled first: its own step, then the delete; '
        'one undo brings 1 back at the typed rotation', (tester) async {
      final h = await mountKeys(tester,
          json: editorPlanJson(), camera: editorCamera());
      final c = h.c;
      c.select({'1'});
      await tester.pump();
      double degrees() {
        final d = c.activeDocument;
        final n = d.tree[TableSurvey.of(d).withNumber('1').single.instance]!
            as InstanceNode;
        return math.atan2(n.transform.b, n.transform.a) * 180 / math.pi;
      }

      expect(degrees(), closeTo(30, 1e-6));
      await tester.tap(byKey('symbol-rotation'));
      await tester.pump();
      await tester.enterText(byKey('symbol-rotation'), '75');
      await tester.pump();
      expect(degrees(), closeTo(30, 1e-6), reason: 'typed, not committed');
      expect(c.deleteSelection(), isTrue);
      await tester.pump();
      expect(TableSurvey.of(c.activeDocument).withNumber('1'), isEmpty);
      c.undo();
      await tester.pump();
      expect(degrees(), closeTo(75, 1e-6), reason: 'the settled step stays');
      c.undo();
      await tester.pump();
      expect(degrees(), closeTo(30, 1e-6));
    });
    testWidgets(
        "DS7 after a load and a mode round trip, the new plan's editor "
        'deletes (each new editor registers before the old one withdraws)',
        (tester) async {
      final h = await mountKeys(tester,
          json: editorPlanJson(), camera: editorCamera());
      final c = h.c;
      c.load(editorPlanJson());
      await tester.pump();
      await tester.pump();
      c.select({'1'});
      expect(c.deleteSelection(), isTrue, reason: 'after a load');
      await tester.pump();
      expect(TableSurvey.of(c.activeDocument).withNumber('1'), isEmpty);
      c.setMode(FloorPlanMode.selection);
      await tester.pump();
      c.setMode(FloorPlanMode.design);
      await tester.pump();
      await tester.pump();
      c.select({'2'});
      expect(c.deleteSelection(), isTrue, reason: 'after a round trip');
      await tester.pump();
      expect(TableSurvey.of(c.activeDocument).withNumber('2'), isEmpty);
    });
  });

  group('autofocus', () {
    /// The view and, after it in the same frame, a host field asking for
    /// the focus: the first request wins, so a view that autofocuses takes
    /// it (the layout the plan pins red, Task 3's T3-i).
    Future<FocusNode> sameFrame(WidgetTester tester, FloorPlanController c,
        {required bool autofocus}) async {
      final field = FocusNode(debugLabel: 'host-field');
      addTearDown(field.dispose);
      await tester.binding.setSurfaceSize(kEditorSurface);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: Column(children: [
        Expanded(child: FloorPlanView(controller: c, autofocus: autofocus)),
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

    for (final mode in FloorPlanMode.values) {
      testWidgets(
          'T6-a ($mode) the view mounted before a host field that asks for '
          'the focus: with autofocus the view takes it; without, the field '
          'keeps it, and a click on the canvas takes it', (tester) async {
        final c = FloorPlanController(json: embeddingPlanJson());
        addTearDown(c.dispose);
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
      Future<(FloorPlanController, FocusNode)> scoped(
          {required bool autofocus}) async {
        final c = FloorPlanController(json: embeddingPlanJson());
        addTearDown(c.dispose);
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
                  child: FloorPlanView(controller: c, autofocus: autofocus))),
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
      final steps = <(String, void Function(FloorPlanController))>[
        ('setMode(selection)', (c) => c.setMode(FloorPlanMode.selection)),
        ('resetLayout', (c) => c.resetLayout()),
        ('load (selection)', (c) => c.load(json)),
        ('setMode(design)', (c) => c.setMode(FloorPlanMode.design)),
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

  group("the review's killers (Task 6 review R-2, R-3)", () {
    for (final caps in [Caps.full, Caps.tablesOnly]) {
      testWidgets(
          'RP1 design, ${caps == Caps.full ? 'full' : 'tablesOnly'}, '
          'shortcuts: false: every letter, F3, Escape, Delete, Backspace and '
          'every chord reach an intent-based host; nothing in the plan '
          'changes. With shortcuts the plan takes the file chords',
          (tester) async {
        final (c, reached, keys) = await mountIntentHost(tester,
            json: editorPlanJson(), camera: editorCamera(), caps: caps);
        await focusCanvas(tester);
        c.select({'1'});
        await tester.pump();
        final before = encoded(c);
        for (final e in kIntentKeys.entries) {
          await sendActivator(tester, e.value);
          await tester.pump();
          expect(reached[e.key], 1, reason: e.key);
          expect(t.canvasFocused(), isTrue, reason: '${e.key}: focus kept');
        }
        await tester.pump(const Duration(seconds: 1));
        expect(encoded(c), before);
        expect(c.activeTool.value, FloorPlanTool.select);
        expect(c.selectedTables.value, {'1'});
        // The control: with the shortcuts the plan takes the chords.
        keys.value = true;
        await tester.pump();
        await sendActivator(tester, kIntentKeys['ctrl+e']!);
        await sendActivator(tester, kIntentKeys['ctrl+p']!);
        expect(reached['ctrl+e'], 1, reason: 'the shell took Ctrl+E');
        expect(reached['ctrl+p'], 1, reason: 'the shell took Ctrl+P');
      });
    }

    testWidgets(
        "RP12 shortcuts: false, tablesOnly, a table armed: R is the symbol "
        "tool's, M (mirror refused) bubbles; W and Escape reach the host; "
        'the tool stays symbol', (tester) async {
      final (c, reached, _) = await mountIntentHost(tester,
          json: editorPlanJson(),
          camera: editorCamera(),
          caps: Caps.tablesOnly);
      await focusCanvas(tester);
      await t.openSymbols(tester, c);
      await t.arm(tester, 'dining.table.round');
      expect(c.activeTool.value, FloorPlanTool.symbol);
      expect(t.canvasFocused(), isTrue, reason: 'premise: the canvas focused');
      await sendActivator(tester, kIntentKeys['R']!);
      await sendActivator(tester, kIntentKeys['M']!);
      expect(reached['R'], 0, reason: "R is the armed tool's");
      expect(reached['M'], 1, reason: 'tablesOnly refuses mirror: M bubbles');
      await sendActivator(tester, kIntentKeys['W']!);
      await sendActivator(tester, kIntentKeys['escape']!);
      expect(reached['W'], 1);
      expect(reached['escape'], 1);
      expect(c.activeTool.value, FloorPlanTool.symbol);
    });

    testWidgets(
        'R-3 (RP5) shortcuts: true: delete: false refuses the call; the Wall '
        "tool idle with the host's selection: the key deletes nothing, the "
        'call deletes', (tester) async {
      final h = await mountKeys(tester,
          json: editorPlanJson(),
          camera: editorCamera(),
          shortcuts: true,
          caps: Caps.full.copyWith(delete: false));
      final c = h.c;
      await focusCanvas(tester);
      c.select({'1'});
      await tester.pump();
      expect(c.deleteSelection(), isFalse, reason: 'delete: false');
      await tester.pumpWidget(const SizedBox());
      final h2 = await mountKeys(tester,
          json: editorPlanJson(), camera: editorCamera(), shortcuts: true);
      final c2 = h2.c;
      await focusCanvas(tester);
      expect(c2.selectTool(FloorPlanTool.wall), isTrue);
      await tester.pump();
      c2.select({'1'});
      await tester.pump();
      final before = encoded(c2);
      await t.press(tester, LogicalKeyboardKey.delete);
      expect(encoded(c2), before, reason: 'the key: the Wall tool has none');
      expect(c2.deleteSelection(), isTrue, reason: 'the call deletes');
      expect(TableSurvey.of(c2.activeDocument).withNumber('1'), isEmpty);
      expect(c2.activeTool.value, FloorPlanTool.wall);
    });
  });
}
