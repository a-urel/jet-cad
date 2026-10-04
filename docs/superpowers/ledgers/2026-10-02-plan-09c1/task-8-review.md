# Task 8 review: the ghost follows a wheel zoom (spec D12)

Reviewer: independent. Reviewed commit `7150bd1` (base `a073fb5`), `git diff a073fb5..7150bd1`, in the detached worktree `.worktrees/plan-09c1-review-t8`.
Files: `apps/floor_planner/lib/symbols/symbol_place_tool.dart`, `apps/floor_planner/test/symbols/symbol_place_tool_test.dart` (nothing else changed).

## Verdict: **Needs fixes** (1 major, 1 minor, 3 notes)

The implementation matches D12 and the plan's Task 8. The listener lifecycle is correct on every path I traced: pointer down, move and up; exit; cancel, including Esc and `ToolController.activate`, which cancels the outgoing tool; disarm; re-arm; dispose. In `main.dart` the shell disposes the camera (l.762) after the tool (l.741). Every named mutant is red. One line this task added survives its deletion (finding 1), and a 6-line test kills it.

## Gates (re-run by me; app only, since engine and render are untouched by the diff)

| Gate | Result | Implementer |
|---|---|---|
| `CI=true flutter test` (app) | `08:30 +1127: All tests passed!`, exit 0 | +1127 (same) |
| `CI=true flutter analyze` | `No issues found!`, exit 0 | same |
| `CI=true dart format --output=none --set-exit-if-changed .` | `Formatted 180 files (0 changed)`, exit 0 | same |
| `CI=true flutter build web --release` | `✓ Built build/web`, exit 0 | same |

Other checks:
- The two allocation invariant tests are unedited (`git diff a073fb5..7150bd1 -- packages/*/test/invariants` is empty).
- No `analysis_options.yaml` in the commit. The commit has exactly the two files. In my worktree, pub get rewrote `packages/jet_cad/analysis_options.yaml`; it is not staged and nothing was committed.
- Purity holds: `wall_attach.dart` and `symbol_box.dart` import no Flutter and no `dart:ui`. The diff does not touch them.
- No existing assertion changed. Only the Rig's `camera` field type moved from `CameraController` to its subclass `CountingCamera`.

## Mutants (re-fired by me)

Each run: `cp` backup, scripted edit with line-content guards, `CI=true flutter test test/symbols/symbol_place_tool_test.dart`, `cp` back. The `diff` after every restore exited 0. Line numbers are at `7150bd1`.

| Id | Change | Result | Red test / excerpt |
|---|---|---|---|
| M-09c-s (not added) | l.220 `want?.camera.addListener(_onCamera);` deleted | **red** `+32 -6` | all 6 camera tests; `Expected: <75875.3> Actual: <80125.3>`, `Expected: <1> Actual: <0>` |
| M-09c-s (not removed on dispose) | l.403-405 deleted | **red** `+37 -1` | dispose test, `Expected: <0> Actual: <1>` |
| M-09c-bb (hide) | l.276 `_syncCamera();` in `onPointerExit` deleted | **red** `+37 -1` | pointer-exit test, `Expected: <0> Actual: <1>` |
| M-09c-bb (cancel) | l.343 deleted | **red** `+37 -1` | cancel test, `Expected: <0> Actual: <1>` |
| M-09c-bb (disarm) | l.153 -> `if (armed.value != null) _syncCamera();` | **red** `+37 -1` | disarm test, `Expected: <0> Actual: <1>` |
| M-09c-ak | Task 7's (ruling C-3) | not fired | — |
| R8-1 (mine) | l.263 `_track(e, ctx);` in `onPointerUp` deleted | **SURVIVES** `+38: All tests passed!` | see finding 1 |
| R8-2 (mine) | l.236 `_track(e, ctx);` in `onPointerDown` deleted | **red** `+37 -1` | zoom test (mid-press), `Expected: <88800.3> Actual: <80350.3>` |
| R8-3 (mine) | l.227 `notifyListeners();` in `_onCamera` deleted | **red** `+35 -3` | zoom, exit and disarm tests, `Expected: [false] Actual: []` |
| R8-4 (mine) | l.216 `ghostVisible` -> `_ghostVisible` (a disarm keeps the listener) | **red** `+37 -1` | disarm test, `Expected: <0> Actual: <1>` |
| R8-5 (mine) | l.158 the re-arm re-resolves the old world point (`_at.point.clone()`) instead of the screen point | **red** `+37 -1` | disarm test, `Expected: <76325.3> Actual: <80125.3>` |
| R8-6 (mine) | l.239 `_syncCamera();` in `onPointerDown` deleted (a press without a hover, i.e. touch) | **red** `+37 -1` | cancel test, `Expected: <1> Actual: <0>` |

