# Task 17 report: the separator's grips, tool and plan type

Status: DONE_WITH_CONCERNS (minor: three brief defects fixed as deviations, listed below)
Commit: `660d3ffe feat(kit-architecture): the separator's grips, tool and plan type` (on `df16d97a`)

## Implementation summary

Kit (`packages/jet_cad_2d_kit_architecture`):
- `lib/src/separator/separator_grips.dart`: ported from
  `jet_cad_floor_plan/lib/src/parametric/separator_grips.dart:1-113`. The only changes are the header
  comment, the `../room/room_inputs.dart` import and the two doc edits the brief names. `diff`
  against the source shows exactly those lines.
- `lib/src/separator/separator_tool.dart`: ported from `.../separator_tool.dart:1-138` in the same
  way (header, import, doc `:20-21` and `:36`).
- `lib/src/separator/separator_plan.dart` (new): `separatorPlanType` (`exported: false`, grips
  `SeparatorGrips(inputs: roomInputsOf(s), objectSnap: () => s.objectSnap)`, no properties) and
  `separatorPlanTool` (S, `Icons.horizontal_rule`, structure/components/geometry,
  `SeparatorTool(roomInputsOf(s))`). The file is verbatim from the brief.
- `lib/src/kit.dart`: `separatorPlanType` comes after `openingPlanType` and `separatorPlanTool`
  after `gapPlanTool`.
- `CHANGELOG.md`: the separator line is appended (wrapped to the file's width).

FREEZE RULE: no memo or cache is added. The tool's rubber band is recomputed for each hover through
`trimSeparator`. The grips call `trimSeparator` on each drag and preview. Every read goes through
Task 16's `RoomInputs` entry points, which already re-check liveness. So there is no new first-reader
freeze test and no new mutation.

Integration (`packages/jet_cad_2d_integration`):
- `test/separator/separator_plans.dart`, `separator_shell_test.dart`, `separator_dashed_test.dart`
  and `separator_export_test.dart` are verbatim from the brief, then run through `dart format`.
- `test/wall/wall_grips_test.dart` gains `shadow`, `sep`, `shadowController`, `shadowTip`, EG7 and
  EG8. The header comment is updated.

Kit wall test: `test/wall/wall_grips_test.dart` gains the imports, `shadow`, `sep`, `shadowDoc`,
`shadowTip` and EG8-k. The header comment is updated.

## TDD evidence

RED, before any lib file existed
(`cd packages/jet_cad_2d_kit_architecture && flutter test test/separator/separator_tool_test.dart test/separator/separator_plan_test.dart`):
```
test/separator/separator_tool_test.dart:31:8: Error: Error when reading 'lib/src/separator/separator_plan.dart': No such file or directory
test/separator/separator_tool_test.dart:32:8: Error: Error when reading 'lib/src/separator/separator_tool.dart': No such file or directory
test/separator/separator_tool_test.dart:37:17: Error: Type 'SeparatorTool' not found.
test/separator/separator_tool_test.dart:51:16: Error: Undefined name 'separatorPlanTool'.
```
and for `separator_plan_test.dart`:
```
test/separator/separator_plan_test.dart:15:8: Error: Error when reading 'lib/src/separator/separator_plan.dart': No such file or directory
test/separator/separator_plan_test.dart:16:8: Error: Error when reading 'lib/src/separator/separator_tool.dart': No such file or directory
test/separator/separator_plan_test.dart:38:44: Error: Undefined name 'separatorPlanType'.
```
GREEN, after Step 4: `flutter test` → `00:12 +199: All tests passed!` (the baseline was 190: ST1-3,
ST5, ST6, SP-type, SP-order, SP-grips and ND2 add 9). Then
`flutter test test/separator` → `00:00 +13: All tests passed!`.

Integration Step 7: `flutter test --enable-vmservice test/separator` → `00:01 +7: All tests passed!`
(ND1, ND3, ND4, SP-dashed-open, SP-export-png, SP-export-pdf, ST1 (editor)). The red runs of these
tests are the mutations below.

Step 7b: in the kit, `test/wall/wall_grips_test.dart` → `00:00 +5: All tests passed!` (EG8-k is
added). In the integration package, `flutter test --enable-vmservice test/wall/wall_grips_test.dart`
→ `00:02 +9: All tests passed!` (EG7 and EG8 are added). The shadow's and `sep`'s stray components
reach the controller's document after its load, as EG6's do. There was no exception, no frozen
object and no second undo step.

## Gates (after the commit)

- Kit: `flutter test` → `00:12 +200: All tests passed!`; `flutter analyze` → `No issues found!`;
  `dart format --output=none --set-exit-if-changed .` → `Formatted 74 files (0 changed)`, exit 0;
  `dart pub publish --dry-run` → `Package has 0 warnings.` (before the commit it said 1 warning,
  "3 checked-in files are modified in git"; the commit cleared it).
- Integration: `flutter test --enable-vmservice` → `00:07 +54: All tests passed!` (the baseline was
  45); `flutter analyze` → `No issues found!`; format → `Formatted 22 files (0 changed)`, exit 0.
- Repository root: `dart run tool/ci/check_kit_deps.dart` →
  `kit dependencies: 2 package(s) checked, none names the plan library or another kit`.
- `git status --short` after the commit: clean. No `analysis_options.yaml` was touched.
- Step 8 (non-ASCII): `×` and `°` in `separator_plans.dart` comments; `m²`, `−`, `·`, `≈` and `°` in
  the ported test's comments. They are literal characters, as in the source (`grep -n "[^ -~]"` was
  run on both).

