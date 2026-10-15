### Task 9: The unit API, design side (spec S3 "The unit API", `unitChanges`; S2 "Per-unit data", "A changed label", "Unlabelled, duplicate and bad labels"; S5 the controller's rows)

**Files:**
- Create: `packages/jet_cad_2d_plan/lib/src/units/unit_detail.dart` (`PlanUnit`, `PlanUnitDetail`, their builders, `PlanUnitChange` and its four subtypes, `diffUnitDetails`; ported from `jet_cad_floor_plan/lib/src/host/floor_plan_types.dart:17-58`, `host/table_detail.dart`, `host/design_changes.dart`)
- Create: `packages/jet_cad_2d_plan/lib/src/controller/plan_camera.dart` (`PlanCamera`, ported from `host/floor_plan_camera.dart`)
- Create: `packages/jet_cad_2d_plan/lib/src/units/unit_fit.dart` (`kUnitFitMarginMm`, `kUnitFitMinSpanMm`, `frameUnits`, ported from `host/table_fit.dart`)
- Create: `packages/jet_cad_2d_plan/lib/src/units/unit_writes.dart` (`unitLabelCommand`: the label's one command, shared with Task 10's panel)
- Modify: `packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart` (the unit API, the camera value, the fit target, the seams Task 11 re-points)
- Modify: `packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart` (exports), `packages/jet_cad_2d_plan/test/barrel_test.dart` (ED-9's set)
- Test (support, new): `packages/jet_cad_2d_plan/test/support/unit_embedding_fixture.dart`
- Test (new): `packages/jet_cad_2d_plan/test/units/unit_api_test.dart` (UA-*)
- Test (ported): `packages/jet_cad_2d_plan/test/controller/unit_detail_test.dart`, `unit_data_test.dart`, `unit_colour_test.dart`, `unit_changes_test.dart`, `unit_camera_test.dart`, `non_finite_unit_test.dart` (all under `test/controller/`), `packages/jet_cad_2d_plan/test/units/unit_fit_test.dart`; T5-c and T5-d appended to `test/editor/units_only_select_test.dart` (Task 8's); VW4 appended to `test/l10n/value_words_test.dart`

(Paths below are under `packages/jet_cad_2d_plan/` unless they say otherwise.)

**Interfaces:**
- Consumes:
  - Task 6: `UnitIndex` (`units`, `operator []`, `withLabel`, `warnings()`), `UnitInfo` (`instance`, `definition`, `owner`, `ownerType`, `label`, `text`, `kind`, `capacity`, `symbolKey`, `locked`, `visible`, `toWorld`, `generated`), `UnitIndexCache.current`, `UnitData` (`componentTypeId` `jetcad.unit_data`, `UnitData(Map<String, String>)`, `data`), `unitDataProblem(Map<String, String>)` (today's `tableDataProblem`), `UnitColour` (`UnitColour(PlanSwatch)`, `name`, `swatch`), `UnitLabelProblem`, `unitLabelProblem(String)`, `UnitLabelWarning` and its three subtypes; `DocumentSession.units` (see Task 8's "Assumed").
  - Task 7: `UnitLabelSystem` installed per document (a turn re-stamps a placed unit's label in the same step).
  - Task 8: `UnitPicker(document, units, {skipLocked, placedOnly})`, `UnitPicker.candidatesOf(document, index, {boxes, leaves})`, `UnitCandidate` (`unit`, `transform`, `box`, `corners`, `worldBounds`), `unitTopOf`, `PolygonTop`, `CircleTop`; the test support `unit_fixtures.dart` and `unit_editor_fixture.dart`.
  - Task 3 (contract): `kUnitLabelTag`, `kUnitLabelTextAttrs`, `unitLabelHeight(Aabb2)`, `unitLabelPayload({anchor, height, instanceToWorld})`, `PlanSwatch`.
  - Task 5: `unitKit()`, `serviceFixture()` (`test/support/service_fixture.dart`), the row type `test.row` and its component `RowComponent` (see "Assumed").
  - 2a (`controller/plan_controller.dart`): `_session` (`:250`), `_open` (`:589-653`), `_replace` (`:674-698`), `_refreshFlags` (`:711-716`), `_unrestricted` (`:743-753`), `execute` (`:542-561`), `settlePendingInput` (`:961-966`), `_canvasRect` (`:1144`), `_fitTarget` and `_Centre` (`:53-63`, `:1185`), `framingFor` (`:1202-1219`), `_request` (`:1250-1254`), `camera` (`CameraController`), `lockHint`, `locked`, `lockBroken`.
- Produces (the Shared interfaces' Task 9 rows, exactly):

```dart
final class PlanUnit { final String? label; final String kind; final int capacity;
  final String? symbolKey; final bool visible; final String? generatedBy; }
final class PlanUnitDetail { final PlanUnit unit; final Offset? center; final Size? size;
  final double rotation; final bool mirrored; final List<Offset> corners; final String layer;
  final bool locked; final Map<String, String> data; final PlanSwatch? colour; }
sealed class PlanUnitChange {}
final class PlanUnitAdded extends PlanUnitChange { final PlanUnitDetail unit; }
final class PlanUnitRemoved extends PlanUnitChange { final PlanUnitDetail unit; }
final class PlanUnitChanged extends PlanUnitChange { final PlanUnitDetail before, after; }
final class PlanUnitsReplaced extends PlanUnitChange {}
final class PlanCamera { double get scale; Offset worldToCanvas(Offset w); Offset canvasToWorld(Offset c);
  Rect visibleWorld(Size canvas); }
// PlanController:
List<PlanUnit> get units; List<PlanUnitDetail> get unitDetails;
String? unitAt(Offset canvasPoint, {PointerDeviceKind kind = PointerDeviceKind.mouse});
void select(Set<String> labels); bool fitToUnits(Set<String> labels);
List<UnitLabelWarning> get labelWarnings;
bool setUnitData(String label, Map<String, String> data); bool setUnitsData(Map<String, Map<String, String>>);
bool setUnitColour(String label, PlanSwatch? colour); bool setUnitsColour(Map<String, PlanSwatch?>);
bool setUnitLabel(String label, String next); bool setUnitsLabel(Map<String, String>);
Stream<PlanUnitChange> get unitChanges; ValueListenable<int> get revision;
ValueListenable<PlanCamera> get cameraValue; Offset? worldToGlobal(Offset); Offset? globalToWorld(Offset);
ValueListenable<Set<String>> get editorSelectedUnits;
@internal UnitIndex get unitIndex;   // Task 6's (R-10), moved here over the `_activeUnits` seam: the active document's from Task 11
```

  Also produced, internal: `@internal List<Handle> get unitDetailInstances` (each detail's instance, index for index: today's `tableDetailInstances`, `floor_plan_controller.dart:1518`; Task 10's inspector and Task 16's overlays key by it); `@visibleForTesting int get debugUnitScans` (today's `designScans`); `DraftCommand? unitLabelCommand(DraftDocument doc, UnitInfo unit, String text)` (`units/unit_writes.dart`, over Task 6's `addUnitLabelCommand`); and **the seams Task 11 re-points**, private to `plan_controller.dart`, each with a doc comment naming Task 11:
  - `UnitIndexCache get _activeUnits` (the design's cache now), `DraftDocument get _activeDocument`, `SelectionController get _activeSelection`;
  - `bool get _inDesign` (`true` now);
  - `void _requireDesign(String who)` (does nothing now; Task 11 makes it throw `StateError` in service);
  - `Set<String> _expandLabels(Set<String> labels)` (returns `labels` now; Task 12 expands a group's label in service);
  - `final ValueNotifier<Set<String>> _selectedUnits` (the active selection's labels; Task 12 exposes it as `selectedUnits`).

Plan decision (where the camera lives): `PlanCamera` goes to `controller/plan_camera.dart`, beside `camera_bounds.dart`: it is the controller's value, not a unit's. `unit_detail.dart` holds the unit types alone.

Plan decision (what is cached): `unitDetails` is rebuilt when `_activeUnits.current` is a new object (Task 6's cache moves on the state id, the layers' revision and `locked`, so today's key, `floor_plan_controller.dart:1495-1514`, is kept and a freeze is followed); two reads with nothing changed return the identical, unmodifiable list. The geometry is the picker's candidate rule (Task 8's `candidatesOf`, today's `TablePicker.candidatesOf` read by `_detailsOf`, `:1527-1555`).

Plan decision (`locked` in a detail): `UnitInfo.locked` (`isLockedUnit`: a locked layer or the lock set), spec S2 "One predicate … used by … `unitDetails.locked`". For a table on a locked layer this is today's value.

Plan decision (generated units): `units` and `unitDetails` list every unit of the index, placed and generated, ascending by instance; `generatedBy` is `UnitInfo.ownerType`. `select` in design takes placed units only (spec S3); `fitToUnits` frames any unit carrying a label, generated included (the framing names units, not the selection); `unitAt` finds any unit.

Plan decision (the writes, spec S3 "Design writes"): one path for data, colour and label, today's `_setTableComponents` (`:1650-1673`): the labels trimmed, each resolved to exactly one unit, a repeated trimmed key refusing all, entries equal to the stored value skipped, the rest one `CompoundCommand`. Added by spec S3: `false` for a unit the lock set covers (`_session.locks.covers`: a frozen or a missing kit's object, a missing kit's symbol), checked **before** executing, so the lock hint never shows for a host call; a unit on a locked or hidden **layer** still takes data and colour (today). The command runs through `execute` with the engine's permissions lifted (`_unrestricted`): a host call is not gated (2a P2; today's T5-c, "a host call under readOnly (V-5)").

Plan decision (`setUnitLabel`): the text rule's violations are an `ArgumentError` naming the problem, as `setUnitData`'s limits are; `false`, changing nothing, for a label naming no unit or several, a generated unit (its label is its type's), a unit the lock set covers, or a `next` that another unit will hold after the call (a unit not renamed in the call, or another entry's `next`). Checking against the labels **after** the call lets `setUnitsLabel({'1': '2', '2': '1'})` swap two tables in one step. An unlabelled placed unit gets a new UNIT ATTRIB (today's `_writeNumber`, `selection_panel.dart:663-683`); the step is labelled `Label`.

Plan decision (the undo labels): today's steps are labelled "Table data" and "Table colour" (`floor_plan_controller.dart:1612`, `:1647`), and HD8 and TC2/TC3 assert them. This plan names them "Unit data" and "Unit colour", following the spec's renaming of the components (`jetcad.table_data` → `jetcad.unit_data`), as 2a's ruling let a class name inside an expected `toString` follow the rename. Controller ruling R-13 accepts it; the executor records it in the ledger.

Plan decision (`unitChanges`): today's `designChanges` (`:1680-1776`): a baseline of the design's details and instances while the stream has a listener, a diff after each design change (the design document's `commands.changes`, as today's `_attach`, `:2098-2105`), `PlanUnitsReplaced` alone for `load` and `newPlan` after the changes still owed, nothing read while no one listens. The baseline is "at" the design while its `UnitIndex` is the identical object (today's state-and-layers key, plus `locked`).

Plan decision (`revision`): a `ValueNotifier<int>` moved by every change of the active document (its `commands.changes`, while `_inDesign` for the design's) and by `load` and `newPlan` (today's `_revision`, `:557`, `:1158-1300`, `:2102`). Task 11 adds the mode switch, Task 13 the reset and the restore.

- [ ] **Step 1: The embedding fixture.** Create `test/support/unit_embedding_fixture.dart`, the port of `jet_cad_floor_plan/test/host/embedding_fixture.dart:1-167`. Adaptations: the table is Task 8's `embeddingTable` (the fixture kit's unit), placed by hand on its layer and labelled with `addUnitLabel` (today's placer numbered it and the test rewrote the text); the plan is a plan file over `fxKit()`.

```dart
// The host embedding API's fixture (jet_cad_floor_plan/test/host/
// embedding_fixture.dart), ported for the unit API (2b Task 9): the
// hand-made unit whose box is off its base point, with an asymmetric top;
// copies of it turned 30 degrees, mirrored at 90 degrees, scaled
// non-uniformly (1.5, 0.8) and turned 180 degrees unmirrored, all 40 m off
// the origin; a unit on a hidden and one on a locked layer; two units
// sharing a label, an unlabelled unit and a unit whose corners are not
// finite; and a camera that is not the identity (panned, 0.37 px/mm).
// Tests compute their expectations from [embeddingBox] and each unit's
// [EmbeddingTable.transform] by the forward transform, never from the code
// under test.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show ViewportTransform;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import 'harness.dart' show planText;
import 'unit_editor_fixture.dart'
    show
        embeddingBox,
        embeddingPlacement,
        embeddingTable,
        kEmbeddingHidden,
        kEmbeddingLocked;
import 'unit_fixtures.dart';

export 'unit_editor_fixture.dart'
    show
        embeddingBox,
        embeddingPlacement,
        embeddingTable,
        kEmbeddingHidden,
        kEmbeddingLocked;

/// One unit of the fixture, as the test knows it.
final class EmbeddingTable {
  const EmbeddingTable(this.label, this.transform,
      {this.degrees = 0,
      this.sx = 1,
      this.sy = 1,
      this.layer = '0',
      this.finite = true});

  /// The label written, or null for an unlabelled unit.
  final String? label;

  /// Definition space to world.
  final Transform2 transform;
  final double degrees, sx, sy;

  /// `0`, [kEmbeddingHidden] or [kEmbeddingLocked].
  final String layer;

  /// Whether its box's corners are finite in the world.
  final bool finite;

  /// The label the plan reads: trimmed, null for none.
  String? get number => label?.trim();
}

/// The fixture's units in placement order (embedding_fixture.dart:82-120).
final List<EmbeddingTable> embeddingTables = [
  EmbeddingTable('1', embeddingPlacement(40000, -27000, 30), degrees: 30),
  const EmbeddingTable('2', Transform2(0, 1, 1, 0, 43000, -27000),
      degrees: 90, sy: -1),
  EmbeddingTable('3', embeddingPlacement(46000, -27000, -20, sx: 1.5, sy: 0.8),
      degrees: -20, sx: 1.5, sy: 0.8),
  EmbeddingTable('4', embeddingPlacement(49000, -27000, 180), degrees: 180),
  EmbeddingTable('5', embeddingPlacement(40000, -31000, 45),
      degrees: 45, layer: kEmbeddingHidden),
  EmbeddingTable('L', embeddingPlacement(43000, -31000, 120, sy: -1),
      degrees: 120, sy: -1, layer: kEmbeddingLocked),
  EmbeddingTable('7', embeddingPlacement(46000, -31000, 60), degrees: 60),
  EmbeddingTable(' 7 ', embeddingPlacement(49000, -31000, -150, sy: -1),
      degrees: -150, sy: -1),
  EmbeddingTable(null, embeddingPlacement(40000, -35000, 15), degrees: 15),
  const EmbeddingTable('9', Transform2(1e306, 0, 0, 1e-306, 43000, -35000),
      sx: 1e306, sy: 1e-306, finite: false),
];

/// The fixture plan, as a plan file over [fxKit]: [tables]
/// ([embeddingTables] by default) on an A4 page at 1:50 from (37,000,
/// -36,200) around them.
String embeddingPlanJson({Iterable<EmbeddingTable>? tables}) =>
    planText([fxKit()], (doc) {
      doc.commands.execute(SetComponentCommand<PageComponent>(
          doc.rootHandle, PageComponent(originX: 37000, originY: -36200)));
      final hidden = addLayer(doc, kEmbeddingHidden, visible: false);
      final locked = addLayer(doc, kEmbeddingLocked, locked: true);
      for (final t in tables ?? embeddingTables) {
        final h = placeUnit(doc, embeddingTable,
            transform: t.transform,
            layer: switch (t.layer) {
              kEmbeddingHidden => hidden,
              kEmbeddingLocked => locked,
              _ => ReservedHandles.layerZero,
            });
        if (t.label case final label?) addUnitLabel(doc, h, label);
      }
      doc.commands.clearHistory();
    });

/// The camera every call runs under: 0.37 px/mm, y flipped, panned so the
/// units sit near the canvas's top left.
ViewportTransform embeddingCamera() => ViewportTransform(
    worldToScreenMatrix: Transform2(0.37, 0, 0, -0.37, -14612.25, -9431.5));

/// World ([x], [y]) in the canvas of [camera], by the forward transform.
({double x, double y}) canvasOf(ViewportTransform camera, double x, double y) {
  final m = camera.worldToScreenMatrix;
  return (x: m.a * x + m.c * y + m.e, y: m.b * x + m.d * y + m.f);
}

/// A controller over [embeddingPlanJson] (or [json]) under
/// [embeddingCamera], disposed at tear-down.
PlanController embeddingController({String? json}) {
  final c = PlanController(kits: [fxKit()], json: json ?? embeddingPlanJson());
  addTearDown(c.dispose);
  c.camera.value = embeddingCamera();
  return c;
}

/// Within a relative 1e-12 of [want], an absolute 1e-12 near 0.
Matcher near(double want) => closeTo(want, 1e-12 * math.max(want.abs(), 1.0));
```

- [ ] **Step 2: The failing tests (new).** Create `test/units/unit_api_test.dart`. Every case runs on Task 5's service fixture (a turned, mirrored table off the origin; two seats-only rows off the origin, one turned, one curved) or on Task 8's editor fixture (two placed tables, `1` and `2`).

```dart
// 2b Task 9, spec S3 "The unit API" and S2 "Per-unit data": the units of
// the design, placed and generated, their details and data, the design
// writes and their refusals, select and fitToUnits in design, and
// unitChanges for a row edit. Over Task 5's service fixture (a turned,
// mirrored table off the origin; two seats-only rows, one turned, one
// curved) and Task 8's editor fixture (the units 1 and 2 placed).
import 'dart:async';

import 'package:flutter/painting.dart' show Size;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show SelectionKey;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:jet_cad_2d_plan/src/units/unit_index.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/harness.dart';
import '../support/service_fixture.dart' show serviceFixture;
import '../support/test_kit.dart';
import '../support/unit_editor_fixture.dart' show unitEditorPlanJson;
import '../support/unit_fixtures.dart' show fxKit;

PlanController design() =>
    controllerFor(kits: [unitKit()], json: serviceFixture().json);

/// The units of [c] labelled [prefix]1, [prefix]2, … (one row's seats).
List<UnitInfo> seatsLabelled(PlanController c, String prefix) => [
      for (final u in c.unitIndex.units)
        if (u.generated && (u.text?.startsWith(prefix) ?? false)) u,
    ];

/// The row whose seats are labelled [prefix]….
Handle rowOf(PlanController c, String prefix) =>
    seatsLabelled(c, prefix).first.owner!;

/// One edit: [row]'s seat count set to [n] (Task 5's row component).
void setRowCount(PlanController c, Handle row, int n) {
  final p = c.document.components.get<RowComponent>(row)!;
  expect(c.execute(SetComponentCommand<RowComponent>(row, p.copyWith(count: n))),
      isTrue);
}

/// One edit: [row]'s label prefix set to [prefix].
void setRowPrefix(PlanController c, Handle row, String prefix) {
  final p = c.document.components.get<RowComponent>(row)!;
  expect(
      c.execute(
          SetComponentCommand<RowComponent>(row, p.copyWith(prefix: prefix))),
      isTrue);
}

PlanUnitDetail detailOf(PlanController c, String label) =>
    c.unitDetails.singleWhere((d) => d.unit.label == label);

/// The placed table's label (the fixture's one placed unit).
String tableLabel(PlanController c) =>
    c.unitIndex.units.singleWhere((u) => !u.generated).text!;

void main() {
  test(
      'UA-units the design\'s units: the placed table and every seat, '
      'ascending by instance; a seat names its row\'s type', () {
    final c = design();
    final units = c.units;
    final index = c.unitIndex.units;
    expect(units, hasLength(index.length));
    expect(units.where((u) => u.generatedBy == null), hasLength(1));
    // M-UA0: `generatedBy: u.ownerType` written `generatedBy: null`.
    expect(
        units.where((u) => u.generatedBy == 'test.row').length, index.length - 1);
    final seat = units.firstWhere((u) => u.generatedBy != null);
    expect((seat.kind, seat.capacity), (UnitKinds.seat, 1));
    expect(c.unitDetails.map((d) => d.unit), units);
  });

  test(
      'UA-shrink-data a row of 12 seats carrying data and a colour shrunk to '
      '10: seats 1-10 keep their handles, data and colour; 11 and 12 '
      'vanish; undo brings them back with theirs (Review Focus 1)', () {
    final c = design();
    final row = rowOf(c, 'A');
    setRowCount(c, row, 12);
    final labels = [for (var i = 1; i <= 12; i++) 'A$i'];
    expect(c.setUnitsData({for (final l in labels) l: {'pos': l.toLowerCase()}}),
        isTrue);
    expect(c.setUnitColour('A11', PlanSwatch.teal), isTrue);
    expect(c.setUnitColour('A3', PlanSwatch.purple), isTrue);
    final handles = {
      for (final u in seatsLabelled(c, 'A')) u.text!: u.instance,
    };
    expect(handles.keys.toSet(), labels.toSet(), reason: 'premise');
    setRowCount(c, row, 10);
    for (var i = 1; i <= 10; i++) {
      final l = 'A$i';
      expect(c.unitIndex.withLabel(l).single.instance, handles[l], reason: l);
      // M-UA1: _detailsOf reading the data of `u.definition`.
      expect(detailOf(c, l).data, {'pos': l.toLowerCase()}, reason: l);
    }
    expect(detailOf(c, 'A3').colour, PlanSwatch.purple);
    expect(c.unitIndex.withLabel('A11'), isEmpty);
    expect(c.unitIndex.withLabel('A12'), isEmpty);
    c.undo();
    expect(c.unitIndex.withLabel('A11').single.instance, handles['A11']);
    expect(detailOf(c, 'A11').data, {'pos': 'a11'});
    expect(detailOf(c, 'A11').colour, PlanSwatch.teal);
    expect(detailOf(c, 'A12').data, {'pos': 'a12'});
  });

  test(
      'UA-seat-data data and a colour on a seat of the turned row: the '
      'write passes the guard, the detail reads them, its geometry is the '
      'seat\'s world place', () {
    final c = design();
    final seat = seatsLabelled(c, 'B')[1];
    final label = seat.text!;
    // M-UA2 (Task 2's guard, cross-check): the components-only write on a
    // generated instance refused.
    expect(c.setUnitData(label, const {'id': 'b2'}), isTrue);
    expect(c.setUnitColour(label, PlanSwatch.orange), isTrue);
    final d = detailOf(c, label);
    expect(d.data, {'id': 'b2'});
    expect(d.colour, PlanSwatch.orange);
    final box = c.document
        .definitionBounds(seat.definition, c.document.leavesByOwner());
    final centre = c.document.tree
        .accumulatedTransform(seat.instance)
        .transformPoint(
            Vector2((box.minX + box.maxX) / 2, (box.minY + box.maxY) / 2));
    expect(d.center!.dx, closeTo(centre.x, 1e-9));
    expect(d.center!.dy, closeTo(centre.y, 1e-9));
  });

  test(
      'UA-locked-write under a frozen row a seat takes no data, no colour '
      'and no label: false, no step, no lock hint', () {
    final c = design();
    final row = rowOf(c, 'A');
    c.lockBroken({row});
    final depth = c.document.commands.undoDepth;
    // M-UA3: the lock-set check removed (execute refuses, the hint shows).
    expect(c.setUnitData('A1', const {'id': 'x'}), isFalse);
    expect(c.setUnitColour('A1', PlanSwatch.red), isFalse);
    expect(c.lockHint.value, isFalse);
    expect(c.document.commands.undoDepth, depth);
    // The placed table is not under the frozen row: it takes data.
    expect(c.setUnitData(tableLabel(c), const {'id': 't'}), isTrue);
  });

  test(
      'UA-label-used a label another unit holds is refused, a seat\'s '
      'included; a free one is one Label step', () {
    final c = design();
    final table = tableLabel(c);
    final depth = c.document.commands.undoDepth;
    // M-UA4: the check against the other units' labels removed.
    expect(c.setUnitLabel(table, 'A1'), isFalse);
    expect(c.document.commands.undoDepth, depth);
    expect(c.setUnitLabel(table, ' 77 '), isTrue);
    expect(c.unitIndex.withLabel('77').single.generated, isFalse);
    expect(c.document.commands.undoDepth, depth + 1);
    expect(() => c.setUnitLabel('77', 'ninechars'), throwsArgumentError);
    expect(() => c.setUnitLabel('77', 'a\nb'), throwsArgumentError);
  });

  test('UA-label-seat a seat\'s label is its type\'s: setUnitLabel is false',
      () {
    final c = design();
    final seat = seatsLabelled(c, 'A').first;
    final text = c.document.entities
        .textAt(c.document.entities.slotOf(seat.label!)!);
    // M-UA5: `u.generated ||` dropped (the ATTRIB edit reaches the guard).
    expect(c.setUnitLabel(seat.text!, 'Z9'), isFalse);
    expect(
        c.document.entities.textAt(c.document.entities.slotOf(seat.label!)!),
        text);
  });

  test(
      'UA-labels-swap setUnitsLabel swaps two tables\' labels in one step; '
      'setUnitLabel alone to a held label is false', () {
    final c = controllerFor(kits: [fxKit()], json: unitEditorPlanJson());
    final one = c.unitIndex.withLabel('1').single.instance;
    final two = c.unitIndex.withLabel('2').single.instance;
    expect(c.setUnitLabel('1', '2'), isFalse);
    final depth = c.document.commands.undoDepth;
    // M-UA6: the after-call check reading the current labels only.
    expect(c.setUnitsLabel({'1': '2', '2': '1'}), isTrue);
    expect(c.document.commands.undoDepth, depth + 1);
    expect(c.unitIndex.withLabel('1').single.instance, two);
    expect(c.unitIndex.withLabel('2').single.instance, one);
    expect(c.setUnitsLabel({'1': '9', '2': '9'}), isFalse,
        reason: 'one label twice');
  });

  test(
      'UA-select-design select in design takes placed units only: a seat\'s '
      'label is ignored', () {
    final c = design();
    final table = c.unitIndex.units.singleWhere((u) => !u.generated);
    // M-UA7: `if (placedOnly && u.generated) continue;` removed.
    c.select({'A1', table.text!});
    expect(c.selection.keys, {SelectionKey.root(table.instance)});
    expect(c.editorSelectedUnits.value, {table.text});
  });

  test(
      'UA-fit-seat fitToUnits frames a seat by its label: true, and the '
      'framing is not the page\'s', () {
    final c = design();
    // M-UA8: generated units skipped in the units' bounds.
    expect(c.fitToUnits({'B1'}), isTrue);
    expect(c.framingFor(const Size(1440, 900)), isNotNull);
    expect(c.fitToUnits({'nope'}), isFalse);
  });

  test(
      'UA-changes-row a row edit reports one change per changed seat, an '
      'add or a remove per seat grown or shrunk, and a relabel as a change',
      () async {
    final c = design();
    final row = rowOf(c, 'A');
    final n = seatsLabelled(c, 'A').length;
    final seen = <PlanUnitChange>[];
    final sub = c.unitChanges.listen(seen.add);
    addTearDown(sub.cancel);
    setRowCount(c, row, n + 2);
    await Future<void>.delayed(Duration.zero);
    expect(seen.whereType<PlanUnitAdded>(), hasLength(2));
    expect(seen.whereType<PlanUnitRemoved>(), isEmpty);
    seen.clear();
    setRowCount(c, row, n);
    await Future<void>.delayed(Duration.zero);
    expect(seen.whereType<PlanUnitRemoved>(), hasLength(2));
    expect(seen.whereType<PlanUnitAdded>(), isEmpty);
    seen.clear();
    setRowPrefix(c, row, 'C');
    await Future<void>.delayed(Duration.zero);
    // M-UA9: the diff matching by label (a relabel as a remove and an add).
    expect(seen, hasLength(n));
    expect(seen, everyElement(isA<PlanUnitChanged>()));
    expect(
        seen.cast<PlanUnitChanged>().map((ch) => ch.after.unit.label),
        [for (var i = 1; i <= n; i++) 'C$i']);
  });
}
```

  Notes for the implementer: `EntityStore.textAt(slot)` is the engine's text read (`jet_cad_2d/lib/src/store/entity_store.dart:352`). `RowComponent` is Task 5's row component; see "Assumed".

- [ ] **Step 3: The ported tests.** Each file below is its source with the common adaptations, then the listed ones; **assertions unchanged** apart from the renamed names controller ruling R-13 accepts (the undo labels, the kind token in `PlanUnit`'s text, the DC tests ported a second time for `unitChanges`); each is a ledger ruling at execution.

  Common adaptations: the imports become the barrel, `unit_embedding_fixture.dart` (or `unit_editor_fixture.dart`), `unit_fixtures.dart`, `harness.dart`, and `package:jet_cad_2d_plan/src/units/unit_index.dart` where a test reads the index; `FloorPlanController(json: embeddingPlanJson())` → `PlanController(kits: [fxKit()], json: embeddingPlanJson())` (disposed at tear-down); `controller.cameraController.value` → `c.camera.value`; `c.camera` (today's value) → `c.cameraValue`; `c.activeDocument` → `c.document`; `c.activeSelection` → `c.selection`; `c.designJson()` → `c.save()`; `FloorPlanView(controller: c)` → `PlanEditor(controller: c)` (a view the test only needs mounted) or `PlanCanvas(controller: c)` (where the canvas's size is the premise: CM7, CR2); `c.tables` → `c.units`; `c.tableDetails` → `c.unitDetails`; `c.tableDetailInstances` → `c.unitDetailInstances`; `c.tableAt` → `c.unitAt`; `c.fitToTables` → `c.fitToUnits`; `c.numberingWarnings` → `c.labelWarnings`; `setTableData`/`setTablesData`/`setTableColor`/`setTablesColor` → `setUnitData`/`setUnitsData`/`setUnitColour`/`setUnitsColour`; `c.designChanges` → `c.unitChanges`; `c.designScans` → `c.debugUnitScans`; `c.selectedTables` (in design) → `c.editorSelectedUnits`; `FloorPlanTable(number: n, seats: s, symbolKey: k, visible: v)` → `PlanUnit(label: n, kind: 'table', capacity: s, symbolKey: k, visible: v)`; `FloorPlanTableDetail` → `PlanUnitDetail`, `.table` → `.unit`, `.table.number` → `.unit.label`, `.table.seats` → `.unit.capacity`, `.color` → `.colour`; `FloorPlanColor.x` → `PlanSwatch.x`; `FloorPlanTableAdded`/`Removed`/`Changed`/`FloorPlanPlanReplaced` → `PlanUnitAdded`/`Removed`/`Changed`/`PlanUnitsReplaced`; `TableSurvey.of(doc).withNumber(n)` → `c.unitIndex.withLabel(n)` (or `UnitIndex.of(doc, catalog: c.catalog, locks: …)` on a bare document), `.tables` → `.units`, `.number` → `.text`; `kTableLabelTag` → `kUnitLabelTag`; `'jetcad.table_data'` → `'jetcad.unit_data'`, `'jetcad.table_color'` → `'jetcad.unit_colour'`, `{"color": …}` → `{"colour": …}` only if Task 6's `UnitColour.toJson` writes `colour` (read Task 6's component); `registerAppComponents` → the plan's own decode (`decodePlan(json, register: …)` with the controller's components: `PlanController(kits: [fxKit()], json: json).document`); the test symbol `'test.embedding'` → `'fx.embedding.four'`.

  1. `test/controller/unit_detail_test.dart` from `host/table_detail_test.dart`: TD0, TD1, TD2, TD3, TD4, TD5, TD6, TD7, TD8, TD9, TD11, TD12, TD13, TD10, TA1, TA2. TA3 ("tableAt follows the camera and the mode: a service move is found") is Task 11's (it needs the mode; its move is a command, no tool). TD12's pure builder test calls `unitDetailOf` (`units/unit_detail.dart`) where it called `tableDetailOf`. TD10's expected `toString` follows the renamed types: `'PlanUnitDetail(PlanUnit(7, table, 4, k, visible: true), center: Offset(40700.0, -26900.0), size: Size(800.0, 600.0), rotation: 0.5, mirrored: true, corners: [Offset(1.0, 2.0), Offset(3.0, 4.0)], layer: L, locked: true, data: {})'` (finding F-T9b).
  2. `test/controller/unit_data_test.dart` from `host/table_data_test.dart`: HD1, HD2, HD3, HD5, HD6, HD7, HD8, HD9, HD10, HD11, HD12. HD4 (the selection mode throws a `StateError`) is Task 11's (its Step 3 appends it to this file). HD10's "renumbering 1 to 21" writes `c.setUnitLabel('1', '21')` where the source wrote the label's text by `SetEntityTextCommand`, if the source does so through the controller's document: keep the source's own command (`SetEntityTextCommand(label, '21', kUnitLabelTag)` on `c.document`) so the premise is the same. HD12 mounts `PlanEditor(controller: c)`. HD8's expected label `'Table data'` → `'Unit data'` (finding F-T9a). `fixtureWith` rewrites `'jetcad.unit_data'`.
  3. `test/controller/unit_colour_test.dart` from `host/table_color_test.dart`: TC2, TC3, TC4, TC5, TC7, TC8, TC9. TC1 (the component's encoding) is Task 6's (its Step 12 item 3 ports it). TC6 (the selection mode) is Task 11's (its Step 3 appends it to this file). TC2/TC3's expected label `'Table colour'` → `'Unit colour'` (finding F-T9a). TC8 deletes in `PlanEditor`.
  4. `test/controller/unit_changes_test.dart` from `host/design_changes_test.dart`: DC1, DC2, DC3, DC4, DC5, DC6, DC8, DC9, DC11, DC12, DC13, DC14, DC17, DC18, DC19. DC7, DC10, DC15 and DC16 need the service mode (Tasks 11 and 14). DC3's renumber writes the label's text on `c.document` as the source does. DC13's and DC14's `toString` texts follow the renamed types (finding F-T9b). **DC8, DC9, DC11, DC12, DC13 and DC17 were ported by 2a to `test/controller/plan_change_test.dart` for the object-level `changes` stream**; they are ported again here for `unitChanges`, the stream that maps today's `designChanges` (spec S5), whose behaviour (replaced, an edit then a load, nothing read with no listener, dispose, the four types' equality, a failed load) is its own code (finding F-T9c).
  5. `test/units/unit_fit_test.dart` from `host/table_fit_test.dart`: TF1, TF2, TF3, TF4. `frameTables` → `frameUnits`, `kTableFitMarginMm`/`kTableFitMinSpanMm` → `kUnitFitMarginMm`/`kUnitFitMinSpanMm`, `kMinScale`/`kMaxScale` → `kPlanMinScale`/`kPlanMaxScale`.
  6. `test/controller/non_finite_unit_test.dart` from `host/non_finite_table_test.dart`: NT1 (`PlanEditor`; `c.select({'9'})`, `c.editorSelectedUnits.value`), NT2 (`pdfOperators(json)` exports with `await c.export('plan.pdf', PlanExportChoice.initial)` (2a's built-in PDF exporter, `export/builtin_exporters.dart:37`) and parses the export's bytes with `PdfContent.parse` as the source does).
  7. `test/controller/unit_camera_test.dart` from `host/camera_test.dart`: CM1, CM2 (`FloorPlanCamera(t)` → `PlanCamera(t)`), CM3 (`c.camera` → `c.cameraValue`), CM7 (mounted as `SizedBox(width: 1440, height: 856, child: PlanCanvas(controller: c, rulers: false))`, so its premise `Size(1440, 856)` holds; `fitToTables({'1'})` → `fitToUnits({'1'})`), CR2 (the view is `PlanCanvas(controller: c)`; `canvasOnScreen(tester)` is the `InteractionLayer`'s rect). CM4-CM6 and CM15 are 2a's (`test/controller/camera_test.dart`); CR1, CR3-CR6, CM8-CM14, CM16 have no unit premise (2a's ground, or Task 11's for CR4's mode switch).
  8. `test/editor/units_only_select_test.dart` (Task 8's file) gains `editor_select_test.dart`'s T5-c (`:332-358`: `c.setTableData('1', …)` → `c.setUnitData('1', …)`; `dataOf1()` reads `c.unitDetails.where((d) => d.unit.label == '1').firstOrNull?.data`; `TableSurvey.of(c.activeDocument).withNumber('1')` → `unitsIn(c).withLabel('1')`) and T5-d (`:362-379`: `c.selectedTables` → `c.editorSelectedUnits`; `liveObjectsOf<WallParams>(d).first` → the north wall's line, `editorNorthWall` found among the root lines; `liveObjectsOf<WallParams>(d), contains(wall.target)` → that line still live).
  9. `test/l10n/value_words_test.dart` (2a's file) gains VW4 (`l10n/value_words_test.dart:90-114`): three `tableSymbol(seats: 4)` units placed with `placeAt` on `unitPlan()` at the source's points and turns, labelled `'1'`, `''`→ none and `'1'` as the source leaves them (label the first `'1'`, the third `'1'` (the source's `'3'` rewritten to `'1'`), the second unlabelled), a fourth labelled `'4'`; the plan encoded with `encodePlan(doc, validateKitSet([fxKit()]))`; `c.numberingWarnings` → `c.labelWarnings`; `const [DuplicateNumber(number: '1', count: 2), Unnumbered(seats: 4, symbolKey: 'test.table')]` → `const [DuplicateLabel(label: '1', count: 2), Unlabelled(kind: 'table', capacity: 4, symbolKey: 'fx.table.two')]` (the renamed types; the `kind` field is Task 6's).

- [ ] **Step 4: Run the tests, see them fail.** Run: `cd packages/jet_cad_2d_plan && flutter test test/units/unit_api_test.dart test/controller/unit_detail_test.dart`. Expected: compile errors — `unitDetails`, `PlanUnit`, `PlanUnitDetail`, `setUnitData`, `unitChanges` and the rest are not defined (`unitIndex` is Task 6's and compiles).

- [ ] **Step 5: The unit types.** Create `lib/src/units/unit_detail.dart`. `PlanUnit` is today's `FloorPlanTable` (`floor_plan_types.dart:17-58`) with `kind`, `capacity` (today's `seats`) and `generatedBy`; `PlanUnitDetail` and its builders are `host/table_detail.dart:14-188` verbatim but for the names (`table` → `unit`, `color` → `colour`, `FloorPlanColor` → `PlanSwatch`) and the doc comments' words (a table → a unit); the four changes and the diff are `host/design_changes.dart:12-129` likewise. The code, whole:

```dart
// A unit for an embedding host (spec 2b S3 "The unit API"): what the
// controller lists (PlanUnit), with its geometry, layer, lock and the
// host's data and colour (PlanUnitDetail), and the design's unit changes
// (PlanUnitChange). Ported from jet_cad_floor_plan's FloorPlanTable
// (host/floor_plan_types.dart:17-58), FloorPlanTableDetail and its builders
// (host/table_detail.dart) and the design changes (host/design_changes.dart).
// Never a handle (umbrella D18).
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart' show Offset, Size;
import 'package:jet_cad_2d/jet_cad_2d.dart' show Aabb2, Handle, Transform2;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show PlanSwatch;

/// One unit of the active plan, as a host sees it: never a handle.
@immutable
final class PlanUnit {
  const PlanUnit(
      {required this.label,
      required this.kind,
      required this.capacity,
      required this.symbolKey,
      this.visible = true,
      this.generatedBy});

  /// The unit's label, trimmed, or null while it has none.
  final String? label;

  /// Its kind (`table`, `seat`, a kit's own): its definition's.
  final String kind;

  /// How many it serves: its definition's.
  final int capacity;

  /// The library key of its symbol, or null for a hand-made one.
  final String? symbolKey;

  /// Whether its layer is shown: false for a unit on a hidden layer, which
  /// the view neither shows nor lets anyone pick.
  final bool visible;

  /// The type id of the object that generates it (a seat's row), or null
  /// for a placed unit.
  final String? generatedBy;

  @override
  bool operator ==(Object other) =>
      other is PlanUnit &&
      other.label == label &&
      other.kind == kind &&
      other.capacity == capacity &&
      other.symbolKey == symbolKey &&
      other.visible == visible &&
      other.generatedBy == generatedBy;

  @override
  int get hashCode =>
      Object.hash(label, kind, capacity, symbolKey, visible, generatedBy);

  @override
  String toString() => 'PlanUnit($label, $kind, $capacity, $symbolKey, '
      'visible: $visible${generatedBy == null ? '' : ', generatedBy: $generatedBy'})';
}

/// One unit of the active plan with its geometry (today's
/// `FloorPlanTableDetail`, table_detail.dart:14-124), as
/// `PlanController.unitDetails` lists it. World coordinates are
/// millimetres with y up. A unit's placement (its world transform: group ×
/// instance for a generated one) is read as `R(rotation) · diag(sx, sy)`
/// with `sx > 0`: [mirrored] means `sy < 0`. A unit the planner neither
/// shows nor picks -- on a hidden layer, or a placement that is singular or
/// has a corner that is not finite -- reports no geometry: [center] and
/// [size] null, [corners] empty, [rotation] 0 and [mirrored] false.
@immutable
final class PlanUnitDetail {
  const PlanUnitDetail({
    required this.unit,
    required this.center,
    required this.size,
    required this.rotation,
    required this.mirrored,
    required this.corners,
    required this.layer,
    required this.locked,
    this.data = const <String, String>{},
    this.colour,
  });

  final PlanUnit unit;

  /// The centre of the symbol's bounding box in the world.
  final Offset? center;

  /// The symbol box's width and height in world millimetres.
  final Size? size;

  /// The unit's turn, radians, counter-clockwise (y up), in `(-π, π]`.
  final double rotation;

  /// Whether the placement mirrors (its determinant is negative).
  final bool mirrored;

  /// The symbol box's four corners in the world, counter-clockwise (y up)
  /// whatever the mirror, starting at the image of the box's (min x, min
  /// y) corner. Unmodifiable as the controller lists it.
  final List<Offset> corners;

  /// The name of the instance's layer (a generated unit's is its object's);
  /// empty when the layer is missing from the plan's layers.
  final String layer;

  /// Whether the unit is locked (`isLockedUnit`: a locked layer, or a
  /// frozen or a missing kit's object or symbol): tapped and reported,
  /// never selected or moved.
  final bool locked;

  /// The host's data on the unit, keys ascending, unmodifiable. Empty for
  /// a unit with none, and for one whose stored data is outside the limits
  /// (kept as read, never refused).
  final Map<String, String> data;

  /// The unit's colour, or null for none and for a stored name this
  /// release cannot read (kept as read).
  final PlanSwatch? colour;

  @override
  bool operator ==(Object other) =>
      other is PlanUnitDetail &&
      other.unit == unit &&
      other.center == center &&
      other.size == size &&
      other.rotation == rotation &&
      other.mirrored == mirrored &&
      listEquals(other.corners, corners) &&
      other.layer == layer &&
      other.locked == locked &&
      mapEquals(other.data, data) &&
      other.colour == colour;

  @override
  int get hashCode => Object.hash(
      unit,
      center,
      size,
      rotation,
      mirrored,
      Object.hashAll(corners),
      layer,
      locked,
      Object.hashAllUnordered(
          [for (final e in data.entries) Object.hash(e.key, e.value)]),
      colour);

  @override
  String toString() => 'PlanUnitDetail($unit, center: $center, '
      'size: $size, rotation: $rotation, mirrored: $mirrored, '
      'corners: $corners, layer: $layer, locked: $locked, data: $data'
      '${colour == null ? '' : ', colour: $colour'})';
}

/// The detail of [unit], placed by [transform] over the symbol box [box],
/// whose world corners are [corners] (`x0, y0, ..., x3, y3`, as
/// `UnitCandidate` carries them). table_detail.dart:132-167.
PlanUnitDetail unitDetailOf(
    {required PlanUnit unit,
    required Transform2 transform,
    required Aabb2 box,
    required Float64List corners,
    required String layer,
    required bool locked,
    Map<String, String> data = const <String, String>{},
    PlanSwatch? colour}) {
  final m = transform;
  var rotation = math.atan2(m.b, m.a);
  if (rotation <= -math.pi) rotation += 2 * math.pi;
  if (rotation == 0) rotation = 0.0;
  final mirrored = m.determinant < 0;
  final cx = (box.minX + box.maxX) / 2, cy = (box.minY + box.maxY) / 2;
  Offset at(int i) => Offset(corners[2 * i], corners[2 * i + 1]);
  return PlanUnitDetail(
    unit: unit,
    center: Offset(m.a * cx + m.c * cy + m.e, m.b * cx + m.d * cy + m.f),
    size: Size((box.maxX - box.minX) * math.sqrt(m.a * m.a + m.b * m.b),
        (box.maxY - box.minY) * math.sqrt(m.c * m.c + m.d * m.d)),
    rotation: rotation,
    mirrored: mirrored,
    corners: List.unmodifiable(
        mirrored ? [at(0), at(3), at(2), at(1)] : [at(0), at(1), at(2), at(3)]),
    layer: layer,
    locked: locked,
    data: data,
    colour: colour,
  );
}

/// The detail of a unit that reports no geometry (table_detail.dart:
/// 169-188).
PlanUnitDetail unitDetailWithoutGeometry(
        {required PlanUnit unit,
        required String layer,
        required bool locked,
        Map<String, String> data = const <String, String>{},
        PlanSwatch? colour}) =>
    PlanUnitDetail(
        unit: unit,
        center: null,
        size: null,
        rotation: 0,
        mirrored: false,
        corners: const <Offset>[],
        layer: layer,
        locked: locked,
        data: data,
        colour: colour);

/// One change of the design's units (today's `FloorPlanDesignChange`), as
/// `PlanController.unitChanges` reports it.
@immutable
sealed class PlanUnitChange {
  const PlanUnitChange();
}

/// A unit now in the design that was not: placed, generated by a grown
/// row, or a delete undone (then [unit] equals the [PlanUnitRemoved.unit]
/// the delete reported, its data included).
final class PlanUnitAdded extends PlanUnitChange {
  const PlanUnitAdded(this.unit);
  final PlanUnitDetail unit;

  @override
  bool operator ==(Object other) =>
      other is PlanUnitAdded && other.unit == unit;

  @override
  int get hashCode => Object.hash(PlanUnitAdded, unit);

  @override
  String toString() => 'PlanUnitAdded($unit)';
}

/// A unit no longer in the design: deleted, dropped by a shrunk row, or
/// its placement undone.
final class PlanUnitRemoved extends PlanUnitChange {
  const PlanUnitRemoved(this.unit);
  final PlanUnitDetail unit;

  @override
  bool operator ==(Object other) =>
      other is PlanUnitRemoved && other.unit == unit;

  @override
  int get hashCode => Object.hash(PlanUnitRemoved, unit);

  @override
  String toString() => 'PlanUnitRemoved($unit)';
}

/// One unit whose detail changed: its label, kind, capacity, symbol,
/// geometry, layer, lock, visibility, data or colour. [before] and [after]
/// are the same unit (the same instance), whatever its label reads.
final class PlanUnitChanged extends PlanUnitChange {
  const PlanUnitChanged(this.before, this.after);
  final PlanUnitDetail before;
  final PlanUnitDetail after;

  @override
  bool operator ==(Object other) =>
      other is PlanUnitChanged && other.before == before && other.after == after;

  @override
  int get hashCode => Object.hash(PlanUnitChanged, before, after);

  @override
  String toString() => 'PlanUnitChanged($before, $after)';
}

/// The design was replaced whole (`load`, `newPlan`): a host reads
/// `unitDetails` again.
final class PlanUnitsReplaced extends PlanUnitChange {
  const PlanUnitsReplaced();

  @override
  bool operator ==(Object other) => other is PlanUnitsReplaced;

  @override
  int get hashCode => (PlanUnitsReplaced).hashCode;

  @override
  String toString() => 'PlanUnitsReplaced()';
}

/// The changes from [before] to [after] (design_changes.dart:101-129), each
/// list ascending by instance with [beforeInstances] and [afterInstances]
/// naming each entry's instance index for index. O(before + after).
List<PlanUnitChange> diffUnitDetails(
    List<Handle> beforeInstances,
    List<PlanUnitDetail> before,
    List<Handle> afterInstances,
    List<PlanUnitDetail> after) {
  final out = <PlanUnitChange>[];
  var i = 0, j = 0;
  while (i < before.length || j < after.length) {
    final a = i < before.length ? beforeInstances[i].value : null;
    final b = j < after.length ? afterInstances[j].value : null;
    if (b == null || (a != null && a < b)) {
      out.add(PlanUnitRemoved(before[i++]));
    } else if (a == null || b < a) {
      out.add(PlanUnitAdded(after[j++]));
    } else {
      if (before[i] != after[j]) {
        out.add(PlanUnitChanged(before[i], after[j]));
      }
      i++;
      j++;
    }
  }
  return out;
}
```

  (`Float64List` comes through `package:flutter/foundation.dart`; if the analyzer asks, import `dart:typed_data`.)

- [ ] **Step 6: The camera and the fit.** Create `lib/src/controller/plan_camera.dart`: `host/floor_plan_camera.dart:1-72` verbatim, `FloorPlanCamera` → `PlanCamera` in the class, its constructor and `toString` (`'PlanCamera(scale: …'`), the doc comments' "the selection mode" → "the service mode". Create `lib/src/units/unit_fit.dart`: `host/table_fit.dart:1-62` verbatim, `kTableFitMarginMm` → `kUnitFitMarginMm`, `kTableFitMinSpanMm` → `kUnitFitMinSpanMm`, `frameTables` → `frameUnits`, "tables" → "units" in the comments, and the import of `kMinScale`/`kMaxScale` → `import '../controller/camera_bounds.dart' show kPlanMaxScale, kPlanMinScale;` with the defaults `minScale = kPlanMinScale, maxScale = kPlanMaxScale`.

- [ ] **Step 7: The label's command.** Create `lib/src/units/unit_writes.dart`. A new label is Task 6's `addUnitLabelCommand` (the placer's record and today's height rule, `placedLabelTopOf`; controller ruling R-21), so nothing is copied here:

```dart
// The one command that gives a placed unit a label (spec 2b S2 "The
// label", S3 setUnitLabel; Task 10's unit section): the label ATTRIB's
// text when the unit has one, its own tag passed back (a blank tag would
// lose it), else a new UNIT ATTRIB stamped as the placer stamps a numbered
// unit's (today's _writeNumber and addTableLabelCommand,
// selection_panel.dart:663-683, tables/table_label.dart:105-153).
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show kUnitLabelTag;

import 'unit_index.dart';
import 'unit_label.dart' show addUnitLabelCommand;

/// The command that makes [text] the label of the placed unit [unit] of
/// [doc], or null when [text] already is its label (compared trimmed, as
/// the label reads). Allocates one handle for a new label. The caller has
/// checked the text rule and that no other unit holds [text].
DraftCommand? unitLabelCommand(DraftDocument doc, UnitInfo unit, String text) {
  if ((unit.text ?? '') == text.trim()) return null;
  final label = unit.label;
  if (label != null) return SetEntityTextCommand(label, text, kUnitLabelTag);
  final node = doc.tree[unit.instance]! as InstanceNode;
  return addUnitLabelCommand(doc,
      instance: unit.instance,
      definition: node.definition,
      placement: node.transform,
      text: text);
}
```

- [ ] **Step 8: The controller.** In `lib/src/controller/plan_controller.dart`:
  1. Imports: `dart:ui` gains `PointerDeviceKind` (`import 'dart:ui' show Locale, Offset, PointerDeviceKind, Rect, Size;`); add `package:vector_math/vector_math_64.dart' show Vector2`, `'../service/unit_picker.dart'`, `'../units/unit_detail.dart'`, `'../units/unit_fit.dart'`, `'../units/unit_index.dart'`, `'../units/unit_label.dart'` (Task 6: `unitLabelProblem`), `'../units/unit_problems.dart'` (Task 6: `UnitLabelWarning`), `'../units/unit_components.dart'` (Task 6: `UnitData`, `UnitColour`, `unitDataProblem`), `'../units/unit_writes.dart'`, `'plan_camera.dart'`.
  2. The fit target (`:53-63` and `:1185`): `_Centre` becomes a subclass of a sealed target, and a framing of units joins it:

```dart
/// What a requested fit frames: a centring or some units.
sealed class _FitTarget {
  const _FitTarget();
}

/// A queued centring (today's `_Centre`): [world] at the canvas's centre.
final class _Centre extends _FitTarget {
  const _Centre(this.world, this.scale, {required this.pageScale});

  final Offset world;
  final double? scale;

  /// Asked with no [scale] before the plan's first fit: the page fit's
  /// scale at the canvas's size.
  final bool pageScale;
}

/// A queued framing of the units carrying [labels] (today's `_Tables`,
/// floor_plan_controller.dart:112-115), found again when it is performed.
final class _Units extends _FitTarget {
  const _Units(this.labels);
  final Set<String> labels;
}

/// The public camera (today's `_CameraValue`, floor_plan_controller.dart:
/// 128-155): one [PlanCamera] per camera value, made at the first read
/// after a change. Listening is the camera controller's own.
final class _PlanCameraValue implements ValueListenable<PlanCamera> {
  _PlanCameraValue(this._camera);

  final CameraController _camera;
  ViewportTransform? _for;
  PlanCamera? _value;

  @override
  PlanCamera get value {
    final now = _camera.value;
    if (!identical(now, _for)) {
      _for = now;
      _value = PlanCamera(now);
    }
    return _value!;
  }

  @override
  void addListener(VoidCallback listener) => _camera.addListener(listener);

  @override
  void removeListener(VoidCallback listener) =>
      _camera.removeListener(listener);
}

/// The design's units as last reported for `unitChanges` (today's
/// `_DesignBaseline`, floor_plan_controller.dart:2180-2196): at the design
/// while its index is the identical object.
final class _UnitBaseline {
  const _UnitBaseline(this.index, this.instances, this.details);

  final UnitIndex index;
  final List<Handle> instances;
  final List<PlanUnitDetail> details;

  bool isAt(UnitIndex now) => identical(index, now);
}
```

     `_Centre? _fitTarget;` becomes `_FitTarget? _fitTarget;`, and `framingFor` becomes:

```dart
  @internal
  ViewportTransform? framingFor(Size viewport) {
    final ViewportTransform framing;
    switch (_fitTarget) {
      case null:
        return null;
      case _Units(:final labels):
        final box = _unitsBounds(labels);
        if (box == null) return null;
        framing = frameUnits(box, viewport,
            minScale: _minScale, maxScale: _maxScale);
      case _Centre(:final world, :final scale, :final pageScale):
        framing = _centred(
            world,
            pageScale
                ? _pageFit(_activeDocument, viewport)
                    .worldToScreenMatrix
                    .scaleMagnitude
                : scale,
            viewport);
    }
    final m = framing.worldToScreenMatrix;
    return [m.a, m.b, m.c, m.d, m.e, m.f].every((v) => v.isFinite)
        ? framing
        : null;
  }
```

  3. The seams and the unit state, after the "Locks" section. Task 6's `unitIndex` getter (after `isLocked`, `=> _session.units.current`) is deleted: it is declared once, below, over the seam (controller ruling R-10: it landed in Task 6, and reads the same here until Task 11 re-points the seam).

```dart
  // ---------------------------------------------------------------------
  // The unit API (spec 2b S3), design side (Task 9). Task 11 re-points the
  // seams below to the service copy in service; every member that switches
  // on the mode reads them.

  /// The active document's units (Task 11: the copy's in service).
  UnitIndexCache get _activeUnits => _session.units;

  /// The active document (Task 11: the copy in service).
  DraftDocument get _activeDocument => _session.document;

  /// The active selection (Task 11: the copy's in service).
  SelectionController get _activeSelection => _session.selection;

  /// Whether the design is the active document (Task 11: the mode).
  bool get _inDesign => true;

  /// Throws a [StateError] naming [who] in service (Task 11): a design
  /// write is refused there (spec S3). Nothing in design.
  void _requireDesign(String who) {}

  /// [labels], each label of a group replaced by its members in service
  /// (Task 12). The labels as given in design.
  Set<String> _expandLabels(Set<String> labels) => labels;

  /// The active document's unit index (`@internal`): the panels, the
  /// inspector and the tests read it.
  @internal
  UnitIndex get unitIndex => _activeUnits.current;

  final ValueNotifier<int> _revision = ValueNotifier(0);

  /// Moves whenever the active plan changes: an edit, an undo or a redo of
  /// it, [load], [newPlan] (Task 11 adds the mode switch, Task 13 the reset
  /// and the restore). A host re-reads [units] and [labelWarnings] on it.
  ValueListenable<int> get revision => _revision;

  late final _PlanCameraValue _cameraValue = _PlanCameraValue(camera);

  /// Where the plan is on the canvas: a new [PlanCamera] at every pan, zoom
  /// and fit; two reads with no camera change in between are identical.
  ValueListenable<PlanCamera> get cameraValue => _cameraValue;

  /// The global point that shows [world], or null with no canvas mounted.
  Offset? worldToGlobal(Offset world) {
    final rect = _canvasRect.value;
    if (rect == null) return null;
    return cameraValue.value.worldToCanvas(world) + rect.topLeft;
  }

  /// The world point shown at the global point [global], or null with no
  /// canvas mounted.
  Offset? globalToWorld(Offset global) {
    final rect = _canvasRect.value;
    if (rect == null) return null;
    return cameraValue.value.canvasToWorld(global - rect.topLeft);
  }

  /// The active plan's units, ascending by instance, placed and generated
  /// (a unit on a hidden layer is listed, [PlanUnit.visible] false).
  List<PlanUnit> get units => [
        for (final u in _activeUnits.current.units) _unitOf(u),
      ];

  static PlanUnit _unitOf(UnitInfo u) => PlanUnit(
      label: u.text,
      kind: u.kind,
      capacity: u.capacity,
      symbolKey: u.symbolKey,
      visible: u.visible,
      generatedBy: u.ownerType);

  List<PlanUnitDetail>? _details;
  List<Handle> _detailInstances = const [];
  UnitIndex? _detailsIndex;

  /// The active plan's units with their geometry (today's `tableDetails`,
  /// floor_plan_controller.dart:1495-1514), ascending by instance like
  /// [units], one per unit. Cached per unit index (a state, a layer or a
  /// lock change makes a new one): two reads with nothing changed return
  /// the identical, unmodifiable list.
  List<PlanUnitDetail> get unitDetails {
    final index = _activeUnits.current;
    if (_details == null || !identical(index, _detailsIndex)) {
      final instances = <Handle>[];
      _details = _detailsOf(_activeDocument, index, instances);
      _detailInstances = List.unmodifiable(instances);
      _detailsIndex = index;
    }
    return _details!;
  }

  /// The instance of each entry of [unitDetails], index for index (the
  /// inspector and the overlays key by it). Never a host's.
  @internal
  List<Handle> get unitDetailInstances {
    unitDetails;
    return _detailInstances;
  }

  /// [index]'s units of [d] joined to the picker's candidates by instance
  /// (today's `_detailsOf`, :1527-1555), each instance added to
  /// [instances] in the same order. O(nodes + entities), at document-change
  /// rate.
  List<PlanUnitDetail> _detailsOf(
      DraftDocument d, UnitIndex index, List<Handle> instances) {
    final candidates = {
      for (final c in UnitPicker.candidatesOf(d, index,
          boxes: <Handle, Aabb2>{}, leaves: d.leavesByOwner))
        c.unit.instance: c,
    };
    final layers = d.tables.layers;
    final details = <PlanUnitDetail>[];
    for (final u in index.units) {
      final node = d.tree[u.instance];
      if (node is! InstanceNode) continue;
      instances.add(u.instance);
      final unit = _unitOf(u);
      final layer = layers[node.layer]?.name ?? '';
      final data = d.components.get<UnitData>(u.instance)?.data ??
          const <String, String>{};
      final colour = d.components.get<UnitColour>(u.instance)?.swatch;
      final c = candidates[u.instance];
      details.add(c == null
          ? unitDetailWithoutGeometry(
              unit: unit,
              layer: layer,
              locked: u.locked,
              data: data,
              colour: colour)
          : unitDetailOf(
              unit: unit,
              transform: c.transform,
              box: c.box,
              corners: c.corners,
              layer: layer,
              locked: u.locked,
              data: data,
              colour: colour));
    }
    return List.unmodifiable(details);
  }

  /// The active plan's labelling problems (today's `numberingWarnings`):
  /// duplicates by first appearance, then the unlabelled units, then the
  /// bad labels (Task 6's order).
  List<UnitLabelWarning> get labelWarnings => _activeUnits.current.warnings();

  UnitPicker? _atPicker;
  UnitIndex? _atIndex;

  /// The label of the unit at [canvasPoint] (today's `tableAt`, :1792-
  /// 1818): a point on its top, else in its symbol's box, the one drawn on
  /// top among several; for a touch, failing both, the unit whose box is
  /// nearest within a finger's reach (24 px). A unit on a hidden layer is
  /// never found; a locked one is; an unlabelled one answers null.
  String? unitAt(Offset canvasPoint,
      {PointerDeviceKind kind = PointerDeviceKind.mouse}) {
    final units = _activeUnits;
    final index = units.current;
    var picker = _atPicker;
    if (picker == null ||
        !identical(picker.units, units) ||
        !identical(_atIndex, index)) {
      picker = _atPicker = UnitPicker(_activeDocument, units);
      _atIndex = index;
    }
    final cam = camera.value;
    final world = cam.screenToWorld(Vector2(canvasPoint.dx, canvasPoint.dy));
    final reach = kind == PointerDeviceKind.touch
        ? kTouchPickRadiusPixels / cam.scale
        : 0.0;
    return picker.pick(world, reach: reach)?.text;
  }

  /// Selects every unit carrying one of [labels] that the selection can
  /// hold -- visible, not locked -- replacing the selection (today's
  /// `select`, :1834-1870). A label two units share selects both; an
  /// unknown one is ignored. In design, placed units only (the design's
  /// selection holds root objects).
  void select(Set<String> labels) {
    settlePendingInput();
    _select(labels);
  }

  void _select(Set<String> labels) {
    final index = _activeUnits.current;
    final placedOnly = _inDesign;
    final keys = <SelectionKey>[];
    for (final l in _expandLabels(labels)) {
      for (final u in index.withLabel(l)) {
        if (placedOnly && u.generated) continue;
        if (!u.visible || u.locked) continue;
        keys.add(SelectionKey.root(u.instance));
      }
    }
    _activeSelection.replace(keys);
    _refreshSelected();
  }

  final ValueNotifier<Set<String>> _selectedUnits =
      ValueNotifier(const <String>{});
  final ValueNotifier<Set<String>> _editorSelected =
      ValueNotifier(const <String>{});

  /// The labels of the units selected in the design's editor (today's
  /// `editorSelectedTables`, :796-800): the active selection's in design,
  /// empty in service. Unmodifiable; it notifies only when the set changes.
  ValueListenable<Set<String>> get editorSelectedUnits => _editorSelected;

  /// The labels of the active selection's units (today's
  /// `_refreshSelected`, :1921-1940).
  void _refreshSelected() {
    final index = _activeUnits.current;
    final labels = <String>{
      for (final k in _activeSelection.keys)
        if (k.chain.isEmpty)
          if (index[k.target]?.text case final t?) t,
    };
    if (!setEquals(labels, _selectedUnits.value)) {
      _selectedUnits.value = Set.unmodifiable(labels);
    }
    final editor = _inDesign ? _selectedUnits.value : const <String>{};
    if (!setEquals(editor, _editorSelected.value)) {
      _editorSelected.value = editor;
    }
  }

  /// Frames the units of the active plan carrying one of [labels] (today's
  /// `fitToTables`, :2068-2093): labels trimmed, blanks dropped; a label
  /// two units share frames both; a unit on a hidden layer is not framed,
  /// a locked one is; an unlabelled unit never matches. The world framed is
  /// the bound of each unit's box at its place, grown by [kUnitFitMarginMm]
  /// per side and to at least [kUnitFitMinSpanMm] per axis. Returns whether
  /// one such unit exists now; when none does, nothing changes. Not
  /// document state.
  bool fitToUnits(Set<String> labels) {
    final wanted = Set<String>.unmodifiable({
      for (final l in labels)
        if (l.trim() case final t when t.isNotEmpty) t,
    });
    if (_unitsBounds(wanted) == null) return false;
    _fitTarget = _Units(wanted);
    _request();
    return true;
  }

  Aabb2? _unitsBounds(Set<String> labels) {
    final d = _activeDocument;
    var box = Aabb2.empty();
    for (final c in UnitPicker.candidatesOf(d, _activeUnits.current,
        boxes: <Handle, Aabb2>{}, leaves: d.leavesByOwner)) {
      if (labels.contains(c.unit.text)) box = box.union(c.worldBounds);
    }
    return box.isEmpty ? null : box;
  }

  /// Stores the host's [data] on the unit labelled [label] (today's
  /// `setTableData`, :1593): one design edit, labelled "Unit data",
  /// undoable, saved with the plan, read back as [PlanUnitDetail.data]. An
  /// empty map removes the data. True when the unit's data is now [data];
  /// false, changing nothing, when the trimmed [label] names no unit or
  /// several, or a unit under a locked object (spec S3). A unit on a hidden
  /// or locked layer takes data. Not gated by [permissions] (a host call).
  /// A [StateError] in service; an [ArgumentError] outside the limits.
  bool setUnitData(String label, Map<String, String> data) =>
      setUnitsData({label: data});

  /// [setUnitData] for several units, all or nothing, one undo step.
  bool setUnitsData(Map<String, Map<String, String>> byLabel) {
    _requireDesign('setUnitData');
    final wanted = <String, UnitData?>{};
    for (final MapEntry(key: label, value: data) in byLabel.entries) {
      if (unitDataProblem(data) case final problem?) {
        throw ArgumentError.value(data, 'data', problem);
      }
      wanted[label] = data.isEmpty ? null : UnitData(data);
    }
    return _setUnitComponents<UnitData>(wanted, 'Unit data');
  }

  /// Gives the unit labelled [label] the swatch [colour] (null removes it),
  /// one "Unit colour" step (today's `setTableColor`, :1631), under
  /// [setUnitData]'s rules.
  bool setUnitColour(String label, PlanSwatch? colour) =>
      setUnitsColour({label: colour});

  /// [setUnitColour] for several units, all or nothing, one undo step.
  bool setUnitsColour(Map<String, PlanSwatch?> byLabel) {
    _requireDesign('setUnitColour');
    return _setUnitComponents<UnitColour>({
      for (final MapEntry(key: l, value: c) in byLabel.entries)
        l: c == null ? null : UnitColour(c),
    }, 'Unit colour');
  }

  /// The one path of the data and colour writes (today's
  /// `_setTableComponents`, :1650-1673).
  bool _setUnitComponents<T extends Component>(
      Map<String, T?> wanted, String label) {
    settlePendingInput();
    final index = _session.units.current;
    final doc = document;
    final labels = <String>{};
    final edits = <DraftCommand>[];
    for (final MapEntry(key: raw, value: next) in wanted.entries) {
      if (!labels.add(raw.trim())) return false;
      final found = index.withLabel(raw);
      if (found.length != 1) return false;
      final instance = found.single.instance;
      if (_session.locks.covers(doc, instance)) return false;
      if (doc.components.get<T>(instance) == next) continue;
      edits.add(SetComponentCommand<T>(instance, next));
    }
    return _runHostEdit(edits, label);
  }

  /// Executes [edits] as one step labelled [label], the engine's
  /// permissions lifted (a host call is not gated, 2a P2); true with
  /// nothing to do.
  bool _runHostEdit(List<DraftCommand> edits, String label) {
    if (edits.isEmpty) return true;
    var applied = false;
    _unrestricted(
        () => applied = execute(CompoundCommand(edits, label: label)));
    _refreshFlags();
    return applied;
  }

  /// Makes [next] the label of the placed unit labelled [label] (spec S3):
  /// one "Label" step. An [ArgumentError] when [next] breaks the text rule
  /// (one to eight UTF-16 units, no control character, trimmed); false,
  /// changing nothing, when [label] names no unit or several, a generated
  /// unit (its type gives its label), a unit under a locked object, or when
  /// another unit already holds [next]. A [StateError] in service.
  bool setUnitLabel(String label, String next) =>
      setUnitsLabel({label: next});

  /// [setUnitLabel] for several units, all or nothing, one step: a [next]
  /// is free when no unit outside the call holds it and no other entry
  /// names it, so two units may swap their labels.
  bool setUnitsLabel(Map<String, String> byLabel) {
    _requireDesign('setUnitLabel');
    for (final next in byLabel.values) {
      if (unitLabelProblem(next) case final problem?) {
        throw ArgumentError.value(next, 'next', 'not a label: $problem');
      }
    }
    settlePendingInput();
    final index = _session.units.current;
    final doc = document;
    final keys = <String>{};
    final renamed = <Handle, String>{};
    for (final MapEntry(key: raw, value: next) in byLabel.entries) {
      if (!keys.add(raw.trim())) return false;
      final found = index.withLabel(raw);
      if (found.length != 1) return false;
      final u = found.single;
      if (u.generated || _session.locks.covers(doc, u.instance)) return false;
      renamed[u.instance] = next.trim();
    }
    final taken = <String>{};
    for (final MapEntry(key: h, value: next) in renamed.entries) {
      if (!taken.add(next)) return false;
      for (final other in index.withLabel(next)) {
        if (other.instance != h && !renamed.containsKey(other.instance)) {
          return false;
        }
      }
    }
    return _runHostEdit([
      for (final MapEntry(key: h, value: next) in renamed.entries)
        if (unitLabelCommand(doc, index[h]!, next) case final command?)
          command,
    ], 'Label');
  }

  // ---- unitChanges (today's designChanges, :1680-1776) ----

  late final StreamController<PlanUnitChange> _unitOut =
      StreamController<PlanUnitChange>.broadcast(
          onListen: _watchUnits, onCancel: _unwatchUnits);
  late final Stream<PlanUnitChange> _unitStream =
      _unitOut.stream.where((_) => !_disposed);
  _UnitBaseline? _unitBaseline;
  int _unitScans = 0;

  /// How many times the design's units were read for [unitChanges].
  @visibleForTesting
  int get debugUnitScans => _unitScans;

  /// The design's unit changes (spec S3), a broadcast stream: after every
  /// design edit, undo or redo, the units added, removed and changed since
  /// the last report, ascending by instance; matched by instance, so a
  /// relabel is one [PlanUnitChanged] and a row edit one change per seat it
  /// changed, an add or a remove per seat it grew or shrank. [load] and
  /// [newPlan] report what is still owed, then [PlanUnitsReplaced] alone.
  /// Nothing done in service is reported. Delivered asynchronously; nothing
  /// is sent on listen; nothing is read while no one listens; closed by
  /// [dispose].
  Stream<PlanUnitChange> get unitChanges => _unitStream;

  void _watchUnits() {
    if (_disposed) return;
    _unitBaseline = _unitsNow();
  }

  void _unwatchUnits() => _unitBaseline = null;

  /// The design's units now: the cached [unitDetails] while the design is
  /// active, else read from the design's own index.
  _UnitBaseline _unitsNow() {
    _unitScans++;
    final cache = _session.units;
    final index = cache.current;
    if (identical(cache, _activeUnits)) {
      return _UnitBaseline(index, unitDetailInstances, unitDetails);
    }
    final found = <Handle>[];
    final details = _detailsOf(_session.document, index, found);
    return _UnitBaseline(index, List.unmodifiable(found), details);
  }

  /// Reports what changed in the design since the baseline, and moves it.
  void _reportUnits() {
    final before = _unitBaseline;
    if (before == null || _disposed || before.isAt(_session.units.current)) {
      return;
    }
    final after = _unitBaseline = _unitsNow();
    for (final change in diffUnitDetails(
        before.instances, before.details, after.instances, after.details)) {
      _unitOut.add(change);
    }
  }

  /// A design change (its `commands.changes`): the flags, the revision
  /// while the design is active, the selected labels, the unit changes.
  void _onDesignChange() {
    _refreshFlags();
    if (_inDesign) _revision.value++;
    _refreshSelected();
    _reportUnits();
  }
```

  4. In `_open` (`:589-653`), the history line becomes `session.history = document.commands.changes.listen((_) { if (!_disposed) _onDesignChange(); });` and, after it, `session.selection.addListener(_refreshSelected);`. In `_replace` (`:674-698`): before `old.disposeKitProducts();`, add `_reportUnits();` and `old.selection.removeListener(_refreshSelected);`; after `_tracker.replaced();`, add:

```dart
    if (_unitBaseline != null) {
      _unitOut.add(const PlanUnitsReplaced());
      _unitBaseline = _unitsNow();
    }
    _atPicker = null;
    _refreshSelected();
    _revision.value++;
```

     In `dispose` (`:1300-1338`): `session.selection.removeListener(_refreshSelected);` before the session is detached; `_revision.dispose(); _selectedUnits.dispose(); _editorSelected.dispose();` beside the other notifiers; `unawaited(_unitOut.close());` beside `_out.close()`.
  5. In `lib/jet_cad_2d_plan.dart` add `export 'src/controller/plan_camera.dart' show PlanCamera;` and `export 'src/units/unit_detail.dart' show PlanUnit, PlanUnitAdded, PlanUnitChange, PlanUnitChanged, PlanUnitDetail, PlanUnitRemoved, PlanUnitsReplaced;` (sorted with the others). Task 6 exports nothing from the barrel (its Produces: "Task 9 exports the host-facing ones"), so add `export 'src/units/unit_label.dart' show UnitLabelProblem;` and `export 'src/units/unit_problems.dart' show BadLabel, DuplicateLabel, Unlabelled, UnitLabelWarning;` (the types `labelWarnings` and the panel's errors hand a host). In `test/barrel_test.dart`, ED-9's set gains `// 2b Task 9` / `'BadLabel', 'DuplicateLabel', 'PlanCamera', 'PlanUnit', 'PlanUnitAdded', 'PlanUnitChange', 'PlanUnitChanged', 'PlanUnitDetail', 'PlanUnitRemoved', 'PlanUnitsReplaced', 'Unlabelled', 'UnitLabelProblem', 'UnitLabelWarning',`.

- [ ] **Step 9: Run the tests, see them pass.** Run: `cd packages/jet_cad_2d_plan && flutter test test/units/ test/controller/unit_detail_test.dart test/controller/unit_data_test.dart test/controller/unit_colour_test.dart test/controller/unit_changes_test.dart test/controller/unit_camera_test.dart test/controller/non_finite_unit_test.dart test/editor/units_only_select_test.dart test/l10n/value_words_test.dart test/barrel_test.dart`. Expected: `All tests passed!`. Then the whole package: `flutter test`, `All tests passed!` (2a's `plan_change_test` keeps passing: `changes` is untouched).

- [ ] **Step 10: Format and the gate.** `cd packages/jet_cad_2d_plan && dart format . && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` — `All tests passed!`, `No issues found!`, exit 0. From the root, `git status --short`: only this task's files.

- [ ] **Step 11: Commit.**

```bash
git add packages/jet_cad_2d_plan/lib/src/units/unit_detail.dart packages/jet_cad_2d_plan/lib/src/controller/plan_camera.dart packages/jet_cad_2d_plan/lib/src/units/unit_fit.dart packages/jet_cad_2d_plan/lib/src/units/unit_writes.dart packages/jet_cad_2d_plan/lib/src/controller/plan_controller.dart packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart packages/jet_cad_2d_plan/test/barrel_test.dart packages/jet_cad_2d_plan/test/support/unit_embedding_fixture.dart packages/jet_cad_2d_plan/test/units/unit_api_test.dart packages/jet_cad_2d_plan/test/units/unit_fit_test.dart packages/jet_cad_2d_plan/test/controller/unit_detail_test.dart packages/jet_cad_2d_plan/test/controller/unit_data_test.dart packages/jet_cad_2d_plan/test/controller/unit_colour_test.dart packages/jet_cad_2d_plan/test/controller/unit_changes_test.dart packages/jet_cad_2d_plan/test/controller/unit_camera_test.dart packages/jet_cad_2d_plan/test/controller/non_finite_unit_test.dart packages/jet_cad_2d_plan/test/editor/units_only_select_test.dart packages/jet_cad_2d_plan/test/l10n/value_words_test.dart
git commit -m "$(cat <<'EOF'
feat(plan): the unit API, design side (2b S3)

PlanController lists the design's units, placed and generated, and
their details (geometry, layer, lock, host data, colour), finds a unit
at a canvas point, selects and frames units by label, and writes data,
colours and labels in one undoable step each; a unit under a locked
object answers false, a seat's label is its row's. unitChanges reports
a row edit seat by seat, matched by instance. PlanCamera, revision,
worldToGlobal and globalToWorld follow today's host API.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 12: Mutation check** (committed files only; after each: run the named test with `cd packages/jet_cad_2d_plan && flutter test test/units/unit_api_test.dart`, see it red, quote the red line, then `git checkout -- <file>` and `git diff --quiet -- <file>` must exit 0):
  - M-UA0 `lib/src/controller/plan_controller.dart`: in `_unitOf`, `generatedBy: u.ownerType` → `generatedBy: null` → UA-units red.
  - M-UA1 same file: in `_detailsOf`, `d.components.get<UnitData>(u.instance)` → `d.components.get<UnitData>(u.definition)` → UA-shrink-data red.
  - M-UA1x (cross-check, Task 1's committed `packages/jet_cad_2d/lib/src/parametric/regeneration.dart`): Task 1's M-E5-match, in `_planInstances` `final existing = s.instances[object] ?? const <InstanceNode>[];` → `final existing = const <InstanceNode>[];` (no output matched, so each regeneration removes and re-adds) → UA-shrink-data red (handles change).
  - M-UA2 (cross-check, Task 2's committed `regeneration.dart`): in `_refused`'s node branch, `: now != seat) return h;` → `: true) return h;` (every touched generated instance refused, a components-only write included) → UA-seat-data red.
  - M-UA3 `plan_controller.dart`: in `_setUnitComponents`, delete `if (_session.locks.covers(doc, instance)) return false;` → UA-locked-write red (the lock hint shows).
  - M-UA4 same file: in `setUnitsLabel`, delete the inner `for (final other in index.withLabel(next)) { … }` loop → UA-label-used red.
  - M-UA5 same file: `if (u.generated || _session.locks.covers(doc, u.instance)) return false;` → `if (_session.locks.covers(doc, u.instance)) return false;` → UA-label-seat red.
  - M-UA6 same file: `if (other.instance != h && !renamed.containsKey(other.instance))` → `if (other.instance != h)` → UA-labels-swap red.
  - M-UA7 same file: delete `if (placedOnly && u.generated) continue;` → UA-select-design red.
  - M-UA8 same file: in `_unitsBounds`, add `if (c.unit.generated) continue;` as the loop's first line → UA-fit-seat red.
  - M-UA9 `lib/src/units/unit_detail.dart`: in `diffUnitDetails`, compare `before[i].unit.label` with `after[j].unit.label` for the match (replace the instance comparison `a < b` / `b < a` by a label comparison: `final a = i < before.length ? before[i].unit.label : null;` and the same for `b`, with `compareTo`) → UA-changes-row red.

#### Assumed from earlier tasks

Each name below is used as written; where the earlier task named it otherwise, use that task's name and report the difference.
- Task 6 (`lib/src/units/`): `unit_index.dart` (as in Task 8's list, plus `UnitInfo.ownerType`, `label`, `kind`, `capacity`, `symbolKey`, `UnitIndex.warnings()`); `unit_components.dart` with `UnitData(Map<String, String>)` (`data`: keys ascending, unmodifiable; empty for kept data), `String? unitDataProblem(Map<String, String>)`, `UnitColour(PlanSwatch)` (`swatch`: null when kept or unknown); `unit_label.dart` with `UnitLabelProblem? unitLabelProblem(String raw)` (trims first); `unit_problems.dart` with the `UnitLabelWarning` types (`DuplicateLabel(label:, count:)`, `Unlabelled(kind:, capacity:, symbolKey:)`, `BadLabel(label:, problem:)`, `const` constructors, `==` by value). The design session's cache is `DocumentSession.units`, and `DocumentSession.locks` is 2a's `LockSet`.
- Task 5: the row component is `RowComponent` (in `test/support/test_kit.dart`) with `count`, `prefix` and `copyWith` (its named parameters include `count` and `prefix`); `unitKit()` carries the row type (`testKit()` alone does not); `serviceFixture().json` (`test/support/service_fixture.dart`) holds a turned, mirrored table labelled `12` (the one placed unit) and two rows: `A` (six seats, turned 0.35 rad) and `B` (five seats, curved).
- Task 8: `UnitPicker` with `document` and `units` fields (the identity check in `unitAt`), and the test support files.
- Task 7: placing and turning a placed unit re-stamps its label in the same step (`UnitLabelSystem`), so a relabel or a turn needs nothing more here.

#### Findings for the controller (rulings before dispatch)

Resolved by R-13 (F-T9a: "Unit data"/"Unit colour"; F-T9b: `toString` texts gain the kind token; F-T9c: DC8/9/11/12/13/17 ported a second time for `unitChanges`). Each is an execution ruling in the ledger.

---

