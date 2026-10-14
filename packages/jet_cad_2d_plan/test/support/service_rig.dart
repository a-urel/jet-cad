// Drives a controller's service tool with explicit ToolPointerEvents (2b
// Task 14): the controller in service over a plan text, a y-up camera that
// is not the identity (0.1 px/mm, panned), and the host's callbacks logged
// through the session's ServiceHost. World points are the inputs; the
// expectations are the fixture's handles and labels.
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show PointerDeviceKind, kPrimaryButton;
import 'package:flutter/painting.dart' show Offset;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show PlanKit;
import 'package:jet_cad_2d_plan/src/controller/plan_controller.dart';
import 'package:jet_cad_2d_plan/src/service/service_session.dart';
import 'package:jet_cad_2d_plan/src/service/service_tool.dart';
import 'package:jet_cad_2d_plan/src/symbols/symbol_placer.dart'
    show definitionForEntry;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'harness.dart' show planText;
import 'service_fixture.dart' show addRow, testEntry;
import 'test_kit.dart';

// `parts` is Task 11's (`service_plans.dart`), re-exported for the tool
// and paint tests (one owner per helper, controller ruling R-19).
export 'service_plans.dart' show parts;

final class ServiceRig {
  /// [json] loaded over [kits] (`unitKit()` by default); [design] runs on
  /// the design before service is entered.
  ServiceRig(String json,
      {List<PlanKit>? kits, void Function(PlanController c)? design})
      : c = PlanController(kits: kits ?? [unitKit()], json: json) {
    design?.call(c);
    c.setMode(PlanMode.service);
    c.camera.value = ViewportTransform(
        worldToScreenMatrix: const Transform2(0.1, 0, 0, -0.1, 700, 450));
    session.host = ServiceHost(
        callbacks: () => callbacks,
        options: () => options,
        events: () => events);
  }

  final PlanController c;
  ServiceSession get session => c.serviceSession!;
  ServiceTool get tool => session.tool;
  ToolContext get ctx => session.toolContext;
  DraftDocument get doc => session.document;
  Set<SelectionKey> get keys => ctx.selection.keys;

  final List<String> taps = [];
  final List<String> doubleTaps = [];
  final List<String> groupTaps = [];
  final List<(String, Offset)> menus = [];
  final List<List<Handle>> moved = [];
  int layouts = 0;

  late final ServiceCallbacks callbacks = (
    onUnitTap: taps.add,
    onLayoutChanged: () => layouts++,
    onGroupTap: (id, label) => groupTaps.add('$id:$label'),
    onMergeRequested: null,
    onSplitRequested: null,
  );

  ServiceOptions options = kDefaultServiceOptions;

  late final ServiceEvents<Handle> events = (
    onUnitsMoved: moved.add,
    onUnitDoubleTap: doubleTaps.add,
    onFloorTap: null,
    onUnitHover: null,
  );

  /// [options] with a context menu that logs into [menus].
  void withMenu() => options = (
        longPress: options.longPress,
        onUnitContextMenu: (l, p) => menus.add((l, p)),
        floorDrag: options.floorDrag,
      );

  void dispose() => c.dispose();

  InstanceNode node(Handle h) => doc.tree[h]! as InstanceNode;

  SelectionKey key(Handle h) => SelectionKey.root(h);

  /// A world point inside unit [h]'s top: its top box's centre through its
  /// world transform (the fixture's tops are convex).
  Vector2 inside(Handle h) {
    final u = c.unitIndex[h]!;
    final t = u.top;
    return u.toWorld
        .transformPoint(Vector2((t.minX + t.maxX) / 2, (t.minY + t.maxY) / 2));
  }

  /// [h]'s symbol box through its world transform, axis-aligned.
  Aabb2 worldBox(Handle h) {
    final u = c.unitIndex[h]!;
    final b = u.box;
    return Aabb2.fromPoints([
      for (final (x, y) in [
        (b.minX, b.minY),
        (b.maxX, b.minY),
        (b.maxX, b.maxY),
        (b.minX, b.maxY)
      ])
        u.toWorld.transformPoint(Vector2(x, y)),
    ]);
  }

