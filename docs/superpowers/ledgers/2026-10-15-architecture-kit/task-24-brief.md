### Task 24: The wall-face provider (spec C5, C2 "Shared caches", C1.5; Appendix A D-01, D-06, D-07, D-08)

**Files:**
- Create (`packages/jet_cad_2d_kit_architecture/`):
  - `lib/src/attach/wall_attach.dart` (ported: `FaceSide`, `FaceRun`, `faceRunsOf`, `faceRunsAmong`, `FaceNeighbour`, `WallAttachment`, `attachToWall`)
  - `lib/src/attach/wall_faces.dart` (ported `WallFaces`, plus `wallFacesOf`)
  - `lib/src/attach/wall_face_provider.dart` (`wallFaceProvider`)
  - `test/support/wall_attach_fixture.dart` (ported fixture; Task 28 uses it)
  - `test/attach/wall_faces_test.dart` (ported WF1-WF9)
  - `test/attach/wall_face_provider_test.dart` (WF-query, WF-keep, WF-hysteresis, WF-hidden, WF-frozen, WF-state, WF-exclude)
- Modify (`packages/jet_cad_2d_kit_architecture/`): `lib/src/kit.dart` (`attachments: [wallFaceProvider]`, `symbols: [furnitureSource]`)
- Create (`packages/jet_cad_2d_integration/`): `test/furniture/furniture_load_test.dart` (FU-load, WF-offered)

**Interfaces:**
- Consumes:
  - Contract: `AttachmentProvider`, `AttachmentQuery` (`footprint`, `current`, `pointer`, `capture`, `edgeCapture`, `mirrored`, `mayRotate`, `exclude`, `keep`), `Attachment({transform, marker, token})` (`jet_cad_2d_kit/lib/src/kit/attachment.dart:11-103`); `PlanServices.shared`, `document` (`plan_services.dart:86-130`); Task 1: `SymbolBox`, `boxOfDefinition`, `boxOfEntry`, `footprintOf`, `isOrthonormal`, `placementTransform`; Task 6: `PlanServices.liveTypeIdOf`, `FakePlanServices` (`package:jet_cad_2d_kit/testing.dart`).
  - Task 9: `typedef LiveTypeOf = String? Function(Handle handle)`, `LiveTypeOf liveTypesOf(PlanServices services)` (`lib/src/live.dart`), `ArchitectureTypes`, `architectureKit`.
  - Task 11: `WallBands` (`liveWalls(doc)`, `generation`, `invalidate()`), `WallBands wallBandsOf(PlanServices s)` (`lib/src/wall/wall_bands.dart`); `WallParams`, `Justification`, `wallJoin` (`lib/src/wall/wall.dart`); `WorldWall`, `HostFrame`, `End`, `capsOf`, `intersect`, `strictlyInside` (`lib/src/wall/wall_geometry.dart`); the test support `test/support/wall_fixture.dart` (`wallDoc`, `addWall`, `addWallLocal`, `polar`, `worldWallOf`, `face`, `oracleMeet`, `worldOutline`, `nearestIn`).
  - Task 11: `wallsInDocument(doc, host, LiveTypeOf live, {moved})` (`lib/src/wall/wall_geometry.dart`, R-P8, R-P17). Task 13: `hostFrameOf`, `hostFrameInDocument`, `layoutInDocument`, `obstaclesOf` (`lib/src/opening/opening_geometry.dart`), each taking a `LiveTypeOf` where today's read the global catalog.
  - Task 15: `bool isUsableHost(DraftDocument doc, Handle wall)` (`lib/src/opening/opening_tool.dart`, today's `opening_tool.dart:447-450`).
  - Task 20: the test support `test/support/dimension_fixture.dart` (`c11`, `docOfWalls`, `scaledGroups`).
  - Task 23: `furnitureSource` (`lib/src/furniture/furniture_source.dart`), the committed `assets/library/furniture.jetlib`, `test/support/place_entry.dart` (`placeEntry`).
  - Integration (Task 9): `PlanController architectureController({String? json, PlanPermissions permissions})`.
- Produces:

```dart
// lib/src/attach/wall_face_provider.dart (Shared interfaces, exact)
AttachmentProvider wallFaceProvider(PlanServices services);
// lib/src/attach/wall_faces.dart (Shared interfaces, exact)
WallFaces wallFacesOf(PlanServices s); // s.shared(...)
// internal, changed from today (see "New shared name"):
List<FaceRun> faceRunsOf(DraftDocument doc, Handle wall, LiveTypeOf live,
    {bool Function(DraftDocument, Handle)? accept});
WallFaces(WallBands bands, LiveTypeOf live, {bool Function(DraftDocument, Handle)? accept});
// today's names kept: FaceSide, FaceRun, faceRunsAmong, FaceNeighbour, WallAttachment,
// attachToWall (unchanged signature), WallFaces.runsOf/neighboursOf/boxOf/attach/builds.
```

**Appendix A rows closed:**
- **D-01**, its kit part: `jet_cad_floor_plan/test/symbols/wall_faces_test.dart` WF1-WF9, all nine in the kit. `wall_attach_test.dart` (23) and `wall_attach_property_test.dart` (2) are Task 28's by the spec's assignment, and `symbol_move_test.dart` (6) too (`PlanMoveResolver`); see "Interface problem" for where the first two can lawfully run.
- **D-06** `WallFaces` compares `document.commands.stateId` (WF-state).
- **D-07** today's capture and keep distance, one capture whether or not the query keeps an earlier answer (WF-hysteresis); the plan test kit's inverted hysteresis is not copied.
- **D-08** the provider fits `AttachmentProvider` (kind `wall-face`); under `mayRotate: false` only a face the symbol already faces, its linear part kept bit for bit (WF-keep).
- C5's layer rule, the kit half of D-04's SS17: a wall on a hidden or locked layer offers no face (WF-hidden). C1.5's "a frozen wall is absent from the wall faces" (WF-frozen).

**Plan decisions:**
- **Today's oracle, unchanged.** `attachToWall` keeps its signature and code (09c D4: face pick, hold check, rotation, centre, edge snap to run ends and neighbours, clamp; F-7's `keep`). The provider maps the query onto it:
  - the footprint is the box: `left = minX`, `right = maxX`, `front = minY`, `back = maxY` (the inverse of `footprintOf`, `jet_cad_2d_plan/lib/src/symbols/symbol_box.dart:166-170`);
  - `pointer`, `capture` and `edgeCapture` as given: the plan passes today's 16 px and the snap aperture over the scale (`jet_cad_2d_plan/lib/src/tools/plan_symbol_tool.dart:254-264`, `move_resolver.dart:80-91`), today's `kWallAttachPixels` and `kSnapAperturePixels` (`jet_cad_floor_plan/lib/src/symbols/symbol_place_tool.dart:298-302`, `symbol_move.dart:54-58`);
  - **F-7** (D-08): `keep: query.mayRotate ? null : query.current`. Today's placement passed the unturned linear part (identity or the mirror, `symbol_place_tool.dart:295-297`) and the move passed `delta · T` (`symbol_move.dart:58`); the plan's `current` is exactly those (the placement's turns are 0 while rotation is refused, `plan_symbol_tool.dart:192`; the move's `current` is `delta · T`, `move_resolver.dart:84`). `attachToWall` reads only the linear part of `keep`;
  - **the query's `keep`** (the previous answer) is not read: today's attachment has one capture, kept or not (D-07). WF-hysteresis pins it;
  - `exclude`: the plan passes none or the one moved node (`move_resolver.dart:89`); `attachToWall` takes one handle. A query excluding more than one object attaches nowhere (the safe answer; no caller asks it) (WF-exclude);
  - the answer: `Attachment(transform, marker: q, token: run)`;
  - an empty footprint attaches nowhere.
