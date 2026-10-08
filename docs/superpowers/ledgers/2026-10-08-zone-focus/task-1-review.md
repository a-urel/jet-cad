# Task 1 review — the candidate rule and the framing (Z0–Z9)

Independent review of commit `ba7eec2` (parent `d0e510e`), branch
`claude/exciting-pasteur-9m22jv`. Everything was run in my own clones,
`/tmp/zone-t1-review/repo` (gates) and `/tmp/zone-t1-review/mut`
(mutants). Both are at `ba7eec2` and `git status --short` is empty in both
after every run. No `analysis_options.yaml` needed copying: all ten are
tracked. Flutter at `/root/sdk/flutter/bin`, `CI=true`. Nothing was
committed.

## Verdict: **Approved**

The code does what Z0–Z9 say. The two deviations the report records are
both justified, and I reproduced both (below). R-13's `setMode`, `load`
and `fitToView` are unchanged apart from the target. No existing test
body was edited. Every assigned mutant I re-ran went red with a
`TestFailure`. Every gate is green and the standing sets are exact.

The findings are two minors and two nits, and none blocks the task. The
two minors (R-1, R-2) fit naturally into Task 2's M-Z43 and
M-Z34/M-Z35 fixtures. The controller should decide whether to fold them
in there or fix them now.

## Spec conformance (paths under `packages/jet_cad_floor_plan/lib/src/`)

| Decision | Where | Finding |
|---|---|---|
| **Z0** one candidate rule | `service/table_picker.dart:103` `TableCandidate`; `:233` `candidatesOf`; `:242` visible layer; `:245` determinant; `:248` empty box; `:250-261` four transformed corners, `every isFinite`; `:207-223` `_build` maps it to `PickCandidate` with a memoised `scan()` (`:211`) | Conforms. The picker and the framing share the rule; the veil is Task 2's. The design mode passes a fresh `boxes: {}` and `document.leavesByOwner` (`host/floor_plan_controller.dart:382-383`). TP12 (one scan per build) is still green, and my R-O9 shows it still guards the memo. |
| **Z1** `bool fitToTables(Set<String>)` | `floor_plan_controller.dart:934-945` | Conforms. The numbers are trimmed with blanks dropped, copied into an unmodifiable set (`:935-938`), and checked against the active plan now (`:939`). The survey excludes nested instances (F-7). Hidden-layer tables are excluded and locked ones included (CZ2). |
| **Z2** four-corner bound | `table_picker.dart:129-139` `worldBounds`; `floor_plan_controller.dart:379-387` | Conforms. The union of the corners' axis-aligned bounds. |
| **Z3** `frameTables` | `host/table_fit.dart:14, 18, 26-55` | Conforms. Margin, then minimum span about the centre, then `ViewportTransform.fit`, then a clamp about the same centre with y flipped. The clamp's `mx, my` equal `cx, cy` because the margin is symmetric. See R-1 for the far edge of the double range. |
| **Z4** none found | `:939` returns before any write | Conforms. CZ5 covers the request, camera and flag; VZ8 covers the earlier pending request. |
| **Z5** target, last request wins | `:217` `_fitTarget`; `:906-910` `fitToView` nulls it; `:940-943` | Conforms. `fitted()` (`:360`) keeps the target. That is harmless: every fit that reads the target comes from a request that has just set it, or from `_fitOnStart`, which only `_replaceDesign` sets, and `_replaceDesign` also nulls the target. |
| **Z6** resolved when performed | `:369-374` `framingFor`, called from `planner_view.dart:181` | Conforms. It falls back to the page and `fitted()` still runs (VZ9). |
| **Z7** seam, size read when performed | `planner_view.dart:99`, `:163-173` (`_fit(_size!)`), `:178-186`; `planner_shell.dart:93, 156, 984`; `host/floor_plan_view.dart:233`; `host/service_view.dart:404` | Conforms. `_size` is only ever set to a non-zero size (`:221-223`), so the `!` is safe and a zero viewport never reaches `framingFor`. `apps/floor_planner` is untouched and passes no framing. |
| **Z8** load/newPlan reset; setMode, resetLayout and restore keep | `:655-657` in `_replaceDesign`. `setMode` (`:670`), `resetLayout` (`:692`) and `restoreServiceLayout` (`:549`) have no hunk in the diff. | Conforms. |
| **Z9** not document state | `:934-945` | Conforms: no settle, notify, command, revision or layout bump (CZ6). |

