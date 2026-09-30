// Spec 12a D6, D7 (plan 12a Task 6): one command table feeds the toolbar
// and the shortcuts. A disabled command's binding stays and does nothing;
// every command waits while a flow runs or a shape is part-way; a guarded
// text field keeps the redo chords from the document; the file chords are
// consumed above the Navigator and run nothing there; Undo and Redo re-read
// the history after the settle; the top bar shows the name and the dirty
// mark without overflowing, and the tab title follows.
import 'dart:convert';

import 'package:floor_planner/main.dart';
import 'package:floor_planner/panel_focus.dart';
import 'package:floor_planner/parametric/live_objects.dart';
import 'package:floor_planner/parametric/opening.dart';
import 'package:floor_planner/parametric/room.dart';
import 'package:floor_planner/parametric/wall.dart';
import 'package:floor_planner/parametric/wall_tool.dart';
import 'package:floor_planner/startup_plan.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderParagraph;
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'support/document_rig.dart';
import 'support/fake_document_files.dart';

/// Far from the origin and from the page, where the edits land.
final Vector2 far = Vector2(-43210.5, 31234.75);

/// The seven buttons, in the toolbar's order.
const List<String> kIds = [
  'new',
  'open',
  'open-sample',
  'save',
  'save-as',
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

/// A chord, spelled out here rather than read from the table, so a table
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

final List<Chord> redoChords = [cmdShiftZ, ctrlShiftZ, ctrlY];
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

/// Counts every call into the dispatcher (execute, undo, redo), through
/// the hook each of them calls first: a disabled command must make none,
/// not rely on the dispatcher refusing (spec 12a D6, S-8).
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

List<int> sampleBytes() {
  final m = FlutterTextMeasurer();
  addTearDown(m.clear);
  return bytesOf(startupPlan(m));
}

/// Two walls drawn far off the origin through the Wall tool, the shape
/// ended: the current shell's document, two steps of history.
Future<void> twoWalls(WidgetTester tester) async {
  await aimCamera(tester, far);
  await drawWall(tester, far + Vector2(-1600, -400), far + Vector2(1400, 300));
  await drawWall(tester, far + Vector2(-900, 1300), far + Vector2(1700, 2100));
  expect(viewOf(tester).document.commands.undoDepth, 2, reason: 'premise');
}

/// A bare shell over the empty document it builds itself, at 1440 x 900.
Future<void> pumpBare(WidgetTester tester,
    {VoidCallback? debugOnSettle}) async {
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
      MaterialApp(home: PlannerShell(debugOnSettle: debugOnSettle)));
  await tester.pump();
}

