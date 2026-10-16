### Task 13: Opening geometry and cuts (spec C3.3, C1.5, C7)

**Files:**
- Create (`packages/jet_cad_2d_kit_architecture/`):
  - `lib/src/opening/opening.dart` (ported: `OpeningKind`, `HingeEnd`, `SwingSide`, `OpeningParams`, `OpeningType`, `isOpeningWidth`)
  - `lib/src/opening/opening_geometry.dart` (ported: the frame, obstacles, stretches, cuts, pieces, symbols, the view adapter's cuts and the document adapter over a `LiveTypeOf`)
  - `test/support/opening_fixture.dart` (ported oracles, plus `liveOf`)
  - `test/opening/opening_params_test.dart`, `opening_geometry_test.dart`, `opening_cut_test.dart`, `opening_kink_test.dart`, `opening_obstacle_test.dart`, `opening_cost_test.dart`, `opening_symbol_test.dart` (ported)
  - `test/opening/opening_live_test.dart` (new: OG-live)
- Modify (`packages/jet_cad_2d_kit_architecture/`):
  - `lib/jet_cad_2d_kit_architecture.dart` (exports the opening's parameter class and enums)
  - `lib/src/wall/wall.dart` (the wall's `generate` cut by its openings: today's `_cut`)
  - `test/support/catalog.dart` (Task 10's kit test catalog, R-P13: registers the opening after the wall)

**Interfaces:**
- Consumes:
  - Task 9: `ArchitectureTypes.opening`, `ArchitectureTypes.wall` (`lib/src/ids.dart`); `typedef LiveTypeOf = String? Function(Handle handle)` (`lib/src/live.dart`).
  - Task 11: `lib/src/wall/wall.dart` (`WallParams`, `Justification`, `wallJoin`, `kWallColor`, `WallType`), `lib/src/wall/wall_geometry.dart` (`WorldWall`, `capsOf`, `cap`, `End`, `Free`, `Tee`, `strictlyInside`, `intersect`, `isSimpleCcw`, `simplifyRing`, and the two adapters this task's "Interface problem" assumes there: `wallsInView(ParametricView view, Handle host)` and `wallsInDocument(DraftDocument doc, Handle host, LiveTypeOf live, {Map<Handle, WorldWall> moved})`). Task 11's test support `test/support/wall_fixture.dart` with today's names (`ox`, `oy`, `far`, `plan`, `polar`, `groupAt`, `nextUp`, `wallDoc`, `addWall`, `addWallLocal`, `addSpoke`, `kids`, `kindOf`, `payloadOf`, `pointsOf`, `worldWallOf`, `worldOutline`, `nearestIn`, `oracleMeet`, `driftOf`, `diagnosticsOf`, `enc`, `canon`, `reload`) and the kit test catalog `testCatalog` (see "New shared name").
  - Task 10: `BoxParams`, `BoxType` (`lib/src/box/box.dart`), registered in `testCatalog` (OD1 hosts an opening on a box).
  - Engine: `ParametricType`, `ParametricView` (`referrers`, `paramsOf`, `toWorld`, `neighbours`), `ParametricSystem`, `ParametricCatalog.typeIdOf`, `ComponentRegistry.withComponent`, `triangulationFor`, `polylinePayload`, `linePayload`, `arcPayload`, `Generated`, `Diagnostic`.
- Produces (internal to the kit, used by Tasks 14, 15, 16, 20-22, 24, 28):

```dart
// lib/src/opening/opening.dart — today's names; the id is the only change.
enum OpeningKind { door, window, gap }
enum HingeEnd { start, end }
enum SwingSide { left, right }
final class OpeningParams implements Component {
  const OpeningParams(this.host, this.position, this.width, this.kind,
      {this.hinge = HingeEnd.start, this.swing = SwingSide.left});
  static const String componentTypeId = ArchitectureTypes.opening; // 'architecture.opening'
  // host, position, width, kind, hinge, swing; toJson; fromJson; copyWith; ==; hashCode; toString
}
final class OpeningType extends ParametricType<OpeningParams> { const OpeningType(); }
bool isOpeningWidth(OpeningKind kind, double w);

// lib/src/opening/opening_geometry.dart — today's names and signatures,
// except the three document adapters, which take the plan's live answer:
final class HostFrame { /* unchanged */ }
HostFrame? hostFrameOf(WorldWall host, List<WorldWall> walls);
typedef Obstacle = ({double a, double b, Handle wall});
List<Obstacle> obstaclesOf(HostFrame frame, WorldWall host, List<WorldWall> walls);
List<(double, double)> stretchesOf(HostFrame frame, List<Obstacle> obstacles);
typedef Cut = ({double a, double b, bool clamped});
Cut? placeCut(List<(double, double)> stretches, double c, double w);
double storedCentreOf(List<(double, double)> stretches, Cut cut, double w);
List<(double, double)> mergeCuts(List<(double, double)> cuts);
({List<Cut?> cuts, List<(double, double)> merged}) cutsOf(HostFrame frame,
    List<(double, double)> stretches, List<(double, double)> openings);
bool overlaps((double, double) x, (double, double) y);
double? edgeSnap(List<(double, double)> stretches,
    List<(double, double)> otherCuts, double u, double w, double aperture);
bool isValidPiece(List<Vector2> ring);
List<List<Vector2>> piecesOf(HostFrame f, List<(double, double)> merged);
List<List<Vector2>> centrelinePieces(HostFrame f, List<(double, double)> merged);
List<Generated> symbolOf(HostFrame f, OpeningParams o, Cut? cut, Transform2 toOwn);
typedef HostLayout = ({HostFrame frame, List<Obstacle> obstacles, List<(double, double)> stretches});
HostLayout? layoutOf(WorldWall host, List<WorldWall> walls);
HostLayout? layoutInView(ParametricView view, Handle host);
List<(Handle, OpeningParams)> openingsInView(ParametricView view, Handle host);
typedef HostCuts = ({HostLayout layout, List<Handle> openings, List<Cut?> cuts, List<(double, double)> merged});
HostCuts? hostCutsInView(ParametricView view, Handle host);
HostFrame? hostFrameInDocument(DraftDocument doc, Handle host, LiveTypeOf live);
HostLayout? layoutInDocument(DraftDocument doc, Handle host, LiveTypeOf live,
    {Map<Handle, WorldWall> moved = const {}});
List<(Handle, OpeningParams)> openingsInDocument(DraftDocument doc, Handle host, LiveTypeOf live);
```

- The kit's barrel gains `export 'src/opening/opening.dart' show HingeEnd, OpeningKind, OpeningParams, SwingSide;` (the Shared interfaces' export list; `OpeningType` and `isOpeningWidth` stay internal).

**Appendix A rows closed:** D-19's opening geometry files: `opening_params_test` (1: OP1), `opening_geometry_test` (9: HF1-HF6, OG5, HF8, HF9), `opening_cut_test` (6: OG1, OG2, OG8, OG9, OR3, OR6), `opening_obstacle_test` (8: OG3, OG4, OG6, OG11 (a)-(d), OD1), `opening_cost_test` (1: RC3), `opening_kink_test` (4 of 7: KJ1, KJ1 (1e-6°), KJ2, KJ6), `opening_symbol_test` (3 of 4: OG7, OG10, OR7). The remaining four cases need the opening's type, grips or tools inside the plan library and are ported in C6 later: `opening_kink_test` KJ4 and KJ5 and `opening_symbol_test` OR8 in Task 14, KJ3 in Task 15 (ruling R13-3). 32 of the opening's 85 cases here.

**Plan rulings (this task):**
- **R13-1 (C1.5, the document adapter's live rule).** Today's document adapters ask the global catalog (`live_objects.dart`: `isLiveObject`, `liveObjectsOf`). In the kit they take a `LiveTypeOf` (the plan's `PlanServices.liveTypeIdOf` through `liveTypesOf`, or a test's): a handle is a live wall when `live(h) == ArchitectureTypes.wall`, a live opening when `live(h) == ArchitectureTypes.opening`, and the candidates are `doc.components.withComponent<T>()` (ascending by contract, as `ParametricCatalog.objectsOf` reads them). A frozen object (`live(h) == null`) is then absent from the adapters exactly as it is from `generate` (spec C1.5). The view adapter (`wallsInView`, `openingsInView`, `hostCutsInView`) reads the engine's view and needs no live answer: a view relates live objects only.
- **R13-2 (C7, placement).** Every case ported here uses only the kit's, the engine's and the Flutter layer's names (`SpatialIndex.pickInto` in OG8, `FlutterTextMeasurer` in the kink fixture): all run in the kit.
- **R13-3 (order).** KJ3 (the Window tool on the canvas), KJ4 (a window's slide grip on the canvas), KJ5 (a wall end grip on the canvas) and OR8 (a click selecting a gap on the canvas) pump today's `PlannerShell`: they are C6 cases and need the opening's `PlanType` (Task 14) or its tools (Task 15) in `architectureKit`. They are not ported here, and not dropped: Tasks 14 and 15 port them, assertions unchanged.
- **R13-4 (the cut lives in the wall).** Today the wall's `generate` reads its openings as referrers through `hostCutsInView` (`opening_geometry.dart:645-653, :677-697`, called from `wall.dart:226-239`). Task 11 cannot name `opening_geometry.dart` (it does not exist yet), so its `WallType.generate` is today's without the `_cut` branch (see "Interface problem"); this task adds the branch back, unchanged, so a wall with openings is cut from here on.
- **R13-5 (kit tests' system).** Today's tests regenerate through the floor planner's global catalog (`wallDoc`, `reload`, `driftOf`, `diagnosticsOf`, `installParametric`). The kit's tests use `testCatalog()` (the raw kit types, no plan guard), as Task 11's support does; a test that called `installParametric(doc)` keeps the call, now `test/support/catalog.dart`'s over `testCatalog()` (R-P13; re-exported by both fixtures).

- [ ] **Step 1: Precondition.** Tasks 9-12 are committed. Run, from the worktree root:
  - `grep -n "wallsInView\|wallsInDocument" packages/jet_cad_2d_kit_architecture/lib/src/wall/*.dart` — expected: both defined in `wall_geometry.dart`, `wallsInDocument` with the signature `wallsInDocument(DraftDocument doc, Handle host, LiveTypeOf live, {Map<Handle, WorldWall> moved = const {}})`.
  - `grep -n "hostCutsInView\|_cut" packages/jet_cad_2d_kit_architecture/lib/src/wall/wall.dart` — expected: no match (Task 11's `generate` has no cut).
  - `grep -n "testCatalog\|register<" packages/jet_cad_2d_kit_architecture/test/support/catalog.dart` — expected: `ParametricCatalog testCatalog()` and `_testCatalog`'s cascade, registering `BoxParams` then `WallParams` (R-P13).
  - `cd packages/jet_cad_2d_kit_architecture && flutter test` — `All tests passed!`.

  Any other result is a finding: stop and report it (the "Interface problem" below names what this task assumes and why).

- [ ] **Step 2: The test catalog registers the opening.** In `test/support/catalog.dart` (R-P13), after the `..register<WallParams>(...)` line of `_testCatalog`'s cascade, add (today's order, `jet_cad_floor_plan/lib/src/parametric/catalog.dart:32-33`):

```dart
  ..register<OpeningParams>(OpeningParams.componentTypeId,
      OpeningParams.fromJson, const OpeningType())
```

  and the import `import 'package:jet_cad_2d_kit_architecture/src/opening/opening.dart';`. (It does not compile until Step 5.)

- [ ] **Step 3: The failing new test.** Create `test/opening/opening_live_test.dart`:

```dart
// Spec 3a C1.5, C3.3: the opening's document adapters ask the live answer
// they are handed (the plan's `PlanServices.liveTypeIdOf`), never a catalog
// of their own. A wall the plan has frozen (spec 2a E2) is neither a host
// nor an obstacle there, and a frozen opening is not among its host's
// openings, while the catalog still names both, exactly as `generate`,
// which sees no frozen object, draws them.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit_architecture/src/ids.dart';
import 'package:jet_cad_2d_kit_architecture/src/opening/opening.dart';
import 'package:jet_cad_2d_kit_architecture/src/opening/opening_geometry.dart';
import 'package:jet_cad_2d_kit_architecture/src/wall/wall.dart';
import 'package:jet_cad_2d_kit_architecture/src/wall/wall_geometry.dart'
    show wallsInDocument;

import '../support/opening_fixture.dart';
import '../support/wall_fixture.dart';

const hA = Handle(1000), hX = Handle(1200);
const hO = Handle(5000), hP = Handle(5100);

void main() {
  test(
      'OG-live (spec 3a C1.5) a frozen crossing wall is no obstacle, a '
      'frozen host has no frame or layout, a frozen opening is not among '
      'its host\'s openings; the catalog names all three', () {
    final doc = wallDoc();
    // A: 4,000 left-justified, at 23 degrees in its own rotated group at
    // the far origin. X crosses it at about 1,900 (an X obstacle, 08 D7).
    doc.commands.execute(
        addWall(doc, hA, plan(0, 0), plan(4000, 0), 200, Justification.left));
    final fa = oracleFrameOf(doc, hA);
    doc.commands.execute(addWall(doc, hX, oracleAt(fa, 1800, -900),
        oracleAt(fa, 1950, 900), 150, Justification.centre));
    // O, a door at 700, and P, a window at 3,200: both on A, both fit.
    doc.commands.execute(addOpening(
        doc, hO, const OpeningParams(hA, 700, 800, OpeningKind.door)));
    doc.commands.execute(addOpening(
        doc, hP, const OpeningParams(hA, 3200, 600, OpeningKind.window)));
    expect(driftOf(doc), isEmpty, reason: 'premise: regenerated');

    final live = liveOf(doc);
    // Control: X is A's one obstacle; O and P are A's openings.
    expect([for (final o in layoutInDocument(doc, hA, live)!.obstacles) o.wall],
        [hX]);
    expect([for (final (h, _) in openingsInDocument(doc, hA, live)) h],
        [hO, hP]);

    // X frozen: no obstacle; A's one stretch is its straight span.
    final noX = liveOf(doc, frozen: {hX});
    expect(testCatalog().typeIdOf(doc, hX), ArchitectureTypes.wall,
        reason: 'the catalog still names it');
    expect([for (final w in wallsInDocument(doc, hA, noX)!.walls) w.handle],
        isNot(contains(hX)));
    final layout = layoutInDocument(doc, hA, noX)!;
    expect(layout.obstacles, isEmpty);
    expect(layout.stretches, [(layout.frame.uS, layout.frame.uE)]);

    // A frozen: no host, no frame, no layout.
    final noA = liveOf(doc, frozen: {hA});
    expect(testCatalog().typeIdOf(doc, hA), ArchitectureTypes.wall);
    expect(wallsInDocument(doc, hA, noA), isNull);
    expect(hostFrameInDocument(doc, hA, noA), isNull);
    expect(layoutInDocument(doc, hA, noA), isNull);
    expect(hostFrameInDocument(doc, hA, live), isNotNull, reason: 'control');

    // O frozen: P alone is A's.
    final noO = liveOf(doc, frozen: {hO});
    expect(testCatalog().typeIdOf(doc, hO), ArchitectureTypes.opening);
    expect([for (final (h, _) in openingsInDocument(doc, hA, noO)) h], [hP]);
  });
}
```

- [ ] **Step 4: The ported tests and their support.** Every file below keeps its cases' names, order and assertions (A12); only imports, ids (C7 class 1) and fixtures change, as listed. Each ported file starts with a header line `// Ported from jet_cad_floor_plan/test/<file> (spec 3a C3.3, C7).` above today's header comment, which is kept.

  The adaptation that applies to every file (call it **A13-imports**): `package:jet_cad_floor_plan/src/parametric/opening.dart` → `package:jet_cad_2d_kit_architecture/src/opening/opening.dart`; `…/opening_geometry.dart` → `…/src/opening/opening_geometry.dart`; `…/wall.dart` → `…/src/wall/wall.dart`; `…/wall_geometry.dart` → `…/src/wall/wall_geometry.dart`; `…/box.dart` → `…/src/box/box.dart`; `…/catalog.dart` removed; `'support/opening_fixture.dart'` → `'../support/opening_fixture.dart'`; `'support/wall_fixture.dart'` → `'../support/wall_fixture.dart'`. A `show` list is kept as it is, except that `wallsInView` and `wallsInDocument` are imported from `wall_geometry.dart` (where they live since Task 11). And (**A13-live**): every call of a document adapter gains the live answer as its third argument: `wallsInDocument(doc, h)` → `wallsInDocument(doc, h, liveOf(doc))`, `hostFrameInDocument(doc, h)` → `hostFrameInDocument(doc, h, liveOf(doc))`, `layoutInDocument(doc, h, moved: m)` → `layoutInDocument(doc, h, liveOf(doc), moved: m)`, `openingsInDocument(doc, h)` → `openingsInDocument(doc, h, liveOf(doc))`.

  1. `test/support/opening_fixture.dart`: copy `jet_cad_floor_plan/test/support/opening_fixture.dart:1-960` with A13-imports (its lines 14-17: `opening.dart`, `wall.dart`, `wall_geometry.dart show isSimpleCcw`, all from the kit's `src/`), plus, after its `import 'wall_fixture.dart';` (today's :22), the line `export 'wall_fixture.dart' show installParametric, liveOf, testCatalog;` (R-P13 for the catalog; R-P17: the kit tests' live reader is Task 11's `liveOf(doc, {frozen})` in `wall_fixture.dart`, `PlanServices.liveTypeIdOf` over `testCatalog()`; re-exported so a test importing only this fixture reaches it, and no second definition clashes with it).

     Nothing else changes: the oracles never call the geometry (Ruling 08-9), and `randomOpeningPlan` builds on `wallDoc`.
  2. `test/opening/opening_params_test.dart` ← `opening_params_test.dart` (OP1). A13-imports. C7 class 1: `:28` becomes `expect(door.typeId, 'architecture.opening');` and `:29` becomes `expect(OpeningParams.componentTypeId, 'architecture.opening');`. No other line changes.
  3. `test/opening/opening_geometry_test.dart` ← `opening_geometry_test.dart` (HF1, HF2, HF3, HF4, HF5, HF6, OG5, HF8, HF9). A13-imports; A13-live at `:395`, `:409`, `:458-460`, `:462`, `:464`, `:471`. Assertions unchanged: HF9's stray `WallParams` (on a nested group, on a handle with no node) answer null from `liveOf(doc)` (`testCatalog().typeIdOf` names no object there), so they are neither hosts nor obstacles, as today.
  4. `test/opening/opening_cut_test.dart` ← `opening_cut_test.dart` (OG1, OG2, OG8, OG9, OR3, OR6). A13-imports. Assertions unchanged.
  5. `test/opening/opening_kink_test.dart` ← `opening_kink_test.dart`: KJ1 (`:162`), KJ1 1e-6° (`:207`), KJ2 (`:231`), KJ6 (`:380`). A13-imports, minus `planner_shell.dart`, `planner_view.dart`, `catalog.dart`, `package:flutter/gestures.dart`, `package:flutter/material.dart`, `package:flutter/services.dart`, `dart:math` and `package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart` (the last two are used only by the shell section, `:85` `FlutterTextMeasurer` and `:156-158` `math.atan2`/`math.pi`; left in, `unused_import: error` fails the analyzer); copy `:1-74` (header, constants, `addKink`, `localPieces`, `reports`, `nofit`, `expectWellFormed`) and the four cases; the shell section `:75-160` (`_scale`, `_gridStep`, `shellDoc`, `pumpShell`, `globalOf`, `tapWorld`, `dragWorld`, `objectGripsOf`, `gridOf`, `bendOf`) is used only by KJ3-KJ5 and is not copied here (Tasks 14 and 15 rebuild it over the plan's editor). A13-live at `:182`, `:215`. Assertions unchanged. A helper the four cases no longer use is dropped (`flutter analyze` reports an unused top-level declaration). KJ3, KJ4, KJ5: R13-3.
  6. `test/opening/opening_obstacle_test.dart` ← `opening_obstacle_test.dart` (OG3, OG4, OG6, OG11 (a), (b), (c), OD1, OG11 (d)). A13-imports (`box.dart` from the kit's `src/box/`). Assertions unchanged: OD1's box host is a live object of `testCatalog`, so the opening is accepted and reported `opening.orphan`, as today.
  7. `test/opening/opening_cost_test.dart` ← `opening_cost_test.dart` (RC3, printed, not asserted). A13-imports.
  8. `test/opening/opening_symbol_test.dart` ← `opening_symbol_test.dart`: OG7 (`:64`), OG10 (`:181`), OR7 (`:287`) and the file's helpers `:26-62` (`offsetOf` among them). A13-imports, minus `planner_shell.dart`, `planner_view.dart`, `catalog.dart`, `package:flutter/gestures.dart`, `package:flutter/material.dart`, `dart:math` and `package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart` (all OR8's: `:355` `FlutterTextMeasurer`, `:460-461` `math.min`/`math.max`; nothing in `:1-347` uses them, and `unused_import` is an error in the kit's analysis options). Assertions unchanged. OR8: R13-3.

  Write these files byte for byte from their sources apart from the listed lines; check every non-ASCII literal (`'—'`, `'°'`, `'×'`, `'₁'`, `'²'` in names and reasons) with `grep -n` against the source after writing (Global Constraints).

- [ ] **Step 5: Run them: they fail.** `cd packages/jet_cad_2d_kit_architecture && flutter test test/opening/`. Expected: compilation errors, `Error when reading 'lib/src/opening/opening.dart': No such file or directory` (and the same for `opening_geometry.dart`), for every file of `test/opening/`.

- [ ] **Step 6: Port `opening.dart`.** Create `lib/src/opening/opening.dart` from `jet_cad_floor_plan/lib/src/parametric/opening.dart`:
  - Lines 1-3 (the header comment) become:

```dart
// Openings hosted in walls (spec 08 D1, D6): their parameters. No Flutter
// import. The geometry they are drawn and cut with is pure Dart, in
// `opening_geometry.dart`. Ported from jet_cad_floor_plan's
// lib/src/parametric/opening.dart (spec 3a C3.3): only the type id changes.
```

  - Line 4 unchanged; lines 6-7 become:

```dart
import '../ids.dart';
import '../wall/wall.dart';
import 'opening_geometry.dart';
```

  - Line 37 becomes `  static const String componentTypeId = ArchitectureTypes.opening;`
  - Copy lines 8-36 and 38-270 unchanged (the enums, `OpeningParams`, `OpeningType` with `reach`, `references`, `generate`, `diagnose`, and `isOpeningWidth`).

- [ ] **Step 7: Port `opening_geometry.dart`.** Create `lib/src/opening/opening_geometry.dart` from `jet_cad_floor_plan/lib/src/parametric/opening_geometry.dart`:
  - Copy lines 1-19 unchanged, then add a line after line 13: `// Ported from jet_cad_floor_plan's lib/src/parametric/opening_geometry.dart (spec 3a C3.3): the document adapter asks the plan's live answer (C1.5).`
  - Lines 20-23 (`live_objects.dart`, `opening.dart`, `wall.dart`, `wall_geometry.dart`) become:

```dart
import '../ids.dart';
import '../live.dart';
import '../wall/wall.dart';
import '../wall/wall_geometry.dart';
import 'opening.dart';
```

  - Copy lines 24-599 unchanged (`HostFrame` to `symbolOf`).
  - Lines 600-616 (`wallsInView`): not copied; it lives in `wall_geometry.dart` since Task 11 (the "Interface problem"), imported above.
  - Copy lines 617-698 unchanged (`HostLayout`, `layoutOf`, `layoutInView`, `openingsInView`, `HostCuts`, `_hostCutsByView`, `hostCutsInView`, `_hostCuts`).
  - Lines 699-727 (`wallsInDocument`): not copied (Task 11's, in `wall_geometry.dart`, over the same `LiveTypeOf`).
  - Lines 729-756 become:

```dart
/// [host]'s frame through the document adapter (`wallsInDocument`, over
/// [live], spec 3a C1.5). Null when [host] is not a live wall or is
/// degenerate.
HostFrame? hostFrameInDocument(
    DraftDocument doc, Handle host, LiveTypeOf live) {
  final w = wallsInDocument(doc, host, live);
  return w == null ? null : hostFrameOf(w.host, w.walls);
}

/// [host]'s layout (frame, obstacles, stretches) through the document
/// adapter (`wallsInDocument`, over [live], with [moved] standing in for
/// the walls it names). Null when [host] is not a live wall or is
/// degenerate.
HostLayout? layoutInDocument(DraftDocument doc, Handle host, LiveTypeOf live,
    {Map<Handle, WorldWall> moved = const {}}) {
  final w = wallsInDocument(doc, host, live, moved: moved);
  return w == null ? null : layoutOf(w.host, w.walls);
}

/// [host]'s openings in [doc]: the live openings ([live] names them
/// `ArchitectureTypes.opening`; a frozen one is not live, spec 3a C1.5)
/// whose host is [host], ascending by handle, with their parameters, as
/// [openingsInView] reads them in a regeneration.
List<(Handle, OpeningParams)> openingsInDocument(
        DraftDocument doc, Handle host, LiveTypeOf live) =>
    [
      for (final h in doc.components.withComponent<OpeningParams>())
        if (live(h) == ArchitectureTypes.opening)
          if (doc.components.get<OpeningParams>(h)! case final o
              when o.host == host)
            (h, o),
    ];
```

- [ ] **Step 8: The wall is cut by its openings (R13-4).** In `lib/src/wall/wall.dart`:
  - add `import '../opening/opening_geometry.dart' show centrelinePieces, hostCutsInView, piecesOf;` to the imports;
  - replace `WallType.generate` (its doc comment and body, as Task 11 left them) with today's `jet_cad_floor_plan/lib/src/parametric/wall.dart:191-213` unchanged (the doc ends "A wall with fitting cuts generates [_cut]'s pieces instead."; the body's first statement is `if (_cut(view, self) case final pieces?) return pieces;`);
  - insert today's `wall.dart:215-239` (`/// [self] split at its openings …` and `static List<Generated>? _cut(ParametricView view, Handle self)`) unchanged right after it.

  `wall.dart` and `opening_geometry.dart` now import each other, as today's do (Dart allows it; neither has a top-level initialiser that reads the other).

- [ ] **Step 9: The barrel.** In `lib/jet_cad_2d_kit_architecture.dart`, add, in the export list's order of the Shared interfaces (after the wall's export):

```dart
export 'src/opening/opening.dart'
    show HingeEnd, OpeningKind, OpeningParams, SwingSide;
```

- [ ] **Step 10: Run them: they pass.** `cd packages/jet_cad_2d_kit_architecture && dart format . && flutter test test/opening/`. Expected: `All tests passed!` (RC3 prints its timings). Then `flutter test` (the whole kit, Task 11's and 12's wall tests included): `All tests passed!`. A wall test that now sees a cut it did not expect is a finding: stop and report it.

- [ ] **Step 11: The gates.** From the worktree root:
  - `cd packages/jet_cad_2d_kit_architecture && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` — `All tests passed!`, `No issues found!`, exit 0.
  - `dart run tool/ci/check_kit_deps.dart` — exit 0 (the kit names neither the plan library nor another kit; `test/` included).
  - `git status --short` — only this task's files.

- [ ] **Step 12: Commit.**

```bash
git add packages/jet_cad_2d_kit_architecture/lib/jet_cad_2d_kit_architecture.dart packages/jet_cad_2d_kit_architecture/lib/src/opening/opening.dart packages/jet_cad_2d_kit_architecture/lib/src/opening/opening_geometry.dart packages/jet_cad_2d_kit_architecture/lib/src/wall/wall.dart packages/jet_cad_2d_kit_architecture/test/support/catalog.dart packages/jet_cad_2d_kit_architecture/test/support/opening_fixture.dart packages/jet_cad_2d_kit_architecture/test/opening/opening_live_test.dart packages/jet_cad_2d_kit_architecture/test/opening/opening_params_test.dart packages/jet_cad_2d_kit_architecture/test/opening/opening_geometry_test.dart packages/jet_cad_2d_kit_architecture/test/opening/opening_cut_test.dart packages/jet_cad_2d_kit_architecture/test/opening/opening_kink_test.dart packages/jet_cad_2d_kit_architecture/test/opening/opening_obstacle_test.dart packages/jet_cad_2d_kit_architecture/test/opening/opening_cost_test.dart packages/jet_cad_2d_kit_architecture/test/opening/opening_symbol_test.dart
git commit -m "$(cat <<'EOF'
feat(architecture): opening parameters, geometry and the wall's cut (spec 3a C3.3)

Ports the opening's parameters, the host frame, obstacles, stretches,
cuts, pieces and symbols into the kit, renamed architecture.opening.
The document adapters ask the plan's live answer, so a frozen wall is
neither host nor obstacle and a frozen opening is not its host's (C1.5).
The wall's generate is cut by its openings again. 32 of the opening's
85 cases ported; KJ3-KJ5 and OR8 follow with the type and the tools.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 13: Mutation check** (committed files only; after each: run the named test with `cd packages/jet_cad_2d_kit_architecture && flutter test <file>`, see it red, then `git checkout -- <file>` and `git diff --quiet -- <file>` must exit 0). Quote each red line.
  - M-OG-1 `lib/src/opening/opening.dart`: `componentTypeId = ArchitectureTypes.opening` → `componentTypeId = 'floor_planner.opening'` → OP1 red (`test/opening/opening_params_test.dart`).
  - M-OG-2 `lib/src/opening/opening_geometry.dart`: in `hostFrameInDocument`, `wallsInDocument(doc, host, live)` → `wallsInDocument(doc, host, (h) => ArchitectureTypes.wall)` → OG-live red (A frozen still has a frame).
  - M-OG-3 `opening_geometry.dart`: in `layoutInDocument`, `wallsInDocument(doc, host, live, moved: moved)` → `wallsInDocument(doc, host, (h) => h == host ? live(h) : ArchitectureTypes.wall, moved: moved)` → OG-live red (X frozen is still an obstacle).
  - M-OG-4 `opening_geometry.dart`: in `openingsInDocument`, delete the line `if (live(h) == ArchitectureTypes.opening)` → OG-live red (O frozen still listed).
  - M-OG-5 `lib/src/wall/wall_geometry.dart` (Task 11's adapter): in `wallsInDocument`'s walls list, delete `&& live(h) == ArchitectureTypes.wall` → OG-live red and HF9 red (`test/opening/opening_geometry_test.dart`: the nested and node-less strays become obstacles).
  - M-OG-6 `lib/src/wall/wall.dart`: delete `if (_cut(view, self) case final pieces?) return pieces;` → OG1 red (`test/opening/opening_cut_test.dart`: the wall is uncut) and OR3 red.
  - M-OG-7 `opening_geometry.dart`: in `placeCut`, `if (distance < bestDistance)` → `if (distance <= bestDistance)` → HF6 red (`test/opening/opening_geometry_test.dart`: a tie goes to the higher `a`).
  - M-OG-8 `opening_geometry.dart`: in `cutsOf`, `if (pieces.isEmpty || !pieces.every(ok))` → `if (pieces.isEmpty)` → KJ1 (1e-6°) red (`test/opening/opening_kink_test.dart`).

#### Assumed from earlier tasks

- Task 9: `lib/src/ids.dart` (`ArchitectureTypes`), `lib/src/live.dart` (`LiveTypeOf`), the barrel `lib/jet_cad_2d_kit_architecture.dart` with one `export … show …` line per type file.
- Task 10: `lib/src/box/box.dart` (`BoxParams`, `BoxType`), registered first in `testCatalog`.
- Task 11: the files and names in "Consumes", `wallsInView` and `wallsInDocument` in `wall_geometry.dart` as the "Interface problem" proposes, `WallType.generate` without the cut, and the kit test support `test/support/wall_fixture.dart` with today's names and `testCatalog` ("New shared name").

#### Interface problem

(Resolved by R-P8 and R-P17: Task 11 puts both adapters in `wall_geometry.dart` with the positional `LiveTypeOf`, exactly as proposed below; kept for the record, do not stop on it.)

**The wall, the opening, the room inputs and the dimension import each other today; the plan's file order splits them across Tasks 11, 13, 14 and 16.** Evidence:
- `jet_cad_floor_plan/lib/src/parametric/wall.dart:4-6` imports `opening_geometry.dart` (`wallsInView` for every wall's outline at `:150`, `hostCutsInView`, `piecesOf`, `centrelinePieces` for the cut at `:226-239`) and `room_inputs.dart` (`placeBoxInView`, `roomInputInView` at `:178-187`).
- `wall_grips.dart:5-9` imports `opening.dart` and `opening_geometry.dart` (`wallsInDocument` for the grips at `:52` and `:159`; `layoutInDocument`, `placeCut`, `storedCentreOf` and `liveObjectsOf<OpeningParams>` for 08 D13's "openings stay put", `:71-131`).
- `dimension.dart:21`, `dimension_grips.dart:9`, `dimension_attach.dart:12-13`, `dimension_tool.dart:17`, `room_inputs.dart:13` and `symbols/wall_attach.dart:59-117` import `wallsInView`/`wallsInDocument` from `opening_geometry.dart`.

Proposed resolution, written into this task and Task 14 (the controller reconciles it with Tasks 11, 12 and 16):
1. **Task 11** puts the two wall adapters in `lib/src/wall/wall_geometry.dart`: `wallsInView` copied from `opening_geometry.dart:600-616` unchanged, and

```dart
/// The walls the tools, the grips and the panel see around [host] (the
/// document adapter, Ruling 08-8): [host] as a [WorldWall], and every other
/// live wall of [doc] ([live] names it `ArchitectureTypes.wall`; a frozen
/// one is not live, spec 3a C1.5), ascending by handle. Null when [host] is
/// not a live wall. [moved] stands in for the walls it names.
({WorldWall host, List<WorldWall> walls})? wallsInDocument(
    DraftDocument doc, Handle host, LiveTypeOf live,
    {Map<Handle, WorldWall> moved = const {}}) {
  if (live(host) != ArchitectureTypes.wall) return null;
  final p = doc.components.get<WallParams>(host)!;
  return (
    host:
        moved[host] ?? WorldWall(host, p, doc.tree.accumulatedTransform(host)),
    walls: [
      for (final h in doc.components.withComponent<WallParams>())
        if (h != host && live(h) == ArchitectureTypes.wall)
          moved[h] ??
              WorldWall(h, doc.components.get<WallParams>(h)!,
                  doc.tree.accumulatedTransform(h)),
    ],
  );
}
```

   and ports `WallType.generate` without the `_cut` branch (a wall draws uncut until Task 13; Task 11's wall tests have no openings). Its place hooks (`room_inputs.dart`) are Task 16's question, not this task's.
2. **Task 12** ports `WallGrips` without 08 D13's `_keptPut`/`_seated` (they name `OpeningParams`), taking the live answer as `WallGrips({required LiveTypeOf live})`; its `wall_grips_test` cases that build openings (EG9 and the like) wait for Task 14, which adds `_keptPut` with `opening_end_drag_test`.
3. **Task 13** (this task) adds the cut to `WallType.generate`; **Task 14** adds `_keptPut`/`_seated` to `WallGrips.drag`.

If Task 11 places the adapters elsewhere, only this task's imports (Steps 3, 4, 7) and M-OG-5's file change.

#### New shared name

- **`testCatalog`** — settled by ruling R-P13: `ParametricCatalog testCatalog()` and `installParametric(doc)` in `packages/jet_cad_2d_kit_architecture/test/support/catalog.dart` (Task 10), re-exported by Task 11's `wall_fixture.dart`; the kit's raw types in today's order (`jet_cad_floor_plan/lib/src/parametric/catalog.dart:27-39`): Task 13 the opening after the wall, Task 16 the separator, Task 18 the room, Task 20 the dimension.
- **`liveOf`** — settled by ruling R-P17: Task 11's `LiveTypeOf liveOf(DraftDocument doc, {Set<Handle> frozen = const {}})` in `test/support/wall_fixture.dart`; `opening_fixture.dart` re-exports it (`export 'wall_fixture.dart' show liveOf;`). Tasks 14-16, 20-22 and 24's kit tests use it for the document adapters.

---

