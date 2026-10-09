# Plan — host embedding API, Slice 1: geometry, camera, per-table widgets

**Spec:** [2026-10-09-host-embedding-api-design.md](../specs/2026-10-09-host-embedding-api-design.md),
revision 3 (`4f5c8fc`): the principles P-1 to P-9 and **Slice 1**
(G-1 to G-9, H-8). Revision 1 was reviewed independently (*Approve with
fixes*, V-1 to V-22, all folded in); the human answered Q-H1 and Q-H2
(Slice 2's).

**Started** on the human's *"evet, Dilim 1 ile devam et"* (2026-10-09).
Slice 1 unblocks Monépro's spec 103 B.1 and D22 and closes the zone
spec's Q-Z1.

**Branch:** `claude/exciting-pasteur-9m22jv`, from `main` at `85905bd`
(release 0.3.0), plus the spec's and STATUS's docs commits and this
plan's.

**Ledger:** `.superpowers/sdd/2026-10-09-host-embedding-api/`
(`spec-review.md` is there): this slice's briefs, reports and reviews as
`s1-task-<n>-report.md` / `s1-task-<n>-review.md`.

## Global constraints

- `CLAUDE.md`'s non-negotiables. **The two allocation invariants**
  (`query_allocation_test`, `paint_allocation_test`) **and every golden
  stay untouched.** The engine (`jet_cad_2d`) is not edited.
  `jet_cad_2d_flutter` is edited **only** in Task 4 (the input marker),
  and its whole suite stays green there.
- **P-1 and P-6:** no existing signature, `==`, `hashCode` or `toString`
  changes; `FloorPlanTable` is untouched. **Existing tests pass unedited**,
  with one named exception: the `@internal camera` → `cameraController`
  rename (Task 2) edits the tests and the demo test that use the internal
  member, mechanically, and nothing else in them. Any other test that has
  to change is a finding for the task's report.
- **The standing sets stay exactly as they are:** engine 2, render 7 plus
  1 skip, compared by
  `dart run tool/ci/expect_failures.dart --package <pkg> --root <pkg> <run.json>`
  (the run from `test --file-reporter json:<run.json>`), as CI does.
- **Every task ends green** in every package it touches and every package
  whose tests read what it changed:
  - `packages/jet_cad_floor_plan`, `apps/restaurant_demo`,
    `apps/floor_planner`: `flutter test`, `flutter analyze`, format;
  - `packages/jet_cad_2d` and `packages/jet_cad_2d_flutter`: through the
    standing comparison (and `flutter analyze` + format in Task 4);
  - `tool/ci`: `dart test`, analyze, format and `check_guide` whenever the
    guide or the probe moves (Task 5).
- **Fixtures** (spec's testing rule; CLAUDE.md's testing bar). A shared
  fixture `test/host/embedding_fixture.dart`, extending the zone fixture's
  idea (`test/host/zone_fixture.dart`):
  - a hand-made servable definition whose **box is off its base point**
    (e.g. box (300..1100, −200..400) mm about base (0, 0)), with an
    asymmetric top;
  - copies: one turned **30°**, one **mirrored** (det < 0) at 90°, one
    with a **non-uniform scale** (1.5, 0.8), one at 180° unmirrored, all
    **40 m off the origin**;
  - a **hidden** and a **locked** layer, a table on each;
  - two tables sharing a number, an unnumbered table, a table with
    non-finite corners;
  - a **non-identity camera** (panned, 0.37 px/mm) before every call.
  Expectations are computed in the test by the forward transform, not
  copied from the code; doubles use `closeTo`, relative 1e-12 (geometry)
  or 1e-6 px (screen).
- **Each named mutant is applied, seen red and reverted**, its killer
  named in the report (Ruling 49/50). Every mutant below belongs to exactly
  one task.
- **Never `git checkout` a file to revert it.** Copy it aside, or use
  `git show HEAD:path > path`.
- **Never commit an `analysis_options.yaml`.** Check `git status` before
  each commit.
- New public names enter `lib/jet_cad_floor_plan.dart`'s `show` lists and
  `test/host/barrel_test.dart` in the task that adds them; P-9's prefix
  and `final class` with `==`/`hashCode` for value types.

## Tasks

### Task 1 — a table's detail and `tableAt` (G-1, G-4)

**Builds:**
- `lib/src/host/table_detail.dart`: `final class FloorPlanTableDetail`
  exactly as G-1 lists (`table`, `center`, `size`, `rotation`, `mirrored`,
  `corners`, `layer`, `locked`, `data`; `data` is `const {}` until Slice
  2), with `==`, `hashCode`, `toString`.
- The decomposition of G-1: `rotation = atan2(b, a)`, `mirrored = det < 0`,
  `size = (box.width · |col0|, box.height · |col1|)`, `center` = the
  transform applied to the box's centre, `corners` from
  `TableCandidate.corners` normalised counter-clockwise.
- `FloorPlanController.tableDetails`: from `TablePicker.candidatesOf`
  (F-8) joined to `TableSurvey` by instance, ascending by handle, for the
  **active** plan; non-candidates (hidden layer, non-finite corners) get
  `center: null`, `size: null`, `corners: const []`, `rotation: 0`;
  `layer` is the instance's layer name, `locked` its lock. **Cached** by
  (active document, `commands.stateId`, `tables.mutationRevision`), as
  `_tables` is; the list is unmodifiable and identical between reads at
  the same key.
- `String? tableAt(Offset canvasPoint, {PointerDeviceKind kind =
  PointerDeviceKind.mouse})`: the active plan's `TablePicker.pick` at the
  camera's `screenToWorld` of the point (touch reach for
  `PointerDeviceKind.touch`), the hit's number, null for none or
  unnumbered.