### The two recorded deviations

- **M-Z32's fixture: accepted.** `newPlan` is empty, so with the spec's
  literal killer Z6's page fallback makes the mutant equivalent. I
  reproduced this. With the mutant applied (the reset moved into `load`
  only), committed VZ2 goes **red**: `Expected … 0.0573…, Actual
  0.2634…`. With VZ2's `placeZoneTable(…'3'…)` line also removed, the
  spec's literal killer, it goes **green**: `+1: All tests passed!`.
  Placing a table 3 in the new plan is the only way to observe the
  mutant.
- **VZ10 strengthened: accepted.** I truncated VZ10 after its first half
  (the spec's killer) and removed the `!mounted` guard. The test was
  **green** (`+1: All tests passed!`), as the report says: the new view
  fits on its first frame anyway. With the second half present (a view
  unmounted in the step that asks), the full VZ10 goes **red**:
  `Expected … 0.10909…, Actual 0.06788…`. Both files were restored and
  checked with `cmp` (exit 0).

## Behaviour unchanged elsewhere

- **`table_picker_test.dart`:** `git diff -U0 d0e510e ba7eec2` has no `-`
  line, only one hunk `@@ -421,0 +422,24 @@` (TP13). It is additions only.
- **Other test files:** the only removed line in any test file is
  `controller_test.dart:8`, where `import 'dart:ui' show Color;` became
  `show Color, Size;`. That widens an import and changes no test body.
  The report records it. Every other hunk is an addition.
- **`fitToView`, `load`, `newPlan`, `setMode`:** in the controller, the
  diff touches only `fitToView` (one added line, `_fitTarget = null`) and
  `_replaceDesign` (the reset, `:655-657`), plus doc comments. `load` and
  `newPlan` reach the reset through `_replaceDesign`, and `setMode`
  (R-13's `_reframe`) has no hunk.
- **V-7, the size read when performed:** this now also applies to
  `fitToView`. A `fitToView` asked in the same step as a layout change
  fits the new size instead of the old one, as Z7 intends. No existing
  test changed. The full planner (1403), floor planner (212) and demo (37)
  suites pass unedited. The engine and the renderer have zero diff
  (`git diff d0e510e ba7eec2 -- packages/jet_cad_2d packages/jet_cad_2d_flutter apps tool | wc -l` prints `0`).

## Correctness hunt

- **Framing before the first frame.** With no view mounted,
  `_fitPending` plus the target make the first view frame the tables
  (VZ1). With a view mounted but not laid out, `_size == null` resets the
  first-layout latch, and the first-layout `_fit` goes through `framing`
  (my R-O14 kills VZ1, VZ3, VZ6, VZ8 and VZ10 when that path skips the
  framing).
- **During a mode switch.** The request comes from a mounted view and
  posts callback A. During the frame's build, `FloorPlanView` registers
  the measurement M before the new view's first-layout fit F. A returns on
  `!mounted`, M corrects the camera, and F frames last. This holds in both
  directions (VZ6, VZ10). M-Z14 and M-Z33 are confirmed above.
- **Two requests in one frame.** Two posted fits both read the current
  target, so the last request wins and `fitted()` simply runs twice
  (VZ4). My R-O11 (`fitted()` also nulls the target) is killed by VZ4 for
  exactly this reason.
- **A request, then `load`, in the same step.** The old shell is keyed
  out (`ObjectKey(document)`), so its posted fit returns on `!mounted`.
  The new view takes `_fitOnStart`, and the target is null, so it fits
  the page. With no view mounted, the result is the same (VZ2).
- **Dispose with a request pending.** A disposed view returns on
  `!mounted`. Disposing the controller while a view is still mounted is
  as unsafe as it was before this change (`fitToView` has the same
  path). Nothing new here.
- **Rotated and mirrored tables.** The corners are computed through the
  full affine transform. CZ1 (turned 37° and mirrored, 40 m off the
  origin) kills a swapped `b`/`c` (R-O3) and a skipped corner (R-O4).
- **Hidden and locked layers.** CZ2 kills both M-Z2 and M-Z40. VZ9 hides
  the layer between the request and the fit and gets the page.
- **Non-finite corners.** TP13 covers a NaN translation, an overflowing
  corner with a finite determinant, and a singular transform. It kills
  `any` in place of `every` (R-O8). **Gap:** corners that are finite but
  close to the double range still produce an infinite camera (R-1).
- **Zero-size viewport.** This cannot reach `framingFor`, because
  `_size` is only set when both sides are greater than 0. When called
  directly, `frameTables(box, Size.zero)` returns scale 1.0 (probed:
  `[1.0, 0.0, 0.0, -1.0, -40500.0, -26500.0]`) and does not throw.
- **The zoom clamp.** TF4 covers both bounds and the centre; R-O13
  (flip lost in the clamp branch) is red.
- **Allocation.** `framingFor` is referenced only from `PlannerView._fit`
  (`planner_view.dart:181`). That runs from a post-frame callback per
  request or from the one-shot first-layout fit, never from a paint. The
  picker's `_build` now allocates a `TableCandidate` and a
  `Float64List(8)` per candidate. That happens at the picker's existing
  rebuild rate (state id or layer revision), not per frame. The paint
  allocation invariant is untouched and green, inside the render
  package's standing comparison.

## Findings

**R-1 — minor — `host/table_fit.dart:29-31, 46-54` with
`service/table_picker.dart:261`: a framing near the double range gives an
infinite camera.**
- Failure scenario: a hand-edited file places a table at
  `e = 1.7e308`. Its four corners are finite, so Z0 keeps it, and a host
  frames its number. `cx = (minX + maxX) / 2` overflows to infinity. The
  span check then gives a NaN width, `ViewportTransform.fit` falls back
  to scale 1, and the camera's translation is `-Infinity`. Probed:
  `frameTables(Aabb2.raw(1.7e308, -1000, 1.7e308, 1000), Size(1000, 700))`
  returns `[1.0, 0.0, 0.0, -1.0, -Infinity, 350.0]`. The canvas goes blank
  and every later camera operation is poisoned.
- Why it matters: Z0's own comment says a non-finite corner "would
  poison a framing's bound". This is the same poisoning, reached from
  finite corners.
- Fix: in `framingFor`, return null (the page) when any coefficient of
  `frameTables`' result is not finite, or compute the centres as
  `minX / 2 + maxX / 2`. Add a table at `e = 1.7e308` to Task 2's M-Z43
  fixture: framing returns false or fits the page, and nothing throws.
  `ViewportTransform.fit` (the engine) does the same arithmetic for
  `fitToView` and is out of scope.

**R-2 — minor (test gap) — `host/floor_plan_controller.dart:935-940`: the
target's trimming and copying have no killer at Task 1.**
- My R-O1 (no trimming) and R-O2 (`_fitTarget = numbers`, aliased and
  untrimmed) both survive all of CZ1–CZ6 and VZ1–VZ11.
- Failure scenario: a host passes its zone set and then reuses it (for
  example, it clears it for the next query) before the pending framing
  is performed. If the copy is removed, the framing finds nothing and
  fits the page.
- The plan assigns M-Z34's framing half (`{' 3 ', ''}` frames 3) to Task
  2, and that would kill R-O1 and R-O2's trimming. No named mutant covers
  aliasing of the fit target; M-Z35 is the focus's.
- Fix: in Task 2, beside M-Z34 and M-Z35, add a fit-target clause. With
  no view mounted, call `fitToTables(s)`, then `s.clear()`, then mount:
  table 3 is framed.

**R-3 — nit (fixture) — `test/host/zone_fixture.dart`: the zone plan has
no page.**
- Probed: `PageNotifier(c.activeDocument).value` is `null`. So in every
  VZ test "the page" is the extents fit, which no real host plan uses.
- Framing taking precedence over a real page is pinned only by SM3 on
  `startupPlan`. My R-O10 (framing consulted only when there is no page)
  survives VZ5 and VZ7 and is killed by SM3 alone.
- Nothing survives overall, so no change is required. If Task 2 or 3
  touches the fixture, giving the zone plan a page would remove this
  degenerate default.

**R-4 — nit (docs) — `host/floor_plan_controller.dart:916-917`.**
- The doc comment says "a servable instance inside a group never
  matches". In this API, "group" also names table groups (merged tables,
  `selectedGroup`), and their members do match.
- Fix: say "a servable instance nested in another block (not at the
  root) never matches".

