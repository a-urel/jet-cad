// Rubber-band spec RB-2 to RB-6 at the selection mode's tool: when a band
// starts (the host's `floorDrag`, the modifier read at the down, a finger's
// reach-only press), what it takes (the band query kept to the picker's
// candidates, groups by the mode's rule, locks), what it does to the
// selection (one `replace`), Escape and cancel, and its painting. Under fake
// time (testWidgets). The camera is y-flipped, scaled and off the origin;
// tables are turned and mirrored, one L-shaped table is turned 37 degrees;
// the plan holds a group of three, a locked table, a group with a locked
// member, an unnumbered table, a hidden one and a planter. Band rects are
// computed from the tables' leaves under their transforms, never read from
// the code.
import 'dart:ui' show Canvas, Offset, Paint, PaintingStyle, Rect, Size;

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter/gestures.dart' show PointerDeviceKind, kPrimaryButton;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart' show KeyEventResult;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_floor_plan/src/host/floor_plan_types.dart';
import 'package:jet_cad_floor_plan/src/parametric/catalog.dart';
import 'package:jet_cad_floor_plan/src/service/table_groups.dart';
import 'package:jet_cad_floor_plan/src/service/table_picker.dart';
import 'package:jet_cad_floor_plan/src/service/table_select_tool.dart';
import 'package:jet_cad_floor_plan/src/symbols/symbol_placer.dart';
import 'package:jet_cad_floor_plan/src/tables/table_index.dart';
import 'package:jet_cad_floor_plan/src/tables/table_label.dart';
import 'package:jet_cad_floor_plan/symbols.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../tables/table_fixture.dart';

/// An L-shaped top, its empty quadrant at the upper right of its
/// 1200 x 1200 box (review V-5): turned 37 degrees, a corner of its
/// bounding box lies off every leaf.
///
/// Two leaves, not the plan's one L polyline: the index's window encloses
/// each leaf's own box lifted to the world (`SpatialIndex._leafPasses`), and
/// one L polyline's box is the whole 1200 x 1200 square, so no band could
/// enclose the leaf and miss the box's corner. Two bars keep the same L and
/// make RB6's premise reachable.
const FurnitureSymbol ellTable = FurnitureSymbol(
  key: 'test.ell',
  name: 'Test L table',
  category: 'Tests',
  tags: ['table', 'test'],
  seats: 3,
  baseX: 600,
  baseY: 600,
  shapes: [
    PolylineShape([(0, 0), (1200, 0), (1200, 500), (0, 500)], closed: true),
    PolylineShape([(0, 500), (500, 500), (500, 1200), (0, 1200)], closed: true),
  ],
);

/// [ellTable]'s leaves, in its definition.
const List<List<(double, double)>> _ellLeaves = [
  [(0, 0), (1200, 0), (1200, 500), (0, 500)],
  [(0, 500), (500, 500), (500, 1200), (0, 1200)],
];

/// [tableSymbol]'s top and chairs, in its definition.
const List<List<(double, double)>> _tableLeaves = [
  [(300, 300), (1500, 300), (1500, 1100), (300, 1100)],
  [(675, -50), (1125, -50), (1125, 400), (675, 400)],
  [(675, 1000), (1125, 1000), (1125, 1450), (675, 1450)],
];

/// [trapezoidTable]'s top, in its definition.
const List<List<(double, double)>> _trapezoidLeaves = [
  [(200, 300), (1600, 300), (1300, 1000), (500, 900)],
];

const KeyDownEvent _escape = KeyDownEvent(
    physicalKey: PhysicalKeyboardKey.escape,
    logicalKey: LogicalKeyboardKey.escape,
    timeStamp: Duration.zero);

const KeyDownEvent _z = KeyDownEvent(
    physicalKey: PhysicalKeyboardKey.keyZ,
    logicalKey: LogicalKeyboardKey.keyZ,
    timeStamp: Duration.zero);

/// A canvas that records every call.
final class RecordingCanvas implements Canvas {
  final List<Invocation> calls = [];

  Iterable<Invocation> named(String name) =>
      calls.where((c) => c.memberName == Symbol(name));

  @override
  dynamic noSuchMethod(Invocation invocation) {
    calls.add(invocation);
    return null;
  }
}

List<double> parts(Transform2 t) => [t.a, t.b, t.c, t.d, t.e, t.f];

/// The world box of [points].
Aabb2 boxOf(Iterable<Vector2> points) => Aabb2.fromPoints(points);

/// [box] grown by [pad] on every side.
Aabb2 padded(Aabb2 box, double pad) =>
    Aabb2.raw(box.minX - pad, box.minY - pad, box.maxX + pad, box.maxY + pad);

