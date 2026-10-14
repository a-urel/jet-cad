# Task 6 report: the jet_cad_2d_plan package, kit-set validation, test kits, CI

Status: DONE. Commit `aeb5e610` (BASE `06ee312e`). One commit; nothing pushed, no real publish.

## Implemented

- `packages/jet_cad_2d_plan`: pubspec (0.8.0, workspace, sdk ^3.6.0, flutter >=3.44.0; deps flutter, jet_cad_2d ^0.7.2, jet_cad_2d_flutter ^0.7.2, jet_cad_2d_kit ^0.1.0, meta ^1.18.0, vector_math ^2.2.0; dev flutter_test, lints ^6.1.0), `analysis_options.yaml` (byte copy of jet_cad_2d_kit's, identical to the brief's text; committed once, here), `LICENSE` (`cmp LICENSE packages/jet_cad_2d_plan/LICENSE`: no output), README and CHANGELOG stubs as the brief, barrel exporting `src/kits/kit_set.dart`.
- Root `pubspec.yaml`: `- packages/jet_cad_2d_plan` right after `- packages/jet_cad_2d_kit`.
- `lib/src/kits/kit_set.dart`: `reservedKitIds`, `KitSet` (`kits`, `types`, `tools`, `kitOf`, `typeOf`), `KitSetError extends ArgumentError` (`problems`, name `kits`, one `  <code>: <message>` line per problem), `validateKitSet` — exactly the brief's code (only `dart format` rewrapping).
- `test/support/test_kit.dart`, `throwing_kit.dart`, `harness.dart`: the brief's code; deviations below (imports only).
- Tests: `test/kits/kit_set_test.dart` (KS1-KS9), `test/kits/test_kits_test.dart` (TK1-TK4 as the brief, plus TK5, see deviations).
- `.github/workflows/ci.yml`: the `package` matrix entry (`packages/jet_cad_2d_plan`, `tool: flutter`) after jet_cad_2d_kit's, and `packages/jet_cad_2d_plan` in the `publishable` matrix after jet_cad_2d_kit. `python3 -c "import yaml,sys; yaml.safe_load(open('.github/workflows/ci.yml'))"`: no output. `git diff` showed exactly the three added lines.

## TDD evidence

RED (before `kit_set.dart` existed), `flutter test test/kits`:
```
lib/jet_cad_2d_plan.dart:5:1: Error: Error when reading 'lib/src/kits/kit_set.dart': No such file or directory
test/kits/kit_set_test.dart:21:1: Error: Type 'KitSetError' not found.
test/kits/kit_set_test.dart:14:5: Error: Method not found: 'validateKitSet'.
...
00:00 +0 -1: loading .../test/kits/kit_set_test.dart [E]
... TK1 .. TK4 passed
00:00 +4 -1: Some tests failed.
```
(test_kits_test.dart compiled and passed: it depends on Tasks 3-4 alone, as the brief predicts.)

GREEN after `kit_set.dart`: `00:00 +13: All tests passed!` (KS1-KS9, TK1-TK4). After TK5 was added: `00:00 +14: All tests passed!`.

SC16 RED before the CI edit (`cd tool/ci && dart test`):
```
00:39 +115 -1: Some tests failed.
  test/scripts_test.dart: SC16 every live package is in the CI matrix
```
GREEN after: `00:39 +116: All tests passed!`.

## Mutations (on committed `kit_set.dart`; each run with `flutter test test/kits/kit_set_test.dart --plain-name '<id> '`; each reverted with `git checkout -- lib/src/kits/kit_set.dart`, then `git diff --quiet -- lib/src/kits/kit_set.dart` printed `revert exit 0`)

