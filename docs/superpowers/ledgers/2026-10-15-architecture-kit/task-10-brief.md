### Task 10: The box (spec C3.1; C7)

**Files:**
- Create (`packages/jet_cad_2d_kit_architecture/`): `lib/src/box/box.dart` (ported), `lib/src/box/box_tool.dart` (ported), `lib/src/box/box_plan.dart` (new), `test/support/catalog.dart` (new: the kit tests' engine catalog), `test/box/box_test.dart` (ported), `test/box/box_plan_test.dart` (new)
- Modify (`packages/jet_cad_2d_kit_architecture/`): `lib/src/kit.dart` (the type and the tool), `lib/jet_cad_2d_kit_architecture.dart` (`BoxParams`), `CHANGELOG.md`
- Create (`packages/jet_cad_2d_integration/`): `test/box/planner_box_test.dart` (ported)

**Interfaces:**
- Consumes:
  - Task 9: `ArchitectureTypes.box`, `ArchitectureTools.box` (`lib/src/ids.dart`), `architectureKit` (`lib/src/kit.dart`), the word ids `type:architecture.box`, `tool:architecture.box`, `property:architecture.box.{width,height}`; the integration package's `architectureController`, `planEditorApp` and its rig (`test/support/editor_rig.dart`: `pumpEditor`, `globalOf`, `status`, `press`, `pagePlanJson`, `kitCatalog`).
  - Task 2 (R-P4, R-P7): `PlanType.fieldsOf(DraftDocument document, Handle group, PlanWords words)`, `commitField(DraftDocument document, Handle group, PropertyField field, Object? input, PlanWords words)`; `LengthProperty` as today plus `range`/`visible` (unused here).
  - Task 6: `FakePlanServices({required DraftDocument document, ...})`, `dispose()` (`package:jet_cad_2d_kit/testing.dart`).
  - The contract today: `PlanType` (`plan_type.dart:34-164`: `grips`, `hasColour`, `hasSection`, `exported`, `registerInto`), `PlanTool` (`plan_tool.dart:36-62`), `LengthProperty` (`properties.dart:72-104`), `PlanGate.reshape`.
  - The Flutter layer: `RectangleTool`, `isDegenerateRectangle` (today's `box_tool.dart:1-47` builds on them).
- Produces (Shared interfaces, exact):

```dart
// lib/src/box/box_plan.dart
final PlanType<BoxParams> boxPlanType;   // id ArchitectureTypes.box; width, height
final PlanTool boxPlanTool;              // id ArchitectureTools.box, letter 'B'
// lib/jet_cad_2d_kit_architecture.dart gains: export 'src/box/box.dart' show BoxParams;
// architectureKit: types [boxPlanType], tools [boxPlanTool]
```

  Kept under `lib/src/box/` with today's names: `BoxParams` (`componentTypeId` now `ArchitectureTypes.box`), `BoxType`, `BoxTool`. Test support produced for every later kit task: `test/support/catalog.dart`'s `testCatalog` and `installParametric` (see "New shared name").

**Appendix A rows closed:**
- D-19, the box: `box_test.dart` (6 of 6: BT1-BT6, kit), `planner_box_test.dart` (6 of 6: BX1-BX6, integration). Neither was ported before (checked: no `BT`/`BX` case and no port header for either file in `packages/jet_cad_2d_plan/test` or `packages/jet_cad_2d_kit/test`; the plan's `box.box` test kit, `jet_cad_2d_plan/test/support/panel_kits.dart:1-341`, is a stand-in for the panel tests and is left alone).

Plan decisions and rulings:
- **The strict bound lives in `write`** (spec C1.1, C3.1): today's panel commits a box side when `value.isFinite && value > 0` (`jet_cad_floor_plan/lib/src/selection_panel.dart:415-417`); the field already refuses a value that is not finite (`properties.dart:376-379`), and `write` throws `ArgumentError` for the rest, which the panel takes as a silent refusal (`jet_cad_2d_plan/lib/src/panels/plan_property_panel.dart:497-525`). No constant `min`: an inclusive `min: 0` would accept 0.
- **The gate is `reshape`**: today a box side is editable only with the host's `reshape` (`selection_panel.dart:384-390`, `_capable`), plus the `components` permission and the type's `editCapability`, which the plan library checks for every field.
- **No grips, no colour, no section, exported** (today's: `ObjectGrips._of` has no box branch, `object_grips.dart:80-86`; `pickedColors` lists rooms and tables only).
- **The tool's icon** is `Icons.crop_din` (today's palette has text rows only, `planner_shell.dart:546-552`; the plan's box stand-in uses this icon, `panel_kits.dart:316`).
- **The integration fixture's grid snap is on** (BX1-BX6): under the editor's turned camera a click's world point does not come back exactly (the plan library measured 120 × 69.99999999999955 for BX4's first box, `jet_cad_2d_plan/test/panels/selection_panel_test.dart:38-43`, and turned the grid on there); the grid gives the clicks today's exact corners. A fixture change (C7), no assertion changes.

- [ ] **Step 1: Precondition.** Task 9 is committed. `cd packages/jet_cad_2d_kit_architecture && flutter test` and `cd packages/jet_cad_2d_integration && flutter test --enable-vmservice`: `All tests passed!`. Read Task 2's `packages/jet_cad_2d_kit/lib/src/kit/plan_type.dart` (`fieldsOf`, `commitField`): they take the words last and positionally (rulings R-P4, R-P7), as BX-props passes them.

- [ ] **Step 2: The failing kit tests.**
  1. Create `test/support/catalog.dart`:

```dart
// The kit tests' engine catalog (spec 3a "Tests": every type's generate
// through the engine's ParametricSystem): today's global parametricCatalog
// and installParametric (jet_cad_floor_plan/lib/src/parametric/
// catalog.dart:27-39, :64-65) for the kit's own tests. The kit's raw types
// (no plan guard), under their ArchitectureTypes ids, in today's order --
// box, wall, opening, separator, room, dimension -- each type task adding
// its line (this task the box's).
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit_architecture/src/box/box.dart';

final ParametricCatalog _testCatalog = ParametricCatalog()
  ..register<BoxParams>(
      BoxParams.componentTypeId, BoxParams.fromJson, const BoxType());

/// The kit tests' catalog (ruling R-P13): the one instance above, so every
/// call sees every registration the type tasks append to its cascade.
ParametricCatalog testCatalog() => _testCatalog;

/// Builds and installs [doc]'s parametric system over [testCatalog].
ParametricSystem installParametric(DraftDocument doc) =>
    ParametricSystem(doc, testCatalog())..install();
```

  2. Create `test/box/box_test.dart`: **ported from `packages/jet_cad_floor_plan/test/box_test.dart`, BT1-BT6, assertions unchanged.** Copy lines 1-91 with these adaptations only:
     - a header comment first: `// Ported from jet_cad_floor_plan/test/box_test.dart (spec 06 D13); assertions unchanged but BT1's id (spec 3a C7 class 1). The floor planner's catalog becomes the kit tests' (test/support/catalog.dart).`
     - `:3` `import 'package:jet_cad_floor_plan/src/parametric/box.dart';` → `import 'package:jet_cad_2d_kit_architecture/src/box/box.dart';`
     - `:4` `import 'package:jet_cad_floor_plan/src/parametric/catalog.dart';` → `import '../support/catalog.dart';`
     - `:39` `expect(p.typeId, 'floor_planner.box');` → `expect(p.typeId, 'architecture.box');` (C7 class 1, ids).
     - `:62` `expect(ParametricSystem(doc, parametricCatalog).drift(), isEmpty);` → `expect(ParametricSystem(doc, testCatalog()).drift(), isEmpty);`
     - `installParametric(doc)` (`:48`, `:57`, `:69`) is unchanged: the support's.
     - The imports are sorted as `dart format` and the analyzer want (`dart:` first, then `package:`, then relative).
  3. Create `test/box/box_plan_test.dart` (new; ids BX-props, BX-kit):

```dart
// Spec 3a C3.1: the box as the kit declares it. Its two properties are
// lengths above zero, the bound strict and refused in write (today's
// selection_panel.dart:415-417), gated by reshape (today's _capable,
// :384-390); its type has no grips, colour or section and is exported; its
// tool is B. The box sits in a group turned 30 degrees, off the origin.
import 'dart:math' as math;

import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:jet_cad_2d_kit/testing.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_kit_architecture/src/box/box_plan.dart';
import 'package:jet_cad_2d_kit_architecture/src/box/box_tool.dart';

import '../support/catalog.dart';

final Transform2 atA = Transform2.translation(7010.5, 3020.25)
    .multiply(Transform2.rotation(math.pi / 6));

/// The panel's words (English, no kit words: the box's fields need none).
final KitWords words = KitNamesWords(KitNames.empty, () => const Locale('en'));

void main() {
  const a = Handle(1000);

  test(
      'BX-props width and height: a positive length commits one step, zero, '
      '-0.0 and a negative are refused in write; both need reshape', () {
    final doc = DraftDocument.empty();
    addTearDown(doc.dispose);
    installParametric(doc);
    doc.commands.execute(CompoundCommand([
      AddNodeCommand(GroupNode(
          handle: a,
          parent: doc.rootHandle,
          transform: atA,
          children: const [])),
      SetComponentCommand<BoxParams>(a, const BoxParams(1200.5, 800.25)),
    ], label: 'Add box'));
    final [width, height] = boxPlanType.fieldsOf(doc, a, words);
    expect(width.wordId, 'property:architecture.box.width');
    expect(height.wordId, 'property:architecture.box.height');
    expect((width.value, height.value), (1200.5, 800.25));
    for (final f in [width, height]) {
      // M-BX-2: a side without its gate.
      expect(f.spec.gate, PlanGate.reshape, reason: f.wordId);
      for (final bad in [0.0, -0.0, -3.0]) {
        // M-BX-1: the bound inclusive (`v >= 0`).
        expect(() => boxPlanType.commitField(doc, a, f, bad, words),
            throwsArgumentError,
            reason: '${f.wordId} $bad');
      }
    }
    final depth = doc.commands.undoDepth;
    doc.commands.execute(boxPlanType.commitField(doc, a, width, 1e-3, words));
    doc.commands.execute(boxPlanType.commitField(doc, a, height, 950.75, words));
    expect(doc.components.get<BoxParams>(a), const BoxParams(1e-3, 950.75));
    expect(doc.commands.undoDepth, depth + 2, reason: 'one step each');
    expect(ParametricSystem(doc, testCatalog()).drift(), isEmpty);
  });

  test(
      'BX-kit the kit carries the box: its type (no grips, colour or '
      'section; exported) and its tool B, which needs structure, components '
      'and geometry, has no settings and makes a BoxTool', () {
    expect(architectureKit.types, contains(boxPlanType));
    expect(boxPlanType.id, ArchitectureTypes.box);
    expect(BoxParams.componentTypeId, boxPlanType.id);
    expect(boxPlanType.grips, isNull);
    expect(boxPlanType.hasColour, isFalse);
    expect(boxPlanType.hasSection, isFalse);
    expect(boxPlanType.exported, isTrue);
    expect(architectureKit.tools, contains(boxPlanTool));
    expect(boxPlanTool.id, ArchitectureTools.box);
    // M-BX-3: another letter.
    expect(boxPlanTool.letter, 'B');
    expect(boxPlanTool.needs,
        {Capability.structure, Capability.components, Capability.geometry});
    expect(boxPlanTool.settings, isNull);
    expect(architectureKit.propertyIds,
        containsAll(['architecture.box.width', 'architecture.box.height']));
    final doc = DraftDocument.empty();
    addTearDown(doc.dispose);
    final services = FakePlanServices(document: doc);
    addTearDown(services.dispose);
    final tool = boxPlanTool.create(services);
    addTearDown(tool.dispose);
    expect(tool, isA<BoxTool>());
  });
}
```

- [ ] **Step 3: Run them, expecting failure.** `cd packages/jet_cad_2d_kit_architecture && flutter test test/box`. Expected: compilation errors, `Target of URI doesn't exist` for `src/box/box.dart`, `src/box/box_plan.dart` and `src/box/box_tool.dart`. Quote them.

- [ ] **Step 4: The kit's box.**
  1. `lib/src/box/box.dart`: **copy `packages/jet_cad_floor_plan/lib/src/parametric/box.dart` lines 1-124**, adapted:
     - a header comment first: `// The box (spec 3a C3.1), ported from jet_cad_floor_plan/lib/src/parametric/box.dart: its parameters and its type, unchanged but for its id.`
     - after `:4` (the `vector_math` import) add a blank line and `import '../ids.dart';`
     - `:10` `static const String componentTypeId = 'floor_planner.box';` → `static const String componentTypeId = ArchitectureTypes.box;`
     - every other line unchanged (`BoxParams`, `_corners`, `BoxType`, `_insideInterval`).
  2. `lib/src/box/box_tool.dart`: **copy `packages/jet_cad_floor_plan/lib/src/parametric/box_tool.dart` lines 1-47 unchanged**, with a header comment first: `// The Box tool (spec 3a C3.1), ported unchanged from jet_cad_floor_plan/lib/src/parametric/box_tool.dart.` (its `import 'box.dart';` names the kit's own file).
  3. `lib/src/box/box_plan.dart` (new):

```dart
// The box as the kit declares it (spec 3a C3.1): its PlanType, whose two
// properties are lengths above zero (today's panel rule,
// jet_cad_floor_plan/lib/src/selection_panel.dart:415-417), refused in
// write and gated by reshape (:384-390); and its PlanTool, B (today's
// palette entry, planner_shell.dart:546-552). No grips, as today.
import 'package:flutter/material.dart' show Icons;
import 'package:jet_cad_2d/jet_cad_2d.dart' show Capability;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';

import '../ids.dart';
import 'box.dart';
import 'box_tool.dart';

/// [v] when it is above zero; otherwise an [ArgumentError], which the
/// property panel takes as a silent refusal (the field shows the stored
/// value). The field has already refused a value that is not finite.
double _positive(double v) =>
    v > 0 ? v : throw ArgumentError.value(v, 'length', 'must be above 0');

/// The box's type: width and height, each a length above zero.
final PlanType<BoxParams> boxPlanType = PlanType<BoxParams>(
  id: ArchitectureTypes.box,
  fromJson: BoxParams.fromJson,
  parametric: const BoxType(),
  properties: [
    LengthProperty<BoxParams>(
        id: 'width',
        read: (p) => p.width,
        write: (p, v) => p.copyWith(width: _positive(v)),
        gate: PlanGate.reshape),
    LengthProperty<BoxParams>(
        id: 'height',
        read: (p) => p.height,
        write: (p, v) => p.copyWith(height: _positive(v)),
        gate: PlanGate.reshape),
  ],
);

/// The Box tool: two opposite corners, one box.
final PlanTool boxPlanTool = PlanTool(
  id: ArchitectureTools.box,
  icon: Icons.crop_din,
  letter: 'B',
  needs: const {
    Capability.structure,
    Capability.components,
    Capability.geometry,
  },
  create: (_) => BoxTool(),
);
```

  4. `lib/src/kit.dart`: add `import 'box/box_plan.dart';` and, in `architectureKit`, `types: [boxPlanType],` and `tools: [boxPlanTool],` after `version:`.
  5. `lib/jet_cad_2d_kit_architecture.dart`: add `export 'src/box/box.dart' show BoxParams;` before the `ids.dart` export.
  6. `CHANGELOG.md`: append the bullet `- The box (`architecture.box`, `BoxParams`): a rectangle whose outline loses what lies inside an overlapping box; its width and height in the property panel; the Box tool (B).`

- [ ] **Step 5: Run the kit's tests, expecting pass.** `cd packages/jet_cad_2d_kit_architecture && dart format . && flutter test`. Expected: `All tests passed!` (BT1-BT6, BX-props, BX-kit; Task 9's SC-conformance now holds `property:architecture.box.width`/`.height` from the descriptor; SC-example lists `architecture.box (B)`).

- [ ] **Step 6: The failing integration test.** Create `packages/jet_cad_2d_integration/test/box/planner_box_test.dart`: **ported from `packages/jet_cad_floor_plan/test/planner_box_test.dart`, BX1-BX6, assertions unchanged**, over `support/box_rig.dart`'s fixtures (`boxDoc`, `pumpDraw`, `globalOf`, `status`, `press`, `boxKids`, `boxes`) rebuilt on the editor rig:

```dart
// Ported from jet_cad_floor_plan/test/planner_box_test.dart (BX1-BX6, spec
// 06 D13); assertions unchanged. PlannerShell becomes PlanEditor over
// architectureController() (spec 3a C6, C7); the palette's 'tool-box' is
// 'tool-architecture.box' (C7 class 1, ids); BX4's drift is asked of the
// kit's types (kitCatalog) instead of the floor planner's catalog. The
// fixture is box_rig.dart's boxDoc (a 1:20 page anchored at (7000, 3000),
// nothing drawn) opened by the controller, its grid snap on: under the
// editor's turned camera a click's world point does not come back exactly
// (the plan library's selection_panel_test.dart:38-43 measured a box of
// 120 x 69.99999999999955), and the grid gives the clicks today's corners.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_integration/jet_cad_2d_integration.dart';
import 'package:jet_cad_2d_kit_architecture/jet_cad_2d_kit_architecture.dart';
import 'package:jet_cad_2d_plan/jet_cad_2d_plan.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/editor_rig.dart';

/// box_rig.dart's `pumpDraw(tester, boxDoc(...))`: the page opened by a
/// controller over the kit, its editor under the turned, zoomed camera
/// centred on (7150, 3110).
Future<PlanController> pumpBoxes(WidgetTester tester) async {
  final c = architectureController(
      json: pagePlanJson(PageComponent(
          scaleDenominator: 20,
          originX: 7000,
          originY: 3000,
          snapToGrid: true)));
  addTearDown(c.dispose);
  await pumpEditor(tester, c, centre: Vector2(7150, 3110));
  return c;
}

/// box_rig.dart's `boxKids` (:77-80): [box]'s generated children,
/// ascending, found by owner.
List<Handle> boxKids(DraftDocument doc, Handle box) => [
      for (final slot in doc.leavesByOwner()[box] ?? const <int>[])
        doc.entities.handleAt(slot),
    ];

/// box_rig.dart's `boxes` (:84-85).
List<Handle> boxes(DraftDocument doc) =>
    doc.components.withComponent<BoxParams>().toList();

// [copy planner_box_test.dart:12-36 unchanged: _worldOf, _childMidpoint,
// _strictlyInside]

void main() {
  testWidgets('BX1 B and the palette entry activate the Box tool',
      (tester) async {
    await pumpBoxes(tester);
    await press(tester, LogicalKeyboardKey.keyB);
    expect(status(tester), 'Box');
    await press(tester, LogicalKeyboardKey.keyV);
    await tester.tap(find.byKey(const Key('tool-${ArchitectureTools.box}')));
    await tester.pump();
    expect(status(tester), 'Box');
  });

  testWidgets('BX2 two clicks: one box, four lines, one undo step',
      (tester) async {
    final c = await pumpBoxes(tester);
    final doc = c.document;
    // [copy planner_box_test.dart:54-66 unchanged, with
    // `globalOf(tester, view, x, y)` → `globalOf(tester, c, x, y)`]
  });

  testWidgets('BX3 Fill does not apply to a box', (tester) async {
    final c = await pumpBoxes(tester);
    // [copy :71-78 with `view` → `c` in globalOf, and
    // `view.document` → `c.document`]
  });

  testWidgets('BX4 two overlapping boxes read as one outline', (tester) async {
    final c = await pumpBoxes(tester);
    final doc = c.document;
    // [copy :84-111 with `view` → `c` in globalOf, and :100
    // `ParametricSystem(doc, parametricCatalog).drift()` →
    // `ParametricSystem(doc, kitCatalog()).drift()`]
  });

  testWidgets(
      'BX5 click a box, Delete: gone with its component; cmd+Z '
      'brings both back (Review Focus 2)', (tester) async {
    final c = await pumpBoxes(tester);
    final doc = c.document;
    // [copy :119-137 with `view` → `c` in globalOf]
  });

  testWidgets('BX6 typing B in the page panel field does not switch tools',
      (tester) async {
    await pumpBoxes(tester);
    // [copy :143-149 unchanged: PlanEditor's right column is keyed
    // `chrome-right` too (plan_editor.dart:957), holding the layer and page
    // panels' fields]
  });
}
```

  Every bracketed copy is the source's lines verbatim but for the renames it names; no assertion line changes. Run `grep -n "view" packages/jet_cad_2d_integration/test/box/planner_box_test.dart` afterwards: no hit.

- [ ] **Step 7: Run it.** `cd packages/jet_cad_2d_integration && dart format . && flutter test --enable-vmservice test/box`. Expected: `All tests passed!` (the kit's code is in from Step 4, so this run is green at once; the red run of these ports is M-BX-5's below). If BX4 counts other than four children per box, quote the counts and stop: the grid premise of this fixture failed.

- [ ] **Step 8: The gates.** From the repository root:
  - `cd packages/jet_cad_2d_kit_architecture && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` — `All tests passed!`, `No issues found!`, exit 0.
  - `cd packages/jet_cad_2d_integration && flutter test --enable-vmservice && flutter analyze && dart format --output=none --set-exit-if-changed .` — the same.
  - `dart run tool/ci/check_kit_deps.dart` — `kit dependencies: 2 package(s) checked, none names the plan library or another kit`.
  - `git status --short`: only this task's files.

- [ ] **Step 9: Commit.**

```bash
git add packages/jet_cad_2d_kit_architecture/lib/src/box/box.dart packages/jet_cad_2d_kit_architecture/lib/src/box/box_tool.dart packages/jet_cad_2d_kit_architecture/lib/src/box/box_plan.dart packages/jet_cad_2d_kit_architecture/lib/src/kit.dart packages/jet_cad_2d_kit_architecture/lib/jet_cad_2d_kit_architecture.dart packages/jet_cad_2d_kit_architecture/CHANGELOG.md packages/jet_cad_2d_kit_architecture/test/support/catalog.dart packages/jet_cad_2d_kit_architecture/test/box/box_test.dart packages/jet_cad_2d_kit_architecture/test/box/box_plan_test.dart packages/jet_cad_2d_integration/test/box/planner_box_test.dart
git commit -m "$(cat <<'EOF'
feat(kit-architecture): the box

Today's box, its id architecture.box: overlapping boxes subtract each
other; width and height are lengths above zero, gated by reshape; the
Box tool is B. Its tests are ported, the shell's onto PlanEditor in the
integration package; the kit's tests get their engine catalog.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 10: Mutation check** (committed files only; after each: run the named test, see it red, then `git checkout -- <file>` and `git diff --quiet -- <file>` must exit 0). Kit tests: `cd packages/jet_cad_2d_kit_architecture && flutter test <file>`; integration: `cd packages/jet_cad_2d_integration && flutter test --enable-vmservice <file>`.
  - M-BX-1 `packages/jet_cad_2d_kit_architecture/lib/src/box/box_plan.dart`: `v > 0 ? v :` → `v >= 0 ? v :` → BX-props red (0.0 and -0.0 commit).
  - M-BX-2 `box_plan.dart`: delete the width's `gate: PlanGate.reshape` (keep the closing parenthesis) → BX-props red.
  - M-BX-3 `box_plan.dart`: `letter: 'B'` → `letter: 'X'` → BX-kit red, and BX1 red (`B` activates nothing).
  - M-BX-4 `lib/src/box/box.dart`: in `BoxType.generate`, `if (inside == null) continue;` → `continue;` (no box clips another) → BT3 red (A 4, B 4) and BX4 red (a child midpoint inside the other box).
  - M-BX-5 `lib/src/kit.dart`: `types: [boxPlanType],` → `types: [],` → BX-kit red, and BX2 red (the plan has no box type: the tool's commit is refused, no box).
  - M-BX-6 `lib/src/box/box.dart`: `componentTypeId = ArchitectureTypes.box` → `componentTypeId = 'architecture.boxes'` → BT1 red.

  Quote each red line.

#### Assumed from earlier tasks

- Task 9: the kit's `kit.dart`, barrel, CHANGELOG and words as Task 9 wrote them; the integration rig (`pumpEditor`, `globalOf`, `status`, `press`, `pagePlanJson`, `kitCatalog`).
- Task 4: `PlanEditor`'s status line is the tool's label alone when nothing is selected and the tool has no notice (BX1's and BX6's `'Box'`).
- Task 2: `fieldsOf`/`commitField` as in the Shared interfaces, the words last and positional (R-P4, R-P7).

#### New shared name

- **The kit tests' engine catalog**, `packages/jet_cad_2d_kit_architecture/test/support/catalog.dart` (this task creates it, with the box):

```dart
ParametricCatalog testCatalog();                        // raw types, today's order (R-P13)
ParametricSystem installParametric(DraftDocument doc);  // ParametricSystem(doc, testCatalog())..install()
```

  Each type task appends one `..register<T>(T.componentTypeId, T.fromJson, const XType())` line to `_testCatalog`'s cascade in today's order (`jet_cad_floor_plan/lib/src/parametric/catalog.dart:27-39`): Task 11 the wall, Task 13 the opening, Task 16 the separator, Task 18 the room, Task 20 the dimension. Its names are today's (`parametricCatalog` → `testCatalog`; `installParametric` kept), so a ported test changes only its import. Ruling R-P13 makes this file and these two names the only ones (no `architectureCatalog`/`installArchitecture`); Task 11's `test/support/wall_fixture.dart` re-exports them (`export 'catalog.dart' show installParametric, testCatalog;`), and every type task's registration goes into this file.

---