bool encloses(Aabb2 outer, Vector2 p) =>
    p.x > outer.minX &&
    p.x < outer.maxX &&
    p.y > outer.minY &&
    p.y < outer.maxY;

bool overlaps(Aabb2 a, Aabb2 b) =>
    a.minX <= b.maxX &&
    a.maxX >= b.minX &&
    a.minY <= b.maxY &&
    a.maxY >= b.minY;

final class Rig {
  /// Tables 1 (at -2000, 1000, a quarter turn, mirrored), 2 (a trapezoid at
  /// 2500, 1000, mirrored), 3 (at 0, -2500, on a locked layer), 4, 5, 6 (at
  /// 6000, 7600 and 9200 by 1000: group 'g'), 7, 8 (at 6000 and 7600 by
  /// -3000: group 'h', 8 on the locked layer), 9 (the L at -6000, -3000,
  /// turned 37 degrees), 10 (at -6000, 2500, its label emptied), 11 (at
  /// -9000, 2500, on a hidden layer) and a planter (at -3500, -1000),
  /// decoded as a service copy.
  Rig() {
    final design = plan();
    void put(FurnitureSymbol s, double x, double y,
        {int quarterTurns = 0, bool mirrored = false}) {
      design.commands.execute(placeSymbol(design, entryOf(s),
          at: Vector2(x, y), quarterTurns: quarterTurns, mirrored: mirrored));
    }

    Handle newest() => design.tree.nodes
        .whereType<InstanceNode>()
        .reduce((a, b) => a.handle.value > b.handle.value ? a : b)
        .handle;

    final zero = design.tables.layers[ReservedHandles.layerZero]!;
    Handle layer(String name) {
      final h = design.handleSeed.next();
      design.commands.execute(AddLayerCommand(LayerRecord(
          handle: h,
          name: name,
          color: const IndexedColor(1),
          linetype: zero.linetype,
          lineweight: zero.lineweight,
          transparency: zero.transparency,
          visible: true,
          locked: false)));
      return h;
    }

    final locked = layer('Locked');
    final hidden = layer('Hidden');
    put(tableSymbol(), -2000, 1000, quarterTurns: 1, mirrored: true); // 1
    put(trapezoidTable, 2500, 1000, mirrored: true); // 2
    put(tableSymbol(), 0, -2500); // 3
    design.commands.execute(SetInstanceLayerCommand(newest(), locked));
    put(tableSymbol(), 6000, 1000); // 4
    put(tableSymbol(), 7600, 1000); // 5
    put(tableSymbol(), 9200, 1000); // 6
    put(tableSymbol(), 6000, -3000); // 7
    put(tableSymbol(), 7600, -3000); // 8
    design.commands.execute(SetInstanceLayerCommand(newest(), locked));
    put(ellTable, -6000, -3000); // 9
    design.commands.execute(TransformNodeCommand(
        newest(), placementAt(-6000, -3000, kDeg37, baseX: 600, baseY: 600)));
    put(tableSymbol(), -6000, 2500); // 10
    final tenth = newest();
    put(tableSymbol(), -9000, 2500); // 11
    design.commands.execute(SetInstanceLayerCommand(newest(), hidden));
    put(planterSymbol, -3500, -1000);
    final planter = newest();
    final survey = TableSurvey.of(design);
    final tenthLabel =
        survey.tables.singleWhere((t) => t.instance == tenth).label!;
    expect(survey.tables.singleWhere((t) => t.instance == tenth).number, '10',
        reason: 'premise: placed tenth');
    design.commands
        .execute(SetEntityTextCommand(tenthLabel, '', kTableLabelTag));
    design.commands.execute(
        SetLayerCommand(design.tables.layers[locked]!.copyWith(locked: true)));
    design.commands.execute(SetLayerCommand(
        design.tables.layers[hidden]!.copyWith(visible: false)));

    doc = DraftDocumentCodec.decodeString(
        DraftDocumentCodec.encodeToString(design),
        permissions: DraftPermissions.runtime,
        registerComponents: registerAppComponents,
        diagnostics: <Diagnostic>[]);
    final tables = TableSurvey.of(doc).tables;
    handles = {
      for (final t in tables)
        if (t.number case final n?) n: t.instance,
    };
    handles['10'] = tenth;
    handles['planter'] = planter;
    expect(tables.singleWhere((t) => t.instance == tenth).number, isNull,
        reason: 'premise: 10 is unnumbered after the round trip');
    expect(doc.tree[planter], isA<InstanceNode>());
    expect(
        handles.keys.toSet(), {for (var i = 1; i <= 11; i++) '$i', 'planter'});

    camera = CameraController(ViewportTransform(
        worldToScreenMatrix: Transform2(0.1, 0, 0, -0.1, 700, 450)));
    index = SpatialIndex(doc);
    selection = SelectionController(doc);
    picker = TablePicker(doc);
    tool = TableSelectTool(
        picker: picker,
        groups: groups,
        callbacks: () => (
              onTableTap: taps.add,
              onLayoutChanged: null,
              onGroupTap: null,
              onMergeRequested: null,
              onSplitRequested: null,
            ),
        options: () => options,
        events: () => events,
        idleKeys: () => idleKeys);
    ctx = ToolContext(
        document: doc, index: index, camera: camera, selection: selection);
  }

