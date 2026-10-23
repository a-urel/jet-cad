// Ported from apps/floor_planner/test/document_commands_test.dart (audit
// docs/superpowers/specs/2026-10-16-architecture-demo-test-audit.md, section
// "document_commands_test.dart"). The old table fed the toolbar and the
// shortcuts from one command list; now `PlanEditor` owns its buttons and
// chords and calls the host's callbacks. Dispositions:
//   PORT   DC1b DC2 DC4 DC5 DC6 DC9 DC10 DC10b DC11
//   SPLIT  DC1 (order: the app's Open sample button leads the bar), DC7
//          (buttons cannot grey out; the file callbacks do nothing while
//          busy, Undo and Redo are the library's), DC12 and DC12c (the name
//          and the dirty mark are a bounded host widget in
//          `PlanEditorBar.leading`; DC12 keeps 800 px, DC12c's floor moves
//          to 800 px with Export's button and the
//          name at 144 px, re-measured in Task 6)
//   COVERED DC3: packages/jet_cad_2d_plan/test/editor/plan_editor_test.dart
//          ED-3 (:133, "without them none is offered") and ED-U (:445),
//          editor/editor_view_test.dart V1 (:28, "the editor has Export and
//          Print and no file commands"); "no name" is the
//          app's widget. The redo chords go with DC2.
//          DC8: packages/jet_cad_2d_plan/test/panels/layer_panel_test.dart:612
//          ("no shell shortcut fires while typing: letters, Undo, Redo and
//          Escape stop at the field") and panels/page_scale_field_test.dart:36
//          (A9); the canvas half is DC2.
//   DROPPED DC12b: the half-of-the-shared-width rule was the old bar's
//          layout (the name beside the status line in one flexible pair);
//          the new name is a host widget of bounded width, so the rule has
//          no counterpart. Its intent (a long name is cut and the status
//          takes the rest) is DC12 and DC12c.
// Spec 12a D6, D7 (plan 12a Task 6): a disabled command's binding stays and
// does nothing; every command waits while a flow runs or a shape is
// part-way; the file chords are consumed above the Navigator and run
// nothing there; Undo and Redo re-read the history after the settle; the
// top bar shows the name and the dirty mark without overflowing, and the
// tab title follows.
import 'dart:convert';

import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/app_rig.dart';

/// Far from the origin and from the page, where the edits land.
final Vector2 far = Vector2(-43210.5, 31234.75);

/// The seven buttons the old toolbar had, in the old order.
const List<String> kIds = [
  'new',
  'open',
  'open-sample',
  'save',
  'save-as',
  'undo',
  'redo',
];

/// The buttons left to right in the app's bar: Open sample leads, then the
/// library's file buttons, Export and Print (Export has its button since the
/// app gave `onExport`, Task 6), then Undo and Redo.
const List<String> kBarOrder = [
  'open-sample',
  'new',
  'open',
  'save',
  'save-as',
  'export',
  'print',
  'undo',
  'redo',
];

Finder button(String id) => find.byKey(Key('toolbar-$id'));

/// Whether the toolbar button [id] is enabled, as built.
bool on(WidgetTester tester, String id) =>
    tester.widget<IconButton>(button(id)).onPressed != null;

Map<String, bool> states(WidgetTester tester) =>
    {for (final id in kIds) id: on(tester, id)};

Map<String, bool> all(bool value) => {for (final id in kIds) id: value};

Future<void> tapButton(WidgetTester tester, String id) async {
  await tester.tap(button(id));
  await tester.pump();
}

/// A chord, spelled out here rather than read from the library, so a library
/// that lost one is caught.
typedef Chord = ({
  LogicalKeyboardKey key,
  bool meta,
  bool control,
  bool shift,
  String name
});

Chord cmd(LogicalKeyboardKey key, String name, {bool shift = false}) =>
    (key: key, meta: true, control: false, shift: shift, name: name);

Chord ctrl(LogicalKeyboardKey key, String name, {bool shift = false}) =>
    (key: key, meta: false, control: true, shift: shift, name: name);

final Chord cmdZ = cmd(LogicalKeyboardKey.keyZ, 'Cmd+Z');
final Chord ctrlZ = ctrl(LogicalKeyboardKey.keyZ, 'Ctrl+Z');
final Chord cmdShiftZ =
    cmd(LogicalKeyboardKey.keyZ, 'Cmd+Shift+Z', shift: true);
final Chord ctrlShiftZ =
    ctrl(LogicalKeyboardKey.keyZ, 'Ctrl+Shift+Z', shift: true);
final Chord ctrlY = ctrl(LogicalKeyboardKey.keyY, 'Ctrl+Y');
final Chord cmdS = cmd(LogicalKeyboardKey.keyS, 'Cmd+S');
final Chord ctrlS = ctrl(LogicalKeyboardKey.keyS, 'Ctrl+S');
final Chord cmdShiftS =
    cmd(LogicalKeyboardKey.keyS, 'Cmd+Shift+S', shift: true);
final Chord ctrlShiftS =
    ctrl(LogicalKeyboardKey.keyS, 'Ctrl+Shift+S', shift: true);
