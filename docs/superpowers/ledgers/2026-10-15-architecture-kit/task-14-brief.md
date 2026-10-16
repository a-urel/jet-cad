### Task 14: The opening type, grips and properties (spec C3.3, C1.1, C1.7, C1.10, C6, C7)

**Files:**
- Create (`packages/jet_cad_2d_kit_architecture/`):
  - `lib/src/opening/opening_grips.dart` (ported: `OpeningGrips`, the slide grip)
  - `lib/src/opening/opening_plan.dart` (new: `openingPlanType`, `openingTitle`, `openingWidthOf`, `openingPositionRange`, `openingGripsOf`)
  - `lib/src/type_naming.dart` (new, R-P19: `kitTypeIdOf`, the engine's naming rule over the kit's raw type registrations; Tasks 16, 18 and 20 append theirs)
  - `test/opening/opening_object_test.dart`, `opening_grips_test.dart`, `opening_end_drag_test.dart` (ported; `opening_grips_test.dart` also carries the new OT-grips)
  - `test/opening/opening_plan_test.dart` (new: OT-title, OT-fields, OT-width, OT-range, OT-flip, OT-kit)
- Modify (`packages/jet_cad_2d_kit_architecture/`):
  - `lib/src/kit.dart` (`types:` gains `openingPlanType` right after `wallPlanType`)
  - `lib/src/wall/wall_grips.dart` (08 D13's "openings stay put": `_keptPut`, `_seated`, in `drag`'s compound)
