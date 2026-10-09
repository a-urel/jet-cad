# Slice 1, Task 2: the public camera (G-2, G-3), independent review

**Commit reviewed:** `03c6d66` (parent `85918c4`), branch `claude/exciting-pasteur-9m22jv`.
**Where:** my own clones, `/tmp/s1t2-review/repo` for the gates and `/tmp/s1t2-review/mut` for the mutants and probes, plus a worktree at `85918c4` for one check. Nothing in `/home/user/jet-cad` was edited apart from this file.
**Read:** CLAUDE.md, the plan's Global constraints and Task 2, the spec's P-1 to P-9, F-7, G-2, G-3 and the Slice 1 mutants, the zone spec's Z5, Z7 and Z8, the implementer's report, and `git diff 85918c4 03c6d66` in full.

## Verdict

**Approve with fixes.** The camera's mapping, the public listenable, the bounds, the clamped fits, the commands, `canvasRect` and `userCamera` are correct for every case the plan names. The rename is complete and mechanical. All six named mutants are killed, and 13 of my 15 own mutants are killed. All gates are green, and the standing sets match exactly.

Three things need attention before the slice closes:
- **R-1** is the implementer's open decision (F-3). My recommendation is to reverse it.
- **R-2** is a real hole in the epoch contract on one edge path, reproduced below.
- **R-3** is a first-frame ordering problem, also reproduced.

R-4 to R-8 are small.

## Findings

### R-1 (Medium, decision): a `panBy` before the first mount should not cancel the plan's own first fit

The implementer asked for a decision on this (choice 5, F-3). `_command()` clears `_fitOnStart`, so any `panBy` or acting `zoomBy` made before a plan's first frame leaves the camera at `_placeNominally`'s guess for a 1440 x 900 window, plus the pan. CM5 pins that behaviour.

Probe P3 (`zz_review_probe_test.dart`, mut clone) shows what this means for a host. With a view mounted, `c.load(json); c.panBy(Offset(5, 5));` leaves the new plan at scale **0.08143**, the nominal camera plus the pan. The same `load` without the pan fits the real canvas at **0.07745**. So the first frame of a freshly loaded plan depends on whether the host touched the camera. Its scale is the one for a 1440 x 900 window, whatever the real canvas is, so on a phone the plan is too large and off centre.

**Recommendation: keep the plan's first fit (constructor, `load`, `newPlan`).** The reasons:
1. G-3's epoch rule is about *requests*: "a camera command after a fit request wins". A plan's first fit is not a host request. It is the planner's own framing (Ruling 01-2, H3), and P-6 wants that look unchanged.
2. Before the first fit, a pan has no reference the host can know. It is relative to an internal 1440 x 900 placement that the host cannot see and that is not part of the API. A command whose result depends on an undocumented guess is not one a host can use.
3. Placing the camera before a view exists already has a well-defined tool: `centerOn(world, scale:)`, which is queued and resolved at the real canvas size (CM9 proves it). The guide can say: "before the first frame, place with `centerOn`; `panBy` and `zoomBy` act on the camera as shown."
4. `load(); panBy()` (or `newPlan(); panBy()`) quietly leaving a plan unframed is a trap that no test or log would show to a host.

**Concrete fix:**
- In `_command()`, drop the line `_fitOnStart = false`.
- In `_command()`, also set `_fitTarget = null` when it drops a pending request (`_fitPending` was true). Otherwise a dropped `fitToTables`/`centerOn` target would be picked up by the first fit that R-1 now keeps (`framingFor` reads `_fitTarget` whatever `_fitPending` says).
- Have the start fit skip the epoch check unless the start fit performs a pending *request* (see R-2 for where to keep that epoch).
- Rewrite CM5: `fitToView(); panBy(d)` before mount drops the request, and the first frame fits the page. Add a probe-style test: with a view mounted, `load(json); panBy(d)` ends at the page fit of the new plan.
- Document in `panBy`'s and `zoomBy`'s dartdoc that before a plan's first frame they are overwritten by the plan's own fit.

