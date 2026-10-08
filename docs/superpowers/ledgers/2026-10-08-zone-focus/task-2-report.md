# Task 2 report — the focus and the veil (Z10–Z13, Z15–Z17)

This is the implementer's report. The work is on branch `claude/exciting-pasteur-9m22jv`, base `ba7eec2`, which holds Task 1. Nothing is committed: every change is in the working tree. The report also folds in the three Task 1 review fixes the coordinator forwarded (R-1, R-2, R-4); see "Task 1 review fixes".

## What was built

All paths are under `packages/jet_cad_floor_plan/`.

### Z10: the focus on the controller (`lib/src/host/floor_plan_controller.dart`)

- `:86` `_Focus` is a `ChangeNotifier implements ValueListenable<Set<String>?>`. Its `replace` notifies on every call, including an equal set or a second null. A plain `ValueNotifier` would stay silent on null → null.
- `:251` `_focus`.
- `:312` `ValueListenable<Set<String>?> get tableFocus`.
- `:324` `void setTableFocus(Set<String>? numbers)`:
  - null means no focus;
  - otherwise each number is trimmed, blanks are dropped, and the result is copied into `Set.unmodifiable`, so `{}` and `{''}` are a focus with no table.
  - It makes no settle, command, `revision`, `dirty`, `serviceLayoutChanges` change or controller notification.
- `:1062` the focus is disposed with the controller.
- Nothing in `setMode`, `load`, `newPlan`, `resetLayout` or `restoreServiceLayout` touches it, so it is kept for the controller's life, by number.

### Z12, Z13, Z16, Z17: `lib/src/service/table_focus_painter.dart` (new)

- `:17` `kTableFocusVeilAlpha = 0.6`.
- `:40` `TableFocusPainter(document, camera, focus, paper, repaint)`.
- `:82` `_rebuild` takes Z0's candidates (`TablePicker.candidatesOf`, with the painter's own box cache).
  - A candidate whose number is in the focus goes to the kept path. Every other candidate goes to the faded path: unnumbered and locked tables fade, and hidden tables are no candidates.
  - `:105` `_addQuad` adds the four world corners, reversed when the determinant is negative, so every quad winds counter-clockwise. Both paths are non-zero.
  - `:101` there is one `Path.combine(PathOperation.difference, faded, kept)` per rebuild.
  - With a null focus nothing is built. With no faded quad there is no region.
- `:123` `paint`:
  - It rebuilds when the state id, the tables' `mutationRevision` or the focus identity moves.
  - `:140` a paper change only recolours the one `Paint`: `Color(paperArgb).withValues(alpha: 0.6)`, which replaces the paper's own alpha.
  - Each frame writes the camera into the one reused `Float64List(16)` and makes one `save/transform/drawPath/restore` call with the same `Path` and `Paint`. A degenerate camera draws nothing.
- `debugAllocations` counts the paint, the matrix and every `Path`; there is also `debugRebuilds`.
- Z17: the paths are in world millimetres under the camera matrix, as the group frames are.

### Z11 and Z13's wiring (`lib/src/host/service_view.dart`)

- `:221` `_focusPainter`. Its repaint is `Listenable.merge([camera, tableFocus, _changed, _paper])`.
- `:442` the overlay is now a `Stack`: the veil (`CustomPaint` keyed `table-focus-layer`, `:447`), then the existing chips (`table-group-chips`). Each sits in its own `RepaintBoundary`. The veil is above the drafting and under the chips and the selection outlines.
- Only `ServiceView` has the veil. The design mode and the shell are unchanged.

### Z15: no change

The tool, the picker, `select` and Merge are untouched. VF5 proves the behaviour.

### Group painter and `FloorPlanTable.visible`

These are Task 3's and are not touched.

## Tests

### Shared helpers

