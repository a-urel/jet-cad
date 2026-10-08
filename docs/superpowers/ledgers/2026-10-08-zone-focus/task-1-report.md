# Task 1 report — the candidate rule and the framing (Z0–Z9)

Implementer's report. Branch `claude/exciting-pasteur-9m22jv`, base `d0e510e`.
Nothing is committed: the changes are in the working tree.

## What was built

All paths are under `packages/jet_cad_floor_plan/`.

### Z0 — one candidate rule
- `lib/src/service/table_picker.dart:103` `TableCandidate`: the table, its
  transform, the definition box, the box's four world corners (a
  `Float64List(8)`, in (min,min), (max,min), (max,max), (min,max) order) and
  `locked`. `:129` `worldBounds` is the corners' axis-aligned bound (Z2).
- `:233` `static TablePicker.candidatesOf(document, {boxes, leaves})`: the
  rule moved out of `_build` (survey table, visible layer, finite non-zero
  determinant, non-empty box), plus the new rule at `:260`: every one of the
  four transformed corners finite. `leaves` is called at most once per call
  and only for a definition whose box is not cached.
- `:209` `_build` now maps `candidatesOf` to `PickCandidate`. It passes a
  memoising `scan()`, so the boxes and the tops still share one
  entity-store scan per build (TP12 unchanged and green).
- The picker's existing tests are unedited and green.

### Z3 — `lib/src/host/table_fit.dart`
- `:14` `kTableFitMarginMm = 500` and `:18` `kTableFitMinSpanMm = 3000`.
- `:26` `frameTables(Aabb2, Size)` is pure. It grows the box by the margin
  per side, grows each axis about the centre to the minimum span, applies
  `ViewportTransform.fit`, and clamps the scale to `[kMinScale, kMaxScale]`
  about the same centre with y flipped.

### Z1, Z2, Z4–Z6, Z8, Z9 — `lib/src/host/floor_plan_controller.dart`
- `:217` `_fitTarget` sits beside `_fitPending`. It is null for the page,
  else the trimmed number set of the last `fitToTables` that found a table.
- `:369` `@internal framingFor(Size)` returns null when the target is the
  page or nothing matches now (Z6). Otherwise it returns `frameTables` of
  the bound.
- `:379` `_tablesBounds` is the union of `worldBounds` over
  `candidatesOf(active document, boxes: {}, leaves: leavesByOwner)` whose
  number is in the set. It uses a fresh box cache and scans once per call.
  The candidates are resolved at call time.
- `:934` `bool fitToTables(Set<String>)`:
  - trims the numbers, drops blanks and copies them unmodifiable;
  - when nothing is found it returns false and changes nothing (Z4);
  - otherwise it sets the target, sets `_fitPending`, bumps `_fits` and
    returns true.
  - It calls no settle, no notify and no command (Z9).
- `:905` `fitToView` sets the target to null (Z5: the last request wins).
- `:657` `_replaceDesign` (`load`, `newPlan`) resets the target beside
  `_fitOnStart` (Z8). `setMode`, `resetLayout` and `restoreServiceLayout` do
  not touch it.
- Doc comments on `takeFitOnStart` and `fitted` now say that `fitToTables`
  goes through the same pending machinery.

### Z7 — the seam
- `lib/src/planner_view.dart:99` adds the optional
  `PlannerView.framing: ViewportTransform? Function(Size)?`.
- `:163` `_onFitRequest` posts `_fit(_size!)`, so `_size` is read when the
  post-frame callback runs, after this frame's layout.
- `:178` `_fit` sets `widget.framing?.call(size) ?? (today's page/extents
  fit)` and keeps the `!mounted` guard.
- `lib/src/planner_shell.dart:156` adds `PlannerShell.framing`, forwarded at
  `:984`.
- `lib/src/host/floor_plan_view.dart:233` passes `c.framingFor` to the
  shell, and `lib/src/host/service_view.dart:404` passes `_c.framingFor` to
  its `PlannerView`.

