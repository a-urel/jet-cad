### Task 8: Permissions, the design's selection mapping and the unit picker (spec S2 "In design, a generated unit stands for its object", "Locked units"; S4 "Permissions", "The unit picker"; decision 9)

**Files:**
- Modify: `packages/jet_cad_2d_plan/lib/src/controller/permissions.dart` (rewritten whole: `relabel`, `selectUnitsOnly`, `serviceMove`, `serviceMerge`, `unitsOnly`, `isUnitSymbol`)
- Create: `packages/jet_cad_2d_plan/lib/src/service/unit_picker.dart` (port of `jet_cad_floor_plan/lib/src/service/table_picker.dart`)
- Modify: `packages/jet_cad_2d_plan/lib/src/tools/plan_select_gates.dart` (rewritten whole: the design mapping, `selectUnitsOnly`)
- Modify: `packages/jet_cad_2d_plan/lib/src/controller/session.dart` (the gates' new arguments, the session's units-only picker)
- Modify: `packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart` (the `permissions` setter: a gesture cancelled and the selection pruned when `selectUnitsOnly` turns on)
- Modify: `packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart` (export `isUnitSymbol`)
- Test (support): modify Task 6's `packages/jet_cad_2d_plan/test/support/unit_fixtures.dart` (the picker's helpers appended; controller ruling R-19); create `packages/jet_cad_2d_plan/test/support/unit_editor_fixture.dart`
- Test (new): `packages/jet_cad_2d_plan/test/tools/design_selection_test.dart` (DS-*)
- Test (ported): `packages/jet_cad_2d_plan/test/service/unit_picker_test.dart`, `packages/jet_cad_2d_plan/test/editor/units_only_select_test.dart`
- Test (grown): `packages/jet_cad_2d_plan/test/controller/permissions_test.dart`, `packages/jet_cad_2d_plan/test/tools/plan_select_gates_test.dart`, `packages/jet_cad_2d_plan/test/barrel_test.dart`

(Paths below are under `packages/jet_cad_2d_plan/` unless they say otherwise.)

**Interfaces:**
- Consumes:
  - Engine (`jet_cad_2d`): `DraftDocument.rootHandle`, `tree[h]`, `Node.parent`, `GroupNode`, `InstanceNode`, `EntityStore.slotOf`/`ownerAt`, `DraftDocument.definitionBounds(definition, leaves)` (`document/draft_document.dart:177`), `leavesByOwner()` (`:233`), `ParametricCatalog.typeIdOf(target, group)` (`parametric/parametric_system.dart:586`), `HitPath()` (`index/hit.dart:28`), `SpatialIndex.pickInto`, `QueryFilter.picking()`, `isClosedPolyline` (`document/grips.dart:50`), `Transform2`, `Aabb2`, `Tolerance`.
  - Flutter layer (`jet_cad_2d_flutter`, unchanged): `SelectGates.restrictsPick`/`pick`/`bandAccepts` (`select_gates.dart:28-42`), `resolveHit` (`selection.dart:54-73`), `SelectionKey.root`, `SelectionController.keys`/`remove`, `ToolPointerEvent.world`/`pickRadiusWorld`/`reachRadiusWorld`/`isTouch` (`tool.dart:31-54`), `kTouchPickRadiusPixels` (`interaction_layer.dart:30`).
  - Contract (`jet_cad_2d_kit`): `PlanGate` with `relabel` (Task 3), `UnitComponent`, `SymbolComponent`, `SymbolEntry`, `CatalogSymbol`/`CatalogUnit`/`CatalogPolyline`/`CatalogCircle`/`CatalogLine` (authoring), `kUnitLabelTag`, `kUnitLabelTextAttrs`, `unitLabelHeight`, `unitLabelPayload` (Task 3).
  - Task 6: `UnitInfo` (`instance`, `definition`, `owner`, `generated`, `locked`, `visible`, `toWorld`), `UnitIndex` (`units`, `operator []`, `withLabel`), `UnitIndex.of(document, catalog:, locks:)`, `UnitIndexCache(document, catalog:, locks:, locked:)` with `current` and `dispose()`; the design session's cache as `DocumentSession.units` (see "Assumed from earlier tasks").
  - Task 5: the test kit with its units (`unitKit()`, kit id `test`, the row type `test.row`; `testKit()` alone has no row) and `serviceFixture()` (`test/support/service_fixture.dart`).
  - 2a: `LockGates` (`kits/locks.dart:371`), `LockSet.scan`, `PlanSymbol` (`symbols/plan_symbol.dart:8`), `definitionForEntry` and `placementTransform` (`symbols/symbol_placer.dart:48`, `:84`), `PlanController.permissions` setter (`controller/plan_controller.dart:819-840`), `DocumentSession` (`controller/session.dart:29-89`), the test helpers `planText`, `controllerFor`, `addLine`, `coordsOf` (`test/support/harness.dart`), `useTestCamera`, `eventAt`, `tapAt`, `dragFrom` (`test/support/tool_events.dart`), `leafRecord` (`test/support/symbol_fixtures.dart:57`).