**Tests** (`test/host/table_detail_test.dart`, `controller_test` for the
mode follow): **M-H1, M-H2, M-H3, M-H4, M-H13, M-H14, M-H15**, and
**M-H19b(tableAt)**: `tableAt` ignores the finger's reach (killer: a touch
point inside reach, outside the box). Also plain: a service move changes
`tableDetails` in the selection mode, not after switching back to design;
two reads at the same key are `identical`.

**Gates:** planner, demo, floor planner; engine and render through the
standing comparison.

### Task 2 — the public camera (G-2, G-3)

**Builds:**
- `lib/src/host/floor_plan_camera.dart`: `final class FloorPlanCamera`
  over a `ViewportTransform`: `scale`, `worldToCanvas`, `canvasToWorld`,
  `visibleWorld(Size)`; `==` by the matrix.
- The controller: the `@internal CameraController camera` is renamed
  `cameraController` (all internal uses, the tests and
  `apps/restaurant_demo/test/demo_test.dart`, mechanically); a public
  `ValueListenable<FloorPlanCamera> camera` derived from it (one wrapper
  per camera value, created on change, never per read).
- `canvasRect`: the views report their drawing area's **origin and size**
  after layout (extend `canvasMeasured`); `ValueListenable<Rect?>
  canvasRect` (global), null with no view mounted; `worldToGlobal`,
  `globalToWorld` (null with none).
- Constructor `minScale = 0.001`, `maxScale = 100` (documented),
  `ArgumentError` unless `0 < minScale < maxScale`, both finite; the
  `CameraController` built with them.
- **Fits clamp** to the bounds: `fitToView`, the start fit, `fitToTables`
  and the page fit pass through one clamp about the canvas centre.
- **The camera epoch:** an `int` the controller bumps on every fit
  request, `fitToTables`, `centerOn`, `zoomBy`, `panBy`; `PlannerView`'s
  post-frame `_fit` captures it when it schedules and returns when it has
  moved.