final Chord cmdO = cmd(LogicalKeyboardKey.keyO, 'Cmd+O');
final Chord ctrlO = ctrl(LogicalKeyboardKey.keyO, 'Ctrl+O');
final Chord cmdN = cmd(LogicalKeyboardKey.keyN, 'Cmd+N');
final Chord ctrlN = ctrl(LogicalKeyboardKey.keyN, 'Ctrl+N');

final List<Chord> fileChords = [
  cmdN,
  ctrlN,
  cmdO,
  ctrlO,
  cmdS,
  ctrlS,
  cmdShiftS,
  ctrlShiftS
];

/// Presses [c]; whether the key-down was handled.
Future<bool> pressChord(WidgetTester tester, Chord c) async {
  final mods = [
    if (c.meta) LogicalKeyboardKey.metaLeft,
    if (c.control) LogicalKeyboardKey.controlLeft,
    if (c.shift) LogicalKeyboardKey.shiftLeft,
  ];
  for (final m in mods) {
    await tester.sendKeyDownEvent(m);
  }
  final handled = await tester.sendKeyEvent(c.key);
  for (final m in mods.reversed) {
    await tester.sendKeyUpEvent(m);
  }
  await tester.pump();
  return handled;
}

/// Counts every call into the dispatcher (execute, undo, redo), through the
/// hook each of them calls first: a disabled command must make none, not
/// rely on the dispatcher refusing (spec 12a D6, S-8).
class DispatcherSpy {
  DispatcherSpy(this.doc) : _guard = doc.commands.onBeforeMutate {
    doc.commands.onBeforeMutate = () {
      calls++;
      _guard?.call();
    };
  }

  final DraftDocument doc;
  final void Function()? _guard;
  int calls = 0;

  void restore() => doc.commands.onBeforeMutate = _guard;
}

/// The history, as a record to compare before and after.
({int depth, bool canRedo, int state}) historyOf(DraftDocument doc) => (
      depth: doc.commands.undoDepth,
      canRedo: doc.commands.canRedo,
      state: doc.commands.stateId,
    );

/// The Room tool over the sample's first room, which is renamed to
/// [roomName]: the status line then reads the kit's "already a room"
/// notice. The mouse rests on the room's seed. Returns the notice.
Future<String> longRoomNotice(
    WidgetTester tester, PlanController c, String roomName) async {
  final room = liveOf<RoomParams>(c, ArchitectureTypes.room).first;
  final params = c.document.components.get<RoomParams>(room)!;
  expect(
      c.execute(SetComponentCommand<RoomParams>(
          room, params.copyWith(name: roomName))),
      isTrue,
      reason: 'premise: renamed');
  final seed =
      c.document.tree.accumulatedTransform(room).transformPoint(params.seed);
  await aimCamera(tester, c, seed);
  await press(tester, LogicalKeyboardKey.keyM);
  final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
  await mouse.addPointer(location: globalOf(tester, c, seed));
  addTearDown(mouse.removePointer);
  await mouse.moveTo(globalOf(tester, c, seed) + const Offset(1, 1));
  await tester.pump();
  return tester.widget<Text>(find.byKey(const Key('status-text'))).data!;
}

/// Two walls drawn far off the origin through the Wall tool, the shape
/// ended: the plan's document, two steps of history.
Future<void> twoWalls(WidgetTester tester, PlanController c) async {
  await aimCamera(tester, c, far);
  await drawWall(
      tester, c, far + Vector2(-1600, -400), far + Vector2(1400, 300));
  await drawWall(
      tester, c, far + Vector2(-900, 1300), far + Vector2(1700, 2100));
  expect(c.document.commands.undoDepth, 2, reason: 'premise');
}

/// Selects the wall [wall] with a canvas click on its middle, then types
/// [text] into its thickness field without Enter: the field keeps the focus
/// and the plan is unchanged (spec 12a D2's pending input).
Future<void> typeThickness(
    WidgetTester tester, PlanController c, Handle wall, String text) async {
  final before = c.document.components.get<WallParams>(wall);
  await clickAt(tester, c, wallMid(c, wall));
  expect(c.activeSelection.keys, [SelectionKey.root(wall)], reason: 'premise');
  final thickness = find.byKey(const Key('property-thickness'));
  await tester.tap(thickness);
  await tester.pump();
  await tester.enterText(thickness, text);
  await tester.pump();
  expect(panelFieldFocused(), isTrue,
      reason: 'premise: the field has the focus');
  expect(c.document.components.get<WallParams>(wall), before,
      reason: 'premise: typed, not committed');
}