- Produces (the Shared interfaces' Task 8 row, exactly):
  - `PlanPermissions` gains `relabel` (Task 3's, kept), `selectUnitsOnly` (default `false`), `serviceMove` (default `true`), `serviceMerge` (default `true`); `static const PlanPermissions unitsOnly`; `copyWith`, `==`, `hashCode`, `toString` over every field.
  - `bool isUnitSymbol(PlanSymbol symbol)` (exported from the barrel).
  - `PlanSelectGates`: `restrictsPick` true (the design's pick); `pick` runs the tool's own pick, `resolveHit`, then maps a key under a parametric or lock-set object to that object; `bandAccepts` refuses such keys; under `selectUnitsOnly` both are restricted to placed units.
  - Internal (`lib/src/tools/plan_select_gates.dart`): `Handle? generatingObjectOf(DraftDocument d, Handle h, ParametricCatalog catalog, Set<Handle> locked)`, `bool isPlacedUnitKey(UnitIndex index, SelectionKey key)`.
  - Internal (`lib/src/service/unit_picker.dart`), **created here, not in Task 14** (Task 9's `unitAt` and Task 14's service tool consume it): `sealed class UnitTop` (`PolygonTop`, `CircleTop`), `UnitTop? unitTopOf(DraftDocument doc, Handle definition, [Map<Handle, List<int>>? leavesByOwner])` (over Task 6's `firstLeafOf(CommandTarget, Handle, [leavesByOwner])`, imported, not redeclared), `final class UnitCandidate` (`unit`, `transform`, `box`, `corners`, `locked`, `worldBounds`), `final class PickCandidate`, and `class UnitPicker` — `UnitPicker(DraftDocument document, UnitIndexCache units, {bool skipLocked = false, bool placedOnly = false, @visibleForTesting Map<Handle, List<int>> Function()? leavesByOwner, @visibleForTesting Transform2 Function(Transform2 transform)? invert})`, `UnitInfo? pick(Vector2 world, {double reach = 0})`, `List<PickCandidate> get candidates`, `static List<UnitCandidate> candidatesOf(DraftDocument document, UnitIndex index, {required Map<Handle, Aabb2> boxes, required Map<Handle, List<int>> Function() leaves})` (controller ruling R-12).

Plan decision (why the picker is here): today's `selectTablesOnly` pick **is** the table picker (`planner_shell.dart:444`, `:1817-1826`: `TablePicker(_document, skipLocked: true)`, "a table's top, else its box; the index pick's tolerance for a mouse, a finger's reach for a touch; a locked table passed over"). The ported `editor_select_test` cases (a click inside table 1's top, away from every line, selects it) cannot pass on the index's pick. So the picker is ported here, whole, with its own tests (`service/table_picker_test.dart`), and Task 9 (`unitAt`) and Task 14 (the service tool, the allocation invariants) use it.

Plan decision (the profiles): `readOnly` gains `relabel: false` (today's `readOnly` has `renumber: false`, `editor_capabilities.dart:192`). `unitsOnly` is today's `tablesOnly` (`:175`) restricted to `PlanPermissions`' fields: tools `{plan.select, plan.symbol}`, `mirror`, `reshape`, `changeLayer`, `editLayers`, `editPage` false, `selectUnitsOnly` true; everything else as `full`. The panels are `PlanEditor`'s options (2a P7). Neither profile touches `serviceMove` or `serviceMerge`: today's profiles govern the editor alone (`editor_capabilities.dart:133-134`, "the selection mode is governed by the view's own parameters").

Plan decision (`edits`): `relabel` is an edit (a label is entity text); `selectUnitsOnly`, `serviceMove` and `serviceMerge` are not (the first restricts a selection, the other two act on the service copy, never on the design).

Plan decision (`toString`): it names every field whose value differs from `full`'s, in declaration order, so `unitsOnly` prints `selectUnitsOnly: true` (2a's version printed `false` flags only; every 2a flag defaults to true, so its texts are unchanged).

Plan decision (the mapping, spec S2): a key's target `h` (an instance or a root-level entity, the only targets `resolveHit` gives, `selection.dart:54-73`) maps to the root-level node above it when that node is a `GroupNode`, is not `h` itself, and is an object of a registered type (`catalog.typeIdOf(d, g) != null`, frozen objects included: a frozen object keeps its component) or a lock-set object (`locked.value.contains(g)`: the controller's `locked` notifier is `LockSet.objects`, `locks.dart:101`). The walk goes up `Node.parent` with no list: hover rate allocates nothing for it. A table inside a plain group maps to nothing (today's selection).

Plan decision (the band, decision 9): `bandAccepts` refuses a key the mapping would map. The tool's own group rule (`select_tool.dart:582-596`, `:621-645`) then gives the row to a crossing band (its seats' ATTRIBs resolve to it) and nothing to a window band over a seats-only row (the row owns no leaf of its own). `jet_cad_2d_flutter` is unchanged.

Plan decision (`selectUnitsOnly`): the pick is the session's units-only picker (`skipLocked: true`, `placedOnly: true`), with the reach today's gates give it: `e.reachRadiusWorld` for a touch, `e.pickRadiusWorld` for a mouse (`planner_shell.dart:1819-1825`). The band keeps placed-unit keys only (today's `_isTableKey`, `:1787-1795`: a root key whose target is a root-level instance of a unit definition). A switch to `selectUnitsOnly` cancels a gesture under way and keeps only the placed units of the selection (today's `didUpdateWidget`, `:1077-1095`), in the controller's `permissions` setter.

- [ ] **Step 1: The fixtures.** Append to Task 6's `test/support/unit_fixtures.dart` (Task 6 owns the file and already holds `fxKitId`, `fxKit()`, `tableUnit`, `tableSymbol`, `stoolSymbol`, `planterSymbol`, `oneChairTable`, `trapezoidTable`, `entryOf` (built by hand), `plan()`, `kDeg37`, `placementAt`, `unitIndexOf`, `labelUnit`, `labelsOf`; controller ruling R-19): two more symbols for the picker's ports, the picker tests' helpers (`service/table_picker_test.dart:24-59`), `rowOfTables` (`service/table_status_painter_test.dart:62-78`), and `Tally`/`CountingTransform` (`service/service_events_test.dart:45-100`). Tasks 9, 10, 14 and 15 reuse them.

  The file's imports gain:

```dart
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_plan/src/service/unit_picker.dart';
import 'package:jet_cad_2d_plan/src/symbols/symbol_placer.dart'
    show definitionForEntry, placementTransform;
```

  and its header comment's first line names Task 8's additions. Append, after `labelsOf`:

```dart
/// One chair right of the top: the box spans x 300..1850.
const CatalogSymbol sideChairTable = CatalogSymbol(
  key: 'fx.table.side',
  name: 'Side chair table',
  category: 'Tests',
  tags: ['table', 'test'],
  unit: CatalogUnit(kind: UnitKinds.table, capacity: 1),
  base: (900, 700),
  shapes: [
    CatalogPolyline([(300, 300), (1500, 300), (1500, 1100), (300, 1100)],
        closed: true),
    CatalogPolyline([(1400, 475), (1850, 475), (1850, 925), (1400, 925)],
        closed: true),
  ],
);

/// A unit whose first leaf is an open polyline: no top (R-8). A library
/// refuses it (K3 rule 11); a plan file may hold it.
const CatalogSymbol openTable = CatalogSymbol(
  key: 'fx.table.open',
  name: 'Open table',
  category: 'Tests',
  tags: ['table', 'test'],
  unit: CatalogUnit(kind: UnitKinds.table, capacity: 2),
  base: (900, 700),
  shapes: [
    CatalogPolyline([(300, 300), (1500, 300), (1500, 1100), (300, 1100)]),
    CatalogPolyline([(675, -50), (1125, -50), (1125, 400), (675, 400)],
        closed: true),
  ],
);

/// An empty plan over [fxKit] (the page, the contract's components), in
/// millimetres, no system installed.
DraftDocument unitPlan() => planDocument([fxKit()]);

/// Places [s] by [transform] on [layer] (layer 0 by default): its
/// definition copied on first use (definitionForEntry), one instance, one
/// step, **no label** (a test adds one with [addUnitLabel]). Returns the
/// instance.
Handle placeUnit(DraftDocument doc, CatalogSymbol s,
    {required Transform2 transform, Handle? layer}) {
  final made = definitionForEntry(doc, entryOf(s));
  final h = doc.handleSeed.next();
  doc.commands.execute(CompoundCommand([
    ...made.commands,
    AddNodeCommand(InstanceNode(
        handle: h,
        parent: doc.rootHandle,
        definition: made.definition,
        layer: layer ?? ReservedHandles.layerZero,
        transform: transform)),
  ], label: 'Place ${s.name}'));
  return h;
}

/// [s] placed with its base point at [at], [quarterTurns] counter-clockwise
/// and [mirrored] (the placer's transform, symbol_placer.dart:48).
Handle placeAt(DraftDocument doc, CatalogSymbol s, Vector2 at,
        {int quarterTurns = 0, bool mirrored = false}) =>
    placeUnit(doc, s,
        transform: placementTransform(
            at: at,
            basePoint: Vector2(s.base.$1, s.base.$2),
            quarterTurns: quarterTurns,
            mirrored: mirrored));

/// Places [s] mirrored (by default) at [at], then turns it by 37 degrees
/// about [at]. Returns the instance node.
InstanceNode placeTurned(DraftDocument doc, CatalogSymbol s, Vector2 at,
    {bool mirrored = true}) {
  final h = placeAt(doc, s, at, mirrored: mirrored);
  final node = doc.tree[h]! as InstanceNode;
  final turn = Transform2.translation(at.x, at.y)
      .multiply(Transform2.rotation(kDeg37))
      .multiply(Transform2.translation(-at.x, -at.y));
  doc.commands.execute(TransformNodeCommand(h, turn.multiply(node.transform)));
  return doc.tree[h]! as InstanceNode;
}

Vector2 worldOf(InstanceNode n, double x, double y) =>
    n.transform.transformPoint(Vector2(x, y));

/// A layer [name] beside layer 0.
Handle addLayer(DraftDocument doc, String name,
    {bool visible = true, bool locked = false}) {
  final zero = doc.tables.layers[ReservedHandles.layerZero]!;
  final h = doc.handleSeed.next();
  doc.commands.execute(AddLayerCommand(LayerRecord(
      handle: h,
      name: name,
      color: const IndexedColor(4),
      linetype: zero.linetype,
      lineweight: zero.lineweight,
      transparency: zero.transparency,
      visible: visible,
      locked: locked)));
  return h;
}

/// Adds [text] as [instance]'s UNIT label, stamped as a placed unit's
/// (spec S2): Task 6's [labelUnit] (`addUnitLabelCommand`: owned by the
/// instance, layer 0, BYBLOCK, the standard text style, anchored at the
/// definition's base point, upright in the world, today's height rule,
/// controller ruling R-21). One step. Returns the label's handle.
Handle addUnitLabel(DraftDocument doc, Handle instance, String text) =>
    labelUnit(doc, doc.tree[instance]! as InstanceNode, text);

/// A unit index cache over [doc] with nothing locked and no type,
/// disposed at tear-down. Call inside a test.
UnitIndexCache unitsOf(DraftDocument doc, {ParametricCatalog? catalog}) {
  final locked = ValueNotifier<Set<Handle>>(const {});
  final cache = UnitIndexCache(doc,
      catalog: catalog ?? ParametricCatalog(),
      locks: LockSet.scan(doc, (_) => true),
      locked: locked);
  addTearDown(() {
    cache.dispose();
    locked.dispose();
  });
  return cache;
}

/// A picker over [doc] ([unitsOf]); the options and seams as UnitPicker's.
UnitPicker pickerOf(DraftDocument doc,
        {bool skipLocked = false,
        bool placedOnly = false,
        Map<Handle, List<int>> Function()? leavesByOwner,
        Transform2 Function(Transform2 transform)? invert}) =>
    UnitPicker(doc, unitsOf(doc),
        skipLocked: skipLocked,
        placedOnly: placedOnly,
        leavesByOwner: leavesByOwner,
        invert: invert);

/// [n] trapezoid tables 40 m off the origin, ten to a row 2.5 m apart,
/// each mirrored and turned 37 degrees about its base point.
DraftDocument rowOfTables(int n) {
  final doc = unitPlan();
  for (var i = 0; i < n; i++) {
    final at = Vector2(40000.0 + 2500 * (i % 10), -27000.0 - 2500 * (i ~/ 10));
    placeTurned(doc, trapezoidTable, at);
  }
  return doc;
}

final class Tally {
  int count = 0;
}

/// A candidate's inverse that counts every new object it is asked for: a
/// point or a direction mapped, a product, an inverse, a list, a string.
/// The coefficients are read as fields, which build nothing.
final class CountingTransform extends Transform2 {
  CountingTransform(Transform2 m, this.made)
      : super(m.a, m.b, m.c, m.d, m.e, m.f);

  final Tally made;

  @override
  Vector2 transformPoint(Vector2 p) {
    made.count++;
    return super.transformPoint(p);
  }

  @override
  Vector2 transformDirection(Vector2 v) {
    made.count++;
    return super.transformDirection(v);
  }

  @override
  Transform2 multiply(Transform2 other) {
    made.count++;
    return super.multiply(other);
  }

  @override
  Transform2 invert() {
    made.count++;
    return super.invert();
  }

  @override
  List<double> toJson() {
    made.count++;
    return super.toJson();
  }

  @override
  String toString() {
    made.count++;
    return super.toString();
  }
}

/// [values] as a Float64List (the tops' expectations).
Float64List f64(List<double> values) => Float64List.fromList(values);
```

  `CountingTransform`'s six overrides are all of today's (`jet_cad_floor_plan/test/service/service_events_test.dart:53-95`). `firstLeafOf` is Task 6's (`lib/src/units/unit_label.dart`, with today's optional `leavesByOwner`); the picker imports it.

  Create `test/support/unit_editor_fixture.dart`, the port of `jet_cad_floor_plan/test/host/editor_fixture.dart:1-176` and the helpers of `editor_tools_test.dart:80-256` the selection tests use. Adaptations: the startup flat is sub-project 3's, so root-level lines stand for the north wall (y 16,850) and its inner face (y 16,750), a closed square polyline for the column, and one line through table 1's top for the parquet hairline that today's index pick finds there (a fixture change, A12; every world coordinate a test reads is today's); the tables are the embedding table as the fixture kit's unit, placed by hand and labelled with `addUnitLabel`; `FloorPlanView` becomes `PlanEditor`; the capabilities become `c.permissions`.

```dart
// The editor fixture of jet_cad_floor_plan (test/host/editor_fixture.dart),
// ported for the units-only selection tests (2b Task 8; Task 10's
// inspector tests reuse it): the embedding fixture's hand-made table (its
// box off its base point, an asymmetric top) placed as `1` (turned 30
// degrees) and `2` (mirrored at exactly 90 degrees) beside the north wall,
// `7` and ` 7 ` sharing a label, an unlabelled table, `5` on a hidden and `L`
// on a locked layer; a root-level group of two lines, turned and off the
// origin; a free line; a TEXT; and a chair, a symbol that is no unit.
// The startup flat (sub-project 3's walls and rooms) is not ported: two
// root-level lines stand for the north wall and its inner face, a closed
// square for the column, and a line through table 1's top for the parquet
// hairline (fixture changes, A12). Same world coordinates, same camera
// (0.37 px/mm, y up, panned): never the identity.
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show InteractionLayer, ViewportTransform;
import 'package:jet_cad_2d_kit/authoring.dart'
    show CatalogPolyline, CatalogSymbol, CatalogUnit;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show PlanKit, UnitKinds;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/kits/locks.dart' show LockSet;
import 'package:jet_cad_2d_plan/src/units/unit_index.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'harness.dart' show planText;
import 'unit_fixtures.dart';

/// The window every editor test runs in.
const Size kEditorSurface = Size(2400, 1500);

const String kEmbeddingHidden = 'Hidden';
const String kEmbeddingLocked = 'Locked';

/// The embedding fixture's table (four seats): its top an asymmetric
/// quadrilateral; its base point the definition's origin, outside its box.
const CatalogSymbol embeddingTable = CatalogSymbol(
  key: 'fx.embedding.four',
  name: 'Test embedding table',
  category: 'Tests',
  tags: ['table', 'test'],
  unit: CatalogUnit(kind: UnitKinds.table, capacity: 4),
  base: (0, 0),
  shapes: [
    CatalogPolyline([(300, -200), (1100, -200), (900, 400), (300, 250)],
        closed: true),
  ],
);

/// [embeddingTable]'s box in definition space: its centre (700, 100) is not
/// its base point (0, 0).
const Aabb2 embeddingBox = Aabb2.raw(300, -200, 1100, 400);

/// A chair: no unit, its base point (0, 0) off its seat.
const CatalogSymbol editorChair = CatalogSymbol(
  key: 'fx.chair.plain',
  name: 'Test chair',
  category: 'Tests',
  tags: ['chair', 'test'],
  base: (0, 0),
  shapes: [
    CatalogPolyline([(50, 50), (500, 50), (500, 430), (50, 430)], closed: true),
    CatalogPolyline([(50, 430), (500, 430), (500, 500), (50, 500)],
        closed: true),
  ],
);

/// `translate(x, y) · R(theta) · diag(sx, sy)`, written out.
Transform2 embeddingPlacement(double x, double y, double degrees,
    {double sx = 1, double sy = 1}) {
  final t = degrees * math.pi / 180;
  final cos = math.cos(t), sin = math.sin(t);
  return Transform2(sx * cos, sx * sin, -sy * sin, sy * cos, x, y);
}

/// One table of the fixture, as the test knows it.
final class EditorTable {
  const EditorTable(this.label, this.transform, {this.layer = '0'});

  /// The label written, or null for an unlabelled table.
  final String? label;
  final Transform2 transform;
  final String layer;
}

/// The fixture's tables in placement order (ascending by handle), as
/// today's `editorTables` (editor_fixture.dart:75-87).
final List<EditorTable> editorTables = [
  EditorTable('1', embeddingPlacement(21650, 15800, 30)),
  const EditorTable('2', Transform2(0, 1, 1, 0, 23100, 15600)),
  EditorTable('7', embeddingPlacement(22900, 14550, 60)),
  EditorTable(' 7 ', embeddingPlacement(25000, 15250, -150, sy: -1)),
  EditorTable(null, embeddingPlacement(21550, 14800, 15)),
  EditorTable('5', embeddingPlacement(24600, 13350, 45),
      layer: kEmbeddingHidden),
  EditorTable('L', embeddingPlacement(25200, 15500, 120, sy: -1),
      layer: kEmbeddingLocked),
];

final Transform2 editorChairPlacement = embeddingPlacement(23800, 16100, 10);
final Transform2 editorGroupPlacement = embeddingPlacement(21600, 13450, 20);
final (Vector2, Vector2) editorFreeLine =
    (Vector2(22700, 13400), Vector2(23300, 14300));
final Vector2 editorTextAt = Vector2(21700, 14250);
const double editorTextHeight = 200;
const String editorTextWords = 'Bar';

/// The north wall's stand-in, its inner face's, and the parquet hairline
/// through table 1's top (local (500, 0) of `1` is (22,083, 16,050)).
final (Vector2, Vector2) editorNorthWall =
    (Vector2(21400, 16850), Vector2(26400, 16850));
final (Vector2, Vector2) editorInnerFace =
    (Vector2(21400, 16750), Vector2(26400, 16750));
final (Vector2, Vector2) editorHairline =
    (Vector2(21900, 16050), Vector2(22300, 16050));

/// The column: a 400 x 400 square, its west edge through (23,500, 14,000).
const List<(double, double)> editorColumn = [
  (23500, 13800),
  (23900, 13800),
  (23900, 14200),
  (23500, 14200),
];

/// The fixture's plan, as a plan file over [fxKit].
String unitEditorPlanJson() => planText([fxKit()], (doc) {
      final zero = ReservedHandles.layerZero;
      final hidden = addLayer(doc, kEmbeddingHidden, visible: false);
      final locked = addLayer(doc, kEmbeddingLocked, locked: true);
      for (final t in editorTables) {
        final h = placeUnit(doc, embeddingTable,
            transform: t.transform,
            layer: switch (t.layer) {
              kEmbeddingHidden => hidden,
              kEmbeddingLocked => locked,
              _ => zero,
            });
        if (t.label case final label?) addUnitLabel(doc, h, label);
      }
      final group = doc.handleSeed.next();
      doc.commands.execute(AddNodeCommand(GroupNode(
          handle: group,
          parent: doc.rootHandle,
          transform: editorGroupPlacement,
          children: const [])));
      for (final (a, b) in [
        (Vector2(100, 100), Vector2(900, 400)),
        (Vector2(100, 400), Vector2(900, 100)),
      ]) {
        doc.commands.execute(AddEntityCommand(
            record: draftRecord(doc.handleSeed.next(), group, EntityKind.line,
                layer: zero),
            payload: linePayload(a, b)));
      }
      for (final (a, b) in [
        editorFreeLine,
        editorNorthWall,
        editorInnerFace,
        editorHairline,
      ]) {
        doc.commands.execute(
            addDrafted(doc, EntityKind.line, linePayload(a, b), layer: zero));
      }
      doc.commands.execute(addDrafted(
          doc,
          EntityKind.polyline,
          polylinePayload([for (final (x, y) in editorColumn) Vector2(x, y)],
              closed: true),
          layer: zero));
      doc.commands.execute(addDrafted(
          doc, EntityKind.text, textPayload(editorTextAt, editorTextHeight),
          layer: zero, text: editorTextWords));
      placeUnit(doc, editorChair, transform: editorChairPlacement);
      doc.commands.clearHistory();
    });

/// The camera every editor test runs under: 0.37 px/mm, y flipped, panned
/// so world (21,400, 17,070) is the canvas's top left.
ViewportTransform editorCamera() => ViewportTransform(
    worldToScreenMatrix: Transform2(0.37, 0, 0, -0.37, -7918, 6315.9));

/// The editor over [unitEditorPlanJson] under [permissions], in
/// [kEditorSurface], under [editorCamera]. The controller is disposed at
/// tear-down.
Future<PlanController> mountUnitEditor(WidgetTester tester,
    {PlanPermissions permissions = PlanPermissions.full}) async {
  final c = PlanController(kits: [fxKit()], json: unitEditorPlanJson());
  addTearDown(c.dispose);
  c.permissions = permissions;
  await tester.binding.setSurfaceSize(kEditorSurface);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
      MaterialApp(home: Scaffold(body: PlanEditor(controller: c))));
  await tester.pump();
  await tester.pump();
  c.camera.value = editorCamera();
  await tester.pump();
  return c;
}

/// Today's `setCaps`: the permissions changed at runtime, one pump.
Future<void> setPermissions(
    WidgetTester tester, PlanController c, PlanPermissions p) async {
  c.permissions = p;
  await tester.pump();
}

Offset canvasOrigin(WidgetTester tester) =>
    tester.getTopLeft(find.byType(InteractionLayer));

/// World [w] on the screen, by the camera's forward transform.
Offset screenOf(WidgetTester tester, PlanController c, Vector2 w) {
  final m = c.camera.value.worldToScreenMatrix;
  return canvasOrigin(tester) +
      Offset(m.a * w.x + m.c * w.y + m.e, m.b * w.x + m.d * w.y + m.f);
}

/// The plan's units, read now (the fixture kit loaded: nothing locked by a
/// missing kit).
UnitIndex unitsIn(PlanController c) => UnitIndex.of(c.document,
    catalog: c.catalog,
    locks: LockSet.scan(c.document, (kit) => c.kits.kitOf(kit) != null));

/// Table [n]'s instance; ` 7 ` is the later of the two sevens, null the
/// unlabelled one.
Handle tableOf(PlanController c, String? n) {
  final index = unitsIn(c);
  if (n == null) return index.units.singleWhere((u) => u.text == null).instance;
  return index.withLabel(n)[n == ' 7 ' ? 1 : 0].instance;
}

/// The world centre of table [n]'s box, by the fixture's own transform.
Vector2 centreOf(PlanController c, String n) {
  final node = c.document.tree[tableOf(c, n)]! as InstanceNode;
  return node.transform.transformPoint(Vector2(700, 100));
}

Future<void> click(WidgetTester tester, Offset at) async {
  final g = await tester.createGesture(kind: ui.PointerDeviceKind.mouse);
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

Future<bool> press(WidgetTester tester, LogicalKeyboardKey key) async {
  final handled = await tester.sendKeyEvent(key);
  await tester.pump();
  return handled;
}

/// The plan's kit set for a controller over [unitEditorPlanJson].
List<PlanKit> editorKits() => [fxKit()];
```

- [ ] **Step 2: The failing tests (new).** Create `test/tools/design_selection_test.dart`. It drives `plan.select` without a canvas (`tool_events.dart`) over Task 5's `serviceFixture()` (a turned, mirrored table off the origin; two rows off the origin, one turned, one curved; the test kit's `test.row` is seats-only). The handles are found from the document, not from the fixture's return value, so only its plan text is read.