## Mutants

Each mutant was applied in `/tmp/zone-t1-review/mut` by exact string
replacement (a script that asserts exactly one match), then the named
tests were run with `--plain-name` and a JSON reporter. The file was
restored from a scratch copy, and both `cmp` and `git diff --quiet` exited
0 after every mutant. "Red" means the run's JSON reported a test failing
with "The following TestFailure was thrown", or a failed `expect`, and
never a compile error.

### Assigned, re-run (15)

| Mutant | Applied | Killer | Result |
|---|---|---|---|
| M-Z2 | `candidatesOf` drops the visible-layer check | CZ2 | red (`Expected: false, Actual: <true>`) |
| M-Z3a | the box at the identity (`c.box`) | CZ1 | red |
| M-Z4b | no clamp | TF4 | red (`Expected: <100.0>`) |
| M-Z5a | margin 0 | CZ3, TF2 | red, red |
| M-Z7a | `_fits.bump()` before the none-found return | CZ5 | red |
| M-Z9 | the reset kept for `newPlan` only (`if (unsettled)`) | VZ2 | red (`Expected … 0.02215…, Actual 0.26346…`) |
| M-Z12a | `fitToView` keeps the target | VZ4 | red |
| M-Z15b | `FloorPlanView` passes no `framingFor` | VZ7 | red |
| M-Z30a | the target set before the none-found check | VZ8 | red |
| M-Z31c (broad) | the view keeps the old camera whenever `framing` answers null | VZ9 | red, but at `pageFit`'s premise (the mutant also breaks `fitToView`) |
| M-Z31c (precise) | `framingFor` returns `camera.value` when nothing matches | VZ9 | red (`Expected … 0.02215…, Actual 0.37`) |
| M-Z32 | the reset moved into `load` only | VZ2 | red. Green with the spec's literal killer (see the deviations above). |
| M-Z33a | `!mounted` guard removed | VZ10 | red. Green with the spec's half alone (see the deviations above). |
| M-Z40 | locked candidates skipped by the framing | CZ2 | red |
| M-Z41 | size captured at the request (the old `_onFitRequest`) | VZ11 | red (`Expected … -10337.67, Actual -10122.67`) |

