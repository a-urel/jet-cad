### Task 11: Wall geometry, bands and parameters (spec C3.2, C2 "Shared caches", C1.5; R-P8)

**Files:**
- Create (`packages/jet_cad_2d_kit_architecture/`): `lib/src/wall/wall.dart` (ported), `lib/src/wall/wall_geometry.dart` (ported, plus the two wall adapters), `lib/src/wall/wall_bands.dart` (ported, plus `wallBandsOf`), `test/support/wall_fixture.dart` (ported), `test/wall/wall_params_test.dart`, `test/wall/wall_geometry_test.dart`, `test/wall/wall_bands_test.dart`, `test/wall/wall_regen_test.dart` (ported), `test/wall/wall_live_test.dart` (new, WL1-WL3)
- Modify (`packages/jet_cad_2d_kit_architecture/`): `test/support/catalog.dart` (Task 10's: the wall's registration appended, R-P13)
- Nothing in `lib/jet_cad_2d_kit_architecture.dart`: `WallParams` and `Justification` are exported in Task 12 with the wall's plan type (the barrel's list in "Shared interfaces"), so the barrel never names a file before it is wired into the kit.

**Interfaces:**
- Consumes:
  - Task 9: `ArchitectureTypes.wall` (`lib/src/ids.dart`); `typedef LiveTypeOf = String? Function(Handle handle)`, `LiveTypeOf liveTypesOf(PlanServices services)` and `List<Handle> liveObjectsOf<T extends Component>(DraftDocument document, LiveTypeOf live, String typeId)` (`lib/src/live.dart`).
  - Task 10: `test/support/catalog.dart` (`ParametricCatalog testCatalog()`, `ParametricSystem installParametric(DraftDocument doc)`), `BoxParams`, `BoxType` (`lib/src/box/box.dart`, today's names, `BoxParams.componentTypeId == ArchitectureTypes.box`).
  - Task 6: `PlanServices.liveTypeIdOf`; `package:jet_cad_2d_kit/testing.dart`'s `FakePlanServices({required DraftDocument document, ParametricCatalog? catalog, Set<Handle> frozen, ...})` and its `dispose()` (shared objects that are `Disposable` disposed).
  - The contract: `Disposable`, `PlanServices.shared` (`jet_cad_2d_kit/lib/src/kit/plan_services.dart:48-52, :110-114`).
  - The engine: `ParametricType`, `ParametricView` (`paramsOf`, `toWorld`, `neighbours`), `ComponentRegistry.withComponent` (ascending), `DocChange`.
- Produces (internal to the kit; every later type task consumes them, see "New shared name"):

```dart
// lib/src/wall/wall.dart — today's wall.dart:1-286 with R-P8's split
enum Justification { left, centre, right }
const Tolerance wallJoin;  const double kWallMaxThickness;  bool isWallThickness(double t);
const double mitreLimit;  const DraftColor kWallColor;
final class WallParams implements Component { /* today's; componentTypeId = ArchitectureTypes.wall */ }
final class WallType extends ParametricType<WallParams> { /* no cut, no place hooks until Tasks 13, 16 */ }
// lib/src/wall/wall_geometry.dart — today's wall_geometry.dart:1-623, plus:
({WorldWall host, List<WorldWall> walls})? wallsInView(ParametricView view, Handle host);
({WorldWall host, List<WorldWall> walls})? wallsInDocument(
    DraftDocument doc, Handle host, LiveTypeOf live,
    {Map<Handle, WorldWall> moved = const {}});
// lib/src/wall/wall_bands.dart
WallBands wallBandsOf(PlanServices services);   // services.shared(...): Shared interfaces
final class WallBands implements Disposable {
  WallBands(LiveTypeOf live);                   // today's members unchanged:
  int get generation; void invalidate(); List<Handle> liveWalls(DraftDocument doc);
  Handle? hostAt(DraftDocument doc, double x, double y,
      {bool Function(DraftDocument, Handle)? accept});
  bool joinInto(DraftDocument doc, double px, double py, Vector2 out);
  @override void dispose();
}
// test/support/wall_fixture.dart (kit) — today's helpers, re-exporting catalog.dart, plus:
LiveTypeOf liveOf(DraftDocument doc, {Set<Handle> frozen = const {}});
```

**Appendix A rows closed:** D-19's wall part, partly: `wall_params_test.dart` (WP1-WP5), `wall_geometry_test.dart` (WG1-WG21), `wall_bands_test.dart` (WB1, WB2) and `wall_regen_test.dart` (WR1-WR13; WR9's sample-plan line carried to Task 25, below) are ported here, all in the kit. The other wall files (`wall_grips`, `wall_paint`, `wall_tool`) are Task 12's.