## Tests

The fixture is `test/host/zone_fixture.dart` (new, shared with Task 2). It
follows the spec's fixture rule:
- the hand-made asymmetric trapezoid, turned 37°, some copies mirrored,
  about 40 m off the origin;
- a hidden layer (table `5`) and a locked layer `L` (table `L`);
- `2` used twice, `B4`, and an unnumbered table;
- table 7 labelled ` 7 `;
- a root TEXT `7` and a real room named `7`, built through the parametric
  system so that its generated name label is a TEXT `7`, both more than
  15 m from table 7.

Every call is preceded by a non-identity camera (panned, 0.37 px/mm).
Expectations come from the symbols' own boxes, taken through the forward
transform in the test (`boundOf`). Cameras compare with `closeTo` at a
relative 1e-12; centres compare within 1e-6 px.

- `test/host/table_fit_test.dart` (new): TF1–TF4.
- `test/host/controller_test.dart:556–` CZ1–CZ6.
- `test/host/view_test.dart:924–` VZ1–VZ11.
- `test/host/seams_test.dart:69–` SM3.
- `test/service/table_picker_test.dart:422–` TP13: the plain pin of the
  picker's candidate list on the non-finite fixture (a NaN translation, an
  infinite corner with a finite determinant, and a singular transform), for
  both `candidatesOf` and `TablePicker.candidates`.

## Mutants

Each mutant was applied by a scratch script that does exact string
replacements. It runs the killing test with `--plain-name` and a JSON
reporter, then restores the file from a scratch copy taken before any
mutation, and confirms the restore with `cmp` (exit 0 every time). After the
last restore, each source file was compared with `cmp` against its scratch
copy (all identical). Every red result below is a `TestFailure` (an
expectation failing) and never a compile error or a crash.