### My own, aimed at gaps (15 runs, 14 mutants)

| Mutant | Applied | Ran | Result |
|---|---|---|---|
| R-O1 | request not trimmed (`if (n.isNotEmpty) n`) | all CZ, all VZ | **survives**. Owed by Task 2's M-Z34 (R-2). |
| R-O2 | `_fitTarget = numbers` (aliased, untrimmed) | all CZ, all VZ | **survives** (R-2) |
| R-O3 | corner formula with `b`/`c` swapped | CZ1 | red |
| R-O4 | `worldBounds` skips corner 1 | all CZ, all VZ | red (CZ1–3, 9 VZ) |
| R-O5 | margin dropped while reordering (malformed: equal to M-Z5a on TF1) | TF1 | survives TF1 alone; superseded by R-O5b |
| R-O5b | minimum span before the margin (order swapped) | TF1–4, CZ3 | red (TF1, TF3); CZ3 green |
| R-O6 | `framingFor` reads `_design`, not `_active` | all CZ, all VZ | red (VZ3) |
| R-O7 | no union: the last table wins | CZ4, CZ3 | red, red |
| R-O8 | the corner check with `any` instead of `every` | TP13 | red |
| R-O9 | picker `scan()` not memoised | TP12 | red (`Expected: <1>`) |
| R-O10 | framing consulted only when there is no page | VZ7, VZ5 / SM3 | VZ7 and VZ5 **survive** (R-3); SM3 red |
| R-O11 | `fitted()` also nulls the target | all CZ, VZ, SM3 | red (VZ4: two requests in one frame) |
| R-O12 | minimum span grown in x only | all TF, CZ, VZ | red (TF1) |
| R-O13 | clamp branch loses the y flip | TF4 | red |
| R-O14 | first-layout fit ignores the framing | all VZ | red (VZ1, VZ3, VZ6, VZ8, VZ10) |