  late final DraftDocument doc;
  late final CameraController camera;
  late final SpatialIndex index;
  late final SelectionController selection;
  late final TablePicker picker;
  late final TableSelectTool tool;
  late final ToolContext ctx;
  late final Map<String, Handle> handles;

  /// The host's groups: 'g' of three, 'h' of two with 8 locked.
  final ValueNotifier<Map<String, TableGroup>> groups =
      ValueNotifier(validateTableGroups({
    'g': TableGroup(members: {'4', '5', '6'}),
    'h': TableGroup(members: {'7', '8'}),
  }));

  /// What the tool reads at each press.
  ServiceOptions options = kDefaultServiceOptions;
  bool idleKeys = true;

  final List<String> taps = [];
  final List<String> doubleTaps = [];
  final List<Offset> floors = [];
  final List<String?> hovers = [];

  late final ServiceEvents<Handle> events = (
    onTablesMoved: null,
    onTableDoubleTap: doubleTaps.add,
    onFloorTap: floors.add,
    onTableHover: hovers.add,
  );

  void drag(FloorPlanFloorDrag floorDrag, {bool serviceMoves = true}) =>
      options = (
        serviceMoves: serviceMoves,
        longPress: FloorPlanLongPress.toggleSelection,
        onTableContextMenu: null,
        floorDrag: floorDrag,
      );

  void dispose() {
    tool.dispose();
    selection.dispose();
    index.dispose();
    camera.dispose();
    groups.dispose();
  }

  InstanceNode node(String n) => doc.tree[handles[n]!]! as InstanceNode;

  SelectionKey key(String n) => SelectionKey.root(handles[n]!);

  Set<SelectionKey> keys(List<String> ns) => {for (final n in ns) key(n)};

  /// The leaves of table [n] in its definition.
  List<List<(double, double)>> leavesOf(String n) => switch (n) {
        '2' => _trapezoidLeaves,
        '9' => _ellLeaves,
        _ => _tableLeaves,
      };

  /// Local ([x], [y]) of table [n] in the world.
  Vector2 world(String n, double x, double y) =>
      node(n).transform.transformPoint(Vector2(x, y));

  /// The world box of every leaf of tables [ns].
  Aabb2 leafBox(List<String> ns) => boxOf([
        for (final n in ns)
          for (final leaf in leavesOf(n))
            for (final (x, y) in leaf) world(n, x, y)
      ]);

  Offset screen(Vector2 w) {
    final s = camera.value.worldToScreen(w);
    return Offset(s.x, s.y);
  }

  Vector2 toWorld(Offset s) => camera.value.screenToWorld(Vector2(s.dx, s.dy));

  /// The screen point of local ([x], [y]) of table [n].
  Offset at(String n, double x, double y) => screen(world(n, x, y));

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
          {bool shift = false,
          bool control = false,
          bool meta = false,
          bool touch = false}) =>
      tool.onPointerDown(
          ev(s, shift: shift, control: control, meta: meta, touch: touch), ctx);
  void move(Offset s,
          {bool shift = false,
          bool control = false,
          bool meta = false,
          bool touch = false}) =>
      tool.onPointerMove(
          ev(s, shift: shift, control: control, meta: meta, touch: touch), ctx);
  void up(Offset s,
          {bool shift = false,
          bool control = false,
          bool meta = false,
          bool touch = false}) =>
      tool.onPointerUp(
          ev(s,
              buttons: 0,
              shift: shift,
              control: control,
              meta: meta,
              touch: touch),
          ctx);

  void tap(Offset s, {bool touch = false}) {
    down(s, touch: touch);
    up(s, touch: touch);
  }

  /// A band over world [box]: a window from its upper left to its lower
  /// right, or a crossing from its upper right to its lower left. Its press
  /// is asserted off every table (a mouse's pick, no reach).
  void band(Aabb2 box,
      {bool crossing = false,
      bool shift = false,
      bool control = false,
      bool meta = false,
      bool touch = false}) {
    final start = Vector2(crossing ? box.maxX : box.minX, box.maxY);
    final end = Vector2(crossing ? box.minX : box.maxX, box.minY);
    expect(picker.pick(start), isNull, reason: 'premise: pressed on the floor');
    final s = screen(start), e = screen(end);
    down(s, shift: shift, control: control, meta: meta, touch: touch);
    move(Offset.lerp(s, e, 0.5)!,
        shift: shift, control: control, meta: meta, touch: touch);
    move(e, shift: shift, control: control, meta: meta, touch: touch);
    up(e, shift: shift, control: control, meta: meta, touch: touch);
  }

  /// What the overlay paints now.
  RecordingCanvas paint() {
    final canvas = RecordingCanvas();
    tool.paintOverlay(
        canvas, camera.value, const Size(1400, 900), PaperPalette.light);
    return canvas;
  }
}