If the human prefers the current rule, R-2 still applies.

### R-2 (Low-Medium): the epoch is not captured when a fit becomes due on a view that has no size yet

`_PlannerViewState` captures the epoch in two places:
- in `_onFitRequest`, but only when `_size != null`;
- in the `LayoutBuilder`, when the view first gets a non-zero size.

A fit that becomes due while the view has no size has two sources: a plan's first fit on a view mounted at zero width or height, and `_onFitRequest` while `_size == null`, which sets `_fitted = false`. Such a fit captures the epoch only later, at the first sized layout. So a command made in between **loses**.

Reproduced (`zz_zero_test.dart`, mut clone):
1. Mount the view in a `SizedBox(width: 0)`.
2. Set the camera to `embeddingCamera()` and call `panBy(Offset(37.25, -11.5))`.
3. Resize the box to 1000.

Under CM5's own rule the camera should stay panned, `[0.37, 0, 0, -0.37, -14575, -9443]`. It ends at the page fit, `[0.0594, …, -2136.7, -1509.0]`. The same path applies to `fitToView(); panBy()` on a view that has not been sized yet.

This is reachable: a host panel that animates open from zero (`SizeTransition`, `AnimatedSize`), or a split pane at zero.

**Fix:** keep a field `int? _dueEpoch` in `_PlannerViewState`.
- Set it in `_onFitRequest` when `_size == null`: `_dueEpoch = widget.cameraEpoch?.call()`.
- Under the current rule, also set it in `initState` when `!_fitted`. Under R-1's rule, leave it null for a plain start fit.
- The `LayoutBuilder` fit then passes `_dueEpoch` instead of reading the epoch at layout time.