- Commands: `void panBy(Offset)` (always), `bool zoomBy(double factor,
  {Offset? focus})` (false with no measured canvas or a bad factor; focus
  default the canvas centre; clamped through `CameraController.zoomAt`),
  `void centerOn(Offset world, {double? scale})` queued like a fit (zone
  spec Z7's `_fitPending` path, last request wins).
- `FloorPlanView.userCamera` (default true): false switches off the
  user's pan, pinch and wheel zoom in that view (`CameraGestureDetector`
  not built, or built disabled), commands still act.

**Tests** (`test/host/camera_test.dart`, `seams_test`, `view_test`):
**M-H5, M-H6, M-H6b, M-H7**, **M-H19b(canvasRect)**: `canvasRect` stale
after the view moves without relayout (killer: a parent `Padding` change
that only repositions), **M-H19b(userCamera)**: `userCamera: false` still
pans (killer: a drag on the canvas leaves the camera unchanged). Plain:
`centerOn` before the first mount centres on the first frame; a
`fitToView` after `centerOn` wins and the reverse; `panBy` with no view.

**Gates:** planner, demo, floor planner; engine and render through the
standing comparison.

### Task 3 — the overlay layer, non-interactive (G-5, G-6, G-7, H-8)

**Builds:**
- `lib/src/host/table_overlay.dart`:
  - `final class FloorPlanTableOverlay` (`detail`, `selected`, `focused`,
    `status` — the **effective** status, a group's over the table's —
    `detailLevel`), `==`/`hashCode`;
  - `typedef FloorPlanTableOverlayBuilder`;
  - `final class FloorPlanOverlayLayout` (`anchor`, `size`,
    `maxNaturalSize`, `hideBelowScale`, `detailBreakpoints`,
    `interactive`), `const`, validated (`ArgumentError` on unordered or
    non-positive breakpoints); `enum FloorPlanOverlaySize { natural, box }`;
  - the widget `TableOverlayLayer` (internal) and its render object
    `RenderFloorPlanOverlays`: a `Flow`-like multi-child box; each child
    behind a `RepaintBoundary`, keyed by instance; per-child offset in its
    parent data recomputed in the camera listener from a per-table
    screen-box cache (rebuilt at document or mode rate; the per-frame
    pass writes reused `Float64List`s, no `Vector2`); `paint`,
    `hitTestChildren` and `applyPaintTransform` read that one offset;
    `natural`: layout once (loose, up to `maxNaturalSize`), camera change
    `markNeedsPaint` + `markNeedsSemanticsUpdate`; `box`: tight to the
    screen bounding box, camera change `markNeedsLayout`; culled off the
    canvas and below `hideBelowScale`; `debugAllocations`.
  - **Builder calls:** per table, only when that table's
    `FloorPlanTableOverlay` changes or the view rebuilds with a new
    builder; never on pan or zoom; a detail-level crossing rebuilds every
    overlay once.
- `PlannerView.tableOverlays` (a new slot) painted after the selection
  overlay, inside the canvas's input listeners, clipped to the canvas;
  `IgnorePointer` around it in this task (interactive is Task 4).
- `FloorPlanView.tableOverlayBuilder`, `tableOverlayLayout`,
  `tableOverlayModes` (default `{selection}`): the service view and, when
  asked, the shell pass the layer to their `PlannerView`.

**Tests** (`test/host/table_overlay_test.dart`): **M-H8, M-H9, M-H10,
M-H11, M-H12, M-H18, M-H19**, **M-H19b(design default)**: overlays shown
in the design mode by default (killer: a design-mode view with a builder
and default modes shows none). Plain: duplicate numbers keep two
overlays; a reset remounts (documented behaviour, pinned); the
render object's `debugAllocations` across 50 camera changes in steady
state is 0 per table; no builder → no layer in the tree, and the existing
`view_test` / `view_palette_test` read as today.

**Gates:** planner, demo, floor planner; engine and render through the
standing comparison.

### Task 4 — interactive overlays (G-5's pointers)

