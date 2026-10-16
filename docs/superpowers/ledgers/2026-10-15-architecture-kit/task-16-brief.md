### Task 16: Room tracing, inputs and label; the separator's parameters (spec C3.4, C3.5, C1.5, C2 "Shared caches", C7)

Room tracing reads walls and separators by place, and the separator's tool and grips (Task 17) read `RoomInputs`, so the separator's parameters and type land here with the tracer. Nothing here is a `PlanType` or a `PlanTool`: `architectureKit` does not change in this task.

**Files:**
- Create (`packages/jet_cad_2d_kit_architecture/`):
  - `lib/src/separator/separator.dart` (ported: `SeparatorParams`, `SeparatorType`)
  - `lib/src/room/room_trace.dart` (ported, unchanged)
  - `lib/src/room/room_inputs.dart` (ported: `RoomInput`, `roomTrace`, the view adapter, `RoomInputs` over a `LiveTypeOf`, `trimSeparator`; new: `roomInputsOf`)
  - `lib/src/room/room_label.dart` (ported, unchanged: `poleOfInaccessibility`, `formatArea`)
  - `test/support/room_fixture.dart` (ported from `jet_cad_floor_plan/test/support/room_fixture.dart`, less its three `RoomParams` helpers, which Task 18 adds)
  - `test/separator/separator_test.dart` (ported: SR1, SR2, SR4, SR5)
  - `test/room/room_trace_test.dart`, `test/room/room_inputs_test.dart`, `test/room/room_label_test.dart`, `test/room/room_localise_test.dart` (ported whole)
  - `test/room/room_tie_test.dart` (ported: its helpers and DE1; Task 18 adds DE2 and DE3)
  - `test/room/room_inputs_services_test.dart` (new: RR-live, RR-shared)
