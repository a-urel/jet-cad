// Spec 14c S3, S4, S8, R-1, R-5, R-6: the selection mode's tool -- taps,
// modifier taps, long presses, drags that move the selection in one step,
// pans on the floor, locked tables tapped only, cancel and Escape. Under
// fake time (testWidgets), so the long press is driven by pumps. Tables are
// off the origin, turned and mirrored, on a service copy (runtime).
import 'dart:convert';

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter/gestures.dart'
    show PointerDeviceKind, kLongPressTimeout, kPrimaryButton;
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_floor_plan/src/parametric/catalog.dart';
import 'package:jet_cad_floor_plan/src/service/table_picker.dart';
import 'package:jet_cad_floor_plan/src/service/table_select_tool.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_placer.dart';
import 'package:jet_cad_floor_plan/src/tables/table_index.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../tables/table_fixture.dart';

/// World (0, 0) at screen (700, 450), 0.1 px per mm, y up.
CameraController newCamera() => CameraController(ViewportTransform(
    worldToScreenMatrix: Transform2(0.1, 0, 0, -0.1, 700, 450)));

final class Rig {
  Rig._(this.doc, this.camera, this.index, this.selection, this.tool, this.ctx);

  /// Tables 1 (at -2000, 1000, turned, mirrored), 2 (at 2500, 1000) and 3
  /// (at 0, -2500, on a locked layer), decoded as a service copy.
  factory Rig() {
    final design = plan();
    design.commands.execute(placeSymbol(design, entryOf(tableSymbol()),
        at: Vector2(-2000, 1000), quarterTurns: 1, mirrored: true));
    design.commands.execute(placeSymbol(design, entryOf(trapezoidTable),
        at: Vector2(2500, 1000), mirrored: true));
    final zero = design.tables.layers[ReservedHandles.layerZero]!;
    final locked = design.handleSeed.next();
    design.commands.execute(AddLayerCommand(LayerRecord(
        handle: locked,
        name: 'Locked',
        color: const IndexedColor(1),
        linetype: zero.linetype,
        lineweight: zero.lineweight,
        transparency: zero.transparency,
        visible: true,
        locked: false)));
    design.commands.execute(
        placeSymbol(design, entryOf(tableSymbol()), at: Vector2(0, -2500)));
    final third = TableSurvey.of(design).withNumber('3').single.instance;
    design.commands.execute(SetInstanceLayerCommand(third, locked));
    design.commands.execute(
        SetLayerCommand(design.tables.layers[locked]!.copyWith(locked: true)));
    final doc = DraftDocumentCodec.decodeString(
        DraftDocumentCodec.encodeToString(design),
        permissions: DraftPermissions.runtime,
        registerComponents: registerAppComponents,
        diagnostics: <Diagnostic>[]);
    final cam = newCamera();
    final index = SpatialIndex(doc);
    final selection = SelectionController(doc);
    final taps = <String>[];
    var layouts = 0;
    final tool = TableSelectTool(
        picker: TablePicker(doc),
        groups: ValueNotifier(const {}),
        callbacks: () => (
              onTableTap: taps.add,
              onLayoutChanged: () => layouts++,
              onGroupTap: null,
              onMergeRequested: null,
              onSplitRequested: null,
            ));
    final rig = Rig._(
        doc,
        cam,
        index,
        selection,
        tool,
        ToolContext(
            document: doc, index: index, camera: cam, selection: selection));
    rig._taps = taps;
    rig._layouts = () => layouts;
    return rig;
  }

  final DraftDocument doc;
  final CameraController camera;
  final SpatialIndex index;
  final SelectionController selection;
  final TableSelectTool tool;
  final ToolContext ctx;
  late final List<String> _taps;
  late final int Function() _layouts;

  List<String> get taps => _taps;
  int get layouts => _layouts();

  void dispose() {
    tool.dispose();
    selection.dispose();
    index.dispose();
    camera.dispose();
  }

  InstanceNode node(String n) =>
      doc.tree[TableSurvey.of(doc).withNumber(n).single.instance]!
          as InstanceNode;

  SelectionKey key(String n) => SelectionKey.root(node(n).handle);