Some tests keep only the listener count as their load-bearing assertion. The implementer's "counts removed" runs show the behavioural assertions also kill N3, N4 and N5, and test 6 checks `ghostAt` as well as the count. The tests therefore do not rely on "does not throw" alone. That matters, because `ChangeNotifier` swallows listener errors.

## Findings

1. **major (testing bar; the user impact is narrow): the release's `_track` is unprotected.**
   - **Where:** `symbol_place_tool.dart:263`.
   - **Evidence:** R8-1 deletes the line and the whole file stays green (`+38`). Every release in the camera tests lands at the screen point of the preceding down or move: test 1 releases at `under(pB screen)` after pressing at pB, and test 2's `up(pC)` is followed by a hover. So no test sees the up's own screen point.
   - **Effect:** after a press at B and a release at C with no move in between (a touch tap-and-slide, or an up whose position differs from the last move), the ghost stays shown at C. A wheel zoom then re-resolves it under B's screen point.
   - **Proof:** I added this scratch test (not committed; deleted afterwards). It passes at `7150bd1` and goes red under R8-1 with `Expected: <73675.3> Actual: <76600.3>`:
     ```dart
     final rig = t.Rig();
     rig.down(t.pB);
     rig.up(t.pC);
     final s = rig.at(t.pC).screen;
     rig.camera.zoomAt(const ui.Offset(90, 520), 1.7);
     final w = rig.camera.value.screenToWorld(Vector2(s.dx, s.dy));
     t.expectAt(rig.tool.ghostAt, t.gridOf(w), 'under the release point');
     ```
   - **Fix:** add that case to the camera group, either in test 1 or as a seventh test, and record R8-1 red in the report.