Rig rig(WidgetTester tester) {
  final r = Rig();
  addTearDown(r.dispose);
  return r;
}

void main() {
  testWidgets(
      'RB1 under pan a plain mouse drag on the floor pans: the selection '
      'unchanged, no band (M-RB1)', (tester) async {
    final r = rig(tester);
    r.selection.replace([r.key('1')]);
    final before = r.camera.value.worldToScreenMatrix;
    const a = Offset(1000, 120), b = Offset(1060, 160);
    expect(r.picker.pick(r.toWorld(a)), isNull, reason: 'premise: the floor');
    r.down(a);
    r.move(const Offset(1030, 140));
    r.move(b);
    expect(r.paint().calls, isEmpty, reason: 'no band painted');
    r.up(b);
    final after = r.camera.value.worldToScreenMatrix;
    expect(after.e, closeTo(before.e + 60, 1e-9));
    expect(after.f, closeTo(before.f + 40, 1e-9));
    expect(r.selection.keys, {r.key('1')});
  });

  testWidgets(
      'RB2 under pan a Shift, Ctrl or Cmd mouse drag bands and adds; a Shift '
      'touch drag pans (M-RB2)', (tester) async {
    final r = rig(tester);
    // Padded 600 mm: the press is past a finger's 24 px reach too.
    final box = padded(r.leafBox(['1', '2']), 600);
    for (final (shift, control, meta) in [
      (true, false, false),
      (false, true, false),
      (false, false, true),
    ]) {
      r.selection.replace([r.key('9')]);
      r.band(box, shift: shift, control: control, meta: meta);
      expect(r.selection.keys, r.keys(['1', '2', '9']),
          reason: 'shift $shift, control $control, meta $meta');
    }
    r.selection.replace([r.key('9')]);
    final before = r.camera.value.worldToScreenMatrix;
    expect(r.picker.pick(Vector2(box.minX, box.maxY), reach: 240), isNull,
        reason: 'premise: out of a finger\'s reach');
    r.band(box, shift: true, touch: true);
    final after = r.camera.value.worldToScreenMatrix;
    expect(after.e, isNot(closeTo(before.e, 1)), reason: 'a finger pans');
    expect(r.selection.keys, {r.key('9')});
  });

  testWidgets(
      'RB2b the modifier is read at the down (R-1): under pan Shift at the '
      'down only still bands and adds; under band Shift on the moves and the '
      'up only still replaces (M-RB24, M-RB25)', (tester) async {
    final r = rig(tester);
    final box = padded(r.leafBox(['1', '2']), 600);
    final s = r.screen(Vector2(box.minX, box.maxY));
    final e = r.screen(Vector2(box.maxX, box.minY));
    expect(r.picker.pick(r.toWorld(s)), isNull, reason: 'premise: the floor');
    expect(r.options.floorDrag, FloorPlanFloorDrag.pan, reason: 'premise');

    // Under pan: Shift at the down only. Read at the first move (M-RB25) the
    // drag would pan; read at the up (M-RB24) it would replace.
    r.selection.replace([r.key('9')]);
    final before = parts(r.camera.value.worldToScreenMatrix);
    r.down(s, shift: true);
    r.move(Offset.lerp(s, e, 0.5)!);
    r.move(e);
    r.up(e);
    expect(r.selection.keys, r.keys(['1', '2', '9']), reason: 'a band adds');
    expect(parts(r.camera.value.worldToScreenMatrix), before, reason: 'no pan');

    // Under band: a plain down, Shift on the moves and the up. Read at the
    // up (M-RB24) it would add 9 to the band's keys.
    r.drag(FloorPlanFloorDrag.band);
    r.selection.replace([r.key('9')]);
    r.down(s);
    r.move(Offset.lerp(s, e, 0.5)!, shift: true);
    r.move(e, shift: true);
    r.up(e, shift: true);
    expect(r.selection.keys, r.keys(['1', '2']), reason: 'a band replaces');
  });

  testWidgets(
      'RB5 under band a drag from a table moves it, from a locked one is '
      'spent; with serviceMoves false it pans (M-RB5)', (tester) async {
    final r = rig(tester);
    r.drag(FloorPlanFloorDrag.band);
    final before = parts(r.node('2').transform);
    final p = r.at('2', 900, 650);
    r.down(p);
    r.move(p + const Offset(40, 0));
    expect(r.paint().calls, isEmpty);
    r.up(p + const Offset(40, 0));
    expect(r.doc.commands.undoDepth, 1, reason: 'one step');
    expect(parts(r.node('2').transform)[4], closeTo(before[4] + 400, 1e-6));
    expect(r.selection.keys, {r.key('2')});

    final cam = parts(r.camera.value.worldToScreenMatrix);
    final q = r.at('3', 900, 700);
    r.down(q);
    r.move(q + const Offset(-60, 30));
    expect(r.tool.phase, ToolPhase.pressed, reason: 'spent');
    expect(r.paint().calls, isEmpty);
    r.up(q + const Offset(-60, 30));
    expect(r.selection.keys, {r.key('2')});
    expect(r.doc.commands.undoDepth, 1);
    expect(parts(r.camera.value.worldToScreenMatrix), cam);

    r.drag(FloorPlanFloorDrag.band, serviceMoves: false);
    final s = r.at('2', 900, 650);
    r.down(s);
    r.move(s + const Offset(30, 20));
    r.up(s + const Offset(30, 20));
    final after = r.camera.value.worldToScreenMatrix;
    expect(after.e, closeTo(cam[4] + 30, 1e-9), reason: 'pans (R-3)');
    expect(after.f, closeTo(cam[5] + 20, 1e-9));
    expect(r.doc.commands.undoDepth, 1);
    expect(r.selection.keys, {r.key('2')});
  });

  testWidgets(
      'RB5b under band a finger 10 px outside a table\'s box bands when '
      'dragged and selects the table when tapped (R-4, M-RB5b)',
      (tester) async {
    final r = rig(tester);
    r.drag(FloorPlanFloorDrag.band);
    r.selection.replace([r.key('1')]);
    final before = parts(r.node('2').transform);
    // 100 mm below the trapezoid's box (y 300): 10 px.
    final p = r.at('2', 900, 200);
    expect(r.picker.pick(r.toWorld(p)), isNull, reason: 'premise: off it');
    expect(r.picker.pick(r.toWorld(p), reach: 240)?.table.number, '2',
        reason: 'premise: within a finger\'s reach');
    r.down(p, touch: true);
    r.move(p + const Offset(40, 60), touch: true);
    expect(r.tool.phase, ToolPhase.dragging);
    expect(r.tool.selectionPreviewTransform, isNull, reason: 'no move');
    expect(r.paint().named('drawRect'), hasLength(2), reason: 'a band');
    r.up(p + const Offset(40, 60), touch: true);
    expect(parts(r.node('2').transform), before);
    expect(r.doc.commands.undoDepth, 0);
    expect(r.selection.isEmpty, isTrue, reason: 'a plain band over nothing');
    r.tap(p, touch: true);
    expect(r.selection.keys, {r.key('2')});
    expect(r.taps, ['2']);
  });

  testWidgets(
      'RB6 a window takes the turned L when every leaf is inside, a corner '
      'of its box outside (M-RB6)', (tester) async {
    final r = rig(tester);
    r.drag(FloorPlanFloorDrag.band);
    final band = padded(r.leafBox(['9']), 50);
    // Each leaf is a rectangle: its vertices' world box is its own box
    // lifted to the world, what the index's window encloses.
    for (final leaf in _ellLeaves) {
      final leafBox = boxOf([for (final (x, y) in leaf) r.world('9', x, y)]);
      for (final corner in [
        Vector2(leafBox.minX, leafBox.minY),
        Vector2(leafBox.maxX, leafBox.maxY),
      ]) {
        expect(encloses(band, corner), isTrue,
            reason: 'premise: leaf $leaf\'s box inside');
      }
    }
    final box = boxOf([
      for (final (x, y) in const [(0.0, 0.0), (1200.0, 0.0), (0.0, 1200.0)])
        r.world('9', x, y),
      r.world('9', 1200, 1200),
    ]);
    expect(encloses(band, r.world('9', 1200, 1200)), isFalse,
        reason: 'premise: the empty quadrant\'s corner is outside');
    expect(box.maxY, greaterThan(band.maxY),
        reason: 'premise: the instance\'s world box is not enclosed');
    r.band(band);
    expect(r.selection.keys, {r.key('9')});
  });

  testWidgets(
      'RB7 a crossing takes a table it touches by a chair, nothing over the '
      'L\'s empty quadrant; turned back mid-drag it crosses (M-RB7, M-RB7b)',
      (tester) async {
    final r = rig(tester);
    r.drag(FloorPlanFloorDrag.band);
    // Off table 1's top (local y 300 up) and box (y -50 up), over its chair
    // (local y -50 to 400): a quarter turn keeps the box exact.
    final chair = boxOf([
      for (final (x, y) in const [(600.0, -300.0), (1200.0, 0.0)])
        r.world('1', x, y)
    ]);
    final top =
        boxOf([for (final (x, y) in _tableLeaves[0]) r.world('1', x, y)]);
    expect(overlaps(chair, top), isFalse, reason: 'premise: off the top');
    r.band(chair, crossing: true);
    expect(r.selection.keys, {r.key('1')}, reason: 'touched by its chair');

    // Above the L's leaves, inside its turned box only near the empty
    // quadrant's corner.
    final leaves = r.leafBox(['9']);
    final corner = r.world('9', 1200, 1200);
    final quadrant = Aabb2.raw(
        corner.x - 400, leaves.maxY + 230, corner.x + 400, leaves.maxY + 330);
    expect(
        r.picker.candidates.where((c) => c.table.number == '9'), hasLength(1));
    expect(quadrant.maxY, lessThan(corner.y),
        reason: 'premise: under the box\'s top corner');
    r.band(quadrant, crossing: true);
    expect(r.selection.isEmpty, isTrue, reason: 'no leaf touched');

    // Right of the press, then back left past it.
    final s = r.screen(Vector2(chair.maxX, chair.maxY));
    final e = r.screen(Vector2(chair.minX, chair.minY));
    r.down(s);
    r.move(s + const Offset(40, 10));
    final window = r.paint();
    expect(window.named('drawRect'), hasLength(2));
    expect(window.named('drawPath'), isEmpty);
    r.move(e);
    final crossing = r.paint();
    expect(crossing.named('drawRect'), hasLength(1));
    expect(crossing.named('drawPath'), hasLength(1));
    r.up(e);
    expect(r.selection.keys, {r.key('1')}, reason: 'taken by crossing');
  });

  testWidgets(
      'RB8 a zoom during a band: the corners are converted under the camera '
      'at the up (M-RB8)', (tester) async {
    final r = rig(tester);
    r.drag(FloorPlanFloorDrag.band);
    final target = padded(r.leafBox(['2']), 100);
    const f = Offset(200, 700);
    final fw = r.toWorld(f);
    // The world points that, after a 1.5x zoom about f, lie under the
    // band's corners: farther from f's world point by 1.5.
    Vector2 before(Vector2 w) => fw + (w - fw) * 1.5;
    final a = before(Vector2(target.minX, target.maxY));
    final b = before(Vector2(target.maxX, target.minY));
    final s0 = r.screen(a), s1 = r.screen(b);
    final mixed = boxOf([a, Vector2(target.maxX, target.minY)]);
    expect(
        encloses(mixed, Vector2(target.minX + 100, target.maxY - 100)), isFalse,
        reason: 'premise: the press\'s old world point misses 2');
    r.down(s0);
    r.move(Offset.lerp(s0, s1, 0.5)!);
    r.camera.value = ViewportTransform(
        worldToScreenMatrix: Transform2.translation(f.dx, f.dy)
            .multiply(Transform2.scale(1.5, 1.5))
            .multiply(Transform2.translation(-f.dx, -f.dy))
            .multiply(r.camera.value.worldToScreenMatrix));
    final w0 = r.toWorld(s0);
    expect(w0.x, closeTo(target.minX, 1e-6), reason: 'premise: the zoom');
    expect(w0.y, closeTo(target.maxY, 1e-6));
    r.move(s1);
    r.up(s1);
    expect(r.selection.keys, {r.key('2')});
  });

  testWidgets(
      'RB9 a window over the whole floor: the hidden table and the planter '
      'are not selected, the unnumbered one is (M-RB9)', (tester) async {
    final r = rig(tester);
    r.drag(FloorPlanFloorDrag.band);
    final all = padded(r.leafBox([for (var i = 1; i <= 11; i++) '$i']), 500);
    expect(
        encloses(
            all, r.node('planter').transform.transformPoint(Vector2(250, 250))),
        isTrue,
        reason: 'premise: the planter inside');
    r.band(all);
    expect(r.selection.keys, r.keys(['1', '2', '4', '5', '6', '7', '9', '10']));
    expect(r.selection.keys, isNot(contains(r.key('11'))));
    expect(r.selection.keys, isNot(contains(r.key('planter'))));
  });

  testWidgets(
      'RB10 locks and groups: a lone locked table is not taken; a window '
      'round a group with a locked member takes its unlocked one; crossing '
      'one member takes its group; a window with one member out takes none '
      '(M-RB10, M-RB10b, M-RB11, M-RB12, M-RB26)', (tester) async {
    final r = rig(tester);
    r.drag(FloorPlanFloorDrag.band);
    r.selection.replace([r.key('1')]);
    r.band(padded(r.leafBox(['3']), 100));
    expect(r.selection.isEmpty, isTrue, reason: 'locked: nothing');

    r.band(padded(r.leafBox(['7', '8']), 100));
    expect(r.selection.keys, {r.key('7')});

    // Over 5's upper chair only (local y 1000 to 1450).
    final chair = boxOf([r.world('5', 800, 1300), r.world('5', 1000, 1650)]);
    for (final n in ['4', '6']) {
      expect(overlaps(chair, r.leafBox([n])), isFalse,
          reason: 'premise: $n untouched');
    }
    r.band(chair, crossing: true);
    expect(r.selection.keys, r.keys(['4', '5', '6']));

    final two = padded(r.leafBox(['4', '5']), 100);
    expect(two.maxX, lessThan(r.leafBox(['6']).minX),
        reason: 'premise: 6 outside');
    r.band(two);
    expect(r.selection.isEmpty, isTrue);

    // A crossing takes a group only through an unlocked member (RB-3): over
    // the right edge of 8 (h's locked member) alone, off 7, it takes nothing
    // and a plain band replaces the selection with that empty set.
    r.selection.replace([r.key('1')]);
    final eight = r.leafBox(['8']);
    final edge = Aabb2.raw(
        eight.maxX - 200, eight.minY - 100, eight.maxX + 300, eight.maxY + 100);
    expect(overlaps(edge, eight), isTrue, reason: 'premise: touches 8');
    expect(overlaps(edge, r.leafBox(['7'])), isFalse,
        reason: 'premise: off 7\'s leaves');
    expect(r.node('8').layer, isNot(r.node('7').layer),
        reason: 'premise: 8 is on the locked layer, 7 not');
    r.band(edge, crossing: true);
    expect(r.selection.isEmpty, isTrue, reason: 'locked member alone: none');
  });

  testWidgets(
      'RB11 a plain band replaces; a Ctrl band adds and keeps a selected '
      'table inside (M-RB13)', (tester) async {
    final r = rig(tester);
    r.drag(FloorPlanFloorDrag.band);
    r.selection.replace([r.key('1')]);
    r.band(padded(r.leafBox(['2']), 100));
    expect(r.selection.keys, {r.key('2')});
    r.selection.replace([r.key('1')]);
    r.band(padded(r.leafBox(['1', '2']), 600), control: true);
    expect(r.selection.keys, r.keys(['1', '2']));
  });

  testWidgets(
      'RB12 a plain band over nothing clears; a Shift band over nothing keeps '
      '(R-2, M-RB14)', (tester) async {
    final r = rig(tester);
    r.drag(FloorPlanFloorDrag.band);
    const empty = Aabb2.raw(2000, 2000, 4000, 3500);
    r.selection.replace([r.key('1')]);
    r.band(empty, shift: true);
    expect(r.selection.keys, {r.key('1')});
    r.band(empty);
    expect(r.selection.isEmpty, isTrue);
  });

  testWidgets(
      'RB13 one notification for a band that changes the selection, none '
      'for one that does not; a band reports no tap, double tap, floor tap '
      'or hover (M-RB15, M-RB16, M-RB27)', (tester) async {
    final r = rig(tester);
    r.drag(FloorPlanFloorDrag.band);
    var notified = 0;
    r.selection.addListener(() => notified++);
    final both = padded(r.leafBox(['1', '2']), 600);
    r.band(both);
    expect(notified, 1);
    expect(r.selection.keys, r.keys(['1', '2']));
    r.band(both);
    expect(notified, 1, reason: 'the same keys: silent');
    expect(r.selection.keys, r.keys(['1', '2']));

    // A tap on 2, then a band from the floor beside it ending over it.
    final top = r.at('2', 900, 650);
    r.tap(top);
    expect(r.taps, ['2']);
    final start = top + const Offset(0, -200);
    expect(r.picker.pick(r.toWorld(start)), isNull, reason: 'premise');
    r.down(start);
    r.move(top);
    r.up(top);
    expect(r.taps, ['2'], reason: 'no tap');
    expect(r.doubleTaps, isEmpty);
    expect(r.floors, isEmpty);
    expect(r.hovers, isEmpty);
    // The rig's events are all stamped zero: were the first tap still
    // remembered, this one would complete a double tap (M-RB27).
    r.tap(top);
    expect(r.taps, ['2', '2']);
    expect(r.doubleTaps, isEmpty, reason: 'the band broke the tap chain');
  });

  testWidgets('RB13b a band, then at once a tap on a table: the tap acts',
      (tester) async {
    final r = rig(tester);
    r.drag(FloorPlanFloorDrag.band);
    r.band(padded(r.leafBox(['2']), 100));
    expect(r.selection.keys, {r.key('2')});
    r.tap(r.at('1', 900, 700));
    expect(r.selection.keys, {r.key('1')});
    expect(r.taps, ['1']);
  });

  testWidgets(
      'RB14 Escape ends a band whatever idleKeys says; every key is handled '
      'mid-band; cancel ends it; the next tap acts (M-RB17, M-RB17b)',
      (tester) async {
    final r = rig(tester);
    r.drag(FloorPlanFloorDrag.band);
    r.idleKeys = false;
    r.selection.replace([r.key('1')]);
    final box = padded(r.leafBox(['2']), 100);
    final s = r.screen(Vector2(box.minX, box.maxY));
    final e = r.screen(Vector2(box.maxX, box.minY));
    r.down(s);
    r.move(e);
    expect(r.tool.phase, ToolPhase.dragging);
    expect(r.tool.onKey(_z, r.ctx), KeyEventResult.handled);
    expect(r.tool.phase, ToolPhase.dragging, reason: 'a key ends nothing');
    expect(r.tool.onKey(_escape, r.ctx), KeyEventResult.handled);
    expect(r.tool.phase, ToolPhase.idle);
    expect(r.paint().calls, isEmpty);
    r.up(e);
    expect(r.selection.keys, {r.key('1')});

    r.down(s);
    r.move(e);
    r.tool.cancel(r.ctx);
    expect(r.tool.phase, ToolPhase.idle);
    r.up(e);
    expect(r.selection.keys, {r.key('1')});
    r.tap(r.at('2', 900, 650));
    expect(r.selection.keys, {r.key('2')});
    expect(r.taps, ['2']);
  });

  testWidgets(
      'RB15 the band painted at the screen rect: a window\'s fill and '
      'outline, a crossing\'s dashes; nothing when idle (M-RB18b)',
      (tester) async {
    final r = rig(tester);
    r.drag(FloorPlanFloorDrag.band);
    expect(r.paint().calls, isEmpty, reason: 'idle');
    const a = Offset(900, 120), b = Offset(1100, 300), c = Offset(800, 300);
    expect(r.picker.pick(r.toWorld(a)), isNull, reason: 'premise');
    r.down(a);
    expect(r.paint().calls, isEmpty, reason: 'a press is no band');
    r.move(b);
    final window = r.paint();
    expect(
        [for (final i in window.calls) i.memberName], [#drawRect, #drawRect]);
    final rect = Rect.fromPoints(a, b);
    final [fill, stroke] = window.calls;
    expect(fill.positionalArguments[0], rect);
    expect((fill.positionalArguments[1] as Paint).style, PaintingStyle.fill);
    expect(stroke.positionalArguments[0], rect);
    expect(
        (stroke.positionalArguments[1] as Paint).style, PaintingStyle.stroke);
    r.move(c);
    final crossing = r.paint();
    expect(
        [for (final i in crossing.calls) i.memberName], [#drawRect, #drawPath]);
    expect(crossing.calls.first.positionalArguments[0], Rect.fromPoints(a, c));
    r.up(c);
    expect(r.paint().calls, isEmpty, reason: 'idle again');
  });

  testWidgets(
      'RB15b the tool notifies as a band grows and when Escape ends it, so '
      'the overlay repaints (M-RB22, M-RB23)', (tester) async {
    final r = rig(tester);
    r.drag(FloorPlanFloorDrag.band);
    var n = 0;
    r.tool.addListener(() => n++);
    const a = Offset(900, 120), b = Offset(1100, 300), c = Offset(1150, 320);
    expect(r.picker.pick(r.toWorld(a)), isNull, reason: 'premise');
    r.down(a);
    r.move(b);
    expect(r.tool.phase, ToolPhase.dragging, reason: 'premise: banding');
    final started = n;
    expect(started, greaterThan(0), reason: 'the band starting repaints');
    r.move(c);
    expect(n, greaterThan(started), reason: 'a further move repaints');
    final grown = n;
    expect(r.paint().calls, isNotEmpty, reason: 'premise: a band is painted');
    expect(r.tool.onKey(_escape, r.ctx), KeyEventResult.handled);
    expect(r.tool.phase, ToolPhase.idle);
    expect(n, greaterThan(grown), reason: 'Escape repaints');
    expect(r.paint().calls, isEmpty);
  });
}