## Mutation results (each was applied to committed code, run red and reverted with `git checkout --`; `git diff --quiet` exit 0 after each)

| Id | Mutation | Red |
|---|---|---|
| M-SP-1 | delete `exported: false,` | SP-type `Expected: false / Actual: <true>`; SP-export-png `[E]`; SP-export-pdf `[E]` (`Actual: <true>`) |
| M-SP-2 | grips `objectSnap: () => true` | SP-grips `Expected: a value less than <0.000001> Actual: <133.03564861776334>`, `F3 off: as placed` |
| M-SP-3 | `letter: 'X'` | SP-type `Expected: 'S' Actual: 'X'`; ST1 (editor) `Expected: Separator Actual: Select` |
| M-SP-4 | `separatorPlanTool` first in `tools:` | SP-order `Which: at location [0] is 'architecture.separator' instead of 'architecture.box'` |
| M-SP-5 | delete the first `inputs.invalidate();` in `accept` | ST2 `Actual: <130.5>`, `trimmed to the new wall's face, origin` |
| M-SP-6 | `accept`'s `objectSnap: true` | ST2 `Expected: SeparatorParams((3000.5, 0.25) -> (3000.5, 3999.75)) Actual: SeparatorParams((3000.5, 100.0) -> (3000.5, 3900.0))`, `across, origin, F3 off: as placed` |
| M-SP-7 | `kept = start ? ends.$1 : ends.$2` | SP-grips `Actual: <49.26216061705426>`, `F3 on: on the segment from the start to the drop` |
| M-SP-9 | delete `prepare: ensureDashedLinetype,` | ND2 `[E] Null check operator used on a null value`; ND1, ND3 `Expected: <Instance of 'LinetypeRecord'> Actual: <null>`; SP-dashed-open also red (`premise: a new plan has it`) |
| M-SP-8 | plan `load`: `for (final kit in kits.kits) { kit.prepare?.call(next); }` after the decode `try` | SP-dashed-open `Expected: null Actual: <Instance of 'LinetypeRecord'>`, `a load adds nothing` |
| M-SP-8b (extra) | constructor `made: json == null` → `made: true` (the json-open path prepares) | SP-dashed-open `Expected: null Actual: <Instance of 'LinetypeRecord'>`, `no record there: it draws continuous` |
| M-SP-10 | `omittedOf`: `return const {};` | SP-export-png `Which: at location [85] is <32> instead of <30>`; SP-export-pdf `Expected: false Actual: <true>`, `no path at the separator` |

The brief names no mutation for EG7, EG8 or EG8-k. They are carried ports with their assertions
unchanged, and their live rule is Task 12's or Task 7's code. I ran no mutation for them.

## Ported-test accounting

