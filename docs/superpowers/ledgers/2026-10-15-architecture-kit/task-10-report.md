# Task 10 report: The box (spec 3a C3.1; C7)

**Status:** DONE_WITH_CONCERNS (one named mutation, M-BX-4, stays green on its integration half; see Concerns)
**Commit:** `711889c1 feat(kit-architecture): the box` (on `8102f8a4`)

## Implementation summary

- **`lib/src/box/box.dart`:** copied from `jet_cad_floor_plan/lib/src/parametric/box.dart:1-124`. It gains a header comment and `import '../ids.dart';`, and `componentTypeId` becomes `ArchitectureTypes.box`. The diff against the source shows only those changes.
- **`lib/src/box/box_tool.dart`:** copied unchanged from `box_tool.dart:1-47`, plus a header comment.
- **`lib/src/box/box_plan.dart`** (new), verbatim from the brief:
  - `boxPlanType`: width and height are `LengthProperty`s, gated by `PlanGate.reshape`. The strict `> 0` bound is checked in `write` (`_positive` throws `ArgumentError`).
  - `boxPlanTool`: id `ArchitectureTools.box`, icon `Icons.crop_din`, letter `B`, needs structure, components and geometry, and creates a `BoxTool`.
- **`lib/src/kit.dart`:** `types: [boxPlanType]` and `tools: [boxPlanTool]`.
- **Barrel:** `export 'src/box/box.dart' show BoxParams;`.
- **`CHANGELOG.md`:** the brief's bullet.
- **`test/support/catalog.dart`** (new, R-P13): `testCatalog()` and `installParametric`, with the box registered.
- **`test/box/box_test.dart`:** BT1-BT6 ported.
- **`test/box/box_plan_test.dart`:** BX-props and BX-kit, verbatim from the brief (`dart format` re-wrapped one line).
- **`jet_cad_2d_integration/test/box/planner_box_test.dart`:** BX1-BX6 ported onto the editor rig (R-P14: it uses `pumpEditor`, `globalOf`, `status`, `press`, `pagePlanJson` and `kitCatalog` from `editor_rig.dart`). The domain-only fixtures stay local to the file: `pumpBoxes`, `boxKids`, `boxes`.

The rig's camera, click (`globalOf` + `tapAt`) and key (`press`) paths were exercised here for the first time, and all worked unchanged. No rig edit was needed.

## TDD evidence

**RED.** Step 3, `cd packages/jet_cad_2d_kit_architecture && flutter test test/box`, before any lib file existed:
```
test/box/box_plan_test.dart:14:8: Error: Error when reading 'lib/src/box/box_plan.dart': No such file or directory
import 'package:jet_cad_2d_kit_architecture/src/box/box_plan.dart';
test/box/box_plan_test.dart:15:8: Error: Error when reading 'lib/src/box/box_tool.dart': No such file or directory
import 'package:jet_cad_2d_kit_architecture/src/box/box_tool.dart';
test/support/catalog.dart:9:8: Error: Error when reading 'lib/src/box/box.dart': No such file or directory
import 'package:jet_cad_2d_kit_architecture/src/box/box.dart';
```
Both files failed to load. This is the CFE's wording; the brief predicted the analyzer's "Target of URI doesn't exist", but it is the same cause.

**GREEN.** Step 5, `dart format . && flutter test` in the kit:
```
Formatted test/box/box_plan_test.dart
Formatted 20 files (1 changed) in 0.03 seconds.
00:00 +14: All tests passed!
```
That is 6 from Task 9, BT1-BT6, BX-props and BX-kit.

**Integration.** Step 7, `cd packages/jet_cad_2d_integration && flutter test --enable-vmservice test/box`:
```
00:00 +0: BX1 B and the palette entry activate the Box tool
00:01 +1: BX2 two clicks: one box, four lines, one undo step
00:01 +2: BX3 Fill does not apply to a box
00:01 +3: BX4 two overlapping boxes read as one outline
00:01 +4: BX5 click a box, Delete: gone with its component; cmd+Z brings both back (Review Focus 2)
00:01 +5: BX6 typing B in the page panel field does not switch tools
00:01 +6: All tests passed!
```
- BX4 counts four children per box, so the grid premise held.
- No async `settleHistory` change was needed.

## Gates (run before the commit; dry-run re-run after it)

