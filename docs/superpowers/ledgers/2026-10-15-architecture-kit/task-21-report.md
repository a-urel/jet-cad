# Task 21 report: the dimension type, grips and properties

Status: **NEEDS_CONTEXT**. Everything is done and committed except one integration file. `packages/jet_cad_2d_integration/test/dimension/dimension_panel_test.dart` is in the worktree, untracked. It waits on two findings that the brief says to stop and report: PN2's focus line, and PN5's refused edit. See "Rulings needed" below.

Commit: `eef72684 feat(kit-architecture): the dimension type, grips and properties (3a C3.6)`. Everything in the brief's file list is in it, apart from the panel test. It also carries `test/support/room_plans.dart` (see Deviation 2).

## Implementation summary

- `lib/src/dimension/dimension_grips.dart`: ported per Step 3, with `live` threaded through `thickestWall`, `wallsInDocument` and `attachCandidates`. `_stateOf` and `_pointOf` are no longer static.
  - **FREEZE RULE.** The grips do hold a memo over live walls. They keep a per-drag `_memoPoints`, plus `_memoThickest` and `_memoDim`, which are also laid out among the live walls, and today these are dropped only on `doc.changes`.
  - The fix: the memo now records the walls that were live when it was made (`_memoWalls`, a reused list). `_syncMemo`'s fast path also requires `_memoStillLive()`, an indexed loop of `live(h) == wall` with no allocation.
  - So a freeze between two previews of one drag drops the memo, and the next preview lays out afresh. The drop never read the memo, unchanged.
  - Every memoised point depends on every live wall (`wallsInDocument` reads them all), so the walls are the whole dependency. Freezes only grow, and a new wall is a document change.
  - The class doc gains a "A freeze drops it too" paragraph.
  - GE5b's layout counts are unchanged: the memo is not dropped spuriously. It printed a median of 102 us per preview among 612 walls.
- `lib/src/dimension/dimension_plan.dart`: Step 5 verbatim, giving `dimensionPlanType`, `dimensionValueOf`, `dimensionAxesOf`, `dimensionEndLine` and `debugDimensionValueScans`. The axes line is a `TextDisplay` over `object.world`, using `words.decimalSeparator`, which is the UI's.
- `lib/src/kit.dart`: `dimensionPlanType` appended last to `types`.
- Kit tests:
  - `test/dimension/dimension_object_test.dart` and `dimension_grips_test.dart` are ported.
  - `dimension_plan_test.dart` holds DM-fields, DM-value, DM-axes and DM-grips (all four as in the brief), plus a new DM-freeze.
  - `test/wall/wall_grips_test.dart` gains EG9-k and EG10-k.
- Integration tests:
  - `test/dimension/dimension_plans.dart` is the support file.
  - `test/wall/wall_grips_test.dart` gains EG9 and EG10.
  - `test/dimension/dimension_panel_test.dart` is uncommitted.

### DM-freeze (new; the FREEZE RULE's first-reader step)

The test runs two drags. Each has its own L at the corpus far origin, its own services with a mutable `frozen` set, and a horizontal dimension in a group turned 53°, with b = A/1/right. That point is the outer mitre (4100, −100) while B is live, and (4000, −100) once B is frozen.

In each drag:
1. One preview builds the memo while B is live.
2. B is frozen, with no document change.
3. The very next preview must equal a fresh provider's preview, which has 5 lines. As a premise, the fresh preview must differ from the preview taken before the freeze.
4. A drop then commits, and b keeps its reference.