**Test:** the reproduction above, plus `fitToView(); panBy(d)` on a never-sized view. My mutant O3 (the start fit's epoch read at fit time) survives today. A test for R-3 kills it.

### R-3 (Low): the first `canvasRect` report comes before the start fit, so a command made on that report cancels the fit

`_check` is registered in `initState` and the start fit at layout, so both run in the same post-frame phase with `_check` first. A host that waits for the canvas (`canvasRect` becomes non-null) and then calls `zoomBy` therefore lands between the two.

Probe P4: a `canvasRect` listener that calls `zoomBy(2)` on its first non-null value. The result is scale **0.1629**, which is the nominal 0.0814 x 2. The start fit was dropped, and the plan sits at the 1440 x 900 guess, doubled.

The natural host pattern of "zoom in once the canvas is known" therefore always produces the wrong first view. `zoomBy` can only act once `canvasRect` is set, so this is the only way it can meet a start fit.

**Fix:** make the first report follow the first fit, so that "`canvasRect` is non-null" implies "the view's first fit has been performed". For example:
- schedule the first `_check` from the start-fit post-frame callback (after `_fit`) when `!_fitted` at `initState`;
- or let `_check` skip reporting until `_fitted` is set and the scheduled fit has run.

**Test:** a listener `zoomBy(2)` on the first report ends at twice the page-fit scale, about the canvas centre.

### R-4 (Low): `canvasRect` lags a mode switch by one frame

From `setMode` until the next frame's post-frame phase, `canvasRect` still holds the old mode's canvas (probe P5):
- design `Rect.fromLTRB(264, 68, 1160, 900)`;
- the selection canvas, `Rect.fromLTRB(0, 44, 1440, 900)`, arrives one frame later.

The camera itself is reframed synchronously by R-13. In that gap:
- `zoomBy` with no focus zooms about the design canvas's centre (448, 416) instead of the selection canvas's (720, 428);
- `worldToGlobal` adds the old origin to an already reframed camera. An external overlay listening to `camera` is drawn one frame off by (−264, −24).

CR1's "never null across a switch" holds. This is a one-frame staleness, not a null.

**Fix (cheap):** document on `canvasRect` and `zoomBy` that after `setMode` the canvas is known from the end of the next frame. **Better:** keep the last rect per mode in the controller, and make `zoomBy`'s default focus and `worldToGlobal` use the active mode's last rect, so they are correct after the first visit to each mode.

### R-5 (Info): the second `FloorPlanView` crash is pre-existing and already an assumption

Verified at `85918c4` in a worktree: two `FloorPlanView`s over one controller in the selection mode throw `Bad state: the dispatcher already has an expander (spec 06 D2)`. `03c6d66` gives the same result (probe P1). The zone spec's Z7 and V-12 already assume one view per controller.

`canvasRect`'s multi-view registry is therefore untestable for now, and harmless. **Action (Task 5):** the host guide should state "one `FloorPlanView` per controller".

### R-6 (Nit): the clamp's absolute tolerance makes a very small `minScale` ineffective

`clampCameraScale` and `CameraController.zoomAt` compare scales with `Tolerance.standard`, which is absolute 1e-9. For a host `minScale` below about 1e-8 the bound is coarse. At `minScale: 1e-10`, `compare(5e-10, 1e-10) == 0`, so the bound is not applied at all. Today's 0.001 is unaffected.

**Fix:** either document a practical floor on `minScale` (for example "≥ 1e-6") and reject below it in the constructor, or compare relatively (`scale / bound` against 1). This is consistent with `zoomAt`, so documenting is enough.

### R-7 (Nit): the bare shell's own nominal placement is not clamped

`planner_shell.dart:524-529` (`_nominalFit`) feeds the standalone planner's first frame and is not clamped. It is outside the host API, lasts one frame, and its camera's bounds are the planner's own. I mention it only because the task said "every fit path". No action needed.

### R-8 (Nit): a reporter replaced while a rect is registered leaves a stale entry

In `_PlannerViewState`, if `onCanvasPlaced` changes from a function to null (or to another function), the old reporter is never told null. `_check` stops, and `dispose` calls the *new* reporter. `FloorPlanView` always passes `c.canvasPlaced`, and a controller swap remounts the shell by `ObjectKey(document)`, so this is not reachable today.

**Fix if wanted:** in `didUpdateWidget`, when `oldWidget.onCanvasPlaced != widget.onCanvasPlaced && _placed != null`, call `oldWidget.onCanvasPlaced?.call(this, null)` and reset `_placed`.

## What I checked and found correct

- **`FloorPlanCamera`:**
  - `worldToCanvas` is `(a·x + c·y + e, b·x + d·y + f)`, with the y flip carried by `d < 0`. `canvasToWorld` uses the inverse, computed once per value.
  - `visibleWorld` takes `top` as the least y, and CM1 pins it.
  - `==`/`hashCode` use the six coefficients exactly. `-0.0` against `0.0` is consistent: I checked that `Object.hash(0.0, 1) == Object.hash(-0.0, 1)`.
  - The `@internal` constructor is fine (choice 2).
- **The public `camera`:**
  - Exactly one wrapper per `ViewportTransform` object, built at the first read. No read in steady state allocates.
  - Listeners are the camera controller's own, so a listener that reads `camera.value` inside its callback sees the new value, and the identical object afterwards (probe P6).
  - Mutant O8, a wrapper cached forever, is killed by CM3, CM6, CM7, CM11 and B4.
- **The rename:**
  - lib: no `FloorPlanController.camera` use remains (grep over `packages/jet_cad_floor_plan/lib`, `apps/*/lib`, `tool/`).
  - Tests: for every one of the 13 edited test files, the file at `03c6d66`, with `cameraController` mapped back to `camera` and all whitespace stripped, is **byte-identical** to the file at `85918c4`. So only the member name changed, plus the formatter's line breaks.
  - `barrel_test`: one name added to B1's set (the allowed edit), and B4 appended.
- **P-1:**
  - Every new parameter is named and optional: `FloorPlanController` (`minScale`, `maxScale`), `FloorPlanView.userCamera`, and the internal `PlannerShell`, `PlannerView`, `ServiceView`, `TableSelectTool` and `frameTables`.
  - No existing `==`/`hashCode`/`toString` was touched, and `FloorPlanTable` is untouched.
  - The 0.3.0 probe does not use `camera`.
  - No golden, no allocation invariant and no `analysis_options.yaml` is in the diff.
- **P-6:**
  - With the default bounds, a page fit at any realistic canvas lies far inside [0.001, 100], so the clamp returns the *same object*. The full suites pass unchanged.
  - Only degenerate cases change: a page-less plan smaller than about 9 mm fitted to 900 px (scale > 100), or a canvas a few pixels wide. In both, the user's own zoom was already bounded, so the clamp is a fix (spec G-3 accepts it).
- **Fits clamped:** checked on every path.
  - `_placeNominally` (O12 is killed by CM7).
  - The start fit and `fitToView` (M-H6b).
  - `fitToTables`: clamped in `frameTables` with the controller's bounds, then again by the view, where it is a no-op (F-5).
  - `centerOn` (CM11, at a scale of 1e6).
  - The clamp is about the canvas centre (O1 is killed).
- **The epoch:**
  - It is captured when a sized view schedules a fit, and a later `panBy`/`zoomBy`/request drops it (M-H7, O2).
  - R-13's reframing (`_reframe`, `canvasMeasured`) pans the camera directly and does not move the epoch, so a mode switch never cancels a fit. A fit pending across a switch is taken by the new view through `takeFitOnStart`.
  - `load`/`newPlan` replace the shell by key, so an old scheduled fit hits `!mounted`, and `_replaceDesign` clears the target.
  - `_request`'s own increment is redundant: O9 survives as an *equivalent* mutant, because `framingFor` is read when a fit is performed, so two requests in one frame give the same camera. Keep it for the spec's wording.
- **Commands:**
  - `panBy` acts with no view and rejects a non-finite delta.
  - `zoomBy` is false with no canvas or a bad factor or focus, defaults to the *local* canvas centre (O7, the global centre, is killed), and is clamped (M-H6).
  - `centerOn` is queued; the last request wins in both orders (CM10, CM11), and the scale argument is honoured (O6 is killed).
- **`canvasRect`:**
  - It is the interaction layer's global rect in both modes (CR1). O14, a local origin, is killed.
  - It follows a padding-only move (M-H19b).
  - It is null after unmount (O4 is killed) and never null across a switch (O13 is killed).
  - Per-frame cost is one `localToGlobal` and one `Rect`, plus one closure for the re-registered callback. That is O(1) per frame and nothing per entity, and it never requests a frame. It runs only for views given a reporter, so the standalone planner and the invariants are unaffected.
- **`worldToGlobal`/`globalToWorld`:** they add the canvas origin (O5 is killed by CR2 and B4).
- **`userCamera: false`:**
  - Selection mode: no `CameraGestureDetector`; a floor drag is spent; middle drag, wheel and pinch are inert (UC1).
  - Design mode: the same (UC2).
  - A **table drag with moves on still moves the table**: probe P2 moved table 1 by (162.2, 0) mm with the camera unchanged.
  - Taps still report (UC1).
  - Toggling keeps the interaction layer's state (the `GlobalKey`), and toggling back to true pans again (probe P7).
  - The value is read live at each press (O10, a value captured at build, is killed by UC1).
  - No other camera writer exists: grep for `panBy`/`zoomAt`/`camera.value =` finds only the tool, the detector, `_fit` and R-13.
- **Barrel B4:** it reaches `FloorPlanCamera`, the bounds, `canvasRect`, `worldToGlobal`/`globalToWorld`, `panBy`/`zoomBy`/`centerOn`, `visibleWorld` and `userCamera` through `package:jet_cad_floor_plan/jet_cad_floor_plan.dart` alone.

## Mutants

Each mutant was applied by `/tmp/s1t2-review/mutate.py`, which copies the file aside, replaces exactly one occurrence, runs `flutter test --no-pub test/host/camera_test.dart test/host/barrel_test.dart`, then restores the file from the copy and checks it with `filecmp`. `restored=True` every time. No `git checkout` was used.

| Mutant | Edit | Result | Killer(s) |
|---|---|---|---|
| M-H5 | `worldToCanvas` y: `- _m.d * world.dy` | killed | CM1, CM3, CM7, CM9, CM10, CM11, CR2 |
| M-H6 | `zoomBy` zooms an unbounded copy, then assigns | killed | CM6 |
| M-H6b | `_fit` clamps with `0, double.infinity` | killed | CM7, CM11 |
| M-H7 | `_fit`'s epoch check removed | killed | CM8 |
| M-H19b(canvasRect) | `_check` reports only on a size change | killed | CR2 |
| M-H19b(userCamera) | the tool's `if (!_pans)` becomes `if (false)` | killed | UC1 |
| O1 | clamp about the canvas origin, not its centre | killed | CM7, CM11 |
| O2 | `_onFitRequest` reads the epoch inside the callback | killed | CM8 |
| O3 | the start fit reads the epoch inside the callback | **survived** | none (see R-2/R-3: a first-report `zoomBy` test kills it) |
| O4 | `dispose` does not report null | killed | CR1 |
| O5 | `worldToGlobal` drops `rect.topLeft` | killed | CR2, B4 |
| O6 | `centerOn` drops `scale` | killed | CM9, CM10, CM11, B4 |
| O7 | `zoomBy` focus default `rect.center` (global) | killed | CM6, CM8, B4 |
| O8 | the public wrapper is built once and never refreshed | killed | CM3, CM6, CM7, CM11, B4 |
| O9 | `_request` does not bump the epoch | **survived (equivalent)** | none: `framingFor` is read when the fit is performed |
| O10 | `FloorPlanView` captures `userCamera` at build | killed | UC1 |
| O11 | `_command` keeps `_fitOnStart` (R-1's alternative) | killed | CM5 |
| O12 | `_placeNominally` unclamped | killed | CM7 |
| O13 | a view leaving sets `canvasRect` null outright | killed | CR1 |
| O14 | `_check` reports a local rect (`Offset.zero & size`) | killed | CR1, CR2 |

Score: all 6 named mutants are killed; 13 of 15 own mutants are killed (1 survivor, 1 equivalent).

## Probes (mut clone, not for commit)

`test/host/zz_review_probe_test.dart` and `test/host/zz_zero_test.dart` in `/tmp/s1t2-review/mut`, and `zz_two_views_test.dart` in the `85918c4` worktree. Output lines as printed:
- P1: `P1 exception: Bad state: the dispatcher already has an expander (spec 06 D2)`. The parent prints `PARENT two views: Bad state: the dispatcher already has an expander (spec 06 D2)`.
- P2: `P2 moved by Offset(162.2, 0.0)`.
- P3: `P3 after load+panBy: [0.08142857142857142, 0.0, 0.0, -0.08142857142857142, -2892.46…, -2065.21…]`. P3b, load alone: `[0.07744761904761904, …, -2720.61…, -1969.00…]`.
- P4: `P4 nominal scale 0.08142857142857142; after mount 0.16285714285714284`.
- P5: `P5 design Rect.fromLTRB(264.0, 68.0, 1160.0, 900.0) stale-after-setMode Rect.fromLTRB(264.0, 68.0, 1160.0, 900.0) service Rect.fromLTRB(0.0, 44.0, 1440.0, 900.0)`.
- Z: `Z want (panned) [0.37, 0.0, 0.0, -0.37, -14575.0, -9443.0]` / `got [0.05935238095238095, 0.0, 0.0, -0.05935238095238095, -2136.7295238095235, -1508.9561904761904]`.

## Gates (`/tmp/s1t2-review/repo` at `03c6d66`; `PATH=/root/sdk/flutter/bin:$PATH`, `CI=true`)

**`packages/jet_cad_floor_plan`**
- `flutter test`: `07:33 +1468: All tests passed!`, exit 0
- `flutter analyze`: `No issues found! (ran in 9.6s)`, exit 0
- `dart format --output=none --set-exit-if-changed .`: `Formatted 248 files (0 changed) in 1.41 seconds.`, exit 0

**`apps/restaurant_demo`**
- test: `00:26 +39: All tests passed!`, exit 0
- analyze: `No issues found! (ran in 4.5s)`, exit 0
- format: `Formatted 4 files (0 changed) in 0.06 seconds.`, exit 0

**`apps/floor_planner`**
- test: `01:38 +212: All tests passed!`, exit 0
- analyze: `No issues found! (ran in 5.7s)`, exit 0
- format: `Formatted 47 files (0 changed) in 0.22 seconds.`, exit 0

**`packages/jet_cad_2d`**
- `dart test --file-reporter json:engine.json` exited 1, with 2 error/failure results in the JSON.
- `dart run tool/ci/expect_failures.dart --package packages/jet_cad_2d --root packages/jet_cad_2d engine.json` printed `packages/jet_cad_2d: 1255 tests; the standing failures and skips, exactly`, exit 0.

**`packages/jet_cad_2d_flutter`**
- `flutter test --file-reporter json:render.json` exited 1, with 7 error/failure results in the JSON.
- The same comparison in path form printed `packages/jet_cad_2d_flutter: 1363 tests; the standing failures and skips, exactly`, exit 0.

`git status --short` in the review clone after the gates: empty.

## Fixes (controller's)

**Commit:** `adaa2bc` on `claude/exciting-pasteur-9m22jv` (parent `b420493`). Not pushed. Files: `floor_plan_controller.dart`, `floor_plan_view.dart`, `service_view.dart`, `planner_shell.dart`, `planner_view.dart`, `test/host/camera_test.dart`. The only existing test edited is CM5, which was this task's own test (allowed by the R-1 ruling). Every other test is unedited.

**Mutants.** A runner script (in the session scratchpad) copied the file aside and replaced exactly one occurrence. It then ran `flutter test --no-pub test/host/camera_test.dart test/host/barrel_test.dart` and restored the file from the copy, checked with `filecmp`. It printed `restored=True` every time. No `git checkout` was used. All 12 mutants are red; the lines below are copied from the logs.

### R-1 (accepted, the reviewer's recommendation)

**Ruling:** a `panBy` or `zoomBy` before a plan's first frame does not cancel that plan's own fit. A command still drops a pending explicit request (`fitToView`, `fitToTables`, `centerOn`).

**Changed:**
- `_command()` no longer sets `_fitOnStart = false`. When it drops a pending request it also sets `_fitTarget = null`, so the plan's own fit frames the page and not the dropped target.
- The view needs to know whether its start fit is the plan's own fit (no epoch) or only a request (an epoch). The controller cannot re-ask the fit instead: `takeFitOnStart()` is used by existing tests (V7e, V7h, CZ5) to mean "already shown and fitted". So the information is passed down:
  - a new `@internal owesFirstFit` on the controller, read by `FloorPlanView` before `takeFitOnStart()`;
  - a new `startFitIsRequest` on `ServiceView`, `PlannerShell` and `PlannerView` (default false).
- `PlannerView`:
  - the plan's own first fit is scheduled with a null epoch, so no command cancels it;
  - a request heard while that fit is still owed merges into it, and a later command clears the request's target, so the fit frames the page.
- Documented on `panBy`, `zoomBy`, `_command`, `_fitOnStart` and `owesFirstFit`. The rule is: before a plan's first frame, the plan's own fit overwrites `panBy`/`zoomBy`, so place the camera with `centerOn`. The guide comes in Task 5.

**Tests:**
- **CM5** (rewritten): `centerOn(3, scale: 0.2); panBy(d)` with no view acts at once, and the first frame fits the page. `fitToTables({'2'}); panBy(d)` gives the page too.
- **CM12**: with a view mounted, `load(json); panBy(5,5)` ends at the new plan's page fit (probe P3).
- **CM13**: a view mounted 0 wide owes the plan's fit. A `panBy` before it gets a size does not cancel the fit, and the page is fitted at 1000 wide.

**Mutant red lines:**
- `_command` sets `_fitOnStart = false` again → CM5 and CM12: `Which: at location [0] is <0.08142857142857142> instead of <0.07744761904761904>` / `the plan's own fit, not centerOn's`
- `_command` keeps `_fitTarget` → CM5: `Which: at location [0] is <0.2> instead of <0.07744761904761904>` / `the plan's own fit, not centerOn's`
- `PlannerView._ownFit = false` (the own fit takes an epoch) → CM13: `Which: at location [0] is <0.37> instead of <0.05935238095238095>`
- `FloorPlanView._fitIsRequest = true` → CM13: the same line

### R-2

**Ruling:** capture the epoch when the fit becomes due. After R-1 the test has to use a pending *explicit* request.

**Changed:** `PlannerView._dueEpoch` is taken in two places:
- in `initState`, when the view is created owing a requested start fit;
- in `_onFitRequest`, when the view has no size.

The layout-scheduled fit uses `_dueEpoch` (null for the plan's own fit) and no longer reads the epoch at layout.

**Test CM14:**
- (a) Mount at 1000, unmount, `fitToView()` with no view, mount 0 wide, `panBy(d)`, resize to 1000: the pan wins. This is the epoch taken at `initState`.
- (b) Mount at 1000, shrink to 0 wide, `resetLayout()` (a fresh service view with no size and no fit owed), `fitToView()`, `panBy(d)`, resize: the pan wins. This is the epoch taken at `_onFitRequest`, the reviewer's reproduction recast for R-1.

**Mutant red lines:**
- The epoch read at layout (the old code) → CM14: `Expected: [0.37, 0.0, 0.0, -0.37, -14575.0, -9443.0]` / `Which: at location [0] is <0.05935238095238095> instead of <0.37>` / `a request owed from the start`
- No `initState` capture → CM14: the same lines, `a request owed from the start`
- No `_onFitRequest` capture → CM14: the same lines, `a request heard with no size`
- **O3, the reviewer's surviving mutant, is now killed.** The start fit reads the epoch inside its callback (`_fit(size, widget.cameraEpoch?.call())`) → CM14: `Expected: [0.37, 0.0, 0.0, -0.37, -14575.0, -9443.0]` / `Which: at location [0] is <0.05935238095238095> instead of <0.37>` / `a request owed from the start`

### R-3

**Ruling:** the first `canvasRect` report comes only after the view's first fit.

**Changed:**
- `_check` reports only after the first fit has run. While `_placed` is null, it holds while the fit is still owed (`!_fitted`, the view has no size) or scheduled but not yet run (`_fitAhead`).
- The layout-scheduled fit's callback runs `_fit` and then `_report()`, in the same post-frame phase. So with a fit pending across a mode switch, `canvasRect` is still never null.
- A view with no size reports nothing.
- Documented on `canvasRect`, `zoomBy` and `onCanvasPlaced`.

**Tests:**
- **CR3**: a listener calls `zoomBy(2)` on the first non-null `canvasRect`. The result is the page fit scaled by 2 about the canvas centre, worked out by hand. This is probe P4. Under R-1 the own fit would overwrite a zoom made before it, so without the fix the result is 1×, not the nominal 2× the probe showed.
- **CM13**: also asserts `canvasRect` is null at 0 wide.

**Mutant red line:** `_check` reports at once (`_report();`) →
- CR3: `Which: at location [0] is <0.07744761904761904> which differs by <0.07744761904761904>`
- CM13: `Expected: null` / `Actual: Rect:<Rect.fromLTRB(0.0, 44.0, 0.0, 700.0)>` / `no size: no report (R-3)`

### R-4

**Ruling:** keep the last rect per mode; otherwise document the lag. The per-mode rect was chosen. It costs one map and three lines.

**Changed:**
- `canvasPlaced` records each rect under the current mode (`_canvasIn`).
- `setMode`, after `_reframe` and only while a view is mounted (`canvasRect` non-null), sets `canvasRect` to the new mode's last rect. `zoomBy`'s default focus and `worldToGlobal` are then right from the switch.
- A mode no view has shown yet keeps the old rect until the end of the next frame. This is documented on `canvasRect`.

**Test CR4:** design → selection (both laid out), then back:
- `setMode(design)` gives the design rect at once, and `setMode(selection)` gives the service rect at once;
- `worldToGlobal` read right after the switch equals its value two frames later.

**Mutant red line:** the assignment in `setMode` removed → CR4: `Expected: Rect:<Rect.fromLTRB(264.0, 68.0, 1160.0, 900.0)>` / `Actual: Rect:<Rect.fromLTRB(0.0, 44.0, 1440.0, 900.0)>` / `into design, at once`

### R-6

**Ruling:** compare relatively, or validate a documented floor. A floor was chosen.

**Why:** a relative compare in `clampCameraScale` alone would leave `CameraController.zoomAt` absolute. That covers the user's pinch and `zoomBy`, and it lives in the engine, which this task does not touch. So `zoomBy` would still pass a bound of 1e-9.

**Changed:** the constructor throws an `ArgumentError` unless `1e-6 <= minScale`. The floor is 1000 × the tolerance of 1e-9 and is documented on the constructor. This narrows the spec's `0 < minScale`; the change is noted here for the spec's owner.

**Test CM15:**
- 1e-9, 1e-10 and 9.99e-7 throw;
- 1e-6 is accepted, and `zoomBy(1e-12)` lands on 1e-6.

**Mutant red line:** the old `minScale <= 0` check → CM15: `Expected: throws <Instance of 'ArgumentError'>` / `Which: returned <Instance of 'FloorPlanController'>`

### R-8

**Ruling:** apply the fix if it is small, and test it if reachable. The fix is the reviewer's, verbatim: `didUpdateWidget` tells the old reporter null and resets `_placed`. The new reporter then hears the rect at the end of the frame.

**Reachable:** not through `FloorPlanView`, whose reporter is always the controller's (equal) tear-off. It is reachable through `PlannerShell(onCanvasPlaced:)`.

**Test CR5:** a bare `PlannerShell` with reporter A, then B, then null.
- A hears `[rect, null]`.
- B hears `[rect]` and then `[rect, null]`.

**Mutant red line:** the condition becomes `false` → CR5: `Expected: [Rect:Rect.fromLTRB(264.0, 68.0, 520.0, 600.0), null]` / `Actual: [Rect:Rect.fromLTRB(264.0, 68.0, 520.0, 600.0)]` / `the old reporter`

### R-5, R-7

- R-5 goes to the guide ("one `FloorPlanView` per controller", Task 5).
- R-7: no action.

### Gates (`/home/user/jet-cad` at `adaa2bc`'s tree; `PATH=/root/sdk/flutter/bin:$PATH`, `CI=true`)

**`packages/jet_cad_floor_plan`**
- `flutter test`: `04:29 +1497: All tests passed!`, exit 0
- `flutter analyze`: `No issues found! (ran in 5.4s)`, exit 0
- `dart format --output=none --set-exit-if-changed .`: `Formatted 250 files (0 changed) in 1.37 seconds.`, exit 0

**`apps/restaurant_demo`**
- test: `00:22 +39: All tests passed!`, exit 0
- analyze: `No issues found! (ran in 4.4s)`, exit 0
- format: `Formatted 4 files (0 changed) in 0.05 seconds.`, exit 0

**`apps/floor_planner`**
- test: `01:31 +212: All tests passed!`, exit 0
- analyze: `No issues found! (ran in 4.6s)`, exit 0
- format: `Formatted 47 files (0 changed) in 0.24 seconds.`, exit 0

The floor-plan count of 1497 includes the 7 new tests. The count at `b420493` was not re-run here, so 1490 is arithmetic, not measured. `git status --short` was empty after the commit. No `analysis_options.yaml` was touched.
