# Task 3 report: the theme and the fill painter in both modes (PC-5, PC-6)

Status: DONE. Commit `9cb886bf` on `feat/plan-colors-slice-2` (parent `ebd5d1a`).

## What was implemented

- **Theme (PC-6).** `FloorPlanTheme.tableColorOpacity` (`double?`) after
  `statusFillOpacity` in the constructor and the fields, with the doc the brief
  gives. It is in `copyWith`, `merge` (`other.tableColorOpacity ??
  tableColorOpacity`), `lerp` (`_lerp(..., _lerpBetween)`), `==`, `hashCode`,
  the debug map (so `toString` too) and `validateFloorPlanTheme`
  (`opacity(theme.tableColorOpacity, 'tableColorOpacity')`). There is a new
  `const double kTableColorOpacity = 0.35;` with a doc line. The barrel still
  exports `show FloorPlanTheme` only, so the constant stays internal.
- **Painter (PC-5).** `TableStatusPainter` takes a new optional `darkCanvas`
  (`bool Function()?`, null means never) with the brief's doc. In `_rebuild`:
  - The survey always runs. The `if (map.isNotEmpty || groupMap.isNotEmpty)`
    guard and its comment are gone.
  - Per table, the status rungs run only when `number != null`. The colour is
    read from `FloorPlanTableColor.colorValue` only when there is no status.
    A table with neither is skipped.
  - The visible-layer rule and the path cache are shared and unchanged.
  - A colour's drawn value is `Color((round(255 * (theme.tableColorOpacity ??
    0.35)) << 24) | rgb)`, where `rgb` goes through `darkCanvasTone(rgb,
    paper & 0xFFFFFF)` when `darkCanvas()` is true. Its paint is keyed by
    ARGB like a status's, and it has no caption.
  - The record is now `(TableInfo, Path, Color drawn, TableStatus? status,
    String? group)`. Captions are built only for a status.
  - The class doc and file header describe the chain (group status, then own
    status, then colour).
  - Fills are still sorted by instance handle.
- **Service mount.** `service_view.dart` passes `darkCanvas: () => _darkCanvas`.
- **Design mount.** In `_PlannerShellState`:
  - The brief's `_fillPaper`, `_fillTheme`, static `_noStatuses` and
    `_noGroups`, and `_fillPainter`. Its repaint is `[_camera,
    _documentChanged, _fillPaper, _fillTheme]`.
  - `didChangeDependencies` sets `_fillTheme` and `_fillPaper` at its end,
    after `_nextResolver` has updated `_darkCanvas`.
  - `_onPage` sets `_fillPaper` first, before its early return.
  - `dispose` disposes `_fillPaper` and `_fillTheme`. The statics are never
    disposed.
  - `PlannerView(underlay: RepaintBoundary(child: CustomPaint(key:
    Key('table-colour-layer'), painter: _fillPainter, size:
    Size.infinite)))`.
  - The import is `host/floor_plan_types.dart show TableGroup, TableStatus`.
  - Step 6 check: `ServiceView` builds its own `PlannerView` (service_view.dart
    `:525`, its own `underlay` at `:557`) and never builds a `PlannerShell`.
    `PlannerShell` is built only by `floor_plan_view.dart:697` for the design
    mode. TF6 pins it: no `table-colour-layer` in the selection mode, and TF1
    and TF9 find exactly one in the design mode.

## Files

- M `packages/jet_cad_floor_plan/lib/src/host/floor_plan_theme.dart`
- M `packages/jet_cad_floor_plan/lib/src/service/table_status_painter.dart`
- M `packages/jet_cad_floor_plan/lib/src/host/service_view.dart`
- M `packages/jet_cad_floor_plan/lib/src/planner_shell.dart`
- A `packages/jet_cad_floor_plan/test/service/table_fill_test.dart` (11 tests:
  the fixture premise and TF1–TF10)
- M `packages/jet_cad_floor_plan/test/host/floor_plan_theme_test.dart` (named
  exception)

## The fixture (table_fill_test.dart)

- **The plan.** One plan, built by `fillDoc` (`prepareDocument` plus
  `installParametric`, disposed after). It has a 1:50 white page with the grid
  off. There is a teal room: four 200 mm walls from 38 to 44 m by −35 to −31 m,
  with `RoomParams(..., color: 'teal')`.
- **The tables.** Every table is turned and mirrored (`embeddingPlacement(...,
  sy: -1)`, det −1, turns between −40° and 120°) and 38 m or more off the
  origin.
  - Most use the embedding fixture's top: an asymmetric quadrilateral whose
    box sits off the definition origin. That origin is the base point and
    where the number label goes, outside the top.
  - B and K are a new `roundTable`, `CircleShape(600, 300, 400)`, also off the
    origin.
  - A: teal, with a status. B: purple, with a group status. C: teal, no status.
  - U: teal, unnumbered. K: purple, on a locked layer. H: teal, on a hidden
    layer. M: the name `"magenta"`, stored through `fromJson`. N: no colour.
    R: purple, inside the teal room.
- **Expectations.** Expected pixels come from `composite(rgb, alpha, paper)` in
  the test (the arithmetic is pinned by a premise literal, `0xA6D6D1`) and from
  literal ARGBs. The dark tone is `darkCanvasTone(0x00897B, kDarkCanvasPaper)`,
  as the brief says. Opacities are 0.6 beside a `statusFillOpacity` of 0.8.

## Rig references verified against the code (and adapted)

- **`table_status_painter_test.dart`'s rig.**
  - It paints into a `SpyCanvas` and into a `PictureRecorder`. I wrote my own
    `FillSpy`, which records each fill's matrix translation (`m[12]`, `m[13]`)
    and paint ARGB, and each caption's centre (x and y).
  - The existing `SpyCanvas` keeps only the reused matrix object, so it cannot
    attribute a fill to a table.
  - Pixels are read from `PictureRecorder` → `toImage` → `toByteData` inside
    `tester.runAsync`, as SP2 and SP12 do.
- **`theme_canvas_test.dart`'s pixel reads.** These are the palette fixture's
  `shotKey` `RepaintBoundary`, `shoot`, `pixelOf` (InteractionLayer plus the
  camera), `windowAt` and the seed's light/dark themes. The view is
  `MaterialApp(..., themeAnimationDuration: Duration.zero, home:
  RepaintBoundary(key: shotKey, child: Scaffold(body: FloorPlanView(...))))`.
  The camera is set through `c.cameraController.value` after two pumps.
- **The theme switch.** I re-pump the same tree with `themeMode:
  ThemeMode.light` (same tree shape, so the state is kept), as theme_canvas
  does.
- **Statuses and groups.** In the view I use `c.setTableStatus({...})`. In the
  painter I use `ValueNotifier`s of `TableStatus`, `TableGroup(members: ...)`
  and the group status keyed by group id, which is how `ServiceView` wires
  `_c.tableStatuses`, `_c.tableGroups` and `_c.groupStatuses`.
- **Colours.** `setTableColor` throws in the selection mode (P-5). TF6
  therefore colours the tables in the file and then calls
  `setMode(selection)`; the service copy carries the colours.
- **TF9's "camera pans by `controller.camera`".** `controller.camera` is a
  read-only `ValueListenable<FloorPlanCamera>`, so the ten pans write
  `c.cameraController.value`.

## TDD evidence

- **RED 1** (before any production change):
  `flutter test --enable-vmservice test/service/table_fill_test.dart` failed to
  compile.
  ```
  test/service/table_fill_test.dart:606:13: Error: No named parameter with the name 'tableColorOpacity'.
  test/service/table_fill_test.dart:629:13: Error: No named parameter with the name 'tableColorOpacity'.
  ```
- **RED 2** (with only the theme field added, Step 3): the same command gave
  `+1 -10`. The fixture premise passed and every TF failed for its own reason:
  - TF1: `Found 0 widgets with key [<'table-colour-layer'>]`
  - TF2: C `Expected: <1493207419> Actual: <null>` (A and B passed)
  - TF3: `Expected: an object with length of <6> Actual: []`
  - TF4: U `Expected: <1493207419> Actual: <null>`
  - TF5: C `Expected: <2566949243> Actual: <null>`
  - TF6: `teal before: 0xffffff, want 0xa6d6d1`
  - TF7: `fill 0x1e1f22, want 0x1d4744`
  - TF8: `set: 0xffffff, want 0xa6d6d1`
  - TF9 and TF10 failed too.
  - The final lines read `00:03 +1 -10: Some tests failed.`
- **GREEN:** after Steps 4–6 the same command gave `00:02 +11: All tests
  passed!` (after the TF8/TF9 frame fix below).

## Changed existing tests

These are all in `test/host/floor_plan_theme_test.dart` (named exception: the
tests that list every field gain `tableColorOpacity`). Line numbers are
old → new.

- `:32` → `:33` (`fullA`): added `tableColorOpacity: 0.25`.
- `:53` → `:55` (`fullB`): added `tableColorOpacity: 0.6`, beside
  `statusFillOpacity: 0.8`.
- `:99` → `:101`: the comment "The sixteen fields" became "The seventeen
  fields".
- `:112` → `:115-120`: a `fields` entry for `tableColorOpacity` (`copyWith`,
  `_double` lerp). Every test driven by `fields` now covers it: `copyWith`,
  `==`, `hashCode`, `toString` and the debug map, `merge`, `lerp`, and
  `expectWithinEnds`.
- `:251` → `:260` (`edgeA`): `tableColorOpacity: 0`. `:265` → `:275`
  (`edgeB`): `tableColorOpacity: 0.6`.
- `:325-326` → `:335-336`: "sixteen" became "seventeen", and `hasLength(16)`
  became `hasLength(17)`.
- `:338-339` → `:348-349`: the merge test's name "all sixteen … fifteen
  others" became "all seventeen … sixteen others".
- `:423` → `:434`: added `expect(edgeB.lerp(edgeA, 1.2).tableColorOpacity,
  0.0)` (the overshoot clamps).
- `:577` → `:589` and `:601` → `:614`: the range check's accepted and refused
  lists gain `('tableColorOpacity', FloorPlanTheme(tableColorOpacity: v))`.
- `:656` → `:669`: `hasLength(4 * 2 + 4 * 5 + 3 * 6)` became
  `hasLength(4 * 3 + 4 * 5 + 3 * 6)`.

`test/service/table_status_painter_test.dart` is **unchanged**. No test there
pinned "no survey when no status is set": SP7 and SP9's empty-map legs still
pass with the survey always running, because their documents have no colours.
So the named exception was not needed. No other existing test changed, and the
full suite passed unedited before the theme re-pins (run 1: `+1969: All tests
passed!`).

## Gates (last lines)

- **Planner.** `cd packages/jet_cad_floor_plan && flutter test
  --enable-vmservice --file-reporter json:<run.json>` gave `02:09 +1969: All
  tests passed!` (exit 0).
- **Standing sets.** From the repo root, `dart run tool/ci/expect_failures.dart
  --package packages/jet_cad_floor_plan --root packages/jet_cad_floor_plan
  <run.json>` gave `packages/jet_cad_floor_plan: 1969 tests; the standing
  failures and skips, exactly` (exit 0).
- **Planner analyze and format.** `flutter analyze` gave `No issues found!`.
  `dart format --output=none --set-exit-if-changed .` gave `Formatted 291
  files (0 changed)` (exit 0).
- **`apps/floor_planner`.** `flutter test` gave `00:37 +212: All tests
  passed!`. `flutter analyze` gave `No issues found!`. Format gave `Formatted
  47 files (0 changed)`.
- **`apps/restaurant_demo`.** `flutter test` gave `00:20 +68: All tests
  passed!`. `flutter analyze` gave `No issues found!`. Format gave `Formatted
  9 files (0 changed)`.
- **Not edited or run.** `jet_cad_2d`, `jet_cad_2d_flutter` and
  `jet_cad_2d_gpu` were not edited and do not read the planner, so I did not
  run them. `query_allocation_test` and `paint_allocation_test` are untouched.
  No `analysis_options.yaml` was committed (`git status` was clean after the
  commit).

## Mutants

All mutants were run the same way:

- **Applied by:**
  `python3 <scratchpad>/run_mutant.py <M> <test> [plain-name]`, run from
  `packages/jet_cad_floor_plan`.
- **What the script does:** it applies the exact text replacement, runs
  `flutter test --enable-vmservice <test> --plain-name <TF>`, copies the three
  sources back from copies set aside before the first mutant, and asserts that
  they are byte-identical again (it prints `reverted <M>` only then).
- **Afterwards:** `git status` showed only the intended changes, and the full
  suite was green again.

| Mutant | Change | Killer | Red output |
|---|---|---|---|
| M-C5 | colour read first (`colour` always read; status branch only `if (status != null && colour == null)`) | TF2 | `Expected: <4293212469> Actual: <1493207419>` (A: 0xFFE53935 wanted, teal@89 drawn) |
| M-C6 | `if (status != null && layer != null && !layer.visible) continue;` | TF3 | `Expected: null Actual: <1493207419>` (H filled) |
| M-C8 (twice) | alpha `255 * o * o` | TF5 | `Expected: <2566949243> Actual: <1543539067>` (alpha 153 wanted, 92 drawn) |
| M-C8 (ignored) | alpha `255` | TF5 | `Expected: <2566949243> Actual: <4278225275>` |
| M-C15 | `_state != state \|\|` removed from the rebuild key | TF8 | `set: 0xffffff, want 0xa6d6d1` (`Actual: <89>`) |
| M-C18 | survey guard kept (`map.isNotEmpty \|\| groupMap.isNotEmpty ? survey.tables : const []`) | TF10, TF1 | TF10: `Expected: an object with length of <1> Actual: []`; TF1: `A: 0xffffff, want 0xa6d6d1` |
| M-C19 | `if (number == null) continue;` restored at the loop's top | TF4 | `Expected: <1493207419> Actual: <null>` (U) |
| M-C20 | `if (layer != null && (!layer.visible \|\| layer.locked)) continue;` | TF4 | `Expected: <1502487722> Actual: <null>` (K) |
| M-C21 | an unknown name drawn (`stored.colorValue ?? FloorPlanColor.grey`) | TF3 | `Expected: null Actual: <1500870005>` (M filled grey@89) |
| M-C24 | design repaint `Listenable.merge([_camera, _fillPaper, _fillTheme])` | TF8 | `set: 0xffffff, want 0xa6d6d1` (`Actual: <89>`) |
| M-C25 | `final rgb = colour!.rgb;` (darkCanvas ignored) | TF7 | `fill 0x144441, want 0x1d4744` (`Actual: <9>`) |
| M-PC6 (merge) | `tableColorOpacity` dropped from `merge` | floor_plan_theme_test | merge "…all seventeen…" `Expected: <0.6> Actual: <null>`; "a null view…" fails (`+28 -2`) |
| M-PC6 (lerp) | `tableColorOpacity` dropped from `lerp` | floor_plan_theme_test | "two full themes…" `Expected: <0.25> Actual: <null>`; R-1, R-2, T1-b and the AnimatedTheme R-1 fail (`+25 -5`) |

Note on M-C15: the brief names "TF8's undo" as its killer. It dies one leg
earlier, at TF8's `setTableColor` leg. A component change moves the
dispatcher's `stateId` but not `tables.mutationRevision`, so without the
`_state` check nothing rebuilds at all.

## Deviations

1. **TF8 and TF9 wait for "the next frame" with two pumps, not one.**
   - The shell hears document changes on the dispatcher's `changes` stream
     (`_history` → `_documentChanged`), which is asynchronous.
   - After `setTableColor`, `hasScheduledFrame` was false (measured with a
     temporary print, since removed). The first `pump` only flushes the
     microtask that delivers the change, and the change then asks for a
     frame. The drafting itself also updates only on that frame.
   - `nextFrame(tester)` pumps, asserts `hasScheduledFrame` is true ("the
     change asks for a frame"), then pumps again.
   - With M-C24 the fill still does not show after both pumps (killed, above),
     so the "nothing else moving" intent holds.
   - I tried a premise that no frame is pending before the change, and dropped
     it: a frame was already pending at one call site.
2. **The sample point avoids the number label in a different way.** The brief
   assumes the label sits at the top's centre. In this fixture the label sits
   at the base point, the definition origin, which is outside the top. The
   sample points are inside the top and 250 mm or more from every edge: the
   quadrilateral's (650, 50), the circle's centre.
3. **TF2 and TF3–TF5 run on the painter directly.**
   - TF2 is "selection mode" via the painter, wired as `ServiceView` wires it,
     with the controller's notifier types. The selection mode's real mount is
     exercised by TF6, and by TF7's last leg, which also pins Step 5's
     `darkCanvas` wiring on the dark canvas.
   - TF5 adds a design-mode view leg (`FloorPlanView(theme: FloorPlanTheme(
     tableColorOpacity: 0.6, statusFillOpacity: 0.8))` → teal and purple at
     alpha 153). This also pins that `_fillTheme` reaches the design mount.
   - TF5 also pins that `statusFillOpacity` alone leaves a colour at 0.35, and
     that a null theme gives 0.35.
4. **Extra assertions beyond the brief.**
   - TF1 checks R, a purple table in the teal room: the room's tint is
     composited over the table's fill (`composite(teal, 51,
     composite(purple, 89, white))`), the V-12 "under the room's tint" case.
     It also checks the room's tint alone.
   - TF7 compares the fill pixel to `composite(tone, 89, paper)` and the
     room's pixel to `composite(tone, 51, paper)`, each within ±2. It also
     takes the room pixel back to its hue and recomposites it at 89, also
     within ±2.

## Self-review

- **The frame path.** The painter's `paint` is untouched. TF9 pins zero
  allocations and zero rebuilds over ten camera frames on the design mount,
  and exactly one rebuild for a colour change. The existing SP1/SP12
  structural checks pass unedited. `darkCanvasTone`, a 40-step bisection, runs
  once per coloured table at rebuild only (document, status, paper or theme
  rate). It is not cached, by choice; it is not per frame.
- **The rebuild key.** `darkCanvas` is not part of the rebuild key, and needs
  not be. The canvas re-tones only on `kDarkCanvasPaper`, and `darkCanvasFor`
  needs a light page, so the paper never equals `kDarkCanvasPaper` off the
  dark canvas. A flip therefore always moves `paper`, which triggers the
  rebuild. This is documented on the field.
- **Draw order.** Fills are still sorted by instance handle, and the record
  list keeps survey order.
- **Exact `==`.** The rebuild key still compares the theme by identity and the
  paper by value. No `Tolerance` decision was added.
- **The barrel.** No component type or handle crosses it.
  `FloorPlanTableColor` is imported only internally (painter).
- **Dispose order.** The design mount's `CustomPaint` detaches, removing its
  repaint listener, before the state's `dispose` disposes `_fillPaper` and
  `_fillTheme`, the same pattern as `ServiceView`'s `_paper` and `_theme`.

## Concerns

- **`fullTheme` in `theme_canvas_test.dart`.** Its doc says "every field set",
  and it now lacks `tableColorOpacity`. It is not one of the named exceptions,
  it still passes, and it does not assert the field, so I left it unedited.
  Worth a look in review or in Task 4.
- **The plan's "one pump" wording for TF8.** See deviation 1. A host or test
  that reads pixels straight after a controller edit needs the frame the
  change schedules. This is how the existing canvas behaves too, not something
  this task introduced.

---

## Fix round 1 (review: Review Focus 2's on-screen leg missing)

Commit `e59969f4` "test(floor-plan): TF8b deletes a coloured table and undoes
it on screen". The only file changed is
`packages/jet_cad_floor_plan/test/service/table_fill_test.dart`. Production
code is unchanged.

### What changed

- **TF8's title** no longer claims Review Focus 2. It now reads "TF8 M-C24
  M-C15 setTableColor, undo and redo each show at the next frame in the
  design mode, nothing else moving". Its body is unchanged.
- **New TF8b**, "Review Focus 2 (on screen): a coloured table deleted in the
  editor leaves the paper; Undo brings its fill back at the next frame, at
  the same pixel, and in tableDetails". It runs in the design shell
  (`FloorPlanView` in the design mode, the fixture's `viewCamera`):
  1. Table C (teal, turned 30° and mirrored, 46 m and −30.5 m off the origin)
     shows teal at alpha 89 over white at `insideTop(C)`. This is the premise.
  2. `c.select({'C'})` and a pump; `selectedTables == {'C'}` is a premise.
  3. The Delete key is sent down and up, as TC8 drives the editor's delete,
     then `nextFrame`.
  4. Asserts: the instance is gone from `doc.tree`, no `tableDetails` entry
     has number C, and the pixel is the paper (`0xFFFFFF` ±2).
  5. `c.undo()`, then `nextFrame`.
  6. Asserts: the instance is back as an `InstanceNode`, the `tableDetails`
     entry for C has colour `FloorPlanColor.teal`, and the same pixel is teal
     at alpha 89 over white again (`0xA6D6D1` ±2).
- The test file now imports `LogicalKeyboardKey` from
  `package:flutter/services.dart`.

### Covering test

`cd packages/jet_cad_floor_plan && flutter test test/service/table_fill_test.dart`:
```
00:02 +12: All tests passed!
```
`flutter analyze` gave `No issues found!`. `dart format --output=none
--set-exit-if-changed .` gave `Formatted 291 files (0 changed)`.

### Mutant check

Each run used `python3 <scratchpad>/run_mutant.py <M>
test/service/table_fill_test.dart TF8b`. Before the runs I confirmed that the
copies set aside match HEAD (`git diff --quiet lib` and `cmp`). The script
then restored the sources and checked they were byte-identical (`reverted`).

- **M-C24 (the design mount's repaint misses `_documentChanged`) dies on
  TF8b.**
  ```
  Expected: a value less than or equal to <2>
    Actual: <89>
  deleted: 0xa6d6d1, want 0xffffff
  00:01 +0 -1: TF8b Review Focus 2 (on screen): ... [E]
  ```
  Without the document's changes the fill layer is never repainted, so the
  deleted table's fill stays on screen.
- **M-C15 (the `stateId` check removed from the rebuild key) survives TF8b**
  (`00:01 +1: All tests passed!`). A delete and its undo also move
  `tables.mutationRevision`, which is still in the key, so the fills rebuild
  anyway. M-C15 remains killed by TF8's `setTableColor` leg: a component edit
  moves only `stateId`.
- **No painter mutant is killed by TF8b alone.** Stated plainly: I found no
  honest painter mutant that only this leg kills.
  - The path cache is keyed by definition, and the definition survives the
    delete.
  - The re-added instance keeps its handle and its component.
  - The rebuild has two independent triggers on this path (`stateId` and
    `tables.mutationRevision`).
  - The only mutant this leg kills is the shell's M-C24, which TF8 also kills.
  - What TF8b adds is coverage of the delete and restore path on screen, which
    TF8 never drew.
