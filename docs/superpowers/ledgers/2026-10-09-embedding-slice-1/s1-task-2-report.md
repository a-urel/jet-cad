# Slice 1, Task 2: the public camera (G-2, G-3), report

**Commit:** `03c6d66` on `claude/exciting-pasteur-9m22jv` (parent `85918c4`). Not pushed.

## What was built

| File | What |
|---|---|
| `packages/jet_cad_floor_plan/lib/src/host/floor_plan_camera.dart` (new) | `final class FloorPlanCamera`, `@immutable`, over a `ViewportTransform`. It provides `scale`, `worldToCanvas`, `canvasToWorld` (no `Vector2`, the inverse is computed once per value), `visibleWorld(Size) → Rect` (world mm, y up, `top` is the least y), `==`/`hashCode` on the six matrix coefficients compared exactly, and `toString`. The constructor is `@internal`. |
| `lib/src/camera_bounds.dart` (new) | `clampCameraScale(camera, canvas, minScale:, maxScale:)` is the single clamp. It scales about the canvas centre and returns **the same object** when the camera is already within bounds, so seams SM3's `same(framed)` still holds. The bound check uses `Tolerance.standard`, the same as `CameraController.zoomAt`. |
| `lib/src/host/floor_plan_controller.dart` | Factory gains `minScale = 0.001`, `maxScale = 100`, with an `ArgumentError` before anything is built. `@internal camera` becomes `cameraController`, built with the bounds. New `ValueListenable<FloorPlanCamera> camera`, `canvasRect`, `worldToGlobal`, `globalToWorld`, `@internal canvasPlaced`, `@internal cameraEpoch`, `centerOn`, `panBy` and `zoomBy`. The fit target is now a sealed `_FitTarget` (`_Tables` or `_Centre`), and `framingFor` resolves both. `_placeNominally` goes through the clamp. |
| `lib/src/planner_view.dart` | `_fit(size, epoch)` returns early when the epoch moved, and clamps to `widget.camera.minScale/maxScale`. The start fit and `_onFitRequest` capture the epoch when they schedule. `userCamera` (no `CameraGestureDetector` when false). The drawing-area subtree has a `GlobalKey`, so toggling `userCamera` reparents it and does not remount it. `onCanvasPlaced` runs a post-frame check that re-registers itself and reports the area's global rect whenever it changes, then null on dispose. |
| `lib/src/planner_shell.dart` | Forwards `cameraEpoch`, `userCamera` and `onCanvasPlaced` to its `PlannerView`. |
| `lib/src/host/service_view.dart` | `bool Function() userCamera`: read at build for the `PlannerView` and at press by the tool. Forwards the epoch and `canvasPlaced`. Its 9 uses of `_c.camera` are now `_c.cameraController`. |
| `lib/src/service/table_select_tool.dart` | Gains `userCamera` (default `() => true`), read at press. With false, a drag that would pan (empty floor, or any table when moves are off) is spent. |
| `lib/src/host/floor_plan_view.dart` | `FloorPlanView.userCamera = true`, documented. Passes `cameraController`, the epoch and `canvasPlaced` to both modes. |
| `lib/src/host/table_fit.dart` | `frameTables` gains optional `{minScale = kMinScale, maxScale = kMaxScale}`, and `framingFor` passes the controller's bounds. TF4 is untouched and green. |
| `lib/jet_cad_floor_plan.dart` | `export 'src/host/floor_plan_camera.dart' show FloorPlanCamera;` |
| `test/host/camera_test.dart` (new) | CM1–CM11, CR1, CR2, UC1, UC2 (15 tests), using `embedding_fixture.dart` and its non-identity camera. |
| `test/host/barrel_test.dart` | B1's pinned set gains `'FloorPlanCamera'`. **B4** is appended: the new API reached through the barrel alone. |

## Choices the spec and plan left open