2. **minor (a hazard for Task 7 under ruling C-3): `_onArmed` re-resolves outside the one recompute path.**
   - **Where:** `symbol_place_tool.dart:150-160`.
   - **The problem:** the re-arm re-resolve calls `_resolve` and then `_syncPlacement` directly, not `_update`. C-3 says Task 7 adds the attachment to `_update`. Once it does, a disarm followed by a re-arm while the ghost is shown will snap without attaching. The ghost would sit unattached next to a wall until the next pointer move.
   - **The re-resolve condition:** separately, `ctx != null && !wasListening` skips the re-resolve on an entry -> entry re-arm while the ghost is shown. That is **not a defect at `7150bd1`**: the camera was tracked, `_resolve` does not depend on the entry, and `_syncPlacement` takes the new base point. After Task 7, though, the attachment depends on the entry: its `against-wall` tag and its box width. A keyboard-driven re-arm, with the mouse resting on the canvas, from a tagged bed to the untagged island would then keep a stale attachment.
   - **Fix (now, in 8b, or written into Task 7's brief):** make `_onArmed` do
     ```dart
     if (ctx != null) { _update(ctx, _worldUnderPointer(ctx)); } else { _syncPlacement(); }
     ```
     This drops `!wasListening`. Re-resolving from the tracked screen point under the tracked camera reproduces the same snapped point, so it is harmless today.
   - **Mutant for Task 7:** "the re-arm re-resolve skips the attachment".

3. **note: two `Vector2`s per camera change, not one.** `_worldUnderPointer` builds one, and `ViewportTransform.screenToWorld` (`Transform2.transformPoint`, `transform2.dart:71`) returns another. This happens per camera event, not in a paint, the same way as `PlacementTool`, so the frame-path invariant is unaffected. Only the report's wording is off.

4. **note: no camera fixture moves the object snap or the adaptive grid.** Every camera test asserts that E lies outside the aperture, and the rig's grid step is fixed (25 mm). D12 says a camera change re-resolves "the snap, the grid". Both read the live `cam.scale` in the shared `_resolve`, so no camera-specific mutant exists today. Task 7 or 11 could add one zoom-out that brings E inside `kSnapAperturePixels / scale` (the ghost jumps to E), and one with `step: null`.

5. **note (R-C8-1): a re-arm can restore a stale ghost.** Pointer events are ignored while disarmed, so `_lastScreen` goes stale. A re-arm after a disarm puts the ghost under the last pre-disarm screen point until the next move. This is the same class as today's behaviour, where re-arming re-shows the old ghost, and the shell never disarms (`main.dart:673` only sets an entry).

## Rulings

- **R-C8-1:** accepted. A disarm removes the listener and keeps `_ghostVisible`. A re-arm while shown re-listens and re-resolves once. This matches D12 ("listens while the ghost is visible") and W-17. See finding 2 for routing the re-resolve through `_update`.
- **R-C8-2:** accepted. The test "a zoom that brings a face within capture attaches" and M-09c-ak are Task 7's under C-3. Task 7 must own both and fire M-09c-ak on the camera path.
- **R-C8-3:** accepted. `_context` (the last event's context) and `_listening` (the listened context) are distinct. `_syncCamera` moves the listener when a later event brings another context, and `dispose` clears both. The shell has a single `ToolContext`.
- The mid-press zoom follows (test 1, R8-2 red). The release resolves from the up event's `e.world`, so it places where the up lands.

## Fixtures (P-2)

The camera tests use non-degenerate fixtures:
- Camera scale 0.05, then 0.085, 0.03 and 0.0375; never 1.
- Pointers around (8e4, −3.5e4), with the zoom focus (90, 520) away from every pointer. Test 1 asserts the world point under the pointer moves more than 1000 mm.
- A grid origin off round numbers.
- A turned and mirrored placement compared on all six components (test 1).
- The toilet's off-centre base point in the re-arm test.

The only gap is finding 4.

## Re-review of 8b (bdff57d)

Diff `git diff 90f0d97..bdff57d`: `lib/symbols/symbol_place_tool.dart` and `test/symbols/symbol_place_tool_test.dart` only. The parent `90f0d97` is Task 9b's cherry-pick and touches only `symbol_placer_test.dart`. Checked out detached in `.worktrees/plan-09c1-review-t8`.

### Verdict: **Approved**

Both findings are fixed, and every mutant I fired is red.

### Gates (re-run by me, app)

| Gate | My result | Implementer |
|---|---|---|
| `CI=true flutter test` | `06:04 +1132: All tests passed!`, exit 0 | +1132 (same) |
| `CI=true flutter analyze` | `No issues found!`, exit 0 | same |
| `CI=true dart format --output=none --set-exit-if-changed .` | `Formatted 180 files (0 changed)`, exit 0 | same |
| `CI=true flutter build web --release` | `✓ Built build/web`, exit 0 | same |

- The commit has exactly the two files.
- No `analysis_options.yaml` in the commit, and no invariant test touched.
- My worktree's `packages/jet_cad/analysis_options.yaml` is pub get's rewrite; it is unstaged and nothing was committed.

### Mutants (re-fired by me at bdff57d)

Method: `cp` backup, scripted edit with line-content guards, run `test/symbols/symbol_place_tool_test.dart`, `cp` back; `diff` exited 0 after every restore.

| Id | Change | Result | Red test / excerpt |
|---|---|---|---|
| R8-1 (my survivor) | l.268 `_track(e, ctx);` in `onPointerUp` deleted | **red** `+39 -1` | "a release with no move before it", `Expected: <73675.3> Actual: <76600.3>` |
| K-1 | the old condition back (`wasListening`; `ctx != null && !wasListening`) | **red** `+39 -1` | the entry -> entry re-arm test, `Expected: <73300.3> Actual: <73250.5>` |
| K-2 | l.161 `_update(...)` -> `_syncPlacement();` | **red** `+38 -2` | disarm test `Expected: <76325.3> Actual: <80125.3>`; entry -> entry test `<73300.3>` / `<73250.5>` |
| K-3 | l.161 `_update(` -> `_resolve(` | **red** `+37 -3` | W-15 ghost test `[..., 81375.3, -36700.7]` vs `[..., 81675.3, -36600.7]`; disarm test `Null check operator used on a null value` (l.1128); entry -> entry test `[0.0, 1.0, -1.0, 0.0, 73300.3, -42050.7]` vs `[..., 73550.5, -42110.25]` |
| K-4 | l.163 the `else` `_syncPlacement();` deleted | **red** `+39 -1` | disarm test, `Expected: null Actual: Transform2:<Transform2(1.0, 0.0, 0.0, 1.0, 79825.3, -35500.7)>` |
| K-5 | l.161 re-resolves `_at.point.clone()` instead of the screen point | **red** `+38 -2` | disarm test `<76325.3>` / `<80125.3>`; entry -> entry test `<73300.3>` / `<73250.3>` |

These match the implementer's table excerpt for excerpt.

### Findings 1 and 2

- **Finding 1 is fixed.**
  - The new test presses at pB and releases at pC with no move in between.
  - It asserts the instance is at `gridOf(pC)`, and that a 1.7 zoom about (90, 520) puts the ghost at `gridOf` of the world point under pC's screen point. That includes E outside the aperture, the point moving, and one repaint.
  - It also asserts the ghost is not under the press's screen point.
  - This is the case I proposed, and it kills R8-1.
- **Finding 2 is fixed.**
  - `_onArmed` now goes through `_update` whenever a camera is listened to after the re-arm, and otherwise only `_syncPlacement()`.
  - `_update` is still exactly `_resolve` followed by `_syncPlacement`. C-3 holds: once Task 7 adds the attachment to `_update`, every re-arm while shown attaches through it.
  - The implementer is right that no behavioural test can tell `_update` from inlined `_resolve` + `_syncPlacement` today. The mutant "the re-arm re-resolve skips the attachment" belongs to Task 7, next to M-09c-ak, and the controller should put it in Task 7's brief.

### R-C8b-1 (re-arm always re-resolves through `_update` while a camera is listened)

**Accepted.**
- If a camera is listened to after `_syncCamera`, then `ghostVisible` is true and the armed value is non-null, so `_update`'s `_syncPlacement` always has an entry.
- An entry -> entry re-arm under an unchanged camera reproduces the same snapped point: `_lastScreen` round-trips through the tracked camera. With no grid and no object snap, it can drift from the event's `e.world` by about 1e-12 mm. The ghost is never committed from that point (the release resolves from `e.world`), so this is harmless.
- A re-arm while pressed still drops the press after the re-resolve.
- It also makes the re-arm pick up snap and document changes made since the last pointer event, which the new F3 test pins.
- Cost if wrong: one condition.

### The new disarm assertion

**Sound.** `expect(rig.tool.ghostPlacement, isNull)` after `armed.value = null` matches the getter's documented contract ("null while idle"). It is what kills K-4, the deleted `else` branch. It is a new assertion, not an edited one.

### Fixtures of the new tests

- The release test reuses the rig: scale 0.05, then 0.085; points far from the origin; zoom focus away from both points.
- The re-arm test:
  - object snap on; the pointer 75 mm from E (inside the 200 mm aperture), at `e0 + (60, −45)`, far from the origin;
  - one quarter turn; the toilet's off-centre base point;
  - all six placement components compared against `placementTransform`;
  - one repaint, and the listener count still 1.

None of this is degenerate.

### Notes (no action for 8b)

- **F3 does not refresh the ghost.** The re-arm test uses the fact that the tool does not re-resolve on an F3 toggle ("F3 alone moves nothing") as its fixture. That is pre-existing behaviour: the ghost stays stale until the next pointer event after F3. Task 7 makes the attachment depend on `objectSnap` (M-09c-l). If Task 7 or later decides F3 should refresh the ghost, this test's fixture assertion has to change with it. Flag it in Task 7's brief.
- **Earlier notes carried to the ledger.** Notes 3 to 5 of the first review are carried to Task 7 and Task 11, as the 8b report says.