  /// The screen point of local ([x], [y]) of table [n].
  Offset at(String n, double x, double y) {
    final w = node(n).transform.transformPoint(Vector2(x, y));
    final s = camera.value.worldToScreen(w);
    return Offset(s.x, s.y);
  }

  ToolPointerEvent ev(Offset screen,
          {int buttons = kPrimaryButton,
          bool shift = false,
          bool control = false,
          bool meta = false,
          bool touch = false}) =>
      ToolPointerEvent(
        screen: screen,
        world: camera.value.screenToWorld(Vector2(screen.dx, screen.dy)),
        pointer: 1,
        buttons: buttons,
        shift: shift,
        control: control,
        meta: meta,
        alt: false,
        pickRadiusWorld: 6 / camera.value.scale,
        kind: touch ? PointerDeviceKind.touch : PointerDeviceKind.mouse,
        reachRadiusWorld: touch ? 24 / camera.value.scale : null,
      );

  void down(Offset s,
          {bool shift = false, bool control = false, bool meta = false}) =>
      tool.onPointerDown(
          ev(s, shift: shift, control: control, meta: meta), ctx);
  void move(Offset s) => tool.onPointerMove(ev(s), ctx);
  void up(Offset s) => tool.onPointerUp(ev(s, buttons: 0), ctx);

  void tap(Offset s,
      {bool shift = false, bool control = false, bool meta = false}) {
    down(s, shift: shift, control: control, meta: meta);
    up(s);
  }
}

List<double> parts(Transform2 t) => [t.a, t.b, t.c, t.d, t.e, t.f];

Rig rig(WidgetTester tester) {
  final r = Rig();
  addTearDown(r.dispose);
  return r;
}