Plan decisions (R-P8, spec C1.5, C2):
- **The split.** Today's `wall.dart` imports `opening_geometry.dart` (for `wallsInView`, `hostCutsInView`, `piecesOf`, `centrelinePieces`: `wall.dart:4, :150, :226-238`) and `room_inputs.dart` (`placeBoxInView`, `roomInputInView`: `wall.dart:5, :172-189`). Neither exists before Tasks 13 and 16. So this task's `WallType` has **no cut** (`wall.dart:199` and `:203`'s `_cut` line, `:215-238`'s `_cut`) and **no place hooks** (`:172-189`: `contributesPlace`, `placeBox`, `placeInput`); Task 13 adds the cut back, Task 16 the place hooks, each from today's lines. Until then a wall regenerates exactly as today's wall with no opening and no room reading it: none of this task's ported cases builds an opening or a room (checked: the four files import only `wall.dart`, `wall_geometry.dart`, `wall_bands.dart`, `box.dart`, `catalog.dart` and `startup_plan.dart`, the last for WR9's sample line only).
- **The two adapters live with the wall.** `wallsInView` (today `opening_geometry.dart:600-616`) and `wallsInDocument` (`:698-725`) read only walls; the wall's own outline (`wall.dart:148-152`) and grips (Task 12) need them before the opening lands. They move into `wall_geometry.dart`; Task 13 does not copy them again (its R13-1 says so). `wallsInDocument` takes the live answer as a positional `LiveTypeOf` (R-P8; Task 13's text), and asks it for the host and for every other holder: today's `isLiveObject<WallParams>`/`liveObjectsOf<WallParams>` over the global catalog (`opening_geometry.dart:714, :720`) become `live(h) == ArchitectureTypes.wall`, so a frozen wall is no wall (C1.5).
- **`WallBands` keeps today's invalidation exactly** (C2): the document's `changes` stream and explicit `invalidate()` (`wall_bands.dart:22-49, :136-143`), one subscription per document. What changes: the constructor takes a `LiveTypeOf` (today's `liveObjectsOf<WallParams>(doc)`, `:153`, becomes Task 9's `liveObjectsOf<WallParams>(doc, _live, ArchitectureTypes.wall)`), it `implements Disposable` so `PlanServices.shared` disposes it with its document, and `wallBandsOf(services)` is the kit's one instance per document (the wall tool, the opening tools and the wall faces share it, as today's shell shared `_bands`, `planner_shell.dart:460-492`).
- **The test catalog** is Task 10's `test/support/catalog.dart` (R-P13); this task appends the wall's line in today's order (`catalog.dart:27-31`: box, then wall). `wall_fixture.dart` re-exports `testCatalog` and `installParametric`, so a ported file changes only its imports. `liveOf(doc, {frozen})` is new in the fixture: `PlanServices.liveTypeIdOf` without a plan (the catalog's type id, null for a frozen handle); Tasks 13 and 14 already call it under this name.
- **Ruling R11-1 (WR9's sample line).** WR9 ends with "the sample plan ... reports none" (`wall_regen_test.dart:497-501`: `startupPlan(measurer)`, its own system, `diagnosticsOf(sample)`). The sample flat is Task 25's `buildSampleFlat`. WR9 lands here without those five lines and with a comment naming Task 25, which restores them (over a document with `installParametric` and `buildSampleFlat(doc, words)`) unchanged in assertion: `expect(diagnosticsOf(sample), isEmpty)`. Every other line of WR9 is unchanged.
- **Purity.** `wall.dart` and `wall_geometry.dart` stay free of Flutter except through `../live.dart`'s typedef (`wall_geometry.dart` imports `show LiveTypeOf` only); the kit has no purity test of its own (2a's purity test is the contract's), so this is a convention, not a gate.

- [ ] **Step 1: Precondition.** Tasks 1-10 are committed. Run, from the repository root:
  - `grep -n "testCatalog\|installParametric\|register<BoxParams>" packages/jet_cad_2d_kit_architecture/test/support/catalog.dart` — expected: the box's registration, `ParametricCatalog testCatalog()`, `ParametricSystem installParametric(DraftDocument doc)` (Task 10).
  - `grep -n "typedef LiveTypeOf\|LiveTypeOf liveTypesOf\|liveObjectsOf" packages/jet_cad_2d_kit_architecture/lib/src/live.dart` — three hits (Task 9).
  - `grep -n "class FakePlanServices\|String? liveTypeIdOf" packages/jet_cad_2d_kit/lib/src/testing/fake_plan_services.dart` — two hits (Task 6).
  - `grep -n "vector_math" packages/jet_cad_2d_kit_architecture/pubspec.yaml` — one hit (R-P11).
  Any miss is a finding: stop and report it.

- [ ] **Step 2: The test support.**
  1. `test/support/catalog.dart`: add `import 'package:jet_cad_2d_kit_architecture/src/wall/wall.dart';` after the box's import, and append the wall's line to `_testCatalog`'s cascade (the instance `testCatalog()` returns), after the box's (today's order, `jet_cad_floor_plan/lib/src/parametric/catalog.dart:28-31`):

```dart
  ..register<WallParams>(
      WallParams.componentTypeId, WallParams.fromJson, const WallType());
```

  2. Create `test/support/wall_fixture.dart`: **copy `packages/jet_cad_floor_plan/test/support/wall_fixture.dart:1-301`**, with these adaptations and nothing else:
     - A header first:

```dart
// Ported from jet_cad_floor_plan/test/support/wall_fixture.dart (3a Task
// 11): the floor planner's catalog becomes the kit tests' (catalog.dart,
// re-exported); `liveOf` is new (spec 3a C1.5).
```

     - Lines 5-9 (the imports after `dart:typed_data`) become:

```dart
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit_architecture/src/live.dart' show LiveTypeOf;
import 'package:jet_cad_2d_kit_architecture/src/wall/wall.dart';
import 'package:jet_cad_2d_kit_architecture/src/wall/wall_geometry.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'catalog.dart';

export 'catalog.dart' show installParametric, testCatalog;
```

     - `:171`'s doc comment: `/// An empty document with the kit tests' parametric system installed.` (the body, `installParametric(doc)`, is unchanged: catalog.dart's). After `wallDoc` (`:176`), insert:

```dart

/// `PlanServices.liveTypeIdOf` over [doc] without a plan: [testCatalog]'s
/// type id, and null for a handle in [frozen] (spec 3a C1.5).
LiveTypeOf liveOf(DraftDocument doc, {Set<Handle> frozen = const {}}) =>
    (h) => frozen.contains(h) ? null : testCatalog().typeIdOf(doc, h);
```

     - `:276-282`: `parametricCatalog` → `testCatalog()` (twice), and the two doc comments' "the floor planner's catalog" → "the kit tests' catalog".
     - `:295-298`: the doc comment → `/// Decodes [s] with the kit tests' factories and installs their system.`; `parametricCatalog.registerComponents` → `testCatalog().registerComponents` (the body's `installParametric(doc)` is catalog.dart's).

- [ ] **Step 3: The ported tests.** Each file is its source, **assertions unchanged** but where named; placed in the kit (C7: every name is the kit's, the engine's or the Flutter layer's). The adaptation common to all four (**A11-imports**): `package:jet_cad_floor_plan/src/parametric/wall.dart` → `package:jet_cad_2d_kit_architecture/src/wall/wall.dart`; `.../wall_geometry.dart` and `.../wall_bands.dart` likewise; `.../box.dart` → `package:jet_cad_2d_kit_architecture/src/box/box.dart`; `'support/wall_fixture.dart'` → `'../support/wall_fixture.dart'`. Add to each file's header (or as its first line when it has none): `// Ported from jet_cad_floor_plan/test/<file> (3a Task 11).`
  1. `test/wall/wall_params_test.dart` ← `wall_params_test.dart:1-101`, WP1-WP5. A11-imports. **C7 class 1 (ids):** WP1's `:19` and `:20` `'floor_planner.wall'` → `'architecture.wall'` (the only changed assertion lines).
  2. `test/wall/wall_geometry_test.dart` ← `wall_geometry_test.dart:1-724`, WG1-WG21. A11-imports only.
  3. `test/wall/wall_bands_test.dart` ← `wall_bands_test.dart:1-96`, WB1, WB2. A11-imports; `:25` and `:76` `final bands = WallBands();` → `final bands = WallBands(liveOf(doc));` (the band cache asks the kit tests' catalog, as today's asked the global one; nothing is frozen).
  4. `test/wall/wall_regen_test.dart` ← `wall_regen_test.dart:1-745`, WR1-WR13. A11-imports; delete the imports `:5` (`catalog.dart`), `:8` (`startup_plan.dart`) and `:11` (`jet_cad_2d_flutter`, used only by WR9's sample line); in WR9 replace `:497-501` with

```dart
    // The sample plan's line (wall_regen_test.dart:497-501) returns with
    // buildSampleFlat in Task 25 (ruling R11-1).
```

     WR10's `BoxParams`/`BoxType` are Task 10's (`ArchitectureTypes.box`); `installParametric`, `driftOf`, `diagnosticsOf`, `reload` are the fixture's.
  Check the non-ASCII literals (the `°` characters of `wall_geometry_test.dart`, 15 lines, and `wall_regen_test.dart`, 12 lines) with `grep -n "°" test/wall/*.dart` against the sources (Global Constraints).

- [ ] **Step 4: The new tests.** Create `test/wall/wall_live_test.dart`:

```dart
// 3a Task 11 (spec C1.5, C2): the walls' caches and the document adapter
// decide "a live wall" through a LiveTypeOf, never through a catalog of
// their own, so a frozen wall is absent from them exactly as it is absent
// from every regeneration. The walls sit at the far origin in their own
// turned groups; the stray WallParams sits on a nested group inside a
// turned and mirrored one.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/testing.dart';
import 'package:jet_cad_2d_kit_architecture/src/wall/wall.dart';
import 'package:jet_cad_2d_kit_architecture/src/wall/wall_bands.dart';
import 'package:jet_cad_2d_kit_architecture/src/wall/wall_geometry.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/wall_fixture.dart';

const Handle a = Handle(1300), b = Handle(2600), f = Handle(3900);
const Handle outer = Handle(5000), nested = Handle(5100);

/// An L of A (200, left) and B (115, centre); F (150, right) apart from it;
/// and a stray `WallParams` from the L's corner on [nested], a group inside
/// the turned and mirrored root group [outer], as only a file brings one.
DraftDocument liveDoc() {
  final doc = wallDoc();
  final corner = plan(1800, 300);
  doc.commands.execute(
      addWall(doc, a, plan(-1200, 300), corner, 200, Justification.left));
  doc.commands.execute(addWall(doc, b, corner, polar(corner, 23 + 105, 2400),
      115, Justification.centre));
  doc.commands.execute(addWall(
      doc, f, plan(-1200, 2300), plan(1800, 2700), 150, Justification.right));
  doc.commands.execute(CompoundCommand([
    AddNodeCommand(GroupNode(
        handle: outer,
        parent: doc.rootHandle,
        transform: Transform2.translation(ox + 640.5, oy - 410.25)
            .multiply(Transform2.rotation(0.7))
            .multiply(Transform2.scale(-1, 1)),
        children: const [])),
    AddNodeCommand(GroupNode(
        handle: nested,
        parent: outer,
        transform: Transform2.translation(-120.5, 330.75)
            .multiply(Transform2.rotation(-0.45)),
        children: const [])),
  ], label: 'Add groups'));
  final toNested = doc.tree.accumulatedTransform(nested).invert();
  final s = toNested.transformPoint(corner);
  final e = toNested.transformPoint(polar(corner, 23 - 40, 1700));
  doc.components.attach<WallParams>(
      nested, WallParams(s.x, s.y, e.x, e.y, 90, Justification.left));
  return doc;
}

/// A point in the middle of [h]'s band, 40% along it.
Vector2 inBand(DraftDocument doc, Handle h) {
  final w = worldWallOf(doc, h);
  final (l, r) = w.offsets;
  return w.s + (w.e - w.s) * 0.4 + Vector2(-w.d.y, w.d.x) * ((l + r) / 2);
}

void main() {
  test(
      'WL1 a frozen wall has no band: the band cache neither hosts nor joins '
      'at it and liveWalls leaves it out; the live walls keep theirs', () {
    final doc = liveDoc();
    final bands = WallBands(liveOf(doc, frozen: {f}));
    addTearDown(bands.dispose);
    expect(bands.liveWalls(doc), [a, b]);
    for (final (h, host) in [(a, a), (b, b), (f, null)]) {
      final p = inBand(doc, h);
      expect(bands.hostAt(doc, p.x, p.y), host, reason: h.toHex());
      final out = Vector2(7, 7);
      expect(bands.joinInto(doc, p.x, p.y, out), host != null,
          reason: h.toHex());
    }
    // The control: nothing frozen, F is a wall with a band.
    final all = WallBands(liveOf(doc));
    addTearDown(all.dispose);
    expect(all.liveWalls(doc), [a, b, f]);
    final p = inBand(doc, f);
    expect(all.hostAt(doc, p.x, p.y), f);
  });

  test(
      'WL2 the document adapter: a frozen wall and a stray WallParams are no '
      "walls and no host's others; a live host sees the live walls, "
      'ascending, bitwise as WorldWall builds them, and moved stands in', () {
    final doc = liveDoc();
    final live = liveOf(doc, frozen: {f});
    expect(
        doc.components.withComponent<WallParams>().toList(), [a, b, f, nested],
        reason: 'premise: four holders of WallParams');
    expect(wallsInDocument(doc, f, live), isNull);
    expect(wallsInDocument(doc, nested, live), isNull);
    final w = wallsInDocument(doc, a, live)!;
    expect(w.host.handle, a);
    expect([for (final o in w.walls) o.handle], [b]);
    final want = worldWallOf(doc, a);
    expect([w.host.s.x, w.host.s.y, w.host.e.x, w.host.e.y],
        [want.s.x, want.s.y, want.e.x, want.e.y]);
    final pb = doc.components.get<WallParams>(b)!;
    final moved = WorldWall(b, pb.copyWith(end: Vector2(-310.5, 920.25)),
        doc.tree.accumulatedTransform(b));
    expect(
        identical(
            wallsInDocument(doc, a, live, moved: {b: moved})!.walls.single,
            moved),
        isTrue);
    // The control: nothing frozen, F is one of A's others.
    expect(
        [for (final o in wallsInDocument(doc, a, liveOf(doc))!.walls) o.handle],
        [b, f]);
  });

  test(
      "WL3 wallBandsOf: the kit's one WallBands per services, over their "
      'live walls (a frozen one has no band), disposed with them: a change '
      'after the dispose no longer reaches it', () async {
    final doc = liveDoc();
    final services =
        FakePlanServices(document: doc, catalog: testCatalog(), frozen: {f});
    final bands = wallBandsOf(services);
    expect(identical(wallBandsOf(services), bands), isTrue);
    expect(bands.liveWalls(doc), [a, b]);
    // The control: a change reaches the live cache.
    final g0 = bands.generation;
    doc.commands.execute(addWall(doc, const Handle(7000), plan(-900, -800),
        plan(2100, -400), 150, Justification.centre));
    await pumpEventQueue();
    expect(bands.generation, greaterThan(g0));
    services.dispose();
    final g1 = bands.generation;
    doc.commands.execute(addWall(doc, const Handle(7100), plan(-900, -1800),
        plan(2100, -1400), 150, Justification.centre));
    await pumpEventQueue();
    expect(bands.generation, g1, reason: 'disposed with its services');
  });
}
```

- [ ] **Step 5: Run the tests, see them fail.** `cd packages/jet_cad_2d_kit_architecture && flutter test test/wall/`. Expected: every file fails to load — `Error when reading 'lib/src/wall/wall.dart': No such file or directory` (and the same for `wall_geometry.dart`, `wall_bands.dart`); the box tests still pass (`flutter test test/box/`).

- [ ] **Step 6: `lib/src/wall/wall.dart`.** **Copy `packages/jet_cad_floor_plan/lib/src/parametric/wall.dart:1-286`**, then:
  1. Lines 4-6 (the relative imports) become:

```dart
import '../ids.dart';
import 'wall_geometry.dart';
```

  2. `:75`: `static const String componentTypeId = 'floor_planner.wall';` → `static const String componentTypeId = ArchitectureTypes.wall;`
  3. Delete `:172-189` (`contributesPlace`, `placeBox`, `placeInput` with their doc comments): Task 16 restores them from these lines (R-P8).
  4. Replace `generate`'s doc comment `:191-199` with:

```dart
  /// 07's path (spec 07 D3): in this order, fixed at creation, the region,
  /// whose outline is [_localOutlineOf] -- computed in world space, taken to
  /// group-local space and checked there -- then the open centreline from
  /// `start` to `end`, the stored values themselves. A degenerate wall (D2)
  /// generates the centreline alone. Every child is [kWallColor].
  ///
  /// The cut at the wall's openings (spec 08 D9) joins in 3a's Task 13.
```

  5. Delete `:203` (`if (_cut(view, self) case final pieces?) return pieces;`) and `:215-239` (`_cut` with its doc comment and the blank line after it): Task 13 restores them (R-P8).
  Lines 7-171 (the enum, `wallJoin`, `kWallMaxThickness`, `isWallThickness`, `mitreLimit`, `kWallColor`, `WallParams`, `_worldWall`, `_localOutlineOf`, `WallType`'s head, `reach`) and `diagnose` (`:240-286`) are unchanged; `_localOutlineOf`'s `wallsInView` now resolves to `wall_geometry.dart`'s.

- [ ] **Step 7: `lib/src/wall/wall_geometry.dart`.** **Copy `packages/jet_cad_floor_plan/lib/src/parametric/wall_geometry.dart:1-623` unchanged**, except its import block `:10-13`, which becomes

```dart
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../ids.dart';
import '../live.dart' show LiveTypeOf;
import 'wall.dart';
```

  and append the two adapters (new code: `wallsInView` is `opening_geometry.dart:600-616` verbatim; `wallsInDocument` is `:698-725` with the live answer passed in):

```dart

// ---------------------------------------------------------------------------
// The two adapters (Ruling 08-8), moved here from opening_geometry.dart
// (:600-616, :698-725), because the wall's own outline and grips read them
// before the opening lands (3a R-P8); every type task reads the walls
// around a host through them.

/// The walls a regeneration sees around [host] (the **view adapter**,
/// Ruling 08-8): [host] as a [WorldWall], and every neighbour of it in
/// [view] carrying `WallParams`, as 07's outline reads them. Null when
/// [host] is not a live wall.
({WorldWall host, List<WorldWall> walls})? wallsInView(
    ParametricView view, Handle host) {
  final p = view.paramsOf<WallParams>(host);
  if (p == null) return null;
  return (
    host: WorldWall(host, p, view.toWorld(host)),
    walls: [
      for (final n in view.neighbours(host))
        if (view.paramsOf<WallParams>(n) case final q?)
          WorldWall(n, q, view.toWorld(n)),
    ],
  );
}

/// The walls the tools, the grips and the panel see around [host] (the
/// **document adapter**, Ruling 08-8): [host] as a [WorldWall], and every
/// other live wall of [doc] ([live] names it `ArchitectureTypes.wall`; a
/// frozen one is not live, spec 3a C1.5), ascending by handle. The view
/// adapter ([wallsInView]) sees only [host]'s neighbours; [classify], [cap]
/// and the openings' obstacles ignore a wall that does not join [host], so
/// the extra walls change nothing. Null when [host] is not a live wall.
///
/// [moved] stands in for the walls it names (an end drag's walls before it
/// is executed, spec 08 D13): each is read from it instead of [doc].
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

- [ ] **Step 8: `lib/src/wall/wall_bands.dart`.** **Copy `packages/jet_cad_floor_plan/lib/src/parametric/wall_bands.dart:1-177`**, then:
  1. Lines 5-10 (the imports after `dart:typed_data`) become, followed by `wallBandsOf`:

```dart
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart'
    show Disposable, PlanServices;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../ids.dart';
import '../live.dart';
import 'wall.dart';
import 'wall_geometry.dart';

/// The kit's one [WallBands] for [services]' document (spec 3a C2): a
/// `PlanServices.shared` object, disposed with its document. The wall tool,
/// the opening tools and the wall faces share it.
WallBands wallBandsOf(PlanServices services) =>
    services.shared<WallBands>((s) => WallBands(liveTypesOf(s)));
```

  2. The class doc's `:15-16` "The shell owns one instance / and hands it to all four." → `One per kit per document / ([wallBandsOf]); the four tools share it.`
  3. `:26` `final class WallBands {` becomes

```dart
final class WallBands implements Disposable {
  /// [live] names the live walls (`liveObjectsOf`): a frozen wall has no
  /// band.
  WallBands(this._live);

  final LiveTypeOf _live;

```

  4. `:148-153`: the comment's first sentence "Live walls only, by the engine's object rule (`live_objects.dart`)." → "Live walls only, by the engine's object rule through [_live] (spec 3a C1.5: a frozen wall is none)." (rewrap the comment at 80 columns; its other sentences unchanged), and `for (final h in liveObjectsOf<WallParams>(doc)) {` → `for (final h in liveObjectsOf<WallParams>(doc, _live, ArchitectureTypes.wall)) {`.
  5. `:170` the doc comment → `/// Cancels the document subscription: \`PlanServices.shared\` calls it` / `/// when the document goes.`, and `@override` before `void dispose() {`.
  Everything else (the stride, the cache, `generation`, `invalidate`, `liveWalls`, `_indexAt`, `hostAt`, `joinInto`, `_refresh`'s subscription and rebuild) is unchanged.

- [ ] **Step 9: Run the tests, see them pass.** `cd packages/jet_cad_2d_kit_architecture && dart format . && flutter test test/wall/`. Expected: `All tests passed!` — 44 tests (WP1-WP5, WG1-WG21, WB1-WB2, WR1-WR13, WL1-WL3). Then `flutter test` (the whole kit): `All tests passed!`.

- [ ] **Step 10: The gates.** From the repository root:
  - `cd packages/jet_cad_2d_kit_architecture && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` — `All tests passed!`, `No issues found!`, exit 0. (The kit's `analysis_options.yaml` is the plan library's, stricter than today's package: `strict-casts`, `strict-inference`, `strict-raw-types`, `avoid_dynamic_calls`, `prefer_final_locals`. A finding in a ported line is fixed without a change of behaviour and listed in the report, e.g. an explicit type argument.)
  - `dart run tool/ci/check_kit_deps.dart` — exit 0 (the kit's files name neither the plan library nor a kit).
  - `git status --short`: only this task's files (no `analysis_options.yaml`).

- [ ] **Step 11: Commit.**

```bash
git add packages/jet_cad_2d_kit_architecture/lib/src/wall/wall.dart packages/jet_cad_2d_kit_architecture/lib/src/wall/wall_geometry.dart packages/jet_cad_2d_kit_architecture/lib/src/wall/wall_bands.dart packages/jet_cad_2d_kit_architecture/test/support/catalog.dart packages/jet_cad_2d_kit_architecture/test/support/wall_fixture.dart packages/jet_cad_2d_kit_architecture/test/wall/wall_params_test.dart packages/jet_cad_2d_kit_architecture/test/wall/wall_geometry_test.dart packages/jet_cad_2d_kit_architecture/test/wall/wall_bands_test.dart packages/jet_cad_2d_kit_architecture/test/wall/wall_regen_test.dart packages/jet_cad_2d_kit_architecture/test/wall/wall_live_test.dart
git commit -m "$(cat <<'EOF'
feat(architecture): the wall's parameters, geometry and band cache (3a C3.2)

Today's wall.dart, wall_geometry.dart and wall_bands.dart moved into the
kit under architecture.wall. The wall regenerates without its opening cut
and without its place hooks until Tasks 13 and 16 bring them; the two
wall adapters move into wall_geometry.dart. The band cache and the
document adapter ask a LiveTypeOf, so a frozen wall has no band and is
no host's neighbour; wallBandsOf is the kit's one cache per document.
WP, WG, WB and WR are ported (WR9's sample line waits for Task 25).

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 12: Mutation check** (committed files only; after each: run the named test with `cd packages/jet_cad_2d_kit_architecture && flutter test <file>`, see it red, quote the red line, then `git checkout -- <file>` and `git diff --quiet -- <file>` must exit 0):
  - M-WL-1 `lib/src/wall/wall_bands.dart`: in `_refresh`, `liveObjectsOf<WallParams>(doc, _live, ArchitectureTypes.wall)` → `doc.components.withComponent<WallParams>()` → `test/wall/wall_live_test.dart` WL1 and WL3 red (the frozen wall listed and hosting).
  - M-WL-2 `lib/src/wall/wall_geometry.dart`: in `wallsInDocument`, delete `if (live(host) != ArchitectureTypes.wall) return null;` → WL2 red (the frozen wall and the stray answer a host).
  - M-WL-3 `wall_geometry.dart`: in `wallsInDocument`'s list, `if (h != host && live(h) == ArchitectureTypes.wall)` → `if (h != host)` → WL2 red (the frozen wall and the stray among A's others).
  - M-WL-4 `wall_bands.dart`: `wallBandsOf`'s body → `WallBands(liveTypesOf(services));` (not shared) → WL3 red (`identical` false).
  - M-WL-5 `wall_bands.dart`: `final class WallBands implements Disposable {` → `final class WallBands {` and delete the `@override` above `dispose` (the `show Disposable` then draws an `unused_shown_name` warning; the test run is what counts) → WL3 red (the change after `services.dispose()` moves `generation`).
  - M-WL-6 `wall_bands.dart`: in `wallBandsOf`, `WallBands(liveTypesOf(s))` → `WallBands((h) => s.document.components.get<WallParams>(h) == null ? null : ArchitectureTypes.wall)` (the services' live answer ignored) → WL3 red (`liveWalls` holds the frozen F).
  - M-WL-7 `lib/src/wall/wall.dart`: `componentTypeId = ArchitectureTypes.wall` → `componentTypeId = 'floor_planner.wall'` → `test/wall/wall_params_test.dart` WP1 red (the id assertion of C7 class 1).

#### Assumed from earlier tasks

- Task 9: `lib/src/live.dart`'s `LiveTypeOf`, `liveTypesOf`, `liveObjectsOf<T>(document, live, typeId)` as in its part (the ascending filter over `withComponent<T>()`); `lib/src/ids.dart`'s `ArchitectureTypes.wall`; the kit's pubspec lists `vector_math` and `meta` (R-P11).
- Task 10: `test/support/catalog.dart` with `testCatalog()` (R-P13: a function over one instance, the box's line) and `installParametric`; `BoxParams.componentTypeId == ArchitectureTypes.box`.
- Task 6: `FakePlanServices` as in "Shared interfaces": `liveTypeIdOf` is `catalog?.typeIdOf(document, h)` unless `h` is in `frozen`; `shared` keeps one per `T` and `dispose()` disposes each `Disposable` one.

#### New shared name

Each is used by a later task; the signatures are the ones above (Produces).
- `lib/src/wall/wall_geometry.dart`: `wallsInView(ParametricView view, Handle host)` and `wallsInDocument(DraftDocument doc, Handle host, LiveTypeOf live, {Map<Handle, WorldWall> moved = const {}})`. Users: Task 12 (grips), 13 (opening geometry, which does **not** copy `opening_geometry.dart:600-616, 698-725` again), 15, 16, 20, 21, 24. R-P6 wrote `{required LiveTypeOf live}`; R-P8 and Task 13's part use the positional form, which this task follows.
- `lib/src/wall/wall_bands.dart`: `WallBands(LiveTypeOf live)` (`implements Disposable`) and `WallBands wallBandsOf(PlanServices services)`; members unchanged. Users: Tasks 12, 15, 24.
- Kit `test/support/wall_fixture.dart`: today's helpers (re-exporting `catalog.dart`'s `testCatalog`, `installParametric`) plus `LiveTypeOf liveOf(DraftDocument doc, {Set<Handle> frozen = const {}})`. Tasks 13 and 14 already call `liveOf(doc)` / `liveOf(doc, frozen: {...})` from it; Task 16's `room_fixture.dart` re-exports this one (R-P17; its `liveIn` is gone), and Task 13's `opening_fixture.dart` too.

#### Carried to later tasks (R-P8, R11-1)

- **Task 13** restores `wall.dart:199`'s sentence, `:203` (`if (_cut(view, self) case final pieces?) return pieces;`) and `:215-238` (`_cut`) in `lib/src/wall/wall.dart`, with `import '../opening/opening_geometry.dart';` (its `hostCutsInView`, `piecesOf`, `centrelinePieces`).
- **Task 16** restores `wall.dart:172-189` (`contributesPlace`, `placeBox`, `placeInput`) with `import '../room/room_inputs.dart';` (its `placeBoxInView`, `roomInputInView`).
- **Task 25** restores WR9's sample-plan line (`wall_regen_test.dart:497-501`, one assertion: the sample flat has no diagnostic) in `test/wall/wall_regen_test.dart`, over `installParametric` and `buildSampleFlat` (Task 25's Step 2b).
- No case of this task's four files needs an opening or a room; none moves elsewhere.

---

