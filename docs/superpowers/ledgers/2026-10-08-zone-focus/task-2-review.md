# Task 2 review — the focus and the veil (Z10–Z13, Z15–Z17), with Task 1's R-1, R-2 and R-4

This is an independent review of commit `fdc8918` (parent `ba7eec2`) on branch `claude/exciting-pasteur-9m22jv`.

I ran everything in my own clones, both at `fdc8918`:
- `/tmp/zone-t2-review/repo` for the gates;
- `/tmp/zone-t2-review/mut` for the mutants.

`git status --short` was empty in both after every run. Flutter came from `/root/sdk/flutter/bin` with `CI=true`. I committed nothing.

Unless a path says otherwise, it is under `packages/jet_cad_floor_plan/`.

## Verdict: **Approved, with fixes recommended (test gaps only)**

The code does what Z10–Z13 and Z15–Z17 say:
- the veil's region, winding, colour and rebuild key are correct;
- the paint order is correct;
- the frame path is O(1).

Task 1's R-1, R-2 and R-4 are fixed and pinned. No existing test line was edited: `git diff -U0 ba7eec2 fdc8918 -- test` has no removed line.

All 14 assigned mutants I re-ran went red with a `TestFailure`. Every gate is green, and the standing sets are exact.

There are no code defects. Three things the code gets right are pinned by no test:
- the veil repaints on a service move (`_changed`);
- the veil repaints on a paper change (`_paper`);
- the veil lies under the selection outlines.

I wrote a killing test for each one. All three are green on `fdc8918` and red under the matching mutant. Each is quoted in R-1–R-3 so it can be landed as-is. These are minor findings. They do not block the task, but they belong in it, because Z16 and Z13 state these properties. The rest are nits.

## Spec conformance

| Z | Where | Finding |
|---|---|---|
| **Z10** | `lib/src/host/floor_plan_controller.dart:86-97` `_Focus`; `:251`; `:312` `tableFocus`; `:324-331` `setTableFocus`; `:1062` dispose | **Conforms.** Each number is trimmed and blanks are dropped (`if (n.trim() case final t when t.isNotEmpty)`). The result is a `Set.unmodifiable` copy, so `{}` and `{''}` are a focus with no table. Every call notifies, including null → null; a `ValueNotifier` would not, which justifies `_Focus`. No settle, command, `revision`, `dirty`, layout change or controller notification happens (CF4). `setMode`, `load`, `newPlan`, `resetLayout` and `restoreServiceLayout` have no hunk, so the focus is kept for the controller's life (CF3, VF4). |
| **Z11** | `lib/src/host/service_view.dart:221-227, 442-460` | **Conforms.** Only `ServiceView` builds the veil. The design branch is untouched, which VF1 shows by key and by pixels. |
| **Z12** | `lib/src/service/table_focus_painter.dart:82-102` | **Conforms.** The painter runs Z0's `candidatesOf`, so hidden tables are no candidates. A table is kept only if `number != null && focused.contains(number)`; unnumbered and locked tables fade (FP2). |
| **Z13** | painter `:17` (0.6); `:105-121` quad CCW by the determinant's sign; `:101` one `Path.combine(difference)`; `:137-141` the paper's RGB at 0.6 | **Conforms.** Both paths are non-zero. Mirrored quads are reversed, so overlapping faded quads add up instead of cancelling: FP1's 'G over H' region kills both M-Z18d and my O9 (an even-odd faded path). The focused union is cut out exactly (M-Z17a/b). The overlay is a `Stack` holding the veil, then the chips (`service_view.dart:442-460`). |
| **Z15** | no hunk in the tool, picker, `select` or Merge | **Conforms.** The veil's `CustomPaint` sits under the topmost `SelectionOverlayPainter` in the `InteractionLayer`'s `Stack`, which is hit first, so hit-testing is unchanged. VF5 covers tap, drag, `select`, keep on a focus change and Merge. |
| **Z16** | painter `:123-160` | **Conforms.** The rebuild key is state id, `tables.mutationRevision` and the focus's identity. A paper change only recolours the paint (`:138-141`). Each frame writes one reused `Float64List(16)` and makes one `save/transform/drawPath/restore` call with the same `Path` and `Paint`. A null focus builds nothing: the constructor makes 2 allocations and `_rebuild(null)` returns early. The repaint merge is camera + `tableFocus` + `_changed` + `_paper` (`service_view.dart:226`), but only `tableFocus` is pinned (R-1, R-2). |
| **Z17** | world-mm paths under the camera matrix | **Conforms.** This is the same construction as the group frames. |