```dart
// 2b Task 8, spec S2 "In design, a generated unit stands for its object"
// and decision 9; S4 selectUnitsOnly, relabel, the profiles. plan.select is
// driven without a canvas (tool_events.dart) under the rotated, flipped,
// off-origin test camera, over Task 5's service fixture: a turned, mirrored
// table off the origin and two seats-only rows off the origin, one turned,
// one curved.
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter/gestures.dart' show kPrimaryButton;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/kits/locks.dart' show LockSet;
import 'package:jet_cad_2d_plan/src/service/unit_picker.dart';
import 'package:jet_cad_2d_plan/src/symbols/symbol_placer.dart'
    show definitionForEntry;
import 'package:jet_cad_2d_plan/src/units/unit_index.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/harness.dart';
import '../support/test_kit.dart';
import '../support/service_fixture.dart' show serviceFixture;
import '../support/tool_events.dart';
import '../support/unit_editor_fixture.dart' show editorChair;
import '../support/unit_fixtures.dart' show entryOf, fxKit, tableSymbol;

/// Task 5's fixture's plan text.
String fixtureText() => serviceFixture().json;

PlanController design({List<PlanKit>? kits}) {
  final c = controllerFor(kits: kits ?? [unitKit()], json: fixtureText());
  useTestCamera(c);
  return c;
}

/// The root-level objects of the test kit's row type, ascending.
List<Handle> rowsOf(PlanController c) {
  final d = c.document;
  final root = d.tree[d.rootHandle]! as GroupNode;
  return [
    for (final h in d.tree.childNodesOf(root.children))
      if (d.components.unknownOf(h).isNotEmpty ||
          c.catalog.typeIdOf(d, h) != null)
        if (d.tree[h] is GroupNode) h,
  ]..sort((a, b) => a.value.compareTo(b.value));
}

/// The seats of [row], ascending.
List<Handle> seatsOf(PlanController c, Handle row) {
  final d = c.document;
  final g = d.tree[row]! as GroupNode;
  return [
    for (final h in d.tree.childNodesOf(g.children))
      if (d.tree[h] is InstanceNode) h,
  ]..sort((a, b) => a.value.compareTo(b.value));
}

/// The placed table: the root-level instance of a unit definition.
Handle tableIn(PlanController c) {
  final d = c.document;
  final root = d.tree[d.rootHandle]! as GroupNode;
  return d.tree.childNodesOf(root.children).singleWhere((h) =>
      d.tree[h] is InstanceNode &&
      d.components.get<UnitComponent>((d.tree[h]! as InstanceNode).definition) !=
          null);
}

/// [seat]'s outline's first vertex (its definition's lowest-handle leaf)
/// in the world.
Vector2 seatCorner(PlanController c, Handle seat) {
  final d = c.document;
  final def = (d.tree[seat]! as InstanceNode).definition;
  final leaf = d.entities.liveSlots
      .where((s) => d.entities.ownerAt(s) == def)
      .reduce((a, b) =>
          d.entities.handleAt(a).value < d.entities.handleAt(b).value ? a : b);
  final p = d.geometry.read(d.entities.geomIndexAt(leaf)).coords;
  return d.tree.accumulatedTransform(seat).transformPoint(Vector2(p[0], p[1]));
}

/// [seat]'s UNIT label's anchor in the world.
Vector2 seatLabel(PlanController c, Handle seat) {
  final d = c.document;
  final slot = d.entities.liveSlots.firstWhere((s) =>
      d.entities.ownerAt(s) == seat &&
      d.entities.kindAt(s) == EntityKind.attrib);
  final p = d.geometry.read(d.entities.geomIndexAt(slot)).coords;
  return d.tree.accumulatedTransform(seat).transformPoint(Vector2(p[0], p[1]));
}

/// The world box of [row]'s seats (their definitions' boxes through their
/// world transforms).
Aabb2 rowBox(PlanController c, Handle row) {
  final d = c.document;
  var box = Aabb2.empty();
  for (final s in seatsOf(c, row)) {
    final def = (d.tree[s]! as InstanceNode).definition;
    box = box.union(d
        .definitionBounds(def, d.leavesByOwner())
        .transformedBy(d.tree.accumulatedTransform(s)));
  }
  return box;
}

/// A band drag around [box] inflated by [pad] screen pixels: a window
/// (screen left to right) or a crossing (right to left).
void band(PlanController c, Aabb2 box, {required bool window, double pad = 8}) {
  final cam = c.toolController.context.camera.value;
  final corners = [
    for (final (x, y) in [
      (box.minX, box.minY),
      (box.maxX, box.minY),
      (box.maxX, box.maxY),
      (box.minX, box.maxY),
    ])
      cam.worldToScreen(Vector2(x, y)),
  ];
  final xs = corners.map((p) => p.x), ys = corners.map((p) => p.y);
  final a = Vector2(xs.reduce((p, q) => p < q ? p : q) - pad,
      ys.reduce((p, q) => p < q ? p : q) - pad);
  final b = Vector2(xs.reduce((p, q) => p > q ? p : q) + pad,
      ys.reduce((p, q) => p > q ? p : q) + pad);
  final from = cam.screenToWorld(window ? a : b);
  final to = cam.screenToWorld(window ? b : a);
  dragFrom(c, from, to);
}

Set<SelectionKey> selected(PlanController c) => {...c.selection.keys};

void main() {
  test('DS-0 premise: two rows of seats, a table, the camera off identity',
      () {
    final c = design();
    expect(rowsOf(c), hasLength(2));
    for (final row in rowsOf(c)) {
      expect(seatsOf(c, row), isNotEmpty);
      expect(c.catalog.typeIdOf(c.document, row), 'test.row');
    }
    expect(tableIn(c), isNotNull);
    expect(c.toolController.context.camera.value.worldToScreenMatrix.b,
        isNot(0));
  });

  test(
      'DS-click-seat a click and a hover on a seat\'s outline name its row; '
      'the gates replace the pick', () {
    final c = design();
    final row = rowsOf(c).first;
    final seat = seatsOf(c, row)[1];
    expect(c.selectGates.restrictsPick, isTrue);
    final tools = c.toolController;
    tools.active.onPointerMove(eventAt(c, seatCorner(c, seat)), tools.context);
    // M-DS1: the mapping removed from `pick` (the seat's key returned).
    expect(c.selection.hover, SelectionKey.root(row), reason: 'the hover');
    tapAt(c, seatCorner(c, seat));
    expect(selected(c), {SelectionKey.root(row)});
  });

  test('DS-click-attrib a click on a seat\'s label selects its row', () {
    final c = design();
    final row = rowsOf(c).last;
    final seat = seatsOf(c, row).first;
    tapAt(c, seatLabel(c, seat));
    // M-DS2: `resolveHit` replaced by the hit's own entity in `pick`.
    expect(selected(c), {SelectionKey.root(row)});
  });

  test('DS-crossing a crossing band over a seats-only row takes the row, no '
      'seat', () {
    final c = design();
    final row = rowsOf(c).first;
    band(c, rowBox(c, row), window: false);
    // M-DS3: `bandAccepts` answering true (the seats' keys let through).
    expect(selected(c), {SelectionKey.root(row)});
  });

  test(
      'DS-window a window band over a seats-only row selects nothing, no '
      'seat included (decision 9, a known limit)', () {
    final c = design();
    final row = rowsOf(c).first;
    band(c, rowBox(c, row), window: true);
    // M-DS3: `bandAccepts` answering true lets every seat in.
    expect(selected(c), isEmpty);
  });

  test(
      'DS-locked-object a row whose kit is missing: a click on a seat names '
      'the row (a lock-set object)', () {
    final c = design(kits: const []);
    final row = rowsOf(c).first;
    expect(c.locked.value, contains(row), reason: 'premise: held');
    expect(c.catalog.typeIdOf(c.document, row), isNull, reason: 'premise');
    tapAt(c, seatCorner(c, seatsOf(c, row).first));
    // M-DS4: `|| locked.contains(current)` dropped from the mapping.
    expect(selected(c), {SelectionKey.root(row)});
  });

  test(
      'DS-plain-group a table inside a plain group: the click and the band '
      'select what the bare select tool selects (today\'s selection)', () {
    final text = planText([testKit(), fxKit()], (d) {
      final g = d.handleSeed.next();
      d.commands.execute(AddNodeCommand(GroupNode(
          handle: g,
          parent: d.rootHandle,
          transform: Transform2.translation(4100.5, -1250.25)
              .multiply(Transform2.rotation(0.4)),
          children: const [])));
      final made = definitionForEntry(d, entryOf(tableSymbol()));
      final t = d.handleSeed.next();
      d.commands.execute(CompoundCommand([
        ...made.commands,
        AddNodeCommand(InstanceNode(
            handle: t,
            parent: g,
            definition: made.definition,
            layer: ReservedHandles.layerZero,
            transform: Transform2.translation(300.25, 200.5))),
      ]));
    });
    final c = controllerFor(kits: [testKit(), fxKit()], json: text);
    useTestCamera(c);
    final d = c.document;
    final table = d.tree.nodes.whereType<InstanceNode>().single.handle;
    final corner = d.tree.accumulatedTransform(table).transformPoint(
        Vector2(300, 300));
    // The bare tool on its own selection, the same document and camera.
    final bareSelection = SelectionController(d);
    addTearDown(bareSelection.dispose);
    final bare = SelectTool();
    final ctx = ToolContext(
        document: d,
        index: c.index,
        camera: c.toolController.context.camera,
        selection: bareSelection,
        page: c.page,
        snap: SnapSettings());
    bare.onPointerDown(
        eventAt(c, corner, buttons: kPrimaryButton), ctx);
    bare.onPointerUp(eventAt(c, corner), ctx);
    tapAt(c, corner);
    // M-DS5: the type and lock condition dropped (every root group maps).
    expect(selected(c), {...bareSelection.keys});
    expect(selected(c), {SelectionKey.root(table)});
  });

  test(
      'DS-units-only selectUnitsOnly: a seat is passed over, the table\'s '
      'top selects it, a crossing band over everything keeps the table '
      'alone', () {
    final c = design();
    c.permissions = PlanPermissions.unitsOnly;
    final row = rowsOf(c).first;
    tapAt(c, seatCorner(c, seatsOf(c, row).first));
    // M-DS6: the session's picker built without `placedOnly`.
    expect(selected(c), isEmpty, reason: 'a seat is no placed unit');
    final table = tableIn(c);
    final node = c.document.tree[table]! as InstanceNode;
    // The centre of the table's top (its first leaf, a closed outline):
    // inside the top, away from its lines.
    final top = c.document
        .definitionBounds(node.definition, c.document.leavesByOwner());
    tapAt(
        c,
        node.transform.transformPoint(
            Vector2((top.minX + top.maxX) / 2, (top.minY + top.maxY) / 2)));
    expect(selected(c), {SelectionKey.root(table)});
    c.selection.clear();
    var all = Aabb2.empty();
    for (final r in rowsOf(c)) {
      all = all.union(rowBox(c, r));
    }
    all = all.union(c.document
        .definitionBounds(node.definition, c.document.leavesByOwner())
        .transformedBy(node.transform));
    band(c, all, window: false, pad: 40);
    // M-DS7: the selectUnitsOnly branch of `bandAccepts` removed.
    expect(selected(c), {SelectionKey.root(table)});
  });

  test(
      'DS-prune selectUnitsOnly turned on keeps only the selection\'s placed '
      'units', () {
    final c = design();
    final row = rowsOf(c).first;
    final table = tableIn(c);
    final line = addLine(c.document, Vector2(-900.5, 300.25),
        Vector2(-200.75, 950.5));
    c.selection.replace([
      SelectionKey.root(table),
      SelectionKey.root(row),
      SelectionKey.root(line),
    ]);
    c.permissions = PlanPermissions.unitsOnly;
    // M-DS8: the prune in the permissions setter removed.
    expect(selected(c), {SelectionKey.root(table)});
  });

  test(
      'DS-picker-seat the picker finds a generated seat by its top in the '
      'world (group × instance), not at its local place', () {
    final c = design();
    final row = rowsOf(c).first;
    final seat = seatsOf(c, row)[2];
    final locked = ValueNotifier<Set<Handle>>(const {});
    addTearDown(locked.dispose);
    final units = UnitIndexCache(c.document,
        catalog: c.catalog,
        locks: LockSet.scan(c.document, (k) => c.kits.kitOf(k) != null),
        locked: locked);
    addTearDown(units.dispose);
    final picker = UnitPicker(c.document, units);
    final d = c.document;
    final def = (d.tree[seat]! as InstanceNode).definition;
    final box = d.definitionBounds(def, d.leavesByOwner());
    final centre = Vector2((box.minX + box.maxX) / 2, (box.minY + box.maxY) / 2);
    final world = d.tree.accumulatedTransform(seat).transformPoint(centre);
    // M-DS9: candidatesOf reads the instance's own transform, not toWorld.
    expect(picker.pick(world)?.instance, seat);
    expect(picker.pick(world)?.generated, isTrue);
    expect(UnitPicker(c.document, units, placedOnly: true).pick(world), isNull);
  });

  test(
      'DS-perm relabel is an edit and readOnly turns it off; the service '
      'flags are not edits; isUnitSymbol admits any unit, a seat included',
      () {
    expect(PlanPermissions.readOnly.relabel, isFalse);
    // M-DS10: `relabel ||` dropped from `edits`.
    expect(PlanPermissions.readOnly.copyWith(relabel: true).edits, isTrue);
    expect(
        PlanPermissions.readOnly
            .copyWith(serviceMove: true, serviceMerge: true, selectUnitsOnly: true)
            .draft,
        same(DraftPermissions.readOnly));
    PlanSymbol symbol(SymbolEntry e) =>
        PlanSymbol(kitId: 'fx', names: KitNames.empty, entry: e);
    final seat = entryOf(tableSymbol(key: 'fx.seat.single', seats: 1));
    final seatEntry = SymbolEntry(
        symbol: seat.symbol,
        unit: UnitComponent(
            kind: UnitKinds.seat,
            capacity: 1,
            labelling: UnitLabelling.assigned),
        definition: seat.definition,
        leaves: seat.leaves);
    expect(isUnitSymbol(symbol(entryOf(tableSymbol()))), isTrue);
    // M-DS11: isUnitSymbol reading `unit?.kind == UnitKinds.table`.
    expect(isUnitSymbol(symbol(seatEntry)), isTrue);
    expect(isUnitSymbol(symbol(entryOf(editorChair))), isFalse);
  });
}
```

  Notes for the implementer: an import the analyzer flags as unused is deleted, never silenced. `SnapSettings()` is `jet_cad_2d_flutter`'s (`snap_settings.dart:6`); `ToolContext` takes exactly these (`document`, `index`, `camera`, `selection` required; `page`, `snap`, `grips` optional: `jet_cad_2d_flutter/lib/src/tool.dart:83-91`). Task 5's `serviceFixture()` returns a record whose `json` is the plan text.