The two drags:
- **Grip 0 (offset):** the stale `_memoDim` would keep b at the mitre.
- **Grip 1 (a's end) at the outer mitre:** with the stale memo, A/1/right is still at the mitre and equals b, so the preview is refused and empty. Fresh, a is fixed there, 100 from b, and the preview has 5 lines.

The named mutation is M-DM11, which removes `&& _memoStillLive()`. Both drags go red, each checked on its own (results below).

## TDD evidence

RED, `flutter test test/dimension/dimension_plan_test.dart` (before any lib file):
```
test/dimension/dimension_plan_test.dart:18:8: Error: Error when reading 'lib/src/dimension/dimension_plan.dart': No such file or directory
test/dimension/dimension_plan_test.dart:35:5: Error: Undefined name 'dimensionPlanType'.
test/dimension/dimension_plan_test.dart:106:19: Error: Undefined name 'debugDimensionValueScans'.
```
RED for the FREEZE RULE, after the straight port of the grips and before the re-check (`--plain-name DM-freeze`):
```
     Which: at location [2] is <4500787.723943477> instead of <4500735.605233634>
  the offset grip: the next preview, B frozen
```
GREEN after `_memoStillLive`: `flutter test test/dimension/dimension_plan_test.dart test/dimension/dimension_grips_test.dart test/dimension/dimension_object_test.dart` gave `00:02 +38: All tests passed!`.

## Gates

Kit (`packages/jet_cad_2d_kit_architecture`):
- Precondition at 83d84672: `00:30 +353: All tests passed!`, `No issues found!`.
- `flutter test`: `00:42 +391: All tests passed!`.
- `flutter analyze`: `No issues found! (ran in 6.2s)`.
- `dart format --output=none --set-exit-if-changed .`: `Formatted 106 files (0 changed)`, exit 0.
- `dart pub publish --dry-run` (after the commit): `Package has 0 warnings.`

Integration (`packages/jet_cad_2d_integration`):
- `flutter analyze`: `No issues found!`.
- `dart format --output=none --set-exit-if-changed .`: `Formatted 29 files (0 changed)`, exit 0.
- `flutter test --enable-vmservice`, with the untracked panel test present: `00:16 +88 -2: Some tests failed.`
  - The two failures are PN2 at origin and PN2 at corpusGroups, both on the focus line only (see Rulings needed).
  - With that one line replaced in a scratch copy, which was then deleted, PN2 passes at both placements: `00:02 +2: All tests passed!`.
- `flutter test --enable-vmservice test/wall/wall_grips_test.dart`: `00:03 +11: All tests passed!`.
- I did not run the integration precondition before the changes. The full suite after the changes is the one above.

Repository root: `dart run tool/ci/check_kit_deps.dart` gave `kit dependencies: 2 package(s) checked, none names the plan library or another kit`, exit 0.

`git status --short` after the commit and after every mutation shows only `?? packages/jet_cad_2d_integration/test/dimension/dimension_panel_test.dart`.

Non-ASCII checks:
- Lines per file match their sources: `dimension_object_test` 46/46, `dimension_grips_test` 26/26, `dimension_panel_test` 23/23.
- For object and grips, the lines are identical.
- For the panel test, the lines differ only in indentation (moved into the `planOf` closure, then reformatted) and in the keys `dimension-axes` → `property-axes`.
- `grep` shows U+2014 at `dimension_plan.dart:89` (`'—'`) and the degree sign where Steps 2 and 5 write them.

The precheck grep for `GE1`, `DO1 ` and `DD1` in the plan and kit tests found nothing (exit 1).

## Mutation results

Every mutation ran on a committed file. Each was reverted with `git checkout --`, and `git diff --quiet` exited 0 every time (`reverted-clean`).

| Mutation | Test | Red line |
|---|---|---|
| M-DM1 delete `gate: PlanGate.reshape` | DM-fields | `Expected: PlanGate:<PlanGate.reshape>  Actual: <null>` |
| M-DM2 swap `end-start` and `end-end` | DM-fields; PN1; PN4 | `Expected: 'Wall 12, start, right face'  Actual: 'Wall 12, end, right face'`; PN1 `Expected: 'Wall 12, start, left face'  Actual: 'Wall 12, end, left face'`; PN4 `Expected: 'Wall 3E, end, right face'  Actual: 'Wall 3E, start, right face'` |
| M-DM3 the memo test without `memo.state != state` | DM-value; PN1 | `Expected: '3951'  Actual: '3451'  a new state is read`; PN1 `... after the wall edit` |
| M-DM4 the memo test → `if (true)` | DM-value | `Expected: <2>  Actual: <4>  one state: no rescan` |
| M-DM5 delete `.replaceAll('.', words.decimalSeparator)` | DM-axes | `Expected: 'Achsen um 53,0° gedreht'  Actual: 'Achsen um 53.0° gedreht'` |
| M-DM6 `face-right` → `face-left` | DM-axes; PN4 | `Expected: 'Duvar 12, bitiş, sağ yüzey'  Actual: 'Duvar 12, bitiş, sol yüzey'`; PN4 `Expected: 'Wall 3E, end, right face'  Actual: 'Wall 3E, end, left face'` |
| M-DM7 `objectSnap: () => true` | DM-grips | `Expected: <Instance of 'FixedEnd'>  Actual: AttachedEnd:<12/0/left>  F3 off` |
| M-DM8 `live:` → the pre-C1.5 `WallParams` rule, with its import | DM-grips | `Expected: <Instance of 'FixedEnd'>  Actual: AttachedEnd:<12/0/left>  A frozen: no wall end point` |
| M-DM9 `drag`: `if (next == null) return null;` | GE2 (both placements) | `Expected: null  Actual: <Instance of 'SetComponentCommand<DimensionParams>'>` |
| M-DM10 `line(l.ext0)` without the flag | DO1 | `Expected: [0, 2, 2, 0, 0, 0]  Actual: [0, 0, 2, 0, 0, 0]` |
| M-DM11 (new) `_syncMemo` without `&& _memoStillLive()` | DM-freeze | `Which: at location [2] is <4500787.723943477> instead of <4500735.605233634>  the offset grip: the next preview, B frozen` |

For M-DM11, the second drag was also run on its own: the offset-grip entry was removed from the committed test, and both files were reverted afterwards. It gave `Actual: []  Which: at location [0] is [] which shorter than expected  a's grip on the outer mitre: the next preview, B frozen`.

The PN1 and PN4 red lines were run against the untracked panel test, whose PN1 and PN4 cases pass without the mutations.

## Ported-test accounting

| Source (jet_cad_floor_plan/test) | Destination | Cases | Change class |
|---|---|---|---|
| dimension_object_test | kit `test/dimension/` | DO1, DO2, DO3, DO4, DO6, DO5, DD1-DD5 (22 runs) | imports only |
| dimension_grips_test | kit `test/dimension/` | GE1, GE2, GE3, GE4, GE5 at both placements, GE5b | imports; `live: liveOf(doc)` (fixture). Three adaptations, detailed below |
| dimension_panel_test | integration (uncommitted) | PN1-PN4 and PN5 at both placements; PN5 refused → PN5-open (pending) | DM-R2 (the `bruteCandidates` premises dropped); DM-R3 (keys, the menu); fixture (`planOf`/`buildPlanIn`) |
| wall_grips_test EG9, EG10 | kit EG9-k, EG10-k; integration EG9, EG10 | 2 + 2 | R-P8 split; the `live` reader arguments; the grip dispatch (fixture); the keys (class 3) |

The three grips-test adaptations:
- **GE1 (DM-R1).** The provider comes from `dimensionPlanType.gripsFor(FakePlanServices)`. The no-index line is not ported, because its premise is impossible.
- **GE4.** It uses `final ObjectGripProvider objects = grips;`.
- **`index`.** It is unused in GE1 and GE4, so those cases destructure it as `_`.

DM-* are new: DM-fields, DM-value, DM-axes, DM-grips and DM-freeze.

## Deviations

1. **The panel test is not committed.** It waits on the two rulings below, and the brief's single commit is otherwise intact. The commit message says so.
2. **No second copy of helpers (R-P14).** The brief's `dimension_plans.dart` copied `W`, `S`, `O`, `Placement`, `origin`, `corpusGroups`, `groupFor`, `addWallLocal`, `kids`, `kindOf`, `payloadOf`, `enc`, `driftOf`, `deleteObject` and `select`. All of these already exist in the integration package's `support/room_plans.dart` and `support/wall_fixture.dart`, with identical bodies. `dimension_plans.dart` imports and re-exports them instead, and also re-exports `canon`.
   - `room_plans.dart`'s private `_groupFor` became public `groupFor`. That is a rename in Task 18's file (3 occurrences), and room tests stay green.
   - The editor rig's names are re-exported as the brief lists. `unnecessary_import` forbids importing the rig again, since `room_plans.dart` already provides `kitCatalog` and `pumpEditor`.
   - The brief's `kids`/`kindOf`/`dimText` came from fixtures; only `dimText`, `fixedAt`, `addDimension`, `addSeparator`, `addOpening`, `buildPlanIn`, `planOf`, `setPage`, `mmPage`, `c2Walls`, `stalePlan`, `pumpPlan` and `byKey` are new.
3. **EG10-k drops today's `:803` `dimP`.** In the kit it is unused, and `unused_local_variable` is an error; it is read only by the shell half. It is replaced by a comment, as EG8-k did. The integration EG10 keeps it.
4. **Brief import names fixed for the analyzer.**
   - EG9-k and EG10-k import `jet_cad_2d_flutter` `show ObjectGripProvider` only (`Grip` and `GripRole` are the engine's).
   - The integration `wall_grips_test` adds `package:flutter/foundation.dart show Key`. `TextInputAction` comes through `flutter_test`.
5. **The FREEZE RULE re-check (see above) and DM-freeze / M-DM11.** These are additions the task notes asked for; the brief does not name them.

## Rulings needed (NEEDS_CONTEXT)

1. **PN2's focus line fails against the plan's panel.** This is the line `expect(FocusManager.instance.primaryFocus, focus, reason: 'the click leaves the focus where it was')`, kept as written per the brief. The brief says to stop and report here.
   - Evidence from the failure:
     ```
     Expected: FocusNode:<FocusNode#c6d3f(InteractionLayer)(context: Focus)>
       Actual: FocusNode:<FocusNode#a5995(DropdownButton<Object?> [PRIMARY FOCUS])(context: Focus,
     ```
   - A scratch probe (deleted) traced the focus through one choice: before, the `InteractionLayer` had primary focus; with the menu open, the menu route's node had it; after the choice, `DropdownButton<Object?>` had it.
   - In the same probe, `press(W)` was handled and the status read `Wall`, so tool letters still reach the editor. What changes is only the focused node: today's `SegmentedButton` left it on the canvas, and the plan's `DropdownButton` keeps it.
   - The rest of PN2 passes once that one line is removed (scratch, deleted).
   - The fix would be in the plan library's `plan_property_panel.dart` ChoiceProperty row: hand focus back to the canvas after a choice, or a dropdown that does not take focus. That is out of this task's scope. The alternative is a C7 class-3 ruling on the line.
2. **PN5's refused edit: the premise is now frozen at open.** The faithful port's premise failed:
   ```
   Expected: throws <Instance of 'StateError'>
     Actual: <Closure: () => void>
      Which: threw PlanLocked:<PlanLocked: the edit would change a locked object>
   ```
   The brief says to stop and report. The notes' Task 18 rule (RN5-open and RN5-refused) covers this case, so I applied it in the uncommitted file, pending your confirmation:
   - **PN5-open:** the same file and repointing. It asserts `c.frozen` contains d and not A; the switch throws `PlanLocked`; `canon` is unchanged; selecting d shows no Dimension section; undo depth stays 0. It passes.
   - **The live half has no premise.** No live dimension's kind switch can be refused by the type or the document. Every kind is one of the menu's values, and a regeneration the engine refuses is frozen at open (C1.10). So "Decided: premise impossible" is recorded in the file's comment.
   - On a live dimension, the panel's catch of a refused edit is already exercised by PN5's stale callback under runtime.
   - Please confirm, or rule otherwise.

## Concerns

- The grips' liveness re-check costs O(walls) calls of `live` per preview. That is the `WallBands._stillLive` precedent, and it allocates nothing. Task 22's tool hover memo over `attachCandidates`' `points` needs the same re-check.

---

# Fix report (after the controller's rulings)

Status: **DONE**. The commits on top of eef72684 are:
- `90417584 fix(plan): a choice row hands the focus back to the canvas`
- `17294c58 test(kit-architecture): the dimension panel's integration cases (3a C3.6)`

## Ruling 1: PN2, fixed in the plan library

PN2's focus line is ported unchanged and now passes. I chose to restore the focus after a choice, not to use a dropdown that never takes it, because a non-focusable dropdown would lose Tab access to the row.

How it works, in `packages/jet_cad_2d_plan/lib/src/panels/plan_property_panel.dart`:
- Each ChoiceProperty row's `DropdownButton` gets its own `PanelFieldFocusNode` (`_choiceFocus`, keyed by the row's key name and disposed with the state).
- `onChanged` runs `_act(...)` and then `_handBackAfterChoice(focus)`. That uses the panel fields' existing `handBack()`, which walks back through the scope's focus history to the node before the panel: the canvas.
- **Why it waits.** `DropdownButton` requests the focus for the row when the menu opens (Flutter 3.27.3 `dropdown.dart:1504`). The menu's route gives the focus back to the row as it closes, but only after `onChanged` has already run. A probe showed the restore lands in the same event, before the next frame.
- So `_handBackAfterChoice` hands back at once if the row already has the focus. Otherwise it adds a one-shot listener that hands back when the row next gains the focus, and removes that listener at the end of the frame.
- A menu dismissed without a choice leaves the focus on the row, as a focused field keeps it.

RED, the new plan test before the fix:
```
Expected: same instance as FocusNode:<FocusNode#887b6(InteractionLayer)(context: Focus)>
  Actual: FocusNode:<FocusNode#74c59(DropdownButton<Object?> [PRIMARY FOCUS])(context: Focus,
the choice hands the focus back
```
My first attempt called `handBack()` straight from `onChanged`, and it stayed red: `Actual: PanelFieldFocusNode:<...(property-finish [PRIMARY FOCUS])`. That attempt is now mutation M-P-choice-focus-b.

The test is **P-choice-focus** in `packages/jet_cad_2d_plan/test/panels/property_panel_test.dart`, using the box kit's `finish` choice:
1. The canvas is focused, with a premise that it has the focus.
2. The finish menu opens, with a premise that the menu has the focus.
3. Gloss is picked: the value is stored, in one undo step, and the focus is back on `canvasFocus`.
4. Matte is picked: the focus is back on the canvas again.
5. B is pressed: the key is handled and the status starts with `Box`.

The plan package has no `keyboard_focus_test`. The whole plan suite, which includes the panel and shortcut focus tests, passes with the fix.

## Ruling 2: PN5, confirmed

PN5-open stands as written, and the live half is recorded as "Decided: premise impossible" in the file's comment. It was committed in 17294c58.

## Gates (final HEAD 17294c58)

- Plan (`packages/jet_cad_2d_plan`):
  - `flutter test --enable-vmservice`: `02:01 +1549: All tests passed!`
  - `flutter analyze`: `No issues found! (ran in 4.0s)`
  - `dart format --output=none --set-exit-if-changed .`: `Formatted 299 files (0 changed)`, exit 0.
- Integration:
  - `flutter test --enable-vmservice`: `00:15 +90: All tests passed!`
  - `flutter analyze`: `No issues found!`
  - Format: 29 files, 0 changed, exit 0.
- Kit:
  - `flutter test`: `00:18 +393: All tests passed!` (391 + EG9-k + EG10-k).
  - `flutter analyze`: `No issues found!`
  - Format: 106 files, 0 changed, exit 0.
- Root: `dart run tool/ci/check_kit_deps.dart` gives `kit dependencies: 2 package(s) checked, none names the plan library or another kit`.
- `git status --short` is empty after the commits and after every mutation.

## Mutations (all rerun on final HEAD; each reverted, `git diff --quiet` exit 0)

| Mutation | Test | Red line |
|---|---|---|
| M-P-choice-focus: delete the `_handBackAfterChoice(focus);` call | P-choice-focus; PN2 (integration) | `Expected: same instance as FocusNode:<...(InteractionLayer)...> Actual: PanelFieldFocusNode:<...(property-finish [PRIMARY FOCUS])... the choice hands the focus back`; PN2 `Actual: PanelFieldFocusNode:<...(property-kind [PRIMARY FOCUS])... the click leaves the focus where it was` |
| M-P-choice-focus-b: the listener only when the row already has the focus (no deferred hand-back) | P-choice-focus | `Actual: PanelFieldFocusNode:<...(property-finish [PRIMARY FOCUS])... the choice hands the focus back` |
| M-DM1 | DM-fields | `Expected: PlanGate:<PlanGate.reshape>  Actual: <null>` |
| M-DM2 | DM-fields; PN1; PN4 | `'Wall 12, start, right face'` vs `'Wall 12, end, right face'`; PN1 `'Wall 12, start, left face'` vs `'... end ...'`; PN4 `'Wall 3E, end, right face'` vs `'Wall 3E, start, right face'` |
| M-DM3 | DM-value; PN1 | `Expected: '3951'  Actual: '3451'` (both) |
| M-DM4 | DM-value | `Expected: <1>  Actual: <3>` (`one state: no rescan`; the counts differ from the first run because this run was the single test) |
| M-DM5 | DM-axes | `'Achsen um 53,0° gedreht'` vs `'Achsen um 53.0° gedreht'` |
| M-DM6 | DM-axes; PN4 | `'Duvar 12, bitiş, sağ yüzey'` vs `'... sol yüzey'`; PN4 `'Wall 3E, end, right face'` vs `'... left face'` |
| M-DM7 | DM-grips | `Expected: <Instance of 'FixedEnd'>  Actual: AttachedEnd:<12/0/left>` |
| M-DM8 | DM-grips | `Expected: <Instance of 'FixedEnd'>  Actual: AttachedEnd:<12/0/left>` |
| M-DM9 | GE2 | `Expected: null  Actual: <Instance of 'SetComponentCommand<DimensionParams>'>` |
| M-DM10 | DO1 | `Expected: [0, 2, 2, 0, 0, 0]  Actual: [0, 0, 2, 0, 0, 0]` |
| M-DM11 | DM-freeze | `Which: at location [2] is <4500787.723943477> instead of <4500735.605233634>` |

## Notes

- The plan's CHANGELOG is not touched. No 3a plan change has an entry there yet (its last change is 2b's), so I left the line for whichever task writes the 3a CHANGELOG entries.
