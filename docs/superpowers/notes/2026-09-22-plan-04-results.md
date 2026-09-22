# Plan 04 — page, grid and rulers: results

**Plan:** [2026-09-22-page-grid-rulers.md](../plans/2026-09-22-page-grid-rulers.md).
**Spec:** [2026-09-22-page-grid-rulers-design.md](../specs/2026-09-22-page-grid-rulers-design.md)
(revision 2, amended at execution 2026-09-22 — see "Spec amendments" below).
**Mutation log:** [plan-04-mutation-log.md](plan-04-mutation-log.md).
**Branch:** `plan-04/page-grid-rulers`, worktree
`.claude/worktrees/plan-04-page-grid-rulers`, cut from `main` at `1e5001d`.
**Twelve tasks: Tasks 1–11 at `39ff5f2..563fdd4`; Task 12 (the gate lines,
this note, the spec amendments, STATUS and the roadmap) on top. NOT merged —
the merge is the human's decision, after the look this note leaves OWED.**
**Ledger (per-task briefs, reports, review diffs, every ruling):**
`.superpowers/sdd/2026-09-22-page-grid-rulers/`.

---

## What was measured

### The four gate lines, pasted

Run in this task, from each package directory, on the tree at `563fdd4`.
Every summary line below is what the command printed, with its exit code.

**`packages/jet_cad_2d`** — `CI=true dart test`:

```
00:05 +860: All tests passed!
```

Exit 0. `dart analyze`:

```
Analyzing jet_cad_2d...
No issues found!
```

Exit 0. `dart format --output=none --set-exit-if-changed .`: `Formatted 125
files (0 changed) in 0.39 seconds.` Exit 0.

**`packages/jet_cad_2d_flutter`** — `CI=true flutter test`:

```
00:29 +795 ~1 -5: Some tests failed.

Failing tests:
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 1 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 2 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 3 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 4 (RenderBackend.canvas)
  .../test/golden/text_ladder_golden_test.dart: text ladder rung 5 (RenderBackend.canvas)
```

Exit 1 — **795 pass, 1 pre-existing skip, and exactly the same five
pre-existing `text_ladder_golden_test.dart` failures named above (`text
ladder rung 1..5`, `RenderBackend.canvas`) and nothing else.** The Plan 01
baseline ruling stands, carried through Plan 02: the goldens were recorded
2026-08-24 on SDK 3.47.2 and the difference is pixel drift, not a regression
this plan introduced. `flutter analyze`:

```
Analyzing jet_cad_2d_flutter...
No issues found! (ran in 3.0s)
```

Exit 0. `dart format --output=none --set-exit-if-changed .`: `Formatted 148
files (0 changed) in 0.33 seconds.` Exit 0.

**`apps/dev_harness_2d`** — `CI=true flutter test --concurrency=1`:

```
00:29 +82: All tests passed!
```

Exit 0 — **82 tests**, the branch-point count unchanged; the harness is
untouched by this plan (`git diff --stat main..HEAD -- apps/dev_harness_2d`
empty, re-checked in Task 11 and pasted in the mutation log). `flutter
analyze`:

```
Analyzing dev_harness_2d...
No issues found! (ran in 3.2s)
```

Exit 0. `dart format --output=none --set-exit-if-changed .`: `Formatted 22
files (0 changed) in 0.07 seconds.` Exit 0.

**`apps/floor_planner`** — `CI=true flutter test`:

```
00:02 +21: All tests passed!
```