| Old case | New case | Change class |
|---|---|---|
| `separator_tool_test.dart` ST1 (tool half, `:143-194`) | kit `separator_tool_test.dart` ST1, `test(` | fixture (the rig is made over `separatorPlanTool.create(FakePlanServices)`, `roomInputsOf`); widget form (`testWidgets` → `test`, its shell half left) |
| ST1 (shell half, `:196-223`) | integration `separator_shell_test.dart` ST1 (editor) | ids (`tool-separator` → `tool-architecture.separator`); widget form (PlannerShell → PlanEditor; `isPending` read as `isMidShape`, R17-1); fixture (boxWalls at `boxPlace`, built through `build:`) |
| ST2, ST3, ST5, ST6 | kit `separator_tool_test.dart`, unchanged bodies | fixture (rig; `separators` over `testCatalog().objectsOf`) |
| ST4 | not ported (Task 18, the room type) | n/a |
| `new_document_test.dart` ND1, ND3 DASHED lines | integration `separator_dashed_test.dart` ND1, ND3 | fixture (`architectureController`; the codec text is `save()`) |
| ND2 DASHED line | kit `separator_plan_test.dart` ND2 | fixture (the kit's `prepare` alone) |
| ND4 "live page and live walls" | integration ND4 | fixture (R17-2: `buildTenWalls` stands in for the sample) |
| `wall_grips_test.dart` EG7 | integration EG7 | fixture/widget form (A12-shell mapping; `shadowController` over `gripPlan`) |
| EG8 (shell part) | integration EG8 | the same; the provider-direct lines become `// The provider directly: EG8-k (the kit).` |
| EG8 (provider-direct, `:626-639`) | kit EG8-k | fixture (`WallGrips(live: liveOf(doc))`, the kit's `gripDoc` and `gridOf`); `// ignore: avoid_dynamic_calls` above `:629` |

The new cases are SP-type, SP-order, SP-grips, SP-dashed-open, SP-export-png and SP-export-pdf.

`diff` of the ported tool test against the source shows only the import, rig, `separators`, ST1
signature and removed-shell/ST4 hunks. Every assertion line is unchanged.

## Deviations (brief defects, each with one obvious fix)

1. **`separator_plan_test.dart` import.** The brief imports
   `package:jet_cad_2d_flutter/jet_cad_2d_flutter.dart' show Grip, GripRole`, but `Grip` and
   `GripRole` are the engine's (`jet_cad_2d/lib/src/document/grips.dart:13,20`), which the file
   already imports. `flutter analyze` gave `undefined_shown_name` (x2) and `unused_import` (an
   error). I removed the import line. Nothing else changed.
2. **`separator_tool_test.dart` import.** The brief's `import 'package:flutter/widgets.dart' show
   Offset;` drew `unnecessary_import`, because `flutter_test` provides `Offset`. I removed it.
3. **EG8-k's copy of `:616-623`.** The copy declares `wallP`, `openingP`, `sepS` and `sepO`, which
   only the shell part's after-drag checks use. In the kit they are `unused_local_variable`, which
   `flutter analyze` reports as an error. I dropped those four reads and added a comment saying
   why. No assertion was removed: the premise `expect` and `corner`/`q` stay, and the integration
   EG8 keeps all four checks.
4. Header comments. The ported grips and tool headers are wrapped to 80 columns, with the brief's
   wording kept. The `wall_grips_test.dart` headers in both packages now say that EG7, EG8 and
   EG8-k are here; the integration header used to say they "move to Task 17".

## Concerns

- In SP-dashed-open, M-SP-8 (in `load`) goes red only at the load half. The constructor's json path
  is a separate route, so I also ran M-SP-8b on it; it goes red at the open half.
- The CHANGELOG has no opening entry from Tasks 13-15. This is out of scope; the separator line
  follows the wall's.

## Files changed

- `/Users/ahmeturel/Projects/oss/jet-cad/.claude/worktrees/architecture-kit/packages/jet_cad_2d_kit_architecture/lib/src/separator/separator_grips.dart` (new)
- `.../packages/jet_cad_2d_kit_architecture/lib/src/separator/separator_tool.dart` (new)
- `.../packages/jet_cad_2d_kit_architecture/lib/src/separator/separator_plan.dart` (new)
- `.../packages/jet_cad_2d_kit_architecture/lib/src/kit.dart`
- `.../packages/jet_cad_2d_kit_architecture/CHANGELOG.md`
- `.../packages/jet_cad_2d_kit_architecture/test/separator/separator_tool_test.dart` (new)
- `.../packages/jet_cad_2d_kit_architecture/test/separator/separator_plan_test.dart` (new)
- `.../packages/jet_cad_2d_kit_architecture/test/wall/wall_grips_test.dart`
- `.../packages/jet_cad_2d_integration/test/separator/separator_plans.dart` (new)
- `.../packages/jet_cad_2d_integration/test/separator/separator_shell_test.dart` (new)
- `.../packages/jet_cad_2d_integration/test/separator/separator_dashed_test.dart` (new)
- `.../packages/jet_cad_2d_integration/test/separator/separator_export_test.dart` (new)
- `.../packages/jet_cad_2d_integration/test/wall/wall_grips_test.dart`
