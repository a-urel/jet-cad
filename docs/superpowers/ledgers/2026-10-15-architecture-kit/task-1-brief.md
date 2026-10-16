### Task 1: The symbol box family moves into the contract (spec C1.4)

**Files:**
- Create (`packages/jet_cad_2d_kit/`): `lib/src/model/symbol_box.dart`, `test/support/box_fixtures.dart`, `test/model/symbol_box_test.dart`, `test/model/placement_transform_test.dart`
- Modify (`packages/jet_cad_2d_kit/`): `lib/src/model/model.dart` (one export), `test/support/placements.dart` (its `placementTransform` copy removed)
- Delete (`packages/jet_cad_2d_plan/`): `lib/src/symbols/symbol_box.dart`
- Modify (`packages/jet_cad_2d_plan/`): `lib/src/symbols/symbol_placer.dart`, `lib/src/tools/move_resolver.dart`, `lib/src/tools/plan_symbol_tool.dart`, `lib/src/panels/symbol_section.dart`, `lib/src/panels/plan_property_panel.dart`, `lib/src/controller/services.dart`, `lib/src/units/unit_index.dart`, `lib/src/units/unit_label.dart`; tests `test/symbols/symbol_box_test.dart`, `test/symbols/symbol_placer_test.dart`, `test/symbols/symbol_ghost_test.dart`, `test/tools/plan_symbol_tool_test.dart`, `test/tools/move_resolver_test.dart`, `test/panels/symbol_section_test.dart`, `test/controller/mode_test.dart`, `test/service/service_record_test.dart`, `test/support/service_plans.dart`, `test/support/unit_fixtures.dart`
- Create (`packages/jet_cad_2d_plan/`): `test/invariants/contract_names_test.dart`
- Modify: `docs/superpowers/specs/2026-10-13-kit-contract-design.md` (a new Amendments section, its first line)