  Offset screen(Vector2 w) {
    final s = c.camera.value.worldToScreen(w);
    return Offset(s.x, s.y);
  }

  ToolPointerEvent ev(Vector2 world,
          {int buttons = kPrimaryButton,
          bool shift = false,
          Duration time = Duration.zero}) =>
      ToolPointerEvent(
        screen: screen(world),
        world: world.clone(),
        pointer: 1,
        buttons: buttons,
        shift: shift,
        control: false,
        meta: false,
        alt: false,
        pickRadiusWorld: 6 / c.camera.value.scale,
        kind: PointerDeviceKind.mouse,
        timeStamp: time,
      );

  void down(Vector2 w, {bool shift = false, Duration time = Duration.zero}) =>
      tool.onPointerDown(ev(w, shift: shift, time: time), ctx);
  void move(Vector2 w) => tool.onPointerMove(ev(w), ctx);
  void up(Vector2 w, {Duration time = Duration.zero}) =>
      tool.onPointerUp(ev(w, buttons: 0, time: time), ctx);

  void tap(Vector2 w, {bool shift = false, Duration time = Duration.zero}) {
    down(w, shift: shift, time: time);
    up(w, time: time + const Duration(milliseconds: 40));
  }

  /// A drag from [from] by [by], in two moves, past the touch slop.
  void drag(Vector2 from, Vector2 by) {
    down(from);
    move(from + by * 0.5);
    move(from + by);
    up(from + by);
  }

  /// A band over world [box] under `PlanFloorDrag.band`: a window from its
  /// upper left to its lower right, or a crossing from its upper right to
  /// its lower left. Its press is on the floor (the caller pads the box off
  /// every unit).
  void band(Aabb2 box, {bool crossing = false}) {
    options = (
      longPress: options.longPress,
      onUnitContextMenu: options.onUnitContextMenu,
      floorDrag: PlanFloorDrag.band,
    );
    final start = Vector2(crossing ? box.maxX : box.minX, box.maxY);
    final end = Vector2(crossing ? box.minX : box.maxX, box.minY);
    down(start);
    move(Vector2((start.x + end.x) / 2, (start.y + end.y) / 2));
    move(end);
    up(end);
  }
}

/// [a] grown by [pad] on every side.
Aabb2 padded(Aabb2 a, double pad) =>
    Aabb2.raw(a.minX - pad, a.minY - pad, a.maxX + pad, a.maxY + pad);

/// The union of [boxes].
Aabb2 unionOf(Iterable<Aabb2> boxes) => Aabb2.fromPoints([
      for (final b in boxes) ...[
        Vector2(b.minX, b.minY),
        Vector2(b.maxX, b.maxY)
      ]
    ]);

bool overlaps(Aabb2 a, Aabb2 b) =>
    a.minX <= b.maxX &&
    a.maxX >= b.minX &&
    a.minY <= b.maxY &&
    a.maxY >= b.minY;

/// 2b Review Focus 5: a hall of 25 rows of 20 seats (500 generated units),
/// rows 1.5 m apart from 40 m off the origin, the even rows turned 37
/// degrees, the odd ones curved 0.03 rad a seat; a plan text over
/// [unitKit], every seat generated by the row type (planText installs the
/// kit's system).
String hallJson() => planText([unitKit()], (d) {
      final seat = testEntry(rowSeatKey);
      final made = definitionForEntry(d, seat);
      d.commands.execute(CompoundCommand(made.commands, label: 'Seat'));
      for (var i = 0; i < 25; i++) {
        addRow(
            d,
            RowComponent(
                prefix: String.fromCharCode(0x41 + i),
                count: 20,
                spacing: 600,
                curve: i.isOdd ? 0.03 : 0,
                seat: made.definition,
                base: seat.definition.basePoint,
                top: entryTop(seat)),
            at: Vector2(40000, -27000 - 1500.0 * i),
            angle: i.isEven ? 37 * math.pi / 180 : 0);
      }
    });

/// A controller over [hallJson], in service. The caller disposes it.
PlanController hallController() {
  final c = PlanController(kits: [unitKit()], json: hallJson());
  c.setMode(PlanMode.service);
  return c;
}