| Mutation | Red line |
|---|---|
| M-KS1 `return KitSet._([...kits]..sort(...))` | KS1: `Expected: ['test', 'disc']  Actual: ['disc', 'test']` |
| M-KS2 duplicate-kit block replaced by `kitIds.add(kit.id);` | KS2: `the set was accepted` (errorOf's fail); KS9: `Which: at location [1] is KitProblemCode.typePlaceConflict instead of KitProblemCode.duplicateKit` |
| M-KS3 `reservedKitIds = {'plan'}` | KS3: `Actual: [KitProblemCode.reservedKitId] ... shorter than expected` |
| M-KS4 cross-kit duplicateType block deleted | KS4: `Expected: an object with length of <1>  Actual: WhereIterable<KitProblemCode>:[]` |
| M-KS5 cross-kit duplicateTool block deleted | KS5: `Expected: an object with length of <1>  Actual: WhereIterable<KitProblemCode>:[]` |
| M-KS6 `seen = typeKits.containsKey(type.id)` / `if (seen)` | KS6: `Expected: an object with length of <1> ... Which: has length of <2>` |
| M-KS7 place-conflict block deleted | KS7: `the set was accepted`; KS9: `Which: at location [3] is [` (list too short) |
| M-KS8 the `kit.validate()` loop deleted | KS8: `the set was accepted` |
| M-KS9 throw moved to the end of the per-kit body | KS9: `Actual: [KitProblemCode.reservedKitId] ... shorter than expected` |

After the last revert: `flutter test` → `00:00 +14: All tests passed!`; `git status --short` empty.

## Gates (quoted)

- `cd packages/jet_cad_2d_plan && dart format .` → `Formatted 7 files (0 changed)`; `flutter test` → `00:00 +14: All tests passed!`; `flutter analyze` → `No issues found! (ran in 2.8s)`; `dart format --output=none --set-exit-if-changed .` → `Formatted 7 files (0 changed)`, exit 0.
- `cd tool/ci && dart test` → `00:39 +116: All tests passed!`.
- `dart run tool/ci/check_kit_deps.dart` → `kit dependencies: 1 package(s) checked, none names the plan library or another kit`, exit 0.
- `cd packages/jet_cad_2d_kit && flutter test` → `00:04 +312: All tests passed!`.
- `cd packages/jet_cad_2d_plan && dart pub publish --dry-run` (after the commit) → `Package has 0 warnings.`
- `git status --short` after every `flutter pub get` (and after analyze/test/dry-run): only this task's files; no existing `analysis_options.yaml` was rewritten, and none was staged other than the new package's.

## Files

- /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-library-2a/pubspec.yaml (modified)
- /Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/plan-library-2a/.github/workflows/ci.yml (modified)
- packages/jet_cad_2d_plan/{pubspec.yaml, analysis_options.yaml, LICENSE, README.md, CHANGELOG.md}
- packages/jet_cad_2d_plan/lib/jet_cad_2d_plan.dart, lib/src/kits/kit_set.dart
- packages/jet_cad_2d_plan/test/support/{test_kit.dart, throwing_kit.dart, harness.dart}
- packages/jet_cad_2d_plan/test/kits/{kit_set_test.dart, test_kits_test.dart}

## Deviations from the brief

The brief's code compiled against the real contract almost unchanged; every Task 3-4 constructor spelling it assumed (LengthProperty..ActionProperty, Attachment, AttachmentQuery, PlanType, PlanTool, PlanToolSettings, ColourTarget, KitNames, Disposable) matched. A token-level diff of each committed file against the brief's block shows only these changes plus `dart format` rewrapping:

1. `test_kit.dart`, `throwing_kit.dart`: `import 'package:flutter/material.dart' hide Tolerance;`. Reason: `Tolerance` is ambiguous between Flutter's physics `Tolerance` and jet_cad_2d's (`ambiguous_import` error; the `const tol = Tolerance.standard` then also failed). The kits mean jet_cad_2d's. Same idiom as `jet_cad_floor_plan/lib/src/service/table_group_painter.dart`.
2. `throwing_kit.dart`: dropped `import 'package:flutter/foundation.dart' show listEquals;`. Reason: ambiguous with jet_cad_2d's exported `listEquals<T>(List<T>, List<T>)`, which has the same element-wise `==` semantics; `BoomComponent ==` now uses jet_cad_2d's.
3. `test_kits_test.dart`: dropped the unused `import 'package:jet_cad_2d_kit/jet_cad_2d_kit.dart';` (`unused_import` is an error in the package's analysis options).
4. `test_kits_test.dart`: added **TK5** (fixture sanity, exempt from the mutation rule), with imports of `jet_cad_2d` and `../support/harness.dart` and one more header-comment line. Reason: none of the brief's tests ran the harness, and every later task builds on it. TK5 runs `planDocument` (page origin (-7425, -5250), separator passed through, millimetres, no undo history), `installSystem` over testKit + discKit + the throwing kit, `addObject` for a turned slab off the origin, a disc and a block (each generates one leaf; the slab's leaf coords equal `slabCorners` in group space), and `addLine` (stored coords).

No Shared interface or other task's contract was changed.

## Final public test-kit API (unchanged from the brief's "Test kit API")

- `test_kit.dart`: `slabTypeId`, `slabToolId`, `discTypeId`, `readerTypeId`, `testEdgeKind`; `KitLog` (`events`, `created`, `disposed`); `SlabComponent` (`width`, `height`, `angle`, `thickness`, `finish`, `labelled`, `label`, `flipped`, `swatch`, `copyWith`, `withSwatch`, `fromJson`, `componentTypeId`); `slabCorners`; `SlabType`; `SlabCache`; `SlabGrips`; `SlabSettings`; `SlabTool`; `slabProperties()`; `slabSettingSpecs()`; `slabSection`; `slabTitle`; `slabType({log})`; `slabTool({log})`; `TestEdge({kind, y, log})`; `testWords`; `testKit({version, log})`; `DiscComponent` (`radius`, `swatch`, `copyWith`, `withSwatch`, `fromJson`); `discOutline`; `DiscType`; `discWords`; `discKit({version})`; `ReaderComponent` (`size`); `ReaderType`; `conflictKit()`; `placeObjectCommand<T>(d, component, {at, handle})`; `addObject<T>(d, component, {at})`.
- `throwing_kit.dart`: `boomHooks`; `BoomFailure` (`hook`); `ThrowingKit({failing})` (`failing`, `failAll`, `check`, `kit`); `BoomComponent` (sealed; `size`, `swatch`, `refs`, `copyWith`, `withSwatch`, `read`); `BlockComponent`, `PostComponent`, `ZoneComponent`; `boomSquare`; `BoomType<T>`; `BoomGrips`; `BoomTool`; `BoomEdge`; `BoomSection`.
- `harness.dart`: `catalogOf`, `registerPlanComponents`, `planDocument({measurer, separator})`, `installSystem`, `addLine`, `leavesOf`, `coordsOf`, `pointerAt({buttons, screen, pickRadiusWorld})`, `pumpApp({size})`.
- Package: `KitSet`, `KitSetError`, `validateKitSet`, `reservedKitIds`.

## Self-review

- `validateKitSet` order and dedup rules are as the brief's plan decisions: a type repeated under a duplicate kit id compares `first != kit.id` with the same id, so only `duplicateKit` is reported (KS2 pins exactly one code); in-kit duplicates are `validate()`'s alone (KS6).
- The place-conflict check reads the descriptor's untyped flags, so a `PlanType<Component>` read does not trip covariance.
- KS7's premise test confirms the engine itself refuses `ReaderType`.
- Fixtures: slab at (2500, -1300) turned 0.4 rad, disc at (-900, 700), non-default separator in TK5.

## Concerns

- `SlabTool`, `BoomTool`, `SlabGrips.drag/preview`, `TestEdge` hysteresis and `pointerAt`/`pumpApp` compile and pass `flutter analyze` but are not exercised at runtime by this task's tests (no ToolContext/PlanServices exists before Task 8); the first task that drives them is their real check. A throwaway probe (deleted, not committed) did run `SlabGrips.gripsOf` and `TestEdge.attach` (unturned, `mayRotate: false`) without error.
- The default `PageComponent` in `planDocument` reports its own (paper) units as meters in `toString`; the document header is millimetres as the brief says. Noted only.