Exit 0 — **21 tests** (13 at the branch point, plus Task 9's four and Task
10's four). `flutter analyze`:

```
Analyzing floor_planner...
No issues found! (ran in 1.3s)
```

Exit 0. `dart format --output=none --set-exit-if-changed .`: `Formatted 7
files (0 changed) in 0.04 seconds.` Exit 0. `flutter build macos --release`:

```
Building macOS application...
✓ Built build/macos/Build/Products/Release/floor_planner.app (51.0MB)
```

Exit 0. `flutter build web --release`:

```
Compiling lib/main.dart for the Web...
Wasm dry run succeeded. Consider building and testing your application with the `--wasm` flag. See docs for more info: https://docs.flutter.dev/platform-integration/web/wasm
Use --no-wasm-dry-run to disable these warnings.
Expected to find fonts for (MaterialIcons, packages/cupertino_icons/CupertinoIcons), but found (MaterialIcons). This usually means you are referring to font families in an IconData class but not including them in the assets section of your pubspec.yaml, are missing the package that would include them, or are missing "uses-material-design: true".
Font asset "MaterialIcons-Regular.otf" was tree-shaken, reducing it from 1645184 to 7736 bytes (99.5% reduction). Tree-shaking can be disabled by providing the --no-tree-shake-icons flag when building your app.
Compiling lib/main.dart for the Web...                             31.8s
✓ Built build/web
```

Exit 0. Both `✓ Built`. The `cupertino_icons` font warning and the Wasm
dry-run note are pre-existing and carried from Plan 01/02's builds; neither
fails the build.

`git status --short` was clean before Step 1, after every gate line and
after both builds: **no `analysis_options.yaml` was rewritten at any point
in this task, so none needed restoring.**

The startup clamp line, printed again on this run by
`startup_plan_test.dart`'s `the clamp constants bracket the fitted scale by
decades`, unchanged from Plan 01 and Plan 02. **Read it carefully: that test
still computes `ViewportTransform.fit(doc.extents, …)`, the *extents* fit,
not the page fit the app now uses** — the clamp bracket is what it asserts,
and re-pointing it at `fitToPage` is one of the deferred minors below:

```
STARTUP fit scale 0.095 px/mm; min 0.001 (95.0x out), max 100.0 (1052.6315789473683x in)
```

### The Plan 01 baseline, recorded again

The five `text_ladder_golden_test.dart` failures (`text ladder rung 1..5`,
`RenderBackend.canvas`) are the same pre-existing Skia/SDK drift Plan 01
recorded and Plan 02 recorded again — measured once more in this task,
identically named, nothing added and nothing healed. This plan's
`jet_cad_2d_flutter` bar is therefore "795 pass, 1 skip, those same five
failures and no other," as Plan 02's was "769 pass, 1 skip, those same
five."

### Mutation summary

**Twenty-two named mutants (M-04a … M-04v) plus the tile-cache twin of
M-04r: 23 fired, 23 killed, 0 survived, 0 declared equivalent.** The spec
claimed no equivalence and none was claimed at execution. Each mutant was
a one-line edit to a production file that was `cp`-backed up first and
restored from that copy afterwards, confirmed with `diff -q`; no
`git checkout --` was used on any `.dart` file. Full transcripts, with the
failing expectation pasted for each:
[plan-04-mutation-log.md](plan-04-mutation-log.md).

Three of the twenty-two do not fire where the spec's table said they would,
and the spec is amended for each (see "Spec amendments"): **M-04c** is
killed by `grid_scale_test` *and* by the differential, not by the
differential alone; **M-04g** fires through the `minorMinPixels` parameter
Ruling 04-7 added to `pick`, because the shipped 64/8 threshold pair cannot
reach the null-minor branch from any rung of either ladder; **M-04q** as
first written (`if (false)`) was a *compile* failure, not a behavioural
kill — Ruling 04-18 re-fired it as a compiling mutant that drops the floor
from the ladder's values, and the first attempt is **not counted** in the
23.

Both allocation gates are green and unchanged — `query_allocation_test.dart`
(5 tests) and `paint_allocation_test.dart` (3 tests), transcripts pasted in
the mutation log's "Extra checks" section, together with the empty
untouched-files diff, the one-hunk `tile_cache.dart` diff (the D13 skip) and
the `dart:ui` grep over the three new engine files, which prints nothing.

### The differential (criterion 12)

`page_chrome_painter_test.dart`'s `'differential: fifty seeded cameras agree
with the literal-ladder oracle'`: **seed `0x5EED0004`, 50 trials**, scale
log-uniform in [`kMinScale`, `kMaxScale`], and the set of major-line screen
x positions recorded by `SpyCanvas` compared to 1e−6 px against a
brute-force oracle built in the test from a **literal copy** of the metric
ladder table, its own 64 px rule, `sheetWorldRect` and `worldToScreen`. The
oracle shares no code with `GridScale.pick`.

**Ruling 04-13 changed how the camera is drawn, and this is the finding
that mattered most in the whole plan.** As the spec wrote it, the
translation was uniform in ±5 000 px, independent of where the sheet is —
and at the standard page's off-origin corner that put the sheet off screen
in **all fifty trials**, so every trial compared the empty set to the empty
set and the differential verified nothing about positions. It was vacuous,
and it passed. The camera is now built so the sheet is on screen by
construction — `tx = sx − s·wx`, `ty = sy + s·wy` with `(wx, wy)` uniform
inside the sheet and `(sx, sy)` uniform in the viewport — and the test
**asserts** that all 50 trials produce majors, **1 to 12 per trial**. A
reader writing the next seeded sweep should take the lesson: a random
camera over an off-origin fixture needs an anti-vacuity counter, or it
proves nothing.

---

## Exit gate

The spec's sixteen criteria, each with its witness.

| # | criterion | verdict | witness |
|---|---|---|---|
| 1 | `PageComponent` round-trips **typed** through the codec with registration, and `encode(decode(encode(doc)))` is byte-identical | **PASS** | `page_component_roundtrip_test.dart`: `the page round-trips typed when the load registers it, and the bytes are stable`; `decode (the map form) takes the same hook` |
| 2 | Without registration the component survives as unknown bytes and re-encodes byte-identically; the test says so in its name | **PASS** | `page_component_roundtrip_test.dart`: `without registration the bytes survive but the type does not — which is why the typed assertion above exists` |
| 3 | Every page edit is one undo step and undo restores the previous value by `==` | **PASS** | `page_panel_test.dart`: `each toggle is exactly one command, and undo reverts the control` (M-04o — `undoDepth` grows by exactly one per edit), `preset, orientation, unit and swatch each issue one command`; `component_edit_skip_test.dart`: `a components-only edit on the root reconciles nothing` (apply, apply, undo, redo, the value compared by `==`); `page_notifier_test.dart`: `follows apply, undo and redo through the stream` |
| 4 | Ruler tick positions and spacing are correct at a camera that is both zoomed and panned, over an off-origin page (M-04a, M-04b) | **PASS** | `ruler_painter_test.dart`: `major ticks sit at worldToScreen of the lattice, labelled in metres`, `minor ticks are shorter and unlabelled` — the standard fixture (page at (7350, −1230), camera at scale 0.137 translated by (−611.5, 412.25)); M-04a and M-04b both fired red on it |
| 5 | The grid picks the documented ladder step at the documented thresholds; minors appear only at ≥ 8 px; nothing at all past the ladder's top (M-04c, M-04g) | **PASS** | `grid_scale_test.dart`: `metric: the smallest ladder step at or above 64 px`, `a mantissa-2 major divides by 4`, `minor is null under the minor threshold`, `null past the top of the ladder, and for a bad scale`; `page_chrome_painter_test.dart`: `minors that coincide with a major are not drawn twice` |
| 6 | Line count is bounded over the intersection range at `kMinScale` and `kMaxScale`; breaks vanish below a 16 px sheet (M-04m, M-04t) | **PASS** | `page_chrome_painter_test.dart`: `bounded at kMinScale, kMaxScale, and the intersection is the range`, `page breaks tile outward and vanish under a 16 px sheet` |
| 7 | Grid, rulers, sheet and breaks add zero entities; a page edit, its undo and its redo cause zero index rebuilds and zero tile drops (M-04r, M-04s) | **PASS** | `component_edit_skip_test.dart`: `a components-only edit on the root reconciles nothing`, `the change carries the capability of the command that made it`, `a compound with one geometry member still reconciles`, `the default capability is geometry, so old construction sites keep their meaning`; `tile_invalidation_test.dart`: `a components-only change drops no tile`; `page_chrome_painter_test.dart`: `a chrome toggle through the log adds no entity and rebuilds no index` |
| 8 | `query_allocation_test.dart` and `paint_allocation_test.dart` pass unchanged | **PASS** | both green and unedited — transcripts in the mutation log's "Extra checks" section, and both are inside the 860 / 795 gate lines above |
| 9 | An adaptively snapped point inside the sheet lies on a drawn grid line; snap is nearest, anchored at the sheet corner, exact at `gridStepMm` (M-04f, M-04h) | **PASS** | `grid_scale_test.dart`: `nearest, anchored at the sheet origin, negative side too`, `an adaptive step lands on the drawn lattice`, `refuses a non-positive step`, `a floor is exact when it fits and the ladder climbs from it`; `page_chrome_painter_test.dart`: `major lines sit where the oracle says, anchored at the sheet corner` (M-04f) |
| 10 | Labels are in the display unit (M-04i), the left ruler reads upward (M-04p) | **PASS** | `grid_scale_test.dart`: `formatLength per unit`; `ruler_painter_test.dart`: `the left ruler reads upward`, `the corner shows the unit symbol`, `past the ladder top, only the bar and the pointer` |
| 11 | The camera fits the page at startup at the drawing area's size; 100 % ⇔ `scale = pixelsPerPaperMm / D` (M-04k, M-04n) | **PASS**, with Ruling 04-16 | `page_geometry_test.dart`: `100 % is pixelsPerPaperMm / D`, `the sheet rect is origin plus effective size times D`, `page space is world minus origin, and back`; `page_fit_test.dart`: `fitToPage fits the sheet rect, not the extents`; `planner_shell_test.dart`: `the camera is fitted to the page at the drawing area's size`, `a resize after the first layout does not re-fit the camera`, `the zoom text reads the scale and the fitted zoom`. **The fit lands in a post-frame callback (Ruling 04-16): the first frame paints at the shell's nominal 1440×900 page fit, the second at the real drawing-area size. It still happens exactly once.** |
| 12 | The differential check passes for 50 seeded random cameras against an oracle that shares no code with `pick` | **PASS** | `page_chrome_painter_test.dart`: `differential: fifty seeded cameras agree with the literal-ladder oracle` — seed `0x5EED0004`, 50 trials, 1..12 majors each, pasted above (Ruling 04-13) |
| 13 | The panel drives its eight controls with one command each; cmd/ctrl+Z reverts the control (M-04o) | **PASS** | `page_panel_test.dart`: `each toggle is exactly one command, and undo reverts the control`, `preset, orientation, unit and swatch each issue one command`, `the scale field commits on submit, refuses junk`, `a custom size shows Custom` |
| 14 | Every named mutant (M-04a…v) fired, killed or declared equivalent with a reason, in `docs/superpowers/notes/plan-04-mutation-log.md` | **PASS** | [plan-04-mutation-log.md](plan-04-mutation-log.md) — 23 fired (22 named plus the tile-cache twin of M-04r), 23 killed, 0 survived, 0 equivalent |
| 15 | The four gate lines — `CI=true` on every test command — are green, with the one standing exception carried from Plan 02 and no other; `analysis_options.yaml` untouched | **PASS with the one recorded exception** | pasted above: `jet_cad_2d` **860**; `jet_cad_2d_flutter` **795 pass, 1 skip, the same five `text_ladder_golden_test.dart` failures and nothing else**; `dev_harness_2d` **82**; `floor_planner` **21**, and `flutter build macos --release` and `flutter build web --release` both `✓ Built`. Every `analyze` and `format` exits 0; `git status --short` clean throughout, no `analysis_options.yaml` rewritten |
| 16 | A human looked, on macOS, in Chrome and in Firefox from `build/web` | **OWED — not looked at; the human looks after this branch is presented** | the look section below, itemised per platform |

**15 of 16 PASS.** No criterion is a MISS. Criterion 16 is **OWED**,
itemised below.

---

## The look — OWED, itemised

**Not looked at. No device run and no visual judgement happened in this
session, and none was simulated.** The human looks after this branch is
presented, and the merge is theirs to decide. macOS from `cd
apps/floor_planner && flutter run -d macos --release`; Chrome from `cd
apps/floor_planner && flutter run -d chrome --release`; Firefox from
`build/web` served statically (`cd apps/floor_planner/build/web && python3
-m http.server`). Eight items, each recorded **seen / not seen / could not
judge**.

### macOS — `flutter run -d macos --release`

1. **The sheet under the plan.** A white A4 landscape sheet with a thin
   edge, sitting under the walls, the app's surface colour outside it.
   ☐ seen ☐ not seen ☐ could not judge
2. **The grid at three zoom levels.** Zoom in, out, and in again: the grid
   step changes in 1-2-5 jumps, majors never closer than about 64 px,
   minors appearing and vanishing at about 8 px, and at extreme zoom-out
   the grid disappears entirely rather than turning into a grey wash.
   ☐ seen ☐ not seen ☐ could not judge
3. **Ruler zero at the sheet corner, labels in metres.** The top and left
   rulers read `0 m` at the sheet's bottom-left corner — not at world
   origin — and the labels are metres, matching the startup page's unit.
   ☐ seen ☐ not seen ☐ could not judge
4. **Page breaks with Letter selected in the panel.** Switch the preset
   dropdown to Letter; dashed break lines tile outward from the sheet.
   ☐ seen ☐ not seen ☐ could not judge
5. **A unit change to ft-in on the rulers.** Switch the unit dropdown to
   feet-inches; the ruler labels become `3'-6"`-shaped and the corner box
   reads `ft`.
   ☐ seen ☐ not seen ☐ could not judge
6. **One panel edit and its undo with cmd+Z.** Toggle a checkbox or a paper
   swatch, then press cmd+Z: the control moves back in one step, not two.
   ☐ seen ☐ not seen ☐ could not judge
7. **The pointer marker.** A thin line in each bar following the cursor.
   ☐ seen ☐ not seen ☐ could not judge
8. **The first frame's flash at the nominal fit (Ruling 04-16).** At
   launch the fit is deferred to a post-frame callback, so frame 1 paints
   at the shell's nominal 1440×900 page fit and frame 2 at the real
   drawing-area size. **Is that one-frame jump visible?** If it is, the fix
   is a silent camera set plus a deferred notify, which needs a
   `CameraController` API and its own ruling — it is deliberately not in
   this plan.
   ☐ seen ☐ not seen ☐ could not judge

### Chrome — `flutter run -d chrome --release`

The same eight items, ctrl+Z in place of cmd+Z for item 6.

1. The sheet under the plan. ☐ seen ☐ not seen ☐ could not judge
2. The grid at three zoom levels. ☐ seen ☐ not seen ☐ could not judge
3. Ruler zero at the sheet corner, labels in metres. ☐ seen ☐ not seen ☐ could not judge
4. Page breaks with Letter selected in the panel. ☐ seen ☐ not seen ☐ could not judge
5. A unit change to ft-in on the rulers. ☐ seen ☐ not seen ☐ could not judge
6. One panel edit and its undo with **ctrl+Z**. ☐ seen ☐ not seen ☐ could not judge
7. The pointer marker. ☐ seen ☐ not seen ☐ could not judge
8. The first frame's flash at the nominal fit (Ruling 04-16). ☐ seen ☐ not seen ☐ could not judge

### Firefox — `build/web`, served statically

The same eight items again, from the release web build rather than
`flutter run`, ctrl+Z for item 6.

1. The sheet under the plan. ☐ seen ☐ not seen ☐ could not judge
2. The grid at three zoom levels. ☐ seen ☐ not seen ☐ could not judge
3. Ruler zero at the sheet corner, labels in metres. ☐ seen ☐ not seen ☐ could not judge
4. Page breaks with Letter selected in the panel. ☐ seen ☐ not seen ☐ could not judge
5. A unit change to ft-in on the rulers. ☐ seen ☐ not seen ☐ could not judge
6. One panel edit and its undo with **ctrl+Z**. ☐ seen ☐ not seen ☐ could not judge
7. The pointer marker. ☐ seen ☐ not seen ☐ could not judge
8. The first frame's flash at the nominal fit (Ruling 04-16). ☐ seen ☐ not seen ☐ could not judge

### Four things to know before looking, stated in as many words

- **`header.units` is a non-goal, and 04 does not read it.** `startupPlan`
  sets `header.units = millimeters` and **nothing ever reads it to
  convert**. The document is millimetres, always; the page's own
  `DisplayUnit` is the only thing that decides what the rulers and labels
  say. A file whose header says `inches` still displays as millimetres —
  13, or an import sub-project, decides whether to convert. Do not read a
  ruler label as evidence about `header.units`.
- **The adaptive snap step follows the zoom** (spec D6). When
  `page.gridStepMm` is null, the snap step is the step `pick` chose at the
  current camera — so the same drag snaps to a different lattice at a
  different zoom. When `gridStepMm` **is** set, it is used exactly, at
  every zoom. If the zoom dependence looks wrong when 03 wires the snap
  into drags, the fix is a default `gridStepMm` on the page, not a change
  to `snapToGrid`.
- **The first frame paints at the nominal 1440×900 page fit** (Ruling
  04-16), the second at the real drawing-area size. Item 8 above asks
  whether that is visible.
- **The differential's camera is seeded `0x5EED0004`, 50 trials, 1..12
  majors each** (Ruling 04-13) — and as the spec first wrote it, it was
  vacuous in all fifty. See the differential section above.

---

## Debt and rulings the human should know

Every item below is a deferred minor from the ledger
(`.superpowers/sdd/2026-09-22-page-grid-rulers/deferred-minors.txt`) or a
ruling made at execution. None is a defect in shipped behaviour; each is
one sentence and the file it lives in.

**Deferred minors, from the ledger:**

- `page_component.dart`'s `toString` prints `custom` where `SheetSize.name`
  prints `Custom` — cosmetic, two spellings of the same state (Task 1).
- `grid_scale.dart`'s `_metricLadder` and `_imperialLadder` are `static
  final` **mutable** lists handed straight back by `ladderFor`, so a caller
  could scribble on the shared ladder; wrap them in `List.unmodifiable`
  (Task 4).
- `page_chrome_painter_test.dart`'s `SpyCanvas` records `TypedData`
  arguments **by reference**, so a test that inspected a recorded list
  after a second paint would read the later frame's bytes; copy the
  `TypedData` in `SpyCanvas`, or keep counters the only cross-paint
  surface (Task 6).
- `page_chrome_painter.dart`'s line bound rests on `cam.scale` (the
  geometric mean), which an anisotropic camera would break; no producer
  makes one today, and the guard would be a doc line or an `assert(b == 0
  && c == 0)` (Task 6).
- The chrome painter test's oracle assumes the **metric, floor-less**
  ladder, so it would diverge silently if the standard fixture's unit ever
  changed (Task 6).
- `page_chrome_painter.dart`'s `onPaintForTest` has no caller yet, and the
  bounded test uses 800 for both viewport axes — looser than the real
  drawing area, and safe (Task 6).
- `ruler_painter.dart` builds a per-frame `ticks` list for the
  `debugLastTicks` record; it is debug-only and outside the entity path,
  but it is a per-frame allocation (Task 7).
- `ruler_frame.dart`'s `_repeat` and `_cornerRepaint` are `late final` over
  `widget.camera` / `widget.page`, so swapping either instance across a
  rebuild would orphan the merged listenable; no call site does (Task 8).
- `planner_view.dart`'s class doc still says "a `CameraGestureDetector`
  over a `DraftCanvas`", which the ruler frame and the chrome painter have
  outgrown; its two fit tests are near-duplicates; `startup_plan_test`
  still brackets `kMin`/`kMaxScale` against the **extents** fit (Task 9).
- `page_panel.dart`'s `_set` issues a `SetComponentCommand` even when
  `next == page`, so re-selecting the already-active preset, unit,
  orientation or swatch creates a no-op undo entry; guard it with an
  equality check (Task 10).

**Rulings a reader must know:**

- **The fit is deferred by one frame (Ruling 04-16).** Assigning
  `camera.value` during `PlannerView`'s `LayoutBuilder` build now notifies
  the zoom text's `ListenableBuilder` — a sibling — and Flutter asserts, so
  the one-time fit moved into a post-frame callback. Ruling 01-2's intent
  (fit to the real size, once) holds from frame two; frame one draws at the
  shell's nominal `fitToPage(page, 1440×900)`. The reviewer judged this the
  right call: the alternative, a silent camera set with a deferred notify,
  needs a `CameraController` API and its own ruling.
- **The seeded differential was vacuous as specified (Ruling 04-13).** See
  the differential section — fifty trials, fifty empty-set comparisons,
  and it passed. Fixed at execution.
- **The imperial ladder is written as fractions of a foot (Ruling 04-11).**
  `304.8 × {1/192, 1/96, 1/48, 1/24, 1/12, 1/6, 1/2}`, not the spec's
  `{1/16, 1/8, 1/4, 1/2, 1, 2, 6} × 25.4`, so a foot rung divided by 4 is
  **bit-equal** to the quarter rung; an exact `==` test pins it. Same
  lengths to 1e−13; the "× 25.4" wording is superseded.
- **Every imperial step divides by 4 (Ruling 04-12)**, floor or not — the
  spec's own words, which the first implementation applied only to the
  floor-less case.
- **`pick` takes a `minorMinPixels` parameter (Ruling 04-7)**, because the
  shipped 64/8 threshold pair cannot reach the null-minor branch from any
  rung of either ladder: M-04g had no reachable kill without it.
- **A minor whose index is a multiple of the divisor is skipped in the
  minor pass (Ruling 04-3)**, so a coincident line is drawn once, by the
  major pass, not twice.
- **The grid's two `sublistView`s are disjoint (Ruling 04-14).** The major
  pass writes **after** the minors' span in the one reused buffer; the
  plan's own code had the major pass overwriting the minors' view, and the
  implementer caught it.
- **The vertical ruler iterates its lattice from the top of the bar
  downward (Ruling 04-15)**, so `debugLastTicks` comes out in bar order on
  both axes; the world-ascending loop the plan wrote produced descending
  screen y. Drawing is unaffected.
- **`startupPlan` clears the history (Ruling 04-1)** — a fresh document
  starts with no undo entries, like a loaded one, so the page that
  `SetComponentCommand` attached is not the first thing cmd+Z removes.
- **The shell owns `PageNotifier` (Ruling 04-2)**, not `PlannerView`, so
  the panel in `chrome-right` and the painters under the canvas read the
  same instance.
- **M-04q's first attempt is not counted (Ruling 04-18).** As logged,
  `if (false)` cost the compiler a null promotion and the file did not
  build: a compile failure is not a behavioural kill. It was re-fired as a
  mutant that compiles — the floor dropped from the ladder's values — and
  went red on `a floor is exact when it fits and the ladder climbs from
  it`.
- **A comment-only fix round is verified by the controller reading the
  diff (Ruling 04-17)**, with no re-review seat; Task 9's fix round was one.
- **Two accepted deviations in the app** (Task 10): the preset dropdown
  carries a `hint` so "Custom" shows when the menu is closed, and the panel
  is wrapped in a `Material` because `ListTile`'s ink assertion broke four
  shell tests without one.
- **The Plan 01 baseline (five text-golden failures) stands**, recorded
  again above — pre-existing Skia/SDK drift from goldens recorded
  2026-08-24, SDK 3.47.2, not a regression this plan introduced.

---

## Spec amendments

Recorded where each applies, in
[2026-09-22-page-grid-rulers-design.md](../specs/2026-09-22-page-grid-rulers-design.md),
each as a paragraph beginning "**Amended at execution (Plan 04,
2026-09-22):**" appended at the end of the relevant decision's section —
nothing original was rewritten:

- **D4** and **D12** gain Ruling 04-16: the one-time fit is deferred to a
  post-frame callback; the first frame paints at the shell's nominal fit,
  the second at the real drawing-area size; the latch still makes it once.
- **D7** gains three: Ruling 04-7 (`pick` takes `minorMinPixels`, because
  the shipped 64/8 pair cannot reach the null-minor branch from any ladder
  rung), Ruling 04-11 (the imperial inch rungs are `304.8 × {1/192, 1/96,
  1/48, 1/24, 1/12, 1/6, 1/2}` so a foot rung ÷ 4 is bit-equal to the
  quarter rung — the "× 25.4" wording is superseded) and Ruling 04-12
  (every imperial step divides by 4, floor or not).
- **D8** gains three: Ruling 04-3 (a minor whose index is a multiple of the
  divisor is skipped in the minor pass), Ruling 04-14 (the major pass
  writes after the minors' span in the one buffer, so the two
  `sublistView`s are disjoint) and Ruling 04-13 (the seeded sweep places
  the sheet on screen by construction; the ±5 000 px translation was
  vacuous in all fifty trials).
- **D10** gains Ruling 04-2: the shell owns `PageNotifier`.
- **D11** gains Ruling 04-15 (the vertical bar iterates its lattice from
  the top of the bar downward, so the debug tick list is in bar order) and
  the `crossAxisAlignment: stretch` the frame's rows need.
- **D12** gains Ruling 04-1 (`startupPlan` clears the history; a fresh
  document has none, like a loaded one) as well as Ruling 04-16 above.
- **Testing** gains the three mutants whose kill site moved: M-04c is
  killed by `grid_scale_test` *and* the differential; M-04g fires through
  `minorMinPixels`; M-04q is killed by dropping the floor from the
  ladder's values, the `if (false)` form being a compile failure rather
  than a behavioural kill (Ruling 04-18).

---

## Files this task touched

- `docs/superpowers/notes/2026-09-22-plan-04-results.md` — this file.
- `docs/superpowers/specs/2026-09-22-page-grid-rulers-design.md` — the
  amendments above, appended, nothing rewritten.
- `STATUS.md` — a Plan 04 section, the header's "Last updated" sentence and
  the "Resume here" section.
- `roadmap/04-page-grid-rulers.md` — the status line.
- `roadmap/00-README.md` — the 04 row in the execution-status table.

No code was touched. The mutation log, the plan and the review notes are
unchanged.