**Builds:**
- `jet_cad_2d_flutter`: a small public marker render object (e.g.
  `RenderInputClaim` behind a `InputClaim` widget, exported from the
  render barrel) and a helper that reports whether a `PointerDownEvent`'s
  hit path carried it; `InteractionLayer`, `CameraGestureDetector` ignore
  a pointer (down through up/cancel) whose down carried it.
- The floor plan: with `interactive: true` the overlay layer drops its
  `IgnorePointer` and wraps each child in the marker; the service view's
  secondary-click `Listener` honours it too.

**Tests** (render package: a marker test beside
`interaction_layer`'s tests; planner: `table_overlay_test`): **M-H16,
M-H17**; plain: a pan that starts off a badge pans; a pinch with one
finger on a badge does not start on that finger.

**Gates:** planner, demo, floor planner; **`jet_cad_2d_flutter` in full**
(`flutter test` through the standing comparison, `flutter analyze`,
format); engine through the standing comparison.

### Task 5 — the demo, docs, CI and the exit (the controller's)

- **Demo** (`apps/restaurant_demo`): the Salon's service view draws a
  badge per table through `tableOverlayBuilder` (guests and a minutes
  counter from the demo's random statuses, a dot below one detail
  breakpoint), with a "Badges" switch; one button centres on table 7
  through `centerOn`. Strings in en, de, tr. Demo tests for both.
- **Host guide:** a new section "Your own widgets on the tables" (G-1 to
  G-9: details, the camera, commands and bounds, `tableAt`, the builder,
  placement, detail levels, interactive overlays, lifetime, the cost) and
  § 4's camera sentence; marked *Unreleased*.
- **Host probe:** the guide's snippets (a builder, `centerOn`, a
  `worldToGlobal` use) in `tool/ci/host_probe/lib/main.dart`;
  `check_guide` green; one mutant: an edited probe snippet makes
  `check_guide` exit 1.
- **CI, invariant 1:** the host-probe job also analyses
  `git show v0.3.0:tool/ci/host_probe/lib/main.dart` against the commit
  under test (the checkout fetches tags); a `tool/ci` test pins the step's
  presence (as SC16/SC17 do).
- **CHANGELOG:** *Unreleased* gains Slice 1's names, the `@internal`
  rename, the clamped fits.
- **Results note** `docs/superpowers/notes/2026-10-09-embedding-slice-1-results.md`;
  **STATUS**; **the roadmap's row 14**.
- **Every gate**, `tool/ci` included, with the standing comparison; both
  web builds; the host probe locally at the full SHA.
- **Web smoke check** in Chromium (Playwright, `locale: 'en-US'`): the
  demo's Salon in Service with badges on; pan and zoom move them with
  their tables; a tap on a table still selects; no console error.
- **The overlays' cost, measured (R-2):** the demo's web build with
  badges on 100+ tables (a generated plan), frame times while panning, in
  the results note.

Then an independent code review of the whole range, its fixes, and the
merge on the human's word.

## Mutants per task

| Task | Mutants | Count |
|---|---|---|
| 1 | M-H1, M-H2, M-H3, M-H4, M-H13, M-H14, M-H15, M-H19b(tableAt) | 8 |
| 2 | M-H5, M-H6, M-H6b, M-H7, M-H19b(canvasRect), M-H19b(userCamera) | 6 |
| 3 | M-H8, M-H9, M-H10, M-H11, M-H12, M-H18, M-H19, M-H19b(design default) | 8 |
| 4 | M-H16, M-H17 | 2 |
| 5 | the probe snippet (check_guide) | 1 |

## Exit gate

- Task 5 green: every gate, the standing sets exact, both web builds, the
  smoke check, the probe locally and in CI (with invariant 1).
- Every named mutant above seen red and recorded.
- The independent review applied.
- **Owed to the human:** a look on a tablet and a terminal (badges,
  pan/zoom smoothness); the German and Turkish read of the demo's new
  strings.
- **Owed to Monépro:** B.1 should name `controller.camera` /
  `tableOverlayBuilder`; Q-H3 (overlay sizes and detail levels).
- **The merge into `main` happens on the human's word.**