void main() {
  testWidgets(
      'DC1-open the toolbar: the app\'s Open sample leads, then New, Open, '
      'Save, Save As, Print and, after a gap, Undo and Redo; the file '
      'buttons are enabled on a fresh plan, Undo and Redo not; an edit '
      'enables Undo, an undo enables Redo (spec 12a D6, D7)', (tester) async {
    // Intent half (order, the 12 px group gap before Undo, Undo and Redo
    // following the history): COVERED, checked: packages/jet_cad_2d_plan/
    // test/editor/plan_editor_test.dart:133 (ED-3: new, open, save, save-as,
    // export, print, undo, redo) and :445 (ED-U).
    // Decided: premise impossible (the order: the app's Open sample button
    // is a `PlanEditorBar.leading` widget, left of the library's buttons;
    // Export and Print are the library's and came after the old test; the
    // step between two buttons is read between Export and Print).
    final rig = await pumpApp(tester);
    final c = rig.controller;
    final doc = c.document;

    for (final id in kBarOrder) {
      expect(button(id), findsOneWidget, reason: id);
    }
    for (var i = 1; i < kBarOrder.length; i++) {
      expect(tester.getTopLeft(button(kBarOrder[i])).dx,
          greaterThan(tester.getTopRight(button(kBarOrder[i - 1])).dx - 0.001),
          reason: '${kBarOrder[i]} after ${kBarOrder[i - 1]}');
    }
    final gap = tester.getTopLeft(button('undo')).dx -
        tester.getTopRight(button('print')).dx;
    final step = tester.getTopLeft(button('print')).dx -
        tester.getTopRight(button('export')).dx;
    expect(gap, greaterThanOrEqualTo(step + 12), reason: 'the group gap');

    expect(states(tester), {...all(true), 'undo': false, 'redo': false},
        reason: 'fresh');

    await aimCamera(tester, c, far);
    await drawWall(tester, c, far, far + Vector2(2500, -700));
    expect(doc.commands.undoDepth, 1, reason: 'premise');
    expect(states(tester), {...all(true), 'redo': false}, reason: 'edited');

    await tapButton(tester, 'undo');
    expect(doc.commands.undoDepth, 0);
    expect(doc.commands.canRedo, isTrue);
    expect(states(tester), {...all(true), 'undo': false}, reason: 'undone');

    await tapButton(tester, 'redo');
    expect(doc.commands.undoDepth, 1);
    expect(states(tester), {...all(true), 'redo': false}, reason: 'redone');
  });

  testWidgets(
      'DC1b each tooltip names its first chord: ⌘ glyphs on macOS, Ctrl+ '
      'elsewhere; Open sample has none (spec 12a D6, S-26)', (tester) async {
    await pumpApp(tester);
    final mac = defaultTargetPlatform == TargetPlatform.macOS;
    final expected = mac
        ? const {
            'new': 'New (⌘N)',
            'open': 'Open… (⌘O)',
            'open-sample': 'Open sample',
            'save': 'Save (⌘S)',
            'save-as': 'Save As… (⌘⇧S)',
            'undo': 'Undo (⌘Z)',
            'redo': 'Redo (⌘⇧Z)',
          }
        : const {
            'new': 'New (Ctrl+N)',
            'open': 'Open… (Ctrl+O)',
            'open-sample': 'Open sample',
            'save': 'Save (Ctrl+S)',
            'save-as': 'Save As… (Ctrl+Shift+S)',
            'undo': 'Undo (Ctrl+Z)',
            'redo': 'Redo (Ctrl+Shift+Z)',
          };
    expect({
      for (final id in kIds) id: tester.widget<IconButton>(button(id)).tooltip
    }, expected);
  },
      variant: const TargetPlatformVariant({
        TargetPlatform.macOS,
        TargetPlatform.windows,
        TargetPlatform.linux
      }));

  testWidgets(
      'DC2 a tap on Undo or Redo, and each of their chords (Ctrl+Y too), '
      'moves exactly one step and back to the same state (spec 12a D6)',
      (tester) async {
    final rig = await pumpApp(tester);
    final c = rig.controller;
    final doc = c.document;
    await twoWalls(tester, c);
    final two = doc.commands.stateId;

    await tapButton(tester, 'undo');
    expect(doc.commands.undoDepth, 1, reason: 'one step, not two');
    final one = doc.commands.stateId;
    await tapButton(tester, 'redo');
    expect(doc.commands.undoDepth, 2);
    expect(doc.commands.stateId, two);

    for (final (undo, redo) in [
      (cmdZ, cmdShiftZ),
      (ctrlZ, ctrlShiftZ),
      (cmdZ, ctrlY),
    ]) {
      expect(await pressChord(tester, undo), isTrue, reason: undo.name);
      expect(doc.commands.undoDepth, 1, reason: undo.name);
      expect(doc.commands.stateId, one, reason: undo.name);
      expect(await pressChord(tester, redo), isTrue, reason: redo.name);
      expect(doc.commands.undoDepth, 2, reason: redo.name);
      expect(doc.commands.stateId, two, reason: redo.name);
    }
    expect(c.activeTool.value, 'plan.select',
        reason: 'no chord reached a tool letter');
  });

  testWidgets(
      'DC4 each file button and each file chord, Cmd and Ctrl, runs its own '
      'flow; the tool stays Select (spec 12a D6)', (tester) async {
    final rig = await pumpApp(tester);
    final c = rig.controller;
    final files = rig.files;
    final session = rig.session;

    // Open: the button, then Cmd+O, then Ctrl+O; each cancelled.
    for (final how in ['button', cmdO, ctrlO]) {
      files.scriptOpenCancel();
      how == 'button'
          ? await tapButton(tester, 'open')
          : await pressChord(tester, how as Chord);
      await tester.pump();
    }
    expect(files.openCalls, 3);
    expect(files.saveLocationCalls, isEmpty);

    // Save As: the button, Cmd+Shift+S, Ctrl+Shift+S; each cancelled.
    for (final how in ['button', cmdShiftS, ctrlShiftS]) {
      files.scriptSaveCancel();
      how == 'button'
          ? await tapButton(tester, 'save-as')
          : await pressChord(tester, how as Chord);
      await tester.pump();
    }
    expect(files.saveLocationCalls, hasLength(3));
    expect(files.writes, isEmpty);

    // Save: untitled, the button asks; titled, Cmd+S and Ctrl+S write in
    // place without asking.
    files.scriptSaveLocation(name: 'plan.jetplan', location: '/p/plan');
    await tapButton(tester, 'save');
    await tester.pump();
    expect(files.saveLocationCalls, hasLength(4));
    expect(files.writes, hasLength(1));
    expect(session.name, 'plan');
    await pressChord(tester, cmdS);
    await tester.pump();
    await pressChord(tester, ctrlS);
    await tester.pump();
    expect(files.saveLocationCalls, hasLength(4), reason: 'titled: no ask');
    expect(
        files.writes.map((w) => w.location), ['/p/plan', '/p/plan', '/p/plan']);

    // Open sample, then New: the button, Cmd+N, Ctrl+N.
    await tapButton(tester, 'open-sample');
    await tester.pump();
    expect(c.document.entities.liveCount, greaterThanOrEqualTo(500));
    expect(session.name, 'Untitled');
    for (final how in ['button', cmdN, ctrlN]) {
      final before = c.document;
      how == 'button'
          ? await tapButton(tester, 'new')
          : await pressChord(tester, how as Chord);
      await tester.pump();
      expect(identical(c.document, before), isFalse, reason: '$how');
      expect(c.document.entities.liveCount, 0, reason: '$how');
    }
    expect(files.openCalls, 3);
    expect(files.saveLocationCalls, hasLength(4));
    expect(files.writes, hasLength(3));
    expect(files.unscriptedCalls, 0);
    expect(session.busy.value, isFalse);
    expect(c.activeTool.value, 'plan.select',
        reason: 'Cmd+N and Cmd+S are not the Window and Separator letters');
  });

  testWidgets(
      'DC5 mid-shape: with the Wall tool part-way every library button is '
      'disabled and a tap changes nothing -- with a wall down too; Escape '
      'enables them and a tap undoes (spec 12a D6, T-2; M-12a-23)',
      (tester) async {
    // Library gap (spec decision 10): the toolbar's mid-shape gating is not
    // pinned by a library test; pinned here through the app.
    // Decided: premise impossible for Open sample: it is the app's own
    // button, and the tool controller (which knows `isMidShape`) is internal
    // to the library, so it cannot grey out; DC5-open-sample below pins what
    // it does instead.
    final rig = await pumpApp(tester);
    final c = rig.controller;
    final files = rig.files;
    final doc = c.document;
    await twoWalls(tester, c);
    await tapButton(tester, 'undo');
    expect(doc.commands.canRedo, isTrue, reason: 'premise: a redo stack');
    expect(states(tester), all(true), reason: 'premise: all enabled');
    final libraryIds = [
      for (final id in kIds)
        if (id != 'open-sample') id
    ];
    Map<String, bool> libraryStates() =>
        {for (final id in libraryIds) id: on(tester, id)};
    Map<String, bool> libraryAll(bool v) =>
        {for (final id in libraryIds) id: v};

    // One click: no wall yet, the redo stack intact -- only the shape
    // disables Redo.
    final a = far + Vector2(-2200, -2600), b = far + Vector2(1900, -2400);
    await press(tester, LogicalKeyboardKey.keyW);
    await clickAt(tester, c, a);
    expect(activeTool(tester).isMidShape, isTrue, reason: 'premise');
    expect(libraryStates(), libraryAll(false));
    final before = historyOf(doc);
    final spy = DispatcherSpy(doc);
    for (final id in libraryIds) {
      await tapButton(tester, id);
    }
    expect(historyOf(doc), before);
    expect(spy.calls, 0);
    expect(identical(c.document, doc), isTrue);
    expect(files.openCalls + files.saveLocationCalls.length, 0);
    expect(files.writes, isEmpty);

    // Two clicks: a wall down, the chain goes on.
    await clickAt(tester, c, b);
    expect(doc.commands.undoDepth, 2, reason: 'premise: a wall down');
    expect(activeTool(tester).isMidShape, isTrue, reason: 'premise');
    expect(libraryStates(), libraryAll(false));
    final down = historyOf(doc);
    spy.calls = 0;
    await tapButton(tester, 'undo');
    await tapButton(tester, 'save');
    expect(historyOf(doc), down);
    expect(spy.calls, 0);
    expect(files.saveLocationCalls, isEmpty);

    // Escape ends the shape: enabled again (Redo waits on its stack, cut by
    // the wall), and a tap undoes.
    await press(tester, LogicalKeyboardKey.escape);
    expect(c.activeTool.value, ArchitectureTools.wall, reason: 'premise');
    expect(activeTool(tester).isMidShape, isFalse);
    expect(libraryStates(), {...libraryAll(true), 'redo': false});
    await tapButton(tester, 'undo');
    expect(doc.commands.undoDepth, 1);
    expect(spy.calls, 1);
    spy.restore();
  });

  testWidgets(
      'DC5-open-sample mid-shape the app\'s Open sample button is not '
      'gated: on a clean plan a tap replaces the plan, the half-drawn wall '
      'is dropped and the tool is Select again', (tester) async {
    // Decided: premise impossible (see DC5): this pins what the app does.
    final rig = await pumpApp(tester);
    final c = rig.controller;
    await aimCamera(tester, c, far);
    await press(tester, LogicalKeyboardKey.keyW);
    await clickAt(tester, c, far + Vector2(-2200, -2600));
    expect(activeTool(tester).isMidShape, isTrue, reason: 'premise');
    expect(c.dirty.value, isFalse, reason: 'premise: clean');
    expect(on(tester, 'open-sample'), isTrue);

    await tapButton(tester, 'open-sample');
    await tester.pump();
    expect(c.document.entities.liveCount, greaterThanOrEqualTo(500));
    expect(c.activeTool.value, 'plan.select');
    expect(activeTool(tester).isMidShape, isFalse);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'DC6 the app tools: Wall, Separator, Dimension and Box are mid-shape '
      'after one click (commands disabled), until Escape; Door, Window, Gap '
      'and Room place with one click and never are (spec 12a D6)',
      (tester) async {
    final rig = await pumpApp(tester);
    final c = rig.controller;
    final doc = c.document;
    final centre = far;
    await aimCamera(tester, c, centre);
    await press(tester, LogicalKeyboardKey.keyW);
    for (final p in [
      centre + Vector2(-2000, -1500),
      centre + Vector2(2000, -1500),
      centre + Vector2(2000, 1500),
      centre + Vector2(-2000, 1500),
      centre + Vector2(-2000, -1500),
    ]) {
      await clickAt(tester, c, p);
    }
    await press(tester, LogicalKeyboardKey.enter);
    await press(tester, LogicalKeyboardKey.escape);
    expect(wallsOf(c), hasLength(4), reason: 'premise: the enclosure');
    expect(on(tester, 'undo'), isTrue, reason: 'premise');

    for (final (letter, name) in [
      (LogicalKeyboardKey.keyW, 'Wall'),
      (LogicalKeyboardKey.keyS, 'Separator'),
      (LogicalKeyboardKey.keyI, 'Dimension'),
      (LogicalKeyboardKey.keyB, 'Box'),
    ]) {
      await press(tester, letter);
      final tool = activeTool(tester);
      expect(tool.isMidShape, isFalse, reason: '$name: fresh');
      expect(on(tester, 'undo'), isTrue, reason: '$name: fresh');
      await clickAt(tester, c, centre + Vector2(-700, 300));
      expect(tool.isMidShape, isTrue, reason: '$name: one click');
      expect(on(tester, 'undo'), isFalse, reason: name);
      expect(on(tester, 'save'), isFalse, reason: name);
      await press(tester, LogicalKeyboardKey.escape);
      expect(tool.isMidShape, isFalse, reason: '$name: Escape');
      expect(on(tester, 'undo'), isTrue, reason: '$name: Escape');
      expect(on(tester, 'save'), isTrue, reason: '$name: Escape');
    }

    for (final (letter, name, at) in [
      (LogicalKeyboardKey.keyD, 'Door', centre + Vector2(-1000, -1500)),
      (LogicalKeyboardKey.keyN, 'Window', centre + Vector2(900, -1500)),
      (LogicalKeyboardKey.keyG, 'Gap', centre + Vector2(2000, 200)),
      (LogicalKeyboardKey.keyM, 'Room', centre + Vector2(-300, 200)),
    ]) {
      await press(tester, letter);
      final tool = activeTool(tester);
      final depth = doc.commands.undoDepth;
      await clickAt(tester, c, at);
      expect(doc.commands.undoDepth, depth + 1, reason: '$name: placed');
      expect(tool.isMidShape, isFalse, reason: name);
      expect(on(tester, 'undo'), isTrue, reason: name);
      expect(on(tester, 'save'), isTrue, reason: name);
      await press(tester, LogicalKeyboardKey.escape);
    }
    expect(liveOf<OpeningParams>(c, ArchitectureTypes.opening), hasLength(3),
        reason: 'premise');
    expect(liveOf<RoomParams>(c, ArchitectureTypes.room), hasLength(1),
        reason: 'premise');
  });

  testWidgets(
      'DC7-open during a held write, no file command and no second Save '
      'reaches the files or the dispatcher, and every file chord is still '
      'consumed; Undo and Redo are the library\'s and act (spec 12a D6, S-8, '
      'S-26, T-6; M-12a-9, M-12a-12)', (tester) async {
    // Decided: premise impossible (spec decision 5): the buttons cannot be
    // disabled, so the file callbacks do nothing while busy; and Undo and
    // Redo during a write are not held (the old test pinned that none of
    // their chords or taps reached the dispatcher). The edit-during-a-write
    // consequences are RN1-open-undo (document_replace_test.dart).
    final rig = await pumpApp(tester);
    final c = rig.controller;
    final files = rig.files;
    final session = rig.session;
    files.scriptOpen(
        name: 'flat.jetplan', bytes: sampleBytes(), location: '/p/flat');
    await rig.host.openFlow();
    await tester.pump();
    final doc = c.document;
    await twoWalls(tester, c);
    await pressChord(tester, cmdZ);
    expect(doc.commands.undoDepth, 1, reason: 'premise');
    expect(doc.commands.canRedo, isTrue, reason: 'premise: a redo stack');
    expect(c.dirty.value, isTrue, reason: 'premise: dirty');
    expect(c.activeTool.value, 'plan.select',
        reason: 'premise: the shape ended');

    files.holdWrites = true;
    expect(await pressChord(tester, cmdS), isTrue);
    expect(files.writes, hasLength(1));
    expect(await pressChord(tester, cmdS), isTrue);
    expect(files.writes, hasLength(1), reason: 'a second Cmd+S: no write');
    expect(session.busy.value, isTrue, reason: 'premise: a flow runs');

    final before = historyOf(doc);
    final spy = DispatcherSpy(doc);
    for (final chord in fileChords) {
      expect(await pressChord(tester, chord), isTrue,
          reason: '${chord.name} is consumed');
      await tester.pump();
    }
    for (final id in ['new', 'open', 'open-sample', 'save', 'save-as']) {
      await tapButton(tester, id);
    }
    expect(historyOf(doc), before);
    expect(spy.calls, 0, reason: 'no call reached the dispatcher');
    expect(files.writes, hasLength(1), reason: 'no second write');
    expect(files.openCalls, 1, reason: 'the Open of the fixture only');
    expect(files.saveLocationCalls, isEmpty);
    expect(identical(c.document, doc), isTrue);

    files.heldWrites.single.complete();
    await tester.pump();
    await tester.pump();
    expect(session.busy.value, isFalse);
    await pressChord(tester, cmdZ);
    expect(doc.commands.undoDepth, 0, reason: 'idle again: Undo acts');
    expect(spy.calls, 1);
    spy.restore();
  });

  testWidgets(
      'DC9 above the dialogs: with the error dialog up (busy), and with the '
      'page panel\'s sheet dropdown open (idle, titled), every file chord is '
      'handled and runs nothing; after each, the chords act again (spec 12a '
      'D6, T-3, U-3, R-10; M-12a-24, M-12a-30)', (tester) async {
    final rig = await pumpApp(tester);
    final c = rig.controller;
    final files = rig.files;
    final session = rig.session;

    // The error dialog of a failed Open, reached by Cmd+O.
    final launch = c.document;
    files.scriptOpen(name: 'list.jetplan', bytes: utf8.encode('[]'));
    await pressChord(tester, cmdO);
    await tester.pump();
    expect(find.byKey(const Key('document-error')), findsOneWidget,
        reason: 'premise: the dialog is up');
    expect(session.busy.value, isTrue, reason: 'premise');
    for (final chord in fileChords) {
      expect(await pressChord(tester, chord), isTrue,
          reason: '${chord.name} handled');
      await tester.pump();
    }
    expect(files.openCalls, 1);
    expect(files.saveLocationCalls, isEmpty);
    expect(files.writes, isEmpty);
    expect(identical(c.document, launch), isTrue);
    await dismissError(tester);
    expect(session.busy.value, isFalse);
    files.scriptOpenCancel();
    await pressChord(tester, cmdO);
    await tester.pump();
    expect(files.openCalls, 2, reason: 'Cmd+O acts again');

    // The sheet dropdown's route over a titled, dirty, idle plan.
    files.scriptOpen(
        name: 'flat.jetplan', bytes: sampleBytes(), location: '/p/flat');
    await rig.host.openFlow();
    await tester.pump();
    final doc = c.document;
    await aimCamera(tester, c, far);
    await drawWall(tester, c, far, far + Vector2(1800, 900));
    expect(c.dirty.value, isTrue, reason: 'premise');
    await tester.tap(find.byKey(const Key('page-preset')));
    await tester.pumpAndSettle();
    expect(find.text('Letter'), findsWidgets, reason: 'premise: menu open');
    expect(session.busy.value, isFalse, reason: 'premise: idle');
    expect(on(tester, 'save'), isTrue, reason: 'premise: Save could act');
    // Save first: a Save that ran here would write in place at once.
    for (final chord in [
      cmdS,
      ctrlS,
      cmdShiftS,
      ctrlShiftS,
      cmdO,
      ctrlO,
      cmdN,
      ctrlN,
    ]) {
      expect(await pressChord(tester, chord), isTrue,
          reason: '${chord.name} handled');
      await tester.pump();
      expect(files.writes, isEmpty, reason: '${chord.name}: no write lands');
      expect(files.openCalls, 3, reason: chord.name);
      expect(files.saveLocationCalls, isEmpty, reason: chord.name);
      expect(identical(c.document, doc), isTrue, reason: chord.name);
    }

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Letter'), findsNothing, reason: 'premise: menu closed');
    await pressChord(tester, cmdS);
    await tester.pump();
    expect(files.writes.map((w) => w.location), ['/p/flat'],
        reason: 'Cmd+S saves again');
    expect(c.dirty.value, isFalse);
  });

  testWidgets(
      'DC10 Redo after a settle: a thickness typed without Enter is committed '
      'by the settle as its own step, which cuts the redo branch, and Redo '
      'then makes no call (spec 12a D2, D6, U-2; M-12a-29)', (tester) async {
    final rig = await pumpApp(tester);
    final c = rig.controller;
    final doc = c.document;
    await twoWalls(tester, c);
    await pressChord(tester, cmdZ);
    expect(doc.commands.canRedo, isTrue, reason: 'premise: a redo stack');
    expect(on(tester, 'redo'), isTrue, reason: 'premise');
    final wall = wallsOf(c).single;
    final params = doc.components.get<WallParams>(wall)!;
    await typeThickness(tester, c, wall, '262.5');
    expect(on(tester, 'redo'), isTrue, reason: 'premise: Redo can be tapped');

    final changes = <DocChange>[];
    final sub = doc.commands.changes.listen(changes.add);
    addTearDown(sub.cancel);
    final spy = DispatcherSpy(doc);
    await tapButton(tester, 'redo');
    await tester.pump();
    expect(
        doc.components.get<WallParams>(wall), params.copyWith(thickness: 262.5),
        reason: 'committed');
    expect(doc.commands.undoDepth, 2, reason: 'the commit is its own step');
    expect(doc.commands.canRedo, isFalse);
    expect(spy.calls, 1, reason: 'the settle\'s commit, and no redo call');
    expect(changes.whereType<CommandRedone>(), isEmpty);
    expect(changes.whereType<CommandApplied>(), hasLength(1));
    expect(on(tester, 'redo'), isFalse);
    expect(panelFieldFocused(), isFalse, reason: 'handed back');
    spy.restore();
  });

  testWidgets(
      'DC10b Undo settles first: a thickness typed without Enter is committed '
      'as its own step, and the tap on Undo removes that step, not the wall '
      '(spec 12a D2, R-9)', (tester) async {
    final rig = await pumpApp(tester);
    final c = rig.controller;
    final doc = c.document;
    await twoWalls(tester, c);
    final wall = wallsOf(c).last;
    final params = doc.components.get<WallParams>(wall)!;
    final two = doc.commands.stateId;
    await typeThickness(tester, c, wall, '90');
    expect(params.thickness, isNot(90), reason: 'premise');

    await tapButton(tester, 'undo');
    expect(doc.components.get<WallParams>(wall), params,
        reason: 'the committed value is undone, the wall stays');
    expect(doc.commands.undoDepth, 2, reason: 'the walls stay');
    expect(doc.commands.stateId, two);
    expect(doc.commands.canRedo, isTrue);
    await tapButton(tester, 'redo');
    expect(doc.components.get<WallParams>(wall), params.copyWith(thickness: 90),
        reason: 'the redo branch is the committed value');
  });

  testWidgets(
      'DC11 the tab title and the top bar follow dirty: • and Edited after an '
      'edit, gone after a save, back after an undo past it (spec 12a D5, D7, '
      'U-4; M-12a-31)', (tester) async {
    final rig = await pumpApp(tester);
    final c = rig.controller;
    final files = rig.files;

    expect(titleOf(tester), 'Untitled — jet-cad');
    expect(shownName(tester), 'Untitled');
    expect(find.byTooltip('Edited'), findsNothing);

    await aimCamera(tester, c, far);
    await drawWall(tester, c, far, far + Vector2(-2100, 1300));
    expect(titleOf(tester), '• Untitled — jet-cad');
    expect(shownName(tester), '• Untitled');
    expect(find.byTooltip('Edited'), findsOneWidget);

    files.scriptSaveLocation(name: 'hall.jetplan', location: '/p/hall');
    await pressChord(tester, cmdS);
    await tester.pump();
    expect(files.writes, hasLength(1), reason: 'premise: saved');
    expect(titleOf(tester), 'hall — jet-cad');
    expect(shownName(tester), 'hall');
    expect(find.byTooltip('Edited'), findsNothing);

    await pressChord(tester, cmdZ);
    expect(titleOf(tester), '• hall — jet-cad');
    expect(shownName(tester), '• hall');
    expect(find.byTooltip('Edited'), findsOneWidget);
  });

  testWidgets(
      'DC12 at 840 px a long file name, dirty, and then a long status '
      'line do not overflow the top bar: each is cut with an ellipsis, and '
      'OSNAP and the zoom stay on screen (spec 12a D7, S-27, T-13)',
      (tester) async {
    // Intent half: COVERED, checked: packages/jet_cad_2d_plan/test/editor/
    // editor_words_test.dart:190 (the OV-$code cases: "no overflow from 704 px
    // down to 656 px", the library bar without host widgets).
    // The width is 840 px: the old 800 px plus the alignment guides' toggle
    // (40 px, plan Task 9b); the name is bounded at 144 px.
    // Decided: this test pins the desktop top bar below 1000 px (an editor
    // narrower than 1000 px has the tablet layout by default now, ruling
    // R6), so it forces the desktop layout.
    final rig = await pumpApp(tester,
        size: const Size(840, 600), layout: PlanEditorLayout.desktop);
    final c = rig.controller;
    const long = 'the ground floor of the house by the lake, third revision, '
        'with the new kitchen and the long hallway to the garden';
    rig.files.scriptOpen(
        name: '$long.jetplan', bytes: sampleBytes(), location: '/p/long');
    await rig.host.openFlow();
    await tester.pump();
    await aimCamera(tester, c, far);
    await drawWall(tester, c, far + Vector2(-500, 0), far + Vector2(500, 0));
    await tester.pump();
    expect(tester.takeException(), isNull);

    final name = find.byKey(const Key('document-name'));
    expect(tester.widget<Text>(name).data, '• $long');
    RenderParagraph paragraph(Finder f) => tester.renderObject<RenderParagraph>(
        find.descendant(of: f, matching: find.byType(RichText)));
    expect(paragraph(name).didExceedMaxLines, isTrue,
        reason: 'cut, not wrapped');
    expect(tester.getRect(name).width, 144, reason: 'bounded at 144');
    final bar = tester.getRect(find.byKey(const Key('chrome-top')));
    expect(
        tester.getRect(name).right,
        lessThanOrEqualTo(
            tester.getRect(find.byKey(const Key('status-text'))).left));
    for (final key in const ['osnap-text', 'zoom-text']) {
      final r = tester.getRect(find.byKey(Key(key)));
      expect(r.right, lessThanOrEqualTo(bar.right), reason: key);
      expect(r.width, greaterThan(0), reason: key);
    }
    expect(tester.getRect(button('redo')).left, greaterThan(bar.left));

    // A long status line too: the Room tool over a room with a long name
    // says "Room — Already a room: <name>".
    const roomName = 'the living room with the bay window, the fireplace and '
        'the door to the terrace';
    final notice = await longRoomNotice(tester, c, roomName);
    expect(tester.takeException(), isNull);
    final status = find.byKey(const Key('status-text'));
    expect(notice, 'Room — Already a room: $roomName',
        reason: 'premise: a long status');
    expect(paragraph(status).didExceedMaxLines, isTrue,
        reason: 'the status is cut, not wrapped');
    for (final key in const ['osnap-text', 'zoom-text']) {
      final r = tester.getRect(find.byKey(Key(key)));
      expect(r.right, lessThanOrEqualTo(bar.right), reason: key);
      expect(r.width, greaterThan(0), reason: key);
    }
  });

  testWidgets(
      'DC12c from 1000 px down to 840 px wide a titled long name and a '
      'long status line do not overflow the top bar, and OSNAP and the zoom '
      'stay on screen (spec 12a D7, S-27)', (tester) async {
    // Decided: premise impossible (the range). The floor is 800 px, measured
    // on this layout: the 144 px name, the 40 px Open sample button, the
    // library's toolbar (Export's button in it, since Task 6) and its gap,
    // OSNAP and the zoom, and the bar's padding, with nothing left for the
    // status; at 799 px the bar overflows by 1 px. (Task 4b measured 776 px
    // with a 160 px name and no Export button.) The old range was 704 px down
    // to 656 px: the host widgets
    // (the name and Open sample) add 200 px to the 576 px the library's bar
    // needs by itself, so 656 px would leave the name 40 px.
    // Decided: forced desktop, as DC12: the test pins the desktop top bar's
    // width range below 1000 px (ruling R6).
    final rig = await pumpApp(tester,
        size: const Size(1000, 600), layout: PlanEditorLayout.desktop);
    final c = rig.controller;
    const long = 'the ground floor of the house by the lake, third revision';
    rig.files.scriptOpen(
        name: '$long.jetplan', bytes: sampleBytes(), location: '/p/long');
    await rig.host.openFlow();
    await tester.pump();
    const roomName = 'the living room with the bay window, the fireplace and '
        'the door to the terrace';
    final notice = await longRoomNotice(tester, c, roomName);
    expect(notice, 'Room — Already a room: $roomName', reason: 'premise');
    expect(tester.takeException(), isNull);
    final name = find.byKey(const Key('document-name'));
    final status = find.byKey(const Key('status-text'));
    // The floor is 840 px since the alignment guides' toggle (40 px, plan
    // Task 9b) joined the bar.
    for (var width = 1000; width >= 840; width--) {
      await tester.binding.setSurfaceSize(Size(width.toDouble(), 600));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '$width px');
      expect(tester.widget<Text>(name).data, '• $long',
          reason: 'premise at $width px: the long name');
      expect(tester.widget<Text>(status).data, notice,
          reason: 'premise at $width px: the long status');
      expect(tester.getRect(name).right,
          lessThanOrEqualTo(tester.getRect(status).left),
          reason: '$width px');
      final bar = tester.getRect(find.byKey(const Key('chrome-top')));
      expect(bar.width, width, reason: 'premise');
      for (final key in const ['osnap-text', 'zoom-text']) {
        final r = tester.getRect(find.byKey(Key(key)));
        expect(r.right, lessThanOrEqualTo(bar.right), reason: '$key, $width');
        expect(r.width, greaterThan(0), reason: '$key, $width');
      }
    }
  });
}