1. **The public wrapper is lazy.** One `FloorPlanCamera` exists per `ViewportTransform` object. It is built at the first read after a change and kept while `cameraController.value` is the identical object, so two reads at one value are `identical`. That meets "one wrapper per camera value, never per read". It is not "created on change": a pan frame nobody reads allocates nothing. The listenable delegates `add`/`removeListener` to the camera controller.
2. **The `FloorPlanCamera` constructor is `@internal`.** It takes the engine's `ViewportTransform`, which the barrel does not export. As a result a host cannot build a camera in its own tests. That could become a public constructor later if a host asks for one.
3. **`canvasPlaced` sits beside `canvasMeasured` instead of extending it.** `canvasMeasured` is R-13's once-per-plan origin, measured relative to the view. `canvasRect` needs global coordinates and has to follow every move. Merging the two would change R-13's timing. Every `PlannerView` given a reporter checks its drawing area once per frame that happens: a post-frame callback that re-registers itself and asks for no frame, then one `localToGlobal`, O(depth) per frame and nothing per entity. That is why a move made by a parent's `Padding`, which causes no relayout (CR2), is still seen. The standalone floor-planner shell passes no reporter and runs no check.
4. **`canvasRect` is a per-view registry.** It holds the last reporter's rect. When a view goes, the value changes at the end of that frame and never while the tree is locked. The new value is the last reporter among the views left, or null when none is left. A mode switch's new view reports earlier in the same post-frame phase, so listeners never hear a null between the two views (CR1 checks this).
5. **`panBy` and an acting `zoomBy` drop any fit not yet performed.** This covers a pending request and also a new plan's first fit (`_fitPending = _fitOnStart = false`), as well as moving the epoch. The spec says only "a camera command after a fit request wins". Applied consistently, a `panBy` made before the first mount means the next view keeps the panned camera and does not fit the page (CM5). Flagged for review.
6. **`centerOn` is a fit target (`_Centre`).** It is queued exactly like `fitToView`: `_fitPending`, the epoch, `_fits.bump()`, and the last request wins. It is resolved in `framingFor` at the canvas size when the fit is performed. With no `scale`, it keeps the camera's scale as of that moment. The view's clamp then applies about the centre. A non-finite world, or a non-finite or non-positive scale, throws `ArgumentError`.
7. **`panBy` with a non-finite delta throws `ArgumentError`.** Otherwise the camera would be poisoned. `zoomBy` returns false for a non-finite focus and returns true at a bound even when nothing moves, because the spec lists only "no canvas, bad factor" as false.
8. **The nominal placement (`_placeNominally`) is clamped too.** The camera is therefore inside the bounds from construction (CM7).
9. **With `userCamera: false`, a floor drag in the selection mode is spent.** It does not pan, and nothing else happens either, the same as a drag on a locked table. Taps, long presses and table moves are unchanged.
10. **No public `minScale`/`maxScale` getters.** The spec names none (R-1). The bounds are visible through the `@internal cameraController`.

## The rename's extent