**Kit** (`packages/jet_cad_2d_kit_architecture`):
- `flutter test`: `00:00 +14: All tests passed!`
- `flutter analyze`: `No issues found! (ran in 3.0s)`
- `dart format --output=none --set-exit-if-changed .`: `Formatted 20 files (0 changed)`, exit 0.
- `dart pub publish --dry-run`, after the commit: `Package has 0 warnings.` Before the commit its only warning was the uncommitted files.

**Integration** (`packages/jet_cad_2d_integration`):
- `flutter test --enable-vmservice`: `00:01 +8: All tests passed!`
- `flutter analyze`: `No issues found! (ran in 2.8s)`
- format: `Formatted 5 files (0 changed)`, exit 0.

**Repository root:**
- `dart run tool/ci/check_kit_deps.dart`: `kit dependencies: 2 package(s) checked, none names the plan library or another kit`, exit 0.
- `git status --short` after the commit is empty. No `analysis_options.yaml` was touched by pub.

## Mutations

All were run on committed code, each reverted with `git checkout -- <file>`, and `git diff --quiet -- <file>` exited 0 after every one.

| Id | Change | Test | Result (quoted) |
|---|---|---|---|
| M-BX-1 | `v > 0 ? v :` → `v >= 0 ? v :` | BX-props | RED: `Expected: throws <Instance of 'ArgumentError'>` / `Actual: <Closure: () => DraftCommand>` / `Which: returned <Instance of 'SetComponentCommand<BoxParams>'>` |
| M-BX-2 | width's `gate: PlanGate.reshape` deleted | BX-props | RED: `Expected: PlanGate:<PlanGate.reshape>` / `Actual: <null>` |
| M-BX-3 | `letter: 'B'` → `'X'` | BX-kit | RED: `Expected: 'B'` / `Actual: 'X'` |
| | | BX1 | RED: `Expected: 'Box'` / `Actual: 'Select'` (also BX2 and BX4 red: no box drawn, `Expected: an object with length of <2>` / `Actual: []`) |
| M-BX-4 | as written (`if (inside == null) continue;` → `continue;`) | — | **Does not compile.** `lib/src/box/box.dart:84:38: Error: Property '$1' cannot be accessed on '(double, double)?' because it is potentially null.` The dead code below the `continue` loses `inside`'s promotion. |
| M-BX-4 equiv. | `if (inside == null) continue;` → `if (inside == null \|\| q.isNotEmpty) continue;` (a quad always has 4 corners, so every quad is skipped: no box clips another) | BT3 | RED: `BT3 a rotated overlapping pair clips each other: A 5, B 3 … [E]` / `Expected: an object with length of <5>` / `Actual: [1001, 1002, 1003, 1004]` |
| | | BX4 | **GREEN**: `00:01 +6: All tests passed!` (see Concerns) |
| M-BX-5 | `types: [boxPlanType],` → `types: [],` | BX-kit | RED: `Expected: contains PlanType<BoxParams>:<PlanType(architecture.box)>` / `Actual: []` |
| | | BX2 | RED: `Bad state: No element` at `planner_box_test.dart:94` (`boxes(doc).single`: no box committed). BX4 and BX5 also red. |
| M-BX-6 | `componentTypeId = ArchitectureTypes.box` → `'architecture.boxes'` | BT1 | RED: `Expected: 'architecture.box'` / `Actual: 'architecture.boxes'` |

**Extra probe (not a named mutation).** The integration fixture's `snapToGrid: true` was flipped to `false` on the committed file, then reverted, and `git diff --quiet` exited 0. Result: `00:02 +6: All tests passed!`. See Concerns.

## Ported-test accounting

**`jet_cad_floor_plan/test/box_test.dart` → `jet_cad_2d_kit_architecture/test/box/box_test.dart` (kit):**

| Old | New | Change class |
|---|---|---|
| BT1 | BT1 | ids (`'floor_planner.box'` → `'architecture.box'`) |
| BT2 | BT2 | none (imports only) |
| BT3 | BT3 | none: `parametricCatalog` → `testCatalog()`, the same catalog role under R-P13 |
| BT4 | BT4 | none |
| BT5 | BT5 | none |
| BT6 | BT6 | none |

`diff` against `box_test.dart:1-91` shows only the header, the imports, and the `:39` and `:62` lines.