### The report's deviations

- **The colour written as `withValues(alpha: 0.6)`: accepted.**
  - `test/invariants/theme_colours_test.dart:30` bans `\bColor\(0[xX]` outside an allow-list, so `Color(0xFF000000 | rgb)` would go red there.
  - `withValues(alpha:)` replaces the alpha rather than multiplying it, so the effect is the same.
  - FP5 checks papers with alpha 0 and alpha 0x80. M-Z25b (alpha × 0.6) is red.
- **`frameTables` builds its own translation: accepted.**
  - It takes `ViewportTransform.fit`'s scale (`table_fit.dart:45-47`) and builds `w/2 − s·cx`, `h/2 + s·cy`.
  - That is the same formula as `jet_cad_2d_flutter/lib/src/viewport_transform.dart:27-47`, which lives in the renderer, and the renderer must not be edited.
  - `min/2 + max/2` equals `(min + max)/2` bit for bit outside the subnormal and overflow ranges: halving commutes with rounding.
  - TF1–TF4 are unchanged and green.
- **The test scales: accepted.**
  - The painter tests run at 0.37 px/mm, panned and off the pixel grid.
  - The view tests run at 0.25 px/mm, also panned and off the grid, so that tables 3 and 7 fit in one shot. VF5 runs at 0.37.
  - Nothing sits at the identity or the origin, so the degenerate-fixture concern the rule exists for does not apply.
- **`_Focus` instead of a `ValueNotifier`: accepted** (Z10, CF1; my O8 is red).

### The veil, checked

- **Winding:** correct for mirrored tables (FP1 premise `g.det < 0`; M-Z18d red).
  - The kept path also uses `_addQuad`, so it is correct too, but nothing pins that (R-4).
- **Overlaps:** a focused table is whole where a faded one overlaps it, and faded overlaps stay veiled (FP1 regions, each over 200 px).
- **Order, read from the code:** `planner_view.dart` paints in this order:
  1. the chrome;
  2. the underlay (frames, then statuses) at `:266`;
  3. `DraftCanvas` at `:268`;
  4. the overlay at `:275`, which is `Stack[veil, chips]`;
  5. `SelectionOverlayPainter` at `:280`.

  So the veil lies above the drafting and the status layer (VF3, M-Z23 red) and below the chips and the outlines. Those last two placements are untested (R-3).
- **Light and dark paper:** VF3 runs light and dark, and FP5 covers `kDarkCanvasPaper`.
- **Null focus:** FP4 shows that nothing is built or drawn.
- **Can the rebuild key go stale?** No, in every case I traced:
  - **A service move or an undo** changes `stateId`. `undo.dart:45-62` gives every new state a fresh id and an undo returns to the recorded one, so the key cannot alias. The move also bumps `_changed`, which repaints.
  - **A table moved in design, then a switch:** `setMode` builds a new copy (`floor_plan_controller.dart:726`). `ServiceView` is keyed `ObjectKey(document)` (`floor_plan_view.dart:206`), so a new state and a new painter result.
  - **`load`, `resetLayout` and `restoreServiceLayout`** also attach a new copy (`:621, 699, 748`), and so get a new painter. VF4 shows this for `load`.
  - **A layer hidden with no command** moves `mutationRevision` (FP6).
  - **The box cache** lasts for the painter's life, as in the group and status painters (14c R-8: a definition cannot change under `runtime`).

### Task 1's fixes

- **R-1:**
  - `table_fit.dart:34, 51` compute the overflow-safe centre.
  - `floor_plan_controller.dart:416-422` return null for a camera that is not finite.
  - VF6 covers both, with B4 at 1.7e308 and an infinite viewport. The report's M-R1a/b/c follow the code.
- **R-2:** VZ12 (`view_test.dart:1586`). The report's M-R2 is red.
- **R-4:** `floor_plan_controller.dart:966`.

## Allocation

