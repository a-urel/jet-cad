# Task 8 report — the ghost follows a wheel zoom (spec D12)

Status: done (implementer). Base `a073fb5`. Commit **`7150bd1`** `fix(app): the symbol ghost follows a wheel zoom`.

## Files changed
- `apps/floor_planner/lib/symbols/symbol_place_tool.dart`
- `apps/floor_planner/test/symbols/symbol_place_tool_test.dart`

## What was built
- `SymbolPlaceTool` keeps the last pointer event's screen point (`e.screen`, `_lastScreen`) and its context (`_context`, a plain reference) on down / move / up (`_track`).
- Invariant: the tool listens to a context's camera (`_listening`) **exactly while `ghostVisible`** (ghost shown and something armed). `_syncCamera()` enforces it: called after each pointer event, on pointer exit, on `cancel`, in `_onArmed` (disarm removes; a re-arm with the ghost still shown re-adds). `dispose` removes it and clears both references. Same shape as `PlacementTool._syncCamera` / `_listening` / `_onCamera`.
- The one recompute path: new `_update(ctx, raw)` = `_resolve` + `_syncPlacement`; all three pointer handlers and `_onCamera` call it (Task 7 adds the attachment there, ruling C-3). `_onCamera` = `_update(ctx, camera.screenToWorld(lastScreen))` + `notifyListeners()`.
- A re-arm from null with the ghost still shown (`_ghostVisible` was never cleared by a disarm) re-resolves once from the screen point, because the camera may have moved while nothing listened (R-C8-1).

## Tests added (group `the camera (spec 09c D12)`, 6 tests; test rig's camera is now a `CountingCamera` that counts listeners)
1. `a zoom about another point moves the ghost and its placement to the world point now under the pointer; a pan too` — R + M set (quarterTurns 1, mirrored), hover far from origin at scale 0.05, `zoomAt((90,520), 1.7)`; the world point under the pointer moves > 1000 mm; ghostAt == gridOf(screenToWorld(s)) exactly; ghostPlacement bytes == placementTransform(...); one notification; then a pan; then mid-press a zoom by 0.6 follows and the release places at the up point.
2. `one camera listener while the ghost is shown, however many events; none before the first pointer event` — also a re-arm while shown keeps 1.
3. `after the ghost hides (pointer exit) a camera change does nothing; a hover listens again` — also a disarm + re-arm while hidden does not listen.
4. `after cancel (a hover, or a press and Esc) a camera change does nothing`
5. `after a disarm a camera change does nothing; a re-arm listens again and puts the ghost under the pointer for the camera now`
6. `dispose with a live camera removes the listener; a camera change after it does nothing and does not throw`
"Does nothing" (`expectInert`): a zoom and a pan; ghostAt unchanged, ghostPlacement `same`, zero notifications, no throw. Fixtures: camera scale 0.05 then 0.085 etc. (never 1), points ~(8e4, -3.5e4), grid origin off round numbers, a non-default turn and mirror in test 1, chair and toilet (off-centre base points).