- **The cache** (`WallFaces`, spec C2 "Shared caches"): one per kit and document through `PlanServices.shared`, over the shared `WallBands` and the kit's `LiveTypeOf`, with today's `isUsableHost` as the host predicate. **D-06:** today the placement tool invalidated the bands after each placement (`symbol_place_tool.dart:500`); `plan.symbol` and `plan.select` are plan tools and cannot. So `_refresh` also keeps the document's `commands.stateId`: when it moved since the last build, it invalidates the bands (their next scan rebuilds, as after today's placement) and rebuilds the runs, the neighbours and the boxes, before the document's `changes` stream reports the change. Today's WA9 (`wall_attach_test.dart:544-610`, Task 28's port) still counts one build per change: a delivered change and a moved state each lead to one rebuild on the next query.
- **Liveness** (C1.5): `faceRunsOf` gains the `LiveTypeOf` its `wallsInDocument` call needs (Task 13); `WallFaces` holds the one it was made with. A frozen wall is then absent from the faces exactly as it is from `generate`.
- **Layers** (C5): a wall whose object layer is hidden or locked offers no face (`accept: isUsableHost`, today's `planner_shell.dart:492`).
- **The source joins the kit here** with the provider (Task 23's plan decision): no state of the branch loads a symbol naming `wall-face` while no provider offers it (WF-offered).
- **Placement of the 09c tests** (C7). `wall_faces_test` uses `faceRunsOf` and the wall geometry only: kit. Its fixture (`jet_cad_floor_plan/test/support/wall_attach_fixture.dart`, 163 lines) is ported here because WF1-WF9 need it; Task 28 reuses it.

- [ ] **Step 1: Precondition.** Tasks 1-23 are committed. Run `cd packages/jet_cad_2d_kit_architecture && flutter analyze` → `No issues found!`. Read Task 11's `wallsInDocument` (`lib/src/wall/wall_geometry.dart`, `live` positional, R-P17) and Task 13's `hostFrameInDocument`, `layoutInDocument` signatures (`lib/src/opening/opening_geometry.dart`), Task 11's `WallBands` constructor and `wallBandsOf`, Task 15's `isUsableHost`, and the kit test support (`test/support/wall_fixture.dart`, `test/support/dimension_fixture.dart`). `wallsInDocument(doc, wall, live)` is R-P17's shape; that is the only adaptation of those calls.

- [ ] **Step 2: The fixture.** Copy `packages/jet_cad_floor_plan/test/support/wall_attach_fixture.dart` to `packages/jet_cad_2d_kit_architecture/test/support/wall_attach_fixture.dart`, lines 1-163 unchanged except:
  - line 11, `import 'package:jet_cad_floor_plan/src/parametric/wall.dart';` → `import 'package:jet_cad_2d_kit_architecture/src/wall/wall.dart';`
  - the header gains the line `// Ported to the architecture kit by 3a Task 24 (spec C5, C7).`
  - No catalog or live reader of its own (rulings R-P13, R-P17): after its `import 'wall_fixture.dart';` add `export 'wall_fixture.dart' show liveOf, testCatalog;`, so a test importing only this fixture reaches Task 11's `liveOf(doc, {frozen})` and Task 10's `testCatalog()` (the kit's raw types in today's order, which `typeIdOf` answers as the plan's catalog does).

- [ ] **Step 3: The ported faces test.** Copy `packages/jet_cad_floor_plan/test/symbols/wall_faces_test.dart` to `packages/jet_cad_2d_kit_architecture/test/attach/wall_faces_test.dart`. **Assertions unchanged.** Adaptations:
  - The header (lines 1-6) gains `// Ported to the architecture kit by 3a Task 24 (spec C5, C7; D-01).`
  - Imports (lines 9-12): `jet_cad_floor_plan/src/parametric/opening_geometry.dart` → `jet_cad_2d_kit_architecture/src/opening/opening_geometry.dart`; `.../parametric/wall.dart` → `.../src/wall/wall.dart`; `.../parametric/wall_geometry.dart` → `.../src/wall/wall_geometry.dart`; `.../symbols/wall_attach.dart` → `.../src/attach/wall_attach.dart`. The support imports (lines 17-19) keep their `show` lists and point at the kit's `test/support/` files.
  - Each of the 19 `faceRunsOf(<doc>, <wall>` calls gains the reader after the wall: `faceRunsOf(<doc>, <wall>, liveOf(<doc>)` (`grep -n "faceRunsOf(" packages/jet_cad_2d_kit_architecture/test/attach/wall_faces_test.dart` lists them; `<doc>` is `sc.doc`, `doc`, `l.doc` or `u.doc`). WF7's `faceRunsOf(doc, h, accept: allow)` becomes `faceRunsOf(doc, h, liveOf(doc), accept: allow)`.
  - The six `hostFrameInDocument(...)` calls and the one `layoutInDocument(...)` call take Task 13's reader argument, `liveOf(<their doc>)`, in Task 13's position.
  - Ported: WF1-WF9, all in the kit.

- [ ] **Step 4: The provider tests.** Create `packages/jet_cad_2d_kit_architecture/test/attach/wall_face_provider_test.dart`:

```dart
// 3a Task 24 (spec C5, C2 "Shared caches", C1.5; D-06, D-07, D-08): the
// wall-face provider over FakePlanServices. Every scene is the 09c fixture's:
// walls in their own rotated groups near (1e5, −7e4), never at the identity.
// The oracle is today's attachToWall over the same runs; the expected points
// are the run's own frame, a + t·u + m·s.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_kit/testing.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart'
    show ArchitectureTypes;
import 'package:jet_cad_2d_kit_architecture/src/attach/wall_attach.dart';
import 'package:jet_cad_2d_kit_architecture/src/attach/wall_face_provider.dart';
import 'package:jet_cad_2d_kit_architecture/src/opening/opening_tool.dart'
    show isUsableHost;
import 'package:jet_cad_2d_kit_architecture/src/wall/wall.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/place_entry.dart';
import '../support/wall_attach_fixture.dart';

/// 16 px and 6 px at 0.1 px/mm: today's capture and edge snap in world.
const double capture = 160, edge = 60;

/// An off-origin box, its front not its back: x 120..1320, y 40..640.
const SymbolBox box = SymbolBox(left: 120, right: 1320, front: 40, back: 640);

/// The point `u` along [r] and `s` into the room from its face.
Vector2 at(FaceRun r, double u, double s) => r.a + r.t * u + r.m * s;

AttachmentQuery query(Aabb2 footprint, Vector2 p,
        {bool mirrored = false,
        bool mayRotate = true,
        Transform2? current,
        Set<Handle> exclude = const {},
        Attachment? keep}) =>
    AttachmentQuery(
      footprint: footprint,
      current: current ?? Transform2.identity(),
      pointer: p,
      capture: capture,
      edgeCapture: edge,
      mirrored: mirrored,
      mayRotate: mayRotate,
      exclude: exclude,
      keep: keep,
    );

/// The kit's services over [doc], frozen [frozen], disposed at tear-down.
FakePlanServices servicesOf(DraftDocument doc,
    {Set<Handle> frozen = const {}}) {
  final s = FakePlanServices(
      document: doc, catalog: testCatalog(), frozen: frozen, scale: 0.1);
  addTearDown(s.dispose);
  return s;
}

List<double> linear(Transform2 g) => [g.a, g.b, g.c, g.d];
List<double> all(Transform2 g) => [g.a, g.b, g.c, g.d, g.e, g.f];

/// The committed library's [key].
SymbolEntry furniture(String key) =>
    SymbolLibrary.decode(
            File('assets/library/furniture.jetlib').readAsBytesSync())
        .entries
        .firstWhere((e) => e.symbol.key == key);

/// [doc]'s last root-level instance.
Handle lastInstance(DraftDocument doc) {
  final root = doc.tree[doc.tree.root]! as GroupNode;
  return [
    for (final h in doc.tree.childNodesOf(root.children))
      if (doc.tree[h] is InstanceNode) h,
  ].last;
}

void main() {
  test(
      'WF-query the provider is today\'s attachToWall over the document\'s '
      'faces: kind wall-face; the footprint read as the box (front minY, '
      'back maxY); the marker the face point q; the token the run; the '
      'back-centre on the marker; beyond the capture, nothing; a 30° wall '
      'in a turned group, mirrored and not', () {
    for (final mirrored in const [false, true]) {
      final why = mirrored ? 'mirrored' : 'plain';
      final sc = freeWallScene(30, Justification.left, mirrored: mirrored);
      final provider = wallFaceProvider(servicesOf(sc.doc));
      expect(provider.kind, 'wall-face');
      final runs = faceRunsOf(sc.doc, sc.walls.single, liveOf(sc.doc),
          accept: isUsableHost);
      expect(runs, hasLength(2), reason: why);
      for (final r in runs) {
        final p = at(r, 1500, 90);
        final want = attachToWall(runs, box, p, capture,
            mirrored: mirrored,
            neighbours: [for (final _ in runs) const <FaceNeighbour>[]],
            edgeCaptureWorld: edge)!;
        final got = provider.attach(
            query(footprintOf(box), p, mirrored: mirrored))!;
        final rw = '$why ${r.side.name}';
        expect(all(got.transform), all(want.transform), reason: rw);
        expect(got.marker, want.q, reason: rw);
        expect((got.token as FaceRun).side, r.side, reason: rw);
        expect(
            (got.transform.transformPoint(box.backCentre) - got.marker).length,
            lessThan(1e-6),
            reason: '$rw: the back edge on the face');
        expect(provider.attach(query(footprintOf(box), at(r, 1500, capture + 1),
                mirrored: mirrored)),
            isNull,
            reason: '$rw: beyond the capture');
      }
    }
  });

  test(
      'WF-keep (D-08) with mayRotate false the symbol attaches only to a '
      'face its current turn already faces and keeps its linear part bit '
      'for bit, mirrored or not; with mayRotate true, to either face', () {
    // A wall along world x in a turned group: one face looks −y (t = (1, 0),
    // the unturned symbol's), the other +y.
    final sc = freeWallScene(0, Justification.centre);
    final provider = wallFaceProvider(servicesOf(sc.doc));
    final runs = faceRunsOf(sc.doc, sc.walls.single, liveOf(sc.doc));
    expect([for (final r in runs) r.m.y.sign], unorderedEquals([1.0, -1.0]),
        reason: 'premise: one face looks −y, the other +y');
    for (final (mirrored, current) in [
      (false, Transform2.translation(37.5, -12.25)),
      (true, const Transform2(-1, 0, 0, 1, 410.5, 88.75)),
    ]) {
      for (final r in runs) {
        final p = at(r, 1800, 60);
        final why = '${mirrored ? 'mirrored' : 'plain'} m.y ${r.m.y.sign}';
        expect(provider.attach(query(footprintOf(box), p, mirrored: mirrored)),
            isNotNull,
            reason: '$why: free to turn');
        final kept = provider.attach(query(footprintOf(box), p,
            mirrored: mirrored, mayRotate: false, current: current));
        if (r.m.y < 0) {
          expect(kept, isNotNull, reason: '$why: the face it already faces');
          expect(linear(kept!.transform), linear(current), reason: why);
        } else {
          expect(kept, isNull, reason: '$why: a face it would turn to');
        }
      }
    }
  });

  test(
      'WF-hysteresis (D-07) one capture, kept or not: 130 mm from the face '
      '(13 px) attaches with and without the previous answer; 170 mm (17 '
      'px) attaches with neither', () {
    final sc = freeWallScene(30, Justification.centre);
    final provider = wallFaceProvider(servicesOf(sc.doc));
    final r = faceRunsOf(sc.doc, sc.walls.single, liveOf(sc.doc)).first;
    final first = provider.attach(query(footprintOf(box), at(r, 1500, 50)))!;
    final near = at(r, 1500, 130), far = at(r, 1500, 170);
    expect(provider.attach(query(footprintOf(box), near)), isNotNull);
    expect(provider.attach(query(footprintOf(box), near, keep: first)),
        isNotNull,
        reason: 'kept: the same capture, not a smaller one');
    expect(provider.attach(query(footprintOf(box), far)), isNull);
    expect(provider.attach(query(footprintOf(box), far, keep: first)), isNull,
        reason: 'kept: the same capture, not a larger one');
  });

  test(
      'WF-hidden (C5, SS17) a wall on a hidden layer and a wall on a locked '
      'layer offer no face; on a visible, unlocked layer they do', () {
    for (final (name, visible, locked, offers) in const [
      ('visible', true, false, true),
      ('hidden', false, false, false),
      ('locked', true, true, false),
    ]) {
      final sc = freeWallScene(30, Justification.right);
      final zero = sc.doc.tables.layers[ReservedHandles.layerZero]!;
      // The restore form: the record exactly, past the current-layer rule.
      sc.doc.commands.execute(SetLayerCommand.restore(
          zero.copyWith(visible: visible, locked: locked)));
      final provider = wallFaceProvider(servicesOf(sc.doc));
      final r = faceRunsOf(sc.doc, sc.walls.single, liveOf(sc.doc)).first;
      final got = provider.attach(query(footprintOf(box), at(r, 1500, 40)));
      expect(got != null, offers, reason: name);
    }
  });

  test(
      'WF-frozen (C1.5) a frozen wall offers no face, though the catalog '
      'still names its type', () {
    final sc = freeWallScene(-112.5, Justification.centre);
    final wall = sc.walls.single;
    final r = faceRunsOf(sc.doc, wall, liveOf(sc.doc)).first;
    final p = at(r, 1500, 40);
    final live = wallFaceProvider(servicesOf(sc.doc));
    expect(live.attach(query(footprintOf(box), p)), isNotNull);
    final s = servicesOf(sc.doc, frozen: {wall});
    expect(testCatalog().typeIdOf(sc.doc, wall), ArchitectureTypes.wall,
        reason: 'premise: the catalog answers a frozen object');
    expect(s.liveTypeIdOf(wall), isNull, reason: 'premise');
    expect(wallFaceProvider(s).attach(query(footprintOf(box), p)), isNull);
  });

  test(
      'WF-state (D-06) a symbol placed by a command is a neighbour at the '
      'next query, before the document\'s changes are delivered: the next '
      'unit snaps flush to it', () {
    final sc = freeWallScene(30, Justification.centre);
    final doc = sc.doc;
    if (!doc.components.isRegistered<SymbolComponent>()) {
      registerKitComponents(doc.components);
    }
    final provider = wallFaceProvider(servicesOf(doc));
    final unit = furniture('architecture.kitchen.base.600');
    final ubox = boxOfEntry(unit)!;
    final foot = footprintOf(ubox);
    final r = faceRunsOf(doc, sc.walls.single, liveOf(doc)).first;
    // The first unit, centred at u = 1200 (its sides 900 and 1500: no end
    // within the edge capture).
    final first = provider.attach(query(foot, at(r, 1200, 40)))!;
    expect((first.marker - at(r, 1200, 0)).length, lessThan(1e-6),
        reason: 'premise: no snap');
    doc.commands.execute(
        placeEntry(doc, unit, at: first.marker, transform: first.transform));
    // No pump: the changes stream has not delivered. The next unit's left
    // side comes 40 short of the first's right (1500): it snaps to 1500,
    // its centre to 1200 + 600.
    final next = provider.attach(query(foot, at(r, 1840, 40)))!;
    expect((next.marker - at(r, 1200 + ubox.width, 0)).length, lessThan(1e-6),
        reason: 'flush to the neighbour placed one command ago');
  });

  test(
      'WF-exclude the excluded instance is no neighbour; a query excluding '
      'two objects attaches nowhere', () {
    final sc = freeWallScene(30, Justification.centre);
    final doc = sc.doc;
    if (!doc.components.isRegistered<SymbolComponent>()) {
      registerKitComponents(doc.components);
    }
    final provider = wallFaceProvider(servicesOf(doc));
    final unit = furniture('architecture.kitchen.base.600');
    final foot = footprintOf(boxOfEntry(unit)!);
    final r = faceRunsOf(doc, sc.walls.single, liveOf(doc)).first;
    final first = provider.attach(query(foot, at(r, 1200, 40)))!;
    doc.commands.execute(
        placeEntry(doc, unit, at: first.marker, transform: first.transform));
    final neighbour = lastInstance(doc);
    final free =
        provider.attach(query(foot, at(r, 1840, 40), exclude: {neighbour}))!;
    expect((free.marker - at(r, 1840, 0)).length, lessThan(1e-6),
        reason: 'no snap to the excluded instance');
    expect(
        provider.attach(query(foot, at(r, 1840, 40),
            exclude: {neighbour, sc.walls.single})),
        isNull);
  });
}
```

- [ ] **Step 5: Run the tests, see them fail.** `cd packages/jet_cad_2d_kit_architecture && flutter test test/attach/`. Expected: compile errors — `lib/src/attach/wall_attach.dart` and `wall_face_provider.dart` do not exist.

- [ ] **Step 6: `wall_attach.dart`.** Create `packages/jet_cad_2d_kit_architecture/lib/src/attach/wall_attach.dart` from `packages/jet_cad_floor_plan/lib/src/symbols/wall_attach.dart`:
  - Lines 1-17 (header and imports) become:

```dart
// The wall faces a symbol stands against (spec 09c D3) and the one
// attachment rule (D4), ported from jet_cad_floor_plan/lib/src/symbols/
// wall_attach.dart:1-397 by 3a Task 24 (spec C5). The cache of runs and
// neighbours is `wall_faces.dart`'s; the provider is
// `wall_face_provider.dart`.
//
// No Flutter import and no `dart:ui`: this file is Dart over
// `package:jet_cad_2d`, the contract's pure-Dart model and the kit's
// geometry. A live wall is the kit's [LiveTypeOf] (spec C1.5); the
// Flutter-side host predicate (`isUsableHost`) is passed in as `accept`.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/authoring.dart'
    show SymbolBox, placementTransform;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../live.dart';
import '../opening/opening_geometry.dart';
import '../wall/wall.dart';
import '../wall/wall_geometry.dart';
```

  - Copy lines 19-57 unchanged (`FaceSide`, `FaceRun`).
  - Lines 58-69 (`faceRunsOf`) become:

```dart
/// The face runs of wall [wall] of [doc] (spec 09c D3) through the document
/// adapter ([wallsInDocument]: every other live wall can cut it). Empty when
/// [wall] is not a live wall by [live] (a frozen wall or a missing kit's is
/// not, spec C1.5), is degenerate, or [accept] refuses it (the kit passes
/// `isUsableHost`: a hidden or locked wall hosts nothing). [accept] is asked
/// only for a live wall.
List<FaceRun> faceRunsOf(DraftDocument doc, Handle wall, LiveTypeOf live,
    {bool Function(DraftDocument, Handle)? accept}) {
  final w = wallsInDocument(doc, wall, live);
  if (w == null) return const [];
  if (accept != null && !accept(doc, wall)) return const [];
  return faceRunsAmong(w.host, w.walls);
}
```

  - Copy lines 70-397 unchanged (`faceRunsAmong` through `_ranksBefore`), with the one adaptation every `hostFrameOf`/`obstaclesOf` call needs if Task 13 changed their parameters (today's take `WorldWall`s only, no catalog: none expected).
  - Lines 399-407 (`isOrthonormal`) are not copied: it is the contract's (Task 1). Lines 409-550 (`WallFaces`) go to `wall_faces.dart`.

- [ ] **Step 7: `wall_faces.dart`.** Create `packages/jet_cad_2d_kit_architecture/lib/src/attach/wall_faces.dart` (today's `wall_attach.dart:409-550`; changed: the reader, the state, `_refresh`, the imports, `wallFacesOf`):

```dart
// The kit's cache of the wall faces a symbol stands against and of the
// symbols already against them (spec 09c D3, D4, S-8; 3a C2 "Shared
// caches", C5), ported from jet_cad_floor_plan/lib/src/symbols/
// wall_attach.dart:409-550 by 3a Task 24. One per kit and document
// (`PlanServices.shared`); besides the bands' generation it keeps the
// document's command state (D-06).
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart'
    show
        PlanServices,
        SymbolBox,
        SymbolComponent,
        boxOfDefinition,
        isOrthonormal;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../live.dart';
import '../opening/opening_tool.dart' show isUsableHost;
import '../wall/wall.dart';
import '../wall/wall_bands.dart';
import 'wall_attach.dart';

/// The cache of the face runs and their neighbours (spec 09c D3, D4, S-8),
/// shared by every query of the wall-face provider for one document.
///
/// Built from [bands]' live walls (`WallBands.liveWalls`, which keeps
/// [WallBands.generation] current), the kit's reader [live], the host
/// predicate [accept] (the kit passes `isUsableHost`: a hidden or locked
/// wall hosts nothing) and the document. The runs, the neighbours and the
/// boxes of the document's definitions are rebuilt only when the document,
/// the bands' generation or the document's command state (`stateId`, D-06)
/// changes; a query over a cached set ([attach]) is O(runs) and allocates
/// O(1).
final class WallFaces {
  WallFaces(this.bands, this.live,
      {bool Function(DraftDocument, Handle)? accept})
      : _accept = accept;

  /// The kit's bands, shared with the Wall and Opening tools.
  final WallBands bands;

  /// Which objects are live walls (spec C1.5): a frozen wall has no face.
  final LiveTypeOf live;
  final bool Function(DraftDocument, Handle)? _accept;

  DraftDocument? _document;
  int _generation = 0;
  int _state = -1;
  List<FaceRun> _runs = const [];
  List<List<FaceNeighbour>> _neighbours = const [];
  final Map<Handle, SymbolBox?> _boxes = <Handle, SymbolBox?>{};
  int _builds = 0;

  /// How many times the runs and neighbours were rebuilt: once per
  /// document, bands generation and command state, never per query.
  int get builds => _builds;

  /// The face runs of [doc]'s accepted live walls, ascending by wall handle
  /// (each wall's left face's runs, then its right face's).
  List<FaceRun> runsOf(DraftDocument doc) {
    _refresh(doc);
    return _runs;
  }

  /// Parallel to [runsOf]: the neighbours (spec D4) standing against each
  /// run.
  List<List<FaceNeighbour>> neighboursOf(DraftDocument doc) {
    _refresh(doc);
    return _neighbours;
  }

  /// The local box of [doc]'s definition [definition], memoised until the
  /// next rebuild (spec D2: per definition handle, cleared on a document
  /// change); null when it does not attach.
  SymbolBox? boxOf(DraftDocument doc, Handle definition) {
    _refresh(doc);
    return _box(doc, definition);
  }

  /// [attachToWall] over [doc]'s cached runs and neighbours, [exclude]
  /// (the instance a move carries, D8) not a neighbour, keeping [keep]'s
  /// linear part when given (F-7).
  WallAttachment? attach(
    DraftDocument doc,
    SymbolBox box,
    Vector2 p,
    double captureWorld, {
    required bool mirrored,
    required double edgeCaptureWorld,
    Handle? exclude,
    Transform2? keep,
  }) {
    _refresh(doc);
    return attachToWall(_runs, box, p, captureWorld,
        mirrored: mirrored,
        neighbours: _neighbours,
        edgeCaptureWorld: edgeCaptureWorld,
        exclude: exclude,
        keep: keep);
  }

  SymbolBox? _box(DraftDocument doc, Handle definition) {
    if (_boxes.containsKey(definition)) return _boxes[definition];
    return _boxes[definition] = boxOfDefinition(doc, definition);
  }

  void _refresh(DraftDocument doc) {
    final state = doc.commands.stateId;
    // D-06: a command since the last build (a placement by plan.symbol, a
    // move by plan.select: plan tools, which cannot invalidate the bands as
    // today's placement tool did, symbol_place_tool.dart:500) makes the
    // walls, the neighbours and the boxes stale before the document's
    // changes stream reports it. Invalidate the bands as that tool did.
    if (identical(doc, _document) && state != _state) bands.invalidate();
    final walls = bands.liveWalls(doc);
    if (identical(doc, _document) && bands.generation == _generation) return;
    _document = doc;
    _generation = bands.generation;
    _state = state;
    _builds++;
    _boxes.clear();
    final runs = <FaceRun>[
      for (final h in walls) ...faceRunsOf(doc, h, live, accept: _accept),
    ];
    _runs = List.unmodifiable(runs);
    _neighbours = _neighboursAlong(doc, runs);
  }

  /// Spec D4's neighbours of each of [runs]: the root-level instances on a
  /// visible, unlocked layer (the picking rule, [QueryFilter.picking])
  /// whose definition carries a [SymbolComponent] and has a box, whose
  /// transform is orthonormal, whose transformed back edge has both ends on
  /// the run's line (within `wallJoin.linear`) with the front on the room
  /// side, and whose interval along `t` overlaps `[0, L]`.
  List<List<FaceNeighbour>> _neighboursAlong(
      DraftDocument doc, List<FaceRun> runs) {
    final placed = <(Handle, Vector2, Vector2, Vector2)>[];
    final root = doc.tree[doc.tree.root];
    if (root is GroupNode) {
      final filter = FilterEvaluator(doc);
      for (final h in doc.tree.childNodesOf(root.children)) {
        final node = doc.tree[h];
        if (node is! InstanceNode) continue;
        if (doc.components.get<SymbolComponent>(node.definition) == null) {
          continue;
        }
        if (!filter.acceptsNode(h, const QueryFilter.picking())) continue;
        final box = _box(doc, node.definition);
        if (box == null) continue;
        final g = doc.tree.accumulatedTransform(h);
        if (!isOrthonormal(g)) continue;
        placed.add((
          h,
          g.transformPoint(Vector2(box.left, box.back)),
          g.transformPoint(Vector2(box.right, box.back)),
          g.transformPoint(Vector2((box.left + box.right) / 2, box.front)),
        ));
      }
    }
    final tol = wallJoin.linear;
    return List.unmodifiable([
      for (final r in runs)
        List<FaceNeighbour>.unmodifiable([
          for (final (h, e1, e2, front) in placed)
            if (((e1 - r.a).dot(r.m)).abs() <= tol &&
                ((e2 - r.a).dot(r.m)).abs() <= tol &&
                (front - r.a).dot(r.m) > 0)
              if (_interval((e1 - r.a).dot(r.t), (e2 - r.a).dot(r.t), h)
                  case final n when n.hi >= 0 && n.lo <= r.length)
                n,
        ]),
    ]);
  }

  static FaceNeighbour _interval(double u1, double u2, Handle h) =>
      u1 <= u2 ? (lo: u1, hi: u2, instance: h) : (lo: u2, hi: u1, instance: h);
}

/// The kit's one [WallFaces] for [s]'s document (spec C2 "Shared caches"):
/// over the shared bands, the kit's live walls and today's host rule.
WallFaces wallFacesOf(PlanServices s) => s.shared<WallFaces>((s) =>
    WallFaces(wallBandsOf(s), liveTypesOf(s), accept: isUsableHost));
```

  Compare it with the source's lines 409-550 (`sed -n 409,550p packages/jet_cad_floor_plan/lib/src/symbols/wall_attach.dart`): only the header, the imports, the constructor, `live`, `_state`, the class and `builds` doc lines, `_refresh` and `wallFacesOf` differ.

- [ ] **Step 8: The provider.** Create `packages/jet_cad_2d_kit_architecture/lib/src/attach/wall_face_provider.dart`:

```dart
// The wall-face attachment provider (spec 3a C5; umbrella A5; 09c D4, D6,
// D8): today's attachToWall over the kit's WallFaces, answering the plan
// library's AttachmentQuery. The capture and the edge snap are the query's
// (today's 16 px and snap aperture, which the plan passes); one capture,
// whether or not the query keeps an earlier answer (D-07); under
// mayRotate false only a face the symbol already faces (F-7, D-08).
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

import 'wall_faces.dart';

/// The target kind the kit's symbols name in `attachTo`.
const String kWallFaceKind = 'wall-face';

/// The kit's provider for [services]' document: one per document, made by
/// the plan library from the kit's `attachments` (spec 2a P1, lifetimes).
AttachmentProvider wallFaceProvider(PlanServices services) =>
    _WallFaceProvider(services);

final class _WallFaceProvider implements AttachmentProvider {
  _WallFaceProvider(this._services);

  final PlanServices _services;

  @override
  String get kind => kWallFaceKind;

  /// [attachToWall] for the query's pointer over the document's faces, its
  /// footprint read as the symbol's box (front `minY`, back `maxY`, the
  /// inverse of `footprintOf`). The marker is the face point the symbol's
  /// back-centre lands on; the token is the run. Null for an empty
  /// footprint, for no face within the capture, for a query excluding
  /// more than one object (no caller asks it), and under `mayRotate:
  /// false` for a face the symbol's current turn does not face.
  @override
  Attachment? attach(AttachmentQuery query) {
    final f = query.footprint;
    if (f.isEmpty) return null;
    final exclude = query.exclude;
    if (exclude.length > 1) return null;
    final a = wallFacesOf(_services).attach(
      _services.document,
      SymbolBox(left: f.minX, right: f.maxX, front: f.minY, back: f.maxY),
      query.pointer,
      query.capture,
      mirrored: query.mirrored,
      edgeCaptureWorld: query.edgeCapture,
      exclude: exclude.isEmpty ? null : exclude.single,
      keep: query.mayRotate ? null : query.current,
    );
    if (a == null) return null;
    return Attachment(transform: a.transform, marker: a.q, token: a.run);
  }
}
```

- [ ] **Step 9: The kit.** In `packages/jet_cad_2d_kit_architecture/lib/src/kit.dart` add `import 'attach/wall_face_provider.dart';` and `import 'furniture/furniture_source.dart';`, and give `architectureKit` `symbols: [furnitureSource],` and `attachments: [wallFaceProvider],` (Task 23's plan decision: the source and the provider land together).

- [ ] **Step 10: The integration test.** Create `packages/jet_cad_2d_integration/test/furniture/furniture_load_test.dart`:

```dart
// 3a Tasks 23-24 (spec C4, C5, C6): the kit's furniture library loads in a
// plan from the package's asset key, named in the kit's words, and its
// wall-face kind is offered.
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d_integration/jet_cad_2d_integration.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart'
    show KitDiagnosticCode, SymbolsState;
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

/// Lets the library's load (a real asset read through the test binding,
/// then a decode) finish: polls [c]'s state, at most about half a second.
/// The plan library's own `settle` (twenty zero delays,
/// `test/support/symbol_fixtures.dart:248-252`) serves in-memory reads only.
Future<void> settle(PlanController c) async {
  for (var i = 0;
      i < 500 && c.symbolsState.value == SymbolsState.loading;
      i++) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'FU-load the furniture library loads from the kit\'s package key: 41 '
      'symbols of the kit, architecture.*@1 in catalog order, named in '
      'German and Turkish by the kit\'s words; no library diagnostic',
      () async {
    final c = architectureController();
    addTearDown(c.dispose);
    await settle(c);
    expect(c.symbolsState.value, SymbolsState.ready);
    final ids = [for (final s in c.symbols) s.id];
    expect(ids, hasLength(41));
    expect(ids.first, 'architecture.dining.table.square.two@1');
    expect(ids.last, 'architecture.office.bookshelf@1');
    expect(ids.every((id) => id.startsWith('architecture.') && id.endsWith('@1')),
        isTrue);
    expect({for (final s in c.symbols) s.kitId}, {'architecture'});
    final bed = c.symbolById('architecture.bed.double@1')!;
    expect(bed.names.symbolName('de', bed.component), 'Doppelbett');
    expect(bed.names.symbolName('tr', bed.component), 'Çift kişilik yatak');
    expect(
        bed.names.categoryName('de', 'architecture', bed.component.category),
        'Schlafzimmer');
    expect([
      for (final d in c.diagnostics.value)
        if (d.code == KitDiagnosticCode.libraryUnreadable ||
            d.code == KitDiagnosticCode.libraryKitMismatch ||
            d.code == KitDiagnosticCode.symbolDuplicate)
          d.code,
    ], isEmpty);
  });

  test(
      'WF-offered every attachment kind the library names is offered: no '
      'attachmentKindUnoffered once the symbols load', () async {
    final c = architectureController();
    addTearDown(c.dispose);
    await settle(c);
    expect(c.symbolsState.value, SymbolsState.ready);
    expect(c.symbols.where((s) => s.component.attachTo.contains('wall-face')),
        hasLength(30),
        reason: 'premise: the library names wall-face');
    expect([
      for (final d in c.diagnostics.value)
        if (d.code == KitDiagnosticCode.attachmentKindUnoffered) d.subject,
    ], isEmpty);
  });
}
```

  The integration pubspec lists `jet_cad_2d_kit` (R-P6, Task 9), so the import above resolves; `SymbolsState` comes from both imports (the plan re-exports it, `jet_cad_2d_plan.dart:8`), which is no conflict, and the plan import is needed for `PlanController`. Only if the pubspec somehow lacks it: import `KitDiagnosticCode` and `SymbolsState` from where its public libraries re-export them (`SymbolsState` is the plan's export, `jet_cad_2d_plan.dart:8`); `KitDiagnosticCode` needs the contract: add `jet_cad_2d_kit: ^0.1.0` to its dependencies and run `flutter pub get` from the root (then `git status --short`, restore any rewritten `analysis_options.yaml`).

- [ ] **Step 11: Run the tests, see them pass.**
  - `cd packages/jet_cad_2d_kit_architecture && flutter test test/attach/` → `All tests passed!`; then `flutter test` → `All tests passed!`.
  - `cd packages/jet_cad_2d_integration && flutter test --enable-vmservice test/furniture/` → `All tests passed!`; then `flutter test --enable-vmservice` → `All tests passed!` (every earlier integration test now loads the library: any that goes red is a finding; quote it and stop).

- [ ] **Step 12: Format and the gates.**
  - `cd packages/jet_cad_2d_kit_architecture && dart format . && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .`
  - `cd packages/jet_cad_2d_integration && dart format . && flutter test --enable-vmservice && flutter analyze && dart format --output=none --set-exit-if-changed .`
  - From the root: `dart run tool/ci/check_kit_deps.dart` → exit 0.
  - `git status --short`: only this task's files.

- [ ] **Step 13: Commit.**

```bash
git add packages/jet_cad_2d_kit_architecture/lib/src/attach/wall_attach.dart packages/jet_cad_2d_kit_architecture/lib/src/attach/wall_faces.dart packages/jet_cad_2d_kit_architecture/lib/src/attach/wall_face_provider.dart packages/jet_cad_2d_kit_architecture/lib/src/kit.dart packages/jet_cad_2d_kit_architecture/test/support/wall_attach_fixture.dart packages/jet_cad_2d_kit_architecture/test/attach/wall_faces_test.dart packages/jet_cad_2d_kit_architecture/test/attach/wall_face_provider_test.dart packages/jet_cad_2d_integration/test/furniture/furniture_load_test.dart
git commit -m "$(cat <<'EOF'
feat(architecture): the wall-face provider (3a C5)

Today's face runs and attachment rule move into the kit over its live
walls; WallFaces is the kit's shared cache and also keeps the document's
command state, since a plan tool no longer invalidates the bands after a
placement. The provider answers the plan's queries with today's capture
(one capture, kept or not), keeps the turn under rotate refused, and
offers no face of a hidden, locked or frozen wall. The furniture library
and the provider join the kit together; WF1-WF9 are ported.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

  (Add `packages/jet_cad_2d_integration/pubspec.yaml` and the root `pubspec.lock` only if Step 10 changed them.)

- [ ] **Step 14: Mutation check** (committed files only; after each: run the named test, see it red, quote the red line, then `git checkout -- <file>` and `git diff --quiet -- <file>` must exit 0; paths under `packages/jet_cad_2d_kit_architecture/`):
  - M-WF1 `lib/src/attach/wall_face_provider.dart`: `front: f.minY, back: f.maxY` → `front: f.maxY, back: f.minY` → WF-query red.
  - M-WF2 same file: `marker: a.q` → `marker: query.pointer` → WF-query red.
  - M-WF3 same file: `keep: query.mayRotate ? null : query.current` → `keep: null` → WF-keep red.
  - M-WF4 same file: `query.capture,` → `query.keep == null ? query.capture : query.capture * 10 / 16,` (the test kit's inverted hysteresis) → WF-hysteresis red.
  - M-WF5 same file: `exclude: exclude.isEmpty ? null : exclude.single` → `exclude: null` → WF-exclude red.
  - M-WF6 same file: delete `if (exclude.length > 1) return null;` → WF-exclude red (`single` of two throws).
  - M-WF7 `lib/src/attach/wall_faces.dart`: in `wallFacesOf`, delete `, accept: isUsableHost` → WF-hidden red.
  - M-WF8 same file: delete the line `if (identical(doc, _document) && state != _state) bands.invalidate();` → WF-state red.
  - M-WF9 same file: in `_refresh`, iterate every handle carrying `WallParams` instead of the bands' live walls (`for (final h in [...doc.components.withComponent<WallParams>()]..sort((a, b) => a.value.compareTo(b.value)))`, keeping the `bands.liveWalls(doc)` call above for the generation) and pass `(x) => doc.components.get<WallParams>(x) == null ? null : ArchitectureTypes.wall` to `faceRunsOf` in place of `live` (import `../ids.dart`) → WF-frozen red.
  - M-WF10 `lib/src/attach/wall_attach.dart`: in `faceRunsOf`, delete `if (accept != null && !accept(doc, wall)) return const [];` → WF7 red.
  - M-WF11 `lib/src/kit.dart`: delete `attachments: [wallFaceProvider],` → WF-offered red (integration).
  - M-WF12 `lib/src/kit.dart`: delete `symbols: [furnitureSource],` → FU-load red (integration).

#### Assumed from earlier tasks

Each name is used as written; where the earlier task named it otherwise, use that task's name and report the difference.
- Task 9: `lib/src/live.dart` with `typedef LiveTypeOf = String? Function(Handle handle)` and `LiveTypeOf liveTypesOf(PlanServices services)`; `lib/src/ids.dart` with `ArchitectureTypes`; `lib/src/kit.dart` with `final PlanKit architectureKit`.
- Task 11: `lib/src/wall/wall_bands.dart`: `WallBands` with today's `liveWalls(DraftDocument)`, `generation`, `invalidate()` (`jet_cad_floor_plan/lib/src/parametric/wall_bands.dart:24-60`) and `WallBands wallBandsOf(PlanServices s)`; `lib/src/wall/wall.dart`: `WallParams`, `Justification`, `wallJoin`; `test/support/wall_fixture.dart` with today's helpers (`jet_cad_floor_plan/test/support/wall_fixture.dart`).
- Task 11: `lib/src/wall/wall_geometry.dart`: `wallsInDocument(DraftDocument doc, Handle host, LiveTypeOf live, {Map<Handle, WorldWall> moved})` (R-P8, R-P17). Task 13: `lib/src/opening/opening_geometry.dart`: `hostFrameInDocument(DraftDocument doc, Handle host, LiveTypeOf live)`, `layoutInDocument(DraftDocument doc, Handle host, LiveTypeOf live, {moved})`; `hostFrameOf`, `obstaclesOf` unchanged (they take `WorldWall`s).
- Task 15: `lib/src/opening/opening_tool.dart`: `bool isUsableHost(DraftDocument doc, Handle wall)`, today's.
- Task 20: `test/support/dimension_fixture.dart` with today's `c11`, `docOfWalls`, `scaledGroups` (`jet_cad_floor_plan/test/support/dimension_fixture.dart:161-240`); if Task 20 did not port them, port those three (and `far`, `turnedAbout`, `c11Hub` they use) into it here, unchanged.
- Task 6: `FakePlanServices(document:, catalog:, frozen:, scale:)`, `liveTypeIdOf`, `shared`, `dispose()`.

#### Interface problem

**(Resolved by rulings R-P1 and R-P3: Task 28 ports both files into the kit.)** D-01's `wall_attach_test.dart` (23) and `wall_attach_property_test.dart` (2) cannot run in `jet_cad_2d_integration`, where spec C5 and Appendix A place them ("they call `placeSymbol`"). Besides `placeSymbol` (plan-internal and not exported: `packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart` has no placer export; `lib/src/symbols/symbol_placer.dart:169`), they name the kit's internals `attachToWall`, `FaceRun`, `faceRunsOf`, `WallBands` and `WallFaces` (`jet_cad_floor_plan/test/symbols/wall_attach_test.dart:13-19, 119, 358-374, 526-625`), which live under `lib/src/` and are not in the kit's public surface (spec C2); the integration package may import public libraries only. Proposed fix: Task 28 ports both files **into the kit** (`test/attach/`), placing through Task 23's `test/support/place_entry.dart` and building `WallBands`/`WallFaces` as this task's tests do (`WallFaces(bands, liveOf(doc))`), assertions unchanged; `symbol_move_test` (`PlanMoveResolver`) stays in the integration package, driven through `plan.select` on a `PlanCanvas`.

#### New shared name

- `List<FaceRun> faceRunsOf(DraftDocument doc, Handle wall, LiveTypeOf live, {bool Function(DraftDocument, Handle)? accept})` and `WallFaces(WallBands bands, LiveTypeOf live, {bool Function(DraftDocument, Handle)? accept})` (`lib/src/attach/`): today's names with the kit's reader added (C1.5); Task 28's ports call them so.
- `const String kWallFaceKind = 'wall-face'` (`lib/src/attach/wall_face_provider.dart`).
- Test support (`test/support/wall_attach_fixture.dart`): today's scenes (`attachScene`, `freeWallScene`, `lScene`, `teeScene`, `crossScene`, `shortBaseScene`, `farAt`, `attachGroup`, `attachAngles`, …) and the re-exports of `wall_fixture.dart`'s `liveOf` and `testCatalog` (R-P13, R-P17). Task 28 uses them.

---