- Create (`packages/jet_cad_2d_integration/`):
  - `test/support/opening_support.dart` (the editor harness over `architectureController` and the opening oracles, copied: the kit's test support is not importable)
  - `test/opening/opening_panel_test.dart` (ported OS1, OS2, OS4; new OT-panel-range)
  - `test/opening/opening_grips_test.dart` (ported SG1 (shell), SG2, SG4)
  - `test/opening/opening_kink_test.dart` (ported KJ4, KJ5)
  - `test/opening/opening_paint_test.dart` (ported RD1)
  - `test/opening/opening_symbol_test.dart` (ported OR8)
  - `test/opening/opening_frozen_test.dart` (new: OT-frozen-host)

**Interfaces:**
- Consumes:
  - Task 2: `PlanObject` (`document`), `LengthProperty(range:)`, `ActionProperty(visible:)`, `PropertySpec.visible`, `PropertyField.visible`, `PlanType.fieldsOf(DraftDocument, Handle, PlanWords)`, `PlanType.commitField(DraftDocument, Handle, PropertyField, Object?, PlanWords)` (R-P4, R-P7; the range checked on commit: a value outside is an `ArgumentError`), the panel's `TextDisplay`-free path unchanged; an `ActionProperty` whose gate the host refuses is hidden (C1.7).
  - Task 6: `PlanServices.liveTypeIdOf`; `FakePlanServices({required DraftDocument document, ParametricCatalog? catalog, Set<Handle> frozen, double scale, bool objectSnap, …})` and `dispose()` (`package:jet_cad_2d_kit/testing.dart`).
  - Task 7: the lock set locks the live objects a frozen object references (C1.10); `PlanController.execute` answers false and sets `lockHint` on `PlanLocked`.
  - Task 9: `ArchitectureTypes`, `ArchitectureTools`, `LiveTypeOf`, `liveTypesOf(PlanServices)`, `architectureKit` (`lib/src/kit.dart`), the words `tool:architecture.{door,window,gap}`, `property:architecture.opening.{width,position,flip-hinge,flip-swing}`; integration: `architectureController({String? json, PlanPermissions permissions})`, `planEditorApp(PlanController controller, {Locale locale})`.
  - Task 10: `BoxParams`, `boxPlanType` (OS1's box, OD1-like hosts).
  - Tasks 11-12: `WallParams`, `Justification`, `wallJoin`, `WorldWall`, `wallsInDocument` (`wall_geometry.dart`), `WallGrips({required LiveTypeOf live})` (`wall_grips.dart`), `wallPlanType`; the kit's test support `wall_fixture.dart` (`testCatalog`, `wallDoc`, `addWall`, `addWallLocal`, `groupAt`, `plan`, `polar`, `ox`, `oy`, `nextUp`, `kids`, `kindOf`, …) and `wall_shell.dart` (`xy`, `walls`, `expectMitre`, `expectSquare`).
  - Task 13: `OpeningParams`, `OpeningKind`, `HingeEnd`, `SwingSide`, `OpeningType`, `isOpeningWidth`, `layoutOf`, `layoutInDocument`, `openingsInDocument`, `cutsOf`, `placeCut`, `storedCentreOf`, `edgeSnap`, `Cut`, `HostLayout`; the kit's `test/support/opening_fixture.dart` (`liveOf`, `addOpening`, `oracleFrameOf`, `oracleAt`, `OpeningOracle`, …).
  - Engine: `kSnapAperturePixels` (`index/drag_snap.dart:14`), `ParametricCatalog.typeIdOf`. Flutter layer: `ObjectGripProvider`, `Grip`, `GripRole`, `GripDrag`, `GripCache`, `InteractionLayer`, `SelectionKey`.
- Produces (internal to the kit; Task 15 uses `openingWidthOf`):

```dart
// lib/src/opening/opening_grips.dart — today's class, the live answer added
final class OpeningGrips implements ObjectGripProvider {
  OpeningGrips({required this.live, double? Function()? edgeAperture});
  final LiveTypeOf live;
  final double? Function() edgeAperture;
}
// lib/src/opening/opening_plan.dart
final PlanType<OpeningParams> openingPlanType;           // Shared interfaces (Task 14)
String openingTitle(OpeningParams o);                   // 'tool:architecture.<kind>'
double openingWidthOf(OpeningKind kind, double w);      // w, or ArgumentError
(double, double)? openingPositionRange(OpeningParams o, PlanObject object);
ObjectGripProvider openingGripsOf(PlanServices services);
// lib/src/type_naming.dart (R-P19; Tasks 16, 18, 20 append their registration)
String? kitTypeIdOf(CommandTarget target, Handle group);
```

**Appendix A rows closed:** D-19's opening type files: `opening_object_test` (5: OR1, OR2, OR4, OR5, DF1), `opening_grips_test` (10: SG1 provider, SG1 apertureDir, SG5, SG3, SG3 old D13, SG6, SG7 in the kit; SG1 (shell), SG2, SG4 in C6), `opening_end_drag_test` (10: EP1-EP4, EP5, EP5 (start), EP6-EP9), `opening_paint_test` (1: RD1, C6), `opening_panel_test` (3 of 5 in C6: OS1, OS2, OS4; OS1 (runtime) and OS3 need the opening tools: Task 15), `opening_kink_test` KJ4, KJ5 (C6, from Task 13's R13-3), `opening_symbol_test` OR8 (C6, from R13-3). 32 of the opening's 85 cases. C1.10's opening user (OT-frozen-host). Contributes to D-46 (a section titled by `title`, `ActionProperty` exercised through the real kit; Task 27 closes the row) and D-48 (the grips and the panel section derived from the kit's hooks; Task 26 closes the row).

**Plan rulings (this task):**
- **R14-1 (C1.1, "is the host a wall").** Today's position check asks `isLiveObject<WallParams>(doc, o.host)` over the global catalog (`selection_panel.dart:425-430`): a group carrying `WallParams` that a later-registered type names (EG9's shadow, `wall_grips_test.dart:655-756`) is no wall, and every position of an opening on it is refused. A `range` sees a `PlanObject` only (document, handle, world), no services. `openingPositionRange` therefore asks the engine's naming rule (`ParametricCatalog.typeIdOf`) of a catalog the kit builds lazily from its own raw type registrations, in today's order (ruling R-P19: `lib/src/type_naming.dart`'s `kitTypeIdOf`, a kit-internal list, not `architectureKit.types`, so no import cycle through `kit.dart`; only the naming rule is read, no hook runs). The plan registers every loaded kit's types in load order, and Tasks 16, 18 and 20 append the separator, the room and the dimension to the list, so for a plan of this kit this answers exactly as the plan's catalog does; it answers a frozen wall's id too, as the panels' `typeIdOf` does (spec C1.5: "the panels, gates and colour row keep using that one"). A frozen host's opening is then refused by the engine on commit (`DanglingReferenceError`, caught by `PlanController.execute`): the same revert. See "Interface problem" for the alternative.
- **R14-2 (L).** `L` is the host's centreline length in its own group-local space, `(host.end - host.start).length` (today's `:428-429`), not its world length: a host in a scaled group keeps today's bound.
- **R14-3 (the fields).** The Opening section's fields, in today's order (`selection_panel.dart:1338-1371`): `width` (`LengthProperty`, `write` through `openingWidthOf`: strict `isOpeningWidth` by kind, an `ArgumentError` the panel turns into a revert), `position` (`LengthProperty`, `range: openingPositionRange`), `flip-hinge` and `flip-swing` (`ActionProperty`, `visible` for doors only). All four have `gate: PlanGate.reshape` (today's `_capable`: a field or button needs the host's `reshape`, `:384-391`; the flips are hidden without it, S-11, and C1.7 now hides an `ActionProperty` whose gate the host refuses). The title is `title: openingTitle` (`tool:architecture.{door,window,gap}`, today's `_titleOf`, `:754-758`). No `colour`, no `section`; `exported` stays true.
- **R14-4 (the grips).** `grips: openingGripsOf`: `OpeningGrips(live: liveTypesOf(services), edgeAperture: () => services.objectSnap ? kSnapAperturePixels / services.camera.value.scale : null)`, today's shell factory (`planner_shell.dart:649-652`) over the services. `OpeningGrips.movable` stays today's (false for an opening).
- **R14-5 (D13 lands here).** 08 D13's "openings stay put" (`wall_grips.dart:27-33, 64-131`) names `OpeningParams`, so Task 12's `WallGrips` cannot carry it (Task 13's "Interface problem"); this task adds it, reading live openings through `WallGrips.live`, with the tests that pin it (`opening_end_drag_test`, `opening_object_test`'s DF1).
- **R14-6 (C7 placement, R-P1).** Kit: every case of `opening_object_test`, `opening_end_drag_test`, and `opening_grips_test`'s seven `test(` cases (they use kit internals: `OpeningGrips`, `WallGrips`, `layoutInDocument`). C6: the cases that pump `PlannerShell` today (SG1 (shell), SG2, SG4, RD1, KJ4, KJ5, OR8) and every `opening_panel_test` case; they run over `architectureController` in `PlanEditor` (`planEditorApp`) and name no kit internal: only the kit's barrel (`architectureKit`, `ArchitectureTypes`, `OpeningParams`, `OpeningKind`, `HingeEnd`, `SwingSide`, `WallParams`, `Justification`, `BoxParams`) and test-local oracle copies (R14-9). The two kit internals they read today are reached otherwise (R-P1's rewrite, as rulings): KJ4's `hostFrameInDocument` through the oracle's span and KJ5's `worldWallOf` through `worldEndsOf` (R14-9).
- **R14-7 (SG6's composite).** SG6 (`opening_grips_test.dart:602-651`) drives today's composite `ObjectGrips`, now the plan library's grip dispatch (spec 2a E1). In the kit it drives a test-local `_Dispatch` that hands an opening to `OpeningGrips`, a wall to `WallGrips` and anything else to no provider (movable by default, as the composite, `object_grips.dart:102-104`): a fixture standing in for the plan's dispatch; its assertions (the box moves, the door is skipped, a rotate is offered, `movable` per object) are unchanged. The other kit cases' `ObjectGrips(edgeAperture: x)` becomes `OpeningGrips(live: liveOf(doc), edgeAperture: x)`: for an opening and a wall the composite answered what `OpeningGrips` answers (`movable(doc, wall)` is true in both).
- **R14-8 (the integration harness reads plan internals).** The C6 ports read what today's tests read from `PlannerView` (`selection`, `grips`, `camera`): on `PlanController` these are `@internal` (`selection`, `grips`, `toolContext`, `frozen`, `toolFor`, `servicesOf`). The package imports only public libraries (C6, `implementation_imports`); an `@internal` member read from another package is the analyzer's `invalid_use_of_internal_member` warning, so each C6 file that reads one starts with `// ignore_for_file: invalid_use_of_internal_member` — the plan library's own tests read the same members. The camera is today's (rotated 0.35 rad, set through `toolContext.camera`, as the plan's own `useTestCamera` does).
- **R14-9 (oracles in C6).** The kit's `test/support/` is not importable from the integration package. `opening_support.dart` copies today's oracles (`opening_fixture.dart:24-786`, `wall_fixture.dart`'s document helpers) and `wall_geometry.dart`'s `signedArea`/`isSimpleCcw` (the one implementation predicate the oracle uses, `storedPiecesSimpleCcw`); none calls the kit's geometry. KJ4's `hostFrameInDocument(doc, hA)!.uE` (the kit's, internal) becomes `OpeningOracle(doc).span(hA).$2`, the oracle's straight-span end read off the stored uncut outline (today's OT1 already compares against it): the asserted value (the window flush against A's straight-span end within 1e-6) is unchanged. If the two differ by more than 1e-6 at the kink, it is a finding: stop and report it. KJ5's `worldWallOf` (it builds the kit's `WorldWall`) becomes `worldEndsOf`, the same world `s`, `e` and `d` written out.
- **R14-10 (finders, C7 class 3).** `Key('opening-section')` → `Key('section-architecture.opening')`; `Key('opening-width')` → `Key('property-width')`; `Key('opening-position')` → `Key('property-position')`; `Key('opening-flip-hinge')` → `Key('property-flip-hinge')`; `Key('opening-flip-swing')` → `Key('property-flip-swing')`; `Key('wall-section')` → `Key('section-architecture.wall')`; `Key('box-width')` → `Key('section-architecture.box')` (the box's section; its width field is `property-width`, the same key as the opening's); the tools' palette keys `tool-door` → `tool-architecture.door` (Task 15). The asserted values do not change. The panel reads a section title from the kit's words: `'Door'`, `'Window'`, `'Gap'` are the English `tool:` words (Task 9), today's.

- [ ] **Step 1: Precondition.** Tasks 2, 6, 7, 9-13 are committed. `cd packages/jet_cad_2d_kit_architecture && flutter test` and `cd packages/jet_cad_2d_integration && flutter test --enable-vmservice`: `All tests passed!`. `grep -n "_keptPut\|OpeningParams" packages/jet_cad_2d_kit_architecture/lib/src/wall/wall_grips.dart`: no match (R14-5). `grep -n "LiveTypeOf _live\|LiveTypeOf live" packages/jet_cad_2d_kit_architecture/lib/src/wall/wall_grips.dart`: `WallGrips`'s constructor parameter and its private field `_live`. Any other result is a finding: stop and report it.

- [ ] **Step 2: The failing kit tests (new).** Create `packages/jet_cad_2d_kit_architecture/test/opening/opening_plan_test.dart`:

```dart
// Spec 3a C3.3, C1.1, C1.7: the opening's PlanType. Its section title by
// kind; its fields over the object (the width strict by kind, the position
// within its host wall's centreline, [0, L], the flips a door's), each
// gated by reshape; its place in the kit. Today's selection panel's Opening
// section is the oracle (jet_cad_floor_plan/lib/src/selection_panel.dart:
// 405-433, 754-758, 1035-1059, 1332-1371).
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_kit_architecture/src/box/box.dart';
import 'package:jet_cad_2d_kit_architecture/src/ids.dart';
import 'package:jet_cad_2d_kit_architecture/src/kit.dart';
import 'package:jet_cad_2d_kit_architecture/src/opening/opening.dart';
import 'package:jet_cad_2d_kit_architecture/src/opening/opening_plan.dart';
import 'package:jet_cad_2d_kit_architecture/src/wall/wall.dart';

import '../support/opening_fixture.dart';
import '../support/wall_fixture.dart';

const hA = Handle(1000), hBox = Handle(1500);
const hD = Handle(4000), hW = Handle(4100), hG = Handle(4200);
const hQ = Handle(4300), hR = Handle(4400);

/// A (4,000 long in its own space, 200 centred) in a group turned 0.6 rad
/// and scaled 1.25 at the far origin, so its world length (5,000) is not
/// its local one. On it: a door D (hinge end, swing right) in its own
/// turned group, a window W and a gap G. A box, and Q, a window the box
/// hosts. R, a window hosted by D after D was given a `WallParams` straight
/// into the store, as a file brings one in: a group carrying two
/// registered types is the later registration's object, an opening
/// (fix/live-object-rule), so R's host is no wall.
DraftDocument planDoc() {
  final doc = wallDoc();
  doc.commands.execute(addWallLocal(
      doc,
      hA,
      const WallParams(0, 0, 4000, 0, 200, Justification.centre),
      Transform2.translation(ox + 300.5, oy - 700.25)
          .multiply(Transform2.rotation(0.6))
          .multiply(Transform2.scale(1.25, 1.25))));
  doc.commands.execute(addOpening(
      doc,
      hD,
      const OpeningParams(hA, 1500, 900, OpeningKind.door,
          hinge: HingeEnd.end, swing: SwingSide.right),
      at: Transform2.translation(ox + 120, oy - 80)
          .multiply(Transform2.rotation(0.9))));
  doc.commands.execute(addOpening(
      doc, hW, const OpeningParams(hA, 3000, 800, OpeningKind.window)));
  doc.commands.execute(
      addOpening(doc, hG, const OpeningParams(hA, 600, 700, OpeningKind.gap)));
  doc.commands.execute(CompoundCommand([
    AddNodeCommand(GroupNode(
        handle: hBox,
        parent: doc.rootHandle,
        transform: groupAt(hBox.value),
        children: const [])),
    SetComponentCommand<BoxParams>(hBox, const BoxParams(1200, 800)),
  ], label: 'Add box'));
  doc.commands.execute(addOpening(
      doc, hQ, const OpeningParams(hBox, 300, 600, OpeningKind.window)));
  doc.components.attach<WallParams>(
      hD, const WallParams(0, 0, 3000, 0, 150, Justification.centre));
  doc.commands.execute(
      addOpening(doc, hR, const OpeningParams(hD, 500, 600, OpeningKind.window)));
  return doc;
}

/// The panel's words (English, no kit words: the fields read none).
final KitWords words = KitNamesWords(KitNames.empty, () => const Locale('en'));

PropertyField fieldOf(DraftDocument doc, Handle h, String id) =>
    openingPlanType.fieldsOf(doc, h, words).firstWhere((f) => f.spec.id == id);

/// What committing [input] through [h]'s field [id] would store.
OpeningParams committed(
        DraftDocument doc, Handle h, String id, Object? input) =>
    (openingPlanType.commitField(doc, h, fieldOf(doc, h, id), input, words)
            as SetComponentCommand<OpeningParams>)
        .value!;

OpeningParams stored(DraftDocument doc, Handle h) =>
    doc.components.get<OpeningParams>(h)!;

void main() {
  test(
      'OT-title (spec 3a C3.3) an opening\'s section is titled by its '
      'kind, with its tool\'s word', () {
    final doc = planDoc();
    expect([
      for (final h in [hD, hW, hG]) openingPlanType.titleWordOf(doc, h)
    ], [
      'tool:architecture.door',
      'tool:architecture.window',
      'tool:architecture.gap',
    ]);
  });

  test(
      'OT-fields (spec 3a C3.3, R14-3) width, position, flip hinge, flip '
      'swing, in that order, each under its property word and gated by '
      'reshape; width and position read the stored values', () {
    final doc = planDoc();
    final fields = openingPlanType.fieldsOf(doc, hD, words);
    expect([for (final f in fields) f.spec.id],
        ['width', 'position', 'flip-hinge', 'flip-swing']);
    expect([for (final f in fields) f.wordId], [
      'property:architecture.opening.width',
      'property:architecture.opening.position',
      'property:architecture.opening.flip-hinge',
      'property:architecture.opening.flip-swing',
    ]);
    expect([for (final f in fields) f.spec.gate],
        List.filled(4, PlanGate.reshape));
    expect([fields[0].value, fields[1].value], [900.0, 1500.0]);
  });

  test(
      'OT-width (spec 08 D6, 3a C3.3) the width is strict by kind: a gap\'s '
      'above 4 × wallJoin.linear, any other\'s above wallJoin.linear; not '
      'finite or not positive is refused', () {
    final doc = planDoc();
    expect(() => committed(doc, hG, 'width', 0.000004), throwsArgumentError);
    expect(committed(doc, hG, 'width', 0.000005).width, 0.000005);
    expect(() => committed(doc, hD, 'width', 0.000001), throwsArgumentError);
    expect(committed(doc, hD, 'width', 0.0000011).width, 0.0000011);
    for (final bad in [0.0, -40.0, double.nan, double.infinity]) {
      expect(() => committed(doc, hW, 'width', bad), throwsArgumentError,
          reason: '$bad');
    }
    expect(committed(doc, hW, 'width', 850.5),
        stored(doc, hW).copyWith(width: 850.5));
  });

  test(
      'OT-range (spec 3a C1.1, R14-1, R14-2) the position lies in [0, L], '
      'L the host\'s centreline length in its own space, both ends '
      'included; a host that is no wall refuses every position: a box, '
      'and an opening\'s group carrying WallParams', () {
    final doc = planDoc();
    final p = doc.components.get<WallParams>(hA)!;
    final l = (p.end - p.start).length;
    expect(l, 4000, reason: 'premise: L local');
    final m = doc.tree.accumulatedTransform(hA);
    expect((m.transformPoint(p.end) - m.transformPoint(p.start)).length,
        closeTo(5000, 1e-6),
        reason: 'premise: the world length differs');
    for (final v in [0.0, 1234.5, l]) {
      expect(committed(doc, hD, 'position', v), stored(doc, hD).copyWith(position: v),
          reason: '$v');
    }
    for (final v in [-1e-9, nextUp(l), 4500.0]) {
      expect(() => committed(doc, hD, 'position', v), throwsArgumentError,
          reason: '$v');
    }
    expect(testCatalog().typeIdOf(doc, hD), ArchitectureTypes.opening,
        reason: 'premise: D carries WallParams and is an opening');
    for (final h in [hQ, hR]) {
      for (final v in [0.0, 10.0, 300.0]) {
        expect(() => committed(doc, h, 'position', v), throwsArgumentError,
            reason: '$h at $v');
      }
    }
  });

  test(
      'OT-flip (spec 3a C1.7, 08 D16) the flips are a door\'s: shown for a '
      'door, hidden for a window and a gap; each turns its own field only',
      () {
    final doc = planDoc();
    expect([
      for (final h in [hD, hW, hG])
        for (final id in ['flip-hinge', 'flip-swing']) fieldOf(doc, h, id).visible
    ], [true, true, false, false, false, false]);
    expect([for (final id in ['width', 'position']) fieldOf(doc, hW, id).visible],
        [true, true]);
    final d0 = stored(doc, hD);
    expect(committed(doc, hD, 'flip-hinge', null),
        d0.copyWith(hinge: HingeEnd.start));
    expect(committed(doc, hD, 'flip-swing', null),
        d0.copyWith(swing: SwingSide.left));
    doc.commands.execute(SetComponentCommand<OpeningParams>(
        hD, d0.copyWith(hinge: HingeEnd.start, swing: SwingSide.left)));
    expect(committed(doc, hD, 'flip-hinge', null).hinge, HingeEnd.end);
    expect(committed(doc, hD, 'flip-swing', null).swing, SwingSide.right);
  });

  test(
      'OT-kit (spec 3a C2) the kit carries the opening type right after '
      'the wall\'s, in today\'s registration order, and validates', () {
    final ids = [for (final t in architectureKit.types) t.id];
    expect(ids.indexOf(ArchitectureTypes.opening),
        ids.indexOf(ArchitectureTypes.wall) + 1);
    expect(architectureKit.validate(), isEmpty);
  });
}
```

  The kit's `opening_grips_test.dart` (Step 4) ends with this new case, after SG7:

```dart
  test(
      'OT-grips (spec 3a C3.3, R14-4) the type\'s grip factory reads the '
      'services: with object snap on the slide grip edge-snaps within the '
      'snap aperture at the camera\'s scale (10 px at 0.5 px/mm: 20 mm), '
      'with it off it does not; the door is not movable', () {
    final doc = wallDoc();
    final s = addClampedDoor(doc);
    final (a, door, o1) = (s.a, s.door, s.o1);
    final f = oracleFrameOf(doc, a);
    final [(_, e0), _] = layoutInDocument(doc, a, liveOf(doc))!.stretches;
    final on = FakePlanServices(document: doc, catalog: testCatalog(), scale: 0.5);
    addTearDown(on.dispose);
    final off = FakePlanServices(
        document: doc, catalog: testCatalog(), scale: 0.5, objectSnap: false);
    addTearDown(off.dispose);
    final snapping = openingPlanType.gripsFor(on)!;
    final plain = openingPlanType.gripsFor(off)!;
    expect(snapping.movable(doc, door), isFalse);
    expect(snapping.movable(doc, a), isTrue, reason: 'control');
    final g = snapping.gripsOf(doc, door).single;
    // The right edge released 15 mm short of the obstacle's near edge:
    // inside 20 mm, so it snaps; 25 mm short: outside, the projection.
    final near = oracleAt(f, o1 - 450 - 15, 40);
    doc.commands.execute(snapping.drag(doc, door, g, near)!);
    expect(paramsOf(doc, door).position + 450, closeTo(e0, 1e-9),
        reason: 'snapped');
    doc.commands.undo();
    doc.commands.execute(plain.drag(doc, door, g, near)!);
    expect(paramsOf(doc, door).position, closeTo(o1 - 465, 1e-6),
        reason: 'object snap off: the projection');
    doc.commands.undo();
    doc.commands.execute(
        snapping.drag(doc, door, g, oracleAt(f, o1 - 450 - 25, 40))!);
    expect(paramsOf(doc, door).position, closeTo(o1 - 475, 1e-6),
        reason: '25 mm: beyond the aperture');
  });
```

  (`opening_grips_test.dart` imports `package:jet_cad_2d_kit/testing.dart` and `package:jet_cad_2d_kit_architecture/src/opening/opening_plan.dart` for it.)

- [ ] **Step 3: The failing integration tests (new).** In `packages/jet_cad_2d_integration/test/opening/opening_panel_test.dart` (Step 5 creates the file with the ported cases), append inside `main`:

```dart
  testWidgets(
      'OT-panel-range (spec 3a C1.1, Review Focus 4) a position typed past '
      'the host wall\'s length, or below 0, shows the stored value and adds '
      'no history and no diagnostic; L itself commits; an opening a box '
      'hosts refuses every position alike', (tester) async {
    late Handle a, door, box, onBox;
    final c = openingController(openingPlanText(shellPage, (d) {
      Handle next() => d.handleSeed.next();
      a = next();
      d.commands.execute(addWall(
          d, a, plan(0, 0), plan(6000, 0), 200, Justification.centre));
      door = next();
      d.commands.execute(addOpening(
          d,
          door,
          OpeningParams(a, 1730, 900, OpeningKind.door,
              hinge: HingeEnd.end, swing: SwingSide.right),
          at: doorGroup));
      box = next();
      d.commands.execute(CompoundCommand([
        AddNodeCommand(GroupNode(
            handle: box,
            parent: d.rootHandle,
            transform: groupAt(box.value),
            children: const [])),
        SetComponentCommand<BoxParams>(box, const BoxParams(1200, 800)),
      ], label: 'Add box'));
      onBox = next();
      d.commands.execute(addOpening(
          d, onBox, OpeningParams(box, 300, 600, OpeningKind.window)));
    }));
    await pumpEditor(tester, c, centre: plan(3000, 1400), scale: 0.15);
    final doc = c.document;
    final wall = doc.components.get<WallParams>(a)!;
    final l = (wall.end - wall.start).length;
    expect(c.diagnostics.value, isEmpty, reason: 'premise');

    await select(tester, c, [door]);
    final d0 = paramsOf(doc, door);
    for (final bad in ['${nextUp(l)}', '6000.5', '-0.5']) {
      await enterAndSubmit(tester, position, bad);
      expect(textOf(tester, position), '1730', reason: bad);
    }
    expect(paramsOf(doc, door), d0);
    expect(doc.commands.undoDepth, 0);
    expect(c.diagnostics.value, isEmpty);
    await enterAndSubmit(tester, position, '$l');
    expect(paramsOf(doc, door).position, l, reason: 'L itself: inclusive');
    expect(doc.commands.undoDepth, 1);
    doc.commands.undo();
    await tester.pump();

    await select(tester, c, [onBox]);
    expect(section, findsOneWidget);
    final o0 = paramsOf(doc, onBox);
    for (final v in ['0', '10', '300.5', '1730']) {
      await enterAndSubmit(tester, position, v);
      expect(textOf(tester, position), '300', reason: 'a box host: $v');
    }
    expect(paramsOf(doc, onBox), o0);
    expect(doc.commands.undoDepth, 0);
    expect(c.diagnostics.value, isEmpty);
  });
```

  Create `packages/jet_cad_2d_integration/test/opening/opening_frozen_test.dart`:

```dart
// Spec 3a C1.10 (decision 6): a frozen object's references are locked. A
// door whose type's code fails for it alone is frozen on load (spec 2a E2);
// its host wall then cannot be edited or deleted (PlanLocked, the lock
// hint), so it never regenerates uncut beside the frozen door or leaves the
// door naming a dead handle. A wall whose door is live edits as usual.
// ignore_for_file: invalid_use_of_internal_member
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';

import '../support/opening_support.dart';

/// The architecture kit, its opening type failing in `generate` for
/// [poisoned] alone, as a kit's code that breaks on one object does. The
/// rest is the kit's own.
PlanKit poisonedKit(Handle poisoned) => PlanKit(
      id: architectureKit.id,
      version: architectureKit.version,
      symbols: architectureKit.symbols,
      types: [
        for (final t in architectureKit.types)
          if (t.id == ArchitectureTypes.opening)
            PlanType<OpeningParams>(
                id: t.id,
                fromJson: OpeningParams.fromJson,
                parametric: _Poisoned(
                    t.parametric as ParametricType<OpeningParams>, poisoned))
          else
            t,
      ],
      tools: architectureKit.tools,
      attachments: architectureKit.attachments,
      names: architectureKit.names,
      prepare: architectureKit.prepare,
    );

final class _Poisoned extends ParametricType<OpeningParams> {
  const _Poisoned(this.inner, this.poisoned);

  final ParametricType<OpeningParams> inner;
  final Handle poisoned;

  @override
  Capability get editCapability => inner.editCapability;

  @override
  Aabb2 reach(OpeningParams params, Transform2 toWorld) =>
      inner.reach(params, toWorld);

  @override
  Iterable<Handle> references(OpeningParams params) =>
      inner.references(params);

  @override
  List<Generated> generate(ParametricView view, Handle self) {
    if (self == poisoned) throw StateError('the test\'s failing door');
    return inner.generate(view, self);
  }

  @override
  List<Diagnostic> diagnose(ParametricView view, Handle self) =>
      inner.diagnose(view, self);
}

void main() {
  testWidgets(
      'OT-frozen-host (spec 3a C1.10) a frozen door locks its host wall: an '
      'edit of the wall is refused with the lock hint and a delete is '
      'refused, the plan unchanged; a wall whose window is live edits in '
      'one step', (tester) async {
    late Handle a, door, b;
    final text = openingPlanText(shellPage, (d) {
      a = d.handleSeed.next();
      d.commands.execute(addWall(
          d, a, plan(0, 0), plan(5000, 0), 200, Justification.right));
      door = d.handleSeed.next();
      d.commands.execute(addOpening(
          d, door, OpeningParams(a, 1730, 900, OpeningKind.door),
          at: doorGroup));
      b = d.handleSeed.next();
      d.commands.execute(addWall(
          d, b, plan(0, 2500), plan(4000, 3100), 150, Justification.left));
      d.commands.execute(addOpening(d, d.handleSeed.next(),
          OpeningParams(b, 2000, 1200, OpeningKind.window)));
    });
    final c = PlanController(kits: [poisonedKit(door)], json: text);
    addTearDown(c.dispose);
    await pumpEditor(tester, c, centre: plan(2500, 1200), scale: 0.15);
    final doc = c.document;
    expect(c.frozen, {door}, reason: 'premise: the door alone, on load');
    expect([for (final d in c.diagnostics.value) d.code],
        contains(KitDiagnosticCode.hookFailed));
    final before = enc(doc);

    final pa = doc.components.get<WallParams>(a)!;
    expect(
        c.execute(SetComponentCommand<WallParams>(a, pa.copyWith(thickness: 250))),
        isFalse,
        reason: 'an edit of the frozen door\'s host');
    expect(c.lockHint.value, isTrue);
    expect(enc(doc), before);
    expect(doc.commands.undoDepth, 0);

    c.selection.replace([SelectionKey.root(a)]);
    await tester.pump();
    expect(c.deleteSelection(), isFalse, reason: 'a delete of it');
    expect(doc.tree[a], isNotNull);
    expect(enc(doc), before);

    final pb = doc.components.get<WallParams>(b)!;
    expect(
        c.execute(SetComponentCommand<WallParams>(b, pb.copyWith(thickness: 180))),
        isTrue,
        reason: 'control: a live door\'s host');
    expect(doc.components.get<WallParams>(b)!.thickness, 180);
    expect(doc.commands.undoDepth, 1);
  });
}
```

- [ ] **Step 4: The ported kit tests.** Every file keeps its cases' names, order and assertions (A12); each starts with `// Ported from jet_cad_floor_plan/test/<file> (spec 3a C3.3, C7).` above today's header. Imports follow Task 13's A13-imports (plus `…/wall_grips.dart` → `package:jet_cad_2d_kit_architecture/src/wall/wall_grips.dart`, `…/opening_grips.dart` → `…/src/opening/opening_grips.dart`, `'support/wall_shell.dart'` → `'../support/wall_shell.dart'`) and A13-live (the document adapters take `liveOf(doc)`), and:
  - **A14-grips:** `WallGrips()` → `WallGrips(live: liveOf(doc))`; `ObjectGrips(edgeAperture: x)` → `OpeningGrips(live: liveOf(doc), edgeAperture: x)` (R14-7); `OpeningGrips()` → `OpeningGrips(live: liveOf(doc))`.
  1. `test/opening/opening_object_test.dart` ← `opening_object_test.dart` (OR1, OR2, OR4, OR5, DF1): copy `:1-542` (the whole file); A14-grips at `:470`. Assertions unchanged.
  2. `test/opening/opening_end_drag_test.dart` ← `opening_end_drag_test.dart` (EP1, EP2, EP3, EP4, EP5, EP5 (start), EP6, EP7, EP8, EP9): copy whole; A14-grips at `:143`, `:214`, `:274`, `:400`, `:470`, `:549`, `:569`, `:641`, `:702`; A13-live at `:578`, `:652`, `:715`, `:748`, `:764`. Assertions unchanged (EP6's stray openings on a nested group and a node-less handle answer null from `liveOf(doc)`: left alone, as today).
  3. `test/opening/opening_grips_test.dart` ← `opening_grips_test.dart`: the header `:1-6`, the imports less `planner_shell.dart`, `planner_view.dart`, `catalog.dart`, `object_grips.dart`, `package:flutter/gestures.dart`, `package:flutter/material.dart`, `package:flutter/services.dart` and `dart:typed_data` (its one use, `Float64List` at `:581-584`, is SG4's, a C6 case; left in, `unused_import: error` fails the analyzer); `k`, `doorGroup`, `addClampedDoor`, `paramsOf` (`:29-63`) and `clamped` (`:162-164`); not the shell section `:65-160` (C6's, Step 5). Cases: SG1 provider (`:167`), SG1 apertureDir (`:282`), SG5 (`:454`), SG3 (`:481`), SG3 old D13 (`:505`), SG6 (`:602`), SG7 (`:653`), then OT-grips (Step 2). A14-grips at `:189`, `:316`, `:465`, `:495`, `:510`, `:535`, `:682`; A13-live at `:184`, `:489`, `:521`. SG6 (`:625`, `:634`, `:648`): `ObjectGrips(edgeAperture: () => null)` → `_Dispatch(doc)`, with, after `clamped`:

```dart
/// SG6's composite (R14-7): the plan library's grip dispatch (spec 2a E1)
/// over the kit's two providers, by the type id that names the group. A
/// group no provider takes (a box: it has no grips) is movable, as today's
/// composite's default (`object_grips.dart:102-104`).
final class _Dispatch implements ObjectGripProvider {
  _Dispatch(DraftDocument doc)
      : _live = liveOf(doc),
        _openings = OpeningGrips(live: liveOf(doc)),
        _walls = WallGrips(live: liveOf(doc));

  final LiveTypeOf _live;
  final OpeningGrips _openings;
  final WallGrips _walls;

  ObjectGripProvider? _of(Handle group) => switch (_live(group)) {
        ArchitectureTypes.opening => _openings,
        ArchitectureTypes.wall => _walls,
        _ => null,
      };

  @override
  List<Grip> gripsOf(DraftDocument d, Handle group) =>
      _of(group)?.gripsOf(d, group) ?? const [];

  @override
  DraftCommand? drag(DraftDocument d, Handle group, Grip grip, Vector2 world) =>
      _of(group)?.drag(d, group, grip, world);

  @override
  List<(EntityKind, GeometryPayload)> preview(
          DraftDocument d, Handle group, Grip grip, Vector2 world) =>
      _of(group)?.preview(d, group, grip, world) ?? const [];

  @override
  bool movable(DraftDocument d, Handle group) =>
      _of(group)?.movable(d, group) ?? true;
}
```

     (with the imports `package:jet_cad_2d_kit_architecture/src/ids.dart` and `…/src/live.dart`). Assertions unchanged.

  Write each file byte for byte from its source apart from the listed lines; check every non-ASCII literal with `grep -n` against the source.

- [ ] **Step 5: The integration support and the ported integration tests.**
  1. Create `packages/jet_cad_2d_integration/test/support/opening_support.dart`. It starts with:

```dart
// The opening's C6 harness (spec 3a C6, R14-8, R14-9): plans of the
// architecture kit built through a temporary parametric system and opened
// in a PlanController over the kit, PlanEditor pumped with today's rotated
// camera, and today's independent oracles (jet_cad_floor_plan/test/
// support/opening_fixture.dart), copied: they never call the kit's
// geometry. The kit's own test support is not importable; the wall fixture
// is Task 12's and the editor rig Task 9's, re-exported (R-P14).
// ignore_for_file: invalid_use_of_internal_member
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/gestures.dart' show PointerDeviceKind, kPrimaryButton;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:jet_cad_2d_integration/jet_cad_2d_integration.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'editor_rig.dart';
import 'wall_fixture.dart';

// The rig's helpers (R-P14) and Task 12's wall fixture (its owner), as the
// opening tests use them: no second copy here.
export 'editor_rig.dart'
    show activeTool, globalAt, globalOf, kitCatalog, press, pumpEditor, status;
export 'wall_fixture.dart'
    show addWall, addWallLocal, canon, diagnosticsOf, driftOf, enc, far,
        groupAt, kids, kindOf, nearestIn, nextUp, oracleMeet, ox, oy,
        payloadOf, plan, pointsOf, polar, worldOutline, xy;

/// Today's shell fixtures' page: 1:20 near the far origin, grid snap on at
/// 10 mm.
final PageComponent shellPage = PageComponent(
    scaleDenominator: 20,
    originX: ox - 2000,
    originY: oy - 2000,
    gridStepMm: 10);

/// The grid step of [shellPage].
const double gridStep = 10;

/// A plan of the architecture kit: [page] on its root, then what [build]
/// adds through a temporary parametric system over the kit's types (as
/// today's `shellDoc`: the objects regenerate as they are made), then what
/// [after] does with no system installed (OS4: a node removed without
/// cascading), saved with its manifest.
String openingPlanText(PageComponent page, void Function(DraftDocument d) build,
    {void Function(DraftDocument d)? after}) {
  final m = FlutterTextMeasurer();
  addTearDown(m.clear);
  final d = DraftDocument.empty(measurer: m);
  PageComponent.register(d.components);
  d.commands.execute(SetComponentCommand<PageComponent>(d.rootHandle, page));
  final system = ParametricSystem(d, kitCatalog())..install();
  try {
    build(d);
  } finally {
    system.dispose();
  }
  after?.call(d);
  return encodePlan(d, validateKitSet([architectureKit]));
}

/// A controller over [text] and the kit, disposed at tear-down.
PlanController openingController(String text) {
  final c = architectureController(json: text);
  addTearDown(c.dispose);
  return c;
}

/// [c]'s camera, today's `view.camera`.
CameraController cameraOf(PlanController c) => c.toolContext.camera;

Future<void> tapWorld(WidgetTester tester, PlanController c, Vector2 p,
    {bool shift = false}) async {
  if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  await tester.tapAt(globalAt(tester, c, p));
  if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  await tester.pump();
}

/// A mouse drag from world [from] to world [to], past the slop at once.
Future<void> dragWorld(
    WidgetTester tester, PlanController c, Vector2 from, Vector2 to) async {
  final a = globalAt(tester, c, from), b = globalAt(tester, c, to);
  final gesture = await tester.createGesture(
      kind: PointerDeviceKind.mouse, buttons: kPrimaryButton);
  await gesture.down(a);
  await gesture.moveTo(a + const Offset(12, 0));
  await gesture.moveTo(b);
  await gesture.up();
  await gesture.removePointer();
  await tester.pump();
}

Future<void> undoKey(WidgetTester tester) async {
  await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
  await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
  await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
  await tester.pump();
}

/// Today's `view.selection.replace`, then a frame.
Future<void> select(
    WidgetTester tester, PlanController c, List<Handle> hs) async {
  c.selection.replace([for (final h in hs) SelectionKey.root(h)]);
  await tester.pump();
}

/// The shown object grips of [h] (today's `view.grips!.grips`).
List<Grip> objectGripsOf(PlanController c, Handle h) => [
      for (final r in c.grips.grips)
        if (r.object && r.key == SelectionKey.root(h)) r.grip,
    ];

/// The page's grid point nearest [p], as the snap chain computes it.
Vector2 gridOf(DraftDocument doc, Vector2 p) => snapToGrid(
    p, gridStep, doc.components.get<PageComponent>(doc.rootHandle)!);

/// The door's own group: off the identity (today's `doorGroup`).
final Transform2 doorGroup = Transform2.translation(ox + 120, oy - 80)
    .multiply(Transform2.rotation(0.9));

/// Wall [h]'s world centreline, from its stored ends through its group's
/// accumulated transform, and its unit direction: what today's
/// `worldWallOf(doc, h)` gives as `s`, `e` and `d` (R14-9).
({Vector2 s, Vector2 e, Vector2 d}) worldEndsOf(DraftDocument doc, Handle h) {
  final p = doc.components.get<WallParams>(h)!;
  final m = doc.tree.accumulatedTransform(h);
  final s = m.transformPoint(p.start), e = m.transformPoint(p.end);
  return (s: s, e: e, d: (e - s).normalized());
}

// The panel's finders (R14-10).
Finder get section => find.byKey(const Key('section-architecture.opening'));
Finder get width => find.byKey(const Key('property-width'));
Finder get position => find.byKey(const Key('property-position'));
Finder get flipHinge => find.byKey(const Key('property-flip-hinge'));
Finder get flipSwing => find.byKey(const Key('property-flip-swing'));

String textOf(WidgetTester tester, Finder f) =>
    tester.widget<TextField>(f).controller!.text;

Future<void> enterAndSubmit(
    WidgetTester tester, Finder field, String text) async {
  await tester.enterText(field, text);
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

OpeningParams paramsOf(DraftDocument doc, Handle h) =>
    doc.components.get<OpeningParams>(h)!;
```

     Then, copied (R14-9), each block under a `// Copied from <file>:<lines> (spec 3a R14-9).` line:
     - from `jet_cad_floor_plan/test/support/wall_fixture.dart`: only `:295-301` (`reload`) with `parametricCatalog` → `kitCatalog()` and `installParametric(doc);` → `ParametricSystem(doc, kitCatalog()).install();`. Every other wall-fixture name the opening tests use (`ox`, `oy`, `far`, `plan`, `nextUp`, `polar`, `groupAt`, `oracleMeet`, `nearestIn`, `addWallLocal`, `addWall`, `kids`, `kindOf`, `payloadOf`, `pointsOf`, `worldOutline`, `driftOf`, `diagnosticsOf`, `enc`, `canon`, `xy`) is Task 12's integration `wall_fixture.dart`, re-exported above (R-P14's merge: one copy per package);
     - from `jet_cad_floor_plan/lib/src/parametric/wall_geometry.dart`: `:554-562` (`signedArea` with its doc line) and `:600-623` (`isSimpleCcw` with its doc), renamed `_signedArea` and `_isSimpleCcw` (private: they are the oracle's copy, not the kit's);
     - from `jet_cad_floor_plan/test/support/opening_fixture.dart`: `:24-786` (the pure oracles, `addOpening`, `deleteLikeSelectTool`, `oracleFrameOf`, `oracleAt`, `fillsOf`, `boundaryOf`, `worldPieces`, `centrelineHandles`, `worldCentrelines`, `storedPiecesTriangulate`, `storedPiecesSimpleCcw` (calling `_isSimpleCcw`), `gapRect`, `uncutTwin`, `uncutOutline`, `tiling`, `violations`, `OracleCut`, `OpeningOracle`, `doorOracle`, `worldLines`, `WorldArc`, `worldArc`, `expectDoorOnOracle`, `expectLinesOnOracle`, `distToSegment`, `strictlyInsideRing`, `symbolSamples`, `worldSymbol`, `oracleObstacles`, `oracleCut`) unchanged; `randomOpeningPlan` (`:787-960`) is not copied.
     A copied name that no C6 test uses is still copied (the block stays whole); `flutter analyze` does not report an unused public top-level declaration.
  2. `test/opening/opening_panel_test.dart` ← `opening_panel_test.dart`: OS1 (`:184-297`), OS2 (`:351-402`), OS4 (`:498-564`), then OT-panel-range (Step 3). OS1 (runtime) (`:299-349`) and OS3 (`:404-496`) are Task 15's (they need the opening tools). Header: today's `:1-4` plus `// Ported (spec 3a C6, C7); over architectureController in PlanEditor.` and `// ignore_for_file: invalid_use_of_internal_member`. Fixture:
     - `panelDoc(m)` (`:66-118`) becomes `(PlanController, Plan) panelPlan()`: `openingController(openingPlanText(shellPage, (doc) { … }))` where the callback holds today's `:81-108` (`Handle next()` to the box) unchanged; the record `p` is built after it from `late` handles. `pumpPanel(tester, doc)` → `pumpEditor(tester, c, centre: plan(3000, 1400), scale: 0.15)`; `select(tester, view, hs)` → `select(tester, c, hs)`; `doc` → `c.document`; `view.selection.keys` → `c.selection.keys`; finders per R14-10 (the file's own `section`, `width`, … and `textOf`, `enterAndSubmit`, `press`, `status`, `paramsOf`, `blur` come from the support, except `blur`, kept in the file).
     - OS4: today's `src` built by `panelDoc`, then the wall C deleted with no system (`:506-507`), then encoded and decoded (`:508-513`). It becomes `openingPlanText(shellPage, build, after: (d) => d.commands.execute(deleteLikeSelectTool(d, c)))` and `openingController(text)`; `expect(src.tree[p.c], isNull)` checks the controller's document (`c.document.tree[…]`). The rest unchanged.
     - Assertions unchanged.
  3. `test/opening/opening_grips_test.dart` ← `opening_grips_test.dart`: SG1 (shell) (`:327-381`), SG2 (`:383-452`), SG4 (`:561-600`). `shellDoc(m, build)` (`:76-96`) → `openingController(openingPlanText(shellPage, build))`; `addClampedDoor` (`:35-60`) and `k` (`:29`) copied into the file; `pumpShell(tester, doc, centre)` → `pumpEditor(tester, c, centre: centre, scale: 0.15)` (the rig's); `view.selection` → `c.selection`; `view.grips!` → `c.grips`; `view.camera` → `cameraOf(c)`; `objectGripsOf(view, h)` → `objectGripsOf(c, h)`; `tapWorld`, `dragWorld`, `undoKey`, `gridOf` from the support with `view` → `c`; `doc` → `c.document`. Assertions unchanged.
  4. `test/opening/opening_kink_test.dart` ← `opening_kink_test.dart`: KJ4 (`:313-342`), KJ5 (`:344-378`); KJ3 is Task 15's. Copy `:32-50` (`centre`, `left`, `right`, `hA`, `hB`, `hO`, `addKink`), `:59-64` (`reports`, `nofit`) and `:153-159` (`bendOf`, with `worldWallOf` → `worldEndsOf`). `shellDoc(build)` → `openingController(openingPlanText(shellPage, build))`; the harness as in 3. KJ4: `hostFrameInDocument(doc, hA)!.uE` → `OpeningOracle(c.document).span(hA).$2` (R14-9). KJ5: `worldWallOf(doc, hB)` → `worldEndsOf(c.document, hB)` (`:356`, `:367`). Assertions unchanged.
  5. `test/opening/opening_paint_test.dart` ← `opening_paint_test.dart` (RD1, `:23-177`): the document is `openingPlanText(PageComponent(scaleDenominator: 20, originX: ox - 3000, originY: oy - 2000, background: blueprint, snapToGrid: false), build)`, `build` holding today's `:56-74` up to the window (`installParametric`, `system.dispose()` and `clearHistory()` dropped: `openingPlanText` does that); the premises read at `:62-70` and `:73` (`kindOf`, the oracle's hinge, `driftOf`) run on `c.document` after the load (the same entities: the plan is saved and loaded). The pump: `pumpEditor(tester, c, centre: from, scale: 8, wrap: (app) => RepaintBoundary(key: capture, child: app))` replaces `:91-107` (`from` read before the pump, from `worldLines(c.document, hD)`); `globalOf(p)` → `globalAt(tester, c, p)` (the rig's). Assertions unchanged.
  6. `test/opening/opening_symbol_test.dart` ← `opening_symbol_test.dart` (OR8, `:348-474`, and the helpers it uses from `:26-62`). The document: `openingPlanText(PageComponent(scaleDenominator: 20, originX: ox - 3000, originY: oy - 2000, snapToGrid: false), build)` with today's `:369-374` in `build`; `:375-377` dropped; the oracle checks `:379-395` run on `c.document`; the pump `:399-410` → `pumpEditor(tester, c, centre: gapEnd, scale: scale)` (today's camera there is not turned: `pumpEditor` turns it 0.35 rad; the clicks are taken in world, so nothing asserted depends on it); the door added at `:426-427` is executed on `c.document.commands`; `view.selection.keys` → `c.selection.keys`. Assertions unchanged.

- [ ] **Step 6: Run them: they fail.** `cd packages/jet_cad_2d_kit_architecture && flutter test test/opening/`: compilation errors (`opening_grips.dart`, `opening_plan.dart` missing). `cd packages/jet_cad_2d_integration && flutter test --enable-vmservice test/opening/`: every new and ported case red, since `architectureKit` has no opening type yet (the fixture's temporary system and the controller do not know `architecture.opening`): an exception while the plan is built, or a failing expectation; quote the first failure of each case. A case that passes here is a finding: stop and report it.

- [ ] **Step 7: Port `opening_grips.dart`.** Create `lib/src/opening/opening_grips.dart` from `jet_cad_floor_plan/lib/src/parametric/opening_grips.dart`:
  - Lines 1-7 become:

```dart
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../live.dart';
import '../wall/wall.dart';
import '../wall/wall_geometry.dart' show wallsInDocument;
import 'opening.dart';
import 'opening_geometry.dart';
```

  - Copy lines 9-39 (the class doc) unchanged, then lines 40-50 become:

```dart
final class OpeningGrips implements ObjectGripProvider {
  /// [live] is the plan's live answer (spec 3a C1.5): the host and its
  /// openings are the live ones. [edgeAperture] returns the snap aperture
  /// in world, or null to turn edge snaps off (Ruling 08-15); by default
  /// they are off.
  OpeningGrips({required this.live, double? Function()? edgeAperture})
      : edgeAperture = edgeAperture ?? _off;

  static double? _off() => null;

  final LiveTypeOf live;

  /// The world aperture of D15's edge snaps, read at each drag event; null:
  /// no edge snap.
  final double? Function() edgeAperture;
```

  - Lines 52-101: unchanged except `_Slide.of(d, group)` → `_Slide.of(d, group, live)` at `:54`, `:65`, `:83`.
  - Lines 103-125 become (the rest of `_Slide`, `:126-182`, unchanged):

```dart
/// One opening on its host, as the document draws it now.
final class _Slide {
  _Slide._(this.params, this.layout, this.toWorld, this.openings, this.index,
      this.cuts)
      : toLocal = toWorld.invert();

  /// [group]'s slide state; null when it is not a live opening on a live,
  /// non-degenerate wall ([live]'s answer, spec 3a C1.5).
  static _Slide? of(DraftDocument d, Handle group, LiveTypeOf live) {
    final p = d.components.get<OpeningParams>(group);
    if (p == null) return null;
    final walls = wallsInDocument(d, p.host, live);
    if (walls == null) return null;
    final layout = layoutOf(walls.host, walls.walls);
    if (layout == null) return null;
    final openings = openingsInDocument(d, p.host, live);
    final i = openings.indexWhere((o) => o.$1 == group);
    if (i < 0) return null;
    final placed = cutsOf(layout.frame, layout.stretches, [
      for (final (_, o) in openings) (o.position, o.width),
    ]);
    return _Slide._(p, layout, walls.host.toWorld, openings, i, placed.cuts);
  }
```

  Add a line to the class doc's last paragraph (`:36-39`): `/// Ported from jet_cad_floor_plan's lib/src/parametric/opening_grips.dart (spec 3a C3.3).`

- [ ] **Step 8: The plan type.** Create `lib/src/opening/opening_plan.dart`:

```dart
// The opening's plan type (spec 3a C3.3, C1.1, C1.7): today's selection
// panel's Opening section (jet_cad_floor_plan/lib/src/selection_panel.dart:
// 405-433, 754-758, 1035-1059, 1332-1371) as property specs over the
// object, and its slide grip over the plan's services. Task 15 adds the
// three opening tools here.
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show ObjectGripProvider;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

import '../ids.dart';
import '../live.dart';
import '../type_naming.dart';
import '../wall/wall.dart';
import 'opening.dart';
import 'opening_grips.dart';

/// An opening's section title: its kind's tool word (today's `_titleOf`).
String openingTitle(OpeningParams o) => switch (o.kind) {
      OpeningKind.door => 'tool:${ArchitectureTools.door}',
      OpeningKind.window => 'tool:${ArchitectureTools.window}',
      OpeningKind.gap => 'tool:${ArchitectureTools.gap}',
    };

/// [w] as the width of an opening of [kind] (spec 08 D6: `isOpeningWidth`,
/// strict; a gap's above `4 × wallJoin.linear`), else an [ArgumentError],
/// which the panel turns into a revert. The type's width and the tools'
/// settings both write through it.
double openingWidthOf(OpeningKind kind, double w) {
  if (!isOpeningWidth(kind, w)) {
    throw ArgumentError.value(w, 'width', 'is no width a ${kind.name} takes');
  }
  return w;
}

/// Where [o]'s position may be (spec 3a C1.1; today's `_valid`,
/// `selection_panel.dart:425-430`): `[0, L]`, `L` its host's centreline
/// length in the host's own group-local space, when the engine names the
/// host a wall; null, refusing every position, when it does not (a box, a
/// group a later type names, a missing handle).
(double, double)? openingPositionRange(OpeningParams o, PlanObject object) {
  final doc = object.document;
  if (kitTypeIdOf(doc, o.host) != ArchitectureTypes.wall) {
    return null;
  }
  final host = doc.components.get<WallParams>(o.host)!;
  return (0, (host.end - host.start).length);
}

OpeningParams _flipHinge(OpeningParams o) => o.copyWith(
    hinge: o.hinge == HingeEnd.start ? HingeEnd.end : HingeEnd.start);

OpeningParams _flipSwing(OpeningParams o) => o.copyWith(
    swing: o.swing == SwingSide.left ? SwingSide.right : SwingSide.left);

bool _isDoor(OpeningParams o) => o.kind == OpeningKind.door;

/// The slide grip over [services] (today's shell factory,
/// `planner_shell.dart:649-652`): edge snaps at the snap aperture in world
/// while object snap is on.
ObjectGripProvider openingGripsOf(PlanServices services) => OpeningGrips(
    live: liveTypesOf(services),
    edgeAperture: () => services.objectSnap
        ? kSnapAperturePixels / services.camera.value.scale
        : null);

/// The opening (spec 3a C3.3): fields width, position, Flip hinge and Flip
/// swing (a door's), each needing `reshape`; titled by its kind.
final PlanType<OpeningParams> openingPlanType = PlanType<OpeningParams>(
  id: ArchitectureTypes.opening,
  fromJson: OpeningParams.fromJson,
  parametric: const OpeningType(),
  grips: openingGripsOf,
  title: openingTitle,
  properties: [
    LengthProperty<OpeningParams>(
        id: 'width',
        read: (o) => o.width,
        write: (o, w) => o.copyWith(width: openingWidthOf(o.kind, w)),
        gate: PlanGate.reshape),
    LengthProperty<OpeningParams>(
        id: 'position',
        read: (o) => o.position,
        write: (o, v) => o.copyWith(position: v),
        range: openingPositionRange,
        gate: PlanGate.reshape),
    ActionProperty<OpeningParams>(
        id: 'flip-hinge',
        apply: _flipHinge,
        visible: _isDoor,
        gate: PlanGate.reshape),
    ActionProperty<OpeningParams>(
        id: 'flip-swing',
        apply: _flipSwing,
        visible: _isDoor,
        gate: PlanGate.reshape),
  ],
);
```

  Create `lib/src/type_naming.dart` (ruling R-P19):

```dart
// The engine's naming rule (ParametricCatalog.typeIdOf) over the kit's own
// raw parametric types, registered in today's order
// (jet_cad_floor_plan/lib/src/parametric/catalog.dart:27-39), for a hook
// that sees a document but no services (spec 3a C1.1: the opening's
// position range asks "is the host a wall"). Built from the raw
// registrations, not from `architectureKit.types`, so `kit.dart` is not
// imported (ruling R-P19). Only the naming rule is read: no hook of a type
// runs. Each type task appends its registration in today's order (Task 16
// the separator, 18 the room, 20 the dimension).
import 'package:jet_cad_2d/jet_cad_2d.dart';

import 'box/box.dart';
import 'opening/opening.dart';
import 'wall/wall.dart';

/// The kit's raw types, built at the first read.
final ParametricCatalog _naming = ParametricCatalog()
  ..register<BoxParams>(
      BoxParams.componentTypeId, BoxParams.fromJson, const BoxType())
  ..register<WallParams>(
      WallParams.componentTypeId, WallParams.fromJson, const WallType())
  ..register<OpeningParams>(OpeningParams.componentTypeId,
      OpeningParams.fromJson, const OpeningType());

/// The type id that names [group]'s object in [target] by the engine's own
/// rule over the kit's types (a root-level group, named by the last
/// registered type whose component it carries), or null when it names no
/// object of the kit. A frozen object still answers its id, as the plan's
/// catalog does (spec 3a C1.5).
String? kitTypeIdOf(CommandTarget target, Handle group) =>
    _naming.typeIdOf(target, group);
```

  In `lib/src/kit.dart`: import `opening/opening_plan.dart` and put `openingPlanType` in `types:` right after `wallPlanType` (today's registration order, `catalog.dart:27-39`).

- [ ] **Step 9: 08 D13 in the wall's grips (R14-5).** In `lib/src/wall/wall_grips.dart`:
  - imports gain `import '../ids.dart';`, `import '../opening/opening.dart';` and `import '../opening/opening_geometry.dart' show layoutInDocument, placeCut, storedCentreOf;`;
  - the class doc gains back today's "Openings stay put" bullet (`wall_grips.dart:27-33`), unchanged;
  - in `drag`, the `CompoundCommand`'s list gains `..._keptPut(d, moved),` right after the walls' `SetComponentCommand<WallParams>`s (today's `:63-66`);
  - after `drag`, add:

```dart
  /// Spec 08 D13: for each wall of [moved] (ascending by handle) whose
  /// stored `start` changed and whose `end` did not (exact `==`, stored
  /// values), each of its live openings ([_live]'s answer, spec 3a C1.5),
  /// ascending, rewritten to `p′ = L′ − (L − p)`: its distance from the end
  /// that did not move is kept. `L` and `L′` are the centreline's
  /// group-local lengths before and after. The document's openings are
  /// read once: O(openings).
  List<DraftCommand> _keptPut(
      DraftDocument d, List<(Handle, WallParams, WorldWall)> moved) {
    final rewrite = <Handle, (double, double)>{};
    for (final (h, p, _) in moved) {
      final old = d.components.get<WallParams>(h)!;
      if (p.start != old.start && p.end == old.end) {
        rewrite[h] = ((old.end - old.start).length, (p.end - p.start).length);
      }
    }
    if (rewrite.isEmpty) return const [];
    final byHost = <Handle, List<(Handle, OpeningParams)>>{};
    for (final o in d.components.withComponent<OpeningParams>()) {
      if (_live(o) != ArchitectureTypes.opening) continue;
      final params = d.components.get<OpeningParams>(o)!;
      if (!rewrite.containsKey(params.host)) continue;
      byHost.putIfAbsent(params.host, () => []).add((o, params));
    }
    final now = {for (final (h, _, w) in moved) h: w};
    final out = <DraftCommand>[];
    for (final (h, _, _) in moved) {
      final lengths = rewrite[h];
      final openings = byHost[h];
      if (lengths == null || openings == null) continue;
      final (l, l2) = lengths;
      final stretches = layoutInDocument(d, h, _live, moved: now)?.stretches;
      openings.sort((a, b) => a.$1.value.compareTo(b.$1.value));
      for (final (o, params) in openings) {
        final p = l2 - (l - params.position);
        out.add(SetComponentCommand<OpeningParams>(
            o,
            params.copyWith(
                position: stretches == null
                    ? p
                    : _seated(stretches, p, params.width))));
      }
    }
    return out;
  }
```

    then today's `_seated` (`wall_grips.dart:113-127`, doc and body) unchanged.

  (Today's `_keptPut` is static over the global catalog; here it is an instance method reading `_live`, Task 12's private field (`WallGrips({required LiveTypeOf live}) : _live = live;`). If Task 12's `drag` builds the compound differently (its C1.8 refusal), the `_keptPut` members still go after the walls' own commands, in the same compound.)

- [ ] **Step 10: Run them: they pass.** `cd packages/jet_cad_2d_kit_architecture && dart format . && flutter test`: `All tests passed!`. `cd packages/jet_cad_2d_integration && dart format . && flutter test --enable-vmservice`: `All tests passed!`.

- [ ] **Step 11: The gates.**
  - `cd packages/jet_cad_2d_kit_architecture && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .`
  - `cd packages/jet_cad_2d_integration && flutter test --enable-vmservice && flutter analyze && dart format --output=none --set-exit-if-changed .`
  - `dart run tool/ci/check_kit_deps.dart` (from the worktree root): exit 0.
  - `git status --short`: only this task's files.

- [ ] **Step 12: Commit.**

```bash
git add packages/jet_cad_2d_kit_architecture/lib/src/opening/opening_grips.dart packages/jet_cad_2d_kit_architecture/lib/src/opening/opening_plan.dart packages/jet_cad_2d_kit_architecture/lib/src/type_naming.dart packages/jet_cad_2d_kit_architecture/lib/src/kit.dart packages/jet_cad_2d_kit_architecture/lib/src/wall/wall_grips.dart packages/jet_cad_2d_kit_architecture/test/opening/opening_plan_test.dart packages/jet_cad_2d_kit_architecture/test/opening/opening_object_test.dart packages/jet_cad_2d_kit_architecture/test/opening/opening_grips_test.dart packages/jet_cad_2d_kit_architecture/test/opening/opening_end_drag_test.dart packages/jet_cad_2d_integration/test/support/opening_support.dart packages/jet_cad_2d_integration/test/opening/opening_panel_test.dart packages/jet_cad_2d_integration/test/opening/opening_grips_test.dart packages/jet_cad_2d_integration/test/opening/opening_kink_test.dart packages/jet_cad_2d_integration/test/opening/opening_paint_test.dart packages/jet_cad_2d_integration/test/opening/opening_symbol_test.dart packages/jet_cad_2d_integration/test/opening/opening_frozen_test.dart
git commit -m "$(cat <<'EOF'
feat(architecture): the opening type, its slide grip and its fields (spec 3a C3.3)

openingPlanType joins the kit: titled by kind, width strict by kind,
position within the host wall's centreline through the object (C1.1),
the flips a door's (C1.7), all gated by reshape; the slide grip over the
plan's services. A wall end drag keeps its openings put again (08 D13).
In the integration package the panel, the grips, the paint and the
kinked joints run in PlanEditor, and a frozen door locks its host
(C1.10). 32 more of the opening's 85 cases ported.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 13: Mutation check** (committed files only; after each: run the named test, see it red, then `git checkout -- <file>` and `git diff --quiet -- <file>` must exit 0). Kit tests: `cd packages/jet_cad_2d_kit_architecture && flutter test <file>`; integration tests: `cd packages/jet_cad_2d_integration && flutter test --enable-vmservice <file>`. Quote each red line.
  - M-OT-1 `lib/src/opening/opening_plan.dart`: in `openingTitle`, swap the window's and the gap's words → OT-title red.
  - M-OT-2 `opening_plan.dart`: in `openingWidthOf`, `isOpeningWidth(kind, w)` → `isOpeningWidth(OpeningKind.door, w)` → OT-width red (a gap at 0.000004 accepted).
  - M-OT-3 `opening_plan.dart`: in `openingPositionRange`, `(0, (host.end - host.start).length)` → `(0, (host.end - host.start).length + 1)` → OT-range red; OT-panel-range red (`'6000.5'` commits).
  - M-OT-4 `opening_plan.dart`: in `openingPositionRange`, the first `return null;` → `return (0.0, double.maxFinite);` → OT-range red (Q, R); OT-panel-range red (the box host commits).
  - M-OT-5 `opening_plan.dart`: `kitTypeIdOf(doc, o.host) != ArchitectureTypes.wall` → `doc.components.get<WallParams>(o.host) == null` → OT-range red (R's host, an opening carrying `WallParams`, takes positions).
  - M-OT-6 `opening_plan.dart`: L in world: `final m = doc.tree.accumulatedTransform(o.host); return (0, (m.transformPoint(host.end) - m.transformPoint(host.start)).length);` → OT-range red (4,500 accepted).
  - M-OT-7 `opening_plan.dart`: delete `visible: _isDoor,` from `flip-hinge` → OT-flip red.
  - M-OT-8 `opening_plan.dart`: `_flipHinge` → `o.copyWith(hinge: HingeEnd.start)` → OT-flip red (the second flip).
  - M-OT-9 `opening_plan.dart`: delete `gate: PlanGate.reshape` from `width` → OT-fields red.
  - M-OT-10 `opening_plan.dart`: in `openingGripsOf`, `services.objectSnap ? kSnapAperturePixels / services.camera.value.scale : null` → `kSnapAperturePixels / services.camera.value.scale` → OT-grips red (object snap off still snaps).
  - M-OT-11 `opening_plan.dart`: `kSnapAperturePixels / services.camera.value.scale` → `kSnapAperturePixels * services.camera.value.scale` → OT-grips red (a 5 mm aperture: the 15 mm release does not snap).
  - M-OT-12 `lib/src/kit.dart`: remove `openingPlanType` from `types:` → OT-kit red; OS1 red (no Opening section).
  - M-OT-13 `lib/src/opening/opening.dart`: `references(OpeningParams params) => [params.host]` → `=> const []` → OT-frozen-host red (the wall edit applies).
  - M-OT-14 `packages/jet_cad_2d_plan/lib/src/kits/locks.dart`: delete the statements Task 7 added that put the live references of frozen objects into the lock set (C1.10) → OT-frozen-host red.
  - M-OT-15 `lib/src/wall/wall_grips.dart`: delete `..._keptPut(d, moved),` → EP1 red (`test/opening/opening_end_drag_test.dart`).
  - M-OT-16 `wall_grips.dart`: in `_keptPut`, delete `if (_live(o) != ArchitectureTypes.opening) continue;` → EP6 red.
  - M-OT-17 `wall_grips.dart`: in `_keptPut`, `position: stretches == null ? p : _seated(stretches, p, params.width)` → `position: p` → EP7 red.
  - M-OT-18 `lib/src/opening/opening_grips.dart`: in `drag`, delete `&& s.cut?.clamped != true` → SG3 red (`test/opening/opening_grips_test.dart`: a door drawn clamped by 1e-7 is not re-seated).

#### Assumed from earlier tasks

- Task 2: `LengthProperty.range` is checked inside `bind`'s commit after the constant bounds, a value outside throwing `ArgumentError`; `commitField` re-binds with a `DocumentPlanObject` over the document it is handed; `PropertyField.visible` is `spec.visible(owner)`.
- Task 6: `FakePlanServices`'s camera is a `CameraController` at `scale` px/mm with no rotation, and `objectSnap` defaults to true.
- Task 7: an edit of a live object a frozen object references is refused with `PlanLocked`, and `PlanController.execute` returns false and sets `lockHint`; `deleteSelection` returns false for it.
- Task 9: `architectureController` is a plain factory that does not register a tear-down (the support's `openingController` disposes it); `planEditorApp(controller)` is a `MaterialApp` whose home is a `PlanEditor` over it; `architectureKit` is a top-level `final` (`lib/src/kit.dart`) whose `types` and `tools` lists each task extends in place, and which carries `prepare` (Task 5's field).
- Task 12: `WallGrips({required LiveTypeOf live})` with the private field `_live` (Task 12's Step 6.3), and the kit's `test/support/wall_shell.dart` (today's `xy`, `walls`, `facesOf`, `expectMitre`, `expectSquare`), as its Step names them. If Task 12 did not port `wall_shell.dart`, this task copies today's `jet_cad_floor_plan/test/support/wall_shell.dart:1-51` with Task 13's A13-imports.
- Task 13: everything in its "Produces" and its kit test support (`liveOf`, `testCatalog` with the opening registered).

#### Interface problem

(Resolved by R-P19: R14-1 accepted, over a kit-internal list of raw registrations, `lib/src/type_naming.dart`, not `architectureKit.types`; Step 8 is written that way. Kept for the record, do not stop on it.)

**A `range` cannot ask "is this a live wall" through the contract.** `LengthProperty.range: (double, double)? Function(T, PlanObject)` (Shared interfaces, Task 2) hands the kit a document, a handle and a transform; today's rule asks the engine's naming rule over the catalog (`jet_cad_floor_plan/lib/src/selection_panel.dart:425-427`, `_isObject` → `isLiveObject<WallParams>`, `:510-511`), and EG9 (`wall_grips_test.dart:735-756`) pins that an opening hosted on a group carrying `WallParams` but named an opening refuses every position. R14-1 answers it with a kit-local catalog over `architectureKit.types` (exact for a plan whose types are this kit's, which is every plan the kit's own objects live in). The alternative, a contract change for the controller to weigh: `PlanObject` gains `String? typeIdOf(Handle handle)` (the plan's `catalog.typeIdOf`, frozen objects included, as the panels' rule), `DocumentPlanObject(document, handle, {String? Function(Handle)? typeIdOf})`, and `PlanType.fieldsOf`/`commitField` pass the plan's catalog through. With it, `openingPositionRange`'s first line becomes `if (object.typeIdOf(o.host) != ArchitectureTypes.wall) return null;` and `_kitCatalog` goes; OT-range and OT-panel-range stand unchanged.

#### New shared name

- **`packages/jet_cad_2d_integration/test/support/opening_support.dart`** (this task): `shellPage`, `gridStep`, `openingPlanText(PageComponent page, void Function(DraftDocument d) build, {void Function(DraftDocument d)? after})`, `openingController(String text)`, `cameraOf`, `tapWorld`, `dragWorld`, `undoKey`, `select`, `objectGripsOf`, `gridOf`, `doorGroup`, `worldEndsOf`, `reload`, the panel finders and today's opening oracles; it re-exports the rig's `pumpEditor`, `globalOf`, `globalAt`, `kitCatalog`, `press`, `status`, `activeTool` (R-P14) and Task 12's wall-fixture names (`ox` … `xy`), so an opening test imports this file alone. Task 15's C6 cases use it; Tasks 26-28 may (their own support files must not redeclare these names in a file a test imports together with this one).
- **The C6 convention R14-8:** a C6 test file that reads an `@internal` member of `PlanController` starts with `// ignore_for_file: invalid_use_of_internal_member`. Every C6 task (Tasks 12, 15-28) meets the same need (the selection, the grips, the camera); the controller may want it as a Global Constraint.

---