**Per frame (`table_focus_painter.dart:123-160`):**
- The frame reads `stateId`, `mutationRevision` and `focus.value`, compares them with `identical`, reads `paper.value` and reads `camera.value.worldToScreenMatrix` (a field).
- It computes `math.sqrt` and writes 8 slots of `_matrix`.
- It makes one `drawPath` call with the prebuilt `_region` and `_paint`.
- `Color.withValues` runs only when the paper changes.

Nothing is allocated per table or per frame.

**Per rebuild:** 3 `Path`s plus one candidate list. That happens at document-change, focus or paper rate, never per frame.

**The test:** FP3 is the spec's named gate, 14c R-3's structural `SpyCanvas`. It runs with N = 60 tables and checks three warm frames, a pan and a zoom: the same matrix, path and paint objects every frame, a steady `debugAllocations` and a steady `debugRebuilds`. M-Z21a is red.

**What it cannot see:** per-entity work that never reaches the canvas and is not counted. My O11, a `candidatesOf` scan per frame, allocates a survey, a list and a `Float64List(8)` per table, and it survives FP3 (R-5).

**Should there be an allocation test, and how would 14c's painters be measured?** The engine already has the right tool, `AllocationMeter` (`jet_cad_2d/test/invariants/vm_allocation_meter.dart`, used by `query_allocation_test`). One test could drive the focus, status and group painters' `paint` on a `SpyCanvas`:
1. run it in steady state at N = 60 and N = 600;
2. assert that the per-frame allocation count of the classes that scale with tables (`TableCandidate`, `_List`, `Float64List`, `Path`, `Paint`) does not grow with N;
3. skip itself when the VM service cannot be reached, as the engine's tests do.

That belongs with 14c's painters as a follow-up, not in this task: Z16 names the structural gate, and `paint_allocation_test` stays untouched (I-1).

## Interaction (Z15)

- No hunk in `table_select_tool.dart`, `table_picker.dart`'s pick or `select`. The only change to `table_picker.dart` is Task 1's.
- VF5 kills the report's four interaction mutants.
- Existing tests are unchanged. The only additions to existing files are import lines (`controller_test.dart:10`, `view_test.dart:22-36`) and new tests at the end.

## Findings