No existing assertion changed (the Rig's `camera` field type changed from `CameraController` to its subclass `CountingCamera`).

## Gates (app only; engine and render untouched by this task, not re-run)
- `CI=true flutter test` (app): `06:34 +1127: All tests passed!` (1,121 at Task 9's tip + 6).
- `CI=true flutter analyze`: `No issues found!`
- `CI=true dart format --output=none --set-exit-if-changed .`: `Formatted 180 files (0 changed)`, exit 0.
- `CI=true flutter build web --release`: `✓ Built build/web`.

## Mutants (all in `lib/symbols/symbol_place_tool.dart` at `7150bd1`'s line numbers; each run on `test/symbols/symbol_place_tool_test.dart`; backup by `cp`, restored by `cp`, `diff` exit 0 each time)

| Id | Line | Change | Red test(s) | Output excerpt |
|---|---|---|---|---|
| M-09c-s (not added) | 220 | `want?.camera.addListener(_onCamera);` deleted | all 6 camera tests | test 1: `Expected: <75875.3> Actual: <80125.3>`; test 2: `Expected: <1> Actual: <0>`; `+32 -6` |
| M-09c-s (not removed on dispose, live camera) | 403-405 | the three cleanup lines in `dispose` deleted | test 6 | `Expected: <0> Actual: <1>`; with the count assertion removed from the test (scratch copy): `Expected: <80125.3> Actual: <75875.3>` — the ghost re-resolved after dispose |
| M-09c-s variant | 403 only | removeListener deleted, `_listening = null` kept | test 6 (count) only | `Expected: <0> Actual: <1>`; without the count assertion the test passes, because `_onCamera` returns on a null `_listening` — the listener is dead weight but inert. The count is the load-bearing assertion here. |
| M-09c-bb (hide) | 276 | `_syncCamera();` in `onPointerExit` deleted | test 3 | `Expected: <0> Actual: <1>`; counts removed: `Expected: <80125.3> Actual: <76325.3>` |
| M-09c-bb (cancel) | 343 | `_syncCamera();` in `cancel` deleted | test 4 | `Expected: <0> Actual: <1>`; counts removed: `Expected: <80125.3> Actual: <76325.3>` |
| M-09c-bb (disarm) | 153 | `if (armed.value != null) _syncCamera();` | test 5 | `Expected: <0> Actual: <1>`; counts removed: `Expected: <80125.3> Actual: <76325.3>` |
| X-1 re-arm does not re-listen | 153 | `if (armed.value == null) _syncCamera();` | test 5 | `Expected: <1> Actual: <0>` |
| X-2 re-arm does not re-resolve | 158 | `_resolve(ctx, _worldUnderPointer(ctx));` deleted | test 5 | `Expected: <76325.3> Actual: <80125.3>` |
| X-3 camera re-resolve skips the placement | 226 | `_update(` -> `_resolve(` | test 1 | `Expected: [0.0, -1.0, -1.0, 0.0, 76175.3, -39100.7] Actual: [0.0, -1.0, -1.0, 0.0, 80425.3, -34900.7]` |
| X-4 screen point not kept | 207 | `_lastScreen = e.screen;` deleted | tests 1, 3, 5 | `Expected: <75875.3> Actual: <68750.3>`; `+35 -3` |

"counts removed" rows: a scratch copy of the test with every `expect(rig.camera.listeners, …)` line deleted (14 lines), to show the behavioural assertions kill the mutant on their own; the test file was restored by `cp` and `diff` exit 0.
M-09c-ak (zoom re-resolve skips the attachment) is Task 7's (ruling C-3): the camera path runs `_update`, the same as a pointer move.

## Proposed rulings
- **R-C8-1:** a disarm removes the camera listener but does not clear `_ghostVisible` (today's behaviour: re-arming with no pointer event shows the ghost again). So a re-arm with the ghost still shown re-adds the listener (using the last pointer event's context, kept as a plain reference) and re-resolves the ghost once from the kept screen point, since the camera may have moved while disarmed. Alternative: a disarm hides the ghost (no re-listen needed; the ghost reappears only on the next pointer event). The shell never disarms today (`main.dart` only sets `_armed.value = entry`), so this is test-only reachability. Cost if wrong: about six lines in `_onArmed` and test 5's second half.
- **R-C8-2:** the plan's test "a zoom that brings a face within capture attaches" is Task 7's with M-09c-ak (C-3); not written here.
- **R-C8-3:** the tool keeps the context of the last pointer event (`_context`) separately from the listened one (`_listening`); if a later event brings a different context, `_syncCamera` moves the listener to it. The shell has a single `ToolContext`, so this does not churn.

## Found, not fixed
- `ChangeNotifier.notifyListeners` (the camera) reports and swallows a listener's error, so "does not throw after dispose" alone cannot detect a listener left on the camera. Test 6 asserts the listener count and the ghost's point instead.

## For the reviewer to look at hardest
- `_onArmed`'s re-resolve condition (`ctx != null && !wasListening`): it only fires on a not-listening -> listening transition; a re-arm entry -> entry while shown does not re-resolve (the camera was tracked).
- The re-resolve on a camera change runs mid-press too (the ghost follows); the release still resolves from the up event's `e.world`.
- The camera path allocates one `Vector2` per camera change (`screenToWorld`), as `PlacementTool` does; it is not the paint path.
