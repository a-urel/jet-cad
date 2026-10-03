// Spec 14c S3, S4, S8, R-1, R-5, R-6: the selection mode's tool -- taps,
// modifier taps, long presses, drags that move the selection in one step,
// pans on the floor, locked tables tapped only, cancel and Escape. Under
// fake time (testWidgets), so the long press is driven by pumps. Tables are
// off the origin, turned and mirrored, on a service copy (runtime).
import 'dart:convert';

import 'package:flutter/gestures.dart' show kPrimaryButton;
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
        callbacks: () => (
              onTableTap: taps.add,
              onLayoutChanged: () => layouts++,
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
          {int buttons = kPrimaryButton, bool shift = false}) =>
      ToolPointerEvent(
        screen: screen,
        world: camera.value.screenToWorld(Vector2(screen.dx, screen.dy)),
        pointer: 1,
        buttons: buttons,
        shift: shift,
        control: false,
        meta: false,
        alt: false,
        pickRadiusWorld: 6 / camera.value.scale,
      );

  void down(Offset s, {bool shift = false}) =>
      tool.onPointerDown(ev(s, shift: shift), ctx);
  void move(Offset s) => tool.onPointerMove(ev(s), ctx);
  void up(Offset s) => tool.onPointerUp(ev(s, buttons: 0), ctx);

  void tap(Offset s, {bool shift = false}) {
    down(s, shift: shift);
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
    expect(r.tool.selectionPreviewTransform, isNotNull);
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
    final before = parts(r.node('2').transform);
    final start = r.at('2', 900, 400);
    r.down(start);
    r.move(start + const Offset(-40, 40));
    r.up(start + const Offset(-40, 40));
    expect(r.selection.keys, {r.key('2')});
    expect(parts(r.node('2').transform)[4], closeTo(before[4] - 400, 1e-6));
    expect(parts(r.node('1').transform)[4], isNot(before[4]));
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

  testWidgets('ST10 the asymmetric, mirrored top: picked where it is',
      (tester) async {
    final r = rig(tester);
    r.tap(r.at('2', 1250, 950));
    expect(r.selection.keys, {r.key('2')});
    r.tap(r.at('2', 1400, 950));
    expect(r.selection.isEmpty, isTrue, reason: 'outside the trapezoid');
    expect(jsonEncode(r.taps), '["2"]');
  });
}
