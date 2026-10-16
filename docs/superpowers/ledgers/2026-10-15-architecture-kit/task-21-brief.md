### Task 21: The dimension type, grips and properties (spec C3.6, C1.1, C1.5, C7)

**Files** (paths under `packages/jet_cad_2d_kit_architecture/` unless they say otherwise):
- Create: `lib/src/dimension/dimension_grips.dart` (ported, adapted), `lib/src/dimension/dimension_plan.dart` (NEW: `dimensionPlanType`)
- Modify: `lib/src/kit.dart` (`dimensionPlanType` in `types`)
- Test (ported, kit): `test/dimension/dimension_object_test.dart`, `test/dimension/dimension_grips_test.dart`
- Test (new, kit): `test/dimension/dimension_plan_test.dart` (DM-*)
- Create (integration): `packages/jet_cad_2d_integration/test/dimension/dimension_plans.dart` (test support), `packages/jet_cad_2d_integration/test/dimension/dimension_panel_test.dart` (ported)
- Modify: the kit's `test/wall/wall_grips_test.dart` (Tasks 12, 17: EG9-k, EG10-k) and the integration package's `packages/jet_cad_2d_integration/test/wall/wall_grips_test.dart` (Tasks 12, 17: EG9, EG10), carried from Task 12 (R-P8)

**Interfaces:**
- Consumes:
  - Task 20: `DimensionParams`, `DimensionType`, `DimKind`, `DimEnd`, `AttachedEnd`, `FixedEnd`, `WallSide`, `layoutDimension`, `offsetFor`, `wallEndPoint`, `wallEndPoints`, `DimLayout` (`lib/src/dimension/dimension.dart`); `WallPoints`, `attachCandidates(..., {required LiveTypeOf live, ...})`, `thickestWall(doc, live)`, `decideEnd` (`dimension_attach.dart`); the test support `dimension_fixture.dart` with `liveOf`.
  - Task 9: `ArchitectureTypes.dimension`, `LiveTypeOf`, `LiveTypeOf liveTypesOf(PlanServices services)` (`lib/src/live.dart`), `architectureKit` (`lib/src/kit.dart`), `architectureNames` (`lib/src/words/words.dart`), and the words listed under "Assumed".
  - Task 11: `wallsInDocument(doc, host, LiveTypeOf live, {moved})` (`lib/src/wall/wall_geometry.dart`; R-P8, R-P17: `live` positional).
  - Task 2 (C1.1): `TextDisplay<T>({required String id, required String? Function(T value, PlanObject object) read, ...})`, `PlanObject`, `DocumentPlanObject`, `PropertyField.visible`, `PlanType.fieldsOf`/`commitField` over `DraftDocument` (see `#### Interface problem` 1: this task needs the words in `read`).
  - Task 3 (C1.6): `KitWords.text(id, args)`, `KitWords.decimalSeparator`, `KitNamesWords(names, locale, {decimalSeparator})`.
  - Task 6 (C1.11): `FakePlanServices` (`package:jet_cad_2d_kit/testing.dart`), `PlanServices.liveTypeIdOf`.
  - Task 9 (integration): `PlanController architectureController({String? json, PlanPermissions permissions})`, `Widget planEditorApp(PlanController controller, {Locale locale})` (`package:jet_cad_2d_integration/jet_cad_2d_integration.dart`).
  - Task 5 (C1.9): `PlanController(kits:, build:)`, `typedef PlanBuild = void Function(DraftDocument, KitWords)`.
  - Plan library (public): `PlanController.document`, `activeSelection`, `camera`, `execute`, `save`, `dispose`; `encodePlan`, `decodePlan`, `validateKitSet` (`jet_cad_2d_plan.dart`); the property panel's keys `section-<type id>`, `property-<spec id>`, `property-<spec id>-<segment>` (`plan_property_panel.dart:700-760, :826-828`).
- Produces:
  - `final PlanType<DimensionParams> dimensionPlanType` (`lib/src/dimension/dimension_plan.dart`, Shared interfaces).
  - Kit-internal: `DimensionGrips({required SpatialIndex index, required bool Function() objectSnap, required LiveTypeOf live})`; `String? dimensionValueOf(DimensionParams p, PlanObject object)`, `String? dimensionAxesOf(DimensionParams p, PlanObject object)`, `String dimensionEndLine(DimEnd end, PlanWords words)`, `@visibleForTesting int debugDimensionValueScans` (`dimension_plan.dart`).
  - `architectureKit.types` gains `dimensionPlanType`, last (today's order, `catalog.dart:27-39`).

**Appendix A rows closed:** D-19's dimension part: `dimension_object_test` (11: kit), `dimension_grips_test` (6: kit), `dimension_panel_test` (6: integration). `dimension_paint_test` (3) cannot be ported here: it runs on the sample flat (Task 25's), so it is Task 26's by ruling R-P5 (`#### Interface problem` 2 hands it on with its full port; Task 26's Step 9 item 10). D-46's "titles by `title`, `TextDisplay`" for the dimension (the section's title is `type:architecture.dimension`; the value, axes and end lines are `TextDisplay`s) is exercised by PN1-PN4 here; Task 27 closes D-46 as a row.

**C7 placement, per file** (sources under `packages/jet_cad_floor_plan/test/`):
- `dimension_object_test.dart` → kit, every case (DO1, DO2, DO3, DO4, DO6, DO5, DD1, DD2, DD3, DD4, DD5): it uses only `box.dart`, `dimension.dart`, `wall.dart`, the engine and the fixtures.
- `dimension_grips_test.dart` → kit, every case (GE1, GE2, GE3, GE4, GE5, GE5b): it uses `DimensionGrips`, `GripCache`, `OutlineCache`, `SelectionController`, `GripDrag` (the Flutter layer) and `ObjectGrips` (today's shell dispatcher, replaced by the type's own provider: a fixture change; one line not ported, ruling DM-R1).
- `dimension_panel_test.dart` → integration, every case (PN1, PN2, PN3, PN4, PN5 looped over `origin` and `corpusGroups`, and PN5's refused-edit case): they pump `PlannerShell` and read `SelectionPanel`'s section; they map to `PlanEditor`'s `PlanPropertyPanel` over a `PlanController` with the kit.
- `dimension_paint_test.dart` → integration, carried to Task 26 (ruling R-P5; `#### Interface problem` 2 gives the port Task 26's Step 9 folds in).
- `wall_grips_test.dart` EG9, EG10 (carried from Task 12, R-P8) → the kit's EG9-k, EG10-k (adapters, band cache, attach, room inputs, providers) and the integration package's EG9, EG10 (the panel, the Position field, the corner drag): Step 10b.

**R-P1 check:** the kit cases use kit internals (`DimensionGrips`, `liveOf`, the fixtures) and the Flutter layer only. The integration cases (PN1-PN5) use only public libraries: the kit's barrel, `jet_cad_2d_plan`'s `PlanController`/`PlanEditor`/`decodePlan`/`encodePlan`/`validateKitSet`, the contract's `registerKitComponents` and `PlanType.registerInto`, and the engine. Their two kit-internal premise lines are dropped (DM-R2, the facts stay asserted in the kit). No plan-internal helper is needed, so no `place_entry.dart` fixture is used.

**Plan rulings (this task; the controller confirms them before execution):**
- **DM-R1 (GE1, one line not ported).** `expect(ObjectGrips(edgeAperture: () => null).gripsOf(doc, dim2), isEmpty)` (`dimension_grips_test.dart:139`) asserts that today's shell dispatcher gives a dimension no grips when it was built without an index (`object_grips.dart:62-64`). The plan always hands a kit's grips factory its services' index (`PlanServices.index`, never null), so the premise cannot be built: not ported (C7, "premise impossible"). The two lines before it (the same grips, and `movable`) are ported over `dimensionPlanType.gripsFor(FakePlanServices(...))`.
- **DM-R2 (PN1, PN2: premises over kit internals).** `bruteCandidates(...)` premises (`dimension_panel_test.dart:127-130` with their comment, `:203-205`) call the kit's attach points (`wallsInDocument`, `wallEndPoints`), which the integration package cannot import (C6: public libraries only). They are dropped from the integration copy; the same facts are the kit's: AP1 asserts C2's points by hand (`dimension_attach_points_test.dart`), GE3 asserts A/0/left and the inner corner as candidates, and PN1's own `dimText == '3451'` premise pins the attach point at x = 0.
- **DM-R3 (PN1-PN5, C7 class 3).** The kind is a `ChoiceProperty`, which the plan draws as a `DropdownButton` (`plan_property_panel.dart:728-744`), not today's `SegmentedButton`: `switchOf(tester).selected` reads `menuOf(tester).value` (`{DimKind.x}` becomes `DimKind.x`, the same kind), `onSelectionChanged` reads `onChanged`, a segment click is a menu open and an item tap; a click "before the panel rebuilds" (PN5's dead handle) calls `onChanged` directly, as PN2 and PN5 already do for the stale callback, because opening a menu pumps a frame. Keys: `dimension-section` → `section-architecture.dimension`, `dimension-value` → `property-value`, `dimension-kind` → `property-kind`, `dimension-<kind>` → `property-kind-<kind>`, `dimension-axes` → `property-axes`, `dimension-end-1|2` → `property-end-1|2`, `wall-section` → `section-architecture.wall`.

#### Assumed from earlier tasks

Each name below is used as written; where the earlier task named it otherwise, use that task's name and report the difference.
- Task 9's words (today's texts, `jet_cad_floor_plan/lib/src/l10n/strings_{en,de,tr}.dart:97, :223-250, :304-308`), English / German / Turkish:
  - `type:architecture.dimension`: `Dimension` / `Bemaßung` / `Ölçü`;
  - `property:architecture.dimension.value`: `Value` / `Wert` / `Değer`; `.end-1`: `End 1` / `Ende 1` / `Uç 1`; `.end-2`: `End 2` / `Ende 2` / `Uç 2`; `.kind.aligned`: `Aligned` / `Ausgerichtet` / `Hizalı`; `.kind.horizontal`: `Horizontal` / `Horizontal` / `Yatay`; `.kind.vertical`: `Vertical` / `Vertikal` / `Dikey`; `.kind` and `.axes`: Task 9's new words;
  - `text:architecture.axes-turned`: `Axes turned {degrees}°` / `Achsen um {degrees}° gedreht` / `Eksenler {degrees}° döndürülmüş`;
  - `text:architecture.end-on-wall`: `Wall {wall}, {end}, {side}` / `Wand {wall}, {end}, {side}` / `Duvar {wall}, {end}, {side}`;
  - `text:architecture.end-start`: `start` / `Anfang` / `başlangıç`; `end-end`: `end` / `Ende` / `bitiş`; `end-fixed`: `Fixed` / `Fest` / `Sabit`; `face-left`: `left face` / `linke Seite` / `sol yüzey`; `face-centre`: `centreline` / `Mittellinie` / `eksen`; `face-right`: `right face` / `rechte Seite` / `sağ yüzey`.