- [ ] **Step 3: The failing tests (2a's grown).**
  1. `test/controller/permissions_test.dart`: replace `kFlagNames`, `flagsOf`, `copyFlag`, `kGateFlag` and `kReadOnly` (whatever Task 3 left in them) with:

```dart
/// Every flag, in declaration order.
const List<String> kFlagNames = [
  'move',
  'rotate',
  'mirror',
  'reshape',
  'delete',
  'changeLayer',
  'recolor',
  'editLayers',
  'editPage',
  'relabel',
  'undo',
  'export',
  'print',
  'selectUnitsOnly',
  'serviceMove',
  'serviceMerge',
];

Map<String, bool> flagsOf(P p) => {
      'move': p.move,
      'rotate': p.rotate,
      'mirror': p.mirror,
      'reshape': p.reshape,
      'delete': p.delete,
      'changeLayer': p.changeLayer,
      'recolor': p.recolor,
      'editLayers': p.editLayers,
      'editPage': p.editPage,
      'relabel': p.relabel,
      'undo': p.undo,
      'export': p.export,
      'print': p.print,
      'selectUnitsOnly': p.selectUnitsOnly,
      'serviceMove': p.serviceMove,
      'serviceMerge': p.serviceMerge,
    };

P copyFlag(P p, String name, bool v) => switch (name) {
      'move' => p.copyWith(move: v),
      'rotate' => p.copyWith(rotate: v),
      'mirror' => p.copyWith(mirror: v),
      'reshape' => p.copyWith(reshape: v),
      'delete' => p.copyWith(delete: v),
      'changeLayer' => p.copyWith(changeLayer: v),
      'recolor' => p.copyWith(recolor: v),
      'editLayers' => p.copyWith(editLayers: v),
      'editPage' => p.copyWith(editPage: v),
      'relabel' => p.copyWith(relabel: v),
      'undo' => p.copyWith(undo: v),
      'export' => p.copyWith(export: v),
      'print' => p.copyWith(print: v),
      'selectUnitsOnly' => p.copyWith(selectUnitsOnly: v),
      'serviceMove' => p.copyWith(serviceMove: v),
      'serviceMerge' => p.copyWith(serviceMerge: v),
      _ => throw ArgumentError(name),
    };

/// The flag each gate reads (spec P3: a gate names a PlanPermissions flag).
const Map<PlanGate, String> kGateFlag = {
  PlanGate.move: 'move',
  PlanGate.rotate: 'rotate',
  PlanGate.mirror: 'mirror',
  PlanGate.reshape: 'reshape',
  PlanGate.delete: 'delete',
  PlanGate.changeLayer: 'changeLayer',
  PlanGate.recolor: 'recolor',
  PlanGate.editLayers: 'editLayers',
  PlanGate.editPage: 'editPage',
  PlanGate.relabel: 'relabel',
};

/// readOnly's flags, as spec P2 and today's S-12 list them (relabel is
/// today's renumber, off in readOnly).
const Map<String, bool> kReadOnly = {
  'move': false,
  'rotate': false,
  'mirror': false,
  'reshape': false,
  'delete': false,
  'changeLayer': false,
  'recolor': false,
  'editLayers': false,
  'editPage': false,
  'relabel': false,
  'undo': false,
  'export': true,
  'print': true,
  'selectUnitsOnly': false,
  'serviceMove': true,
  'serviceMerge': true,
};

/// unitsOnly's flags (today's tablesOnly, editor_capabilities.dart:175-190,
/// restricted to PlanPermissions' fields; spec S4).
const Map<String, bool> kUnitsOnly = {
  'move': true,
  'rotate': true,
  'mirror': false,
  'reshape': false,
  'delete': true,
  'changeLayer': false,
  'recolor': true,
  'editLayers': false,
  'editPage': false,
  'relabel': true,
  'undo': true,
  'export': true,
  'print': true,
  'selectUnitsOnly': true,
  'serviceMove': true,
  'serviceMerge': true,
};
```

     In PM-1, the line `expect(flagsOf(P.full), {for (final n in kFlagNames) n: true});` becomes `expect(flagsOf(P.full), {for (final n in kFlagNames) n: n != 'selectUnitsOnly'});` (today's EC2, `editor_capabilities_test.dart:132-134`: a restriction is false in full), and PM-1 gains at its end:

```dart
    // EC2's tablesOnly half (editor_capabilities_test.dart:137-160), on
    // PlanPermissions' fields.
    expect(P.unitsOnly.tools, {'plan.select', 'plan.symbol'});
    // M-PM1b: unitsOnly's `selectUnitsOnly: true` dropped.
    expect(flagsOf(P.unitsOnly), kUnitsOnly);
```

     In PM-2, `for (final base in [P.full, P.readOnly])` becomes `[P.full, P.readOnly, P.unitsOnly]`. In PM-3 add `expect(P.unitsOnly == P.readOnly, isFalse); expect(identical(P.unitsOnly, P.unitsOnly), isTrue); expect(P.unitsOnly, P.unitsOnly.copyWith());`. In PM-6 the first loop stays `kFlagNames.take(9)` (move .. editPage), and the second loop's list becomes `['undo', 'export', 'print', 'selectUnitsOnly', 'serviceMove', 'serviceMerge']`, with `copyFlag(P.readOnly, name, !kReadOnly[name]!)` in place of `copyFlag(P.readOnly, name, true)` (the three service-side flags are on in readOnly already: each is turned the other way, and none is an edit). PM-7's readOnly text becomes `'PlanPermissions(tools: {plan.select}, move: false, rotate: false, mirror: false, reshape: false, delete: false, changeLayer: false, recolor: false, editLayers: false, editPage: false, relabel: false, undo: false)'` and PM-7 gains:

```dart
    // EC5's tablesOnly text (editor_capabilities_test.dart:266-271), on
    // PlanPermissions' fields: a restriction prints when on.
    // M-PM7b: toString printing only the flags that are false.
    expect(
        P.unitsOnly.toString(),
        'PlanPermissions(tools: {plan.select, plan.symbol}, mirror: false, '
        'reshape: false, changeLayer: false, editLayers: false, '
        'editPage: false, selectUnitsOnly: true)');
```

     Add, after PM-7, the port of EC3b (`editor_capabilities_test.dart:386-435`, its alternating bases over `PlanPermissions`' sixteen flags; the assertions unchanged, the `rulers`/`grid` premise line becomes `expect(base.relabel, isNot(base.editPage));`):

```dart
  // EC3b (editor_capabilities_test.dart:386-435): two bases whose flags
  // alternate, so a field copied from its neighbour is seen.
  test(
      'EC3b copyWith on two bases whose flags alternate: no argument keeps '
      'every field, each flag replaces that field alone', () {
    P alternating(bool first) {
      final v = [for (var i = 0; i < kFlagNames.length; i++) i.isEven == first];
      return P(
        tools: const {'plan.select', 'plan.line', 'plan.symbol'},
        move: v[0],
        rotate: v[1],
        mirror: v[2],
        reshape: v[3],
        delete: v[4],
        changeLayer: v[5],
        recolor: v[6],
        editLayers: v[7],
        editPage: v[8],
        relabel: v[9],
        undo: v[10],
        export: v[11],
        print: v[12],
        selectUnitsOnly: v[13],
        serviceMove: v[14],
        serviceMerge: v[15],
      );
    }

    for (final first in [true, false]) {
      final base = alternating(first);
      final flags = flagsOf(base);
      for (final (i, name) in kFlagNames.indexed) {
        expect(flags[name], i.isEven == first, reason: name);
      }
      expect(base.relabel, isNot(base.editPage));
      final kept = base.copyWith();
      expect(flagsOf(kept), flags, reason: 'copyWith() on $base');
      expect(kept.tools, {'plan.select', 'plan.line', 'plan.symbol'});
      for (final name in kFlagNames) {
        // M-PM2b: `serviceMerge: serviceMerge ?? this.serviceMove`.
        expect(flagsOf(copyFlag(base, name, !flags[name]!)),
            {...flags, name: !flags[name]!},
            reason: '$name on $base');
      }
    }
  });
```

     These are 2a's own tests (not ports, A12 does not bind them); each change grows them with the type, and no expectation they held is dropped.
  2. `test/tools/plan_select_gates_test.dart`: the `Rig` builds the gates with the new arguments, and PM-8's last line follows spec S2:

```dart
    selection = SelectionController(document);
    final units = UnitIndexCache(document,
        catalog: catalog,
        locks: LockSet.scan(document, (_) => true),
        locked: locked);
    final picker = UnitPicker(document, units,
        skipLocked: true, placedOnly: true);
    gates = PlanSelectGates(
        permissions: () => permissions,
        selection: selection,
        locked: locked,
        catalog: catalog,
        picker: () => picker,
        units: () => units.current);
    addTearDown(() {
      gates.dispose();
      units.dispose();
      selection.dispose();
      locked.dispose();
    });
```

     with a field `final ParametricCatalog catalog = ParametricCatalog();` and the imports of `unit_picker.dart`, `unit_index.dart` and `LockSet`. PM-11 passes the same new arguments to its own `PlanSelectGates` (a `ParametricCatalog()`, a picker and a cache over its document, disposed after the assertions). In PM-8, `// The pick and the band are the select tool's own.` / `expect(r.gates.restrictsPick, isFalse);` becomes `// 2b S2: the design's pick maps a generated unit to its object.` / `expect(r.gates.restrictsPick, isTrue);` (spec S2 supersedes 2a's premise; a 2a test, not a port).
  3. `test/barrel_test.dart`: in ED-9's expected set, add the line `// 2b Task 8` / `'isUnitSymbol',` after the Task 20 group.

- [ ] **Step 4: The ported tests.**
  1. `test/service/unit_picker_test.dart` from `jet_cad_floor_plan/test/service/table_picker_test.dart`, the whole file, its ids suffixed `K` (`TPK…`; Task 7 ports `table_placement_test.dart`'s TP1-TP7 under their source ids): TPK1, TPK2, TPK3, TPK4, TPK5, TPK6, TPK7, TPK7b, TPK10, TPK11, TPK12, TPK8, TPK9, TPK13, TPK14. **Assertions unchanged.** Adaptations:
     - imports: `unit_picker.dart`, `unit_fixtures.dart`, `harness.dart` (`addLine`), `unit_index.dart`; no `table_index`, `table_label`, `symbol_placer` of the old package.
     - `plan()` → `unitPlan()`; `placeTurned(doc, s, at)` and `worldOf` → the fixture's (same semantics; the symbol a `CatalogSymbol`); `placeSymbol(doc, entryOf(s), at: at, mirrored: m)` + `doc.commands.execute` → `placeAt(doc, s, at, mirrored: m)`; `nodes.whereType<InstanceNode>()` reads unchanged.
     - `TablePicker(doc)` → `pickerOf(doc)`; `TablePicker(doc, leavesByOwner: f)` → `pickerOf(doc, leavesByOwner: f)`; `TablePicker(doc, invert: f)` → `pickerOf(doc, invert: f)`; `TablePicker.candidatesOf(doc, boxes: {}, leaves: doc.leavesByOwner)` → `UnitPicker.candidatesOf(doc, unitsOf(doc).current, boxes: {}, leaves: doc.leavesByOwner)`.
     - `picker.pick(p)?.table.instance` → `picker.pick(p)?.instance`; `hit.table.instance` → `hit.instance`; `hit.locked` unchanged; `picker.candidates.map((c) => c.table.instance)` → `.map((c) => c.unit.instance)`; `tableTopOf` → `unitTopOf`; `TableSurvey.of(doc).tables` (TPK14) → `unitsOf(doc).current.units`, `t.instance` unchanged.
     - TPK2's wall (an ATTRIB-shaped record turned into a line, `:91-97`) → `addLine(doc, a, b)` (a root-level line between the same points).
     - TPK12's keys `test.table.a`/`.b` → `fx.table.a`/`fx.table.b` (K2 keys have three segments).
     - The fixture symbols: `tableSymbol`, `stoolSymbol`, `trapezoidTable`, the inline `sideChair` → `sideChairTable`, the inline `open` → `openTable` (each the same shapes and base point).
  2. `test/editor/units_only_select_test.dart` from `jet_cad_floor_plan/test/host/editor_select_test.dart`, the `selectTablesOnly` and `tablesOnly` cases: "M-H42 tablesOnly: a window and a crossing band over the whole canvas …" (`:145-184`), "M-H42 S-15 a click on a wall line … inside its box off its top too" (`:186-221`), "S-15 a finger reaches a table within its reach …" (`:223-235`), "the tables on the hidden and the locked layers are never selected …" (`:237-264`), "T5-a readOnly: a body drag of 1 executes nothing; tablesOnly: it moves 1 by the drag" (`:268-292`), "S-9 h a body drag of 1 started under tablesOnly …" (`:381-398`), the two R-1 cases that switch to tablesOnly mid-drag (`:495-532`, `:532-582`), R-3 (`:643-662`), R-5 (`:663-677`), R-4 (`:679-694`). **Assertions unchanged.** Adaptations:
     - `t.mountEditor(tester, caps: Caps.X)` → `mountUnitEditor(tester, permissions: PlanPermissions.X)` with `tablesOnly` → `unitsOnly`, `readOnly` → `readOnly`, `full` → `full`, `Caps.tablesOnly.copyWith(f: v)` → `PlanPermissions.unitsOnly.copyWith(f: v)`; `setCaps(tester, h, caps)` → `setPermissions(tester, c, permissions)`.
     - `c.activeDocument` → `c.document`; `c.activeSelection` → `c.selection`; `c.cameraController.value` → `c.camera.value`; `t.screenOf`, `t.click`, `t.press`, `t.centreOf` → the editor fixture's; `tableOf`, `keyOf`, `transformOf`, `onTable`, `topOf`, `boxOf`, `edgeOf`, `selected`, `drag`, `fingerTap`, `canvasRect`, `degreesOf` copied from `editor_select_test.dart:30-141` with `TableSurvey.of(c.activeDocument).withNumber(n)` → `unitsIn(c).withLabel(n)` and the unlabelled table found as `unitsIn(c).units.singleWhere((u) => u.text == null).instance`.
     - `encoded(c)` → `DraftDocumentCodec.encodeToString(c.document)`.
     - The north wall: `wallEnds(d, wall)` → the selected line's two points (`coordsOf(d, wall)` from `harness.dart`); `c.activeDocument.components.get<WallParams>(wall.target)` (`:202-203`) → `c.document.entities.kindAt(c.document.entities.slotOf(wall.target)!) == EntityKind.line` is true; `liveObjectsOf<WallParams>(d), contains(wall)` (`:509-510`) → the same kind check; "the column" is the fixture's square.
     - The chair's grip (R-1, `:532-582`): `editorChairPlacement` is the fixture's; `gripsOf(tester)` → `c.grips` (2a's `@internal` getter); `t.canvasOrigin(tester)` → `canvasOrigin(tester)`.
     - The cases that read `selectedTables`, `setTableData`, `tableDetails` (T5-c, T5-d) and the rotate buttons (T5-b) are not ported here: T5-c and T5-d go to Task 9 (they read its API), T5-b to Task 10 (the unit section's ±90 buttons). M-H43c, the gatesChanged case and the third R-1 case have no tables-only premise (2a's ground).

- [ ] **Step 5: Run the tests, see them fail.** Run: `cd packages/jet_cad_2d_plan && flutter test test/tools/design_selection_test.dart test/service/unit_picker_test.dart test/controller/permissions_test.dart test/tools/plan_select_gates_test.dart`. Expected: compile errors — `unitsOnly`, `selectUnitsOnly`, `serviceMove`, `serviceMerge`, `isUnitSymbol`, `UnitPicker`, `unitTopOf` and the gates' new arguments are not defined.

- [ ] **Step 6: The permissions.** Replace `lib/src/controller/permissions.dart` whole:

```dart
// Spec P2 "Permissions" (2a) and 2b S4 "Permissions": what the plan's
// widgets let their user do. The select gates, the palette and selectTool,
// the panels and the controller's widget-facing commands read it; a host's
// own calls are not gated. 2b adds relabel (today's renumber),
// selectUnitsOnly (today's selectTablesOnly), the two service flags
// (serviceMove, today's view parameter serviceMoves; serviceMerge, Merge and
// Split), the unitsOnly profile and the gallery filter isUnitSymbol.
import 'package:flutter/foundation.dart' show immutable, setEquals;
import 'package:jet_cad_2d/jet_cad_2d.dart' show DraftPermissions;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show PlanGate;

import '../symbols/plan_symbol.dart';

/// The editor's permissions (spec P2, 2b S4).
///
/// - [tools]: the tool ids offered (the palette, the letters,
///   `PlanController.selectTool`); null offers every tool. `plan.select` is
///   always offered, whatever the set says. [copyWith] copies the set it
///   is given, unmodifiable; the `const` constructor keeps the set as
///   given.
/// - [move], [rotate], [mirror], [reshape], [delete]: the select tool's
///   gates and the panel's matching fields; [changeLayer], [recolor]: the
///   panel's layer field and colour row; [editLayers], [editPage]: the
///   Layer and Page panels; [relabel]: the unit section's label field;
///   [undo]: the Undo and Redo buttons and chords; [export], [print]:
///   theirs. A property spec's `gate` names one of the first ten
///   ([allows]).
/// - [selectUnitsOnly]: the design's click and band pick placed units only
///   (a restriction: off in [full]).
/// - [serviceMove]: the service view's drags move units; [serviceMerge]:
///   the service bar offers Merge and Split (still only with their
///   callbacks). The design flags do not gate service (spec S4).
/// - [draft]: what the document's own `DraftPermissions` become.
@immutable
final class PlanPermissions {
  const PlanPermissions({
    this.tools,
    this.move = true,
    this.rotate = true,
    this.mirror = true,
    this.reshape = true,
    this.delete = true,
    this.changeLayer = true,
    this.recolor = true,
    this.editLayers = true,
    this.editPage = true,
    this.relabel = true,
    this.undo = true,
    this.export = true,
    this.print = true,
    this.selectUnitsOnly = false,
    this.serviceMove = true,
    this.serviceMerge = true,
  });

  /// Every tool, every flag on, no restriction: today's editor.
  static const PlanPermissions full = PlanPermissions();

  /// Select, pan and zoom; no edit, no undo. Export and print stay: neither
  /// is an edit. The service flags stay: the profile governs the editor.
  static const PlanPermissions readOnly = PlanPermissions(
    tools: {_select},
    move: false,
    rotate: false,
    mirror: false,
    reshape: false,
    delete: false,
    changeLayer: false,
    recolor: false,
    editLayers: false,
    editPage: false,
    relabel: false,
    undo: false,
  );

  /// Today's `tablesOnly` (editor_capabilities.dart:175-190): select and
  /// place symbols; no mirror, reshape or layer change; no layer or page
  /// editing; the click and the band pick placed units only. Hiding the
  /// Layer and Page panels is `PlanEditor`'s options (2a P7); the gallery's
  /// filter is [isUnitSymbol].
  static const PlanPermissions unitsOnly = PlanPermissions(
    tools: {_select, _symbol},
    mirror: false,
    reshape: false,
    changeLayer: false,
    editLayers: false,
    editPage: false,
    selectUnitsOnly: true,
  );

  static const String _select = 'plan.select';
  static const String _symbol = 'plan.symbol';

  final Set<String>? tools;
  final bool move, rotate, mirror, reshape, delete;
  final bool changeLayer, recolor, editLayers, editPage, relabel;
  final bool undo, export, print;
  final bool selectUnitsOnly, serviceMove, serviceMerge;

  /// Whether the tool [id] is offered: `plan.select` always, else by
  /// [tools] (null: every id).
  bool allowsTool(String id) => id == _select || (tools?.contains(id) ?? true);

  /// Whether [gate]'s flag is on.
  bool allows(PlanGate gate) => switch (gate) {
        PlanGate.move => move,
        PlanGate.rotate => rotate,
        PlanGate.mirror => mirror,
        PlanGate.reshape => reshape,
        PlanGate.delete => delete,
        PlanGate.changeLayer => changeLayer,
        PlanGate.recolor => recolor,
        PlanGate.editLayers => editLayers,
        PlanGate.editPage => editPage,
        PlanGate.relabel => relabel,
      };

  /// Whether anything may be edited: an edit flag, or a tool other than
  /// `plan.select` (a drawing tool or a kit's). [selectUnitsOnly],
  /// [serviceMove] and [serviceMerge] are not edits of the design.
  bool get edits =>
      move ||
      rotate ||
      mirror ||
      reshape ||
      delete ||
      changeLayer ||
      recolor ||
      editLayers ||
      editPage ||
      relabel ||
      (tools?.any((id) => id != _select) ?? true);

  /// The document's engine permissions: [DraftPermissions.readOnly] when
  /// nothing may be edited ([edits] false), else [DraftPermissions.all].
  DraftPermissions get draft =>
      edits ? DraftPermissions.all : DraftPermissions.readOnly;

  /// A copy with the given fields replaced; a null argument keeps the
  /// field (so `copyWith(tools: null)` keeps the set: start from [full] for
  /// every tool). A given [tools] is copied, unmodifiable.
  PlanPermissions copyWith({
    Set<String>? tools,
    bool? move,
    bool? rotate,
    bool? mirror,
    bool? reshape,
    bool? delete,
    bool? changeLayer,
    bool? recolor,
    bool? editLayers,
    bool? editPage,
    bool? relabel,
    bool? undo,
    bool? export,
    bool? print,
    bool? selectUnitsOnly,
    bool? serviceMove,
    bool? serviceMerge,
  }) =>
      PlanPermissions(
        tools: tools == null ? this.tools : Set.unmodifiable(tools),
        move: move ?? this.move,
        rotate: rotate ?? this.rotate,
        mirror: mirror ?? this.mirror,
        reshape: reshape ?? this.reshape,
        delete: delete ?? this.delete,
        changeLayer: changeLayer ?? this.changeLayer,
        recolor: recolor ?? this.recolor,
        editLayers: editLayers ?? this.editLayers,
        editPage: editPage ?? this.editPage,
        relabel: relabel ?? this.relabel,
        undo: undo ?? this.undo,
        export: export ?? this.export,
        print: print ?? this.print,
        selectUnitsOnly: selectUnitsOnly ?? this.selectUnitsOnly,
        serviceMove: serviceMove ?? this.serviceMove,
        serviceMerge: serviceMerge ?? this.serviceMerge,
      );

  /// The flags, in declaration order: name, value and [full]'s value.
  List<(String, bool, bool)> get _flags => [
        ('move', move, true),
        ('rotate', rotate, true),
        ('mirror', mirror, true),
        ('reshape', reshape, true),
        ('delete', delete, true),
        ('changeLayer', changeLayer, true),
        ('recolor', recolor, true),
        ('editLayers', editLayers, true),
        ('editPage', editPage, true),
        ('relabel', relabel, true),
        ('undo', undo, true),
        ('export', export, true),
        ('print', print, true),
        ('selectUnitsOnly', selectUnitsOnly, false),
        ('serviceMove', serviceMove, true),
        ('serviceMerge', serviceMerge, true),
      ];

  @override
  bool operator ==(Object other) {
    if (other is! PlanPermissions || !setEquals(other.tools, tools)) {
      return false;
    }
    final a = other._flags, b = _flags;
    for (var i = 0; i < a.length; i++) {
      if (a[i].$2 != b[i].$2) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
      tools == null ? null : Object.hashAllUnordered(tools!),
      Object.hashAll([for (final (_, v, _) in _flags) v]));

  /// The fields that differ from [full], as `name: value`; the tools
  /// sorted.
  @override
  String toString() => 'PlanPermissions(${[
        if (tools case final t?) 'tools: {${(t.toList()..sort()).join(', ')}}',
        for (final (n, v, d) in _flags)
          if (v != d) '$n: $v',
      ].join(', ')})';
}

/// The gallery's filter for [PlanPermissions.unitsOnly] (today's
/// `tablesOnly` filter, editor_capabilities.dart:209-211, widened by spec
/// S5): any symbol whose definition carries `jetcad.unit`, a seat
/// included. Pass it to `PlanSymbolGallery(filter:)` or
/// `PlanEditor(symbolFilter:)`.
bool isUnitSymbol(PlanSymbol symbol) => symbol.entry.unit != null;
```

  In `lib/jet_cad_2d_plan.dart`, the permissions export becomes `export 'src/controller/permissions.dart' show PlanPermissions, isUnitSymbol;`.

- [ ] **Step 7: The unit picker.** Create `lib/src/service/unit_picker.dart`, the port of `jet_cad_floor_plan/lib/src/service/table_picker.dart:1-371`. Copied verbatim, renamed only: `TableTop` → `UnitTop` (`:17-36`), `PolygonTop` (`:38-73`), `CircleTop` (`:75-86`), the box distance (`:365-370`); `firstLeafOf` is Task 6's (`lib/src/units/unit_label.dart`, today's `table_label.dart:155-181` with its optional `leavesByOwner`), imported, not copied. Everything else is the code below (the header, `unitTopOf`, `UnitCandidate`, `PickCandidate`, `UnitPicker`); what changed from today, line by line: the candidates come from `UnitIndexCache.current` (every unit, placed and generated; `UnitInfo.toWorld` for the transform, `UnitInfo.visible` and `UnitInfo.locked` for the layer rule and the lock), the cache is keyed by the index's identity (the cache rebuilds on the state id, the layers and `locked`), and `placedOnly` passes over a generated unit as `skipLocked` passes over a locked one.

```dart
// Picking a unit (spec 2b S4 "The unit picker"; today's TablePicker, spec
// 14c S1, S2): a point inside a unit's top picks it, whatever else is drawn
// there; failing that, a point inside the unit symbol's bounding box (its
// chairs, the space between them) does; for a touch, failing both, the unit
// whose box is nearest within the finger's reach. Ported from
// jet_cad_floor_plan/lib/src/service/table_picker.dart over UnitIndex: placed
// and generated units alike, each through its world transform (group ×
// instance for a seat).
//
// No Flutter import: this file is Dart over `package:jet_cad_2d` only.
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:meta/meta.dart' show visibleForTesting;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../units/unit_index.dart';
import '../units/unit_label.dart' show firstLeafOf;

// UnitTop, PolygonTop, CircleTop: table_picker.dart:17-86, TableTop renamed.

/// The top of [definition] in [doc]: its lowest-handle leaf, when that is
/// a closed polyline (its last vertex repeating its first, by exact `==`)
/// or a circle; null otherwise (such a unit is picked by its box alone).
/// [leavesByOwner] as for [firstLeafOf]. (table_picker.dart:88-110.)
UnitTop? unitTopOf(DraftDocument doc, Handle definition,
    [Map<Handle, List<int>>? leavesByOwner]) {
  final leaf = firstLeafOf(doc, definition, leavesByOwner);
  if (leaf == null) return null;
  final payload = leaf.payload;
  switch (leaf.kind) {
    case EntityKind.circle:
      return CircleTop(
          payload.coords[0], payload.coords[1], payload.scalars[0]);
    case EntityKind.polyline:
      if (!isClosedPolyline(payload)) return null;
      final xy = payload.coords;
      return PolygonTop(
          Float64List.fromList(Float64List.sublistView(xy, 0, xy.length - 2)));
    default:
      return null;
  }
}

/// A unit the planner can show and act on (zone spec Z0): a unit on a
/// visible layer, its world transform's determinant finite and non-zero,
/// its box non-empty, the box's four corners finite in the world. The one
/// rule for the picker, the framing, the details and the focus.
final class UnitCandidate {
  UnitCandidate(
      {required this.unit,
      required this.transform,
      required this.box,
      required this.corners,
      required this.locked});

  final UnitInfo unit;

  /// Definition space to world: the unit's [UnitInfo.toWorld].
  final Transform2 transform;

  /// The symbol's bounding box in definition space.
  final Aabb2 box;

  /// [box]'s corners in the world, `x0, y0, ..., x3, y3`: its (min, min),
  /// (max, min), (max, max) and (min, max) through [transform].
  final Float64List corners;

  /// [UnitInfo.locked]: picked and reported, never selected or moved.
  final bool locked;

  /// The axis-aligned bound of [corners] (zone spec Z2).
  Aabb2 get worldBounds {
    var minX = corners[0], minY = corners[1], maxX = minX, maxY = minY;
    for (var i = 2; i < 8; i += 2) {
      minX = math.min(minX, corners[i]);
      maxX = math.max(maxX, corners[i]);
      minY = math.min(minY, corners[i + 1]);
      maxY = math.max(maxY, corners[i + 1]);
    }
    return Aabb2.raw(minX, minY, maxX, maxY);
  }
}

/// One unit the picker can hit.
final class PickCandidate {
  PickCandidate(
      {required this.unit,
      required this.inverse,
      required this.top,
      required this.box,
      required this.locked,
      required this.scale});

  final UnitInfo unit;

  /// World to definition space.
  final Transform2 inverse;

  /// Null when the first leaf is no top.
  final UnitTop? top;
  final Aabb2 box;
  final bool locked;

  /// The world transform's linear scale, `sqrt(|det|)`.
  final double scale;
}

/// The units of one document, ready to pick. The candidates are rebuilt
/// when [units] gives a new index (a state, a layer or a lock change),
/// never per pointer event; the tops and boxes are kept per definition for
/// the picker's life. A pick allocates nothing per unit (CLAUDE.md; the
/// ported `pick_allocation_test`, Task 14).
class UnitPicker {
  UnitPicker(this.document, this.units,
      {this.skipLocked = false,
      this.placedOnly = false,
      @visibleForTesting Map<Handle, List<int>> Function()? leavesByOwner,
      @visibleForTesting Transform2 Function(Transform2 transform)? invert})
      : _leavesByOwner = leavesByOwner ?? document.leavesByOwner,
        _invert = invert ?? _inverseOf;

  final DraftDocument document;
  final UnitIndexCache units;

  /// Whether [pick] passes over a locked unit as if it were not there (the
  /// design's units-only pick, today's `skipLocked: true`); false in
  /// service, which picks a locked unit and never selects it (spec S2).
  final bool skipLocked;

  /// Whether [pick] passes over a generated unit (the design's units-only
  /// pick: placed units only, spec S4).
  final bool placedOnly;

  final Map<Handle, List<int>> Function() _leavesByOwner;
  final Transform2 Function(Transform2 transform) _invert;

  static Transform2 _inverseOf(Transform2 transform) => transform.invert();

  /// The boundary tolerance: a point on a top's edge is inside.
  static const Tolerance tolerance = Tolerance(linear: 1e-6, angular: 1e-9);

  final Float64List _point = Float64List(2);
  List<PickCandidate> _candidates = const [];
  final Map<Handle, UnitTop?> _tops = {};
  final Map<Handle, Aabb2> _boxes = {};
  UnitIndex? _index;

  /// The candidates, ascending by instance handle.
  List<PickCandidate> get candidates {
    final index = units.current;
    if (!identical(index, _index)) {
      _candidates = _build(index);
      _index = index;
    }
    return _candidates;
  }

  List<PickCandidate> _build(UnitIndex index) {
    Map<Handle, List<int>>? leaves;
    Map<Handle, List<int>> scan() => leaves ??= _leavesByOwner();
    return [
      for (final c in candidatesOf(document, index, boxes: _boxes, leaves: scan))
        PickCandidate(
            unit: c.unit,
            inverse: _invert(c.transform),
            top: _tops.putIfAbsent(
                c.unit.definition, () => unitTopOf(document, c.unit.definition, scan())),
            box: c.box,
            locked: c.locked,
            scale: math.sqrt(c.transform.determinant.abs())),
    ];
  }

  /// The candidates of [index] over [document] (zone spec Z0), ascending by
  /// instance handle. [boxes] caches the definitions' boxes; [leaves] is
  /// [DraftDocument.leavesByOwner] or a stand-in, called at most once.
  /// O(units + entities) at document-change rate, never per frame.
  static List<UnitCandidate> candidatesOf(DraftDocument document, UnitIndex index,
      {required Map<Handle, Aabb2> boxes,
      required Map<Handle, List<int>> Function() leaves}) {
    final out = <UnitCandidate>[];
    Map<Handle, List<int>>? scanned;
    for (final u in index.units) {
      if (!u.visible) continue;
      final m = u.toWorld;
      final det = m.determinant;
      if (det == 0 || !det.isFinite) continue;
      final box = boxes.putIfAbsent(u.definition,
          () => document.definitionBounds(u.definition, scanned ??= leaves()));
      if (box.isEmpty) continue;
      final corners = Float64List(8);
      void corner(int i, double x, double y) {
        corners[2 * i] = m.a * x + m.c * y + m.e;
        corners[2 * i + 1] = m.b * x + m.d * y + m.f;
      }

      corner(0, box.minX, box.minY);
      corner(1, box.maxX, box.minY);
      corner(2, box.maxX, box.maxY);
      corner(3, box.minX, box.maxY);
      if (!corners.every((v) => v.isFinite)) continue;
      out.add(UnitCandidate(
          unit: u, transform: m, box: box, corners: corners, locked: u.locked));
    }
    return out;
  }

  /// Today's `TablePicker.pick` (table_picker.dart:306-363): the unit whose
  /// top holds [world], the highest handle among several; else the unit
  /// whose box holds it, the highest handle among several; else, with a
  /// [reach], the unit whose box is nearest within [reach] world units, the
  /// higher handle on a tie; else null. A unit [skipLocked] or [placedOnly]
  /// passes over is not there. Allocates nothing per unit.
  UnitInfo? pick(Vector2 world, {double reach = 0}) {
    final list = candidates;
    final storage = world.storage;
    final wx = storage[0], wy = storage[1];
    for (var i = list.length - 1; i >= 0; i--) {
      final c = list[i];
      if (_passes(c)) continue;
      final m = c.inverse;
      final top = c.top;
      if (top == null) continue;
      _point
        ..[0] = m.a * wx + m.c * wy + m.e
        ..[1] = m.b * wx + m.d * wy + m.f;
      if (top.containsAt(_point, tolerance)) return c.unit;
    }
    for (var i = list.length - 1; i >= 0; i--) {
      final c = list[i];
      if (_passes(c)) continue;
      final m = c.inverse;
      final x = m.a * wx + m.c * wy + m.e, y = m.b * wx + m.d * wy + m.f;
      if (_boxDistance(c.box, x, y) <= tolerance.linear) return c.unit;
    }
    if (reach <= 0) return null;
    PickCandidate? best;
    var bestDistance = reach;
    for (var i = list.length - 1; i >= 0; i--) {
      final c = list[i];
      if (_passes(c)) continue;
      final m = c.inverse;
      final x = m.a * wx + m.c * wy + m.e, y = m.b * wx + m.d * wy + m.f;
      final d = _boxDistance(c.box, x, y) * c.scale;
      if (d < bestDistance || (best == null && d <= bestDistance)) {
        best = c;
        bestDistance = d;
      }
    }
    return best?.unit;
  }

  bool _passes(PickCandidate c) =>
      (skipLocked && c.locked) || (placedOnly && c.unit.generated);

  // _boxDistance: table_picker.dart:365-370, verbatim.
}
```

- [ ] **Step 8: The gates.** Replace `lib/src/tools/plan_select_gates.dart` whole:

```dart
// Spec 2a P2 "Permissions" (the select gates: move, rotate, reshape,
// delete) and P4 "Locks" (the gates refuse a locked object), 2a Task 12; and
// 2b S2 "In design, a generated unit stands for its object" and S4
// selectUnitsOnly (Task 8). One object on the select tool and on the grip
// cache, as today's shell shares one (planner_shell.dart:439-445,
// :648-657, :1797-1846). jet_cad_2d_flutter is unchanged: the gates replace
// the tool's pick and filter its band.
import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';

import '../controller/permissions.dart';
import '../kits/locks.dart' show LockGates;
import '../service/unit_picker.dart';
import '../units/unit_index.dart';

/// Past this many parents a chain is taken as no object's (the tree refuses
/// cycles; this only bounds a malformed one).
const int _maxDepth = 4096;

/// The root-level object [h] stands for in design (spec S2), or null: the
/// root-level node above [h] when it is a [GroupNode] other than [h] that
/// is an object of a registered type ([ParametricCatalog.typeIdOf], frozen
/// objects included) or a lock-set object ([locked], the controller's
/// `locked`). A root-level key, and a key under a plain group, stand for
/// themselves. An entity key starts from its owner. Walks the parents
/// only: no allocation (hover rate).
Handle? generatingObjectOf(DraftDocument d, Handle h, ParametricCatalog catalog,
    Set<Handle> locked) {
  final root = d.rootHandle;
  var current = h;
  final slot = d.entities.slotOf(h);
  if (slot != null) current = d.entities.ownerAt(slot);
  if (current == root) return null;
  for (var depth = 0; depth < _maxDepth; depth++) {
    final node = d.tree[current];
    if (node == null) return null;
    final up = node.parent;
    if (up == root) {
      if (current == h || node is! GroupNode) return null;
      return catalog.typeIdOf(d, current) != null || locked.contains(current)
          ? current
          : null;
    }
    if (up.isNone || up == current) return null;
    current = up;
  }
  return null;
}

/// Whether [key] names a placed unit of [index] (today's `_isTableKey`,
/// planner_shell.dart:1787-1795): a root key whose target is a root-level
/// instance of a unit definition.
bool isPlacedUnitKey(UnitIndex index, SelectionKey key) =>
    key.chain.isEmpty && index[key.target]?.generated == false;

/// The select tool's and the grip cache's gates: each drag kind and Delete
/// need their [PlanPermissions] flag, and a selection holding a locked
/// object (or a key inside one) shuts them all ([LockGates]). In design the
/// pick and the band map a generated unit to its object (spec S2); under
/// [PlanPermissions.selectUnitsOnly] they pick placed units only.
///
/// The getters are read at every hover, key and frame (`SelectGates`'s
/// contract): the lock state is [LockGates]' cached `bool`, and the
/// permissions are read through one closure call.
final class PlanSelectGates extends LockGates {
  PlanSelectGates({
    required PlanPermissions Function() permissions,
    required SelectionController selection,
    required ValueListenable<Set<Handle>> locked,
    required ParametricCatalog catalog,
    required UnitPicker Function() picker,
    required UnitIndex Function() units,
  })  : _permissions = permissions,
        _lockedObjects = locked,
        _catalog = catalog,
        _picker = picker,
        _units = units,
        super(selection: selection, locked: locked);

  final PlanPermissions Function() _permissions;
  final ValueListenable<Set<Handle>> _lockedObjects;
  final ParametricCatalog _catalog;
  final UnitPicker Function() _picker;
  final UnitIndex Function() _units;
  final HitPath _hit = HitPath();

  /// The select tool's idle keys (Escape, Delete, Backspace while no
  /// gesture runs): the shortcuts' option (Task 16 sets it).
  @override
  bool idleKeys = true;

  /// The design's pick is always the gates' (spec S2).
  @override
  bool get restrictsPick => true;

  /// The tool's own pick (the precise radius, then a finger's reach,
  /// select_tool.dart:160-171), resolved by [resolveHit], then mapped to
  /// its object ([generatingObjectOf]). Under selectUnitsOnly, the
  /// units-only picker's: a placed unit's top, else its box, within the
  /// pick tolerance for a mouse and the reach for a finger; a locked unit
  /// passed over (planner_shell.dart:1817-1826).
  @override
  SelectionKey? pick(ToolPointerEvent e, ToolContext ctx) {
    if (_permissions().selectUnitsOnly) {
      final hit = _picker().pick(e.world,
          reach: e.isTouch ? e.reachRadiusWorld : e.pickRadiusWorld);
      return hit == null ? null : SelectionKey.root(hit.instance);
    }
    if (!ctx.index.pickInto(
            e.world, e.pickRadiusWorld, const QueryFilter.picking(), _hit) &&
        (e.reachRadiusWorld <= e.pickRadiusWorld ||
            !ctx.index.pickInto(e.world, e.reachRadiusWorld,
                const QueryFilter.picking(), _hit))) {
      return null;
    }
    final key = resolveHit(_hit, ctx.document);
    if (key == null) return null;
    final object = generatingObjectOf(
        ctx.document, key.target, _catalog, _lockedObjects.value);
    return object == null ? key : SelectionKey.root(object);
  }

  /// A key under a parametric or lock-set object is refused (the band's
  /// group rule gives the object itself: a crossing takes a row, a window
  /// over a seats-only row takes nothing, decision 9). Under
  /// selectUnitsOnly, placed units only.
  @override
  bool bandAccepts(DraftDocument d, SelectionKey key) {
    if (_permissions().selectUnitsOnly) return isPlacedUnitKey(_units(), key);
    return generatingObjectOf(d, key.target, _catalog, _lockedObjects.value) ==
        null;
  }

  @override
  bool get move => _permissions().move && super.move;

  @override
  bool get rotate => _permissions().rotate && super.rotate;

  @override
  bool get reshape => _permissions().reshape && super.reshape;

  @override
  bool get delete => _permissions().delete && super.delete;
}
```

- [ ] **Step 9: Wire the session and the controller.**
  1. `lib/src/controller/session.dart`: import `'../service/unit_picker.dart'`. The gates' construction (`:54-55`) becomes:

```dart
    gates = PlanSelectGates(
        permissions: permissions,
        selection: selection,
        locked: locked,
        catalog: catalog,
        picker: () => unitPicker,
        units: () => units.current);
```

     and the session gains, beside `gates`:

```dart
  /// The design's units-only picker (spec S4 selectUnitsOnly): placed,
  /// unlocked units, made at its first use and kept for the session's life
  /// (today's `_tablePicker`, planner_shell.dart:444).
  late final UnitPicker unitPicker =
      UnitPicker(document, units, skipLocked: true, placedOnly: true);
```

     (`units` is Task 6's `UnitIndexCache` of the session; the closures read it after the constructor has run.)
  2. `lib/src/controller/plan_controller.dart`, in the `permissions` setter (`:819-840`): `final stale = switch (select.dragKind) {` becomes `final stale = old.selectUnitsOnly != value.selectUnitsOnly || switch (select.dragKind) {` (today's `planner_shell.dart:1077-1083`), and right after `if (stale) select.cancel(toolController.context);` add:

```dart
    // Today's S-9 g (planner_shell.dart:1085-1095): a change to units only
    // keeps the placed units of the selection.
    if (value.selectUnitsOnly && !old.selectUnitsOnly) {
      final index = _session.units.current;
      final drop = [
        for (final k in selection.keys)
          if (!isPlacedUnitKey(index, k)) k
      ];
      if (drop.isNotEmpty) selection.remove(drop);
    }
```

     with `isPlacedUnitKey` imported from `'../tools/plan_select_gates.dart'` (already imported for `PlanSelectGates`; widen its `show` if it has one).

- [ ] **Step 10: Run the tests, see them pass.** Run: `cd packages/jet_cad_2d_plan && flutter test test/tools/design_selection_test.dart test/service/unit_picker_test.dart test/editor/units_only_select_test.dart test/controller/permissions_test.dart test/tools/plan_select_gates_test.dart test/barrel_test.dart`. Expected: `All tests passed!`. Then the whole package, `flutter test`: `All tests passed!` (2a's select-tool and canvas tests keep passing: in design the gates' pick is the tool's own pick plus a mapping that changes nothing where no parametric object holds an instance).

- [ ] **Step 11: Format and the gate.** `cd packages/jet_cad_2d_plan && dart format . && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` — `All tests passed!`, `No issues found!`, exit 0. An unused or unnecessary import the analyzer names is deleted, nothing else changed to quiet it. From the root, `git status --short`: only this task's files.

- [ ] **Step 12: Commit.**

```bash
git add packages/jet_cad_2d_plan/lib/src/controller/permissions.dart packages/jet_cad_2d_plan/lib/src/service/unit_picker.dart packages/jet_cad_2d_plan/lib/src/tools/plan_select_gates.dart packages/jet_cad_2d_plan/lib/src/controller/session.dart packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart packages/jet_cad_2d_plan/test/support/unit_fixtures.dart packages/jet_cad_2d_plan/test/support/unit_editor_fixture.dart packages/jet_cad_2d_plan/test/tools/design_selection_test.dart packages/jet_cad_2d_plan/test/service/unit_picker_test.dart packages/jet_cad_2d_plan/test/editor/units_only_select_test.dart packages/jet_cad_2d_plan/test/controller/permissions_test.dart packages/jet_cad_2d_plan/test/tools/plan_select_gates_test.dart packages/jet_cad_2d_plan/test/barrel_test.dart
git commit -m "$(cat <<'EOF'
feat(plan): units-only permissions and the design's unit selection (2b S2, S4)

PlanPermissions gains relabel, selectUnitsOnly, serviceMove and
serviceMerge, the unitsOnly profile and the isUnitSymbol gallery filter.
In design a click, a hover and a band on a generated seat name its row
(a parametric or lock-set object); a window band over a seats-only row
takes nothing (decision 9). Under selectUnitsOnly the pick is the unit
picker's, ported from today's TablePicker over UnitIndex: a placed
unit's top, else its box, a locked one passed over.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 13: Mutation check** (committed files only; after each: run the named test with `cd packages/jet_cad_2d_plan && flutter test <file>`, see it red, quote the red line, then `git checkout -- <file>` and `git diff --quiet -- <file>` must exit 0):
  - M-DS1 `lib/src/tools/plan_select_gates.dart`: in `pick`, `return object == null ? key : SelectionKey.root(object);` → `return key;` → DS-click-seat red (`test/tools/design_selection_test.dart`).
  - M-DS2 same file: `final key = resolveHit(_hit, ctx.document);` → `final key = SelectionKey.root(_hit.entity);` → DS-click-attrib red.
  - M-DS3 same file: `bandAccepts`' last `return` → `return true;` → DS-window and DS-crossing red.
  - M-DS4 same file: in `generatingObjectOf`, `|| locked.contains(current)` deleted → DS-locked-object red.
  - M-DS5 same file: in `generatingObjectOf`, the `return catalog.typeIdOf(...) ... : null;` → `return current;` → DS-plain-group red.
  - M-DS6 `lib/src/controller/session.dart`: `placedOnly: true` → `placedOnly: false` → DS-units-only red.
  - M-DS7 `plan_select_gates.dart`: in `bandAccepts`, delete the `if (_permissions().selectUnitsOnly) ...;` line → DS-units-only red.
  - M-DS8 `lib/src/controller/plan_controller.dart`: delete the `if (value.selectUnitsOnly && !old.selectUnitsOnly) { ... }` block → DS-prune red.
  - M-DS9 `lib/src/service/unit_picker.dart`: in `candidatesOf`, `final m = u.toWorld;` → `final m = (document.tree[u.instance]! as InstanceNode).transform;` → DS-picker-seat red.
  - M-DS10 `lib/src/controller/permissions.dart`: delete `relabel ||` from `edits` → DS-perm red.
  - M-DS11 same file: `symbol.entry.unit != null` → `symbol.entry.unit?.kind == 'table'` → DS-perm red.
  - M-PM1b same file: delete `selectUnitsOnly: true,` from `unitsOnly` → PM-1 red (`test/controller/permissions_test.dart`).
  - M-PM2b same file: `serviceMerge: serviceMerge ?? this.serviceMerge` → `serviceMerge: serviceMerge ?? this.serviceMove` → EC3b red.
  - M-PM7b same file: `if (v != d)` → `if (!v)` → PM-7 red.
  - M-TP-skip `unit_picker.dart`: in `_passes`, `(skipLocked && c.locked) ||` deleted → the ported R-4 and "the tables on the hidden and the locked layers …" red (`test/editor/units_only_select_test.dart`).

#### Assumed from earlier tasks

Each name below is used as written; where the earlier task named it otherwise, use that task's name and report the difference.
- Task 6 (`lib/src/units/unit_index.dart`): `UnitInfo` with `instance`, `definition`, `owner`, `text`, `locked`, `visible`, `toWorld`, `bool get generated`; `UnitIndex` with `units`, `operator [](Handle)`, `withLabel(String)` (trimmed), `UnitIndex.of(document, catalog:, locks:)`; `UnitIndexCache(document, catalog:, locks:, locked:)` with `current` (the identical index until a state, layer or `locked` change) and `dispose()`. **The design session's cache is `DocumentSession.units`** (a `late final UnitIndexCache units`, built in the session's constructor and disposed with it).
- Task 3: `PlanGate.relabel` (last value); `PlanPermissions.relabel` (default true) and its `allows` arm (this task rewrites the file over them); `kUnitLabelTag`, `kUnitLabelTextAttrs`, `unitLabelHeight(Aabb2 top)`, `unitLabelPayload({anchor, height, instanceToWorld})` exported from `package:jet_cad_2d_kit/jet_cad_2d_kit.dart`.
- Task 5 (`test/support/test_kit.dart`, `test/support/service_fixture.dart`): `unitKit()` (kit id `test`; `testKit()` without `units: true` has no row) whose `test.row` is a parametric type generating seats only (no entity of its own), each seat an instance with one UNIT ATTRIB; `serviceFixture()` whose plan text this task reads as `.json`. Task 5's row is seats only (its plan decision "`test.row` is seats only"), which DS-window's premise needs.
- 2a: `PlanController.selectGates`, `selection`, `index`, `page`, `grips`, `toolController`, `locked`, `catalog`, `kits` (`@internal` where marked), `PlanSymbol(kitId:, names:, entry:)`.

#### Interface problem

Resolved by R-12 (`UnitPicker` is created here with the document, `skipLocked`, `placedOnly`, the two test seams, `candidates` and `candidatesOf`; Tasks 9 and 14 consume it; the Shared interfaces list it under Task 8).

---