`test/host/zone_fixture.dart` (Task 1's file; additions only):

- `:178` `TestQuad`: the test's own quad, the symbol box through the transform, with a signed distance.
- `:211` `quadsOf` and `quadsNumbered`.
- `:223` `veilOver`, the paper at 0.6 over a colour.
- `:260` `checkVeil`, a whole-image check:
  - a pixel inside a faded quad and outside every focused quad, by more than 1.5 px, must be the paper at 0.6 over the scene below it (±1 per channel);
  - a pixel inside a focused quad, or outside every faded quad, must equal the scene exactly;
  - pixels at edges are skipped;
  - named regions are counted, to make each premise visible.

The scene below is either a flat colour (painter tests) or a shot of the same view without the focus (view tests).

### `test/service/table_focus_painter_test.dart` (new)

It uses the zone fixture decoded, plus a cluster about 41 m off the origin:
- F: the trapezoid, turned;
- G: the trapezoid, turned and mirrored, over F's corner;
- H: the rectangle, over G.

The camera is set at 0.37 px/mm, panned and off the pixel grid. Pixels are read back from a `PictureRecorder` under `runAsync`.

| Test | Line | What it checks |
|---|---|---|
| FP1 | `:126` | Whole-image check, with region premises (each asserted over 200 checked pixels; seen 25,000 to 113,000): F over G is clear; G outside F but inside F's AABB is veiled; G over H outside F is veiled; G's AABB outside every quad is clear; G's box at its translation only, outside every quad, is clear. |
| FP2 | `:175` | Focus {3}: the unnumbered and the locked table are veiled, hidden 5's box is clear, 3 is clear. Each is shot on its own. Then `{}` and `{''}` veil 3. |
| FP3 | `:222` | N = 60 (`rowOfTables`), half focused, on 14c R-3's `SpyCanvas`. After three warm frames, each frame passes exactly `[matrix, path, paint]`, identical across a pan and a zoom. The buffer holds each frame's camera. `debugAllocations` and `debugRebuilds` are steady. |
| FP4 | `:260` | A null focus builds and draws nothing (allocations = 2). Every table focused draws nothing. |
| FP5 | `:280` | The veil uses the paper's RGB: `kPaper`, `kDarkCanvasPaper`, alpha-0 and alpha-0x80 papers each give their RGB at 0.6. A paper change rebuilds nothing, and the `Path` is identical. |
| FP6 | `:313` | 7 moved by command: the veil follows. Undo: it follows back. Layer `L` hidden by a direct table edit (no command; `stateId` unchanged, `mutationRevision` moved): no veil there. |

### `test/host/controller_test.dart` (additions only, plus one new import line)

| Test | Line | What it checks |
|---|---|---|
| CF1 | `:692` | Trimming and blanks. `{}`, `{''}` and `{' ', ''}` are empty, not null. The set is unmodifiable. Every call notifies (7 calls, 7 notifications). |
| CF2 | `:721` | The host's set is copied. |
| CF3 | `:733` | The focus is the identical set after `setMode`, `resetLayout`, `restoreServiceLayout`, `load`, `newPlan` and back. |
| CF4 | `:758` | I-2: json, dirty, undo depth, canRedo, revision, controller notification, layout change and settle, in both modes. |
| CF5 | `:799` | The focus is disposed with the controller. |

### `test/host/view_test.dart` (additions only, plus new import lines)

The fixture is the zone fixture with a White page. The real seed themes come from `palette_fixture`. The window is 1440 × 900 at device pixel ratio 1.

| Test | Line | What it checks |
|---|---|---|
| VF1 | `:1285` | Design mode: no `table-focus-layer`, and the whole canvas is pixel-identical before and after `setTableFocus` (table 3 is on it). The selection mode has the layer. |
| VF2 | `:1312` | The veil painter's listener fires on each `setTableFocus`, including an equal set and null. |
| VF3 light / dark | `:1336` | Statuses on 7 (faded) and 3 (focused): the whole-canvas check. At a sample on 7's top, the scene is the status and the shot is `veilOver(paper, status)`; 3's sample is the status alone. The dark run's paper is `kDarkCanvasPaper`. |
| VF4 | `:1381` | The focus is set in the design and drawn after the switch. Then a `load` where 3 and 7 swapped labels (premise: 7 is the old 3's instance): the veil follows the number. |
| VF5 | `:1437` | With 7 focused, faded 3: a mouse tap gives `onTableTap('3')` and selects it; a drag moves it by the screen delta (`onLayoutChanged` once); `select({'3','A1'})`; `setTableFocus({})` keeps the selection; Merge is enabled and reports `{3, A1}`. |
| VF6 | `:1499` | Selection mode, service copy: A1 gets a NaN translation, A2 a singular transform, B4 `e = 1.7e308`. `fitToTables` gives false for A1 and for A2. `{A1, A2, 3}` frames 3 alone, performed at the canvas (`expectFramed`). The picker's candidates skip A1 and A2. The focus `{}` veils 3 with nothing thrown. Then, with the view unmounted, the same in the design mode. The R-1 clauses are under "Task 1 review fixes". |
| VZ12 | `:1586` | R-2 and M-Z34's framing half: `fitToTables({' 3 ', ''})`, then the host clears the set, then mount: 3 is framed. |
| VF7 | `:1599` | `{' 7 '}` leaves 7 clear. A clean host set changed after the call, followed by an off-canvas move that rebuilds the veil, leaves 3 still veiled. `{''}` veils 7. |

## Mutants

The method:
1. A scratch script applies each mutant by exact string replacements. Each anchor must occur exactly once.
2. It runs each killer with `--plain-name` and a JSON file reporter, and classifies the failure from the reporter's `error` and `print` events.
3. It restores each file from a snapshot taken before any mutation and checks it with `cmp`.

Every restore was confirmed with `cmp` (exit 0); the log has 49 restore lines, all `cmp=0`. After the last restore, each of the six source files was compared with its snapshot (all identical) before the gates ran. Every red result below is a `TestFailure` (`failure` for the plain `test`s), never a compile error or a crash.

| Mutant | What was applied | Killer | Result |
|---|---|---|---|
| M-Z16 | `FloorPlanView`'s design branch wrapped in a `Stack` with a veil `CustomPaint` (keyed) over the shell | VF1 | red |
| M-Z16b (extra) | the same, unkeyed, so only the pixel half can see it | VF1 | red |
| M-Z17a | no subtraction (`_region = faded`) | FP1 | red |
| M-Z17b | the focused quads subtracted as their axis-aligned world bounds | FP1 | red |
| M-Z18a | the veil at the box at the identity | FP1 | red |
| M-Z18b | the box moved by the translation only | FP1 | red |
| M-Z18c | the world axis-aligned bound | FP1 | red |
| M-Z18d | mirrored quads not reversed | FP1 | red |
| M-Z19 | unnumbered tables not faded | FP2 | red |
| M-Z39a | locked tables not faded | FP2 | red |
| M-Z39b | hidden tables faded (the visible check dropped from `candidatesOf`) | FP2 | red |
| M-Z20a | focus cleared in `_replaceDesign` (load, newPlan) | CF3, VF4 | red, red |
| M-Z20b | cleared in `setMode` | CF3, VF4 | red, red |
| M-Z20c | cleared in `resetLayout` | CF3 | red |
| M-Z20d | cleared in `restoreServiceLayout` | CF3 | red |
| M-Z20e | kept by handle: the focused instances' handles carried across `_replaceDesign` and re-read as numbers | VF4 | red |
| M-Z21a | a new `Float64List(16)` per frame | FP3 | red |
| M-Z21b | a new `Paint` per frame | FP3 | red |
| M-Z21c | a rebuild every frame | FP3 | red |
| M-Z22a | `_select` drops numbers outside the focus | VF5 | red |
| M-Z22b | inert faded tables: a `TablePicker` subclass in `ServiceView` whose `pick` returns null outside the focus | VF5 | red |
| M-Z22c | `setTableFocus` prunes the selection to the focus | VF5 | red |
| M-Z22d | Merge enabled only when every selected number is focused | VF5 | red |
| M-Z23 | the veil moved into the underlay, under the status layer | VF3 light, VF3 dark | red, red |
| M-Z25a | paper ignored (White) | FP5; VF3 dark | red; red (VF3 light survives: its paper is White, as expected) |
| M-Z25b | the paper's alpha used (`a × 0.6`) | FP5 | red |
| M-Z25c | a paper change rebuilds the path | FP5 | red |
| M-Z26 | an empty focus (after trimming) read as null | CF1, VF7 | red, red |
| M-Z27a | `notifyListeners()` in `setTableFocus` | CF4 | red |
| M-Z27b | `_revision.value++` | CF4 | red |
| M-Z27c | `_layoutChanges.bump()` | CF4 | red |
| M-Z27d | `_settle?.call()` | CF4 | red |
| M-Z34a | focus numbers not trimmed | CF1, VF7 | red, red |
| M-Z34b | blanks kept (`n.trim()` for every n) | CF1 | red |
| M-Z34c (framing half) | `fitToTables` numbers not trimmed | VZ12 | red |
| M-Z35 | aliasing: an already-clean host set kept as an `UnmodifiableSetView` | CF2, VF7 | red, red |
| M-Z36 | `tableFocus` dropped from the veil's repaint merge | VF2 | red |
| M-Z37a | rebuild keyed on the focus only | FP6 | red |
| M-Z37b | key without the tables' revision | FP6 | red |
| M-Z37c | key without the state id | FP6 | red |
| M-Z43 | the four-finite-corners check removed from `candidatesOf` | VF6 | red |
| M-R1a | R-1 undone whole: `(min + max) / 2` centres and no finite guard in `framingFor` | VF6 | red |
| M-R1b | the finite guard alone removed | VF6 | red |
| M-R1c | the overflow-safe centre alone undone | VF6 | red (the first run crashed on a `!`; the test now `expect`s non-null first, and the re-run is a `TestFailure`) |
| M-R2 | `_fitTarget = numbers` (aliased) | VZ12 | red |
| extra | a null focus treated as `{}` | FP4 | red |
| extra | `_focus.dispose()` removed | CF5 | red |

All 17 of Task 2's mutants (M-Z16–M-Z23, M-Z25–M-Z27, M-Z34–M-Z37, M-Z39, M-Z43) went red. So did the review's M-R1a/b/c and M-R2, and the two extras. None survived.

## Task 1 review fixes

- **R-1** (`lib/src/host/table_fit.dart`):
  - `:34` the centre is `minX / 2 + maxX / 2` (and y the same). Halving is exact, so elsewhere this is the same number as before, and TF1–TF4 are unchanged and green.
  - `:45-51` `frameTables` takes only the scale from `ViewportTransform.fit` and builds the translation itself about the safe centre. `ViewportTransform.fit` takes `(min + max) / 2` and lives in the renderer, which is not edited. The clamp branch now shares that construction.
  - `floor_plan_controller.dart:413-422` `framingFor` returns null, so the page fits, when any coefficient is not finite.
  - The test is in VF6 (the M-Z43 fixture):
    - B4 at `e = 1.7e308` (four finite corners) gives `fitToTables` true;
    - `framingFor(1200 × 900)` is non-null and finite, and equals `frameTables` on the test's bound;
    - `framingFor(Size(double.infinity, 900))` is null.
  - Mutants M-R1a, M-R1b and M-R1c (above).
- **R-2:** VZ12 (`view_test.dart:1586`), with no view mounted: `fitToTables(s)` where `s = {' 3 ', ''}`, then `s.clear()`, then mount: 3 is framed. Mutant M-R2 (`_fitTarget = numbers`) is red, and so is M-Z34c (untrimmed).
- **R-4:** `floor_plan_controller.dart:966` now says "a servable instance nested in another block never matches".

## Deviations and notes

- **`_Focus` instead of a `ValueNotifier`.** Z10 says that every call notifies, an equal set included. A `ValueNotifier` would not notify null → null, so a small notifier is used. CF1 pins this.
- **Some test files changed outside their own new tests:**
  - `controller_test.dart` gains one new import line (`flutter/foundation.dart show ChangeNotifier`, for CF5). `view_test.dart` gains new import lines (`palette_fixture`, `catalog`, `table_picker`, `table_label`). No existing line was edited: `git diff -U0` shows no removed line in either file.
  - `zone_fixture.dart` (Task 1's new file) gains `dart:math` and the helpers listed above, with no removed line.
- **The veil's colour is not written `Color(0xFF000000 | rgb)`.** That literal trips `test/invariants/theme_colours_test.dart` (D9a). `Color(paper).withValues(alpha: 0.6)` replaces the alpha, which has the same effect; FP5 checks it with alpha-0 and alpha-0x80 papers.
- **Its own box cache.** The painter calls `candidatesOf` with its own box cache, rather than sharing the `ServiceView` picker's. That is one `leavesByOwner` scan per definition for the painter's life. The picker is untouched (Z15).
- **The view tests and the 0.37 px/mm camera.** Every view test sets a panned camera off the pixel grid before it shoots. Only VF5 shoots at 0.37 px/mm; the others use 0.25 px/mm, so that tables 3 and 7 (2.4 m apart) fit in one shot. The painter tests use 0.37 px/mm throughout, except for FP3's zoom frame.
- **A finding outside this task's scope: 1.7e308 in Skia.** A world coordinate of 1.7e308 is beyond float32 range. In VF6 the veil's `Path.combine` with B4's quad did not throw on the test engine, and the veil over 3 checked correctly. I did not test it on the web renderers.
- **The allocation bar.** It is measured structurally (FP3, 14c R-3's `SpyCanvas`), as the spec names. `paint_allocation_test` (the renderer's) and `query_allocation_test` (the engine's) are untouched and green in the gates below. The planner's own `test/invariants` (including `theme_colours_test`) run in the planner's full suite, which is green.

## Gates

All gates ran after the last restore, on the final tree. Each package ran `<runner> test --file-reporter json:<tmp>/<pkg>.json`, then from the repo root `dart run tool/ci/expect_failures.dart --package <pkg> --root <pkg> <json>`, then analyze and format. These are the outputs as printed (the runner's last line):

```
=== packages/jet_cad_floor_plan
test runner exit 0
03:28 +1423: All tests passed!
packages/jet_cad_floor_plan: 1423 tests; the standing failures and skips, exactly
expect_failures exit 0
No issues found! (ran in 3.6s)
analyze exit 0
Formatted 242 files (0 changed) in 0.84 seconds.
format exit 0
=== apps/floor_planner
test runner exit 0
01:21 +212: All tests passed!
apps/floor_planner: 212 tests; the standing failures and skips, exactly
expect_failures exit 0
No issues found! (ran in 3.5s)
analyze exit 0
Formatted 47 files (0 changed) in 0.17 seconds.
format exit 0
=== apps/restaurant_demo
test runner exit 0
00:19 +37: All tests passed!
apps/restaurant_demo: 37 tests; the standing failures and skips, exactly
expect_failures exit 0
No issues found! (ran in 3.5s)
analyze exit 0
Formatted 4 files (0 changed) in 0.04 seconds.
format exit 0
=== packages/jet_cad_2d
test runner exit 1
For example, 'dart test --chain-stack-traces'.
packages/jet_cad_2d: 1255 tests; the standing failures and skips, exactly
expect_failures exit 0
No issues found!
analyze exit 0
Formatted 169 files (0 changed) in 0.50 seconds.
format exit 0
=== packages/jet_cad_2d_flutter
test runner exit 1
  ... and 3 more
packages/jet_cad_2d_flutter: 1363 tests; the standing failures and skips, exactly
expect_failures exit 0
No issues found! (ran in 3.3s)
analyze exit 0
Formatted 221 files (0 changed) in 0.59 seconds.
format exit 0
```

- The planner has 1403 tests from Task 1 plus 20 new ones: FP1–FP6, CF1–CF5, VF1–VF7 with VF3 twice, and VZ12.
- The engine and render runners exit 1 because of their standing failures (engine 2, render 7 plus 1 skip). The comparison is the verdict, and it is exact for both.
- The engine was analyzed with `dart analyze --fatal-infos`.
- The engine and the renderer are untouched.

## `git status --short`

```
 M packages/jet_cad_floor_plan/lib/src/host/floor_plan_controller.dart
 M packages/jet_cad_floor_plan/lib/src/host/service_view.dart
 M packages/jet_cad_floor_plan/lib/src/host/table_fit.dart
 M packages/jet_cad_floor_plan/test/host/controller_test.dart
 M packages/jet_cad_floor_plan/test/host/view_test.dart
 M packages/jet_cad_floor_plan/test/host/zone_fixture.dart
?? packages/jet_cad_floor_plan/lib/src/service/table_focus_painter.dart
?? packages/jet_cad_floor_plan/test/service/table_focus_painter_test.dart
```

No `analysis_options.yaml` appears.