## Gates (real output, run at `ba7eec2` in `/tmp/zone-t1-review/repo`)

**Planner** (`packages/jet_cad_floor_plan`):
```
$ flutter test --file-reporter json:/tmp/zone-t1-review/out/planner.json
03:33 +1403: All tests passed!
test runner exit 0
$ dart run tool/ci/expect_failures.dart --package packages/jet_cad_floor_plan --root packages/jet_cad_floor_plan /tmp/zone-t1-review/out/planner.json
packages/jet_cad_floor_plan: 1403 tests; the standing failures and skips, exactly
expect_failures exit 0
$ flutter analyze
Analyzing jet_cad_floor_plan...
No issues found! (ran in 6.7s)
analyze exit 0
$ dart format --output=none --set-exit-if-changed .
Formatted 240 files (0 changed) in 0.89 seconds.
format exit 0
```

**Demo** (`apps/restaurant_demo`):
```
00:20 +37: All tests passed!
test runner exit 0
apps/restaurant_demo: 37 tests; the standing failures and skips, exactly
expect_failures exit 0
Analyzing restaurant_demo...
No issues found! (ran in 3.6s)
analyze exit 0
Formatted 4 files (0 changed) in 0.05 seconds.
format exit 0
```

**Floor planner** (`apps/floor_planner`, the plan's gate):
```
01:27 +212: All tests passed!
test runner exit 0
apps/floor_planner: 212 tests; the standing failures and skips, exactly
expect_failures exit 0
Analyzing floor_planner...
No issues found! (ran in 4.0s)
analyze exit 0
Formatted 47 files (0 changed) in 0.16 seconds.
format exit 0
```

**Engine and render, through the standing comparison** (zero diff in
both packages):
```
packages/jet_cad_2d:      00:17 +1253 -2: Some tests failed.   test runner exit 1
packages/jet_cad_2d: 1255 tests; the standing failures and skips, exactly
expect_failures exit 0
packages/jet_cad_2d_flutter: 01:03 +1355 ~1 -7: Some tests failed.   test runner exit 1
packages/jet_cad_2d_flutter: 1363 tests; the standing failures and skips, exactly
expect_failures exit 0
```

## The report, checked

- Its file:line references match the tree, to within a line:
  `table_picker.dart:260` is `:261`, and `fitToView` `:905` is `:906`.
- Its test counts match mine: 1403, 212 and 37, with engine 1255 and
  render 1363 exact.
- Its claim that existing tests are unedited matches the diff (one import
  widened, recorded).
- Its M-Z32 and M-Z33a deviations reproduce exactly as described.
- One stale sentence: "Nothing is committed". It was written before the
  controller committed `ba7eec2`.