- Task 9: `lib/src/kit.dart` declares `architectureKit` with a `types:` list (box, wall, opening, separator, room after Tasks 10-18).
- Task 9 (integration): `planEditorApp` returns a `MaterialApp` whose home shows `PlanEditor(controller: controller)` with its property panel, in [locale]; the integration pubspec lists `jet_cad_2d`, `jet_cad_2d_flutter`, `jet_cad_2d_kit`, `vector_math` (Task 20's `#### Interface problem`).
- Task 10: `BoxParams` (`lib/src/box/box.dart`), registered in the test catalog (DD2's live box).
- Task 18: `section-architecture.wall` is the wall's section key (`section-<type id>`, the plan's own rule).

- [ ] **Step 1: Precondition.** Task 20 is committed. `cd packages/jet_cad_2d_kit_architecture && flutter test && flutter analyze`: `All tests passed!`, `No issues found!`. `cd packages/jet_cad_2d_integration && flutter test --enable-vmservice && flutter analyze`: the same. Read `packages/jet_cad_2d_kit/lib/src/kit/properties.dart` and `plan_type.dart` as Task 2 left them: confirm `TextDisplay`, `PlanObject`, `fieldsOf` and how a `TextDisplay`'s `read` reaches the words (`#### Interface problem` 1). **Do not start this task until the controller has settled that problem**: Steps 3 and 5 are written against its proposed fix and change with it.

- [ ] **Step 2: The failing kit tests (new).** Create `test/dimension/dimension_plan_test.dart`:

```dart
// 3a Task 21, spec C3.6, C1.1, C1.5: the dimension as a plan type. Its five
// fields over the object (the value as drawn, memoised by the history
// state; the kind, gated by reshape; the axes line in the words' language
// with their decimal separator, omitted when not turned; the two end
// lines in words), and its grips over the plan's services: F3 and the live
// types are the services' (spec C1.5: a frozen wall attaches nothing).
// Today's section: jet_cad_floor_plan/lib/src/selection_panel.dart:846-976.
// Every fixture is C2's L at the corpus far origin, each wall in its own
// turned group, on a 1:50 mm page.
import 'dart:math' as math;
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_kit/testing.dart';
import 'package:jet_cad_2d_kit_architecture/src/dimension/dimension.dart';
import 'package:jet_cad_2d_kit_architecture/src/dimension/dimension_plan.dart';
import 'package:jet_cad_2d_kit_architecture/src/words/words.dart'
    show architectureNames;
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/dimension_fixture.dart';

const l = WallSide.left, r = WallSide.right;

/// The kit's words in [language], with [separator] as the UI's decimal
/// separator.
KitWords wordsIn(String language, {String separator = '.'}) => KitNamesWords(
    architectureNames, () => Locale(language),
    decimalSeparator: () => separator);

/// [h]'s fields as the plan's panel binds them (spec C1.1).
List<PropertyField> fieldsOf(DraftDocument doc, Handle h, KitWords words) =>
    dimensionPlanType.fieldsOf(doc, h, words);

PropertyField fieldOf(List<PropertyField> fields, String id) =>
    fields.singleWhere((f) => f.spec.id == id);

/// C2's L at the corpus far origin in own groups, on a 1:50 mm page.
Plan lPlan() {
  final plan = buildPlan(c2Walls, place: corpusGroups);
  attachPage(plan.doc, mmPage);
  return plan;
}

/// The placement turned [deg] further: a dimension group's transform.
Transform2 turned(double deg) =>
    corpusGroups.m.multiply(Transform2.rotation(deg * math.pi / 180));

void main() {
  test(
      'DM-fields five fields in order under property:architecture.dimension, '
      'the kind gated by reshape; the value as drawn; no axes line for '
      'aligned; the end lines in words (M-DM1, M-DM2)', () {
    final plan = lPlan();
    final doc = plan.doc;
    final [a, _] = plan.walls;
    // DO3's d1: A/0/right (0, −100) → A/1/right, the outer mitre (4100,
    // −100), aligned, offset −612.25: 4100.
    final d = addDimension(doc, AttachedEnd(a, 0, r), AttachedEnd(a, 1, r),
        offset: -612.25, at: corpusGroups.m);
    final fields = fieldsOf(doc, d, wordsIn('en'));
    const ids = ['value', 'kind', 'axes', 'end-1', 'end-2'];
    expect([for (final f in fields) f.spec.id], ids);
    expect([for (final f in fields) f.wordId],
        [for (final id in ids) 'property:architecture.dimension.$id']);
    expect(fieldOf(fields, 'kind').spec.gate, PlanGate.reshape);
    expect(fieldOf(fields, 'value').spec.gate, isNull);
    expect(fieldOf(fields, 'value').value, '4100');
    expect(fieldOf(fields, 'value').commit, isNull, reason: 'read-only');
    expect(fieldOf(fields, 'kind').value, DimKind.aligned);
    expect(fieldOf(fields, 'axes').visible, isFalse,
        reason: 'aligned: no axes line');
    expect(fieldOf(fields, 'end-1').value, 'Wall ${a.toHex()}, start, right face');
    expect(fieldOf(fields, 'end-2').value, 'Wall ${a.toHex()}, end, right face');

    // The kind's commit: only the kind changes (R-27), one command.
    final p0 = doc.components.get<DimensionParams>(d)!;
    final command = dimensionPlanType.commitField(
        doc, d, fieldOf(fields, 'kind'), DimKind.horizontal, wordsIn('en'));
    doc.commands.execute(command);
    expect(doc.components.get<DimensionParams>(d),
        p0.copyWith(kind: DimKind.horizontal));
  });

  test(
      'DM-value the value as drawn, read once per history state; a wall '
      'edit re-reads it; a broken dimension reads — (M-DM3, M-DM4)', () {
    final plan = lPlan();
    final doc = plan.doc;
    final [a, _] = plan.walls;
    // PN1's dimension: A/0/left (0, 100) to the plan point (3450.6, 100):
    // 3450.6 mm, which reads 3451.
    final d = addDimension(doc, AttachedEnd(a, 0, l),
        fixedAt(plan.at(3450.6, 100), corpusGroups.m),
        kind: DimKind.aligned, offset: 400.25, at: corpusGroups.m);
    final broken = addDimension(doc, AttachedEnd(a, 2, l),
        fixedAt(plan.at(3450.6, 100), corpusGroups.m),
        kind: DimKind.aligned, offset: 400.25, at: corpusGroups.m);
    final words = wordsIn('en');
    String? value(Handle h) =>
        fieldOf(fieldsOf(doc, h, words), 'value').value as String?;

    expect(value(d), '3451');
    final scans = debugDimensionValueScans;
    expect(value(d), '3451');
    expect(value(d), '3451');
    expect(debugDimensionValueScans, scans, reason: 'one state: no rescan');

    // A moved 500.25 along the plan's −x (its joint with B broken): A/0/left
    // is (−500.25, 100), the value 3950.85, which reads 3951 (PN1).
    final t = corpusGroups.m.transformDirection(Vector2(-500.25, 0));
    doc.commands.execute(TransformNodeCommand(a,
        Transform2.translation(t.x, t.y).multiply(doc.tree[a]!.transform)));
    expect(dimText(doc, d), '3951', reason: 'premise: regenerated');
    expect(value(d), '3951', reason: 'a new state is read');
    expect(debugDimensionValueScans, scans + 1);

    expect(kids(doc, broken), isEmpty, reason: 'premise: broken (D15)');
    expect(value(broken), '—');
  });

  test(
      'DM-axes the axes line in the words\' language with their decimal '
      'separator; the end lines in Turkish (M-DM5, M-DM6)', () {
    final plan = lPlan();
    final doc = plan.doc;
    final [a, _] = plan.walls;
    // Horizontal in a group turned 30° past the placement's 23°: the world
    // rotation is 53°, which reads 53.0.
    final d = addDimension(
        doc, AttachedEnd(a, 1, r), const FixedEnd(1000.25, 1500.5),
        kind: DimKind.horizontal, offset: 300.5, at: turned(30));
    expect(fieldOf(fieldsOf(doc, d, wordsIn('en')), 'axes').value,
        'Axes turned 53.0°');
    expect(
        fieldOf(fieldsOf(doc, d, wordsIn('de', separator: ',')), 'axes')
            .value,
        'Achsen um 53,0° gedreht');
    final tr = fieldsOf(doc, d, wordsIn('tr', separator: ','));
    expect(fieldOf(tr, 'axes').value, 'Eksenler 53,0° döndürülmüş');
    expect(fieldOf(tr, 'axes').visible, isTrue);
    expect(fieldOf(tr, 'end-1').value, 'Duvar ${a.toHex()}, bitiş, sağ yüzey');
    expect(fieldOf(tr, 'end-2').value, 'Sabit');
  });

  test(
      'DM-grips the type\'s grips read the plan\'s services: F3 off fixes the '
      'dropped end; a frozen wall attaches nothing (M-DM7, M-DM8)', () {
    final plan = lPlan();
    final doc = plan.doc;
    final [a, _] = plan.walls;
    final g = turned(30);
    FakePlanServices services(
        {bool objectSnap = true, Set<Handle> frozen = const {}}) {
      final s = FakePlanServices(
          document: doc,
          catalog: testCatalog(),
          objectSnap: objectSnap,
          frozen: frozen);
      addTearDown(s.dispose);
      return s;
    }

    // A fresh fixed-fixed dimension; its grip at a dropped on A's free
    // start's left corner (0, 100), A/0/left alone (GE3's premise).
    DimEnd dropA(FakePlanServices s) {
      final d = addDimension(doc, fixedAt(plan.at(500.25, 1500.5), g),
          fixedAt(plan.at(2500.75, 2200.25), g),
          kind: DimKind.aligned, offset: 250.5, at: g);
      final grips = dimensionPlanType.gripsFor(s)!;
      final grip = grips.gripsOf(doc, d)[1];
      doc.commands.execute(grips.drag(doc, d, grip, plan.at(0, 100))!);
      return doc.components.get<DimensionParams>(d)!.a;
    }

    expect(dropA(services()), AttachedEnd(a, 0, l), reason: 'control');
    expect(dropA(services(objectSnap: false)), isA<FixedEnd>(),
        reason: 'F3 off');
    expect(dropA(services(frozen: {a})), isA<FixedEnd>(),
        reason: 'A frozen: no wall end point');
  });
}
```

  Run: `cd packages/jet_cad_2d_kit_architecture && flutter test test/dimension/dimension_plan_test.dart`. Expected: compile failure (`dimension_plan.dart` does not exist).

- [ ] **Step 3: Port the grips.** Create `lib/src/dimension/dimension_grips.dart` from `packages/jet_cad_floor_plan/lib/src/parametric/dimension_grips.dart`:
  - lines 1-10 (imports) become:
    ```dart
    // A dimension's grips (spec 11 D13), moved from jet_cad_floor_plan (3a
    // spec C3.6): the live walls are the plan's (C1.5), through [live].
    import 'dart:async' show StreamSubscription, unawaited;

    import 'package:jet_cad_2d/jet_cad_2d.dart';
    import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart';
    import 'package:vector_math/vector_math_64.dart' show Vector2;

    import '../live.dart';
    import '../wall/wall.dart' show wallJoin;
    import '../wall/wall_geometry.dart' show wallsInDocument;
    import 'dimension.dart';
    import 'dimension_attach.dart';
    ```
  - copy lines 11-79 unchanged (the class doc's "through the render layer's object grip seam", `:26`, stays: it reads true of the plan; `:83`'s "The shell's spatial index" is inside the block replaced below, which says "The plan's");
  - lines 80-88 become:
    ```dart
    final class DimensionGrips implements ObjectGripProvider {
      DimensionGrips(
          {required this.index, required this.objectSnap, required this.live});

      /// The plan's spatial index, which [attachCandidates] queries.
      final SpatialIndex index;

      /// Whether object snap (F3) is on, read at each drag event: with it off
      /// nothing attaches (decision 4).
      final bool Function() objectSnap;

      /// The plan's live types (spec 3a C1.5): which walls an end attaches to
      /// and reads its point from.
      final LiveTypeOf live;
    ```
  - copy lines 89-118 unchanged; line 119 becomes `    final next = _dropped(d, s, grip.index, world, thickestWall(d, live), null);`;
  - copy lines 120-158 unchanged; line 159 becomes `    _memoThickest = thickestWall(d, live);`;
  - copy lines 160-183 unchanged; lines 184-185 and 202-203 lose `static` (`_Dim? _stateOf(` and `Vector2? _pointOf(`: they read [live] now); line 212 becomes `        final ws = wallsInDocument(d, wall, live);`;
  - copy lines 186-242 otherwise unchanged; lines 243-244 become:
    ```dart
        final candidates = attachCandidates(d, index, q,
            live: live,
            objectSnap: objectSnap(),
            thickest: thickest,
            points: points);
    ```
  - copy lines 245-269 unchanged (`_find` and `_fixedAt` stay `static`).

- [ ] **Step 4: Port the tests (kit).** Assertions unchanged except where a ruling above says.
  - `dimension_object_test.dart` → `test/dimension/dimension_object_test.dart`, every case: imports `package:jet_cad_floor_plan/src/parametric/box.dart` → `package:jet_cad_2d_kit_architecture/src/box/box.dart`; `dimension.dart` → `.../src/dimension/dimension.dart`; `wall.dart` → `.../src/wall/wall.dart`; `'support/dimension_fixture.dart'` → `'../support/dimension_fixture.dart'`. Nothing else.
  - `dimension_grips_test.dart` → `test/dimension/dimension_grips_test.dart`, every case:
    - imports: `dimension.dart`, `dimension_attach.dart`, `dimension_grips.dart` → the kit's `src/dimension/`; `wall.dart` → `src/wall/wall.dart`; `object_grips.dart` removed; add `import 'package:jet_cad_2d_kit/testing.dart' show FakePlanServices;` and `import 'package:jet_cad_2d_kit_architecture/src/dimension/dimension_plan.dart';`; `'support/...'` → `'../support/...'`.
    - `gripsFor` (`:41-46`): `DimensionGrips(index: index, objectSnap: snap ?? () => true)` → `DimensionGrips(index: index, objectSnap: snap ?? () => true, live: liveOf(doc))`; `fresh()` (`:589-590`) the same, `live: liveOf(doc)`.
    - `attachCandidates(...)` (`:225-226, :355-356, :368-369, :404-405`) gain `live: liveOf(doc),`; `thickestWall(doc)` → `thickestWall(doc, liveOf(doc))`.
    - GE1 `:134-139` become (DM-R1):
      ```dart
            // Through the plan type's provider over the plan's services: the
            // same grips, and a dimension is movable (R-19).
            final services = FakePlanServices(document: doc, catalog: testCatalog());
            addTearDown(services.dispose);
            final objects = dimensionPlanType.gripsFor(services)!;
            expect(objects.gripsOf(doc, dim2), gs);
            expect(objects.movable(doc, dim2), isTrue);
      ```
      (`index` from `gripsFor` is then unused in GE1: write `final (grips, _) = gripsFor(doc);` at `:83`.)
    - GE4 `:468`: `final objects = ObjectGrips(edgeAperture: () => null, index: index);` → `final ObjectGripProvider objects = grips;` (today's dispatcher handed a dimension group to exactly this provider, `object_grips.dart:80-95`), and `:429` `final (grips, index) = gripsFor(doc, snap: () => snap);` → `final (grips, _) = gripsFor(doc, snap: () => snap);` (`index` is then unused, and `unused_local_variable` is an error here); every later line unchanged, `GripCache(..., objects: objects)`, `GripDrag.reshapeObject(..., objects)` and `expect(objects.gripsOf(doc, broken), isEmpty)` included.
  - Before porting, `grep -rn "GE1\|DO1 \|DD1" packages/jet_cad_2d_plan/test packages/jet_cad_2d_kit/test`: expected none; a hit is a finding.

- [ ] **Step 5: The plan type.** Create `lib/src/dimension/dimension_plan.dart`:

```dart
// The dimension as a plan type (3a spec C3.6, C1.1): today's Dimension
// section (jet_cad_floor_plan/lib/src/selection_panel.dart:846-976) as
// property specs over the object, and the grips over the plan's services.
//
// - Value: the TEXT child's string as drawn, '—' without one (a broken
//   dimension, D15), read once per dimension and history state (today:
//   once per document change, :232-236, :851-864).
// - Kind: a choice; a change keeps the ends and the offset (R-27). Gated
//   by `reshape` (today's `_dimensionEditable`, :870-875: the host's
//   reshape, then the document's `components` and the type's geometry,
//   which the plan's panel checks for every type).
// - Axes: a linear dimension's group's world rotation, rounded to tenths
//   and normalised to (−180°, 180°], in the UI language's words and
//   decimal separator; omitted for aligned and below 0.05° (:901-916).
// - End 1, End 2: `Wall <hex>, start|end, <side>` or `Fixed` (:918-931).
import 'dart:math' as math;

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

import '../ids.dart';
import '../live.dart';
import 'dimension.dart';
import 'dimension_grips.dart';

/// The dimension's plan type (Shared interfaces, spec C3.6).
final PlanType<DimensionParams> dimensionPlanType = PlanType<DimensionParams>(
  id: ArchitectureTypes.dimension,
  fromJson: DimensionParams.fromJson,
  parametric: const DimensionType(),
  grips: (s) => DimensionGrips(
      index: s.index, objectSnap: () => s.objectSnap, live: liveTypesOf(s)),
  properties: [
    TextDisplay<DimensionParams>(id: 'value', read: dimensionValueOf),
    ChoiceProperty<DimensionParams, DimKind>(
        id: 'kind',
        values: DimKind.values,
        read: (p) => p.kind,
        write: (p, kind) => p.copyWith(kind: kind),
        gate: PlanGate.reshape),
    TextDisplay<DimensionParams>(id: 'axes', read: dimensionAxesOf),
    TextDisplay<DimensionParams>(
        id: 'end-1', read: (p, o) => dimensionEndLine(p.a, o.words)),
    TextDisplay<DimensionParams>(
        id: 'end-2', read: (p, o) => dimensionEndLine(p.b, o.words)),
  ],
);

/// Every scan [dimensionValueOf] made of a document's entities. Tests read
/// the difference across calls: one per dimension shown and history state.
@visibleForTesting
int debugDimensionValueScans = 0;

/// The last value read, per document.
final class _ValueMemo {
  Handle? handle;
  int state = 0;
  String? text;
}

final Expando<_ValueMemo> _valueMemo = Expando<_ValueMemo>('dimension value');

/// The Value line (spec 11 D14, decision 13): [object]'s TEXT child's
/// stored string, exactly as drawn, or '—' when it has none (a broken
/// dimension generates no child, D7, D15). Read once per dimension and
/// `document.commands.stateId` (spec 3a C1.1): a wall edit or a page change
/// is a command and rewrites the string in place.
String? dimensionValueOf(DimensionParams p, PlanObject object) {
  final doc = object.document;
  final state = doc.commands.stateId;
  final memo = _valueMemo[doc] ??= _ValueMemo();
  if (memo.handle != object.handle || memo.state != state) {
    debugDimensionValueScans++;
    final entities = doc.entities;
    String? text;
    for (final slot in entities.liveSlots) {
      if (entities.ownerAt(slot) == object.handle &&
          entities.kindAt(slot) == EntityKind.text) {
        text = entities.textAt(slot);
        break;
      }
    }
    memo
      ..handle = object.handle
      ..state = state
      ..text = text;
  }
  return memo.text ?? '—';
}

/// The axes line (spec 11 D11, R-18), or null: for a linear kind whose
/// group's world rotation, `atan2(M.b, M.a)` in degrees, is at least 0.05°
/// either way (the number, not its printed string, S-8). Rounded to tenths
/// first and then normalised to (−180°, 180°], so −179.96° reads `180.0°`,
/// in [object]'s words with their decimal separator (spec 3a C1.6).
String? dimensionAxesOf(DimensionParams p, PlanObject object) {
  if (p.kind == DimKind.aligned) return null;
  final m = object.world;
  final angle = math.atan2(m.b, m.a) * 180 / math.pi;
  if (angle.abs() < 0.05) return null;
  var shown = double.parse(angle.toStringAsFixed(1));
  if (shown <= -180) shown += 360;
  final words = object.words;
  return words.text('text:architecture.axes-turned', {
    'degrees':
        shown.toStringAsFixed(1).replaceAll('.', words.decimalSeparator),
  });
}

/// An end line (spec 11 D14, R-28): for an attached end, its wall's handle
/// in hex, the start or end word for its `k` and the side's word (`Wall 1A,
/// end, left face`); the fixed word for a fixed end.
String dimensionEndLine(DimEnd end, PlanWords words) => switch (end) {
      FixedEnd() => words.word('text:architecture.end-fixed'),
      AttachedEnd(:final wall, :final k, :final side) =>
        words.text('text:architecture.end-on-wall', {
          'wall': wall.toHex(),
          'end': words.word(k == 0
              ? 'text:architecture.end-start'
              : 'text:architecture.end-end'),
          'side': words.word(switch (side) {
            WallSide.left => 'text:architecture.face-left',
            WallSide.centre => 'text:architecture.face-centre',
            WallSide.right => 'text:architecture.face-right',
          }),
        }),
    };
```

  After writing, `grep -n "'—'" lib/src/dimension/dimension_plan.dart` must show the em dash U+2014 (today's `selection_panel.dart:948`), and `grep -n "°" ...` the degree sign.

- [ ] **Step 6: The kit.** In `lib/src/kit.dart`: `import 'dimension/dimension_plan.dart';` and `dimensionPlanType` appended to `types` (last, after `roomPlanType`).

- [ ] **Step 7: Run the kit's tests.** `cd packages/jet_cad_2d_kit_architecture && flutter test`. Expected: `All tests passed!` (Task 9's SC-conformance included: the kit's words cover the new type's property ids; a `wordMissing` there is Task 9's word table, report it).

- [ ] **Step 8: The integration support.** Create `packages/jet_cad_2d_integration/test/dimension/dimension_plans.dart`:

```dart
// Plans for the dimension's integration tests (3a Tasks 21, 22), built in
// code through the plan's build seam (spec C1.9) over the architecture
// kit's public types, and read back through the plan's public API (C6).
// Copied, not imported (the plan's Ruling 11-22), from
// jet_cad_floor_plan/test/support/room_fixture.dart (:28-99, :118-194,
// :663-668), wall_fixture.dart (:180-191, :223-235, :284) and
// dimension_fixture.dart (:366-403). The rig's helpers are imported, not
// copied (R-P14).
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart'
    show SelectionKey;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/editor_rig.dart';

export '../support/editor_rig.dart'
    show activeTool, kitCatalog, press, pumpEditor, status;

/// A wall in plan millimetres (room_fixture.dart:28-35).
final class W {
  const W(this.sx, this.sy, this.ex, this.ey, this.t,
      [this.j = Justification.centre]);

  final double sx, sy, ex, ey, t;
  final Justification j;
}

/// Where a plan is placed: plan point -> world point (room_fixture.dart:
/// 50-67).
final class Placement {
  const Placement(this.name, this.dx, this.dy, this.deg, {this.groups = false});

  final String name;
  final double dx, dy, deg;
  final bool groups;

  Transform2 get m => Transform2.translation(dx, dy)
      .multiply(Transform2.rotation(deg * math.pi / 180));

  Vector2 at(double x, double y) => m.transformPoint(Vector2(x, y));

  @override
  String toString() => name;
}

const origin = Placement('origin', 0, 0, 0);
const corpusGroups = Placement(
    'corpus far origin, 23 deg, own groups', 4500000, 1200000, 23,
    groups: true);

/// A group transform for object number [k] of a [Placement.groups] plan
/// (room_fixture.dart:94-97).
Transform2 groupFor(Placement p, int k) => p.m
    .multiply(Transform2.translation(311.5 * (k % 7), -173.25 * (k % 5)))
    .multiply(Transform2.rotation(0.3 + 0.7 * (k % 9)));

/// C2: an L, A east then B north, 200 each (dimension_fixture.dart:76).
const List<W> c2Walls = [W(0, 0, 4000, 0, 200), W(4000, 0, 4000, 3000, 200)];

/// A page at 1:50 in millimetres (dimension_fixture.dart:366-367).
PageComponent get mmPage =>
    PageComponent().copyWith(displayUnit: DisplayUnit.millimeters);

/// [page] on [doc]'s root, one command.
void setPage(DraftDocument doc, PageComponent page) => doc.commands
    .execute(SetComponentCommand<PageComponent>(doc.rootHandle, page));

/// A controller over the architecture kit whose new plan [build] fills
/// (spec C1.9: the plan's own document, system and DASHED record; the
/// history cleared after). A throw inside [build] fails the test (the
/// controller would only report it as a diagnostic). Disposed at
/// tear-down.
PlanController planOf(void Function(DraftDocument doc) build) {
  Object? failure;
  StackTrace? trace;
  final c = PlanController(
      kits: [architectureKit],
      build: (doc, _) {
        try {
          build(doc);
        } catch (e, s) {
          failure = e;
          trace = s;
          rethrow;
        }
      });
  addTearDown(c.dispose);
  if (failure != null) fail('the build threw: $failure\n$trace');
  return c;
}

/// A separator in plan millimetres (room_fixture.dart:37).
typedef S = (double sx, double sy, double ex, double ey);

/// An opening: its host's index in the plan's wall list, its position, its
/// width, kind and swing side (room_fixture.dart:41-47).
typedef O = (
  int wall,
  double position,
  double width,
  OpeningKind kind,
  SwingSide swing
);

/// What [buildPlanIn] added, in the order given.
typedef Built = ({List<Handle> walls, List<Handle> seps, List<Handle> openings});

/// room_fixture.dart:118-163's `buildPlan` on [doc], the plan's own
/// document inside a `PlanBuild`: [walls], then [seps], then [openings]
/// (hosted by the walls they index), each object one command, at [place].
/// Without `installParametric` and `ensureDashedLinetype`: the plan
/// installed its system and prepared the DASHED record (spec C1.3, C1.9).
Built buildPlanIn(DraftDocument doc, List<W> walls,
    {List<S> seps = const [],
    List<O> openings = const [],
    Placement place = origin}) {
  final wh = <Handle>[], sh = <Handle>[], oh = <Handle>[];
  var k = 0;
  for (final w in walls) {
    final h = doc.handleSeed.next();
    final g = place.groups ? groupFor(place, k++) : Transform2.identity();
    final inv = g.invert();
    final s = inv.transformPoint(place.at(w.sx, w.sy));
    final e = inv.transformPoint(place.at(w.ex, w.ey));
    doc.commands.execute(CompoundCommand([
      AddNodeCommand(GroupNode(
          handle: h, parent: doc.rootHandle, transform: g, children: const [])),
      SetComponentCommand<WallParams>(
          h, WallParams(s.x, s.y, e.x, e.y, w.t, w.j)),
    ], label: 'Add wall'));
    wh.add(h);
  }
  for (final (sx, sy, ex, ey) in seps) {
    sh.add(addSeparator(doc, place.at(sx, sy), place.at(ex, ey),
        at: place.groups ? groupFor(place, k++) : null));
  }
  for (final (i, position, width, kind, swing) in openings) {
    oh.add(addOpening(
        doc, OpeningParams(wh[i], position, width, kind, swing: swing)));
  }
  return (walls: wh, seps: sh, openings: oh);
}

/// A separator from world [s] to world [e] in its own root group [at]
/// (room_fixture.dart:165-178).
Handle addSeparator(DraftDocument doc, Vector2 s, Vector2 e, {Transform2? at}) {
  final h = doc.handleSeed.next();
  final g = at ?? Transform2.identity();
  final inv = g.invert();
  final ls = inv.transformPoint(s), le = inv.transformPoint(e);
  doc.commands.execute(CompoundCommand([
    AddNodeCommand(GroupNode(
        handle: h, parent: doc.rootHandle, transform: g, children: const [])),
    SetComponentCommand<SeparatorParams>(
        h, SeparatorParams(ls.x, ls.y, le.x, le.y)),
  ], label: 'Add separator'));
  return h;
}

/// Opening [o] in its own root group at the identity, one command
/// (room_fixture.dart:180-194).
Handle addOpening(DraftDocument doc, OpeningParams o) {
  final h = doc.handleSeed.next();
  doc.commands.execute(CompoundCommand([
    AddNodeCommand(GroupNode(
        handle: h,
        parent: doc.rootHandle,
        transform: Transform2.identity(),
        children: const [])),
    SetComponentCommand<OpeningParams>(h, o),
  ], label: 'Add opening'));
  return h;
}

/// Wall [h] in its own group [at] with the local parameters [p], one
/// command (wall_fixture.dart:180-191).
DraftCommand addWallLocal(
        DraftDocument doc, Handle h, WallParams p, Transform2 at) =>
    CompoundCommand([
      AddNodeCommand(GroupNode(
          handle: h, parent: doc.rootHandle, transform: at, children: const [])),
      SetComponentCommand<WallParams>(h, p),
    ], label: 'Add wall');

/// A dimension from [a] to [b] in its own root group at [at]: the
/// Dimension tool's commit (dimension_fixture.dart:373-386).
Handle addDimension(DraftDocument doc, DimEnd a, DimEnd b,
    {DimKind kind = DimKind.aligned, double offset = 500, Transform2? at}) {
  final h = doc.handleSeed.next();
  doc.commands.execute(CompoundCommand([
    AddNodeCommand(GroupNode(
        handle: h,
        parent: doc.rootHandle,
        transform: at ?? Transform2.identity(),
        children: const [])),
    SetComponentCommand<DimensionParams>(
        h, DimensionParams(a, b, kind, offset)),
  ], label: 'Add dimension'));
  return h;
}

/// A fixed end at world [w] in a group at [at] (dimension_fixture.dart:
/// 390-393).
FixedEnd fixedAt(Vector2 w, [Transform2? at]) {
  final l = (at ?? Transform2.identity()).invert().transformPoint(w);
  return FixedEnd(l.x, l.y);
}

/// [group]'s children, ascending (wall_fixture.dart:223-227).
List<Handle> kids(DraftDocument doc, Handle group) => [
      for (final slot in doc.entities.liveSlots)
        if (doc.entities.ownerAt(slot) == group) doc.entities.handleAt(slot),
    ]..sort((a, b) => a.value.compareTo(b.value));

EntityKind kindOf(DraftDocument doc, Handle h) =>
    doc.entities.kindAt(doc.entities.slotOf(h)!);

GeometryPayload payloadOf(DraftDocument doc, Handle h) =>
    doc.geometry.read(doc.entities.geomIndexAt(doc.entities.slotOf(h)!));

/// Dimension [h]'s value string: its one TEXT child's.
String dimText(DraftDocument doc, Handle h) {
  final text = kids(doc, h).singleWhere((k) => kindOf(doc, k) == EntityKind.text);
  return doc.entities.textAt(doc.entities.slotOf(text)!);
}

/// The select tool's group delete (room_fixture.dart:663-668).
DraftCommand deleteObject(DraftDocument doc, Handle g) => CompoundCommand([
      for (final k in kids(doc, g))
        if (kindOf(doc, k) != EntityKind.fill) RemoveEntityCommand(k),
      RemoveNodeCommand(g),
    ], label: 'Delete');

String enc(DraftDocument doc) => DraftDocumentCodec.encodeToString(doc);

/// `drift()` of [doc] under the kit's types (wall_fixture.dart's `driftOf`)
/// through the rig's [kitCatalog].
List<Handle> driftOf(DraftDocument doc) =>
    ParametricSystem(doc, kitCatalog()).drift();

/// A saved plan with what [add] adds to a copy of [saved] that has no
/// parametric system (room_fixture.dart's `staleFile`): the commands land
/// as given and nothing is generated, as a file written by another program.
String stalePlan(String saved, void Function(DraftDocument bare) add) {
  final bare = decodePlan(saved,
      register: (r) {
        PageComponent.register(r);
        registerKitComponents(r);
        kitCatalog().registerComponents(r);
      },
      diagnostics: <Diagnostic>[]);
  add(bare);
  return encodePlan(bare, validateKitSet([architectureKit]));
}

/// [c]'s editor in a 1440 x 900 window, one frame: the rig's [pumpEditor].
Future<void> pumpPlan(WidgetTester tester, PlanController c,
        {Locale locale = const Locale('en')}) =>
    pumpEditor(tester, c, locale: locale);

/// [hs] as the design's selection, one frame.
Future<void> select(
    WidgetTester tester, PlanController c, List<Handle> hs) async {
  c.activeSelection.replace([for (final h in hs) SelectionKey.root(h)]);
  await tester.pump();
}

Finder byKey(String k) => find.byKey(Key(k));
```

  (`unused_import` is an error in this workspace: an import the file does not use once written is dropped.)

- [ ] **Step 9: Port the panel tests (integration).** Create `packages/jet_cad_2d_integration/test/dimension/dimension_panel_test.dart` from `packages/jet_cad_floor_plan/test/dimension_panel_test.dart`, every case (PN1-PN5 over `origin` and `corpusGroups`, and PN5's refused edit), **assertions unchanged** but for DM-R2 and DM-R3:
  - header comment (`:1-15`): keep, then `// Ported to jet_cad_2d_integration (3a Task 21): PlanEditor's property\n// panel over a PlanController with the architecture kit (spec C6, C7).`
  - imports (`:16-32`) become `dart:convert`, `dart:math`, `dart:typed_data show Float64List`, `package:flutter/material.dart`, `package:flutter_test/flutter_test.dart`, `package:jet_cad_2d/jet_cad_2d.dart`, `package:jet_cad_2d_integration/jet_cad_2d_integration.dart` (`architectureController`, PN5's refused case), `package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart`, `package:vector_math/vector_math_64.dart show Vector2`, `'dimension_plans.dart'` (no `jet_cad_2d_plan` import: the cases name none of its names, the support file does, and `unused_import` fails the analyzer; add it back only if the analyzer reports a plan name undefined).
  - helpers (`:36-117`) become:
    ```dart
    Finder get section => byKey('section-architecture.dimension');
    Finder get value => byKey('property-value');
    Finder get kindMenu => byKey('property-kind');
    Finder get axes => byKey('property-axes');

    String textAt(WidgetTester tester, String key) =>
        tester.widget<Text>(byKey(key)).data!;

    String valueText(WidgetTester tester) => textAt(tester, 'property-value');

    DropdownButton<Object?> menuOf(WidgetTester tester) =>
        tester.widget<DropdownButton<Object?>>(kindMenu);

    /// A choice of [kind] in the kind menu (DM-R3): open it, tap the item
    /// (the menu's copy, the last). A read-only menu does not open: the
    /// click lands on nothing, as a disabled segment's did.
    Future<void> tapKind(WidgetTester tester, DimKind kind) async {
      final enabled = menuOf(tester).onChanged != null;
      await tester.ensureVisible(kindMenu); // the plan panel's own tapKey
      await tester.tap(kindMenu);
      await tester.pumpAndSettle();
      if (!enabled) return;
      await tester.tap(byKey('property-kind-${kind.name}').last);
      await tester.pumpAndSettle();
    }

    DimensionParams paramsOf(DraftDocument doc, Handle h) =>
        doc.components.get<DimensionParams>(h)!;

    Transform2 turned(Placement place, double deg) =>
        place.m.multiply(Transform2.rotation(deg * math.pi / 180));

    /// [h]'s children's payloads as bytes and its TEXT's string
    /// (dimension_panel_test.dart:98-117, unchanged).
    (List<Handle>, List<List<int>>, String) childrenOf(
            DraftDocument doc, Handle h) => /* copy :103-117 unchanged */;
    ```
    (Copy `childrenOf`'s body `:103-117` unchanged; the comment above is the instruction, not code.)
  - `panelPlan(place)` + `finish(plan)` + `pumpShell(...)` (`:70-96`) become one pattern: each case builds through `planOf((doc) { setPage(doc, mmPage); final [a, b] = buildPlanIn(doc, c2Walls, place: place).walls; ... })`, assigning the handles the case uses to `late final` locals declared before the call, then `await pumpPlan(tester, c);` and `final doc = c.document;`. `plan.at(x, y)` → `place.at(x, y)`; `place.m` stays. `select(tester, view, hs)` → `select(tester, c, hs)`.
  - Per case:
    - PN1: `:127-130` (the `bruteCandidates` premise and its comment) not ported (DM-R2). `find.byKey(const Key('wall-section'))` → `byKey('section-architecture.wall')`. The wall edit (`:173-176`) runs on `c.document` after the pump, as today. `driftOf(doc)` is `dimension_plans.dart`'s.
    - PN2: `:203-205` (the `bruteCandidates` expect; the comment `:199-202` stays, it describes `e`) not ported (DM-R2); `b` (`:194`) is then used by nothing, so the build destructures `final [a, _] = ...walls` (`unused_local_variable` fails the analyzer). `switchOf(tester).selected, {DimKind.x}` → `menuOf(tester).value, DimKind.x`; `tapKind(tester, 'dimension-horizontal')` → `tapKind(tester, DimKind.horizontal)` (likewise for every kind); `switchOf(tester).onSelectionChanged!({DimKind.aligned})` → `menuOf(tester).onChanged!(DimKind.aligned)`. The focus line (`:231-232`, `the click leaves the focus where it was`) is kept as written: if the menu's route leaves the focus elsewhere, that is a finding (stop and report; do not change the line).
    - PN3: `textAt(tester, 'dimension-axes')` → `textAt(tester, 'property-axes')`; `axes, findsNothing` stays (`axes` is the row's key, absent when the field is not visible).
    - PN4: the handle seed raised and wall C added inside `planOf`'s build (`doc.handleSeed.raiseTo(const Handle(0x3D))` then `addWallLocal(...)` executed there); the expected strings unchanged.
    - PN5 (looped): `switchOf(tester).onSelectionChanged, isNull` → `menuOf(tester).onChanged, isNull` (and `isNotNull`); `final stale = menuOf(tester).onChanged!; ... stale(DimKind.horizontal);`; the dead-handle click `await tester.tap(find.byKey(const Key('dimension-horizontal')))` → `menuOf(tester).onChanged!(DimKind.horizontal)` read **before** the delete is executed (DM-R3: the callback the panel built for the live dimension, called after the delete and before a rebuild), then `await tester.pump(); await tester.pump();`.
    - PN5 (refused): `src` is `planOf(...)` with C2's L at `corpusGroups` and the dimension; `aOutline` read from `src.document` as today (`:471-473`); `staleFile(src.doc, (bare) {...})` → `stalePlan(src.save(), (bare) {...})` with the same region command; the JSON repointing (`:492-501`) unchanged on `stalePlan`'s text; `DraftDocumentCodec.decode(j, ...)` + `pumpShell(tester, doc, 'refused')` → `final c = architectureController(json: jsonEncode(j)); addTearDown(c.dispose); await pumpPlan(tester, c); final doc = c.document;` (drop the `addTearDown` if Task 9's `architectureController` already registers one). If the controller refuses or repairs the file on load (the premise `throwsStateError` fails, or `c.loadDiagnostics` holds an error), stop and report: a finding, not a test change.

- [ ] **Step 10: Run the integration tests.** `cd packages/jet_cad_2d_integration && flutter test --enable-vmservice test/dimension/`. Expected: `All tests passed!`.

- [ ] **Step 10b: `wall_grips_test` EG9, EG10 (carried from Task 12, R-P8).** Today's `packages/jet_cad_floor_plan/test/wall_grips_test.dart:655-892`; **assertions unchanged**, split as Task 12's R12-3 split EG1-EG6 (kit internals in the kit, the editor in the integration package). Both files are Task 12's, with Task 17's `shadowDoc`/`shadowController` (Step 7b there).
  1. Kit, `packages/jet_cad_2d_kit_architecture/test/wall/wall_grips_test.dart`: add the imports the cases need (`package:jet_cad_2d_kit/testing.dart`, `package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart` for `Grip`, `GripRole`, `ObjectGripProvider`, the kit's `src/kit.dart`, `src/dimension/dimension.dart`, `src/dimension/dimension_attach.dart`, `src/dimension/dimension_grips.dart`, `src/opening/opening_geometry.dart`, `src/opening/opening_grips.dart`, `src/room/room_inputs.dart`, `src/separator/separator_grips.dart`, `src/wall/wall_bands.dart`, `src/wall/wall_geometry.dart` show `wallsInDocument`, and `'../support/dimension_fixture.dart' show dimLines`; the analyzer prunes any unused one). Append:
     - `test("EG9-k a file's group carrying WallParams and OpeningParams is an opening everywhere and a wall nowhere; a separator carrying OpeningParams is a separator everywhere, the kit's readers directly", () {`, today's `:660-677` (the fixture, the orphan, the premise), then `:678-724`, then `});`.
     - `test("EG10-k a file's dimension group carrying WallParams on the joint is a dimension, not a wall, the kit's readers directly", () {`, today's `:767-807` (`gripDoc(FlutterTextMeasurer(), (doc) {` → `gripDoc((doc) {`), `:808-869`, `final q = gridOf(plan(3500, -400));` (`:871`, the kit's `gridOf`), `:872-875` with `// ignore: avoid_dynamic_calls` on the line before `:874`'s `expect([for (final m in c.children) (m as dynamic).handle as Handle],` (the kit's analysis options enable `avoid_dynamic_calls`; Task 17's EG8-k does the same; the line itself unchanged), then `});`.
     - In both, the kit's readers take the live rule (C1.5, R-P17): `wallsInDocument(doc, X)` → `wallsInDocument(doc, X, liveOf(doc))`; `openingsInDocument(doc, X)` → `openingsInDocument(doc, X, liveOf(doc))`; `WallBands()` → `WallBands(liveOf(doc))`; `thickestWall(doc)` → `thickestWall(doc, liveOf(doc))`; every `attachCandidates(...)` gains `live: liveOf(doc),`; `RoomInputs(doc)` → `RoomInputs(doc, liveOf(doc))`; `OpeningGrips()` → `OpeningGrips(live: liveOf(doc))`; `WallGrips()` → `WallGrips(live: liveOf(doc))`; `DimensionGrips(index: index, objectSnap: () => true)` → `DimensionGrips(index: index, objectSnap: () => true, live: liveOf(doc))`.
     - Today's dispatcher `ObjectGrips(...)` (`:715`, `:863-864`; "each group's naming type's provider") is the plan's own dispatch, by the naming type, as DM-R1 ports GE1's: `final services = FakePlanServices(document: doc, catalog: testCatalog()); addTearDown(services.dispose); ObjectGripProvider objectOf(Handle h) => architectureKit.types.singleWhere((t) => t.id == liveOf(doc)(h)).gripsFor(services)!;` with `object.gripsOf(doc, h)` → `objectOf(h).gripsOf(doc, h)`, `object.movable(doc, h)` → `objectOf(h).movable(doc, h)` and `object.separators!` → `SeparatorGrips(inputs: inputs, objectSnap: () => true)`. The compared rows are positions, which the services' own index and inputs do not change. **This mapping is a fixture change for the controller to confirm** (it is DM-R1's, applied to two more cases).
  2. Integration, `packages/jet_cad_2d_integration/test/wall/wall_grips_test.dart`: append EG9 (`:655-760`) and EG10 (`:762-892`) with A12-shell and Task 12's EG1-EG6 mapping, and:
     - EG9: `final doc = shadowDoc(dangling: false);` → `final ctrl = shadowController(dangling: false); final doc = ctrl.document;`; the orphan (`:662-670`) is added on `doc` before any pump; `:678-724` → `// The adapters, the band cache, the attach, the room inputs and the grips: EG9-k (the kit).`
     - EG10: `final doc = gripDoc(FlutterTextMeasurer(), (doc) { <:779-790> });` → `final ctrl = wallController(gripPlan((doc) { <:779-790> })); final doc = ctrl.document;`; the stray (`:794-802`) is written on `doc` before any pump (EG6's order); `:808-869` → `// The adapters, the band cache, the attach, the room inputs and the grips: EG10-k (the kit).`; `:872-875` → `// The provider directly: EG10-k (the kit).`
     - Keys (C7 class 3, Task 14's R14-10, DM-R3): `opening-section` → `section-architecture.opening`, `opening-position` → `property-position`, `dimension-section` → `section-architecture.dimension`, `wall-section` → `section-architecture.wall`.
  - Run `cd packages/jet_cad_2d_kit_architecture && flutter test test/wall/wall_grips_test.dart` and `cd packages/jet_cad_2d_integration && flutter test --enable-vmservice test/wall/wall_grips_test.dart`: `All tests passed!`. A red case is a finding (the code under it is Tasks 12-21's): stop and report it.

- [ ] **Step 11: Format and the gates.** `cd packages/jet_cad_2d_kit_architecture && dart format . && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .`; `cd packages/jet_cad_2d_integration && dart format . && flutter test --enable-vmservice && flutter analyze && dart format --output=none --set-exit-if-changed .`; from the root `dart run tool/ci/check_kit_deps.dart`. Every one green; `git status --short`: only this task's files. Non-ASCII check (Global Constraints): `perl -ne '$n++ if /[^\x00-\x7f]/; END { print $n+0, "\n" }' <file>` gives the source's count on each ported file: `dimension_object_test` 46, `dimension_grips_test` 26, `dimension_panel_test` 23 (no dropped or replaced line holds one; the sources' `—`, `°` and `−` (U+2212, in `'horizontal −30'` and the reasons) included), and `perl -ne 'print "$.: $_" if /[^\x00-\x7f]/' <file>` lists the same lines as over the source; `grep -n "'—'\|°" packages/jet_cad_2d_kit_architecture/lib/src/dimension/dimension_plan.dart packages/jet_cad_2d_kit_architecture/test/dimension/dimension_plan_test.dart` shows U+2014 and the degree sign where Step 5 and Step 2 write them.

- [ ] **Step 12: Commit.**

```bash
git add packages/jet_cad_2d_kit_architecture/lib/src/dimension/dimension_grips.dart packages/jet_cad_2d_kit_architecture/lib/src/dimension/dimension_plan.dart packages/jet_cad_2d_kit_architecture/lib/src/kit.dart packages/jet_cad_2d_kit_architecture/test/dimension/dimension_object_test.dart packages/jet_cad_2d_kit_architecture/test/dimension/dimension_grips_test.dart packages/jet_cad_2d_kit_architecture/test/dimension/dimension_plan_test.dart packages/jet_cad_2d_integration/test/dimension/dimension_plans.dart packages/jet_cad_2d_integration/test/dimension/dimension_panel_test.dart packages/jet_cad_2d_kit_architecture/test/wall/wall_grips_test.dart packages/jet_cad_2d_integration/test/wall/wall_grips_test.dart
git commit -m "$(cat <<'EOF'
feat(kit-architecture): the dimension type, grips and properties (3a C3.6)

dimensionPlanType: the value as drawn (memoised by the history state),
the kind gated by reshape, the axes line and the end lines in the kit's
words with the UI's decimal separator, and the grips over the plan's
services and live types. Seventeen kit cases and the panel's six
integration cases ported; DM-* are new.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 13: Mutation check** (committed files only; after each: run the named test, see it red, quote the red line, then `git checkout -- <file>` and `git diff --quiet -- <file>` must exit 0). `P = packages/jet_cad_2d_kit_architecture/lib/src/dimension/dimension_plan.dart`; kit tests run from `packages/jet_cad_2d_kit_architecture`, integration tests from `packages/jet_cad_2d_integration` with `--enable-vmservice`.
  - M-DM1 `P`: delete `gate: PlanGate.reshape` from the kind's spec → DM-fields red (`flutter test test/dimension/dimension_plan_test.dart`). (No ported case runs under a `PlanPermissions` without `reshape`; DM-fields is the pin.)
  - M-DM2 `P`: in `dimensionEndLine`, swap `'text:architecture.end-start'` and `'text:architecture.end-end'` → DM-fields red; PN1, PN4 red (integration).
  - M-DM3 `P`: `if (memo.handle != object.handle || memo.state != state)` → `if (memo.handle != object.handle)` → DM-value red (`a new state is read`); PN1 red (`after the wall edit`).
  - M-DM4 `P`: the same condition → `if (true)` → DM-value red (`one state: no rescan`).
  - M-DM5 `P`: delete `.replaceAll('.', words.decimalSeparator)` → DM-axes red (German and Turkish lines).
  - M-DM6 `P`: `WallSide.right => 'text:architecture.face-right'` → `WallSide.right => 'text:architecture.face-left'` → DM-axes red (`sağ yüzey`), PN4 red.
  - M-DM7 `P`: `objectSnap: () => s.objectSnap` → `objectSnap: () => true` → DM-grips red (`F3 off`).
  - M-DM8 `P`: `live: liveTypesOf(s)` → `live: (h) => s.document.components.get<WallParams>(h) != null ? ArchitectureTypes.wall : null` (the pre-C1.5 rule; add `import '../wall/wall.dart' show WallParams;`) → DM-grips red (`A frozen`).
  - M-DM9 `lib/src/dimension/dimension_grips.dart`: in `drag`, `if (next == null || next.params == s.params) return null;` → `if (next == null) return null;` → GE2 red (`a drop that changes nothing returns null`; a port check).
  - M-DM10 `lib/src/dimension/dimension.dart` (Task 20's file, committed): in `generate`, `line(l.ext0, flags: EntityFlags.unpickable)` → `line(l.ext0)` → DO1 red (a port check).

#### Interface problem

1. **(Resolved by rulings R-P4 and R-P7: `PlanObject.words` is a `PlanWords`; `fieldsOf(document, group, words)` and `commitField(document, group, field, input, words)` take the words last and positionally. The code above follows them.)** **A `TextDisplay`'s `read` cannot reach the words.** Shared interfaces give `TextDisplay.read: String? Function(T value, PlanObject object)` and `PlanObject { document; handle; world; }` (the 3a plan, "Shared interfaces", `properties.dart` block). Spec C3.6 needs the axes line "degrees with `KitWords.decimalSeparator`" and End 1, End 2 "`text:architecture.endOnWall` with the start or end word and the side word, or the fixed word"; spec C1.6 says `KitWords.decimalSeparator` exists so "a kit formats a number in the UI language (the axes line)". Today the panel reads its own strings for both (`jet_cad_floor_plan/lib/src/selection_panel.dart:907-931`, `_strings.axesTurned`, `_strings.endOnWall`, `_strings.decimalSeparator`). Neither `read`'s arguments nor `PlanType.fieldsOf(DraftDocument, Handle)` carry a `KitWords`, and a `PlanType` is a static value (`architectureKit` is built once, `plan_type.dart:34-48`), so no closure can capture the plan's words either. **Proposed fix** (what Steps 2, 3 and 5 are written against): `PlanObject` gains `KitWords get words;` (the owning kit's words at the plan's current locale: `PlanServices.words`), `DocumentPlanObject(this.document, this.handle, this.words)`, and `PlanType.fieldsOf(DraftDocument document, Handle group, {required KitWords words})` and `commitField(DraftDocument document, Handle group, PropertyField field, Object? input, {required KitWords words})` build it; the plan's panel passes `c.servicesOf(kit).words`, as it already does to `sectionFor` (`plan_property_panel.dart:836-845`). A language switch then re-words the lines at the panel's next build (the panel rebuilds on `reportLocale`). Alternative: a third `read` argument, `String? Function(T value, PlanObject object, KitWords words)`, with the same `fieldsOf`/`commitField` change. Either way Task 2 owns the change; this task's `object.words` (three uses) and its test helper `fieldsOf(..., words:)` follow the controller's choice.
2. **(Resolved by ruling R-P5: Task 26 ports it, its Step 9 item 10.)** **`dimension_paint_test` needs the sample flat, which lands in Task 25.** Its three cases (RR1, RR2, RR3) open today's `startupPlan(FlutterTextMeasurer())` (`dimension_paint_test.dart:45-60`) and assert pixels at the sample's five dimensions (`dimsOf`, `:62-66`; the width and the Hall's, `:229`). The sample is `buildSampleFlat` (Task 25) and `sampleFlatController()` arrives with it; Task 25 itself needs this task's `dimensionPlanType` (the sample has five dimensions), so the order cannot be swapped. **Proposed fix (settled by ruling R-P5: Task 26):** the port below runs in Task 26 (after `sampleFlatController()` exists), as `packages/jet_cad_2d_integration/test/dimension/dimension_paint_test.dart`, every case, assertions unchanged:
   - imports: drop `planner_shell.dart`, `parametric/catalog.dart`, `planner_view.dart`, `startup_plan.dart`; `parametric/dimension.dart` → `package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart`; add `package:jet_cad_2d_integration/jet_cad_2d_integration.dart`, `package:jet_cad_2d_plan/jet_cad_2d_plan.dart`, `'dimension_plans.dart'` (for `kids`, `kindOf`, `dimText`-free helpers it needs); `support/dimension_fixture.dart`'s `dimTextHandle` and `pageOf` copied into the test (`dimension_fixture.dart:396-399`, `room_fixture.dart:615-619`).
   - `samplePlan({scale, background})` (`:45-60`) → `PlanController sampleFlat({double scale = 50, int? background})`: `final c = sampleFlatController(); addTearDown(c.dispose);` then, when `scale != 50 || background != null`, `c.document.commands.execute(SetComponentCommand<PageComponent>(c.document.rootHandle, pageOf(c.document).copyWith(scaleDenominator: scale, background: background ?? pageOf(c.document).background)))` and `c.document.commands.clearHistory()` (the controller's own system regenerates, so no `installParametric`); `expect(driftOf(c.document), isEmpty)`; callers read `c.document` where they read `doc`.
   - `Rig.of(tester, doc)` (`:85-94`) → `Rig.of(tester, PlanController c)`: `RepaintBoundary(key: capture, child: planEditorApp(c))`; the field `view` → `controller`; `view.camera.value = camera` → `controller.camera.value = camera`; `view.camera.value` → `controller.camera.value`.
   - `find.byType(InteractionLayer)` stays (the plan's canvas draws through it); every other line unchanged. A frame whose canvas rect differs from the shell's changes no assertion: the samples are taken at world points through the camera.

#### New shared name

- None beyond Task 20's. This task's integration support `test/dimension/dimension_plans.dart` is test-local (Task 22 extends it; no other task imports it).

---