**R-1 — minor (test gap) — `lib/src/host/service_view.dart:226`: nothing proves the veil repaints on a change to the copy.**
- **Mutant O1** (`_changed` dropped from the veil's merge) survives all of VF1–VF7. FP6 proves only that the painter rebuilds when it is painted, by direct `paint` calls; nothing proves it is asked to paint.
- **Failure scenario:**
  1. A waiter drags faded table 7, or presses Undo, in the selection mode.
  2. The table redraws at its new place, because `DraftCanvas` has its own boundary.
  3. The veil's `RepaintBoundary` is never marked, so a pale patch stays on empty floor and table 7 shows unfaded until the next pan or focus change.

  This is the M-Z37 behaviour ("move a faded table: the veil follows") through the real view.
- **Fix:** land this test in `test/host/view_test.dart`. It is green at `fdc8918` and red under O1:

```dart
  testWidgets('RV1 a service move of a faded table moves the veil',
      (tester) async {
    final c = paged();
    c.setMode(FloorPlanMode.selection);
    await mountFocus(tester, c);
    await aim(tester, c, midX, midY);
    c.setTableFocus({'3'});
    await tester.pump();
    final before = quad(c, '7');
    move(c, '7', 610.5, -455.25);
    await tester.pump();
    await tester.pump();
    final after = quad(c, '7');
    final got = await shoot(tester);
    c.setTableFocus(null);
    await tester.pump();
    final check = compare(tester, c, await shoot(tester), got,
        focus: {'3'},
        paper: white,
        regions: {
          'left': (x, y) => before.holds(x, y, 0) && !after.holds(x, y, 0),
          'reached': (x, y) => after.holds(x, y, 0) && !before.holds(x, y, 0),
        });
    expect(check.counts['left'] ?? 0, greaterThan(1000));
    expect(check.counts['reached'] ?? 0, greaterThan(1000));
  });
```

**R-2 — minor (test gap) — `lib/src/host/service_view.dart:226`: nothing proves the veil repaints on a paper change.**
- **Mutant O2** (`_paper` dropped from the merge) survives all of VF1–VF7. M-Z25's "a paper change recolours" is pinned only by FP5's direct `paint` calls.
- **Failure scenario:**
  1. The host switches the app to dark.
  2. `didChangeDependencies` sets `_paper` to `kDarkCanvasPaper`, and the drafting re-renders under the new resolver.
  3. The veil keeps painting the light paper at 0.6 on the dark canvas.

  A page background change goes through a command, so `_changed` hides this case. A theme switch does not.
- **Fix:** this test is green at `fdc8918` and red under O2:

```dart
  testWidgets('RV2 a theme switch recolours the veil with the new paper',
      (tester) async {
    final c = paged();
    c.setMode(FloorPlanMode.selection);
    await mountFocus(tester, c);
    await aim(tester, c, midX, midY);
    c.setTableFocus({'3'});
    await tester.pump();
    await pumpThemed(
        tester, Scaffold(body: FloorPlanView(controller: c)), ThemeMode.dark);
    await tester.pump();
    await tester.pump();
    final got = await shoot(tester);
    c.setTableFocus(null);
    await tester.pump();
    final seven = quad(c, '7');
    final check = compare(tester, c, await shoot(tester), got,
        focus: {'3'},
        paper: kDarkCanvasPaper,
        regions: {'7': (x, y) => seven.holds(x, y, 0)});
    expect(check.counts['7'] ?? 0, greaterThan(10000));
  });
```

**R-3 — minor (test gap) — `lib/src/host/service_view.dart:442-460`: the veil's place under the chips and the selection outlines is unpinned.**
- **Mutant O3** (the `Stack` swapped to chips, then veil) survives every VF test, because the zone fixture has no group.
- **Mutant O4** (the veil moved above `SelectionOverlayPainter`, in a `Stack` over `PlannerView`) also survives every VF test.
- Z13 states both placements: "under the chips and the selection outlines"; "Selection outlines stay above the veil".
- **Failure scenario:** a waiter selects a faded table to transfer it, and its selection outline is drawn at 40 %. A refactor of the layers would go unnoticed.
- **Fix, outlines:** this test is green at `fdc8918` and red under O4 (709 of the outline's opaque pixels changed):

```dart
  testWidgets('RV3 a selected faded table\'s outline lies above the veil',
      (tester) async {
    final c = paged();
    c.setMode(FloorPlanMode.selection);
    await mountFocus(tester, c);
    await aim(tester, c, midX, midY);
    final plain = await shoot(tester);
    c.select({'7'});
    await tester.pump();
    final selected = await shoot(tester);
    c.setTableFocus({'3'});
    await tester.pump();
    final both = await shoot(tester);
    final area = tester.getTopLeft(find.byType(InteractionLayer));
    final size = tester.getSize(find.byType(InteractionLayer));
    final counts = <int, int>{};
    for (var y = area.dy.toInt(); y < (area.dy + size.height).toInt(); y++) {
      for (var x = area.dx.toInt(); x < (area.dx + size.width).toInt(); x++) {
        final s = selected.rgbAt(x, y);
        if (s != plain.rgbAt(x, y)) counts[s] = (counts[s] ?? 0) + 1;
      }
    }
    // The outline's opaque colour: the commonest changed colour.
    final ink = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    var outline = 0, wrong = 0;
    for (var y = area.dy.toInt(); y < (area.dy + size.height).toInt(); y++) {
      for (var x = area.dx.toInt(); x < (area.dx + size.width).toInt(); x++) {
        if (selected.rgbAt(x, y) != ink || plain.rgbAt(x, y) == ink) continue;
        outline++;
        if (both.rgbAt(x, y) != ink) wrong++;
      }
    }
    expect(outline, greaterThan(200), reason: 'premise: an outline');
    expect(wrong, 0, reason: '$wrong of $outline outline pixels changed');
  });
```

  The test only checks the outline's opaque ink. A first version compared every changed pixel and went red on the real code: the outline's anti-aliased and translucent pixels legitimately differ over a veiled background.
- **Fix, chips:** hand this to Task 3. M-Z24's straddling-group clause ("normal frame, unveiled chip") must place that group's chip **over a faded member's quad**. Then the chips-under-veil order (O3) goes red there.

**R-4 — nit (test gap) — `lib/src/service/table_focus_painter.dart:92`: the kept path's winding is unpinned.**
- **Mutant O13** adds the focused quads with no reversal (`kept.addPolygon` by the transform's own order). It survives FP1–FP6 and VF1–VF7. FP1 focuses only F, so the kept path never holds two overlapping quads.
- **Failure scenario:** a mirrored focused table overlaps another focused table over a faded third one. With opposite windings, the focused union has a hole, and the triple overlap is veiled. The code is correct today, because `_addQuad` serves both paths.
- **Fix:** add a clause to FP1 with focus `{F, G}` (G is mirrored), where H covers part of F ∩ G. Pixels in F ∩ G ∩ H must stay clear.

**R-5 — nit — `test/service/table_focus_painter_test.dart:222` (FP3): the structural gate cannot see per-entity work that never reaches the canvas.**
- **Mutant O11** (a `candidatesOf` scan on every frame) survives FP3.
- This is inherent to 14c R-3's method, which the spec names. It is not this task's defect.
- **Fix (follow-up, not in this task):** the `AllocationMeter` test described under Allocation, covering the focus, status and group painters together.

**R-6 — nit — `lib/src/service/table_focus_painter.dart:144-145`: the degenerate-camera guard is untested.**
- **Mutant O10** (the guard removed) survives every FP and VF test.
- It is likely equivalent: every camera a fit produces is invertible, and Skia draws nothing under a singular matrix.
- Accept it, or add one FP4 clause: a zero-scale camera gives an empty `SpyCanvas`.

**R-7 — nit (risk note) — Z0's finite check is in doubles, while Skia stores paths in float32.**
- B4 at `e = 1.7e308` passes Z0 and goes into `Path.combine` (VF6). On the native test engine this neither threw nor disturbed the veil over 3, as the report says.
- The web renderers are untested: CanvasKit's `MakeFromOp` could fail on infinite floats, and Flutter would then throw.
- **Fix:** include a far table in R-1's web smoke check at the exit gate. If it throws there, the painter can skip quads whose corners exceed ±3.4e38.

## Mutants

**Method:**
1. A script (`/tmp/zone-t2-review/scripts/mut.py`) applies each mutant by exact replacement and asserts that each anchor occurs exactly once.
2. It runs the named tests with `--plain-name` and `--file-reporter json:`.
3. It classifies each result from the JSON. A load failure would read COMPILE/LOAD; none did. Every red below is a `TestFailure` (`isFailure`, or "The following TestFailure was thrown").
4. It restores each file from a scratch copy and checks it with `cmp`. Every restore printed `cmp=0`, and `git status --short` was `''` after each batch.

One batch was interrupted, and its files were restored with `git show HEAD:path > path` plus `cmp`. Every mutant in it was then run again from the start.

### Assigned, re-run (14)

| Mutant | Applied | Killer | Result (first expectation) |
|---|---|---|---|
| M-Z17a | `_region = faded` (no subtraction) | FP1 | red (`Expected: empty`, pixels wrong) |
| M-Z18d | mirrored quads not reversed (`det != 0`) | FP1 | red |
| M-Z19 | unnumbered tables skipped | FP2 | red |
| M-Z39a | locked tables skipped | FP2 | red |
| M-Z20b | `_focus.replace(null)` in `setMode` | CF3, VF4 | red (`same instance as {7}`, got null), red |
| M-Z21a | `Float64List(16)` per frame | FP3 | red (`item 0` not identical) |
| M-Z23 | the veil in the underlay, under the statuses | VF3 light and dark | red, red |
| M-Z25b | the paper's alpha used (`a × 0.6`) | FP5 | red |
| M-Z26 | an all-blank focus read as null | CF1, VF7 | red (`Expected: not null`), red |
| M-Z27a | `notifyListeners()` in `setTableFocus` | CF4 | red (`(0,0,1)` vs `(1,0,1)`) |
| M-Z35 | a clean host set aliased | CF2, VF7 | red (`{7,3}` vs `{3,A1}`), red |
| M-Z36 | `tableFocus` dropped from the veil's merge | VF2 | red (`<1>` vs `<0>`) |
| M-Z37a | rebuild keyed on the focus only | FP6 | red |
| M-Z43 | the four-finite-corners check removed | VF6 | red (`Expected: false, Actual: true`) |

### My own (13)

| # | Applied | Run against | Result |
|---|---|---|---|
| O1 | `_changed` dropped from the veil's merge | VF1–VF7 | **survives** → RV1 red (R-1) |
| O2 | `_paper` dropped from the veil's merge | VF1–VF7 | **survives** → RV2 red (R-2) |
| O3 | `Stack` order swapped (chips, then veil) | VF1–VF7 | **survives**, no group in the fixture (R-3, Task 3) |
| O4 | the veil above the selection outlines | VF1–VF7 | **survives** → RV3 red (R-3) |
| O5 | rebuild key without `mutationRevision` | FP6 | red |
| O6 | paper cache never refreshed (`_paperBuilt == null`) | FP1–FP6; VF3 | red (FP5); VF3 green, since each run has one paper |
| O7 | `_focus.dispose()` removed | CF5 | red |
| O8 | `_Focus` notifies only when `!=` (silences null → null) | CF1; VF2 | red (`<7>` vs `<6>`); VF2 green |
| O9 | faded path even-odd | FP1 | red |
| O10 | degenerate-camera guard removed | FP1–FP6, VF1–VF7 | survives (R-6, likely equivalent) |
| O11 | a `candidatesOf` scan per frame | FP3 | survives (R-5) |
| O12 | the focus copied with `Set.of` (modifiable) | CF1 | red (`throws UnsupportedError`) |
| O13 | focused quads added unreversed | FP1–FP6, VF1–VF7 | survives (R-4) |

### The review's own tests (RV1–RV3, appended to `view_test.dart` in the mutant clone, then restored)

| Run | Result |
|---|---|
| RV1–RV3 on `fdc8918` | green, 3 of 3 |
| O1 + RV | red: RV1 fails (the old RV3 draft also failed in this batch) |
| O2 + RV | red: RV2 fails (likewise) |
| O4 + RV (final RV3) | red: `Expected: <0>, Actual: <709>` |

The O1 and O2 batches ran with the first RV3 draft, which failed on the real code too. In each, 1 of 3 passed and 2 failed: RV3 plus the target test. The final RV3 was re-run on `fdc8918` (green) and under O4 (red).

## Gates (in `/tmp/zone-t2-review/repo`, at `fdc8918`; real output, last lines)

```
=== packages/jet_cad_floor_plan  (flutter test --file-reporter json:...)
04:09 +1423: All tests passed!
test runner exit 0
packages/jet_cad_floor_plan: 1423 tests; the standing failures and skips, exactly
expect_failures exit 0
No issues found! (ran in 7.4s)
analyze exit 0
Formatted 242 files (0 changed) in 1.08 seconds.
format exit 0

=== apps/restaurant_demo
00:19 +37: All tests passed!
test runner exit 0
apps/restaurant_demo: 37 tests; the standing failures and skips, exactly
expect_failures exit 0
No issues found! (ran in 3.6s)
analyze exit 0
Formatted 4 files (0 changed) in 0.05 seconds.
format exit 0

=== packages/jet_cad_2d (standing comparison)
00:16 +1253 -2: Some tests failed.
test runner exit 1
packages/jet_cad_2d: 1255 tests; the standing failures and skips, exactly
expect_failures exit 0

=== packages/jet_cad_2d_flutter (standing comparison)
01:01 +1355 ~1 -7: Some tests failed.
test runner exit 1
packages/jet_cad_2d_flutter: 1363 tests; the standing failures and skips, exactly
expect_failures exit 0
```

- `git diff ba7eec2 fdc8918 -- packages/jet_cad_2d packages/jet_cad_2d_flutter apps tool` is empty, so I-1 holds. The engine's 2 failures and the renderer's 7 failures plus 1 skip are the standing sets, exactly.
- `git status --short` was empty after the gates, and no `analysis_options.yaml` was touched.
- I did not re-run `apps/floor_planner`, because this commit does not touch anything it reads. The report gives 212 for it.

## The report, checked

- Its line citations match the code. I checked `:86`, `:251`, `:312`, `:324`, `:1062`, the painter's `:17`, `:82`, `:101`, `:105`, `:123` and `:140`, and `service_view.dart:221` and `:442-447`.
- Its counts match my runs: planner 1423, demo 37, engine 1255, render 1363.
- Every mutant I re-ran from its table went red, as it says.
- Its claim that "no existing line was edited" is true.