void main() {
  testWidgets(
      'DC1 the toolbar: seven buttons in order, a gap before Undo; the file '
      'commands enabled on a fresh document, Undo and Redo not; an edit '
      'enables Undo, an undo enables Redo (spec 12a D6, D7)', (tester) async {
    await pumpApp(tester, FakeDocumentFiles());
    final doc = sessionOf(tester).document;

    for (final id in kIds) {
      expect(button(id), findsOneWidget, reason: id);
    }
    for (var i = 1; i < kIds.length; i++) {
      expect(tester.getTopLeft(button(kIds[i])).dx,
          greaterThan(tester.getTopRight(button(kIds[i - 1])).dx - 0.001),
          reason: '${kIds[i]} after ${kIds[i - 1]}');
    }
    final gap = tester.getTopLeft(button('undo')).dx -
        tester.getTopRight(button('save-as')).dx;
    final step = tester.getTopLeft(button('save-as')).dx -
        tester.getTopRight(button('save')).dx;
    expect(gap, greaterThanOrEqualTo(step + 12), reason: 'the group gap');

    expect(states(tester), {...all(true), 'undo': false, 'redo': false},
        reason: 'fresh');

    await aimCamera(tester, far);
    await drawWall(tester, far, far + Vector2(2500, -700));
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
    await pumpApp(tester, FakeDocumentFiles());
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
    await pumpApp(tester, FakeDocumentFiles());
    final doc = sessionOf(tester).document;
    await twoWalls(tester);
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
    expect(viewOf(tester).tools.active, isA<SelectTool>(),
        reason: 'no chord reached a tool letter');
  });

  testWidgets(
      'DC3 a bare shell shows Undo and Redo only, no name, and keeps undo and '
      'gains redo on its chords (spec 12a D1, D7; plan 12a P-4)',
      (tester) async {
    await pumpBare(tester);
    for (final id in kIds.take(5)) {
      expect(button(id), findsNothing, reason: id);
    }
    expect(button('undo'), findsOneWidget);
    expect(button('redo'), findsOneWidget);
    expect(find.byKey(const Key('document-name')), findsNothing);
    final doc = viewOf(tester).document;
    await twoWalls(tester);
    expect(on(tester, 'undo'), isTrue);
    expect(on(tester, 'redo'), isFalse);

    for (final (undo, redo) in [
      (ctrlZ, ctrlY),
      (cmdZ, cmdShiftZ),
      (ctrlZ, ctrlShiftZ),
    ]) {
      await pressChord(tester, undo);
      expect(doc.commands.undoDepth, 1, reason: undo.name);
      expect(on(tester, 'redo'), isTrue);
      await pressChord(tester, redo);
      expect(doc.commands.undoDepth, 2, reason: redo.name);
      expect(on(tester, 'redo'), isFalse);
    }
    await tapButton(tester, 'undo');
    expect(doc.commands.undoDepth, 1);
    await tapButton(tester, 'redo');
    expect(doc.commands.undoDepth, 2);
  });

  testWidgets(
      'DC4 each file button and each file chord, Cmd and Ctrl, runs its own '
      'flow; the tool stays Select (spec 12a D6)', (tester) async {
    final files = FakeDocumentFiles();
    await pumpApp(tester, files);
    final session = sessionOf(tester);

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
    expect(session.document.entities.liveCount, greaterThanOrEqualTo(500));
    expect(session.name, 'Untitled');
    for (final how in ['button', cmdN, ctrlN]) {
      final before = session.document;
      how == 'button'
          ? await tapButton(tester, 'new')
          : await pressChord(tester, how as Chord);
      await tester.pump();
      expect(identical(session.document, before), isFalse, reason: '$how');
      expect(session.document.entities.liveCount, 0, reason: '$how');
    }
    expect(files.openCalls, 3);
    expect(files.saveLocationCalls, hasLength(4));
    expect(files.writes, hasLength(3));
    expect(files.unscriptedCalls, 0);
    expect(session.busy.value, isFalse);
    expect(viewOf(tester).tools.active, isA<SelectTool>(),
        reason: 'Cmd+N and Cmd+S are not the Window and Separator letters');
  });

  testWidgets(
      'DC5 mid-shape: with the Wall tool part-way every button is disabled '
      'and a tap changes nothing -- with a wall down too; Escape enables '
      'them and a tap undoes (spec 12a D6, T-2; M-12a-23)', (tester) async {
    final files = FakeDocumentFiles();
    await pumpApp(tester, files);
    final session = sessionOf(tester);
    final doc = session.document;
    await twoWalls(tester);
    await tapButton(tester, 'undo');
    expect(doc.commands.canRedo, isTrue, reason: 'premise: a redo stack');
    expect(states(tester), all(true), reason: 'premise: all enabled');

    // One click: no wall yet, the redo stack intact -- only the shape
    // disables Redo.
    final a = far + Vector2(-2200, -2600), b = far + Vector2(1900, -2400);
    await press(tester, LogicalKeyboardKey.keyW);
    await clickAt(tester, a);
    expect(viewOf(tester).tools.active.isMidShape, isTrue, reason: 'premise');
    expect(states(tester), all(false));
    final before = historyOf(doc);
    final spy = DispatcherSpy(doc);
    for (final id in kIds) {
      await tapButton(tester, id);
    }
    expect(historyOf(doc), before);
    expect(spy.calls, 0);
    expect(identical(session.document, doc), isTrue);
    expect(files.openCalls + files.saveLocationCalls.length, 0);
    expect(files.writes, isEmpty);

    // Two clicks: a wall down, the chain goes on.
    await clickAt(tester, b);
    expect(doc.commands.undoDepth, 2, reason: 'premise: a wall down');
    expect(viewOf(tester).tools.active.isMidShape, isTrue, reason: 'premise');
    expect(states(tester), all(false));
    final down = historyOf(doc);
    spy.calls = 0;
    await tapButton(tester, 'undo');
    await tapButton(tester, 'save');
    expect(historyOf(doc), down);
    expect(spy.calls, 0);
    expect(files.saveLocationCalls, isEmpty);

    // Escape ends the shape: enabled again (Redo waits on its stack, cut
    // by the wall), and a tap undoes.
    await press(tester, LogicalKeyboardKey.escape);
    expect(viewOf(tester).tools.active, isA<WallTool>(), reason: 'premise');
    expect(viewOf(tester).tools.active.isMidShape, isFalse);
    expect(states(tester), {...all(true), 'redo': false});
    await tapButton(tester, 'undo');
    expect(doc.commands.undoDepth, 1);
    expect(spy.calls, 1);
    spy.restore();
  });

  testWidgets(
      'DC6 the app tools: Wall, Separator, Dimension and Box are mid-shape '
      'after one click (commands disabled), until Escape; Door, Window, Gap '
      'and Room place with one click and never are (spec 12a D6)',
      (tester) async {
    await pumpApp(tester, FakeDocumentFiles());
    final doc = sessionOf(tester).document;
    final c = far;
    await aimCamera(tester, c);
    await press(tester, LogicalKeyboardKey.keyW);
    for (final p in [
      c + Vector2(-2000, -1500),
      c + Vector2(2000, -1500),
      c + Vector2(2000, 1500),
      c + Vector2(-2000, 1500),
      c + Vector2(-2000, -1500),
    ]) {
      await clickAt(tester, p);
    }
    await press(tester, LogicalKeyboardKey.enter);
    await press(tester, LogicalKeyboardKey.escape);
    expect(wallsOf(doc), hasLength(4), reason: 'premise: the enclosure');
    expect(on(tester, 'undo'), isTrue, reason: 'premise');

    for (final (letter, name) in [
      (LogicalKeyboardKey.keyW, 'Wall'),
      (LogicalKeyboardKey.keyS, 'Separator'),
      (LogicalKeyboardKey.keyI, 'Dimension'),
      (LogicalKeyboardKey.keyB, 'Box'),
    ]) {
      await press(tester, letter);
      final tool = viewOf(tester).tools.active;
      expect(tool.isMidShape, isFalse, reason: '$name: fresh');
      expect(on(tester, 'undo'), isTrue, reason: '$name: fresh');
      await clickAt(tester, c + Vector2(-700, 300));
      expect(tool.isMidShape, isTrue, reason: '$name: one click');
      expect(on(tester, 'undo'), isFalse, reason: name);
      expect(on(tester, 'save'), isFalse, reason: name);
      await press(tester, LogicalKeyboardKey.escape);
      expect(tool.isMidShape, isFalse, reason: '$name: Escape');
      expect(on(tester, 'undo'), isTrue, reason: '$name: Escape');
      expect(on(tester, 'save'), isTrue, reason: '$name: Escape');
    }

    for (final (letter, name, at) in [
      (LogicalKeyboardKey.keyD, 'Door', c + Vector2(-1000, -1500)),
      (LogicalKeyboardKey.keyN, 'Window', c + Vector2(900, -1500)),
      (LogicalKeyboardKey.keyG, 'Gap', c + Vector2(2000, 200)),
      (LogicalKeyboardKey.keyM, 'Room', c + Vector2(-300, 200)),
    ]) {
      await press(tester, letter);
      final tool = viewOf(tester).tools.active;
      final depth = doc.commands.undoDepth;
      await clickAt(tester, at);
      expect(doc.commands.undoDepth, depth + 1, reason: '$name: placed');
      expect(tool.isMidShape, isFalse, reason: name);
      expect(on(tester, 'undo'), isTrue, reason: name);
      expect(on(tester, 'save'), isTrue, reason: name);
      await press(tester, LogicalKeyboardKey.escape);
    }
    expect(liveObjectsOf<OpeningParams>(doc), hasLength(3), reason: 'premise');
    expect(liveObjectsOf<RoomParams>(doc), hasLength(1), reason: 'premise');
  });

  testWidgets(
      'DC7 disabled means no call: during a held write no Undo or Redo chord '
      'or tap, and no second Save or other file command, reaches the '
      'dispatcher or the files; every chord is still consumed (spec 12a D6, '
      'S-8, S-26, T-6; M-12a-9, M-12a-12)', (tester) async {
    final files = FakeDocumentFiles();
    final host = await pumpApp(tester, files);
    final session = sessionOf(tester);
    files.scriptOpen(
        name: 'flat.jetplan', bytes: sampleBytes(), location: '/p/flat');
    await host.openFlow();
    await tester.pump();
    final doc = session.document;
    await twoWalls(tester);
    await pressChord(tester, cmdZ);
    expect(doc.commands.undoDepth, 1, reason: 'premise');
    expect(doc.commands.canRedo, isTrue, reason: 'premise: a redo stack');
    expect(session.dirty.value, isTrue, reason: 'premise: dirty');
    expect(viewOf(tester).tools.active, isA<SelectTool>(),
        reason: 'premise: the shape ended');

    files.holdWrites = true;
    expect(await pressChord(tester, cmdS), isTrue);
    expect(files.writes, hasLength(1));
    expect(await pressChord(tester, cmdS), isTrue);
    expect(files.writes, hasLength(1), reason: 'a second Cmd+S: no write');
    expect(session.busy.value, isTrue, reason: 'premise: a flow runs');
    expect(states(tester), all(false));

    final before = historyOf(doc);
    final spy = DispatcherSpy(doc);
    for (final c in [
      cmdZ,
      ctrlZ,
      cmdShiftZ,
      ctrlShiftZ,
      ctrlY,
      ...fileChords,
    ]) {
      expect(await pressChord(tester, c), isTrue,
          reason: '${c.name} is consumed');
      await tester.pump();
    }
    for (final id in kIds) {
      await tapButton(tester, id);
    }
    expect(historyOf(doc), before);
    expect(spy.calls, 0, reason: 'no call reached the dispatcher');
    expect(files.writes, hasLength(1), reason: 'no second write');
    expect(files.openCalls, 1, reason: 'the Open of the fixture only');
    expect(files.saveLocationCalls, isEmpty);
    expect(identical(session.document, doc), isTrue);

    files.heldWrites.single.complete();
    await tester.pump();
    await tester.pump();
    expect(session.busy.value, isFalse);
    expect(states(tester), all(true));
    await pressChord(tester, cmdZ);
    expect(doc.commands.undoDepth, 0, reason: 'idle again: Undo acts');
    expect(spy.calls, 1);
    spy.restore();
  });

  testWidgets(
      'DC8 a focused Selection panel field keeps each redo chord from the '
      'document; on the canvas each one redoes (spec 12a D6, S-7, T-6; '
      'M-12a-15)', (tester) async {
    await pumpBare(tester);
    final view = viewOf(tester);
    final doc = view.document;
    await twoWalls(tester);
    await pressChord(tester, cmdZ);
    expect(doc.commands.canRedo, isTrue, reason: 'premise: a redo stack');
    final wall = wallsOf(doc).single;

    await clickAt(tester, far + Vector2(-100, -50));
    expect(view.selection.keys, [SelectionKey.root(wall)], reason: 'premise');
    final thickness = find.byKey(const Key('wall-thickness'));
    await tester.tap(thickness);
    await tester.pump();
    final field = FocusManager.instance.primaryFocus;
    expect(field, isA<PanelFieldFocusNode>(), reason: 'premise: focused');
    final text = tester.widget<TextField>(thickness).controller!.text;

    final before = historyOf(doc);
    final spy = DispatcherSpy(doc);
    for (final c in redoChords) {
      await pressChord(tester, c);
      expect(historyOf(doc), before, reason: c.name);
      expect(spy.calls, 0, reason: c.name);
      expect(FocusManager.instance.primaryFocus, same(field), reason: c.name);
      expect(tester.widget<TextField>(thickness).controller!.text, text,
          reason: c.name);
    }

    // Back on the canvas, each of them is the document's.
    await clickAt(tester, far + Vector2(3000, -3000));
    expect(
        FocusManager.instance.primaryFocus, isNot(isA<PanelFieldFocusNode>()),
        reason: 'premise: handed back');
    for (final c in redoChords) {
      await pressChord(tester, c);
      expect(doc.commands.undoDepth, 2, reason: c.name);
      await pressChord(tester, cmdZ);
      expect(historyOf(doc), before, reason: c.name);
    }
    spy.restore();
  });

  testWidgets(
      'DC9 above the dialogs: with the error dialog up (busy), and with the '
      'page panel\'s sheet dropdown open (idle, titled), every file chord is '
      'handled and runs nothing; after each, the chords act again (spec 12a '
      'D6, T-3, U-3, R-10; M-12a-24, M-12a-30)', (tester) async {
    final files = FakeDocumentFiles();
    final host = await pumpApp(tester, files);
    final session = sessionOf(tester);

    // The error dialog of a failed Open, reached by Cmd+O.
    final launch = session.document;
    files.scriptOpen(name: 'list.jetplan', bytes: utf8.encode('[]'));
    await pressChord(tester, cmdO);
    await tester.pump();
    expect(find.byKey(const Key('document-error')), findsOneWidget,
        reason: 'premise: the dialog is up');
    expect(session.busy.value, isTrue, reason: 'premise');
    for (final c in fileChords) {
      expect(await pressChord(tester, c), isTrue, reason: '${c.name} handled');
      await tester.pump();
    }
    expect(files.openCalls, 1);
    expect(files.saveLocationCalls, isEmpty);
    expect(files.writes, isEmpty);
    expect(identical(session.document, launch), isTrue);
    await dismissError(tester);
    expect(session.busy.value, isFalse);
    files.scriptOpenCancel();
    await pressChord(tester, cmdO);
    await tester.pump();
    expect(files.openCalls, 2, reason: 'Cmd+O acts again');

    // The sheet dropdown's route over a titled, dirty, idle document.
    files.scriptOpen(
        name: 'flat.jetplan', bytes: sampleBytes(), location: '/p/flat');
    await host.openFlow();
    await tester.pump();
    final doc = session.document;
    await aimCamera(tester, far);
    await drawWall(tester, far, far + Vector2(1800, 900));
    expect(session.dirty.value, isTrue, reason: 'premise');
    await tester.tap(find.byKey(const Key('page-preset')));
    await tester.pumpAndSettle();
    expect(find.text('Letter'), findsWidgets, reason: 'premise: menu open');
    expect(session.busy.value, isFalse, reason: 'premise: idle');
    expect(on(tester, 'save'), isTrue, reason: 'premise: Save could act');
    // Save first: a Save that ran here would write in place at once.
    for (final c in [
      cmdS,
      ctrlS,
      cmdShiftS,
      ctrlShiftS,
      cmdO,
      ctrlO,
      cmdN,
      ctrlN,
    ]) {
      expect(await pressChord(tester, c), isTrue, reason: '${c.name} handled');
      await tester.pump();
      expect(files.writes, isEmpty, reason: '${c.name}: no write lands');
      expect(files.openCalls, 3, reason: c.name);
      expect(files.saveLocationCalls, isEmpty, reason: c.name);
      expect(identical(session.document, doc), isTrue, reason: c.name);
    }

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Letter'), findsNothing, reason: 'premise: menu closed');
    await pressChord(tester, cmdS);
    await tester.pump();
    expect(files.writes.map((w) => w.location), ['/p/flat'],
        reason: 'Cmd+S saves again');
    expect(session.dirty.value, isFalse);
  });

  testWidgets(
      'DC10 Redo re-reads the history after the settle: a value the settle '
      'commits cuts the branch, and Redo then makes no call (stubbed settle; '
      'spec 12a D6, U-2; M-12a-29)', (tester) async {
    VoidCallback? settle;
    await pumpBare(tester, debugOnSettle: () => settle?.call());
    final doc = viewOf(tester).document;
    await twoWalls(tester);
    await pressChord(tester, cmdZ);
    expect(doc.commands.canRedo, isTrue, reason: 'premise: a redo stack');
    expect(on(tester, 'redo'), isTrue, reason: 'premise');
    final wall = wallsOf(doc).single;
    final params = doc.components.get<WallParams>(wall)!;
    final typed = params.copyWith(thickness: 262.5);
    expect(typed, isNot(params), reason: 'premise');
    // What the settle will commit (spec 12a D2): a typed thickness.
    settle = () =>
        doc.commands.execute(SetComponentCommand<WallParams>(wall, typed));

    final changes = <DocChange>[];
    final sub = doc.commands.changes.listen(changes.add);
    addTearDown(sub.cancel);
    final spy = DispatcherSpy(doc);
    await tapButton(tester, 'redo');
    await tester.pump();
    expect(doc.components.get<WallParams>(wall), typed, reason: 'committed');
    expect(doc.commands.undoDepth, 2, reason: 'the commit is its own step');
    expect(doc.commands.canRedo, isFalse);
    expect(spy.calls, 1, reason: 'the settle\'s commit, and no redo call');
    expect(changes.whereType<CommandRedone>(), isEmpty);
    expect(changes.whereType<CommandApplied>(), hasLength(1));
    expect(on(tester, 'redo'), isFalse);
    spy.restore();
  });

  testWidgets(
      'DC10b Undo settles first: the committed value is its own step, and '
      'the undo removes it (stubbed settle; spec 12a D2, R-9)', (tester) async {
    VoidCallback? settle;
    await pumpBare(tester, debugOnSettle: () => settle?.call());
    final doc = viewOf(tester).document;
    await twoWalls(tester);
    final wall = wallsOf(doc).last;
    final params = doc.components.get<WallParams>(wall)!;
    final two = doc.commands.stateId;
    settle = () => doc.commands.execute(
        SetComponentCommand<WallParams>(wall, params.copyWith(thickness: 90)));

    await pressChord(tester, cmdZ);
    expect(doc.components.get<WallParams>(wall), params,
        reason: 'the committed value is undone');
    expect(doc.commands.undoDepth, 2, reason: 'the walls stay');
    expect(doc.commands.stateId, two);
    expect(doc.commands.canRedo, isTrue);
  });

  testWidgets(
      'DC11 the tab title and the top bar follow dirty: • and Edited after an '
      'edit, gone after a save, back after an undo past it (spec 12a D5, D7, '
      'U-4; M-12a-31)', (tester) async {
    final files = FakeDocumentFiles();
    await pumpApp(tester, files);
    // The app's own Title: WidgetsApp's, the first in the tree.
    String appTitle() => tester
        .widget<Title>(find
            .descendant(
                of: find.byType(WidgetsApp), matching: find.byType(Title))
            .first)
        .title;
    String shown() =>
        tester.widget<Text>(find.byKey(const Key('document-name'))).data!;

    expect(appTitle(), 'Untitled — jet-cad');
    expect(shown(), 'Untitled');
    expect(find.byTooltip('Edited'), findsNothing);

    await aimCamera(tester, far);
    await drawWall(tester, far, far + Vector2(-2100, 1300));
    expect(appTitle(), '• Untitled — jet-cad');
    expect(shown(), '• Untitled');
    expect(find.byTooltip('Edited'), findsOneWidget);

    files.scriptSaveLocation(name: 'hall.jetplan', location: '/p/hall');
    await pressChord(tester, cmdS);
    await tester.pump();
    expect(files.writes, hasLength(1), reason: 'premise: saved');
    expect(appTitle(), 'hall — jet-cad');
    expect(shown(), 'hall');
    expect(find.byTooltip('Edited'), findsNothing);

    await pressChord(tester, cmdZ);
    expect(appTitle(), '• hall — jet-cad');
    expect(shown(), '• hall');
    expect(find.byTooltip('Edited'), findsOneWidget);
  });

  testWidgets(
      'DC12 at 800 x 600 a long file name, dirty, and then a long status line '
      'do not overflow the top bar: each is cut with an ellipsis, and OSNAP '
      'and the zoom stay on screen '
      '(spec 12a D7, S-27, T-13)', (tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final files = FakeDocumentFiles();
    await tester.pumpWidget(FloorPlannerApp(files: files));
    await tester.pump();
    final long = 'the ground floor of the house by the lake, third revision, '
        'with the new kitchen and the long hallway to the garden';
    files.scriptOpen(
        name: '$long.jetplan', bytes: sampleBytes(), location: '/p/long');
    await hostOf(tester).openFlow();
    await tester.pump();
    await aimCamera(tester, far);
    // The canvas is 280 px wide here: a short wall about its centre.
    await drawWall(tester, far + Vector2(-500, 0), far + Vector2(500, 0));
    await tester.pump();
    expect(tester.takeException(), isNull);

    final name = find.byKey(const Key('document-name'));
    expect(tester.widget<Text>(name).data, '• $long');
    final paragraph = tester.renderObject<RenderParagraph>(
        find.descendant(of: name, matching: find.byType(RichText)));
    expect(paragraph.didExceedMaxLines, isTrue, reason: 'cut, not wrapped');
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
    // says "Room — Already a room: <name>" (spec 10 D19).
    final doc = sessionOf(tester).document;
    final room = (liveObjectsOf<RoomParams>(doc).toList()
          ..sort((a, b) => a.value.compareTo(b.value)))
        .first;
    final params = doc.components.get<RoomParams>(room)!;
    const roomName = 'the living room with the bay window, the fireplace and '
        'the door to the terrace';
    doc.commands.execute(
        SetComponentCommand<RoomParams>(room, params.copyWith(name: roomName)));
    final seed =
        doc.tree.accumulatedTransform(room).transformPoint(params.seed);
    await aimCamera(tester, seed);
    await press(tester, LogicalKeyboardKey.keyM);
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: globalOf(tester, seed));
    addTearDown(mouse.removePointer);
    await mouse.moveTo(globalOf(tester, seed) + const Offset(1, 1));
    await tester.pump();
    expect(tester.takeException(), isNull);
    final status = find.byKey(const Key('status-text'));
    expect(tester.widget<Text>(status).data, 'Room — Already a room: $roomName',
        reason: 'premise: a long status');
    expect(
        tester
            .renderObject<RenderParagraph>(
                find.descendant(of: status, matching: find.byType(RichText)))
            .didExceedMaxLines,
        isTrue,
        reason: 'the status is cut, not wrapped');
    for (final key in const ['osnap-text', 'zoom-text']) {
      final r = tester.getRect(find.byKey(Key(key)));
      expect(r.right, lessThanOrEqualTo(bar.right), reason: key);
      expect(r.width, greaterThan(0), reason: key);
    }
  });
}