void main() {
  testWidgets(
      'ST1 a tap selects a table alone and reports its number; another tap '
      'replaces; a tap on the floor clears (M-14c2-9)', (tester) async {
    final r = rig(tester);
    r.tap(r.at('1', 900, 700));
    expect(r.selection.keys, {r.key('1')});
    r.tap(r.at('2', 900, 400));
    expect(r.selection.keys, {r.key('2')});
    expect(r.taps, ['1', '2']);
    r.tap(const Offset(40, 40));
    expect(r.selection.isEmpty, isTrue);
    expect(r.taps, ['1', '2'], reason: 'the floor reports nothing');
    expect(r.doc.commands.undoDepth, 0);
  });

  testWidgets(
      'ST2 a Shift tap toggles; a Shift tap on the floor keeps the selection',
      (tester) async {
    final r = rig(tester);
    r.tap(r.at('1', 900, 700));
    r.tap(r.at('2', 900, 400), shift: true);
    expect(r.selection.keys, {r.key('1'), r.key('2')});
    r.tap(const Offset(40, 40), shift: true);
    expect(r.selection.keys, hasLength(2));
    r.tap(r.at('1', 900, 700), shift: true);
    expect(r.selection.keys, {r.key('2')});
  });

  testWidgets(
      'ST3 a drag on a selected table moves the selection: one step, '
      'translation only, the drag\'s delta (M-14c2-3, M-14c2-4)',
      (tester) async {
    final r = rig(tester);
    r.tap(r.at('1', 900, 700));
    r.tap(r.at('2', 900, 400), shift: true);
    final before1 = parts(r.node('1').transform);
    final before2 = parts(r.node('2').transform);
    final start = r.at('2', 900, 400);
    r.down(start);
    r.move(start + const Offset(30, 0));
    r.move(start + const Offset(60, -20));
    // 60 px right, 20 px up: +600, +200 in world (review F-6).
    expect(parts(r.tool.selectionPreviewTransform!),
        [1, 0, 0, 1, closeTo(600, 1e-6), closeTo(200, 1e-6)]);
    r.move(start + const Offset(85, -35));
    r.up(start + const Offset(85, -35));
    expect(r.doc.commands.undoDepth, 1, reason: 'one step per drag');
    expect(r.layouts, 1);
    // 85 px right, 35 px up at 0.1 px/mm: +850, +350 in world.
    for (final (n, before) in [('1', before1), ('2', before2)]) {
      final after = parts(r.node(n).transform);
      expect(after.sublist(0, 4), before.sublist(0, 4), reason: 'linear');
      expect(after[4], closeTo(before[4] + 850, 1e-6));
      expect(after[5], closeTo(before[5] + 350, 1e-6));
    }
    expect(r.taps, ['1', '2'], reason: 'a drag reports no tap');
    r.doc.commands.undo();
    expect(parts(r.node('1').transform), before1);
  });

  testWidgets('ST4 a drag on an unselected table selects it alone and moves it',
      (tester) async {
    final r = rig(tester);
    r.tap(r.at('1', 900, 700));
    final before1 = parts(r.node('1').transform);
    final before = parts(r.node('2').transform);
    final start = r.at('2', 900, 400);
    r.down(start);
    r.move(start + const Offset(-40, 40));
    r.up(start + const Offset(-40, 40));
    expect(r.selection.keys, {r.key('2')});
    expect(parts(r.node('2').transform)[4], closeTo(before[4] - 400, 1e-6));
    expect(parts(r.node('1').transform), before1,
        reason: 'the previous selection stays where it was (review F-1)');
  });

  testWidgets(
      'ST5 a long press toggles and spends the gesture: no tap, no move '
      '(M-14c2-5)', (tester) async {
    final r = rig(tester);
    r.tap(r.at('1', 900, 700));
    final p = r.at('2', 900, 400);
    r.down(p);
    await tester.pump(const Duration(milliseconds: 499));
    expect(r.selection.keys, {r.key('1')});
    await tester.pump(const Duration(milliseconds: 2));
    expect(r.selection.keys, {r.key('1'), r.key('2')}, reason: 'added');
    r.move(p + const Offset(80, 0));
    r.up(p + const Offset(80, 0));
    expect(r.doc.commands.undoDepth, 0, reason: 'spent: no move');
    expect(r.taps, ['1'], reason: 'a long press reports no tap');
    r.down(p);
    await tester.pump(const Duration(milliseconds: 501));
    r.up(p);
    expect(r.selection.keys, {r.key('1')}, reason: 'removed');
  });

  testWidgets(
      'ST6 a press that drags before the long press never toggles; a short '
      'press is a tap (M-14c2-6)', (tester) async {
    final r = rig(tester);
    final p = r.at('1', 900, 700);
    r.down(p);
    await tester.pump(const Duration(milliseconds: 300));
    r.move(p + const Offset(40, 0));
    await tester.pump(const Duration(milliseconds: 400));
    r.up(p + const Offset(40, 0));
    expect(r.selection.keys, {r.key('1')}, reason: 'dragged, selected');
    expect(r.doc.commands.undoDepth, 1);
    r.down(r.at('2', 900, 400));
    await tester.pump(const Duration(milliseconds: 450));
    r.up(r.at('2', 900, 400));
    expect(r.selection.keys, {r.key('2')}, reason: 'a tap, not a toggle');
    await tester.pump(const Duration(milliseconds: 200));
    expect(r.selection.keys, {r.key('2')}, reason: 'the timer was cancelled');
  });

  testWidgets(
      'ST7 a locked table is tapped only: reported, never selected, toggled '
      'or moved (M-14l)', (tester) async {
    final r = rig(tester);
    r.tap(r.at('1', 900, 700));
    final before = parts(r.node('3').transform);
    final p = r.at('3', 900, 700);
    r.tap(p);
    expect(r.taps, ['1', '3']);
    expect(r.selection.keys, {r.key('1')});
    r.down(p);
    await tester.pump(const Duration(milliseconds: 600));
    r.up(p);
    expect(r.selection.keys, {r.key('1')}, reason: 'no toggle');
    final cam = parts(r.camera.value.worldToScreenMatrix);
    r.down(p);
    r.move(p + const Offset(60, 60));
    r.up(p + const Offset(60, 60));
    expect(parts(r.node('3').transform), before);
    expect(parts(r.camera.value.worldToScreenMatrix), cam, reason: 'no pan');
    expect(r.doc.commands.undoDepth, 0);
  });

  testWidgets('ST8 a drag on the floor pans and keeps the selection',
      (tester) async {
    final r = rig(tester);
    r.tap(r.at('1', 900, 700));
    final before = r.camera.value.worldToScreenMatrix;
    r.down(const Offset(40, 40));
    r.move(const Offset(70, 50));
    r.move(const Offset(100, 90));
    r.up(const Offset(100, 90));
    final after = r.camera.value.worldToScreenMatrix;
    expect(after.e, closeTo(before.e + 60, 1e-9));
    expect(after.f, closeTo(before.f + 50, 1e-9));
    expect(r.selection.keys, {r.key('1')});
    expect(r.doc.commands.undoDepth, 0);
  });

  testWidgets(
      'ST9 cancel mid-drag executes nothing and stops the timer; hover moves '
      'are ignored; Escape clears (R-5, R-6)', (tester) async {
    final r = rig(tester);
    final p = r.at('2', 900, 400);
    r.down(p);
    r.move(p + const Offset(50, 0));
    r.tool.cancel(r.ctx);
    r.up(p + const Offset(50, 0));
    expect(r.doc.commands.undoDepth, 0);
    r.down(p);
    r.tool.cancel(r.ctx);
    await tester.pump(const Duration(milliseconds: 600));
    expect(r.selection.keys, {r.key('2')}, reason: 'no toggle after cancel');

    r.tool.onPointerMove(r.ev(p + const Offset(90, 0), buttons: 0), r.ctx);
    expect(r.tool.phase, ToolPhase.idle);
    r.tool.onKey(
        const KeyDownEvent(
            physicalKey: PhysicalKeyboardKey.escape,
            logicalKey: LogicalKeyboardKey.escape,
            timeStamp: Duration.zero),
        r.ctx);
    expect(r.selection.isEmpty, isTrue);
  });

  testWidgets(
      'ST10 the asymmetric, mirrored top: picked where it is, and off it '
      'inside its box', (tester) async {
    final r = rig(tester);
    r.tap(r.at('2', 1250, 950));
    expect(r.selection.keys, {r.key('2')});
    r.tap(r.at('2', 1700, 700));
    expect(r.selection.isEmpty, isTrue, reason: 'outside the box');
    r.tap(r.at('2', 1500, 950));
    expect(r.selection.keys, {r.key('2')},
        reason: 'outside the trapezoid, inside its box: no line hit');
    expect(jsonEncode(r.taps), '["2","2"]');
  });

  testWidgets(
      'ST11 a cancelled press leaves no timer behind: a later press is not '
      'toggled early (R-5, review F-2)', (tester) async {
    final r = rig(tester);
    r.down(r.at('1', 900, 700));
    await tester.pump(const Duration(milliseconds: 300));
    r.tool.cancel(r.ctx);
    final b = r.at('2', 900, 400);
    r.down(b);
    await tester.pump(const Duration(milliseconds: 250));
    expect(r.selection.keys, isEmpty, reason: 'the old timer did not fire');
    r.up(b);
    expect(r.selection.keys, {r.key('2')}, reason: 'a tap');
    expect(r.taps, ['2']);
  });

  testWidgets(
      'ST12 within the touch slop a press stays a tap; past it, a drag '
      '(R-7, review F-6)', (tester) async {
    final r = rig(tester);
    final p = r.at('2', 900, 400);
    r.down(p);
    r.move(p + const Offset(12, 0));
    r.up(p + const Offset(12, 0));
    expect(r.taps, ['2'], reason: '12 px is within kTouchSlop');
    expect(r.doc.commands.undoDepth, 0);
    r.down(p);
    r.move(p + const Offset(19, 0));
    r.up(p + const Offset(19, 0));
    expect(r.taps, ['2'], reason: '19 px is past it: no tap');
    expect(r.doc.commands.undoDepth, 1);
  });

  testWidgets(
      'ST13 a drag back to its start executes nothing and reports no layout '
      'change (review F-6)', (tester) async {
    final r = rig(tester);
    final p = r.at('2', 900, 400);
    r.down(p);
    r.move(p + const Offset(60, 30));
    r.move(p);
    r.up(p);
    expect(r.doc.commands.undoDepth, 0);
    expect(r.layouts, 0);
    expect(r.taps, isEmpty, reason: 'a drag, not a tap');
  });

  testWidgets('ST14 Ctrl and Cmd toggle as Shift does (S3, review F-6)',
      (tester) async {
    final r = rig(tester);
    r.tap(r.at('1', 900, 700));
    r.tap(r.at('2', 900, 400), control: true);
    expect(r.selection.keys, {r.key('1'), r.key('2')});
    r.tap(r.at('1', 900, 700), meta: true);
    expect(r.selection.keys, {r.key('2')});
    r.tap(const Offset(40, 40), meta: true);
    expect(r.selection.keys, {r.key('2')}, reason: 'the floor keeps it');
    r.tap(const Offset(40, 40), control: true);
    expect(r.selection.keys, {r.key('2')});
  });

  testWidgets(
      'ST15 an undo mid-drag: the step applies to each transform as it is at '
      'release (R-6, review F-6)', (tester) async {
    final r = rig(tester);
    final before = parts(r.node('2').transform);
    final p = r.at('2', 900, 400);
    r.down(p);
    r.move(p + const Offset(-50, 0));
    r.up(p + const Offset(-50, 0));
    expect(r.doc.commands.undoDepth, 1);
    final q = r.at('2', 900, 400);
    r.down(q);
    r.move(q + const Offset(0, -30));
    r.doc.commands.undo(); // the first move, while the second drags
    r.up(q + const Offset(0, -30));
    final after = parts(r.node('2').transform);
    expect(after.sublist(0, 4), before.sublist(0, 4));
    expect(after[4], closeTo(before[4], 1e-6), reason: 'the undone -500 x');
    expect(after[5], closeTo(before[5] + 300, 1e-6), reason: 'the +300 y');
  });

  testWidgets(
      'ST16 a finger 15 px outside a table selects it; a mouse there does '
      'not (spec 14t R-11, M-14t-26)', (tester) async {
    final r = rig(tester);
    // 150 mm below the trapezoid's bottom edge (y 300): 15 px.
    final p = r.at('2', 900, 150);
    r.tap(p);
    expect(r.selection.isEmpty, isTrue);
    expect(r.taps, isEmpty);
    r.tap(r.at('2', 900, 260)); // 40 mm, 4 px: a mouse has no reach
    expect(r.selection.isEmpty, isTrue, reason: 'review F-5');
    r.tool.onPointerDown(r.ev(p, touch: true), r.ctx);
    r.tool.onPointerUp(r.ev(p, touch: true, buttons: 0), r.ctx);
    expect(r.selection.keys, {r.key('2')});
    expect(r.taps, ['2']);
    // 300 mm: past a finger's reach.
    final far = r.at('2', 900, 0);
    r.tool.onPointerDown(r.ev(far, touch: true), r.ctx);
    r.tool.onPointerUp(r.ev(far, touch: true, buttons: 0), r.ctx);
    expect(r.selection.isEmpty, isTrue);
  });

  testWidgets(
      'ST17 a finger\'s long press toggles kTouchHoldBack sooner than a '
      'mouse\'s: 500 ms from contact (T5, M-14t-15)', (tester) async {
    final r = rig(tester);
    final p = r.at('2', 900, 400);
    final early = kLongPressTimeout - kTouchHoldBack;
    r.tool.onPointerDown(r.ev(p, touch: true), r.ctx);
    await tester.pump(early - const Duration(milliseconds: 1));
    expect(r.selection.isEmpty, isTrue);
    await tester.pump(const Duration(milliseconds: 2));
    expect(r.selection.keys, {r.key('2')});
    r.tool.onPointerUp(r.ev(p, touch: true, buttons: 0), r.ctx);
    r.down(p);
    await tester.pump(early + const Duration(milliseconds: 1));
    expect(r.selection.keys, {r.key('2')}, reason: 'a mouse waits 500 ms');
    await tester.pump(kTouchHoldBack);
    expect(r.selection.isEmpty, isTrue);
    r.up(p);
  });
}