| Mutant | What was applied | Killing test | Result |
|---|---|---|---|
| M-Z1 | `_tablesBounds` also unions the world anchor of every TEXT whose trimmed text is a requested number | CZ1 | red |
| M-Z2 | `candidatesOf` drops the visible-layer check | CZ2 | red |
| M-Z3a | the box at the identity (`c.box`, the definition box) | CZ1 | red |
| M-Z3b | the box moved by the translation only | CZ1 | red |
| M-Z4a | no minimum span (both axes) | TF1 | red |
| M-Z4b | no clamp | TF4 | red |
| M-Z4c | no lower clamp (`clamp(0, kMaxScale)`) | TF4 | red |
| M-Z4d | no upper clamp | TF4 | red |
| M-Z5a | margin dropped (0) | CZ3, TF2 | red, red |
| M-Z5b | margin doubled (1000) | CZ3, TF2 | red, red |
| M-Z5c (extra, for TF3) | margin on x only | TF3 | red (TF2 and CZ3 survive it: TF3's own reason to land) |
| M-Z6a | minimum span grown from the min edge, not about the centre | VZ5, TF1 | red, red |
| M-Z6b | clamp path not y-flipped | TF4 | red |
| M-Z6c | clamp path centred on the box's min corner | TF4 | red |
| M-Z7a | `_fits.bump()` before the none-found return | CZ5 | red |
| M-Z7b | `_fitPending = true` before the none-found return | CZ5 | red |
| M-Z8 | `fitToTables` sets no `_fitPending` | VZ1 | red |
| M-Z9 | target reset in `newPlan` only (so `load` keeps it) | VZ2 | red |
| M-Z10 | box captured at the call, used at the fit | VZ3 | red |
| M-Z11a (framing half) | `notifyListeners()` in `fitToTables` | CZ6 | red |
| M-Z11b | `_revision.value++` in `fitToTables` | CZ6 | red |
| M-Z11c | `_settle?.call()` in `fitToTables` | CZ6 | red |
| M-Z11d | `_layoutChanges.bump()` in `fitToTables` | CZ6 | red |
| M-Z12a | `fitToView` keeps the target | VZ4 | red |
| M-Z12b | `fitToTables` sets the target only when no fit is pending (the first request wins) | VZ4 | red |
| M-Z13 | one table per number (a seen-set) | CZ4 | red |
| M-Z14 | F-5's order reversed: `FloorPlanView`'s measurement deferred one more post-frame callback, so it lands after the fit | VZ6 (also VZ10) | red, red |
| M-Z15a | `PlannerShell` does not forward `framing` | SM3, VZ7 | red, red |
| M-Z15b | `FloorPlanView` does not pass `framingFor` to the shell | VZ7 | red |
| M-Z15c (extra) | `ServiceView` does not pass `framingFor` | VZ5, VZ1 | red, red |
| M-Z30a | the target is set before the none-found check | VZ8 | red |
| M-Z30b | a failed call clears `_fitPending` | VZ8 | red |
| M-Z31a | `framingFor` null: no fit and no `fitted()` | VZ9 | red |
| M-Z31b | `framingFor` null: the page is fitted, but there is no `fitted()` | VZ9 | red |
| M-Z31c | `framingFor` null: the old camera is kept, `fitted()` is called | VZ9 | red |
| M-Z32 | target reset in `load` only (so `newPlan` keeps it) | VZ2 | red |
| M-Z33a | `!mounted` guard removed from `PlannerView._fit` | VZ10 | **survived the spec's killer**; red after VZ10 was strengthened (below) |
| M-Z33b | the measurement registered after the fit (M-Z14's mutation) | VZ10 | red |
| M-Z40 | locked tables skipped by the framing | CZ2 | red |
| M-Z41 | size captured at the request (the old `_onFitRequest`) | VZ11 | red |
| Z0 plain pin (no number; M-Z43 is Task 2's) | the four-finite-corners check removed | TP13 | red |

**M-Z33a and the spec's killer.** The spec's killer was: a mounted design
view, `fitToTables` then `setMode(selection)` in one step, pump twice,
centred. It does not kill a removed `!mounted` guard:
1. The old view's posted fit always runs first. It sets the camera at the
   design size and calls `fitted()`.
2. The new view had already taken `fitOnStart = true` in its build, so it
   fits on its first frame anyway and overwrites the old view's camera.

That run passed (`success`, recorded in the mutant log).

I strengthened VZ10 with a second half, in the same test:
1. A mounted design view; the host calls `fitToTables` and unmounts the
   view in the same step.
2. `setMode(selection)`, then remount.

Without the guard, the unmounted view's posted fit calls `fitted()`, so the
remounted view has nothing pending and does not frame. VZ10 is then red,
with a scale of 0.0679 against the expected 0.1091. With the guard, it is
green.

## Deviations and notes

- **`TableCandidate` is a new class beside `PickCandidate`.**
  `candidatesOf` returns `List<TableCandidate>`, and the picker maps it to
  `PickCandidate`. I added it because the framing and the veil need the
  transform and the world corners, not the inverse or the top. The corners
  are computed for the finite check anyway, so they are kept for Task 2's
  quads. `PickCandidate` is unchanged.
- **`candidatesOf` takes `required` named `boxes` and `leaves`.** This is as
  the plan names them. The framing passes `boxes: {}` and
  `leaves: document.leavesByOwner`.
- **The VZ10 strengthening for M-Z33a**, described above. The spec allowed
  for this ("each killer is a hypothesis until seen red").
- **M-Z32 as specified ("M-Z9 with `newPlan`") cannot go red on its own.**
  `newPlan` is empty and Z6 falls back to the page when nothing matches. So
  VZ2's `newPlan` half places a table `3` in the new plan before the view
  mounts. The old request named the old plan's 3.
- **M-Z9 and M-Z32 are split into two mutants.** `load` and `newPlan` share
  `_replaceDesign`, so I moved the reset into one of them at a time. That
  way each half of VZ2 is shown to be needed.
- **Existing tests are unedited (I-6).** The only change to an existing
  line of a test file is the import in `controller_test.dart`:
  `dart:ui show Color` became `show Color, Size`. New tests and imports are
  appended.
- `frameTables` asserts a non-empty box; `framingFor` never passes an empty
  one.
- The engine and the renderer are untouched.

## Gates

All run after the last restore, on the final tree. Each package ran
`<tool> test --file-reporter json:<tmp>/<pkg>.json`, then from the repo root
`dart run tool/ci/expect_failures.dart --package <pkg> --root <pkg> <json>`,
then analyze and format. The outputs, as printed:

```
=== packages/jet_cad_floor_plan
test runner exit 0
03:10 +1403: All tests passed!
packages/jet_cad_floor_plan: 1403 tests; the standing failures and skips, exactly
expect_failures exit 0
Analyzing jet_cad_floor_plan...
No issues found! (ran in 3.4s)
analyze exit 0
Formatted 240 files (0 changed) in 0.85 seconds.
format exit 0
=== apps/floor_planner
test runner exit 0
01:18 +212: All tests passed!
apps/floor_planner: 212 tests; the standing failures and skips, exactly
expect_failures exit 0
Analyzing floor_planner...
No issues found! (ran in 5.0s)
analyze exit 0
Formatted 47 files (0 changed) in 0.14 seconds.
format exit 0
=== apps/restaurant_demo
test runner exit 0
00:18 +37: All tests passed!
apps/restaurant_demo: 37 tests; the standing failures and skips, exactly
expect_failures exit 0
Analyzing restaurant_demo...
No issues found! (ran in 3.6s)
analyze exit 0
Formatted 4 files (0 changed) in 0.04 seconds.
format exit 0
=== packages/jet_cad_2d
test runner exit 1
For example, 'dart test --chain-stack-traces'.
packages/jet_cad_2d: 1255 tests; the standing failures and skips, exactly
expect_failures exit 0
Analyzing jet_cad_2d...
No issues found!
analyze exit 0
Formatted 169 files (0 changed) in 0.50 seconds.
format exit 0
=== packages/jet_cad_2d_flutter
test runner exit 1
  ... and 3 more
packages/jet_cad_2d_flutter: 1363 tests; the standing failures and skips, exactly
expect_failures exit 0
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 5.0s)
analyze exit 0
Formatted 221 files (0 changed) in 0.52 seconds.
format exit 0
```

The engine and render runners exit 1 because of their standing failures
(engine 2, render 7 plus 1 skip). The comparison is the verdict, and it is
exact for both. The engine was analyzed with `dart analyze --fatal-infos`,
as CI does.

The order was:
1. The VZ10 strengthening.
2. The M-Z33a, M-Z33b and M-Z14 re-runs.
3. These gates, which include the strengthened VZ10.
4. The M-Z5c run, after the gates. It is a mutation only, and its file was
   restored and confirmed with `cmp` (exit 0).

## `git status --short`

```
 M packages/jet_cad_floor_plan/lib/src/host/floor_plan_controller.dart
 M packages/jet_cad_floor_plan/lib/src/host/floor_plan_view.dart
 M packages/jet_cad_floor_plan/lib/src/host/service_view.dart
 M packages/jet_cad_floor_plan/lib/src/planner_shell.dart
 M packages/jet_cad_floor_plan/lib/src/planner_view.dart
 M packages/jet_cad_floor_plan/lib/src/service/table_picker.dart
 M packages/jet_cad_floor_plan/test/host/controller_test.dart
 M packages/jet_cad_floor_plan/test/host/seams_test.dart
 M packages/jet_cad_floor_plan/test/host/view_test.dart
 M packages/jet_cad_floor_plan/test/service/table_picker_test.dart
?? packages/jet_cad_floor_plan/lib/src/host/table_fit.dart
?? packages/jet_cad_floor_plan/test/host/table_fit_test.dart
?? packages/jet_cad_floor_plan/test/host/zone_fixture.dart
```

No `analysis_options.yaml` appears.
