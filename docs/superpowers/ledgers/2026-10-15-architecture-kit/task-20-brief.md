### Task 20: Dimension geometry, attachment and parameters (spec C3.6, C1.5, C7)

**Files** (paths under `packages/jet_cad_2d_kit_architecture/` unless they say otherwise):
- Create: `lib/src/dimension/dimension_geometry.dart` (ported), `lib/src/dimension/dimension_attach.dart` (ported, adapted), `lib/src/dimension/dimension.dart` (ported, adapted)
- Modify: `lib/jet_cad_2d_kit_architecture.dart` (the dimension's public names)
- Modify: `test/support/catalog.dart` (Task 10's kit test catalog, R-P13): the dimension's registration
- Modify: `lib/src/type_naming.dart` (Task 14's, ruling R-P19: `kitTypeIdOf`'s raw registrations; Tasks 16 and 18 appended the separator and the room): the dimension's registration, last
- Modify: `test/room/room_tool_test.dart` (Task 19's): TT10, moved here from Task 19 (it needs the dimension this task creates)
- Test (support, ported): `test/support/dimension_fixture.dart`
- Test (ported): `test/dimension/dimension_params_test.dart`, `dimension_format_test.dart`, `dimension_layout_test.dart`, `dimension_attach_test.dart`, `dimension_attach_points_test.dart`, `dimension_follow_test.dart`, `dimension_rotate_test.dart`, `dimension_fuzz_test.dart`
- Test (new): `test/dimension/dimension_live_test.dart` (DG-frozen, DG-id)

**Reconciliation with the scopes.** The plan's File structure puts `dimension.dart` (`DimensionParams`, `DimensionType`) in this task, beside the geometry and the attachment; the task scope listed it under Task 21. This task follows the File structure: four of this task's eight ported files (`dimension_params`, `_follow`, `_rotate`, `_fuzz`) construct `DimensionParams` and generate through `DimensionType`, so they cannot land without it. Task 21 ports the grips and the plan type only.

**Interfaces:**
- Consumes:
  - Task 9 (Shared interfaces): `ArchitectureTypes.{wall, opening, dimension}` (`lib/src/ids.dart`), `typedef LiveTypeOf = String? Function(Handle handle)` (`lib/src/live.dart`).
  - Task 11: `WallParams`, `Justification`, `wallJoin` (`lib/src/wall/wall.dart`); `WorldWall`, `drawnCapsOf` (`lib/src/wall/wall_geometry.dart`).
  - Task 13: `OpeningParams` (`lib/src/opening/opening.dart`). Task 11: `wallsInView`, `wallsInDocument(doc, host, LiveTypeOf live, {moved})` (`lib/src/wall/wall_geometry.dart`, R-P8, R-P17).
  - Task 9: `ensureDashedLinetype` (`lib/src/separator_linetype.dart`, used by the fixture).
  - Engine: `ParametricType`, `ParametricView`, `ParametricCatalog.typeIdOf` (`parametric_system.dart:674`), `SpatialIndex`, `FilterEvaluator`, `QueryFilter.rendering`, `objectLayer`, `PageComponent`, `DisplayUnit`, `DecimalSeparator`, `ComponentRegistry.withComponent` (ascending by contract, `parametric_system.dart:641-652`).
- Produces (kit-internal; no Shared-interfaces name is new):
  - `lib/src/dimension/dimension_geometry.dart`: today's names unchanged (`WallSide`, `dimAttach`, `dimFormat`, `wallEndPoint`, `wallEndPoints`, `DimKind`, `DimEnd`, `AttachedEnd`, `FixedEnd`, `measuringDirection`, `offsetFor`, `readable`, the `kDim*` constants, `DimLayout`, `layoutDimension`, `roundHalfUp`, `formatDimension`).
  - `lib/src/dimension/dimension_attach.dart`:
    ```dart
    int debugLineTestPasses;            // unchanged
    int debugWallPointComputations;     // unchanged
    typedef WallPoints = List<(int, WallSide, Vector2)>;
    double thickestWall(DraftDocument doc, LiveTypeOf live);
    List<AttachedEnd> attachCandidates(DraftDocument doc, SpatialIndex index, Vector2 q,
        {required LiveTypeOf live, required bool objectSnap, required double thickest,
        Map<Handle, WallPoints>? points});
    AttachedEnd? decideEnd(DraftDocument doc, List<AttachedEnd> candidates,
        {required DimKind kind, required Vector2 at, required Vector2 other, required Transform2 m}); // unchanged
    ```
  - `lib/src/dimension/dimension.dart`: `DimensionParams` (its `componentTypeId` is `ArchitectureTypes.dimension`), `debugDimensionGenerates`, `endPointInView`, `DimensionType`; re-exports `dimension_geometry.dart` (today's).
  - The barrel exports `DimensionParams, DimKind, DimEnd, AttachedEnd, FixedEnd, WallSide` (Shared interfaces' export list).

**R-P1 check:** every case here uses kit internals (`wallsInDocument`, `attachCandidates`, the debug counters) and no plan-library name, so all run in the kit; none needs a plan-internal helper (no `placeSymbol`), so no `place_entry.dart` fixture is used.

**Appendix A rows closed:** D-19's dimension part for these eight files (33 cases): `dimension_params_test` (1), `dimension_format_test` (4), `dimension_layout_test` (6), `dimension_attach_test` (9), `dimension_attach_points_test` (3), `dimension_follow_test` (4), `dimension_rotate_test` (5), `dimension_fuzz_test` (1). Every case goes to the kit (C7): each uses only today's `parametric/` files, the engine, `flutter_test` and the test fixtures; none names `PlannerShell`, `PlannerView`, `SelectionPanel` or any plan-library name. The remaining six dimension files are Tasks 21 and 22. Also `room_tool_test` TT10 (moved from Task 19: it needs this task's dimension), which closes that file with Task 19's eleven.

#### Assumed from earlier tasks

Each name below is used as written; where the earlier task named it otherwise, use that task's name and report the difference in the task report.
- Task 9: `lib/src/ids.dart`'s `ArchitectureTypes`, `lib/src/live.dart`'s `LiveTypeOf` exactly as in Shared interfaces; the kit's pubspec lists `vector_math` (see `#### Interface problem`).
- Task 11 (the wall's test support, ported from `jet_cad_floor_plan/test/support/wall_fixture.dart`): `test/support/wall_fixture.dart` with today's `far`, `polar`, `wallDoc`, `addWallLocal`, `kids`, `kindOf`, `payloadOf`, `worldOutline`, `driftOf`, `diagnosticsOf`, `enc`, `canon`, `reload`, and today's `installParametric(doc)` and `parametricCatalog` turned into the kit's **test catalog**, called `testCatalog` here: a `ParametricCatalog` registering the kit's raw types under their `ArchitectureTypes` ids in today's order (`catalog.dart:27-39`: box, wall, opening, separator, room, dimension), each type task adding its own line. This task adds the dimension's line (Step 3).
- Task 11 (R-P8, R-P17): `wallsInDocument(DraftDocument doc, Handle host, LiveTypeOf live, {Map<Handle, WorldWall> moved = const {}})` in `lib/src/wall/wall_geometry.dart`: today's `opening_geometry.dart:711-727` with its two `live_objects.dart` reads (`:714`, `:720`) answered by `live(h) == ArchitectureTypes.wall`. Every call below passes `live` positionally.
- Task 16 (the room's test support): `test/support/room_fixture.dart`, today's `room_fixture.dart` ported, with `W`, `S`, `O`, `Placement`, `origin`, `corpus`, `corpusGroups`, `km1000`, `km1000Axis`, `km1000Groups`, `placements`, `Plan`, `buildPlan`, `addSeparator`, `addOpening`, `recordOf`, `worldPoints`, `attachPage`, `addRoom`, `pageOf`, `reloadWithPage`, `deleteObject`, `staleFile`, `codedAs`, `samplePlan`, `sampleWalls`, `sampleColumn`, `sampleSeparator`, `sampleOpenings`, `sampleSeeds`, and its re-export of `wall_fixture.dart` (`kids, kindOf, payloadOf, driftOf, diagnosticsOf, canon, reload, enc`).

- [ ] **Step 1: Precondition.** Tasks 9-19 are committed. Run `cd packages/jet_cad_2d_kit_architecture && flutter test && flutter analyze`. Expected: `All tests passed!`, `No issues found!`. Read `test/support/wall_fixture.dart` and `test/support/room_fixture.dart` (Tasks 11, 16) and `lib/src/opening/opening_geometry.dart` (Task 13): confirm the names in "Assumed from earlier tasks", and use the real ones where they differ.

  **Order (tests first):** write Steps 7-9 (the fixture, the ported tests, the new tests) before Steps 2-6, run `cd packages/jet_cad_2d_kit_architecture && flutter test test/dimension/` and see it fail to compile (expected: `Error: Error when reading 'lib/src/dimension/dimension.dart': No such file or directory`, or the analyzer's `Target of URI doesn't exist`); then write Steps 2-6.

- [ ] **Step 2: Port the geometry.** Create `lib/src/dimension/dimension_geometry.dart` from `packages/jet_cad_floor_plan/lib/src/parametric/dimension_geometry.dart`:
  - lines 1-13 (the header) become:
    ```dart
    // Pure dimension geometry (spec 11 D1, D2, D4, D6-D9; the plan's Ruling
    // 11-2): the wall attach points, the dimension tolerances, the value types
    // of a dimension's ends and kind with their JSON, the measuring direction,
    // the placement function, the layout with its paper constants, and the
    // value's format. Moved from jet_cad_floor_plan's
    // lib/src/parametric/dimension_geometry.dart (3a spec C3.6), unchanged
    // but for its imports. No Flutter import.
    ```
  - lines 14-17 unchanged (`dart:math`, `jet_cad_2d`, `vector_math`);
  - lines 19-20 become `import '../wall/wall.dart' show wallJoin;` and `import '../wall/wall_geometry.dart';`;
  - copy lines 21-494 unchanged.

- [ ] **Step 3: Port the attachment.** Create `lib/src/dimension/dimension_attach.dart` from `.../parametric/dimension_attach.dart`:
  - lines 1-6 (header): keep, and append `// Moved from jet_cad_floor_plan (3a spec C3.6); a live wall or opening is\n// the plan's live type (spec C1.5), asked through a LiveTypeOf.`
  - lines 7-14 (imports) become:
    ```dart
    import 'package:jet_cad_2d/jet_cad_2d.dart';
    import 'package:vector_math/vector_math_64.dart' show Vector2;

    import '../ids.dart';
    import '../live.dart';
    import '../opening/opening.dart' show OpeningParams;
    import '../wall/wall.dart';
    import '../wall/wall_geometry.dart' show wallsInDocument;
    import 'dimension_geometry.dart';
    ```
  - copy lines 15-32 unchanged;
  - lines 33-46 (`thickestWall`) become:
    ```dart
    /// `T` (spec 11 D10): the largest **world** thickness of a live wall of
    /// [doc], each wall's stored thickness times its group's `scaleMagnitude`
    /// (so a scaled group, file only, is covered); 0 with no live wall. One pass
    /// over the walls. A live wall is one [live] names a wall (spec 3a C1.5:
    /// the plan's `liveTypeIdOf`, so a frozen wall is none).
    double thickestWall(DraftDocument doc, LiveTypeOf live) {
      var t = 0.0;
      for (final h in doc.components.withComponent<WallParams>()) {
        if (live(h) != ArchitectureTypes.wall) continue;
        final w = doc.components.get<WallParams>(h)!.thickness *
            doc.tree.accumulatedTransform(h).scaleMagnitude;
        if (w > t) t = w;
      }
      return t;
    }
    ```
  - lines 48-114 (the doc comment of `attachCandidates`): copy unchanged, then append a paragraph:
    ```dart
    ///
    /// **[live]** answers which handles are live walls and live openings (spec
    /// 3a C1.5): the plan's `liveTypeIdOf`, so a frozen wall or opening is in
    /// neither query, as it is in no survey.
    ```
  - lines 115-171 become:
    ```dart
    List<AttachedEnd> attachCandidates(
        DraftDocument doc, SpatialIndex index, Vector2 q,
        {required LiveTypeOf live,
        required bool objectSnap,
        required double thickest,
        Map<Handle, WallPoints>? points}) {
      if (!objectSnap) return const [];
      final walls = <Handle>{};
      final tight = dimAttach.linear;
      index.forEachInRect(
          Aabb2.raw(q.x - tight, q.y - tight, q.x + tight, q.y + tight),
          const QueryFilter.rendering(), (slot) {
        final owner = doc.entities.ownerAt(slot);
        if (live(owner) == ArchitectureTypes.wall) walls.add(owner);
      });
      final grown = dimAttach.linear + thickest;
      FilterEvaluator? drawn;
      index.forEachInRect(
          Aabb2.raw(q.x - grown, q.y - grown, q.x + grown, q.y + grown),
          const QueryFilter.rendering(), (slot) {
        final owner = doc.entities.ownerAt(slot);
        if (live(owner) != ArchitectureTypes.opening) return;
        final host = doc.components.get<OpeningParams>(owner)!.host;
        if (live(host) != ArchitectureTypes.wall) return;
        // Only a host the renderer draws (D10: what is drawn attaches): the
        // opening's children passed `rendering()`, its host's group must too,
        // and its object layer must be visible (spec 12b D6, R-7).
        drawn ??= FilterEvaluator(doc);
        if (drawn!.acceptsNode(host, const QueryFilter.rendering()) &&
            _layerVisible(doc, objectLayer(doc, host))) {
          walls.add(host);
        }
      });
      final out = <AttachedEnd>[];
      for (final h in walls.toList()..sort((a, b) => a.value.compareTo(b.value))) {
        if (!_onALine(doc, h, q)) continue;
        debugLineTestPasses++;
        final six = points == null
            ? _wallPointsOf(doc, h, live)
            : (points[h] ??= _wallPointsOf(doc, h, live));
        for (final (k, side, p) in six) {
          if ((p - q).length <= dimAttach.linear) out.add(AttachedEnd(h, k, side));
        }
      }
      return out;
    }

    /// Whether [layer] is drawn (spec 12b D6): a missing record counts as
    /// visible, as `FilterEvaluator` counts it.
    bool _layerVisible(DraftDocument doc, Handle layer) =>
        doc.tables.layers[layer]?.visible ?? true;

    /// Live wall [h]'s six points among every other live wall of [doc].
    WallPoints _wallPointsOf(DraftDocument doc, Handle h, LiveTypeOf live) {
      debugWallPointComputations++;
      final ws = wallsInDocument(doc, h, live)!;
      return wallEndPoints(ws.host, ws.walls);
    }
    ```
  - copy lines 172-297 unchanged (`_onALine`, `_nearALine`, `decideEnd`, `_parallelMeasure`, `_before`, `_centreRank`: they read `WallParams` of handles the caller already decided).

- [ ] **Step 4: Port the parameters and the type.** Create `lib/src/dimension/dimension.dart` from `.../parametric/dimension.dart`:
  - lines 1-12 (header): keep, and append `// Moved from jet_cad_floor_plan (3a spec C3.6); its type id is\n// architecture.dimension.`
  - lines 13-24 become:
    ```dart
    import 'dart:math' as math;
    import 'dart:typed_data' show Float64List;

    import 'package:flutter/foundation.dart' show visibleForTesting;
    import 'package:jet_cad_2d/jet_cad_2d.dart';
    import 'package:vector_math/vector_math_64.dart' show Vector2;

    import '../ids.dart';
    import '../wall/wall.dart' show WallParams, wallJoin;
    import '../wall/wall_geometry.dart' show wallsInView;
    import 'dimension_geometry.dart';

    export 'dimension_geometry.dart';
    ```
    (`visibleForTesting` comes from Flutter's foundation, which re-exports `meta`'s; the kit's pubspec also lists `meta` (R-P11), so `package:meta/meta.dart` would do as well; one of the two, not both, or `unnecessary_import` fails the analyzer.)
  - copy lines 25-42 unchanged; line 43 becomes `  static const String componentTypeId = ArchitectureTypes.dimension;`
  - copy lines 44-304 unchanged (`endPointInView` reads `wallsInView`, the view adapter, which needs no `LiveTypeOf`: the view answers only live objects of the survey).

- [ ] **Step 5: The barrel.** In `lib/jet_cad_2d_kit_architecture.dart` add, in the export order Task 9 set (types in `ArchitectureTypes` order):
  ```dart
  export 'src/dimension/dimension.dart'
      show AttachedEnd, DimEnd, DimKind, DimensionParams, FixedEnd, WallSide;
  ```

- [ ] **Step 6: The test catalog.** In the kit's test catalog (`test/support/catalog.dart`, Task 10's, R-P13), append to `_testCatalog`'s cascade after the room's registration, keeping today's order (`catalog.dart:38-39`):
  ```dart
    ..register<DimensionParams>(DimensionParams.componentTypeId,
        DimensionParams.fromJson, const DimensionType())
  ```
  and the import `package:jet_cad_2d_kit_architecture/src/dimension/dimension.dart`. Separator stays registered after opening (AM7's premise: a group carrying both is the later registration's, the separator).

  Likewise in `lib/src/type_naming.dart` (Task 14, ruling R-P19; its header names this task): append to `_naming`'s cascade, after the room's (today's order, `catalog.dart:38-39`), with `import 'dimension/dimension.dart';`:
  ```dart
    ..register<DimensionParams>(DimensionParams.componentTypeId,
        DimensionParams.fromJson, const DimensionType())
  ```
  (Without it a dimension group that also carries `WallParams`, EG10's, would read as a wall to the opening's position range, unlike the plan's catalog.)

- [ ] **Step 7: Port the fixture.** Create `test/support/dimension_fixture.dart` from `packages/jet_cad_floor_plan/test/support/dimension_fixture.dart`:
  - lines 1-15 (header): keep, and append `// Ported into jet_cad_2d_kit_architecture (3a Task 20): the kit's own\n// files, the kit's test catalog, and a LiveTypeOf for the attach calls.`
  - lines 16-32 (imports) become:
    ```dart
    import 'dart:math' as math;

    import 'package:jet_cad_2d/jet_cad_2d.dart';
    import 'package:jet_cad_2d_kit_architecture/src/dimension/dimension.dart';
    import 'package:jet_cad_2d_kit_architecture/src/opening/opening.dart';
    import 'package:jet_cad_2d_kit_architecture/src/separator_linetype.dart'
        show ensureDashedLinetype;
    import 'package:jet_cad_2d_kit_architecture/src/wall/wall.dart';
    import 'package:jet_cad_2d_kit_architecture/src/wall/wall_geometry.dart';
    import 'package:vector_math/vector_math_64.dart' show Vector2;

    import 'room_fixture.dart';
    import 'wall_fixture.dart' show addWallLocal, far, liveOf, polar, wallDoc;

    export 'room_fixture.dart';
    ```
    (No `live.dart` import: the fixture never names `LiveTypeOf`, it only calls `liveOf(doc)`. `unused_import` fails `flutter analyze`: if one of these imports is unused once the file is written, drop it.)
  - copy lines 33-264 unchanged;
  - no live reader of its own: every attach call of the ported tests passes `liveOf(doc)` (Task 11's `wall_fixture.dart`, R-P17; it reaches the tests through `room_fixture.dart`'s re-export, which this file exports);
  - line 277 becomes `    final ws = wallsInDocument(doc, h, liveOf(doc));`; line 452 becomes `      final ws = wallsInDocument(doc, wall, liveOf(doc));`;
  - copy lines 265-276, 278-451, 453-522 unchanged (`flushFreeScaled`'s `ensureDashedLinetype` is the kit's, imported above).

- [ ] **Step 8: Port the eight test files** into `test/dimension/`, **assertions unchanged**, no C7 class of change applies (no id, tag or widget is asserted). Common adaptations for every file:
  - imports: `package:jet_cad_floor_plan/src/parametric/<f>.dart` → `package:jet_cad_2d_kit_architecture/src/dimension/<f>.dart` for `dimension`, `dimension_geometry`, `dimension_attach`; `.../wall/wall.dart`, `.../wall/wall_geometry.dart`, `.../opening/opening.dart`, `.../opening/opening_geometry.dart` for the others, except that a `show` list's `wallsInView` and `wallsInDocument` come from `.../wall/wall_geometry.dart` (Task 11, R-P8); `parametric/separator.dart` `show SeparatorParams, ensureDashedLinetype` → `.../separator/separator.dart' show SeparatorParams` plus `.../separator_linetype.dart' show ensureDashedLinetype`; `parametric/catalog.dart' show installParametric` → dropped: `installParametric` (Task 10's installer of `testCatalog()`) reaches every file through `dimension_fixture.dart`, which exports `room_fixture.dart` and its re-export of it, so a second import of it is an `unnecessary_import`, which fails `flutter analyze`; `'support/<x>.dart'` → `'../support/<x>.dart'`. Keep every `show` list otherwise as written.
  - every call `wallsInDocument(doc, X)` → `wallsInDocument(doc, X, liveOf(doc))` (the document variable as named at the call);
  - every call `thickestWall(doc)` → `thickestWall(doc, liveOf(doc))`;
  - every call `attachCandidates(doc, index, q, objectSnap: ..., thickest: ...)` gains `live: liveOf(doc),` as its first named argument (the document as named at the call).
  - Per file (sources under `packages/jet_cad_floor_plan/test/`; every case to the kit):
    - `dimension_params_test.dart` → `test/dimension/dimension_params_test.dart`: DP1 (looped over `origin`, `corpusGroups`). Imports only.
    - `dimension_format_test.dart`: DF1, DF2, DF3, Q0-DF1. `:9-10`'s `opening_geometry.dart' show wallsInDocument` → `.../wall/wall_geometry.dart' show wallsInDocument`; `:234-235` (`wallsInDocument(doc, e0.wall)!`, `wallsInDocument(doc, e1.wall)!`) gain `liveOf(doc)` as their third argument.
    - `dimension_layout_test.dart`: DL1, DL2, DL2b, DL3, DL4, DL5. Imports only.
    - `dimension_attach_test.dart`: AM3, AM1, AM2, AM2 (scaled group), AM4, AM5 (prints), AM6, AM6b, AM7. `:33, :40, :62, :412, :600` (`wallsInDocument`), `:400, :454, :648, :665, :752, :770, :815, :863, :896, :988` (`thickestWall`), `:421, :453, :647, :715, :732, :754, :827, :845, :873, :895, :990, :999` (`attachCandidates`); `hiddenPlan`'s `installParametric(doc); ensureDashedLinetype(doc);` (`:140-141`) stays as written with the imports above. AM7 keeps its premise comment "Separator is registered after Opening": it holds for `testCatalog` (Step 6).
    - `dimension_attach_points_test.dart`: AP1, AP2, AP3. Imports only (`wall_fixture.dart show far, worldOutline`).
    - `dimension_follow_test.dart`: DN1, DN2, DN3, DN4. Imports only (`debugDimensionGenerates` from the kit's `dimension.dart`).
    - `dimension_rotate_test.dart`: DR1, DR2, DR3, DR4, DR5. Imports only.
    - `dimension_fuzz_test.dart`: DZ1. Imports only.
  - Before porting, check `packages/jet_cad_2d_plan/test/` and `packages/jet_cad_2d_kit/test/` for any of these ids (`grep -rn "DP1\|DF1\|DL1\|AM3\|AP1\|DN1\|DR1\|DZ1" packages/jet_cad_2d_plan/test packages/jet_cad_2d_kit/test`): expected none (no 2a or 2b task ported a dimension case, `deferrals.md` rows 125-138). A hit is a finding: stop and report it.
  - Non-ASCII literals (Global Constraints, 2b's lesson): the sources hold `−` (U+2212), `–` (U+2013), `σ`, `∩` and `°` in strings and comments (e.g. `dimension_format_test.dart:128, :174, :215`; `dimension_attach_test.dart`'s reasons with `σ_A`), and no edited line holds one. After writing, run `perl -ne '$n++ if /[^\x00-\x7f]/; END { print $n+0, "\n" }' <file>` on each source and its destination (and on `support/dimension_fixture.dart`): the counts are equal (format 53, layout 52, attach 53, attach_points 54, follow 29, rotate 63, fuzz 1, params 0), and `perl -ne 'print "$.: $_" if /[^\x00-\x7f]/' <file>` shows the same lines.

- [ ] **Step 9: The new tests.** Create `test/dimension/dimension_live_test.dart`:

```dart
// 3a Task 20, spec C1.5: the dimension's attach search asks the plan's live
// types, never a catalog of its own. A frozen wall (the plan's
// liveTypeIdOf answers null) is no candidate, by its own children or as an
// opening's host, and no part of T; a frozen opening brings no host in.
// Today's rule (`live_objects.dart`) asked the global catalog, which
// answers a frozen object's id too (spec C1.5's Facts:
// `ParametricCatalog.typeIdOf`, parametric_system.dart:672-675).
//
// The fixture is AM6's flush T (spike C5) at the corpus far origin with
// every wall in its own turned group: C (0, 0) -> (6000, 0), 200; S (2500,
// 0) -> (2500, 3000), 100; a 900 mm door on S centred 450 along it, so S's
// butt-end points are reached only through the door's host query (AM6's
// premise, re-asserted below).
import 'dart:convert' show jsonDecode;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit_architecture/src/dimension/dimension.dart';
import 'package:jet_cad_2d_kit_architecture/src/dimension/dimension_attach.dart';
import 'package:jet_cad_2d_kit_architecture/src/ids.dart';
import 'package:jet_cad_2d_kit_architecture/src/live.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/dimension_fixture.dart';

const l = WallSide.left, c = WallSide.centre;

void main() {
  test(
      'DG-frozen a frozen wall is no candidate and no part of T; a frozen '
      'host is not brought in by its door; a frozen door brings no host '
      '(M-DG1, M-DG2, M-DG3, M-DG4)', () {
    final plan = flushT(corpusGroups);
    final doc = plan.doc;
    final [cw, s] = plan.walls;
    final door = plan.openings.single;
    final index = SpatialIndex(doc);
    addTearDown(index.dispose);
    final all = liveOf(doc);
    LiveTypeOf frozen(Handle h) => (x) => x == h ? null : all(x);

    // Premises: the catalog names all three; the plan's view of a frozen
    // object answers null for it alone.
    expect(all(cw), ArchitectureTypes.wall);
    expect(all(s), ArchitectureTypes.wall);
    expect(all(door), ArchitectureTypes.opening);
    expect(frozen(cw)(cw), isNull);
    expect(frozen(cw)(s), ArchitectureTypes.wall);

    // -- T: the thickest live wall. C is 200, S 100.
    expect(thickestWall(doc, all), 200, reason: 'control');
    expect(thickestWall(doc, frozen(cw)), 100, reason: 'C frozen: S only');

    // -- C's free start, left face (0, 100): a point of C's own children.
    final c0 = plan.at(0, 100);
    List<AttachedEnd> at(Vector2 q, LiveTypeOf live) => attachCandidates(
        doc, index, q,
        live: live, objectSnap: true, thickest: thickestWall(doc, live));
    expect(at(c0, all), contains(AttachedEnd(cw, 0, l)), reason: 'control');
    expect([for (final e in at(c0, frozen(cw))) e.wall], isNot(contains(cw)),
        reason: 'C frozen: none of its points');

    // -- S's butt end on C's face, its centre (2500, 0): not stored on S
    // (AM6), so only the door's host query reaches it.
    final s0 = plan.at(2500, 0);
    expect(at(s0, all), contains(AttachedEnd(s, 0, c)), reason: 'control');
    expect(bruteCandidates(doc, s0), contains(AttachedEnd(s, 0, c)),
        reason: 'premise: a point of S');
    expect([for (final e in at(s0, frozen(s))) e.wall], isNot(contains(s)),
        reason: 'S frozen: its door does not bring it in');
    expect([for (final e in at(s0, frozen(door))) e.wall], isNot(contains(s)),
        reason: 'the door frozen: no host query through it');
  });

  test(
      'DG-id a dimension is stored under architecture.dimension (M-DG5)',
      () {
    expect(DimensionParams.componentTypeId, ArchitectureTypes.dimension);
    expect(ArchitectureTypes.dimension, 'architecture.dimension');
    final plan = buildPlan(const [W(0, 0, 4000, 0, 200)], place: corpusGroups);
    addDimension(plan.doc, const FixedEnd(10.5, -20.25),
        const FixedEnd(3010.75, 1180.5),
        kind: DimKind.horizontal, offset: 300.25, at: corpusGroups.m);
    final json = jsonDecode(enc(plan.doc)) as Map<String, Object?>;
    final components = json['components']! as Map<String, Object?>;
    expect(components.keys, contains('architecture.dimension'));
    expect(components.keys, isNot(contains('floor_planner.dimension')));
  });
}
```

  Run: `cd packages/jet_cad_2d_kit_architecture && flutter test test/dimension/`. Expected before Steps 2-6: the compile failure of Step 1's order note. After Steps 2-6: `All tests passed!`; if the S/0/centre premise of DG-frozen fails (`bruteCandidates` not containing `AttachedEnd(s, 0, c)`), re-read AM6's hand values (`dimension_attach_test.dart:793-800` today) and report: never change a hand value.

- [ ] **Step 9b: TT10 (moved from Task 19).** Append to `test/room/room_tool_test.dart` (Task 19's), inside `main` after TT9, today's TT10 (`packages/jet_cad_floor_plan/test/room_tool_test.dart:929-1008`), **assertions unchanged**, with Task 19's adaptations for its lines: `.notice.value` → `.occupied.value` at `:996` and `:1005` (the tool's listenable renamed, Task 19); `:982` `isLiveObject<DimensionParams>(doc, h)` → `testCatalog().names<DimensionParams>(doc, h)`. `DimensionParams`, `FixedEnd` and `DimKind` come from the kit barrel the file already imports (Step 5 exports them). Its premise "Dimension is registered after Room" holds through Step 6. Run `flutter test test/room/room_tool_test.dart`: TT10 passes (the Room tool's live rule is Task 19's); a red TT10 is a finding for Task 19's code: stop and report it.

- [ ] **Step 10: Run the whole package.** `cd packages/jet_cad_2d_kit_architecture && flutter test`. Expected: `All tests passed!` (AM5 prints its timing; nothing asserted on it).

- [ ] **Step 11: Format and the gates.** `cd packages/jet_cad_2d_kit_architecture && dart format . && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` — `All tests passed!`, `No issues found!`, exit 0. From the repository root: `dart run tool/ci/check_kit_deps.dart` (the kit changed): exit 0 and no line naming `jet_cad_2d_kit_architecture`. `git status --short`: only this task's files.

- [ ] **Step 12: Commit.**

```bash
git add packages/jet_cad_2d_kit_architecture/lib/src/type_naming.dart packages/jet_cad_2d_kit_architecture/lib/src/dimension/dimension_geometry.dart packages/jet_cad_2d_kit_architecture/lib/src/dimension/dimension_attach.dart packages/jet_cad_2d_kit_architecture/lib/src/dimension/dimension.dart packages/jet_cad_2d_kit_architecture/lib/jet_cad_2d_kit_architecture.dart packages/jet_cad_2d_kit_architecture/test/support/catalog.dart packages/jet_cad_2d_kit_architecture/test/support/dimension_fixture.dart packages/jet_cad_2d_kit_architecture/test/dimension/dimension_params_test.dart packages/jet_cad_2d_kit_architecture/test/dimension/dimension_format_test.dart packages/jet_cad_2d_kit_architecture/test/dimension/dimension_layout_test.dart packages/jet_cad_2d_kit_architecture/test/dimension/dimension_attach_test.dart packages/jet_cad_2d_kit_architecture/test/dimension/dimension_attach_points_test.dart packages/jet_cad_2d_kit_architecture/test/dimension/dimension_follow_test.dart packages/jet_cad_2d_kit_architecture/test/dimension/dimension_rotate_test.dart packages/jet_cad_2d_kit_architecture/test/dimension/dimension_fuzz_test.dart packages/jet_cad_2d_kit_architecture/test/dimension/dimension_live_test.dart packages/jet_cad_2d_kit_architecture/test/room/room_tool_test.dart
git commit -m "$(cat <<'EOF'
feat(kit-architecture): dimension geometry, attachment and parameters (3a C3.6)

The dimension's geometry, attach search and parametric type move from
jet_cad_floor_plan, unchanged but for the id (architecture.dimension)
and the live rule: the attach search and T ask the plan's live types
(C1.5), so a frozen wall or opening is no candidate. Thirty-three
cases ported with their assertions; DG-frozen and DG-id are new.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

  (The test catalog lives in `test/support/catalog.dart`, R-P13: that file is staged, not `wall_fixture.dart`.)

- [ ] **Step 13: Mutation check** (committed files only; after each: run the named test, see it red, quote the red line, then `git checkout -- <file>` and `git diff --quiet -- <file>` must exit 0). `F = packages/jet_cad_2d_kit_architecture/lib/src/dimension/dimension_attach.dart`; tests run from `packages/jet_cad_2d_kit_architecture`.
  - M-DG1 `F`: in `thickestWall`, delete `if (live(h) != ArchitectureTypes.wall) continue;` → DG-frozen red (`flutter test test/dimension/dimension_live_test.dart`: `C frozen: S only`).
  - M-DG2 `F`: in the first `forEachInRect`, `if (live(owner) == ArchitectureTypes.wall) walls.add(owner);` → `if (doc.components.get<WallParams>(owner) != null) walls.add(owner);` → DG-frozen red (`C frozen: none of its points`, or a null-check throw from `wallsInDocument`: either is red).
  - M-DG3 `F`: `if (live(host) != ArchitectureTypes.wall) return;` → `if (doc.components.get<WallParams>(host) == null) return;` → DG-frozen red (`S frozen`).
  - M-DG4 `F`: `if (live(owner) != ArchitectureTypes.opening) return;` → `if (doc.components.get<OpeningParams>(owner) == null) return;` → DG-frozen red (`the door frozen`) and AM7 red (`flutter test test/dimension/dimension_attach_test.dart`).
  - M-DG5 `lib/src/dimension/dimension.dart`: `componentTypeId = ArchitectureTypes.dimension` → `componentTypeId = 'floor_planner.dimension'` → DG-id red. (The test catalog registers under `componentTypeId`, so the ported tests may stay green: that is why DG-id exists.)
  - M-DG6 `lib/src/dimension/dimension_geometry.dart`: in `formatDimension`'s centimetres arm, `${decimalSeparator.char}` → `.` → Q0-DF1 red (`flutter test test/dimension/dimension_format_test.dart`). A port check: a mutation that stays green is a finding.
  - M-DG7 `lib/src/dimension/dimension.dart`: `references` returns a `List` (`=> [ if (...) wall, if (...) wall ]`) instead of the set → DP1 red (`references are deduplicated`).
  - M-RT-7 (moved from Task 19 with TT10) `lib/src/room/room_plan.dart`: in `roomPlanTool.create`, `live: liveTypesOf(s)` → `live: (h) => ArchitectureTypes.room` → TT10 red (`flutter test test/room/room_tool_test.dart`: the dimension group carrying `RoomParams` occupies the face).
  - M-RT-10 (moved from Task 19 with TT10) `lib/src/room/room_tool.dart`: in `_liveRooms`, `if (live(h) == ArchitectureTypes.room) h` → `h` → TT10 red.

#### Interface problem

1. **(Resolved by rulings R-P6 and R-P11.)** **The kit's pubspec needs `vector_math`.** Every ported file imports `package:vector_math/vector_math_64.dart` (today's `dimension_geometry.dart:17`, `dimension_attach.dart:8`, `dimension.dart:18`, and every wall, opening, room and separator file), and `jet_cad_2d`'s barrel does not export `Vector2` (`packages/jet_cad_2d/lib/jet_cad_2d.dart`, no `vector_math` export). Under `lints/recommended` (`depend_on_referenced_packages`) the import needs a direct dependency. Global Constraints' "Dependencies" list `flutter`, `jet_cad_2d`, `jet_cad_2d_flutter`, `jet_cad_2d_kit` "and nothing else at runtime". **Proposed fix:** Task 9's pubspec adds `vector_math: ^2.2.0` (the plan library's and the contract's own floor, `packages/jet_cad_2d_plan/pubspec.yaml`, `packages/jet_cad_2d_kit/pubspec.yaml`), and Global Constraints say so. The same holds for `jet_cad_2d_integration`, whose tests build plans with `Vector2`, `Transform2` and `PageComponent` (it needs `jet_cad_2d`, `jet_cad_2d_flutter`, `jet_cad_2d_kit` and `vector_math` as direct dependencies, not only "what they export"). `meta` is avoided here (`visibleForTesting` from `package:flutter/foundation.dart`); if Task 9 lists `meta`, either import works.

#### New shared name

- **The kit's test catalog** (test support, used by every type task's ported tests; settled by ruling R-P13): `ParametricCatalog testCatalog()` and `ParametricSystem installParametric(DraftDocument doc)` in `packages/jet_cad_2d_kit_architecture/test/support/catalog.dart` (Task 10; Task 11's `wall_fixture.dart` re-exports them), registering the kit's raw types under their `ArchitectureTypes` ids in today's order (box, wall, opening, separator, room, dimension; `catalog.dart:27-39`), each type task appending its own registration (this task: the dimension's). It replaces today's `parametricCatalog` in every ported fixture (`wallDoc`, `driftOf`, `diagnosticsOf`, `reload`, `reloadWithPage`, `staleFile`). If Task 11 builds it from `architectureKit.types` instead, the dimension's raw registration in Step 6 is still needed until Task 21 adds `dimensionPlanType`, and Task 21 removes it.
- **`wallsInDocument`'s live parameter** (settled by ruling R-P17; Task 11's, in `wall_geometry.dart`; consumed here, in Tasks 21 and 22 and by every caller of the document adapter): `({WorldWall host, List<WorldWall> walls})? wallsInDocument(DraftDocument doc, Handle host, LiveTypeOf live, {Map<Handle, WorldWall> moved = const {}})`.

---