- Modify (`packages/jet_cad_2d_kit_architecture/`):
  - `lib/jet_cad_2d_kit_architecture.dart` (export `SeparatorParams`)
  - `test/support/catalog.dart` (Task 10's; R-P13: the separator's line in `_testCatalog`'s cascade)
  - `lib/src/wall/wall.dart` (`WallType`'s three place hooks, which Task 11 left out by ruling R-P8; Step 2)
  - `lib/src/type_naming.dart` (Task 14's, ruling R-P19: the separator's registration after the opening's)

**Interfaces:**
- Consumes:
  - Task 9: `ArchitectureTypes` (`lib/src/ids.dart`), `typedef LiveTypeOf = String? Function(Handle handle)` and `LiveTypeOf liveTypesOf(PlanServices services)` (`lib/src/live.dart`), `ensureDashedLinetype(DraftDocument doc)` and `kDashedLinetypeRecord` (`lib/src/separator_linetype.dart`), the barrel `lib/jet_cad_2d_kit_architecture.dart`.
  - Task 11: `WallParams`, `Justification`, `WallType` (`lib/src/wall/wall.dart`), `WorldWall`, `localOutlineOf` (`lib/src/wall/wall_geometry.dart`); the kit's test support `test/support/wall_fixture.dart` with today's names (`enc`, `kids`, `kindOf`, `payloadOf`, `driftOf`, `diagnosticsOf`, `canon`, `reload`, `addWall`, `addWallLocal`, `far`, `polar`, `wallDoc`, `worldWallOf`) and, by ruling R-P6, `ParametricCatalog testCatalog()` and `ParametricSystem installParametric(DraftDocument doc)` (the kit's raw types in today's order, each type task appending its line).
  - Task 11: `wallsInView` (`lib/src/wall/wall_geometry.dart`, R-P8). Task 13: `OpeningParams`, `OpeningKind`, `SwingSide`, `OpeningType` (`lib/src/opening/opening.dart`), and their registration in `testCatalog()`.
  - Task 6: `PlanServices.liveTypeIdOf`; `package:jet_cad_2d_kit/testing.dart`'s `FakePlanServices` (`document`, `catalog`, `frozen`; `liveTypeIdOf` = `catalog?.typeIdOf(document, h)` unless `h` is in `frozen`; `shared` one per `T`, a `Disposable` disposed by `dispose()`).
  - Contract today: `PlanServices.shared`, `Disposable` (`jet_cad_2d_kit/lib/src/kit/plan_services.dart:50-52, :114`).
  - Engine: `ParametricCatalog.typeIdOf` (`jet_cad_2d/lib/src/parametric/parametric_system.dart:674`), `ComponentRegistry.withComponent` (ascending), `ReservedHandles.dashedLinetype`.
- Produces (Shared interfaces, exact):

```dart
// lib/src/room/room_inputs.dart
RoomInputs roomInputsOf(PlanServices s);   // s.shared(...): one per kit and document
// Today's names, kept (spec 3a "Shared interfaces": only ids and the
// global-catalog reads change):
const Tolerance roomTrace;                  // unchanged
final class RoomInput { ... }               // unchanged
RoomInput? roomInputOf(Handle h, Component params, Transform2 toWorld,
    {List<WorldWall> walls = const []});    // unchanged
RoomInput? roomInputInView(ParametricView view, Handle h);   // unchanged
Aabb2? placeBoxInView(ParametricView view, Handle h);        // unchanged
PlaceSource placeSourceInView(ParametricView view);          // unchanged
final class RoomInputs implements PlaceSource, Disposable {
  RoomInputs(this.document, this.live);     // NEW second parameter
  final DraftDocument document;
  final LiveTypeOf live;                    // NEW: the plan's live rule
  int get generation; void invalidate(); RoomInput? inputOf(Handle h);
  Aabb2? placeBoxOf(Handle h); List<Handle> wallNeighboursOf(Handle h);
  List<Handle> placedIn(Aabb2 box); Aabb2? get bounds; int debugRebuilds;
  void dispose();
}
(Vector2, Vector2)? trimSeparator(Vector2 a, Vector2 b, RoomInputs inputs,
    {required bool objectSnap});            // unchanged
// lib/src/room/room_trace.dart, lib/src/room/room_label.dart: unchanged
// (TraceResult, SeedInWall, Unbounded, Traced, traceRoom, PlaceSource,
// traceRoomAmong, outerContours, Tint, tintOf, distToSegment, pointInRing,
// pointInRingXY, shoelace, debugTracedSegments, kGrowthStart,
// kCertificateMargin, kSlit; poleOfInaccessibility, formatArea).
// lib/src/separator/separator.dart
final class SeparatorParams implements Component {   // exported by the barrel
  static const String componentTypeId = ArchitectureTypes.separator;  // was 'floor_planner.separator'
  /* the rest unchanged */
}
final class SeparatorType extends ParametricType<SeparatorParams> { /* unchanged */ }
```

  Test support produced for Tasks 17, 18, 19 (`test/support/room_fixture.dart`): today's `W`, `S`, `O`, `Placement`, `origin`, `corpus`, `corpusGroups`, `km1000`, `km1000Axis`, `km1000Groups`, `placements`, `Plan`, `buildPlan`, `addSeparator`, `addOpening`, `recordOf`, `worldPoints`, `ViewInputs`, `everywhere`, `probeView`, `sameBox`, the plans (`sampleWalls`, `sampleOpenings`, `sampleSeparator`, `sampleColumn`, `sampleSeeds`, `samplePlan`, `lWalls`, `lOpenings`, `fourThickWalls`, `jmWalls`, `twoRoomWalls`, `boxWalls`, `hollowColumnWalls`, `boxSeparator`, `boxAndSeparatorPlan`, `trWalls`, `trSeed`, `fbWalls`, `fbW`, `fbX`, `fbSeed`, `fbXEditEnd`, `thinLWalls`), `attachPage`, `labelsOf`, `textOf`, `worldTintOf`, `pageOf`, `anchorOf`, `moveWall`, `reloadWithPage`, `deleteObject`, `staleFile`, `labelStrings`, `kindsOf`, `faceAt`, `codedAs`, `expectSameTrace`, the re-exports of `wall_fixture.dart` (`kids`, `kindOf`, `payloadOf`, `driftOf`, `diagnosticsOf`, `canon`, `reload`, `enc`), and `liveOf` (Task 11's, re-exported; R-P17).

**Appendix A rows closed:**
- D-19, in part: `separator_test` (SR1, SR2, SR4, SR5: 4 of 4; SR3 is a shell case of `room_paint_test`, see Task 18), `room_trace_test` (8 of 8), `room_inputs_test` (3 of 3), `room_label_test` (4 of 4), `room_localise_test` (3 of 3), `room_tie_test` DE1 (DE2, DE3: Task 18). `room_cost_test` is ported in Task 18 (RK1 and RK2 add rooms) and its LZ3 runs on today's `startupPlan` (see "Interface problem" 3).
- D-48's tenth item ("the room inputs", `parametric/room_inputs.dart:96-148, :296-314`): kit-internal now; RR-live is its proof (Task 26 lists it).
- D-40: no `isLocked`, `allows` or settings listenable is used here (spec C1.5).

**Placement (spec C7).** Every ported case of this task uses only the kit's, the contract's (`FakePlanServices`), the engine's and the Flutter layer's names: all go to the kit. No case of these files pumps `PlannerShell`, `SelectionPanel` or `PlannerView`. None of these files has a twin under `packages/jet_cad_2d_plan/test/` or `packages/jet_cad_2d_kit/test/` (checked: `grep -rln "RoomInput\|traceRoom\|SeparatorParams" packages/jet_cad_2d_plan/test packages/jet_cad_2d_kit/test` finds nothing).

**Plan decisions:**
- **The live rule.** Today's `isLiveObject<T>`/`liveObjectsOf<T>` (`jet_cad_floor_plan/lib/src/parametric/live_objects.dart:21-29`) ask the **global** `parametricCatalog`. The kit's `RoomInputs` asks the `LiveTypeOf` it is given: in the plan, `liveTypesOf(services)` (the plan's `liveTypeIdOf`, null for a frozen object, spec C1.5); in the kit's own tests, `liveOf(doc)` (the fixture catalog's `typeIdOf`, which follows the same naming rule as today's `names<T>`, `parametric_system.dart:638-675`). Today's `liveObjectsOf<T>(doc)` becomes "the holders of a `T`, ascending (`withComponent<T>()`), whose live type id is `T`'s": the same handles in the same order for any document without a frozen object.
- **Invalidation is today's** (spec C2): `RoomInputs` keeps its `changes` subscription and its explicit `invalidate()`; `roomInputsOf` only moves the owner from the shell (`planner_shell.dart:473`) to `PlanServices.shared`, which disposes it with its document.
- **Purity.** Today's `room_inputs.dart`, `room_trace.dart` and `room_label.dart` are Flutter-free (spec 10 D1). `room_trace.dart` and `room_label.dart` stay so; `room_inputs.dart` now imports the contract's barrel for `PlanServices` and `Disposable` (the Shared interfaces put `roomInputsOf` in this file); its header says so.
- **`room_tie_test` splits by case**, not by placement: DE1 traces only; DE2 and DE3 add rooms (`addRoom`, `RoomParams`, Task 18). The file lands here with DE1 and its helpers; Task 18 adds its `room_label.dart` import (used by DE2 alone; `unused_import` is an error in this workspace) and the two cases.

- [ ] **Step 1: Precondition.** Tasks 9-15 are committed (Task 14 created `lib/src/type_naming.dart`). Run, one by one, from the repository root:
  - `cd packages/jet_cad_2d_kit_architecture && flutter analyze` — expected `No issues found!`.
  - `grep -n "placeBoxInView\|roomInputInView\|contributesPlace" packages/jet_cad_2d_kit_architecture/lib/src/wall/wall.dart` — note the result for Step 2.
  - `ls packages/jet_cad_2d_kit_architecture/lib/src/room/` — note whether an earlier task created `room_inputs.dart`.
  - `grep -n "register<" packages/jet_cad_2d_kit_architecture/test/support/catalog.dart` — expected: `_testCatalog`'s box, wall and opening registrations (Tasks 10, 11, 13; R-P13).

- [ ] **Step 2: The wall's place hooks** (ruling R-P8: Task 11 deleted them, so Step 1's first grep finds none; any other result is a finding: stop and report it). Today's `WallType` contributes places (`jet_cad_floor_plan/lib/src/parametric/wall.dart:172-189`). Add them back after `WallType.reach` in `lib/src/wall/wall.dart`, with `import '../room/room_inputs.dart' show placeBoxInView, roomInputInView;`:

```dart
  /// A wall is an input to rooms (spec 10 D4, D16): its uncut band.
  @override
  bool get contributesPlace => true;

  /// The world box of [self]'s uncut band ([roomInputInView]), or null for
  /// a degenerate wall or a band with a non-finite coordinate.
  @override
  Aabb2? placeBox(ParametricView view, Handle self) =>
      placeBoxInView(view, self);

  /// [self]'s uncut band in world, a [RoomInput]: its joined ring after 07's
  /// joints, the short-wall fallback and the local-ring fallback, never its
  /// parameters, so equal inputs mean an equal band (the engine's contract).
  /// The engine asks only when [placeBox] is not null; a fresh `Object()`
  /// otherwise counts as changed, which can only regenerate more.
  @override
  Object placeInput(ParametricView view, Handle self) =>
      roomInputInView(view, self) ?? Object();
```

  If an earlier task created `lib/src/room/room_inputs.dart` as a stand-in, Step 6 replaces it whole.

- [ ] **Step 3: The test support.**
  1. `test/support/catalog.dart` (R-P13): in `_testCatalog`'s cascade, add the separator's registration after the opening's, in today's order (`jet_cad_floor_plan/lib/src/parametric/catalog.dart:27-39`), and its import:

```dart
import 'package:jet_cad_2d_kit_architecture/src/separator/separator.dart';
```

```dart
  ..register<SeparatorParams>(SeparatorParams.componentTypeId,
      SeparatorParams.fromJson, const SeparatorType())
```

  2. Create `test/support/room_fixture.dart`: **copy `packages/jet_cad_floor_plan/test/support/room_fixture.dart` lines 1-758**, with these adaptations only:
     - Lines 1-6, the header: append a paragraph:

```dart
// Ported from jet_cad_floor_plan/test/support/room_fixture.dart (spec 3a
// C7): the floor planner's catalog becomes the kit's test catalog
// (wall_fixture.dart's testCatalog), and a RoomInputs reads the live rule
// [liveOf] gives (wall_fixture.dart's, R-P17). The room helpers that need RoomParams (addRoom,
// addSampleRooms, renameRoom) arrive with the room (Task 18).
```

     - Lines 10-16, the imports, become (lines 21-24, the `wall_fixture.dart` import and export, are adapted next):

```dart
import 'package:jet_cad_2d_kit_architecture/src/opening/opening.dart';
import 'package:jet_cad_2d_kit_architecture/src/room/room_inputs.dart';
import 'package:jet_cad_2d_kit_architecture/src/room/room_trace.dart';
import 'package:jet_cad_2d_kit_architecture/src/separator/separator.dart';
import 'package:jet_cad_2d_kit_architecture/src/separator_linetype.dart';
import 'package:jet_cad_2d_kit_architecture/src/wall/wall.dart';
```

       Line 21's `import 'wall_fixture.dart' show enc, kids, kindOf, payloadOf;` gains `installParametric, liveOf, testCatalog`, and line 23-24's `export 'wall_fixture.dart' show ...` gains `installParametric, liveOf, testCatalog` (so every room test reaches the catalog through this file, as today's reached `catalog.dart`).
     - Lines 125 (`buildPlan`) and 653 (`reloadWithPage`): `installParametric(doc)` unchanged (R-P6: the kit's `installParametric`).
     - Lines 561-579 (`addRoom`), 669-677 (`addSampleRooms`) and 694-697 (`renameRoom`): **not copied** (Task 18).
     - Lines 645-655 (`reloadWithPage`) and 684-692 (`staleFile`): `parametricCatalog.registerComponents(r);` → `testCatalog().registerComponents(r);`.
     - Line 709 (`faceAt`): `final inputs = RoomInputs(doc);` → `final inputs = RoomInputs(doc, liveOf(doc));`.
     - No live reader of its own: `liveOf` (Task 11's `wall_fixture.dart`, R-P17: the test catalog's `typeIdOf`, null for a frozen handle) is imported and re-exported above.

     Every other line is unchanged (`probeView`'s catalog, lines 312-320, registers the types under their `componentTypeId`, now `architecture.*`).

- [ ] **Step 4: The failing tests (ported).** Create each file by copying its source from `packages/jet_cad_floor_plan/test/` with the adaptations listed; **assertions unchanged** in every case. Every file's `import 'package:jet_cad_floor_plan/src/parametric/<f>.dart';` becomes `import 'package:jet_cad_2d_kit_architecture/src/<dir>/<f>.dart';` (`separator` → `separator/`, `room_*` → `room/`, `wall*` → `wall/`), and `import 'support/<f>.dart'` becomes `import '../support/<f>.dart'`. Each file gains, after its header, the line `// Ported from jet_cad_floor_plan/test/<file>; assertions unchanged.` (with the C7 class named where one applies).

  | Source → destination | Cases | Further adaptations (line numbers of the source) |
  |---|---|---|
  | `separator_test.dart` → `test/separator/separator_test.dart` | SR1, SR2, SR4, SR5 | Line 5 (`catalog.dart`) is dropped: `installParametric` (R-P6) comes through `room_fixture.dart`'s export. Lines 6-8 follow the rule above (`room/room_inputs.dart`, `separator/separator.dart`, `wall/wall.dart`); add `import 'package:jet_cad_2d_kit_architecture/src/separator_linetype.dart';` (SR2, SR5 call `ensureDashedLinetype`). :38 `'floor_planner.separator'` → `'architecture.separator'` (C7 class 1, ids). :66 and :197 `installParametric(` unchanged (R-P6). :146 `RoomInputs(plan.doc)` → `RoomInputs(plan.doc, liveOf(plan.doc))`. |
  | `room_trace_test.dart` → `test/room/room_trace_test.dart` | RT1, RT2, RT3, RT4, RT6, RT7, RT8, RT9 | :19 `RoomInputs(plan.doc)` → `RoomInputs(plan.doc, liveOf(plan.doc))`. |
  | `room_inputs_test.dart` → `test/room/room_inputs_test.dart` | RI1, RI2, RT5 | :9 `import 'package:jet_cad_floor_plan/src/parametric/separator.dart';` → `import 'package:jet_cad_2d_kit_architecture/src/separator_linetype.dart';` (the file's one use of it is `ensureDashedLinetype` at :142, which lives in `separator_linetype.dart` since Task 9; the kit's `separator.dart` would be an unused import, an error). :17-18 `import 'support/wall_fixture.dart' show ...` → `import '../support/wall_fixture.dart' show ...` (the same names, Task 11's port). :25, :212, :340 `RoomInputs(doc)` → `RoomInputs(doc, liveOf(doc))`; :118 `RoomInputs(columnLast.doc)` → `RoomInputs(columnLast.doc, liveOf(columnLast.doc))`; :226, :256 `RoomInputs(plan.doc)` → `RoomInputs(plan.doc, liveOf(plan.doc))`. |
  | `room_label_test.dart` → `test/room/room_label_test.dart` | RL1, RL2, RA1, Q0-RA1 | :38 `RoomInputs(plan.doc)` → `RoomInputs(plan.doc, liveOf(plan.doc))`. |
  | `room_localise_test.dart` → `test/room/room_localise_test.dart` | LZ1, LZ2, LZ4 | :329, :390, :446, :476 `RoomInputs(plan.doc)` → `RoomInputs(plan.doc, liveOf(plan.doc))`. The isolate (`traceWithin`, :293-316) sends `List<RoomInput>` only, unchanged. |
  | `room_tie_test.dart` → `test/room/room_tie_test.dart` | DE1 | Copy lines 1-14, 16-435 (line 15, `room_label.dart`, is DE2's alone), then a closing `}` for `main`. :67 `RoomInputs(plan.doc)` → `RoomInputs(plan.doc, liveOf(plan.doc))`. |

  Non-ASCII literals (`'m²'`, `'ft²'`, `'—'`) are copied byte for byte: check with `grep -n "m²\|ft²" packages/jet_cad_2d_kit_architecture/test/room/room_label_test.dart` against the source.

- [ ] **Step 5: The failing tests (new).** Create `test/room/room_inputs_services_test.dart`:

```dart
// Spec 3a C1.5, C2: the room inputs as the kit's code sees them in a plan.
// roomInputsOf(services) is the kit's one RoomInputs per document
// (PlanServices.shared, disposed with it), and its live rule is the plan's
// liveTypeIdOf: a frozen wall or separator is no input, exactly as it is in
// no survey (E2), while the catalog still answers its type id.
//
// The plan is the two-room box (a 100 mm partition at x 3,000) with a
// separator face to face at x 6,250.5, at the corpus far origin turned 23°,
// every wall and the separator in its own rotated, translated group.
// Expected areas are hand arithmetic: inner faces 100 in.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_kit/testing.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart'
    show ArchitectureTypes;
import 'package:jet_cad_2d_kit_architecture/src/room/room_inputs.dart';
import 'package:jet_cad_2d_kit_architecture/src/room/room_trace.dart';

import '../support/room_fixture.dart';

/// The plan of both cases.
Plan fixture() => buildPlan(twoRoomWalls,
    seps: const [(6250.5, 100, 6250.5, 3900)], place: corpusGroups);

void main() {
  test(
      'RR-live a frozen wall and a frozen separator are no input to rooms; '
      'the catalog still names them (M-RR-1, M-RR-2)', () {
    final plan = fixture();
    final doc = plan.doc;
    final partition = plan.walls[4], sep = plan.seps.single;
    final frozen = FakePlanServices(
        document: doc, catalog: testCatalog(), frozen: {partition, sep});
    addTearDown(frozen.dispose);
    // Premises: the catalog names both; the plan's live rule names neither.
    expect(testCatalog().typeIdOf(doc, partition),
        ArchitectureTypes.wall);
    expect(testCatalog().typeIdOf(doc, sep), ArchitectureTypes.separator);
    expect(frozen.liveTypeIdOf(partition), isNull);
    expect(frozen.liveTypeIdOf(sep), isNull);

    final inputs = roomInputsOf(frozen);
    expect(inputs.inputOf(partition), isNull);
    expect(inputs.inputOf(sep), isNull);
    expect(inputs.placedIn(everywhere), plan.walls.take(4).toList(),
        reason: 'the four outer walls only, ascending');
    expect(inputs.wallNeighboursOf(plan.walls[0]), isNot(contains(partition)));
    // Traced among them, the seed's face is the whole box:
    // 7,800 × 3,800 = 29,640,000.
    final whole = traceRoomAmong(plan.at(1500.25, 2000.5), inputs);
    expect(whole, isA<Traced>());
    expect((whole as Traced).area, closeTo(29640000, 1e-2));

    // The control: nothing frozen. The partition and the separator are
    // inputs; the left face is 2,850 × 3,800 = 10,830,000.
    final live =
        FakePlanServices(document: doc, catalog: testCatalog());
    addTearDown(live.dispose);
    final all = roomInputsOf(live);
    expect(all.inputOf(partition), isNotNull);
    expect(all.inputOf(sep), isNotNull);
    expect(all.placedIn(everywhere), [...plan.walls, sep]);
    final left = traceRoomAmong(plan.at(1500.25, 2000.5), all) as Traced;
    expect(left.area, closeTo(10830000, 1e-2));
  });

  test(
      'RR-shared one RoomInputs per services; it follows the document\'s '
      'changes and is released with its services (M-RR-3, M-RR-4)',
      () async {
    final plan = fixture();
    final doc = plan.doc;
    final s = FakePlanServices(document: doc, catalog: testCatalog());
    final inputs = roomInputsOf(s);
    expect(roomInputsOf(s), same(inputs), reason: 'one per document');
    expect(inputs.live(plan.walls[4]), ArchitectureTypes.wall,
        reason: 'the services\' live rule');

    // A change stales it once delivered (today's `changes` subscription).
    final g0 = inputs.generation;
    doc.commands.execute(
        moveWall(plan, 4, const W(3300.5, 0, 3300.5, 4000, 100)));
    await Future<void>.delayed(Duration.zero);
    expect(inputs.generation, greaterThan(g0), reason: 'invalidated');

    // Released with its services: no subscription is left.
    s.dispose();
    final g1 = inputs.generation;
    doc.commands
        .execute(moveWall(plan, 4, const W(3000, 0, 3000, 4000, 100)));
    await Future<void>.delayed(Duration.zero);
    expect(inputs.generation, g1, reason: 'disposed with its services');
  });
}
```

- [ ] **Step 6: Run the kit's tests, expecting failure.** `cd packages/jet_cad_2d_kit_architecture && flutter test test/separator test/room`. Expected: compile errors, `Target of URI doesn't exist` for `src/separator/separator.dart`, `src/room/room_inputs.dart`, `src/room/room_trace.dart`, `src/room/room_label.dart` (and `Undefined name 'roomInputsOf'`). Quote them.

- [ ] **Step 7: The separator.** Create `lib/src/separator/separator.dart`: **copy `packages/jet_cad_floor_plan/lib/src/parametric/separator.dart` lines 1-120 unchanged**, with these adaptations; lines 121-149 (`kDashedLinetypeRecord`, `ensureDashedLinetype`) are **not copied**: they live in `lib/src/separator_linetype.dart` (Task 9).
  - Line 4 `import 'room_inputs.dart';` → the two lines:

```dart
import '../ids.dart';
import '../room/room_inputs.dart';
```

  - Line 17: `static const String componentTypeId = 'floor_planner.separator';` → `static const String componentTypeId = ArchitectureTypes.separator;`.
  - Insert before line 6's doc comment, as the file's header:

```dart
// The room separator (spec 3a C3.4): ported from jet_cad_floor_plan's
// parametric/separator.dart, its id architecture.separator. Its DASHED
// record and ensureDashedLinetype are the kit's prepare
// (separator_linetype.dart, spec 3a C1.3).
```

  In `lib/src/type_naming.dart` (Task 14, ruling R-P19), append the separator's registration to `_naming`'s cascade after the opening's (today's order, `catalog.dart:34-35`), with `import 'separator/separator.dart';`:

```dart
  ..register<SeparatorParams>(SeparatorParams.componentTypeId,
      SeparatorParams.fromJson, const SeparatorType())
```

  Then the barrel `lib/jet_cad_2d_kit_architecture.dart` gains `export 'src/separator/separator.dart' show SeparatorParams;` (kept in the export list's alphabetical place; the Shared interfaces' "exports exactly" list includes `SeparatorParams`).

- [ ] **Step 8: The tracer and the label.** Create `lib/src/room/room_trace.dart`: **copy `packages/jet_cad_floor_plan/lib/src/parametric/room_trace.dart` lines 1-1111 unchanged** (its one relative import, `room_inputs.dart`, resolves in the same directory). Create `lib/src/room/room_label.dart`: **copy `.../parametric/room_label.dart` lines 1-179 unchanged**. Each gains one header line after its first comment block: `// Ported from jet_cad_floor_plan's parametric/<file> unchanged (spec 3a C3.5).`

- [ ] **Step 9: The inputs.** Create `lib/src/room/room_inputs.dart`: **copy `packages/jet_cad_floor_plan/lib/src/parametric/room_inputs.dart` lines 1-483**, with these adaptations (every other line unchanged):
  - Lines 5-6 of the header (`No Flutter import: ...`) become:

```dart
// separator (D20). Ported from jet_cad_floor_plan's parametric/
// room_inputs.dart (spec 3a C3.5): a live wall or separator is one the
// plan's liveTypeIdOf names (a LiveTypeOf, spec 3a C1.5), so a frozen one
// is no input, as it is in no survey; and the document adapter is the
// kit's PlanServices.shared object (roomInputsOf, spec 3a C2), not a shell
// field. The tracer's own files (room_trace.dart, room_label.dart) stay
// Flutter-free; this one imports the contract for PlanServices.
```

  - Lines 9-17, the imports, become:

```dart
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart'
    show Disposable, PlanServices;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../ids.dart';
import '../live.dart';
import '../separator/separator.dart';
import '../wall/wall.dart';
import '../wall/wall_geometry.dart';
import 'room_trace.dart' show PlaceSource, distToSegment, pointInRing;
```

  - Lines 199-221 (the class doc, the declaration, the constructor and its first field) become:

```dart
/// The trace inputs of a whole document, for the Room and Separator tools
/// and the separator grips (spec 10 D4, D19-D21; Ruling 10-11): the
/// **document adapter**. The kit keeps one per document, [roomInputsOf]
/// (spec 3a C2: a `PlanServices.shared` object, disposed with its
/// document), and hands it to all three.
///
/// It holds every **live** wall and separator ([live]: in a plan, its
/// `liveTypeIdOf`, so a frozen one is left out as every survey leaves it
/// out, spec 3a C1.5), each wall's wall neighbours by the engine's own
/// predicate over `WallType().reach`, each input and place box, and
/// [bounds]. The inputs are those the view adapter gives, bit for bit
/// (`RI1`).
///
/// Marked stale on each of the document's changes (its `changes` stream,
/// which delivers after the task that made the change) and on [invalidate],
/// and rebuilt at the next query.
///
/// It is the tools' [PlaceSource] (spec 10 D7, D19): `traceRoomAmong(seed,
/// roomInputs)` traces what a room there would.
final class RoomInputs implements PlaceSource, Disposable {
  RoomInputs(this.document, this.live) {
    _changes = document.changes.listen((_) => invalidate());
  }

  final DraftDocument document;

  /// The type id of the live object [Handle] names, or null: the plan's
  /// `liveTypeIdOf` (spec 3a C1.5).
  final LiveTypeOf live;
```

    (today's lines 222-223, `StreamSubscription<DocChange>? _changes;` and `bool _stale = true;`, follow unchanged.)
  - Lines 299-314 in `_refresh` become:

```dart
    final walls = <WorldWall>[
      for (final h in _live<WallParams>(ArchitectureTypes.wall))
        WorldWall(h, doc.components.get<WallParams>(h)!,
            doc.tree.accumulatedTransform(h)),
    ];
    _sweep(walls);
    final byHandle = {for (final w in walls) w.handle: w};
    for (final w in walls) {
      _inputs[w.handle] = roomInputOf(w.handle, w.params, w.toWorld, walls: [
        for (final n in _neighbours[w.handle]!) byHandle[n]!,
      ]);
    }
    for (final h in _live<SeparatorParams>(ArchitectureTypes.separator)) {
      _inputs[h] = roomInputOf(h, doc.components.get<SeparatorParams>(h)!,
          doc.tree.accumulatedTransform(h));
    }
```

  - After `_refresh` (before `_sweep`'s doc comment, today's line 327), add:

```dart
  /// The holders of a `T` whose live type id is [typeId], ascending by
  /// handle (`withComponent`'s order): today's `liveObjectsOf<T>`, asked of
  /// the plan's live rule.
  List<Handle> _live<T extends Component>(String typeId) => [
        for (final h in document.components.withComponent<T>())
          if (live(h) == typeId) h,
      ];
```

  - Line 358's doc (`/// Cancels the document subscription. The owner calls it once.`) → `/// Cancels the document subscription: once, by its owner (the kit's /// services dispose it with its document).` and the method gains `@override`.
  - After the class (after today's line 364), add:

```dart
/// The kit's one [RoomInputs] for [s]'s document (spec 3a C2): the Room
/// tool, the Separator tool and the separator grips share it, as they
/// shared the shell's one. Made on first use, disposed with the document.
RoomInputs roomInputsOf(PlanServices s) =>
    s.shared<RoomInputs>((s) => RoomInputs(s.document, liveTypesOf(s)));
```

- [ ] **Step 10: Run the kit's tests.** `cd packages/jet_cad_2d_kit_architecture && dart format . && flutter test`. Expected: `All tests passed!` (the new and ported files, and every earlier task's). Then check the non-ASCII literals: `grep -c "m²" packages/jet_cad_2d_kit_architecture/test/room/room_label_test.dart` equals `grep -c "m²" packages/jet_cad_floor_plan/test/room_label_test.dart` (likewise `ft²`, and `room_trace_test`, `room_tie_test`).

- [ ] **Step 11: The gates.** From the repository root:
  - `cd packages/jet_cad_2d_kit_architecture && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` — `All tests passed!`, `No issues found!`, exit 0.
  - `dart run tool/ci/check_kit_deps.dart` — exit 0 (the kit names neither the plan library nor another kit, `test/` included).
  - `git status --short` — only this task's files; no `analysis_options.yaml`, nothing under `packages/jet_cad_floor_plan`.

- [ ] **Step 12: Commit.**

```bash
git add packages/jet_cad_2d_kit_architecture/lib/jet_cad_2d_kit_architecture.dart packages/jet_cad_2d_kit_architecture/lib/src/wall/wall.dart packages/jet_cad_2d_kit_architecture/lib/src/type_naming.dart packages/jet_cad_2d_kit_architecture/lib/src/separator/separator.dart packages/jet_cad_2d_kit_architecture/lib/src/room/room_trace.dart packages/jet_cad_2d_kit_architecture/lib/src/room/room_inputs.dart packages/jet_cad_2d_kit_architecture/lib/src/room/room_label.dart packages/jet_cad_2d_kit_architecture/test/support/catalog.dart packages/jet_cad_2d_kit_architecture/test/support/room_fixture.dart packages/jet_cad_2d_kit_architecture/test/separator/separator_test.dart packages/jet_cad_2d_kit_architecture/test/room/room_trace_test.dart packages/jet_cad_2d_kit_architecture/test/room/room_inputs_test.dart packages/jet_cad_2d_kit_architecture/test/room/room_label_test.dart packages/jet_cad_2d_kit_architecture/test/room/room_localise_test.dart packages/jet_cad_2d_kit_architecture/test/room/room_tie_test.dart packages/jet_cad_2d_kit_architecture/test/room/room_inputs_services_test.dart
git commit -m "$(cat <<'EOF'
feat(kit-architecture): room tracing, its inputs and the separator's type

Ports the room tracer, its inputs and its label, and the separator's
parameters and type, from jet_cad_floor_plan (spec 3a C3.4, C3.5). The
document adapter reads the plan's live rule, so a frozen wall or
separator is no input, and is the kit's PlanServices.shared object
(roomInputsOf), with today's invalidation. The separator's tests, the
tracer's, the inputs', the label's, the localised trace's and the
doubled-edge DE1 come with them, assertions unchanged.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 13: Mutation check** (committed files only; after each: run the named test, see it red, then `git checkout -- <file>` and `git diff --quiet -- <file>` must exit 0). Run with `cd packages/jet_cad_2d_kit_architecture && flutter test <test file>`. Quote each red line.
  - M-RR-1 `lib/src/room/room_inputs.dart`: in `_refresh`, `_live<WallParams>(ArchitectureTypes.wall)` → `document.components.withComponent<WallParams>()` → RR-live red (the frozen partition is an input; the box splits).
  - M-RR-2 `room_inputs.dart`: `_live<SeparatorParams>(ArchitectureTypes.separator)` → `document.components.withComponent<SeparatorParams>()` → RR-live red (`inputOf(sep)` not null).
  - M-RR-3 `room_inputs.dart`: `roomInputsOf`'s body → `RoomInputs(s.document, liveTypesOf(s))` → RR-shared red (`same(inputs)`).
  - M-RR-4 `room_inputs.dart`: `implements PlaceSource, Disposable` → `implements PlaceSource` (and delete the `@override` on `dispose`) → RR-shared red (the generation moves after the services are disposed).
  - M-RR-5 `room_inputs.dart`: in `_live`, `if (live(h) == typeId) h` → `h` → RR-live red (the port's live rule is the one read).
  - M-RR-6 (the port is the one tested) `lib/src/separator/separator.dart`: `lineweight: 35` → `lineweight: 25` → SR2 red.
  - M-RR-7 `separator.dart`: `componentTypeId = ArchitectureTypes.separator` → `componentTypeId = 'architecture.separators'` → SR1 red.
  - M-RR-8 `lib/src/room/room_trace.dart`: `const double kCertificateMargin = 1;` → `0` → LZ1 red (the margin case, `marginCase`).

#### Assumed from earlier tasks

- Task 9: `lib/src/live.dart` defines `LiveTypeOf` and `liveTypesOf(PlanServices)` as in the Shared interfaces; `lib/src/separator_linetype.dart` defines `kDashedLinetypeRecord` and `ensureDashedLinetype` (today's `separator.dart:122-149`); the kit's pubspec lists `vector_math` (ruling R-P6).
- Task 11: `test/support/wall_fixture.dart` keeps today's names, and its `driftOf`, `diagnosticsOf`, `reload` and `wallDoc` read `testCatalog()` (so the separator registered here counts in them from this task on).
- Task 11: `wallsInView` keeps today's signature (today's `opening_geometry.dart:604-617`, in the kit's `wall_geometry.dart` since Task 11, R-P8).

#### Interface problem

1. **(Resolved by ruling R-P8: Task 11 leaves the place hooks to this task; Step 2 adds them.)** **An import cycle across Tasks 11, 13 and 16.** Today's `wall.dart` imports `room_inputs.dart` for the wall's three place hooks (`jet_cad_floor_plan/lib/src/parametric/wall.dart:5, 172-189`) and `opening_geometry.dart` for its cut (`:4, :150`); `room_inputs.dart` imports `wall.dart`, `wall_geometry.dart` and `opening_geometry.dart`'s `wallsInView` (`room_inputs.dart:13-17`). Task 11 cannot port `WallType` whole before this task. **Proposed fix:** Task 11 ports `WallType` without `contributesPlace`, `placeBox` and `placeInput` (the engine's defaults: no place), and this task adds them (Step 2 is written for that case and is a no-op otherwise). `wall_regen_test` and `wall_bands_test` (Task 11) do not read places; the room tests here do, and land with the hooks.
2. **The kit's runtime dependencies** (`vector_math`, `meta`): settled by ruling R-P6 (the kit's pubspec lists `vector_math`; Task 18's `room.dart` also needs `meta`, as the contract's pubspec has it: Task 9 to confirm).
3. **`room_cost_test`'s LZ3 needs the sample flat.** LZ3 (`room_cost_test.dart:94-174`) runs on `startupPlan(m)` (`:104`). The kit's `buildSampleFlat` arrives in Task 25. **Proposed fix (settled by ruling R-P10: Task 26, not 25, adds LZ3; its Step 8 does, in the kit over `buildSampleFlat`):** Task 18 ports RK1 and RK2; Task 26 adds LZ3 to `test/room/room_cost_test.dart` (a document with the test catalog's system and `buildSampleFlat` run on it, as Task 25's own `startup_plan_test` port does), assertions unchanged.

#### New shared name

- `test/support/room_fixture.dart` re-exports Task 11's `liveOf(doc, {frozen})` (R-P17; no `liveOf`), and the fixture itself (re-exporting `testCatalog` and `installParametric`), consumed by Task 17 (today's `separator_tool_test.dart` builds its plans with `room_fixture.dart`) and Tasks 18, 19. Every `RoomInputs(x)` of a ported kit case becomes `RoomInputs(x, liveOf(x))`.

---