`FloorPlanController`'s `@internal camera` is now `cameraController`. The other objects' cameras (`PlannerView.camera`, `PlannerShell.camera`, the rigs' `ctx.camera`, `view.camera` in the shell tests) are untouched.
- lib: `floor_plan_controller.dart` (the field, `_placeNominally`, `_reframe`, `canvasMeasured`, `tableAt`, `dispose`), `service_view.dart` (9), `floor_plan_view.dart` (1).
- Tests: only the member name changed. Counts are `+` lines in the commit. `dart format` reflowed a few lines in `view_test` and `demo_test`, line breaks only. A word-diff before formatting showed nothing but `camera` → `cameraController`.
  - `apps/restaurant_demo/test/demo_test.dart`: 12
  - `test/host/view_test.dart`: 58, which is 55 renames plus reflowed lines
  - `test/host/table_groups_look_test.dart`: 7
  - `test/host/controller_test.dart`: 6
  - `test/host/table_detail_test.dart`: 6
  - `test/host/table_groups_gesture_test.dart`: 4
  - `test/host/status_caption_test.dart`: 3
  - `test/host/view_palette_test.dart`: 3
  - `test/service/service_options_test.dart`: 3
  - `test/host/table_groups_toolbar_test.dart`: 2
  - `test/host/table_groups_context_test.dart`: 1
  - `test/dark_canvas_test.dart`: 1
  - `test/l10n/determinism_test.dart`: 1
- No other existing test was edited, apart from `barrel_test`'s pinned set (the allowed edit) and the appended B4.

## Mutants

Each mutant was applied by a script that copied the file aside and replaced exactly one occurrence. It then ran `flutter test test/host/camera_test.dart`, which exited 1 every time, and restored the file from the copy (`filecmp` true every time). No `git checkout` was used. All of them were run again on the final code before the commit. The red lines below are copied from those logs.

| Mutant | Edit | Killer | Red line |
|---|---|---|---|
| M-H5 | `worldToCanvas`: `_m.b * x - _m.d * y + _m.f` (y flip dropped) | **CM1** (also CM3, CM10, CM11) | `Expected: a numeric value within <0.000001> of <396.95706005997636>` / `Actual: <-19259.957060059976>` / `table 1: y` |
| M-H6 | `zoomBy` zooms an unbounded `CameraController(value)` copy | **CM6** | `Expected: a numeric value within <1e-12> of <0.5>` / `Actual: <4.625>` / `max` |
| M-H6b | `_fit` clamps with `minScale: 0, maxScale: double.infinity` | **CM7** (also CM11) | `Expected: a numeric value within <1e-15> of <0.01>` / `Actual: <0.07744761904761904>` / `start fit` |
| M-H7 | `_fit`'s epoch line removed | **CM8** | `Expected: [0.37, 0.0, 0.0, -0.37, -14575.0, -9443.0]` / `Which: at location [0] is <0.07744761904761904> instead of <0.37>` / `panBy after fitToView` |
| M-H19b(canvasRect) | `_check` reports only when the size changes (`rect.size != _placed?.size`) | **CR2** | `Expected: Rect:<Rect.fromLTRB(130.0, 119.0, 1130.0, 775.0)>` / `Actual: Rect:<Rect.fromLTRB(10.0, 64.0, 1010.0, 720.0)>` |
| M-H19b(userCamera) | the tool's `if (!_pans)` → `if (false)` (a floor drag still pans) | **UC1** | `Expected: same instance as <Instance of 'ViewportTransform'>` / `Actual: <Instance of 'ViewportTransform'>` / `floor drag` |
| M-H19b(userCamera), variant b | `PlannerView._userCamera` always builds the detector | UC1, UC2 | `Expected: no matching candidates` / `Actual: _TypeWidgetFinder:<Found 1 widget with type "CameraGestureDetector" …>` |

CR2's premise was checked once with a temporary `debugPrint` in `PlannerView`'s `LayoutBuilder`, restored from a copy and confirmed with `cmp`. The builder ran once only. The padding move did not relay out the canvas.

## Gates (real output tails)

`export PATH=/root/sdk/flutter/bin:$PATH CI=true`. All gates were run on the final tree before the commit.

**`packages/jet_cad_floor_plan`**
- `flutter test`: `05:29 +1468: All tests passed!` (exit 0)
- `flutter analyze`: `No issues found! (ran in 5.0s)`
- `dart format --output=none --set-exit-if-changed .`: `Formatted 248 files (0 changed) in 1.35 seconds.`, exit 0

**`apps/restaurant_demo`**
- `flutter test`: `00:26 +39: All tests passed!`
- `flutter analyze`: `No issues found! (ran in 5.3s)`
- format: `Formatted 4 files (0 changed) in 0.06 seconds.`, exit 0

**`apps/floor_planner`**
- `flutter test`: `02:10 +212: All tests passed!`
- `flutter analyze`: `No issues found! (ran in 5.7s)`
- format: `Formatted 47 files (0 changed) in 0.25 seconds.`, exit 0

**`packages/jet_cad_2d`**
- `dart test --file-reporter json:<run>.json` exited 1 (the two standing failures).
- `dart run tool/ci/expect_failures.dart --package packages/jet_cad_2d --root packages/jet_cad_2d <run>.json` printed `packages/jet_cad_2d: 1255 tests; the standing failures and skips, exactly`, exit 0.

**`packages/jet_cad_2d_flutter`**
- `flutter test --file-reporter json:<run>.json` exited 1 (the standing seven).
- The comparison printed `packages/jet_cad_2d_flutter: 1363 tests; the standing failures and skips, exactly`, exit 0.
- This is the path form from `.github/workflows/ci.yml` (`--package ${{ matrix.package }} --root ${{ matrix.package }}`).

`git status` before the commit showed only this task's files. No `analysis_options.yaml` was touched.

## Findings

- **F-1. Two `FloorPlanView`s over one controller crash, and did before this task.** The second service view installs a second expander: `Bad state: the dispatcher already has an expander (spec 06 D2)`. A CR3 test for that case was written, failed for this reason, and was dropped. `canvasRect`'s registry handles several views in principle, but this path is untested. The host guide might say "one view per controller".
- **F-2. `canvasRect` is top-left plus size in global logical pixels.** An ancestor that scales or rotates the view (`Transform`, `FittedBox`) is not accounted for, and `worldToGlobal` would be off under it. This is documented on `canvasRect`. A full transform would need a matrix in the API.
- **F-3. Choice 5 needs a decision:** `panBy` before the first mount suppresses the page fit. If the reviewer or the human prefers that the constructor's or `load`'s first fit survive a `panBy`, it is one line in `_command` (keep `_fitOnStart`).
- **F-4. The test count went from 1452 to 1468.** That is the 15 camera tests plus B4. Task 1's report gives 1452.
- **F-5. `frameTables` carries its own clamp, so a table fit is clamped twice.** Its clamp is kept because TF4 pins it, and it now takes the controller's bounds. The view's clamp is then a no-op on its result, so "one clamp" holds in effect.
