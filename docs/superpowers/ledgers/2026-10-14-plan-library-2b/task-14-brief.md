### Task 14: The service tool, the picker's use and the allocation invariants (spec S4 "The service tool", "A drag", "The unit picker"; S2 "Locked units", "Unlabelled, duplicate and bad labels"; Review Focus 4, 5)

**Files:**
- Create: `packages/jet_cad_2d_plan/lib/src/service/service_tool.dart` (port of `jet_cad_floor_plan/lib/src/service/table_select_tool.dart`: `ServiceTool`, `PlanLongPress`, `PlanFloorDrag`, the `ServiceCallbacks` / `ServiceOptions` / `ServiceEvents` records, `contextSelect`, `ServiceHost`)
- Modify: `packages/jet_cad_2d_plan/lib/src/service/service_session.dart` (Task 11's: the session builds the `ServiceTool`; `host`, `picker`; the idle placeholder goes)
- Modify: `packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart` (`_buildService` passes the controller's `unitGroups` and `serviceMove`)
- Modify: `.github/workflows/ci.yml` (`test_flags: --enable-vmservice` for `packages/jet_cad_2d_plan`), `tool/ci/test/scripts_test.dart` (SC20b)
- Test support: `packages/jet_cad_2d_plan/test/support/unit_fixtures.dart` (Tasks 6 and 8's; this task adds `numberedRowOfTables` and `copyForService`), `packages/jet_cad_2d_plan/test/support/service_rig.dart` (new), `packages/jet_cad_2d_plan/test/invariants/vm_allocation_meter.dart` (copied)
- Test (new): `packages/jet_cad_2d_plan/test/service/service_tool_units_test.dart` (ST-seat, ST-mixed-drag, ST-group-seat, ST-locked-seat, ST-unlabelled, ST-band-two-rows, ST-secondary, ST-move-gate)
- Test (ported): `test/service/service_tool_test.dart` (ST1 … ST17), `test/service/service_band_test.dart` (RB1 … RB15b), `test/service/service_events_test.dart` (SE1 … SE16), `test/invariants/pick_allocation_test.dart` (PA1 … PA3, and the new PA4, PA5), `test/invariants/band_allocation_test.dart` (RB16, and the new RB16-hall)

(Paths below are under `packages/jet_cad_2d_plan/` unless they start at the repository root. `floor_plan/` abbreviates `packages/jet_cad_floor_plan/`.)

**Interfaces:**
- Consumes:
  - Flutter layer: `Tool`, `ToolPhase`, `TouchPress`, `ToolContext` (`execute`, `selection`, `index`, `camera`), `ToolPointerEvent` (`isTouch`, `reachRadiusWorld`, `timeStamp`), `ToolController`, `SelectionController` (`keys`, `replace`, `toggle`, `clear`), `SelectionKey.root`, `SelectionBandPainter`, `BandMode`, `bandModeFor`, `kTouchHoldBack`, `SpatialIndex.forEachInstanceInBand`, `QueryFilter.snapping`, `PaperPalette` (`jet_cad_2d_flutter/lib/src/tool.dart:82-157`).
  - Engine: `TransformNodeCommand`, `CompoundCommand`, `InstanceNode`, `Transform2.translation`, `Aabb2.raw`.
  - Task 6 (`lib/src/units/unit_index.dart`): `UnitInfo` (`instance`, `owner`, `text`, `locked`, `generated`, `toWorld`, `top`, `box`), `UnitIndex` (`operator []`, `units`, `withLabel`), `UnitIndexCache` (`current`).
  - Task 8 (`lib/src/service/unit_picker.dart`): `class UnitPicker` — `UnitPicker(DraftDocument document, UnitIndexCache units, {bool skipLocked = false, bool placedOnly = false, @visibleForTesting leavesByOwner, @visibleForTesting invert})`, `units`, `List<PickCandidate> get candidates`, `UnitInfo? pick(Vector2 world, {double reach = 0})`, `static const Tolerance tolerance`; `PickCandidate` (`unit`, `inverse`, `top`, `box`, `locked`, `scale`); `CircleTop`, `PolygonTop` (`UnitTop.contains`). Test support (`test/support/unit_fixtures.dart`): `fxKit`, `unitPlan`, `placeAt`, `placeTurned`, `addLayer`, `addUnitLabel`, `unitsOf`, `entryOf`, `tableUnit`, `tableSymbol`, `trapezoidTable`, `stoolSymbol`, `planterSymbol`, `kDeg37`, `rowOfTables`, `Tally`, `CountingTransform`.
  - Task 11 (`lib/src/service/service_session.dart`): `PlanMode`, `serviceCopyOf(design, {register, measurer})`, `ServiceSession` (`document`, `index`, `selection`, `units`, `toolContext`, `tools`, `tool`, `dispose`), `PlanController.serviceSession`, `setMode`, `_buildService` (its Step 6).
  - Task 12 (`lib/src/service/service_state.dart`): `UnitGroup`, `validateUnitGroups`, `GroupUnit({handle, label, visible, locked, generated})`, `UnitGroupLookup` (`visibleMembers`, `selectableMembers`, `hasLockedVisibleMember`, `hasGeneratedVisibleMember`); `PlanController.unitGroups`, `setUnitGroups`; Task 11's `selectedUnits`.
  - Task 8: `PlanPermissions.serviceMove`, `copyWith(serviceMove:)`.
  - Task 9: `@internal UnitIndex get unitIndex` on `PlanController` (the active document's since Task 11).
  - Task 5: `unitKit()`, `RowComponent`, `rowSeatKey`, `entryTop` (`test/support/test_kit.dart`); `serviceFixture()` (`json`, `table`, `seatsA`: six, `A1` … `A6`; `seatsB`: five, `B1` … `B5`), `testEntry`, `addRow`, `unitLabelsOf` (`test/support/service_fixture.dart`); 2a's `planText` (`test/support/harness.dart:112-122`).
- Produces (`lib/src/service/service_tool.dart`; the barrel exports are Task 16's):
  - `enum PlanLongPress { toggleSelection, contextMenu }`, `enum PlanFloorDrag { pan, band }` (Shared interfaces).
  - `typedef ServiceCallbacks = ({void Function(String label)? onUnitTap, void Function()? onLayoutChanged, void Function(String groupId, String label)? onGroupTap, void Function(Set<String> labels)? onMergeRequested, void Function(String groupId)? onSplitRequested});`, `const ServiceCallbacks kNoServiceCallbacks`.
  - `typedef ServiceOptions = ({PlanLongPress longPress, void Function(String label, Offset globalPosition)? onUnitContextMenu, PlanFloorDrag floorDrag});`, `const ServiceOptions kDefaultServiceOptions`. No `serviceMove` in it: the tool reads the permission through `moves`, as Task 16 assumes.
  - `typedef ServiceEvents<M> = ({void Function(List<M> moved)? onUnitsMoved, void Function(String label)? onUnitDoubleTap, void Function(Offset world)? onFloorTap, void Function(String? label)? onUnitHover});`, `const kNoServiceEvents`.
  - `final class ServiceHost` — `const ServiceHost({ServiceCallbacks Function() callbacks, ServiceOptions Function() options, bool Function() userCamera, Offset Function(Offset local) toGlobal, ServiceEvents<Handle> Function() events, bool Function() idleKeys})`, each defaulting to today's behaviour; `static const ServiceHost none` (Task 16's `ServiceHost`, its "Interface problem" 1).
  - `String? contextSelect(UnitInfo hit, SelectionController selection, {Set<SelectionKey>? group})`.
  - `class ServiceTool extends Tool` — `ServiceTool({required UnitPicker picker, required ValueListenable<Map<String, UnitGroup>> groups, required ServiceCallbacks Function() callbacks, ServiceOptions Function() options, bool Function() moves, bool Function() userCamera, Offset Function(Offset local) toGlobal, ServiceEvents<Handle> Function() events, bool Function() idleKeys})`; `final UnitPicker picker`; `Set<SelectionKey>? groupKeysOf(UnitInfo hit)`; `void secondaryClick(Vector2 world, Offset globalPosition, SelectionController selection)`.
  - On `ServiceSession` (`@internal`): `late final UnitPicker picker` (service: a locked unit and a seat are picked), `ServiceHost host` (settable; `ServiceHost.none` by default; Task 16's view sets it while its canvas is mounted), `late final ServiceTool tool` (the tool controller's one tool). Its constructor gains `ValueListenable<Map<String, UnitGroup>>? groups` and `bool Function()? moves`, and Task 11's `_IdleTool` is deleted (Task 11 made no `tool:` factory, controller ruling R-17).

Plan decision (**the picker is Task 8's**): Task 8 creates `service/unit_picker.dart` (controller ruling R-12: the constructor takes the document, `candidates` and the test seams exist, the class is not `final`). This task uses it in service as today's selection mode does: `UnitPicker(copy, units)`, `skipLocked` and `placedOnly` false (a locked unit is picked and never selected; a seat is picked and selected, spec S2, S4).

Plan decision (**the session's host**): today's `ServiceView` built the tool with the view's closures (`floor_plan/lib/src/host/service_view.dart:133-142`). In 2b the session owns the tool controller (Task 11), so the tool reads `session.host`, a `ServiceHost` of read-at-each-call functions that Task 16's `PlanServiceView` sets while its canvas is mounted and puts back to `ServiceHost.none` when it goes (Task 16's design, adopted as written). The session builds the tool itself, so `ServiceSession.tool` is a `ServiceTool`, as Task 16 reads it; Task 11's idle placeholder is removed (controller ruling R-17).

Plan decision (**moves are a permission**, spec S4 "Permissions"): today's view option `serviceMoves` (`T:229`, `:270`, `T` the source tool file) is `PlanPermissions.serviceMove`; the tool reads it through `moves` at each press, and `ServiceOptions` loses the field. The controller passes `moves: () => permissions.serviceMove`.

Plan decision (**a drag with seats**, spec S4 "A drag"): the moving set is every selected root key whose unit is **placed** (`UnitInfo.generated` false), plus the selectable members of every group one of them belongs to. A selected seat stays where it is. The drag is spent, the selection untouched (today's rule for a group with a locked member, `T:310-344`), when a group involved has a locked or a generated visible member (Task 12's `hasGeneratedVisibleMember`), or when the moving set is empty (a drag from an unselected seat, or from a seat selected with no placed unit). Known limit, not a defect: the engine strokes a move preview for every selected key the grip cache does not call immovable (`jet_cad_2d_flutter/lib/src/selection_overlay.dart:240-248`), and the copy's `ToolContext` has no grip cache (as today's), so a selected seat's preview outline follows a mixed drag; the seat itself stays.

Plan decision (**the band and the group lookup read the picker's candidates**, as today, `T:399-401`, `:545-557`): the units the picker can hit (zone spec Z0), placed and generated, a locked one listed. A band's key for a seat is `SelectionKey.root(seat)` (spec S4); `forEachInstanceInBand` walks the flattened instance list, seats included (spec Facts, `spatial_index.dart:445-488`).

Plan decision (**the secondary click's rule moves into the tool**): today's selection-and-report rule for a secondary click lived in the view (`service_view.dart:212-227`); it is `ServiceTool.secondaryClick` here, pinned by ST-secondary, and Task 16's view keeps only the pointer checks (`service_view.dart:194-210`, `:229-231`).

Plan decision (**the view-level tests go to Task 16**): `floor_plan/test/service/service_options_test.dart`, `test/host/band_view_test.dart`, `test/host/table_groups_gesture_test.dart` and `test/host/table_groups_context_test.dart` pump `FloorPlanView` in the selection mode and drive real pointers through `ServiceView`'s listeners (`service_options_test.dart:96`, `band_view_test.dart:152`, `table_groups_gesture_test.dart:118-120`, `table_groups_context_test.dart:27-29`). `PlanServiceView` is Task 16's, so they can only run there. Controller ruling R-15 moves them to Task 16 (its Step B2b), assertions unchanged. This task ports the tool-level tests: `table_select_tool_test`, `table_band_test`, `service_events_test` and the two allocation tests.

Plan decision (**the profiler in CI**): the allocation tests read the VM's allocation profiler, which `flutter test` serves only with `--enable-vmservice`; without it they skip, and CI's standing comparison reads a skip as red (`floor_plan/test/invariants/pick_allocation_test.dart:8-11`). The `jet_cad_2d_plan` entry of `.github/workflows/ci.yml` (`:45-46`) gains the planner's flag (`:47-53`), pinned by SC20b beside SC20 (`tool/ci/test/scripts_test.dart:411-430`).

- [ ] **Step 1: The fixtures.**
  1. `test/support/unit_fixtures.dart` (Task 6 created it, Task 8 appended to it; controller ruling R-19). Append:

```dart
/// [rowOfTables] numbered as today's placer numbered them: `1` … `n` in
/// placement order (`floor_plan/test/service/table_status_painter_test.dart:
/// 59-79` placed them through the numbering placer).
DraftDocument numberedRowOfTables(int n) {
  final doc = rowOfTables(n);
  final instances = [
    for (final node in doc.tree.nodes)
      if (node is InstanceNode) node.handle
  ]..sort((a, b) => a.value.compareTo(b.value));
  for (final (i, h) in instances.indexed) {
    addUnitLabel(doc, h, '${i + 1}');
  }
  return doc;
}

/// [design] decoded as a service copy (Task 11's `serviceCopyOf`, today's
/// `_copyOf`): runtime permissions, the plan's components, the handles the
/// design's.
DraftDocument copyForService(DraftDocument design) => serviceCopyOf(design,
    register: (r) => registerPlanComponents(r, ParametricCatalog()),
    measurer: const InsertionPointMeasurer());
```

     with the import `package:jet_cad_2d_plan/src/service/service_session.dart show serviceCopyOf` (the file already imports `harness.dart` whole, Task 6).
  2. `test/invariants/vm_allocation_meter.dart`: copy `floor_plan/test/invariants/vm_allocation_meter.dart:1-243` unchanged but for a first header line, `// Copied from jet_cad_floor_plan/test/invariants/vm_allocation_meter.dart (itself the engine's).`
  3. `test/support/service_rig.dart` (new):

```dart
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
      for (final b in boxes) ...[Vector2(b.minX, b.minY), Vector2(b.maxX, b.maxY)]
    ]);

bool overlaps(Aabb2 a, Aabb2 b) =>
    a.minX <= b.maxX && a.maxX >= b.minX && a.minY <= b.maxY && a.maxY >= b.minY;

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
```

- [ ] **Step 2: The failing tests.** Create `test/service/service_tool_units_test.dart`:

```dart
// 2b spec S4 "The service tool", "A drag"; S2 "Locked units", "Unlabelled,
// duplicate and bad labels"; Review Focus 4: the service tool over placed
// and generated units, on the controller's service copy. The fixture is
// Task 5's serviceFixture(): a table a quarter turn and mirrored off the
// origin, row A (six seats) turned, row B (five seats) curved, all off the
// origin.
import 'package:flutter/painting.dart' show Offset;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show PlanKit, kUnitLabelTag;
import 'package:jet_cad_2d_plan/src/controller/plan_controller.dart';
import 'package:jet_cad_2d_plan/src/service/service_state.dart'
    show UnitGroup;
import 'package:jet_cad_2d_plan/src/service/service_tool.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/service_fixture.dart';
import '../support/service_rig.dart';

/// [json] in service over `unitKit()`, or over no kit ([missingKit]: the
/// table and both rows are then held by the lock set).
ServiceRig rig(String json,
    {bool missingKit = false, void Function(PlanController c)? design}) {
  final r = ServiceRig(json,
      kits: missingKit ? const <PlanKit>[] : null, design: design);
  addTearDown(r.dispose);
  return r;
}

void main() {
  testWidgets(
      'ST-seat a seat is picked, selected alone and reported by its label; '
      'a seat in a group selects the group and reports it (M-ST-seat)',
      (tester) async {
    final f = serviceFixture();
    final r = rig(f.json);
    final a3 = f.seatsA[2], b2 = f.seatsB[1], b3 = f.seatsB[2];
    expect(r.c.unitIndex[a3]!.generated, isTrue, reason: 'premise: a seat');
    r.c.setUnitGroups({
      'g': UnitGroup(members: {'B2', 'B3'})
    });

    r.tap(r.inside(a3));
    expect(r.keys, {r.key(a3)});
    expect(r.taps, ['A3']);
    expect(r.c.selectedUnits.value, {'A3'});

    r.tap(r.inside(b2), time: const Duration(seconds: 1));
    expect(r.keys, {r.key(b2), r.key(b3)});
    expect(r.taps, ['A3', 'B2']);
    expect(r.groupTaps, ['g:B2']);
  });

  testWidgets(
      'ST-mixed-drag a drag from the table with two seats selected moves the '
      'table alone, translation only, one step; the seats stay '
      '(M-ST-mixed)', (tester) async {
    final f = serviceFixture();
    final r = rig(f.json);
    final t = f.table, a1 = f.seatsA[0], a2 = f.seatsA[1];
    r.tap(r.inside(t));
    r.tap(r.inside(a1), shift: true);
    r.tap(r.inside(a2), shift: true);
    expect(r.keys, {r.key(t), r.key(a1), r.key(a2)}, reason: 'premise');
    final table0 = parts(r.node(t).transform);
    final seats0 = [parts(r.node(a1).transform), parts(r.node(a2).transform)];
    final from = r.inside(t);
    final by = Vector2(600, -300);
    final dx = (from.x + by.x) - from.x, dy = (from.y + by.y) - from.y;

    r.drag(from, by);
    expect(parts(r.node(t).transform),
        [...table0.take(4), table0[4] + dx, table0[5] + dy]);
    expect(parts(r.node(a1).transform), seats0[0]);
    expect(parts(r.node(a2).transform), seats0[1]);
    expect(r.layouts, 1);
    expect(r.moved, [
      [t]
    ]);
    expect(r.keys, {r.key(t), r.key(a1), r.key(a2)},
        reason: 'the selection is kept');
  });

  testWidgets(
      'ST-group-seat a group mixing the table and a seat is never dragged: '
      'the drag is spent, nothing moves, the selection is kept '
      '(M-ST-group)', (tester) async {
    final f = serviceFixture();
    final r = rig(f.json);
    final t = f.table, a1 = f.seatsA[0];
    final label = r.c.unitIndex[t]!.text!;
    r.c.setUnitGroups({
      'g': UnitGroup(members: {label, 'A1'})
    });
    r.tap(r.inside(t));
    expect(r.keys, {r.key(t), r.key(a1)}, reason: 'premise: the group');
    final table0 = parts(r.node(t).transform);

    r.drag(r.inside(t), Vector2(600, -300));
    expect(parts(r.node(t).transform), table0);
    expect(r.layouts, 0);
    expect(r.moved, isEmpty);
    expect(r.keys, {r.key(t), r.key(a1)});
  });

  testWidgets(
      'ST-locked-seat Review Focus 4: the kit missing, a seat is tapped and '
      'reported with its group, never selected by a tap, a long press, a '
      'band or a context click, never dragged (M-ST-locked)', (tester) async {
    final f = serviceFixture();
    final r = rig(f.json, missingKit: true);
    final a2 = f.seatsA[1];
    expect(r.c.unitIndex[a2]!.locked, isTrue, reason: 'premise: locked');
    expect(r.c.unitIndex[a2]!.generated, isTrue, reason: 'premise: a seat');
    r.c.setUnitGroups({
      'g': UnitGroup(members: {'A2', 'A3'})
    });

    r.tap(r.inside(a2));
    expect(r.taps, ['A2']);
    expect(r.groupTaps, ['g:A2']);
    expect(r.keys, isEmpty, reason: 'a tap selects nothing');

    // Under toggle a locked press starts no timer (T:236-243): held past
    // the long press, it is a tap.
    r.down(r.inside(a2), time: const Duration(seconds: 2));
    await tester.pump(const Duration(seconds: 1));
    r.up(r.inside(a2), time: const Duration(seconds: 3));
    expect(r.keys, isEmpty, reason: 'a long press selects nothing');

    r.band(padded(unionOf([for (final s in f.seatsA) r.worldBox(s)]), 400),
        crossing: true);
    expect(r.keys, isEmpty, reason: 'a band selects nothing');

    r.withMenu();
    r.tool.secondaryClick(r.inside(a2), const Offset(12, 34), r.ctx.selection);
    expect(r.menus, [('A2', const Offset(12, 34))]);
    expect(r.keys, isEmpty, reason: 'a context click selects nothing');

    r.options = kDefaultServiceOptions;
    final seat0 = parts(r.node(a2).transform);
    r.drag(r.inside(a2), Vector2(600, -300));
    expect(parts(r.node(a2).transform), seat0);
    expect(r.layouts, 0);
    expect(r.moved, isEmpty);
  });

  testWidgets(
      'ST-unlabelled an unlabelled table is selected by a tap and dragged, '
      'reported by onUnitsMoved, never by a label-keyed callback '
      '(M-ST-unlabelled)', (tester) async {
    final f = serviceFixture();
    final r = rig(f.json, design: (c) {
      for (final (label, _) in unitLabelsOf(c.document, f.table)) {
        expect(c.execute(SetEntityTextCommand(label, '', kUnitLabelTag)),
            isTrue);
      }
    });
    final t = f.table;
    expect(r.c.unitIndex[t]!.text, isNull, reason: 'premise: unlabelled');

    r.tap(r.inside(t));
    r.tap(r.inside(t), time: const Duration(milliseconds: 100));
    expect(r.keys, {r.key(t)});
    expect(r.taps, isEmpty);
    expect(r.doubleTaps, isEmpty);

    r.drag(r.inside(t), Vector2(600, -300));
    expect(r.layouts, 1);
    expect(r.moved, [
      [t]
    ]);
  });

  testWidgets(
      'ST-band-two-rows a crossing band over both rows takes every seat of '
      'both as a root key and not the table; a window round row B takes row '
      'B\'s seats alone (M-ST-band)', (tester) async {
    final f = serviceFixture();
    final r = rig(f.json);
    final rows = unionOf([
      for (final s in [...f.seatsA, ...f.seatsB]) r.worldBox(s)
    ]);
    final rowB = unionOf([for (final s in f.seatsB) r.worldBox(s)]);
    expect(overlaps(padded(rows, 50), r.worldBox(f.table)), isFalse,
        reason: 'premise: the table lies off both rows');
    for (final s in f.seatsA) {
      expect(overlaps(padded(rowB, 50), r.worldBox(s)), isFalse,
          reason: 'premise: row A lies off row B\'s window');
    }

    r.band(padded(rows, 50), crossing: true);
    expect(r.keys, {
      for (final s in [...f.seatsA, ...f.seatsB]) r.key(s)
    });

    r.band(padded(rowB, 50));
    expect(r.keys, {for (final s in f.seatsB) r.key(s)});
  });

  testWidgets(
      'ST-secondary a context click on an unselected seat selects it alone '
      'and reports its label; on a selected unit it keeps the selection; '
      'with no menu it does nothing (M-ST-secondary)', (tester) async {
    final f = serviceFixture();
    final r = rig(f.json);
    final a1 = f.seatsA[0], t = f.table;
    r.withMenu();
    r.tool.secondaryClick(r.inside(a1), const Offset(5, 6), r.ctx.selection);
    expect(r.keys, {r.key(a1)});
    expect(r.menus, [('A1', const Offset(5, 6))]);

    r.tap(r.inside(t), shift: true);
    final label = r.c.unitIndex[t]!.text!;
    r.tool.secondaryClick(r.inside(t), const Offset(7, 8), r.ctx.selection);
    expect(r.keys, {r.key(a1), r.key(t)}, reason: 'a selected unit keeps it');
    expect(r.menus.last, (label, const Offset(7, 8)));

    r.options = kDefaultServiceOptions;
    r.ctx.selection.clear();
    r.tool.secondaryClick(r.inside(a1), const Offset(5, 6), r.ctx.selection);
    expect(r.keys, isEmpty, reason: 'no menu: nothing');
    expect(r.menus, hasLength(2));
  });

  testWidgets(
      'ST-move-gate serviceMove false: a drag from the table pans, the '
      'table stays; the permission is read at each press (M-ST-gate)',
      (tester) async {
    final f = serviceFixture();
    final r = rig(f.json);
    final t = f.table;
    final table0 = parts(r.node(t).transform);
    r.c.permissions = r.c.permissions.copyWith(serviceMove: false);
    final camera0 = parts(r.c.camera.value.worldToScreenMatrix);

    r.drag(r.inside(t), Vector2(600, -300));
    expect(parts(r.node(t).transform), table0);
    expect(r.layouts, 0);
    expect(parts(r.c.camera.value.worldToScreenMatrix), isNot(camera0),
        reason: 'the drag panned');

    r.c.permissions = r.c.permissions.copyWith(serviceMove: true);
    r.drag(r.inside(t), Vector2(600, -300));
    expect(r.layouts, 1, reason: 'read again at the next press');
  });
}
```

- [ ] **Step 3: Run them, expecting failure.** Run: `cd packages/jet_cad_2d_plan && flutter test test/service/service_tool_units_test.dart`. Expected: a compile error naming `package:jet_cad_2d_plan/src/service/service_tool.dart` (not found).

- [ ] **Step 4: The tool.** Create `lib/src/service/service_tool.dart` as `floor_plan/lib/src/service/table_select_tool.dart:1-693` copied with exactly these adaptations (a method not named keeps its body; `T:` is the source file):
  1. Header (`T:1-5`):

```dart
// The service mode's tool (2b spec S4 "The service tool", "A drag"):
// today's TableSelectTool (jet_cad_floor_plan/lib/src/service/
// table_select_tool.dart; spec 14c S3, S4, S8, R-1, R-5 to R-7, rubber-band
// RB-2 to RB-5, table-groups G4) over units, placed and generated. A tap
// selects a unit, a long press adds or removes one, a drag moves the
// selected placed units (a seat stays), a floor drag pans or bands, and a
// unit in a group acts with its whole group. It writes the copy's engine
// selection with SelectionKey.root(unit), for a seat too. A locked unit
// (isLockedUnit) is tapped and grouped, never selected or dragged.
```

  2. Imports (`T:24-26`): `'../host/floor_plan_types.dart'`, `'table_groups.dart'`, `'table_picker.dart'` become `'../units/unit_index.dart' show UnitInfo;`, `'service_state.dart' show GroupUnit, UnitGroup, UnitGroupLookup;`, `'unit_picker.dart' show PickCandidate, UnitPicker;`.
  3. After the imports, the enums (their docs from `floor_plan/lib/src/host/floor_plan_types.dart:168-200`, renamed):

```dart
/// What a long press on a unit does in service (today's FloorPlanLongPress).
enum PlanLongPress {
  /// Adds the unit to the selection or removes it (a group whole).
  toggleSelection,

  /// Reports the unit to `onUnitContextMenu`, as a secondary click does.
  contextMenu,
}

/// What a drag on the floor does in service (today's FloorPlanFloorDrag).
enum PlanFloorDrag {
  /// The camera pans; Shift, Ctrl or Cmd with a mouse or stylus bands.
  pan,

  /// A band selects: left to right the units wholly inside, right to left
  /// those it touches. The camera pans with two fingers, a trackpad's
  /// scroll or the middle button.
  band,
}
```

  4. The records and their defaults (`T:28-81`) become:

```dart
/// What the tool and the service bar tell their host, read at each call
/// (R-5). [onMergeRequested] and [onSplitRequested] are the service bar's.
typedef ServiceCallbacks = ({
  void Function(String label)? onUnitTap,
  void Function()? onLayoutChanged,
  void Function(String groupId, String label)? onGroupTap,
  void Function(Set<String> labels)? onMergeRequested,
  void Function(String groupId)? onSplitRequested,
});

/// No callback.
const ServiceCallbacks kNoServiceCallbacks = (
  onUnitTap: null,
  onLayoutChanged: null,
  onGroupTap: null,
  onMergeRequested: null,
  onSplitRequested: null,
);

/// The view's options for the tool, read at each press;
/// [onUnitContextMenu] takes a global position. Moves are the permission
/// `serviceMove` (spec S4), read through the tool's `moves`.
typedef ServiceOptions = ({
  PlanLongPress longPress,
  void Function(String label, Offset globalPosition)? onUnitContextMenu,
  PlanFloorDrag floorDrag,
});

/// Today's behaviour: a long press toggles, no menu, a floor drag pans.
const ServiceOptions kDefaultServiceOptions = (
  longPress: PlanLongPress.toggleSelection,
  onUnitContextMenu: null,
  floorDrag: PlanFloorDrag.pan,
);

/// The view events, read at each call (R-5). [M] is what a drag reports as
/// moved: the live instances at the tool, the controller's fresh details at
/// the view (Task 16).
typedef ServiceEvents<M> = ({
  void Function(List<M> moved)? onUnitsMoved,
  void Function(String label)? onUnitDoubleTap,
  void Function(Offset world)? onFloorTap,
  void Function(String? label)? onUnitHover,
});

/// No view event. Its fields are `Null`, so it is a [ServiceEvents] whatever
/// its type argument.
const kNoServiceEvents = (
  onUnitsMoved: null,
  onUnitDoubleTap: null,
  onFloorTap: null,
  onUnitHover: null,
);

ServiceCallbacks _noCallbacks() => kNoServiceCallbacks;
ServiceOptions _defaultOptions() => kDefaultServiceOptions;
ServiceEvents<Handle> _noEvents() => kNoServiceEvents;
Offset _sameOffset(Offset local) => local;
bool _always() => true;

/// What a service session's tool reads from the view that shows the
/// session, at each call (2b; today's ServiceView closures,
/// service_view.dart:133-142). The view sets one on `ServiceSession.host`
/// while its canvas is mounted; [none] is today's behaviour with no view.
final class ServiceHost {
  const ServiceHost({
    this.callbacks = _noCallbacks,
    this.options = _defaultOptions,
    this.userCamera = _always,
    this.toGlobal = _sameOffset,
    this.events = _noEvents,
    this.idleKeys = _always,
  });

  /// No view: no callback, today's options, a free camera, the local
  /// offset, the keys bound.
  static const ServiceHost none = ServiceHost();

  final ServiceCallbacks Function() callbacks;
  final ServiceOptions Function() options;

  /// Whether a drag on the floor pans (host embedding API spec G-3).
  final bool Function() userCamera;

  /// The layer's local point as a global one, for a context menu.
  final Offset Function(Offset local) toGlobal;

  /// Read at each button-less move: a view hands back a record it keeps.
  final ServiceEvents<Handle> Function() events;

  /// Whether the tool's idle Escape acts (spec C-7, S-16).
  final bool Function() idleKeys;
}
```

     `T:78-81`'s private defaults are those above.
  5. `contextSelect` (`T:83-96`):

```dart
/// A context gesture's selection (spec 14d S6): an unselected, unlocked
/// unit becomes the selection alone -- or, a member of a group, its
/// [group]'s selectable members -- a selected one keeps the selection, a
/// locked one changes nothing. Returns the unit's label, which the host is
/// told when it is not null.
String? contextSelect(UnitInfo hit, SelectionController selection,
    {Set<SelectionKey>? group}) {
  if (!hit.locked) {
    final key = SelectionKey.root(hit.instance);
    if (!selection.keys.contains(key)) selection.replace(group ?? [key]);
  }
  return hit.text;
}
```

  6. The class head (`T:100-138`): `TableSelectTool` → `ServiceTool`; the constructor gains `this.moves = _always,` after `this.options = _defaultOptions,`; the fields become `final UnitPicker picker;` and `final ValueListenable<Map<String, UnitGroup>> groups;` (doc: "The host's unit groups, as `PlanController.unitGroups` holds them: validated, ids trimmed."), plus

```dart
  /// Whether a drag on a unit moves it (spec S4: `PlanPermissions
  /// .serviceMove`, today's view option `serviceMoves`), read at each press:
  /// false makes it a pan, as on the floor.
  final bool Function() moves;
```

     The field `bool _pans = true;` (`T:141`) gains a sibling `bool _moves = true;` ([moves] as the press read it).
  7. The gesture state (`T:161`): `PickCandidate? _hit;` → `UnitInfo? _hit;`. The lookup state (`T:181-189`) becomes:

```dart
  /// The picker's candidates by instance (Z0: the units the picker can
  /// hit, a locked one listed), rebuilt when the picker's list is a new one
  /// (it is rebuilt only when the unit index is); never per pointer event.
  Map<Handle, UnitInfo> _byHandle = const {};
  List<PickCandidate>? _byHandleFor;

  /// The groups resolved against the picker's candidates, and each visible
  /// member's group by handle (G4). Rebuilt when the candidates list or the
  /// groups map is replaced, so a `setUnitGroups` alone refreshes it.
  UnitGroupLookup? _lookup;
  Map<Handle, String> _groupByHandle = const {};
  List<PickCandidate>? _lookupCandidates;
  Map<String, UnitGroup>? _lookupGroups;
```

  8. `name` (`T:192`): `'Tables'` → `'Units'`.
  9. `onPointerDown` (`T:215-245`): after `_pans = userCamera();` add `_moves = moves();`; `FloorPlanLongPress.contextMenu` → `PlanLongPress.contextMenu`. `onPointerMove` (`T:270`): `if (hit == null || !_options.serviceMoves) {` → `if (hit == null || !_moves) {`. `_startsBand` (`T:305`): `FloorPlanFloorDrag.band` → `PlanFloorDrag.band`.
  10. `_startDrag` (`T:310-344`):

```dart
  /// The drag's start (S4, G4; 2b S4 "A drag"): an unselected unit, or its
  /// whole group, replaces the selection; what moves is every selected
  /// placed unit, each group having a member among them taken whole. A
  /// selected seat stays where it is. False, with the selection untouched,
  /// when such a group has a locked or a generated visible member, or when
  /// no placed unit would move: the drag is then spent.
  bool _startDrag(UnitInfo hit, ToolContext ctx) {
    final key = SelectionKey.root(hit.instance);
    // With no group every unit stands alone, as before groups (G7).
    final lookup = _groupLookup();
    final groupOf = lookup == null ? const <Handle, String>{} : _groupByHandle;
    final hitGroup = groupOf[hit.instance];
    final replace = !ctx.selection.keys.contains(key);
    final selected = !replace
        ? ctx.selection.keys
        : hitGroup == null
            ? {key}
            : _memberKeys(lookup!, hitGroup);
    final index = picker.units.current;
    final roots = [
      for (final k in selected)
        if (k.chain.isEmpty && !(index[k.target]?.generated ?? false))
          k.target
    ];
    final involved = <String>{
      for (final h in roots)
        if (groupOf[h] case final id?) id
    };
    if (roots.isEmpty ||
        involved.any((id) =>
            lookup!.hasLockedVisibleMember(id) ||
            lookup.hasGeneratedVisibleMember(id))) {
      return false;
    }
    if (replace) ctx.selection.replace(selected);
    _moving = _sorted({
      ...roots,
      for (final id in involved)
        for (final t in lookup!.selectableMembers(id)) t.handle,
    });
    _gesture = _Gesture.dragging;
    return true;
  }
```

  11. `_bandKeys` (`T:395-432`): the head becomes the code below; from `final lookup = _groupLookup();` (`T:407`) on the body is unchanged but `!locked[h]!` (`T:414`) → `!byHandle[h]!.locked`.

```dart
  /// The band's keys (RB-3), ascending by handle: a seat's a root key too
  /// (2b S4). `snapping`, not `picking`: a locked layer's unit reaches the
  /// window's group rule (review V-1); a locked unit is never a key.
  List<SelectionKey> _bandKeys(Aabb2 world, BandMode mode, ToolContext ctx) {
    final byHandle = _units();
    final passing = <Handle>{};
    ctx.index.forEachInstanceInBand(world, mode, const QueryFilter.snapping(),
        (h) {
      if (byHandle.containsKey(h)) passing.add(h);
    });
```

  12. `_hover` (`T:434-444`): `events().onTableHover` → `events().onUnitHover`; `picker.pick(e.world)?.table.number` → `picker.pick(e.world)?.text`; the local `number` → `label`; its doc's "unnumbered table" → "unlabelled unit".
  13. `_tap` (`T:446-496`): `hit.table.instance` → `hit.instance` (each place); from `T:480` to the end:

```dart
    final label = hit.text;
    if (label == null) {
      _lastTap = null;
      return;
    }
    final doubleTap = !_toggle && _completesDoubleTap(hit.instance);
    _lastTap = _toggle || doubleTap
        ? null
        : (instance: hit.instance, time: _pressTime, screen: _pressScreen);
    callbacks().onUnitTap?.call(label);
    if (group != null) callbacks().onGroupTap?.call(group, label);
    if (doubleTap) events().onUnitDoubleTap?.call(label);
  }
```

     Doc words "table" → "unit", "number" → "label", "numbered" → "labelled".
  14. `groupKeysOf` (`T:509-515`): `PickCandidate hit` → `UnitInfo hit`, `hit.table.instance` → `hit.instance`. `_memberKeys` and `_addOrRemoveGroup` (`T:517-538`): `TableGroupLookup` → `UnitGroupLookup`.
  15. `_groupLookup` (`T:540-567`) becomes the code below, with `_units` beside it:

```dart
  /// The picker's candidates by instance (see [_byHandle]).
  Map<Handle, UnitInfo> _units() {
    final candidates = picker.candidates;
    if (!identical(_byHandleFor, candidates)) {
      _byHandle = {for (final c in candidates) c.unit.instance: c.unit};
      _byHandleFor = candidates;
    }
    return _byHandle;
  }

  /// The group lookup over the picker's current candidates, or null while
  /// the host has no group (then every gesture is as before groups).
  UnitGroupLookup? _groupLookup() {
    final map = groups.value;
    if (map.isEmpty) return null;
    final candidates = picker.candidates;
    if (_lookup == null ||
        !identical(_lookupCandidates, candidates) ||
        !identical(_lookupGroups, map)) {
      // The picker lists visible units only; a locked one is listed.
      final lookup = UnitGroupLookup(map, [
        for (final c in candidates)
          GroupUnit(
              handle: c.unit.instance,
              label: c.unit.text,
              visible: true,
              locked: c.unit.locked,
              generated: c.unit.generated),
      ]);
      _lookup = lookup;
      _groupByHandle = {
        for (final id in map.keys)
          for (final t in lookup.visibleMembers(id)) t.handle: id,
      };
      _lookupCandidates = candidates;
      _lookupGroups = map;
    }
    return _lookup;
  }
```

  16. `_move` (`T:569-589`): `events().onTablesMoved` → `events().onUnitsMoved`.
  17. `_longPress` (`T:591-622`): `FloorPlanLongPress.contextMenu` → `PlanLongPress.contextMenu`; `number` → `label`; `_options.onTableContextMenu` → `_options.onUnitContextMenu`; `hit.table.instance` → `hit.instance`.
  18. `onPointerExit` (`T:624-631`): `onTableHover` → `onUnitHover`.
  19. After `onPointerExit`:

```dart
  /// A secondary click at [world] that the view's listener let through
  /// (spec 14d S6; today's `ServiceView._onSecondaryUp`, service_view.dart:
  /// 212-227): with no `onUnitContextMenu` nothing, not even a pick; else
  /// the unit there takes [contextSelect]'s selection and, labelled, is
  /// reported at [globalPosition].
  void secondaryClick(
      Vector2 world, Offset globalPosition, SelectionController selection) {
    final report = options().onUnitContextMenu;
    if (report == null) return;
    final hit = picker.pick(world);
    if (hit == null) return;
    final label = contextSelect(hit, selection, group: groupKeysOf(hit));
    if (label != null) report(label, globalPosition);
  }
```

- [ ] **Step 5: The session.** In `lib/src/service/service_session.dart` (Task 11's code, its Step 5):
  1. Imports gain `package:meta/meta.dart show internal`, `'service_state.dart' show UnitGroup`, `'service_tool.dart'`, `'unit_picker.dart' show UnitPicker`.
  2. The constructor gains `ValueListenable<Map<String, UnitGroup>>? groups, bool Function()? moves,` after `damage`; its doc's sentence on the idle placeholder becomes "[groups] are the controller's unit groups and [moves] its `serviceMove`, both read by the service tool at each call; without them: no group, moves allowed (a session a test builds)."
  3. In the body, `tool = _IdleTool();` becomes

```dart
    picker = UnitPicker(document, units);
    tool = ServiceTool(
        picker: picker,
        groups: groups ?? _noGroups,
        callbacks: () => host.callbacks(),
        options: () => host.options(),
        moves: moves ?? _always,
        userCamera: () => host.userCamera(),
        toGlobal: (local) => host.toGlobal(local),
        events: () => host.events(),
        idleKeys: () => host.idleKeys());
```

  4. The fields: `late final Tool tool;` → `late final ServiceTool tool;` (doc: "The service tool (2b S4), the tool controller's one tool."), and new:

```dart
  /// The copy's picker: a locked unit and a seat are picked (spec S2, S4).
  @internal
  late final UnitPicker picker;

  /// What the tool reads from the view that shows this session, at each
  /// call: the view sets it while its canvas is mounted and puts
  /// [ServiceHost.none] back when it goes (Task 16).
  @internal
  ServiceHost host = ServiceHost.none;

  static final ValueNotifier<Map<String, UnitGroup>> _noGroups =
      ValueNotifier(const <String, UnitGroup>{});
  static bool _always() => true;
```

  5. `_IdleTool` (the end of Task 11's file) is deleted, and any import only it used.
  6. `lib/src/controller/plan_controller.dart`, `_buildService` (Task 11's Step 6): the `ServiceSession(…)` call gains `groups: unitGroups, moves: () => permissions.serviceMove,`.

- [ ] **Step 6: Run the new tests.** Run: `cd packages/jet_cad_2d_plan && flutter test test/service/service_tool_units_test.dart`. Expected: `All tests passed!` (8 tests).

- [ ] **Step 7: Port the tool tests.** Assertions unchanged in every ported test; only fixtures, names and imports change, as listed. Each file starts with `// Ported from jet_cad_floor_plan/test/<path>; assertions unchanged.` None was ported by 2a (2a results note, "Ported tests"). Common adaptations:
  - the old fixtures come from `../support/unit_fixtures.dart`: `plan()` → `unitPlan()`; `placeSymbol(doc, entryOf(s), at: a, quarterTurns: q, mirrored: m)` → `placeAt(doc, s, a, quarterTurns: q, mirrored: m)` **followed by** `addUnitLabel(doc, h, '<n>')`, `<n>` the number today's numbering placer gave it (1, 2, … in placement order among the units; a planter none), so the plan's labels are today's numbers;
  - the copy: `DraftDocumentCodec.decodeString(…, permissions: DraftPermissions.runtime, registerComponents: registerAppComponents, …)` → `copyForService(design)`;
  - `TableSurvey.of(doc)` → `unitsOf(doc).current` (inside a test; one cache per document, kept in a field where the source re-surveys), `.withNumber(n)` → `.withLabel(n)`, `.tables` → `.units`, `t.number` → `t.text`;
  - `TablePicker(doc)` → `UnitPicker(doc, unitsOf(doc))`; `TableSelectTool(…)` → `ServiceTool(…)` with the records' renamed fields (`onTableTap` → `onUnitTap`, `onTablesMoved` → `onUnitsMoved`, `onTableDoubleTap` → `onUnitDoubleTap`, `onTableHover` → `onUnitHover`, `onTableContextMenu` → `onUnitContextMenu`); an options record's `serviceMoves: x` is dropped and the tool built with `moves: () => <the rig's moves>`;
  - `FloorPlanLongPress` → `PlanLongPress`, `FloorPlanFloorDrag` → `PlanFloorDrag`, `TableGroup` → `UnitGroup`, `validateTableGroups` → `validateUnitGroups`, `kTableLabelTag` → `kUnitLabelTag`.
  1. **`test/service/service_tool_test.dart`** from `floor_plan/test/service/table_select_tool_test.dart`: ST1 … ST17. `Rig()` (`:33-84`): tables placed and labelled `1`, `2`, `3`; the locked layer `addLayer(design, 'Locked')`; `TableSurvey.of(design).withNumber('3').single.instance` → `unitsOf(design).current.withLabel('3').single.instance`; the copy `copyForService(design)`; the tool `ServiceTool(picker: UnitPicker(doc, units), groups: ValueNotifier(const <String, UnitGroup>{}), callbacks: () => (onUnitTap: taps.add, onLayoutChanged: () => layouts++, onGroupTap: null, onMergeRequested: null, onSplitRequested: null))` with `units = unitsOf(doc)` a field; `node(n)` (`:107-109`) reads `units.current.withLabel(n)`.
  2. **`test/service/service_band_test.dart`** from `floor_plan/test/service/table_band_test.dart`: RB1 … RB15b. `ellTable` (`:33-54`) a `CatalogSymbol` keyed `fx.ell.three` (`unit: tableUnit(3)`, `base: (600, 600)`, the two closed `CatalogPolyline`s); `put` (`:127-131`) places with `placeAt` and labels the units `1` … `11` in order (the planter unlabelled); the tenth's label emptied with `SetEntityTextCommand(…, '', kUnitLabelTag)`; the surveys → `unitsOf(design).current` and `unitsOf(doc).current`; `picker = UnitPicker(doc, unitsOf(doc))`; the tool's `options: () => options, moves: () => moves` with a rig field `bool moves = true;`; `drag(floorDrag, {serviceMoves = true})` (`:246-252`) sets `options = (longPress: PlanLongPress.toggleSelection, onUnitContextMenu: null, floorDrag: floorDrag)` and `moves = serviceMoves`; `groups` (`:225-230`) → `ValueNotifier<Map<String, UnitGroup>>(validateUnitGroups({'g': UnitGroup(members: {'4', '5', '6'}), 'h': UnitGroup(members: {'7', '8'})}))`.
  3. **`test/service/service_events_test.dart`** from `floor_plan/test/service/service_events_test.dart`: SE1 … SE16. `CountingPicker` (`:31-40`) `extends UnitPicker`, `CountingPicker(super.document, super.units)`, `UnitInfo? pick(…)`; `Tally` and `CountingTransform` (`:45-100`) are Task 8's (`unit_fixtures.dart`) and are deleted here; the rig (`:91-111`) copies the design of `PlanController(kits: [fxKit()], json: embeddingPlanJson())` (Task 9's `test/support/unit_embedding_fixture.dart`) with `copyForService`, then `units = unitsOf(doc)`, `picker = CountingPicker(doc, units)`; `instance(i)` (`:149`) → `units.current.units[i].instance`; `table(n)` (`:208-209`) unchanged (Task 9 keeps `EmbeddingTable.number`). SE15 (`:587-700`): `rowOfTables(60)` → `numberedRowOfTables(60)`; `TablePicker(doc, invert: …)` → `UnitPicker(doc, unitsOf(doc), invert: …)`; `TablePicker.tolerance` → `UnitPicker.tolerance`; `TableSurvey.of(doc).tables` → `unitsOf(doc).current.units`, `t.number` → `t.text`.

- [ ] **Step 8: Port the allocation tests, extend them, and the CI flag.**
  1. **`test/invariants/pick_allocation_test.dart`** from `floor_plan/test/invariants/pick_allocation_test.dart`: PA1, PA2, PA3, assertions unchanged. Adaptations: imports (`:39-46`) → `package:jet_cad_2d_plan/src/service/unit_picker.dart`, `package:jet_cad_2d_plan/src/units/unit_index.dart`, `'../support/unit_fixtures.dart'`, `'vm_allocation_meter.dart'`; `_floor()` (`:60-77`) builds `unitPlan()` and places with `placeAt(doc, i.isEven ? stoolSymbol : trapezoidTable, at, mirrored: true)`, then the same turn (no label: the picks read none); `picker`, `list`, `first`, `toWorld`, `circle`, `topPoint`, `boxPoint` (`:90-100`) become `late` variables set in `setUpAll` (`unitsOf` registers its tear-down there, run after all tests): `picker = UnitPicker(doc, unitsOf(doc))`; `measure`'s `PickCandidate? expected` → `UnitInfo? expected`; PA2 and PA3 pass `expected: first.unit`. Then add (Review Focus 5):

```dart
  // 2b Review Focus 5: a dense hall, 500 generated seats in 25 rows (even
  // rows turned 37 degrees, odd rows curved), 40 m off the origin.
  group('the hall', () {
    late PlanController hall;
    late UnitPicker hallPicker;
    late List<PickCandidate> hallList;

    setUpAll(() {
      hall = hallController();
      hallPicker = hall.serviceSession!.picker;
      hallList = hallPicker.candidates;
    });

    tearDownAll(() => hall.dispose());

    Future<void> measureHall(Vector2 world,
        {required double reach, required UnitInfo? expected}) async {
      final m = meter;
      if (m == null) {
        markTestSkipped(vmServiceUnavailableReason);
        return;
      }
      expect(hallList.where((c) => c.unit.generated), hasLength(500),
          reason: 'premise: every seat a candidate');
      expect(identical(hallPicker.pick(world, reach: reach), expected), isTrue,
          reason: 'premise: the pick answers');
      for (var i = 0; i < 20000; i++) {
        hallPicker.pick(world, reach: reach);
      }
      await m.reset();
      const picks = 1000;
      for (var i = 0; i < picks; i++) {
        hallPicker.pick(world, reach: reach);
      }
      final accumulated = await m.accumulatedInstances(_watched);
      expect(identical(hallPicker.candidates, hallList), isTrue,
          reason: 'premise: the candidates were not rebuilt');
      for (final MapEntry(key: name, value: count) in accumulated.entries) {
        expect(count / picks, lessThan(_perPickBudget),
            reason: '$name: $count over $picks picks of 500 seats');
      }
    }

    test(
        'PA4 a pick on the hall\'s floor, with a finger\'s reach, allocates '
        'nothing per seat: every seat visited by all three passes', () async {
      await measureHall(Vector2(-9000, 13000), reach: 150, expected: null);
    });

    test(
        'PA5 a pick on the lowest seat\'s top allocates nothing per seat: '
        'every top above it visited', () async {
      final first = hallList.firstWhere((c) => c.unit.generated);
      final t = first.unit.top;
      final world = first.unit.toWorld.transformPoint(
          Vector2((t.minX + t.maxX) / 2, (t.minY + t.maxY) / 2));
      await measureHall(world, reach: 0, expected: first.unit);
    });
  });
```

     The file gains `import 'package:jet_cad_2d_plan/src/controller/plan_controller.dart';`, `import '../support/service_rig.dart' show hallController;`, and `TestWidgetsFlutterBinding.ensureInitialized();` as the first statement of `main` (the hall's controller needs the binding).
  2. **`test/invariants/band_allocation_test.dart`** from `floor_plan/test/invariants/band_allocation_test.dart`: RB16, assertions unchanged. Adaptations: imports (`:32-46`) as in 1. plus `service_tool.dart` and `service_state.dart show UnitGroup`; `plan()` → `unitPlan()`; the table placed with `placeAt(doc, tableSymbol(), Vector2(-2000, 1000), quarterTurns: 1, mirrored: true)`; `TablePicker(doc)` → `UnitPicker(doc, unitsOf(doc))`; the groups notifier typed `Map<String, UnitGroup>`; `TableSelectTool(…)` → `ServiceTool(picker: …, groups: groups, callbacks: () => kNoServiceCallbacks, options: () => (longPress: PlanLongPress.toggleSelection, onUnitContextMenu: null, floorDrag: PlanFloorDrag.band))`. Extract RB16's body from `final recorder = ui.PictureRecorder();` (`:132`) to its last `expect` (`:189-190`) into `Future<void> bandFrames(AllocationMeter m, Tool tool, ToolContext ctx, CameraController camera, ui.Offset press, ToolPointerEvent Function(ui.Offset s) ev)`, its statements unchanged, and call it from RB16. Then add:

```dart
  test(
      'RB16-hall a live band over the hall (500 seats in 25 rows) builds no '
      'Paint and no Path per frame (2b Review Focus 5)', () async {
    final m = meter;
    if (m == null) {
      markTestSkipped(vmServiceUnavailableReason);
      return;
    }
    final hall = hallController();
    addTearDown(hall.dispose);
    final s = hall.serviceSession!;
    s.host = ServiceHost(
        options: () => (
              longPress: PlanLongPress.toggleSelection,
              onUnitContextMenu: null,
              floorDrag: PlanFloorDrag.band,
            ));
    hall.camera.value = ViewportTransform(
        worldToScreenMatrix: Transform2(0.1, 0, 0, -0.1, -3300, -2250));
    final camera = hall.camera;
    final ctx = s.toolContext;
    ToolPointerEvent ev(ui.Offset p) => ToolPointerEvent(
          screen: p,
          world: camera.value.screenToWorld(Vector2(p.dx, p.dy)),
          pointer: 1,
          buttons: kPrimaryButton,
          shift: false,
          control: false,
          meta: false,
          alt: false,
          pickRadiusWorld: 6 / camera.value.scale,
          kind: PointerDeviceKind.mouse,
        );
    const press = ui.Offset(900, 120);
    expect(s.picker.pick(ev(press).world), isNull,
        reason: 'premise: the press is on the floor');
    expect(s.picker.candidates.where((c) => c.unit.generated), hasLength(500),
        reason: 'premise: the hall');
    s.tool.onPointerDown(ev(press), ctx);
    s.tool.onPointerMove(ev(const ui.Offset(1100, 300)), ctx);
    expect(s.tool.phase, ToolPhase.dragging, reason: 'premise: a live band');
    await bandFrames(m, s.tool, ctx, camera, press, ev);
  });
```

     The file gains `TestWidgetsFlutterBinding.ensureInitialized();` first in `main`, and imports `plan_controller.dart` and `'../support/service_rig.dart' show hallController`.
  3. **`.github/workflows/ci.yml`**: the `packages/jet_cad_2d_plan` entry (`:45-46`) becomes

```yaml
          - package: packages/jet_cad_2d_plan
            tool: flutter
            # The pick's and the band's allocation tests (2b Task 14) read
            # the VM's allocation profiler, as the planner's do.
            test_flags: --enable-vmservice
```

  4. **`tool/ci/test/scripts_test.dart`**: after SC20 (`:411-430`):

```dart
  // 2b Task 14: the plan library's pick and band allocation tests read the
  // VM's allocation profiler too; without the flag they skip, which the
  // standing comparison reads as red.
  test('SC20b the plan library\'s tests run with --enable-vmservice', () {
    final entry = workflow.indexOf('- package: packages/jet_cad_2d_plan');
    expect(entry, isNot(-1));
    final next = workflow.indexOf('- package: ', entry + 1);
    expect(
      workflow.substring(entry, next),
      contains('\n            test_flags: --enable-vmservice\n'),
    );
  });
```

- [ ] **Step 9: Run the ported tests.** One by one:
  - `cd packages/jet_cad_2d_plan && flutter test test/service`. Expected: `All tests passed!`.
  - `cd packages/jet_cad_2d_plan && flutter test --enable-vmservice test/invariants/pick_allocation_test.dart test/invariants/band_allocation_test.dart`. Expected: `All tests passed!`, no test skipped (PA1 … PA5, RB16, RB16-hall). Quote the run.
  - `cd tool/ci && dart test`. Expected: `All tests passed!`.

  A ported test that fails on an assertion is a finding (Global Constraints): stop and report it with the failing line; never change the assertion.

- [ ] **Step 10: Format and the gates.** `cd packages/jet_cad_2d_plan && dart format . && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` — each exits 0 (`flutter test` without the flag skips the two allocation files; expected locally). `cd tool/ci && dart test` exits 0. `git status --short` lists only this task's files.

- [ ] **Step 11: Commit.**

```bash
git add packages/jet_cad_2d_plan/lib/src/service/service_tool.dart packages/jet_cad_2d_plan/lib/src/service/service_session.dart packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart packages/jet_cad_2d_plan/test/support/unit_fixtures.dart packages/jet_cad_2d_plan/test/support/service_rig.dart packages/jet_cad_2d_plan/test/invariants/vm_allocation_meter.dart packages/jet_cad_2d_plan/test/service/service_tool_units_test.dart packages/jet_cad_2d_plan/test/service/service_tool_test.dart packages/jet_cad_2d_plan/test/service/service_band_test.dart packages/jet_cad_2d_plan/test/service/service_events_test.dart packages/jet_cad_2d_plan/test/invariants/pick_allocation_test.dart packages/jet_cad_2d_plan/test/invariants/band_allocation_test.dart .github/workflows/ci.yml tool/ci/test/scripts_test.dart
git commit -m "$(cat <<'EOF'
feat(plan): the service tool over units, placed and generated (2b S4)

Today's table tool ported over units: taps, bands, long presses,
context clicks, drags, hover and keys write the copy's selection with
root keys, seats included. A drag moves the selected placed units, a
group whole; a seat stays, and a group with a seat or a locked member
is never dragged. A locked unit is tapped and grouped, never
selected. The session builds the tool, which reads the view through
the session's host and moves through serviceMove. The pick and band
allocation tests are ported and extended with a hall of 500 seats;
CI runs the plan library's tests with the VM service.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

  (Step 5 changes no Task 11 test file: Task 11's tests build no `tool:`, controller ruling R-17.)

- [ ] **Step 12: Mutation check** (on the committed files; after each: run the named test, quote its red line, `git checkout -- <file>`, then `git diff --quiet -- <file>` exits 0):
  - M-ST-seat `lib/src/service/service_tool.dart`, in `_tap`: `final key = SelectionKey.root(hit.instance);` → `final key = SelectionKey.root(hit.owner ?? hit.instance);` → ST-seat red (the selection holds the row).
  - M-ST-mixed `service_tool.dart`, in `_startDrag`: `if (k.chain.isEmpty && !(index[k.target]?.generated ?? false))` → `if (k.chain.isEmpty)` → ST-mixed-drag red (the copy's guard refuses the seats' moves, or they move).
  - M-ST-group `service_tool.dart`, in `_startDrag`: delete `|| lookup.hasGeneratedVisibleMember(id)` → ST-group-seat red (the table moves).
  - M-ST-locked `service_tool.dart`, in `_tap`: `if (!hit.locked) {` → `if (true) {` → ST-locked-seat red (`r.keys` not empty).
  - M-ST-unlabelled `service_tool.dart`, in `_tap`: `final label = hit.text;` → `final label = hit.text ?? '';` → ST-unlabelled red (`taps` is `['', '']`).
  - M-ST-band `service_tool.dart`, in `_bandKeys`: `if (byHandle.containsKey(h)) passing.add(h);` → `if (byHandle[h]?.generated == false) passing.add(h);` → ST-band-two-rows red (no seat taken).
  - M-ST-secondary `service_tool.dart`, in `secondaryClick`: `final label = contextSelect(hit, selection, group: groupKeysOf(hit));` → `final label = hit.text;` → ST-secondary red (the selection stays empty).
  - M-ST-gate `lib/src/controller/plan_controller.dart`, in `_buildService`: `moves: () => permissions.serviceMove,` → `moves: () => true,` → ST-move-gate red (the table moves).
  - M-14l (ported) `service_tool.dart`, in `_longPress`: delete `if (hit.locked) return;` → `service_tool_test.dart`'s ST7 red.
  - M-RB-lone-locked `service_tool.dart`, in `_bandKeys`: `} else if (!byHandle[h]!.locked) {` → `} else {` → `service_band_test.dart`'s RB10 red (a lone locked table taken).
  - M-H29 (ported) `service_tool.dart`, in `onPointerMove`: `if (e.buttons == 0 && !e.isTouch) _hover(e);` → `if (e.buttons == 0) _hover(e);` → `service_events_test.dart`'s SE12 red (a finger hovers).
  - M-RB19 (ported) `service_tool.dart`, in `paintOverlay`: `_bandPainter.paint(` → `SelectionBandPainter().paint(` → `band_allocation_test.dart`'s RB16 red, run with `--enable-vmservice`.
  - M-PA-hall `lib/src/service/unit_picker.dart` (Task 8's, committed), in `pick`'s first loop: `final m = c.inverse;` → `final m = c.unit.toWorld.invert();` → PA4 red (a `Transform2` and boxed doubles per seat), run with `--enable-vmservice`.
  - M-SC20b `.github/workflows/ci.yml`: delete the plan library's `test_flags` line → `cd tool/ci && dart test`'s SC20b red.

#### Assumed from earlier tasks

Each name below is used as written; where the earlier task named it otherwise, the implementer uses that task's name and reports the difference.
- Task 5: `unitKit()`, `RowComponent({prefix, count, spacing, curve, seat, base, top})`, `rowSeatKey`, `entryTop` (`test/support/test_kit.dart`); `serviceFixture()` (`json`, `table`, `seatsA`, `seatsB`), `testEntry`, `addRow(d, row, {at, angle})`, `unitLabelsOf(d, instance)` (`test/support/service_fixture.dart`). The tests read the table's label through `c.unitIndex` (its lowest-handle UNIT ATTRIB), never a literal, so a second label that Task 7's numbering placer may add leaves them correct.
- Task 6: `UnitInfo`, `UnitIndex`, `UnitIndexCache` as in the Shared interfaces.
- Task 8: `UnitPicker`, `PickCandidate` and the test support named in "Consumes"; `PlanPermissions.copyWith(serviceMove:)`.
- Task 9: `PlanController.unitIndex` (`@internal`); `test/support/unit_embedding_fixture.dart` (`embeddingPlanJson`, `embeddingCamera`, `embeddingTables`, `EmbeddingTable.number`, `canvasOf`).
- Task 11: `PlanMode` and `serviceCopyOf` in `lib/src/service/service_session.dart`; `ServiceSession`'s constructor, fields and `dispose` as its Step 5 writes them; `_buildService` in `plan_controller.dart`.
- Task 12: `GroupUnit`, `UnitGroupLookup` (with `hasGeneratedVisibleMember`), `validateUnitGroups`, `PlanController.unitGroups`, `setUnitGroups`; Task 11's `selectedUnits`.
- 2a: `PlanController.permissions` (settable), `execute`, `camera`, `document`, `dispose`; `planText`, `planDocument`, `registerPlanComponents` (`test/support/harness.dart`).

#### Interface problem

1. Resolved by R-12 (`UnitPicker` is Task 8's; this task consumes it).
2. Resolved by R-17 (`ServiceHost` and the settable `ServiceSession.host` built here; `ServiceSession.tool` is a `ServiceTool`; Task 11 makes only a private `_IdleTool`, no `tool:` factory, and this task deletes it; `ServiceOptions` has no `serviceMove`).
3. Resolved by R-15 (the view-level ports are Task 16's Step B2b).
4. Resolved by R-23: Step 1 adds `vm_service: ^15.2.0` to `packages/jet_cad_2d_plan/pubspec.yaml`'s `dev_dependencies` (the engine's and today's planner's constraint), runs `flutter pub get` from the root, stages the pubspec by explicit path with this task's files (never `analysis_options.yaml` or `pubspec.lock` outside the root), and the gates run as written.

---