**`jet_cad_floor_plan/test/planner_box_test.dart` → `jet_cad_2d_integration/test/box/planner_box_test.dart`:**

| Old | New | Change class |
|---|---|---|
| BX1 | BX1 | widget form (PlannerShell → PlanEditor via `pumpBoxes`); ids (`'tool-box'` → `'tool-${ArchitectureTools.box}'`) |
| BX2 | BX2 | widget form (`view` → `c`) |
| BX3 | BX3 | widget form |
| BX4 | BX4 | widget form; `parametricCatalog` → `kitCatalog()` |
| BX5 | BX5 | widget form |
| BX6 | BX6 | widget form (`chrome-right` exists on PlanEditor, `plan_editor.dart:968`) |

- The fixture change named by the brief, grid snap on, applies to all six.
- `diff` against source lines 12-151 shows only the `pumpDraw` → `pumpBoxes` and `view` → `c` lines, the tool key, and the catalog. No assertion line differs.
- `_worldOf`, `_childMidpoint` and `_strictlyInside` were copied verbatim.
- The brief's `grep -n "view"` check returns one hit, `:152`, the word "Review" in BX5's test name. No `view` identifier remains.

**New tests:** BX-props and BX-kit (`box_plan_test.dart`).

## Files changed

- `packages/jet_cad_2d_kit_architecture/lib/src/box/box.dart` (new)
- `packages/jet_cad_2d_kit_architecture/lib/src/box/box_tool.dart` (new)
- `packages/jet_cad_2d_kit_architecture/lib/src/box/box_plan.dart` (new)
- `packages/jet_cad_2d_kit_architecture/lib/src/kit.dart`
- `packages/jet_cad_2d_kit_architecture/lib/jet_cad_2d_kit_architecture.dart`
- `packages/jet_cad_2d_kit_architecture/CHANGELOG.md`
- `packages/jet_cad_2d_kit_architecture/test/support/catalog.dart` (new)
- `packages/jet_cad_2d_kit_architecture/test/box/box_test.dart` (new)
- `packages/jet_cad_2d_kit_architecture/test/box/box_plan_test.dart` (new)
- `packages/jet_cad_2d_integration/test/box/planner_box_test.dart` (new)

## Deviations

1. **M-BX-4 does not compile as written.** I ran its intended equivalent, `|| q.isNotEmpty`, which has the same effect: no overlapping quad clips. The compile error is quoted above.
2. **The box_test header comment** is wrapped over three lines instead of the brief's single 230-character line. The text is unchanged.
3. **`box_plan_test.dart`:** `dart format` re-wrapped one `doc.commands.execute(...)` line, as the brief's Step 5 directs. No code change.
4. **The Step 3 RED wording** is the CFE's "Error when reading … No such file or directory", not the analyzer's "Target of URI doesn't exist". The cause is the same.

## Concerns

1. **BX4 cannot detect a lost clip (its integration half of M-BX-4 stays green).**
   - Box A spans (7010, 3020)-(7130, 3090); box B spans (7100, 3060)-(7190, 3120). They overlap only at a corner.
   - Unclipped, each box still has 4 children.
   - The midpoints of the four touched edges lie on or outside the other box, never strictly inside it: A-east (7130, 3055), A-north (7070, 3090), B-west (7100, 3090), B-south (7145, 3060). So `_strictlyInside` is false for each.
   - The drift check only compares against a fresh system running the same `generate`.
   - The old line's BX4 has the same blind spot (same fixture). Clipping is pinned by BT3 in the kit, which goes red.
   - Per the porting rule I did not touch BX4. If the controller wants an integration-level clip pin, a **new** case could assert a touched edge's length, for example A's east child spanning y 3020→3060 (40, not 70). That is new work, not a port change.
2. **The grid fixture change is not load-bearing.** With `snapToGrid: false`, BX1-BX6 all pass: BX2's `closeTo(…, 1e-6)` absorbs the camera's sub-picometre error. The change is harmless and keeps exact corners, but the brief's justification ("the grid gives the clicks today's corners", needed for the assertions) overstates it for this file.
3. **BX-props uses a single box** (the brief's fixture): a turned group off the origin, not a pair. Its subject is the field and commit rules, not geometry, so I take it as within the bar.