**Interfaces:**
- Consumes:
  - Engine (`package:jet_cad_2d/jet_cad_2d.dart`, all pure Dart): `Transform2` (`geometry/transform2.dart:31`), `Aabb2` (`Aabb2.raw`, `Aabb2.empty()`), `EntityKind`, `GeometryPayload`, `DraftDocument`, `Handle`, `Tolerance` (`core/tolerance.dart:17`, `standard.linear` = 1e-9), `angleInSweep` (`geometry/primitives.dart:67`), `isClosedPolyline` (`document/grips.dart:50`).
  - Contract model: `SymbolEntry`, `SymbolLeaf` (`lib/src/model/symbol_library.dart`), `registerKitComponents`.
  - `package:vector_math/vector_math_64.dart` `Vector2` (already a dependency of `jet_cad_2d_kit`, and on the purity walker's allow-list, `test/support/import_walker.dart:21`).
- Produces (Shared interfaces, exact; `lib/src/model/symbol_box.dart`, exported by `jet_cad_2d_kit.dart` and `authoring.dart` through `src/model/model.dart`):

```dart
final class SymbolBox {
  const SymbolBox({required double left, required double right,
      required double front, required double back});
  final double left, right, front, back;
  double get width; double get depth; Vector2 get backCentre;
  // == and hashCode exact on the four sides; toString unchanged
}
bool isOrthonormal(Transform2 g);
SymbolBox? boxOfLeaves(Iterable<(EntityKind, GeometryPayload)> leaves);
SymbolBox? boxOfEntry(SymbolEntry entry);
Aabb2 servedTopOfEntry(SymbolEntry entry);
SymbolBox? boxOfDefinition(DraftDocument doc, Handle definition);
Aabb2 footprintOf(SymbolBox box);
Transform2 placementTransform({required Vector2 at, required Vector2 basePoint,
    int? quarterTurns, (double, double)? rotation, bool mirrored = false});
```

**Appendix A rows closed:** D-09 (the `isOrthonormal` copies: `move_resolver.dart:18` and `symbol_section.dart:137` deleted, one owner in the contract, pinned by SB-one-owner), D-10 (the stale `WallFaces` doc comment, `symbol_box.dart:153`, rewritten in the move). Old test files: none of `jet_cad_floor_plan` (the plan's own `symbol_box_test` and `symbol_placer_test` groups move, assertions unchanged; their source, `jet_cad_floor_plan/test/symbols/symbol_box_test.dart`, keeps its D-13 rows for Task 28).

Plan decisions:
- **Every dependency is pure Dart and the contract's.** `symbol_box.dart` (plan, `:10-14`) imports `dart:math`, `package:jet_cad_2d`, `SymbolEntry` from the kit and `Vector2`; `placementTransform` (`symbol_placer.dart:59-86`) uses only `Transform2`, `Vector2` and its private `_quarterTurn` table; the two `isOrthonormal` copies use `Transform2` and `Tolerance`. No plan-internal type is dragged: no interface problem.
- **One file in `lib/src/model/`**, so the existing purity test P1 (`test/invariants/purity_test.dart:23-34`, which walks every file under `lib/src/model`) covers it with no new walker entry, and both public libraries export it through `model.dart` ("The model's single export list").
- **The whole plan file goes.** Every declaration of `jet_cad_2d_plan/lib/src/symbols/symbol_box.dart` moves (its privates `_axisAngles`, `_axisX`, `_axisY`, `_entryBoxes`, `_Memo` with it), so the file is deleted; every importer takes the names from the contract's barrel, by a `show` list where the file already has one.
- **Test placement (C7).** The plan's `test/symbols/symbol_box_test.dart` groups `SymbolBox`, `boxOfLeaves`, `an arc by its true extents`, `library entries` and the second `boxOfDefinition` case use only contract and engine names: they move. The first `boxOfDefinition` case calls `placeSymbol` (a plan name): it stays. The plan's `test/symbols/symbol_placer_test.dart` group `placementTransform` (P1-P4, P20-P23) uses only `placementTransform`, the fixture library and engine names: it moves; every other group stays. The fixture library (`jet_cad_2d_plan/test/support/symbol_fixtures.dart:23-140`, part one, kit `fixture`) is copied into the contract's test support, since the contract cannot import the plan's tests and its own `library_fixtures.dart` is a different library (kit `sample`, other leaves), so the moved assertions on `fixture.*` boxes keep their numbers.
- **The kit's test copy of `placementTransform` goes.** `jet_cad_2d_kit/test/support/placements.dart:17-39` copied the placer's quarter-turn form for 2b Task 3; once the barrel exports the real one, `test/kit/unit_label_test.dart` (which imports both) would hit an ambiguous import. The copy is deleted; `unit_label_test.dart` is unchanged and now calls the contract's (`quarterTurns` null is 0, the same bytes, P22).
- **CHANGELOG:** written in Task 29 (Global Constraints: the CHANGELOGs gain their 3a additions; the scopes give them to the gate).

- [ ] **Step 1: Precondition.** Run `git status --short` (expected: nothing staged, no change under `packages/`), then `cd packages/jet_cad_2d_kit && flutter test test/invariants/purity_test.dart` (expected `All tests passed!`) and `cd packages/jet_cad_2d_plan && flutter analyze` (expected `No issues found!`).

- [ ] **Step 2: The contract's test fixture.** Create `packages/jet_cad_2d_kit/test/support/box_fixtures.dart`: copy `packages/jet_cad_2d_plan/test/support/symbol_fixtures.dart` lines 25-140 unchanged (the constants `sofaDef` .. `armchairCircle`, `sofaSymbol`, `nightstandSymbol`, `armchairSymbol`, `leafRecord`, `fixtureLeaves`, `buildValidLibrary`, `bytesOf`), under this header (no `package:jet_cad_2d_plan` import, no part two):

```dart
// The 09a fixture library (kit "fixture"), copied from jet_cad_2d_plan's
// test/support/symbol_fixtures.dart part one (lines 25-140, unchanged) for
// the symbol box and placement tests that moved into the contract (3a
// Task 1, spec C1.4): their assertions name these keys and boxes. Not
// degenerate: every base point and leaf off the origin, versions 3, 2 and
// 1, definition handles far apart, the leaves inserted out of handle order.
import 'dart:convert';
import 'dart:typed_data';

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;
```

- [ ] **Step 3: The failing contract tests.**
  1. Create `packages/jet_cad_2d_kit/test/model/symbol_box_test.dart`. Ported from `packages/jet_cad_2d_plan/test/symbols/symbol_box_test.dart`, assertions unchanged: copy its lines 21-46 (`entryIn`, `cx`, `cy`, `r`, `arc`, `boxOfArc`, `ends`, `near`) and 48-53 (`target`) unchanged; in `main`, copy the groups `SymbolBox` (lines 66-98), `boxOfLeaves` (100-179), `an arc by its true extents` (181-262) and `library entries` (264-292) unchanged, then a group `boxOfDefinition` holding only the case `'not a definition (the root, a leaf, nothing), or a definition without leaves: no box'` (lines 319-341, unchanged). Adaptations: imports only (below); `buildValidLibrary`, `bytesOf`, `leafRecord` come from `../support/box_fixtures.dart`. Then the new SB tests. The file:

```dart
// Spec 09c D2, moved into the contract by 3a Task 1 (spec C1.4): the
// symbol's local box. The groups SymbolBox, boxOfLeaves, the arc's true
// extents, the library entries and boxOfDefinition's refusals are
// jet_cad_2d_plan's test/symbols/symbol_box_test.dart (itself ported from
// jet_cad_floor_plan's), assertions unchanged; boxOfDefinition's placed
// case calls the plan's placeSymbol and stays there. New: SB-ortho,
// SB-barrels. Fixtures avoid the degenerate cases (P-2): leaves far from
// the origin, every side of a box set by a different kind of leaf.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/authoring.dart' as authoring
    show boxOfLeaves, footprintOf, isOrthonormal, placementTransform;
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/box_fixtures.dart';

// <- plan lines 21-46 and 48-53 here, unchanged.

void main() {
  // <- plan groups at lines 66-98, 100-179, 181-262, 264-292 here,
  //    unchanged.

  group('boxOfDefinition', () {
    // <- plan lines 319-341 here, unchanged.
  });

  group('isOrthonormal (spec 09c W-8, S-10)', () {
    test(
        'SB-ortho a turn, a mirror and a turned mirror far from the origin '
        'are; a scale, and unit columns that are not perpendicular, are not',
        () {
      final turn = Transform2.translation(-41250.5, 17320.25)
          .multiply(Transform2.rotation(37 * math.pi / 180));
      final turnedMirror = turn.multiply(Transform2.scale(-1, 1));
      expect(isOrthonormal(turn), isTrue);
      expect(isOrthonormal(turnedMirror), isTrue);
      expect(isOrthonormal(Transform2.scale(-1, 1)), isTrue);
      // A file's scale: |a² + b² − 1| = 0.002001.
      expect(isOrthonormal(turn.multiply(Transform2.scale(1.001, 1))), isFalse);
      // Both columns of length 1, at 89.43° to each other: only the
      // a·c + b·d term (sin 0.01 ≈ 0.01) refuses it. M-SB-ortho: drop it.
      final skew =
          Transform2(1, 0, math.sin(0.01), math.cos(0.01), 1e5 + 3.5, -7e4);
      expect((skew.c * skew.c + skew.d * skew.d - 1).abs(),
          lessThanOrEqualTo(Tolerance.standard.linear),
          reason: 'premise: the second column has unit length');
      expect(isOrthonormal(skew), isFalse);
    });
  });

  test(
      'SB-barrels the authoring library exports the family too: the same '
      'functions as the contract barrel', () {
    // A premise of the export list (pure Dart kits build boxes and
    // placements under `dart run`), exempt from the mutation rule beyond
    // M-SB-export: without the export this file does not compile.
    expect(identical(authoring.boxOfLeaves, boxOfLeaves), isTrue);
    expect(identical(authoring.footprintOf, footprintOf), isTrue);
    expect(identical(authoring.isOrthonormal, isOrthonormal), isTrue);
    expect(identical(authoring.placementTransform, placementTransform), isTrue);
  });
}
```

  2. Create `packages/jet_cad_2d_kit/test/model/placement_transform_test.dart`. Ported from `packages/jet_cad_2d_plan/test/symbols/symbol_placer_test.dart`, assertions unchanged: copy its lines 29-34 (`library`, `entryOf`, `sofa`), 101-116 (`expectedWorld` and its doc) and 176-190 (`at`, `far`, `rotations`, `tol`) unchanged; `main` holds the group `placementTransform` (lines 193-394: P1, P2, P3, P4, P20, P21, P22, P23) unchanged. Adaptations: imports only; `bytesOf`, `buildValidLibrary` and `sofaLine` come from `../support/box_fixtures.dart`.

```dart
// Spec 09 D6 and 09c D5, moved into the contract by 3a Task 1 (spec
// C1.4): placementTransform. The group is jet_cad_2d_plan's
// test/symbols/symbol_placer_test.dart group 'placementTransform' (P1-P4,
// P20-P23), assertions unchanged; the placer's own groups stay there.
// Fixtures: every base point and `at` off the origin, rotations of 30° and
// −112.5° (no 0 or ±1), mirrored or not.
import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import '../support/box_fixtures.dart';

// <- plan lines 29-34, 101-116 and 176-190 here, unchanged.

void main() {
  // <- plan lines 193-394 (the group 'placementTransform') here, unchanged.
}
```

  Run `cd packages/jet_cad_2d_kit && flutter test test/model/symbol_box_test.dart test/model/placement_transform_test.dart`. Expected: compilation fails, e.g. `Error: Method not found: 'boxOfLeaves'` and `Undefined name 'SymbolBox'` (the contract has none yet).

- [ ] **Step 4: The contract's file.** Create `packages/jet_cad_2d_kit/lib/src/model/symbol_box.dart`:
  - Header (replaces plan lines 1-9) and imports (replace plan lines 10-14):

```dart
// The symbol's local box (spec 09c D2): the axis-aligned bounds of a
// symbol's leaves in its definition's coordinates (the base point not
// subtracted). The catalog's frame (F-1) puts the front of a piece on its
// smallest y and its back on its largest, so `front = minY` and
// `back = maxY`. And the placement transform (spec 09 D6, 09c D5) and the
// orthonormal test (09c W-8, S-10) a placement and an attachment use.
//
// Moved into the contract from jet_cad_2d_plan's symbols/symbol_box.dart
// and symbol_placer.dart, unchanged (3a Task 1, spec C1.4): a kit's
// attachment provider needs the neighbours' boxes and the exact placement
// (the wall-face provider, spec 3a C5).
//
// Pure Dart: no Flutter, no dart:io.
import 'dart:math' as math;

import 'package:jet_cad_2d/jet_cad_2d.dart';
import 'package:vector_math/vector_math_64.dart' show Vector2;

import 'symbol_library.dart' show SymbolEntry;
```

  - Copy plan `symbol_box.dart` lines 16-151 unchanged (`SymbolBox` through the first paragraph of `boxOfDefinition`'s doc), then this doc tail in place of lines 152-153 (D-10: the comment named a class of the old planner):

```dart
/// Not memoised: O(entities) per call. A caller that asks often keeps its
/// own memo and drops it when the document changes (its
/// `commands.stateId`).
```

  - Copy plan lines 154-171 unchanged (`boxOfDefinition`'s body, `footprintOf`).
  - Append `isOrthonormal` (the body of `move_resolver.dart:18-23`, unchanged; the doc merged from both copies):

```dart

/// Whether [g]'s linear part is orthonormal (spec 09c W-8, S-10):
/// `|a² + b² − 1|`, `|c² + d² − 1|` and `|ac + bd|` each at most
/// `Tolerance.standard.linear`. A mirror is orthonormal; a scale is not.
bool isOrthonormal(Transform2 g) {
  final tol = Tolerance.standard.linear;
  return (g.a * g.a + g.b * g.b - 1).abs() <= tol &&
      (g.c * g.c + g.d * g.d - 1).abs() <= tol &&
      (g.a * g.c + g.b * g.d).abs() <= tol;
}
```

  - Append a blank line, then copy plan `symbol_placer.dart` lines 44-86 unchanged (`placementTransform`'s doc and body, `_quarterTurn`).

  `packages/jet_cad_2d_kit/lib/src/model/model.dart`: add `export 'symbol_box.dart';` after `export 'register.dart' show registerKitComponents;` (the list's order: before `symbol_library.dart`).

  `packages/jet_cad_2d_kit/test/support/placements.dart`: delete lines 17-39 (the `placementTransform` copy) and the `vector_math` import (line 7, now unused); the header's first sentence becomes `// The fixture placement the label tests use (2b Task 3): today's fixture placement (jet_cad_floor_plan/test/tables/table_fixture.dart: 72-78). The placer's form is the contract's placementTransform (3a Task 1).`

  Run `cd packages/jet_cad_2d_kit && dart format . && flutter test test/model/ test/kit/unit_label_test.dart test/invariants/purity_test.dart`. Expected: `All tests passed!`.

- [ ] **Step 5: The plan library follows.** Delete `packages/jet_cad_2d_plan/lib/src/symbols/symbol_box.dart` (`git rm packages/jet_cad_2d_plan/lib/src/symbols/symbol_box.dart`). Then:
  1. `lib/src/symbols/symbol_placer.dart`: delete lines 44-87 (`placementTransform`, its doc, `_quarterTurn` and the blank line after it); the kit import's `show` list gains `placementTransform` (alphabetical among the lower-case names: `..., UnitLabelling, placementTransform, unitLabelHeight, unitLabelPayload;`). The doc reference `[placementTransform]` at `:160` resolves to the import.
  2. `lib/src/tools/move_resolver.dart`: delete lines 16-23 (the public `isOrthonormal` and its doc) and line 13 (`import '../symbols/symbol_box.dart';`); the kit import becomes `show Attachment, AttachmentQuery, AttachmentRegistry, SymbolBox, SymbolComponent, boxOfDefinition, footprintOf, isOrthonormal;`.
  3. `lib/src/panels/symbol_section.dart`: delete lines 132-142 (`_isOrthonormal` and its doc) and the blank line after them; `:157`'s `_isOrthonormal(` → `isOrthonormal(`; delete `import '../symbols/symbol_box.dart';` (`:14`); the kit import becomes `show SymbolBox, SymbolComponent, SymbolEntry, UnitComponent, boxOfDefinition, boxOfEntry, isOrthonormal;`.
  4. `lib/src/tools/plan_symbol_tool.dart`: delete `import '../symbols/symbol_box.dart';` (`:32`); the kit import (`:26-27`) becomes `show Attachment, AttachmentQuery, AttachmentRegistry, boxOfEntry, footprintOf, placementTransform;` (`symbol_placer.dart` stays imported: `placeSymbol`).
  5. `lib/src/panels/plan_property_panel.dart`: delete `import '../symbols/symbol_box.dart';` (`:32`; the unshown kit import at `:22` gives `SymbolBox`, `boxOfDefinition`, `boxOfEntry`).
  6. `lib/src/controller/services.dart`: delete `import '../symbols/symbol_box.dart' show servedTopOfEntry;` (`:11`; the unshown kit import at `:8` gives it).
  7. `lib/src/units/unit_index.dart`: delete `import '../symbols/symbol_box.dart' show boxOfLeaves;`; the kit import becomes `show SymbolComponent, UnitComponent, UnitLabelling, boxOfLeaves, kUnitLabelTag;`.
  8. `lib/src/units/unit_label.dart`: delete `import '../symbols/symbol_box.dart' show boxOfLeaves;`; the kit import becomes `show boxOfLeaves, kUnitLabelTag, kUnitLabelTextAttrs, unitLabelHeight, unitLabelPayload;`.
  9. Tests and their support (imports only, no assertion changes):
     - `test/tools/plan_symbol_tool_test.dart`: delete `:46` (`symbol_box.dart`) and `:48` (`symbol_placer.dart`, whose only name it used, `placementTransform`, is now the kit barrel's at `:43`).
     - `test/symbols/symbol_ghost_test.dart`: delete `:39` (`symbol_placer.dart`, the same reason; kit barrel at `:37`).
     - `test/tools/move_resolver_test.dart`: delete `:12` (`symbol_box.dart`).
     - `test/panels/symbol_section_test.dart`: delete `:37` (`symbol_box.dart`).
     - `test/controller/mode_test.dart`: `:10-11` become `import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart' show placementTransform;`, moved above the `jet_cad_2d_plan` imports.
     - `test/service/service_record_test.dart`: delete `:12-13`; `test/support/service_plans.dart`: delete `:14-15` (both import the kit barrel unshown).
     - `test/support/unit_fixtures.dart`: `:30-31` become `import 'package:jet_cad_2d_plan/src/symbols/symbol_placer.dart' show definitionForEntry;`.
  10. `test/symbols/symbol_box_test.dart` keeps only `boxOfDefinition`'s placed case. Its new content: the header below; imports `package:flutter_test/flutter_test.dart`, `package:jet_cad_2d/jet_cad_2d.dart`, `package:jet_cad_2d_kit/jet_cad_2d_kit.dart`, `package:jet_cad_2d_plan/src/symbols/symbol_placer.dart`, `package:vector_math/vector_math_64.dart' show Vector2`, `'../support/symbol_fixtures.dart'`; then the old lines 21-22 (`entryIn`), 47-63 (`target`, `definitionOf`) unchanged; then `void main() { group('boxOfDefinition', () { <old lines 295-317 unchanged> }); }`.

```dart
// Spec 09c D2 (ported to the plan library, Task 14): a placed definition's
// box. Ported from jet_cad_floor_plan's symbol_box_test.dart, assertions
// unchanged. The box functions are the contract's since 3a Task 1 (spec
// C1.4), and so are their other tests (jet_cad_2d_kit's
// test/model/symbol_box_test.dart); this case stays because it places
// through the plan's placeSymbol. The furniture asset's literal boxes stay
// with that asset's kit (3a Task 28).
```

  11. `test/symbols/symbol_placer_test.dart`: delete lines 193-395 (the group `placementTransform` and the blank line after it); the helpers stay (the placer's groups use `at`, `far`, `rotations`, `expectedWorld`); the header gains `// The group 'placementTransform' moved into the contract (3a Task 1): jet_cad_2d_kit's test/model/placement_transform_test.dart.`

- [ ] **Step 6: The one-owner pin (D-09).** Create `packages/jet_cad_2d_plan/test/invariants/contract_names_test.dart`:

```dart
// 3a Task 1 (spec C1.4, Appendix A D-09): the symbol box family and the
// placement transform have one owner, the contract. The plan library
// declares none of them, under its own name or a private one, so a rule
// changed in the contract cannot drift from a copy here.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A top-level declaration of one of the contract's names, public or
/// private.
final RegExp _declaration = RegExp(
    r'^(?:final\s+)?(?:class\s+_?SymbolBox\b|'
    r'(?:bool|Transform2|Aabb2|SymbolBox\??)\s+_?'
    r'(?:isOrthonormal|placementTransform|boxOfLeaves|boxOfEntry|'
    r'servedTopOfEntry|boxOfDefinition|footprintOf)\s*\()',
    multiLine: true);

void main() {
  test(
      'SB-one-owner no file under lib/ declares the symbol box family or '
      'the placement transform (M-SB-owner)', () {
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .toList();
    expect(files.length, greaterThan(50), reason: 'premise: lib/ was read');
    final found = [
      for (final f in files)
        for (final m in _declaration.allMatches(f.readAsStringSync()))
          '${f.path}: ${m[0]}',
    ];
    expect(found, isEmpty);
  });

  test('SB-one-owner-probe the pattern finds each form it names', () {
    // The detector's own positive control (exempt from the mutation rule).
    for (final line in [
      'bool isOrthonormal(Transform2 g) {',
      'bool _isOrthonormal(Transform2 g) {',
      'Transform2 placementTransform({',
      'final class SymbolBox {',
      'SymbolBox? boxOfLeaves(Iterable<(EntityKind, GeometryPayload)> l) {',
      'Aabb2 footprintOf(SymbolBox box) =>',
    ]) {
      expect(_declaration.hasMatch(line), isTrue, reason: line);
    }
    expect(_declaration.hasMatch('  if (!isOrthonormal(t)) return null;'),
        isFalse);
  });
}
```

  Run `cd packages/jet_cad_2d_plan && dart format . && flutter analyze && flutter test test/invariants/contract_names_test.dart test/symbols/ test/tools/ test/panels/symbol_section_test.dart test/controller/mode_test.dart test/service/service_record_test.dart test/units/`. Expected: `No issues found!`, then `All tests passed!`. Count the `lib/` Dart files once (`find lib -name '*.dart' | wc -l`) and quote it: 101 at `c6bcce3e`, 100 after this task's delete, so the premise `greaterThan(50)` holds with room.

- [ ] **Step 7: The amendment line.** `docs/superpowers/specs/2026-10-13-kit-contract-design.md`: insert, after the section `## Amendments from the PR review (2026-10-13)` and before `## Inputs for sub-project 2`:

```markdown
## Amendments from sub-project 3a (2026-10-15)

Each line is written by the 3a task that lands it (the 3a spec,
[2026-10-15-architecture-kit-design.md](2026-10-15-architecture-kit-design.md),
"Amendments to other specs").

- **The symbol box family** (3a C1.4): `SymbolBox`, `isOrthonormal`,
  `boxOfLeaves`, `boxOfEntry`, `servedTopOfEntry`, `boxOfDefinition`,
  `footprintOf` and `placementTransform` are the contract's, pure Dart in
  the model (`lib/src/model/symbol_box.dart`), exported by both libraries;
  moved unchanged from the plan library, which imports them from here and
  keeps no copy.
```

- [ ] **Step 8: The gates.** From the repository root:
  - `cd packages/jet_cad_2d_kit && flutter test && flutter analyze && dart format --output=none --set-exit-if-changed .` — `All tests passed!`, `No issues found!`, exit 0.
  - `cd packages/jet_cad_2d_plan && flutter test --enable-vmservice && flutter analyze && dart format --output=none --set-exit-if-changed .` — the same.
  - `dart run tool/ci/check_kit_deps.dart` — exit 0.
  - `git status --short`: only this task's files (no `analysis_options.yaml`).

- [ ] **Step 9: Commit.**

```bash
git add packages/jet_cad_2d_kit/lib/src/model/symbol_box.dart packages/jet_cad_2d_kit/lib/src/model/model.dart packages/jet_cad_2d_kit/test/support/box_fixtures.dart packages/jet_cad_2d_kit/test/support/placements.dart packages/jet_cad_2d_kit/test/model/symbol_box_test.dart packages/jet_cad_2d_kit/test/model/placement_transform_test.dart packages/jet_cad_2d_plan/lib/src/symbols/symbol_box.dart packages/jet_cad_2d_plan/lib/src/symbols/symbol_placer.dart packages/jet_cad_2d_plan/lib/src/tools/move_resolver.dart packages/jet_cad_2d_plan/lib/src/tools/plan_symbol_tool.dart packages/jet_cad_2d_plan/lib/src/panels/symbol_section.dart packages/jet_cad_2d_plan/lib/src/panels/plan_property_panel.dart packages/jet_cad_2d_plan/lib/src/controller/services.dart packages/jet_cad_2d_plan/lib/src/units/unit_index.dart packages/jet_cad_2d_plan/lib/src/units/unit_label.dart packages/jet_cad_2d_plan/test/symbols/symbol_box_test.dart packages/jet_cad_2d_plan/test/symbols/symbol_placer_test.dart packages/jet_cad_2d_plan/test/symbols/symbol_ghost_test.dart packages/jet_cad_2d_plan/test/tools/plan_symbol_tool_test.dart packages/jet_cad_2d_plan/test/tools/move_resolver_test.dart packages/jet_cad_2d_plan/test/panels/symbol_section_test.dart packages/jet_cad_2d_plan/test/controller/mode_test.dart packages/jet_cad_2d_plan/test/service/service_record_test.dart packages/jet_cad_2d_plan/test/support/service_plans.dart packages/jet_cad_2d_plan/test/support/unit_fixtures.dart packages/jet_cad_2d_plan/test/invariants/contract_names_test.dart docs/superpowers/specs/2026-10-13-kit-contract-design.md
git commit -m "$(cat <<'EOF'
refactor(kit): the symbol box family moves into the contract (spec 3a C1.4)

SymbolBox, isOrthonormal, boxOfLeaves, boxOfEntry, servedTopOfEntry,
boxOfDefinition, footprintOf and placementTransform move unchanged from
the plan library into the contract's model, exported by both libraries,
so a kit's attachment provider can read the neighbours' boxes and the
exact placement. The plan library imports them and keeps no copy: the
two isOrthonormal copies are gone and a source scan pins it. Their pure
tests move with them, assertions unchanged; the contract spec records
the amendment.

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 10: Mutation check** (committed files only; after each: run the named test, see it red, then `git checkout -- <file>` and `git diff --quiet -- <file>` must exit 0). Kit tests run with `cd packages/jet_cad_2d_kit && flutter test <file>`; the plan's with `cd packages/jet_cad_2d_plan && flutter test <file>`.
  - M-SB-ortho `jet_cad_2d_kit/lib/src/model/symbol_box.dart`: delete ` &&\n      (g.a * g.c + g.b * g.d).abs() <= tol` from `isOrthonormal` → `test/model/symbol_box_test.dart` SB-ortho red.
  - M-SB-export `jet_cad_2d_kit/lib/src/model/model.dart`: delete `export 'symbol_box.dart';` → `test/model/symbol_box_test.dart` fails to compile (red).
  - M-SB-pure `jet_cad_2d_kit/lib/src/model/symbol_box.dart`: add `import 'package:flutter/foundation.dart';` after the `vector_math` import → `test/invariants/purity_test.dart` P1 red (`lib/src/model/symbol_box.dart: package:flutter/foundation.dart`).
  - M-SB-arc `jet_cad_2d_kit/lib/src/model/symbol_box.dart`: in `boxOfLeaves`, delete the `for (var k = 0; k < 4; k++) { ... }` axis-extreme loop → `test/model/symbol_box_test.dart` group `an arc by its true extents` red (the moved tests still bite in their new home).
  - M-SB-clean `jet_cad_2d_kit/lib/src/model/symbol_box.dart`: in `placementTransform`, `clean(m.a), clean(m.b), clean(m.c), clean(m.d), clean(m.e), clean(m.f)` → `m.a, m.b, m.c, m.d, m.e, m.f` → `test/model/placement_transform_test.dart` P3 and P23 red.
  - M-SB-owner `jet_cad_2d_plan/lib/src/panels/symbol_section.dart`: add at the end of the file `bool _isOrthonormal(Transform2 g) => isOrthonormal(g);` → `test/invariants/contract_names_test.dart` SB-one-owner red (and `flutter analyze` warns `unused_element`, which the revert removes).

  Quote each red line.

---

