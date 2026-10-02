# Task 8b report: the review's fixes to Task 8 (spec D12)

Status: done (implementer). Base `90f0d97`. Commit **`bdff57d`** `fix(app): the ghost's camera path at release and re-arm`.

## Files changed
- `apps/floor_planner/lib/symbols/symbol_place_tool.dart`
- `apps/floor_planner/test/symbols/symbol_place_tool_test.dart`

## Changes
1. **Finding 1 (major): the release's `_track` is now covered.** New test in the camera group: `a release with no move before it: a zoom puts the ghost under the release point, not the press`. It does `down(pB)` and then `up(pC)`, with no move between them, and asserts the instance sits at `gridOf(pC)`. It then calls `expectFollows(rig, screen of pC, 1.7, ...)`. That checks:
   - the ghost is at `gridOf(screenToWorld(screen of pC))` under the zoomed camera;
   - E is outside the aperture;
   - the point under the pointer moved;
   - there is exactly one repaint.
   The test also asserts the ghost is **not** at `gridOf` of the press's screen point. The zoom is about (90, 520), away from both points.
2. **Finding 2 (minor): `_onArmed` uses the one recompute path.** It now reads:
   ```dart
   _syncPath();
   _syncCamera();
   final ctx = _listening;
   if (ctx != null) {
     _update(ctx, _worldUnderPointer(ctx));
   } else {
     _syncPlacement();
   }
   ```
   `!wasListening` is gone, so an entry -> entry re-arm while the ghost is shown also re-resolves (ruling R-C8b-1). I updated the doc comments on `_update` and the class.
   - New test: `a re-arm from one entry to another while the ghost is shown re-resolves it under the pointer: a snap change since the last event shows`. It presses R, hovers 75 mm from E and checks the ghost is at E. It then toggles F3 off; the tool does not listen to F3, so the ghost stays at E, and that is asserted as the fixture. It then re-arms chair -> toilet and asserts:
     - the ghost is at `gridOf(near)`;
     - all six components of the placement equal `placementTransform(gridOf(near), toilet base point, 1, false)`;
     - there is one repaint;
     - the camera still has one listener.
   - Added to the existing disarm test: `ghostPlacement` is null after a disarm (the getter's documented "null while idle"). Without it, the new `else` branch was unprotected (K-4 below).

No existing assertion changed. The only edit to an existing test is the one added `expect` in the disarm test.

## Gates (app only; engine and render are untouched by this task and were not re-run)
- `CI=true flutter test`: `04:35 +1132: All tests passed!`, exit 0. The base `90f0d97` has 1,130 (Task 8's 1,127 plus Task 9b's 3); this task adds 2.
- `CI=true flutter analyze`: `No issues found! (ran in 2.2s)`, exit 0.
- `CI=true dart format --output=none --set-exit-if-changed .`: `Formatted 180 files (0 changed)`, exit 0.
- `CI=true flutter build web --release`: `✓ Built build/web`, exit 0.
- `packages/jet_cad/analysis_options.yaml` (rewritten by pub get) is not staged; the commit has exactly the two files above.

## Mutants
All mutants are in `lib/symbols/symbol_place_tool.dart` at `bdff57d`'s line numbers. Each was run on `test/symbols/symbol_place_tool_test.dart`. Method: `cp` backup, scripted edit with line-content guards, run, `cp` back; `diff` exited 0 after every restore.

| Id | Change | Result | Red test / excerpt |
|---|---|---|---|
| R8-1 | l.268 `_track(e, ctx);` in `onPointerUp` deleted | **red** `+39 -1` | the release test: `Expected: <73675.3> Actual: <76600.3>` |
| K-1 | back to the old condition: `final wasListening = _listening != null;` before `_syncCamera()`, `if (ctx != null && !wasListening)` | **red** `+39 -1` | the entry -> entry re-arm test: `Expected: <73300.3> Actual: <73250.5>` (the ghost stays on E) |
| K-2 | l.161 `_update(...)` -> `_syncPlacement();` (a re-arm does not re-resolve) | **red** `+38 -2` | disarm test `Expected: <76325.3> Actual: <80125.3>`; entry -> entry test `Expected: <73300.3> Actual: <73250.5>` |
| K-3 | l.161 `_update(` -> `_resolve(` (the re-arm re-resolve skips the placement) | **red** `+37 -3` | W-15 ghost test `Expected: [0.0, -1.0, -1.0, 0.0, 81375.3, -36700.7] Actual: [..., 81675.3, -36600.7]`; disarm test `Null check operator used on a null value` (no placement); entry -> entry test `Expected: [0.0, 1.0, -1.0, 0.0, 73300.3, -42050.7] Actual: [0.0, 1.0, -1.0, 0.0, 73550.5, -42110.25]` |
| K-4 | l.163 the `else` `_syncPlacement();` deleted | survived (`+40: All tests passed!`) before the disarm test's added assertion; **red** `+39 -1` after it | disarm test: `Expected: null Actual: Transform2:<Transform2(1.0, 0.0, 0.0, 1.0, 79825.3, -35500.7)>` |
| K-5 | l.161 re-resolves the old world point (`_at.point.clone()`) instead of the screen point | **red** `+38 -2` | disarm test `Expected: <76325.3> Actual: <80125.3>`; entry -> entry test `Expected: <73300.3> Actual: <73250.3>` |

**Routing through `_update` versus the direct calls:** no test can tell them apart today. `_update` is exactly `_resolve` followed by `_syncPlacement`, so the two forms are the same program until Task 7 adds the attachment to `_update`. I considered a test seam, such as a `@visibleForTesting` count of `_update` calls, and decided against it. It would pin the code's structure, not its behaviour, and the refactor it detects (inlining `_update`) preserves behaviour today. K-3 does pin that the re-arm refreshes the placement, not only the point. **For the controller:** the mutant **"the re-arm re-resolve skips the attachment"** (l.161 `_update(` replaced by `_resolve(ctx, ...); _syncPlacement();`, or whatever Task 7's attachment step becomes) belongs to Task 7. Task 7 should fire it with a re-arm from an untagged entry to a tagged one (or back) while the ghost rests near a face, alongside M-09c-ak on the camera path.

## Rulings
- **R-C8b-1:** a re-arm re-resolves through `_update` whenever the tool listens to a camera after the re-arm, that is, while the ghost is shown. This covers a disarm -> entry re-arm and also an entry -> entry re-arm.
  - **Why:** after Task 7 the attachment depends on the entry: its `against-wall` tag and its box. A keyboard re-arm with the mouse resting must not keep the previous entry's attachment. A re-arm also picks up snap or document changes made since the last pointer event; the new test shows this with F3.
  - **Cost today:** `_lastScreen` round-trips through the tracked camera. Under a grid or an object snap that gives the same snapped point. With no grid and no snap the point can differ from the event's `e.world` by floating-point rounding (around 1e-12 mm). No existing test changed.
  - **With no listened context** (hidden, disarmed, or before any pointer event), a re-arm only refreshes the placement, as before.
  - **Cost if wrong:** restore the condition; that is one line.

## Notes
- The review's note 3 (two `Vector2`s per camera change), note 4 (no camera fixture moves the object snap or the adaptive grid) and note 5 (a re-arm can restore a stale ghost) are not addressed here. They are recorded in the ledger for Task 7 and Task 11.
